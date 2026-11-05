-- ============================================================
-- لمّتنا: الريأكشنز الستة (إعجاب/حب/ضحك/دهشة/حزن/غضب)
-- شغّله بعد setup.sql و social.sql (وبعد members.sql لو شغّلته):
--   Supabase -> SQL Editor -> New query -> الصق الملف كله -> Run
-- الملف آمن لو شغّلته أكتر من مرة.
-- ============================================================

-- ---------- 1) توسيع قيد reactions.kind ----------
-- بنحذف أي قيد check قديم على العمود kind (أيًا كان اسمه) وبعدين نضيف القيد الجديد.
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.reactions'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%kind%'
  loop
    execute format('alter table public.reactions drop constraint %I', c.conname);
  end loop;
end;
$$;

alter table public.reactions
  add constraint reactions_kind_check
  check (kind in ('like', 'love', 'haha', 'wow', 'sad', 'angry')) not valid;

alter table public.reactions validate constraint reactions_kind_check;

-- ---------- 2) توسيع قيد notifications.type ----------
-- comment و reply بيفضلوا زي ما هما، وبنضيف الأنواع الأربعة الجديدة.
-- إشعارات like و love القديمة بتفضل صالحة وشغالة عادي.
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
    'comment', 'reply', 'like', 'love', 'haha', 'wow', 'sad', 'angry'
  )) not valid;

alter table public.notifications validate constraint notifications_type_check;

-- ---------- 3) ترجر الإشعارات ----------
-- عند أول ريأكشن: بنعمل إشعار نوعه = نوع الريأكشن.
-- عند تغيير الريأكشن: بنحدّث نفس الإشعار بدل ما نعمل إشعار جديد مكرر.
-- لو فيه إشعارات قديمة مكررة لنفس الشخص على نفس الهدف، بنسيب الأحدث ونحذف الباقي.
create or replace function public.notify_on_reaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_notif_id uuid;
begin
  -- تحديث من غير تغيير فعلي في نوع الريأكشن: مفيش داعي لإشعار جديد.
  if tg_op = 'UPDATE' then
    if new.kind is not distinct from old.kind then
      return new;
    end if;
  end if;

  if new.post_id is not null then
    select user_id into v_owner from public.posts where id = new.post_id;
  else
    select user_id into v_owner from public.videos where id = new.video_id;
  end if;

  -- صاحب المنشور/الفيديو بس هو اللي بيوصله إشعار، ومش بيتبعت لنفسه.
  if v_owner is null or v_owner = new.user_id then
    return new;
  end if;

  update public.notifications n
     set type = new.kind,
         is_read = false,
         created_at = now()
   where n.id = (
     select n2.id
     from public.notifications n2
     where n2.user_id = v_owner
       and n2.actor_id = new.user_id
       and n2.type in ('like', 'love', 'haha', 'wow', 'sad', 'angry')
       and n2.post_id is not distinct from new.post_id
       and n2.video_id is not distinct from new.video_id
     order by n2.created_at desc
     limit 1
   )
  returning n.id into v_notif_id;

  if v_notif_id is null then
    insert into public.notifications (user_id, actor_id, type, post_id, video_id)
    values (v_owner, new.user_id, new.kind, new.post_id, new.video_id);
  else
    -- تنظيف أي إشعارات ريأكشن قديمة مكررة لنفس الشخص على نفس الهدف.
    delete from public.notifications n
     where n.user_id = v_owner
       and n.actor_id = new.user_id
       and n.type in ('like', 'love', 'haha', 'wow', 'sad', 'angry')
       and n.post_id is not distinct from new.post_id
       and n.video_id is not distinct from new.video_id
       and n.id <> v_notif_id;
  end if;

  return new;
end;
$$;

drop trigger if exists reactions_notify on public.reactions;
create trigger reactions_notify
  after insert or update of kind on public.reactions
  for each row execute function public.notify_on_reaction();

revoke execute on function public.notify_on_reaction() from public, anon, authenticated;

-- ---------- ملاحظات ----------
-- الصلاحيات وقواعد RLS الحالية زي ما هي، مش بنلمسها.
-- التطبيق بيحدّث عمود kind فقط عند تغيير الريأكشن (مش user_id ولا الهدف).
-- الـ grants الحالية على جدول reactions بتسمح بالتحديث، والـ RLS بتقيده لصاحب الريأكشن.
