-- Allow authenticated users to edit only their own comments.

drop policy if exists "Users can update their own post comments"
on public.post_comments;

create policy "Users can update their own post comments"
on public.post_comments
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant update (content)
on public.post_comments
to authenticated;
