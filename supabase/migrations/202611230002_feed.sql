-- Anime Friends: Feed tables and access policies.

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint posts_content_length
    check (char_length(trim(content)) between 1 and 4000),

  constraint posts_image_https
    check (image_url is null or image_url ~* '^https://')
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  value smallint not null default 1 check (value in (-1, 1)),
  created_at timestamptz not null default now(),

  primary key (post_id, user_id)
);

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now(),

  constraint post_comments_content_length
    check (char_length(trim(content)) between 1 and 1500)
);

create index if not exists posts_created_at_idx
  on public.posts (created_at desc);

create index if not exists posts_user_id_idx
  on public.posts (user_id);

create index if not exists post_likes_user_id_idx
  on public.post_likes (user_id);

create index if not exists post_comments_post_id_idx
  on public.post_comments (post_id);

alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;

-- Posts: authenticated users can read; authors can insert,
-- update and delete their own posts.
drop policy if exists "Authenticated users can read posts"
  on public.posts;
create policy "Authenticated users can read posts"
  on public.posts for select to authenticated
  using (true);

drop policy if exists "Users can create their own posts"
  on public.posts;
create policy "Users can create their own posts"
  on public.posts for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own posts"
  on public.posts;
create policy "Users can update their own posts"
  on public.posts for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own posts"
  on public.posts;
create policy "Users can delete their own posts"
  on public.posts for delete to authenticated
  using (auth.uid() = user_id);

-- Likes: visible to authenticated users; each user controls
-- only their own like record.
drop policy if exists "Authenticated users can read post likes"
  on public.post_likes;
create policy "Authenticated users can read post likes"
  on public.post_likes for select to authenticated
  using (true);

drop policy if exists "Users can add their own post likes"
  on public.post_likes;
create policy "Users can add their own post likes"
  on public.post_likes for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can remove their own post likes"
  on public.post_likes;
create policy "Users can remove their own post likes"
  on public.post_likes for delete to authenticated
  using (auth.uid() = user_id);

-- Comments: authenticated users can read; authors can add
-- and remove their own comments.
drop policy if exists "Authenticated users can read post comments"
  on public.post_comments;
create policy "Authenticated users can read post comments"
  on public.post_comments for select to authenticated
  using (true);

drop policy if exists "Users can add their own post comments"
  on public.post_comments;
create policy "Users can add their own post comments"
  on public.post_comments for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can remove their own post comments"
  on public.post_comments;
create policy "Users can remove their own post comments"
  on public.post_comments for delete to authenticated
  using (auth.uid() = user_id);

revoke all on public.posts, public.post_likes, public.post_comments
  from anon, authenticated;


-- Return Feed posts with author information and aggregated counts.
-- Runs with the caller's permissions and respects table RLS.
create or replace function public.get_feed_posts(p_limit integer default 30)
returns table (
  id uuid,
  user_id uuid,
  content text,
  image_url text,
  created_at timestamptz,
  username text,
  display_name text,
  avatar_url text,
  like_count bigint,
  comment_count bigint,
  liked boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    p.id,
    p.user_id,
    p.content,
    p.image_url,
    p.created_at,
    pr.username,
    pr.display_name,
    pr.avatar_url,
    (
      select count(*)
      from public.post_likes pl
      where pl.post_id = p.id and pl.value = 1
    ) as like_count,
    (
      select count(*)
      from public.post_comments pc
      where pc.post_id = p.id
    ) as comment_count,
    exists (
      select 1
      from public.post_likes pl
      where pl.post_id = p.id
        and pl.user_id = auth.uid()
        and pl.value = 1
    ) as liked
  from public.posts p
  join public.profiles pr on pr.id = p.user_id
  order by p.created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 50));
$$;

revoke all on function public.get_feed_posts(integer)
  from public, anon, authenticated;

grant execute on function public.get_feed_posts(integer)
  to authenticated;

grant select, delete on public.posts to authenticated;
grant insert (user_id, content, image_url)
  on public.posts to authenticated;
grant update (content, image_url)
  on public.posts to authenticated;

grant select, delete on public.post_likes to authenticated;
grant insert (post_id, user_id, value)
  on public.post_likes to authenticated;

grant select, delete on public.post_comments to authenticated;
grant insert (post_id, user_id, content)
  on public.post_comments to authenticated;
