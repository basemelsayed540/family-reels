-- ============================================================
-- لمّتنا: أقسام قابلة للإضافة والتعديل + قوائم الحفظ
-- شغّله: SQL Editor -> New query -> الصق الملف كله -> Run
-- آمن لو شغّلته أكتر من مرة.
-- ============================================================

-- ---------- الأقسام ----------
create table if not exists public.sections (
  key text primary key,
  title text not null check (char_length(title) between 1 and 40),
  icon int not null default 0,
  color int not null default 0,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

insert into public.sections (key, title, icon, color, created_at) values
  ('family',   'لمّة العيلة', 0, 0, '2020-01-01 00:00:01+00'),
  ('events',   'مناسبات',     1, 1, '2020-01-01 00:00:02+00'),
  ('trips',    'رحلات',       2, 2, '2020-01-01 00:00:03+00'),
  ('memories', 'ذكريات',      3, 3, '2020-01-01 00:00:04+00')
on conflict (key) do nothing;

-- نفك قيد الأقسام الثابتة القديم على videos.category
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.videos'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%category%'
  loop
    execute format('alter table public.videos drop constraint %I', c.conname);
  end loop;
end;
$$;

alter table public.sections enable row level security;

grant select, insert, update, delete on public.sections to authenticated;

drop policy if exists sections_select on public.sections;
create policy sections_select on public.sections
  for select to authenticated using (public.is_approved());

drop policy if exists sections_insert on public.sections;
create policy sections_insert on public.sections
  for insert to authenticated
  with check (public.is_approved() and created_by = auth.uid());

drop policy if exists sections_update on public.sections;
create policy sections_update on public.sections
  for update to authenticated
  using (public.is_admin() or created_by = auth.uid())
  with check (public.is_admin() or created_by = auth.uid());

drop policy if exists sections_delete on public.sections;
create policy sections_delete on public.sections
  for delete to authenticated
  using (key <> 'family' and (public.is_admin() or created_by = auth.uid()));

-- عند حذف قسم، فيديوهاته تنتقل لقسم "لمّة العيلة"
create or replace function public.on_section_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.videos set category = 'family' where category = old.key;
  return old;
end;
$$;

revoke execute on function public.on_section_delete() from public, anon, authenticated;

drop trigger if exists sections_before_delete on public.sections;
create trigger sections_before_delete
  before delete on public.sections
  for each row execute function public.on_section_delete();

-- ---------- قوائم الحفظ (خاصة بكل مستخدم) ----------
create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  created_at timestamptz not null default now()
);

create table if not exists public.saved_items (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  video_id uuid references public.videos(id) on delete cascade,
  created_at timestamptz not null default now(),
  check ((post_id is null) <> (video_id is null))
);

create unique index if not exists saved_items_post_uq
  on public.saved_items (collection_id, post_id) where post_id is not null;
create unique index if not exists saved_items_video_uq
  on public.saved_items (collection_id, video_id) where video_id is not null;
create index if not exists saved_items_user_idx on public.saved_items (user_id);

alter table public.collections enable row level security;
alter table public.saved_items enable row level security;

grant select, insert, update, delete on public.collections to authenticated;
grant select, insert, delete on public.saved_items to authenticated;

drop policy if exists collections_all on public.collections;
create policy collections_all on public.collections
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_approved());

drop policy if exists saved_items_all on public.saved_items;
create policy saved_items_all on public.saved_items
  for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and public.is_approved()
    and exists (
      select 1 from public.collections c
      where c.id = collection_id and c.user_id = auth.uid()
    )
  );
