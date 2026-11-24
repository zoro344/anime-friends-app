-- Add one-level replies to post comments.
alter table public.post_comments
add column if not exists parent_comment_id uuid
references public.post_comments(id)
on delete cascade;

create index if not exists post_comments_parent_comment_id_idx
on public.post_comments(parent_comment_id);

-- Replies must belong to the same post as their parent.
-- Replies to replies are intentionally not allowed.
create or replace function public.validate_post_comment_parent()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  parent_post_id uuid;
  parent_parent_id uuid;
begin
  if new.parent_comment_id is null then
    return new;
  end if;

  select post_id, parent_comment_id
  into parent_post_id, parent_parent_id
  from public.post_comments
  where id = new.parent_comment_id;

  if not found then
    raise exception 'Parent comment does not exist';
  end if;

  if parent_post_id <> new.post_id then
    raise exception 'Reply must belong to the same post';
  end if;

  if parent_parent_id is not null then
    raise exception 'Replies to replies are not supported';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_post_comment_parent
on public.post_comments;

create trigger validate_post_comment_parent
before insert or update of parent_comment_id, post_id
on public.post_comments
for each row
execute function public.validate_post_comment_parent();

-- Allow authenticated users to include a parent comment when inserting.
grant insert (parent_comment_id)
on public.post_comments
to authenticated;
