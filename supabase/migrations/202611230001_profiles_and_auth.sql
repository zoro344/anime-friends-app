-- Anime Friends: Supabase account profile foundation.
-- Email and password remain managed by Supabase Auth.
-- Public profiles contain usernames, not email addresses.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  display_name text,
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_username_format
    check (username ~ '^[a-z0-9_]{3,24}$'),

  constraint profiles_display_name_length
    check (display_name is null or char_length(display_name) <= 40),

  constraint profiles_bio_length
    check (char_length(bio) <= 150)
);

-- Usernames are unique without regard to letter case.
create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username));

alter table public.profiles enable row level security;

-- Authenticated users can view public profiles.
drop policy if exists "Authenticated users can view profiles" on public.profiles;
create policy "Authenticated users can view profiles"
  on public.profiles
  for select
  to authenticated
  using (true);

-- Users can update only their own profile.
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (username, display_name, bio, avatar_url)
  on public.profiles to authenticated;

-- Create a profile automatically when Supabase Auth creates an account.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_username text;
  requested_display_name text;
begin
  requested_username :=
    lower(trim(coalesce(new.raw_user_meta_data ->> 'username', '')));

  requested_display_name :=
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '');

  if requested_username !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'Username must be 3-24 characters using lowercase letters, numbers, or underscores.';
  end if;

  if requested_display_name is not null
     and char_length(requested_display_name) > 40 then
    raise exception 'Display name is too long.';
  end if;

  insert into public.profiles (id, username, display_name)
  values (new.id, requested_username, requested_display_name);

  return new;
end;
$$;

-- Prevent application roles from directly executing this privileged function.
revoke all on function public.handle_new_user()
  from PUBLIC, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute procedure public.handle_new_user();

-- Keep updated_at current when a profile changes.
create or replace function public.set_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute procedure public.set_profile_updated_at();
