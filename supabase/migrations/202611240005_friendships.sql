-- Anime Friends: Supabase friend requests and friendships.

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friend_requests_no_self check (sender_id <> receiver_id)
);

-- Prevent duplicate pending requests or duplicate accepted friendships,
-- regardless of which user initiated the relationship.
create unique index if not exists friend_requests_unique_active_pair
on public.friend_requests (
  least(sender_id, receiver_id),
  greatest(sender_id, receiver_id)
)
where status in ('pending', 'accepted');

create index if not exists friend_requests_receiver_status
on public.friend_requests (receiver_id, status);

create index if not exists friend_requests_sender_status
on public.friend_requests (sender_id, status);

alter table public.friend_requests enable row level security;

drop policy if exists "Users can view their own friend relationships"
on public.friend_requests;

create policy "Users can view their own friend relationships"
on public.friend_requests
for select
to authenticated
using (auth.uid() in (sender_id, receiver_id));

drop policy if exists "Users can send their own friend requests"
on public.friend_requests;

create policy "Users can send their own friend requests"
on public.friend_requests
for insert
to authenticated
with check (
  auth.uid() = sender_id
  and status = 'pending'
);

drop policy if exists "Receivers can respond to pending requests"
on public.friend_requests;

create policy "Receivers can respond to pending requests"
on public.friend_requests
for update
to authenticated
using (
  auth.uid() = receiver_id
  and status = 'pending'
)
with check (
  auth.uid() = receiver_id
  and status in ('accepted', 'rejected')
);

drop policy if exists "Users can remove accepted friendships"
on public.friend_requests;

create policy "Users can remove accepted friendships"
on public.friend_requests
for delete
to authenticated
using (
  auth.uid() in (sender_id, receiver_id)
  and status = 'accepted'
);

revoke all on public.friend_requests from anon, authenticated;

grant select, insert, delete
on public.friend_requests to authenticated;

grant update (status)
on public.friend_requests to authenticated;

-- Keep updated_at current when a request is accepted or rejected.
create or replace function public.set_friend_request_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists friend_requests_set_updated_at
on public.friend_requests;

create trigger friend_requests_set_updated_at
before update on public.friend_requests
for each row
execute procedure public.set_friend_request_updated_at();
