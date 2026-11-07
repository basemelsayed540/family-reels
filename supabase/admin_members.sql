-- ============================================================
-- لمّتنا: المدير يحذف الأعضاء (التعديل شغّال أصلًا من setup.sql)
-- شغّله: SQL Editor -> New query -> الصق الملف كله -> Run
-- آمن لو شغّلته أكتر من مرة.
-- ============================================================

create or replace function public.admin_delete_member(target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'غير مسموح';
  end if;
  if target = auth.uid() then
    raise exception 'لا يمكنك حذف حسابك';
  end if;
  if exists (select 1 from public.profiles where id = target and role = 'admin') then
    raise exception 'لا يمكن حذف مدير. اجعله عضوًا أولًا';
  end if;
  -- حذف المستخدم يحذف بروفايله ومحتواه (فيديوهات/ستوري/منشورات/تعليقات/ريأكشنز) بالتتابع
  delete from auth.users where id = target;
end;
$$;

revoke execute on function public.admin_delete_member(uuid) from public, anon;
grant execute on function public.admin_delete_member(uuid) to authenticated;
