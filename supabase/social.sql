-- ============================================================
-- لمّتنا: المنشورات والتعليقات والتفاعلات (إعجاب/قلب) والإشعارات
-- شغّله بعد setup.sql:  SQL Editor -> New query -> الصق الملف كله -> Run
-- آمن لو شغّلته أكتر من مرة.
-- ============================================================

-- ---------- الجداول ----------
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists posts_created_idx on public.posts (created_at desc);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  video_id uuid references public.videos(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now(),
  check ((post_id is null) <> (video_id is null))
);
create index if not exists comments_post_idx on public.comments (post_id, created_at);
create index if not exists comments_video_idx on public.comments (video_id, created_at);

create table if not exists public.reactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  video_id uuid references public.videos(id) on delete cascade,
  kind text not null check (kind in ('like', 'love')),
  created_at timestamptz not null default now(),
  check ((post_id is null) <> (video_id is null))
);
create unique index if not exists reactions_user_post_uidx
  on public.reactions (user_id, post_id) where post_id is not null;
create unique index if not exists reactions_user_video_uidx
  on public.reactions (user_id, video_id) where video_id is not null;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('comment', 'reply', 'like', 'love')),
  post_id uuid references public.posts(id) on delete cascade,
  video_id uuid references public.videos(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  preview text not null default '',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);

alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.reactions enable row level security;
alter table public.notifications enable row level security;

-- ---------- ترحيل الإعجابات القديمة على الفيديوهات (تتحول لقلب) ----------
-- بنعمل الترحيل قبل إنشاء التريجرز عشان ما تتولدش إشعارات قديمة.
insert into public.reactions (user_id, video_id, kind, created_at)
select user_id, video_id, 'love', created_at from public.video_likes
on conflict do nothing;

-- ---------- تريجرز الإشعارات ----------
create or replace function public.notify_on_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  if new.post_id is not null then
    select user_id into v_owner from public.posts where id = new.post_id;
  else
    select user_id into v_owner from public.videos where id = new.video_id;
  end if;

  -- صاحب المنشور/الفيديو
  if v_owner is not null and v_owner <> new.user_id then
    insert into public.notifications (user_id, actor_id, type, post_id, video_id, comment_id, preview)
    values (v_owner, new.user_id, 'comment', new.post_id, new.video_id, new.id, left(new.body, 80));
  end if;

  -- باقي اللي علّقوا قبل كده على نفس المنشور/الفيديو
  insert into public.notifications (user_id, actor_id, type, post_id, video_id, comment_id, preview)
  select distinct c.user_id, new.user_id, 'reply', new.post_id, new.video_id, new.id, left(new.body, 80)
  from public.comments c
  where c.id <> new.id
    and c.user_id <> new.user_id
    and c.user_id is distinct from v_owner
    and (
      (new.post_id is not null and c.post_id = new.post_id)
      or (new.video_id is not null and c.video_id = new.video_id)
    );

  return new;
end;
$$;

drop trigger if exists comments_notify on public.comments;
create trigger comments_notify
  after insert on public.comments
  for each row execute function public.notify_on_comment();

create or replace function public.notify_on_reaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  if new.post_id is not null then
    select user_id into v_owner from public.posts where id = new.post_id;
  else
    select user_id into v_owner from public.videos where id = new.video_id;
  end if;

  if v_owner is null or v_owner = new.user_id then
    return new;
  end if;

  if not exists (
    select 1 from public.notifications n
    where n.user_id = v_owner
      and n.actor_id = new.user_id
      and n.type = new.kind
      and n.post_id is not distinct from new.post_id
      and n.video_id is not distinct from new.video_id
  ) then
    insert into public.notifications (user_id, actor_id, type, post_id, video_id)
    values (v_owner, new.user_id, new.kind, new.post_id, new.video_id);
  end if;

  return new;
end;
$$;

drop trigger if exists reactions_notify on public.reactions;
create trigger reactions_notify
  after insert or update of kind on public.reactions
  for each row execute function public.notify_on_reaction();

revoke execute on function public.notify_on_comment() from public, anon, authenticated;
revoke execute on function public.notify_on_reaction() from public, anon, authenticated;

-- ---------- الصلاحيات ----------
grant select, insert, delete on public.posts to authenticated;
grant select, insert, delete on public.comments to authenticated;
grant select, insert, update, delete on public.reactions to authenticated;
grant select, delete on public.notifications to authenticated;
grant update (is_read) on public.notifications to authenticated;

-- ---------- قواعد الأمان (RLS) ----------
-- posts
drop policy if exists posts_select on public.posts;
create policy posts_select on public.posts
  for select to authenticated using (public.is_approved());

drop policy if exists posts_insert on public.posts;
create policy posts_insert on public.posts
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_approved());

drop policy if exists posts_delete on public.posts;
create policy posts_delete on public.posts
  for delete to authenticated
  using (public.is_admin() or user_id = auth.uid());

-- comments
drop policy if exists comments_select on public.comments;
create policy comments_select on public.comments
  for select to authenticated using (public.is_approved());

drop policy if exists comments_insert on public.comments;
create policy comments_insert on public.comments
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_approved());

drop policy if exists comments_delete on public.comments;
create policy comments_delete on public.comments
  for delete to authenticated
  using (public.is_admin() or user_id = auth.uid());

-- reactions
drop policy if exists reactions_select on public.reactions;
create policy reactions_select on public.reactions
  for select to authenticated using (public.is_approved());

drop policy if exists reactions_insert on public.reactions;
create policy reactions_insert on public.reactions
  for insert to authenticated
  with check (user_id = auth.uid() and public.is_approved());

drop policy if exists reactions_update on public.reactions;
create policy reactions_update on public.reactions
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists reactions_delete on public.reactions;
create policy reactions_delete on public.reactions
  for delete to authenticated using (user_id = auth.uid());

-- notifications (كل واحد يشوف إشعاراته هو بس)
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
  for select to authenticated using (user_id = auth.uid());

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists notifications_delete on public.notifications;
create policy notifications_delete on public.notifications
  for delete to authenticated using (user_id = auth.uid());
