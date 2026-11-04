-- ============================================================
-- لمّتنا: إعداد قاعدة البيانات والصلاحيات (شغّله مرة واحدة)
-- Supabase  ->  SQL Editor  ->  New query  ->  الصق الملف كله  ->  Run
-- الملف آمن لو شغّلته أكتر من مرة.
-- ============================================================

-- ---------- الجداول ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'member' check (role in ('admin', 'member')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'blocked')),
  invite_used text,
  created_at timestamptz not null default now()
);

create table if not exists public.invite_codes (
  code text primary key,
  created_by uuid references public.profiles(id) on delete set null,
  used_by uuid references public.profiles(id) on delete set null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

-- الريلز (الأدمن فقط يرفع)
create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  path text not null,
  caption text not null default '',
  category text not null default 'family' check (category in ('family', 'events', 'trips', 'memories')),
  created_at timestamptz not null default now()
);

create index if not exists videos_created_idx on public.videos (created_at desc);

-- الستوري (أي عضو مقبول يرفع، وتختفي بعد 24 ساعة)
create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  path text not null,
  caption text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists stories_created_idx on public.stories (created_at desc);

create table if not exists public.video_likes (
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

alter table public.profiles enable row level security;
alter table public.invite_codes enable row level security;
alter table public.videos enable row level security;
alter table public.stories enable row level security;
alter table public.video_likes enable row level security;

-- ---------- دوال مساعدة ----------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and status = 'approved'
  );
$$;

create or replace function public.is_approved()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and status = 'approved'
  );
$$;

-- أول حساب يتسجّل = الأدمن (انت). باقي الحسابات: قيد المراجعة،
-- أو مقبولة تلقائيًا لو سجّلت بكود دعوة صحيح.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := upper(trim(coalesce(new.raw_user_meta_data ->> 'invite_code', '')));
  v_role text := 'member';
  v_status text := 'pending';
  v_name text;
  v_used text;
begin
  if not exists (select 1 from public.profiles) then
    v_role := 'admin';
    v_status := 'approved';
  end if;

  v_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    split_part(coalesce(new.email, ''), '@', 1)
  );

  insert into public.profiles (id, display_name, role, status)
  values (new.id, v_name, v_role, v_status);

  if v_status = 'pending' and v_code <> '' then
    update public.invite_codes
       set used_by = new.id, used_at = now()
     where code = v_code and used_by is null
    returning code into v_used;

    if v_used is not null then
      update public.profiles
         set status = 'approved', invite_used = v_used
       where id = new.id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- إنشاء كود دعوة (للأدمن فقط)
create or replace function public.create_invite_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if not public.is_admin() then
    raise exception 'not allowed';
  end if;
  v_code := 'FAM-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
  insert into public.invite_codes (code, created_by) values (v_code, auth.uid());
  return v_code;
end;
$$;

-- ---------- الصلاحيات (نحدد بالظبط مين يعمل إيه) ----------
revoke execute on function public.is_admin() from public, anon;
revoke execute on function public.is_approved() from public, anon;
revoke execute on function public.create_invite_code() from public, anon;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_approved() to authenticated;
grant execute on function public.create_invite_code() to authenticated;

grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.invite_codes to authenticated;
grant select, insert, delete on public.videos to authenticated;
grant select, insert, delete on public.stories to authenticated;
grant select, insert, delete on public.video_likes to authenticated;

-- ---------- قواعد الأمان (RLS) ----------
-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_approved());

drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- invite_codes (الأدمن فقط)
drop policy if exists invite_codes_select on public.invite_codes;
create policy invite_codes_select on public.invite_codes
  for select to authenticated
  using (public.is_admin());

-- videos
drop policy if exists videos_select on public.videos;
create policy videos_select on public.videos
  for select to authenticated
  using (public.is_approved());

drop policy if exists videos_insert on public.videos;
create policy videos_insert on public.videos
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_admin());

drop policy if exists videos_delete on public.videos;
create policy videos_delete on public.videos
  for delete to authenticated
  using (public.is_admin());

-- stories
drop policy if exists stories_select on public.stories;
create policy stories_select on public.stories
  for select to authenticated
  using (
    public.is_admin()
    or (public.is_approved() and created_at > now() - interval '24 hours')
  );

drop policy if exists stories_insert on public.stories;
create policy stories_insert on public.stories
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_approved());

drop policy if exists stories_delete on public.stories;
create policy stories_delete on public.stories
  for delete to authenticated
  using (public.is_admin() or user_id = auth.uid());

-- video_likes
drop policy if exists video_likes_select on public.video_likes;
create policy video_likes_select on public.video_likes
  for select to authenticated
  using (public.is_approved());

drop policy if exists video_likes_insert on public.video_likes;
create policy video_likes_insert on public.video_likes
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_approved());

drop policy if exists video_likes_delete on public.video_likes;
create policy video_likes_delete on public.video_likes
  for delete to authenticated
  using (user_id = auth.uid());

-- ---------- التخزين (خاص: الملفات مش بتتفتح بدون تسجيل دخول) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media', 'media', false, 52428800,
  array[
    'video/mp4', 'video/quicktime', 'video/webm', 'video/x-matroska', 'video/3gpp',
    'image/jpeg', 'image/png', 'image/webp', 'image/heic'
  ]
)
on conflict (id) do update
  set file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types,
      public = false;

drop policy if exists media_read on storage.objects;
create policy media_read on storage.objects
  for select to authenticated
  using (bucket_id = 'media' and public.is_approved());

drop policy if exists media_insert on storage.objects;
create policy media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and (
      (name like 'videos/%' and public.is_admin())
      or (name like 'stories/%' and public.is_approved())
    )
  );

drop policy if exists media_delete on storage.objects;
create policy media_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'media'
    and (public.is_admin() or owner_id::text = auth.uid()::text)
  );
