-- ============================================================
-- لمّتنا: إشعارات الفيديوهات الجديدة
-- شغّله بعد setup.sql و social.sql (وبعد reactions.sql لو شغّلته):
--   Supabase -> SQL Editor -> New query -> الصق الملف كله -> Run
-- الملف آمن لو شغّلته أكتر من مرة.
-- ============================================================

-- ---------- 1) توسيع قيد notifications.type ----------
-- بنحذف أي قيد check قديم على العمود type (أيًا كان اسمه) وبعدين نضيف القيد الجديد.
-- كل الأنواع القديمة بتفضل صالحة، وبنضيف نوع new_video.
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.notifications'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%type%'
  loop
    execute format('alter table public.notifications drop constraint %I', c.conname);
  end loop;
end;
$$;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'comment', 'reply', 'like', 'love', 'haha', 'wow', 'sad', 'angry',
    'new_video'
  )) not valid;

alter table public.notifications validate constraint notifications_type_check;

-- ---------- 2) ترجر إشعار الفيديو الجديد ----------
-- عند رفع فيديو جديد: بنبعت إشعار لكل الأعضاء المقبولين ما عدا اللي رفع الفيديو.
-- الوصف بيتبعت مختصر لو موجود.
create or replace function public.notify_on_new_video()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (user_id, actor_id, type, video_id, preview)
  select
    p.id,
    new.user_id,
    'new_video',
    new.id,
    left(coalesce(nullif(btrim(new.caption), ''), ''), 80)
  from public.profiles p
  where p.status = 'approved'
    and p.id <> new.user_id;

  return new;
end;
$$;

drop trigger if exists videos_notify_new_video on public.videos;
create trigger videos_notify_new_video
  after insert on public.videos
  for each row execute function public.notify_on_new_video();

revoke execute on function public.notify_on_new_video() from public, anon, authenticated;

-- ---------- ملاحظات ----------
-- الصلاحيات وقواعد RLS الحالية زي ما هي، مش بنلمسها.
-- الإشعارات القديمة (comment/reply/like/love/haha/wow/sad/angry) بتفضل شغالة عادي.
