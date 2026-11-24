alter table public.anime_library
  add column if not exists rewatch_count integer not null default 0,
  add column if not exists priority smallint not null default 2,
  add column if not exists notes text;

alter table public.anime_library
  drop constraint if exists anime_library_rewatch_count_check,
  add constraint anime_library_rewatch_count_check
    check (rewatch_count >= 0),
  drop constraint if exists anime_library_priority_check,
  add constraint anime_library_priority_check
    check (priority between 1 and 3),
  drop constraint if exists anime_library_notes_check,
  add constraint anime_library_notes_check
    check (notes is null or char_length(notes) <= 500);

alter table public.manga_library
  add column if not exists reread_count integer not null default 0,
  add column if not exists priority smallint not null default 2,
  add column if not exists notes text;

alter table public.manga_library
  drop constraint if exists manga_library_reread_count_check,
  add constraint manga_library_reread_count_check
    check (reread_count >= 0),
  drop constraint if exists manga_library_priority_check,
  add constraint manga_library_priority_check
    check (priority between 1 and 3),
  drop constraint if exists manga_library_notes_check,
  add constraint manga_library_notes_check
    check (notes is null or char_length(notes) <= 500);

create table if not exists public.manga_chapter_history (
  id uuid primary key default gen_random_uuid(),
  library_id uuid not null
    references public.manga_library(id) on delete cascade,
  chapter_number integer not null check (chapter_number > 0),
  read_at timestamptz not null default now(),
  unique (library_id, chapter_number)
);

create index if not exists manga_chapter_history_library_idx
  on public.manga_chapter_history (library_id, chapter_number);

alter table public.manga_chapter_history enable row level security;

drop policy if exists "Users can read their chapter history"
  on public.manga_chapter_history;
create policy "Users can read their chapter history"
  on public.manga_chapter_history
  for select to authenticated
  using (
    exists (
      select 1 from public.manga_library library
      where library.id = manga_chapter_history.library_id
        and library.user_id = auth.uid()
    )
  );

drop policy if exists "Users can add their chapter history"
  on public.manga_chapter_history;
create policy "Users can add their chapter history"
  on public.manga_chapter_history
  for insert to authenticated
  with check (
    exists (
      select 1 from public.manga_library library
      where library.id = manga_chapter_history.library_id
        and library.user_id = auth.uid()
    )
  );

drop policy if exists "Users can delete their chapter history"
  on public.manga_chapter_history;
create policy "Users can delete their chapter history"
  on public.manga_chapter_history
  for delete to authenticated
  using (
    exists (
      select 1 from public.manga_library library
      where library.id = manga_chapter_history.library_id
        and library.user_id = auth.uid()
    )
  );

grant select, delete on public.manga_chapter_history to authenticated;
grant insert (library_id, chapter_number)
  on public.manga_chapter_history to authenticated;
