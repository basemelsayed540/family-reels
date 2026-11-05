-- ============================================================
-- لمّتنا: السماح لكل الأعضاء المقبولين بالنشر + تعديل/حذف للمالك والأدمن
-- شغّله بعد setup.sql و social.sql:
-- SQL Editor -> New query -> الصق الملف كله -> Run
-- آمن لو شغّلته أكتر من مرة.
-- ============================================================

-- ---------- منشورات بصور ----------
alter table public.posts add column if not exists image_path text;
alter table public.posts alter column body set default '';
alter table public.posts drop constraint if exists posts_body_check;
alter table public.posts drop constraint if exists posts_body_or_image;
alter table public.posts add constraint posts_body_or_image
  check (char_length(body) <= 1000 and (char_length(body) >= 1 or image_path is not null));

-- ---------- الفيديوهات (ريلز): أي عضو مقبول يرفع، والمالك والأدمن يعدّلوا ويحذفوا ----------
drop policy if exists videos_insert on public.videos;
create policy videos_insert on public.videos
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_approved());

drop policy if exists videos_delete on public.videos;
create policy videos_delete on public.videos
  for delete to authenticated
  using (public.is_admin() or user_id = auth.uid());

drop policy if exists videos_update on public.videos;
create policy videos_update on public.videos
  for update to authenticated
  using (public.is_admin() or user_id = auth.uid())
  with check (public.is_admin() or user_id = auth.uid());

-- ---------- التعديل (المالك والأدمن) ----------
drop policy if exists stories_update on public.stories;
create policy stories_update on public.stories
  for update to authenticated
  using (public.is_admin() or user_id = auth.uid())
  with check (public.is_admin() or user_id = auth.uid());

drop policy if exists posts_update on public.posts;
create policy posts_update on public.posts
  for update to authenticated
  using (public.is_admin() or user_id = auth.uid())
  with check (public.is_admin() or user_id = auth.uid());

drop policy if exists comments_update on public.comments;
create policy comments_update on public.comments
  for update to authenticated
  using (public.is_admin() or user_id = auth.uid())
  with check (public.is_admin() or user_id = auth.uid());

-- التعديل مسموح على أعمدة محددة فقط (مش على صاحب المحتوى مثلًا)
grant update (caption, category) on public.videos to authenticated;
grant update (caption) on public.stories to authenticated;
grant update (body) on public.posts to authenticated;
grant update (body) on public.comments to authenticated;

-- ---------- التخزين: أي عضو مقبول يرفع في مجلداته (باسم يبدأ برقمه) ----------
drop policy if exists media_insert on storage.objects;
create policy media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and public.is_approved()
    and (
      name like 'videos/' || auth.uid()::text || '_%'
      or name like 'stories/' || auth.uid()::text || '_%'
      or name like 'posts/' || auth.uid()::text || '_%'
    )
  );
