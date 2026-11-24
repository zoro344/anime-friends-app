-- Anime Friends: community anime reviews and ratings.

create table if not exists public.anime_reviews (
  id uuid primary key default gen_random_uuid(),
  anime_id integer not null check (anime_id > 0),
  user_id uuid not null default auth.uid()
    references public.profiles(id) on delete cascade,
  rating smallint not null
    check (rating between 1 and 10),
  review_text text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint anime_reviews_text_length
    check (char_length(trim(review_text)) between 1 and 1500),

  constraint anime_reviews_one_per_user
    unique (anime_id, user_id)
);

create index if not exists anime_reviews_anime_created_idx
  on public.anime_reviews (anime_id, created_at desc);

create index if not exists anime_reviews_user_idx
  on public.anime_reviews (user_id);

alter table public.anime_reviews enable row level security;

drop policy if exists "Authenticated users can read anime reviews"
  on public.anime_reviews;

create policy "Authenticated users can read anime reviews"
  on public.anime_reviews
  for select to authenticated
  using (true);

drop policy if exists "Users can create their own anime reviews"
  on public.anime_reviews;

create policy "Users can create their own anime reviews"
  on public.anime_reviews
  for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own anime reviews"
  on public.anime_reviews;

create policy "Users can update their own anime reviews"
  on public.anime_reviews
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own anime reviews"
  on public.anime_reviews;

create policy "Users can delete their own anime reviews"
  on public.anime_reviews
  for delete to authenticated
  using (auth.uid() = user_id);

revoke all on public.anime_reviews from anon, authenticated;

grant select, delete on public.anime_reviews to authenticated;

grant insert (anime_id, rating, review_text)
  on public.anime_reviews to authenticated;

grant update (rating, review_text)
  on public.anime_reviews to authenticated;

-- Maintain updated_at whenever a review is edited.
create or replace function public.set_anime_review_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_anime_review_updated_at()
  from public, anon, authenticated;

drop trigger if exists anime_reviews_set_updated_at
  on public.anime_reviews;

create trigger anime_reviews_set_updated_at
  before update on public.anime_reviews
  for each row
  execute procedure public.set_anime_review_updated_at();
