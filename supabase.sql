-- Run in Supabase SQL Editor after creating a project. Creates the Roomi data model,
-- row-level security, profile-photo storage, and event notifications.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'Roomi',
  age int check (age is null or age between 18 and 100),
  city text,
  college text,
  bio text check (bio is null or char_length(bio) <= 350),
  habits text[] not null default '{}',
  budget int check (budget is null or budget >= 0),
  move_in date,
  avatar text,
  role text not null default 'user' check (role in ('user','admin')),
  is_suspended boolean not null default false,
  created_at timestamptz not null default now()
);

-- Contact information is kept apart from discoverable profiles.
create table if not exists public.profile_contacts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  phone text,
  instagram text
);

create table if not exists public.likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  liked_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, liked_user_id),
  check (user_id <> liked_user_id)
);
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.is_roomi_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin') $$;

create or replace function public.create_roomi_profile()
returns trigger language plpgsql security definer set search_path=public
as $$ begin
  insert into public.profiles(id,name) values(new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1))) on conflict(id) do nothing;
  return new;
end $$;
drop trigger if exists roomi_auth_user_created on auth.users;
create trigger roomi_auth_user_created after insert on auth.users for each row execute procedure public.create_roomi_profile();

create or replace function public.notify_roomi_like()
returns trigger language plpgsql security definer set search_path=public
as $$ declare liker text; begin
  select name into liker from public.profiles where id=new.user_id;
  insert into public.notifications(user_id,text) values(new.liked_user_id,coalesce(liker,'Someone')||' liked your profile. Say hello!'); return new;
end $$;
drop trigger if exists roomi_like_notification on public.likes;
create trigger roomi_like_notification after insert on public.likes for each row execute procedure public.notify_roomi_like();

create or replace function public.notify_roomi_message()
returns trigger language plpgsql security definer set search_path=public
as $$ declare sender text; begin
  select name into sender from public.profiles where id=new.sender_id;
  insert into public.notifications(user_id,text) values(new.receiver_id,coalesce(sender,'Someone')||' sent you a message.'); return new;
end $$;
drop trigger if exists roomi_message_notification on public.messages;
create trigger roomi_message_notification after insert on public.messages for each row execute procedure public.notify_roomi_message();

alter table public.profiles enable row level security;
alter table public.likes enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.profile_contacts enable row level security;
drop policy if exists "Contacts visible to owner or mutual match" on public.profile_contacts;
create policy "Contacts visible to owner or mutual match" on public.profile_contacts for select to authenticated using (
  user_id=auth.uid() or public.is_roomi_admin() or exists(
    select 1 from public.likes a join public.likes b on b.user_id=profile_contacts.user_id and b.liked_user_id=a.user_id
    where a.user_id=auth.uid() and a.liked_user_id=profile_contacts.user_id
  )
);
drop policy if exists "Members manage own contacts" on public.profile_contacts;
create policy "Members manage own contacts" on public.profile_contacts for all to authenticated using (user_id=auth.uid() or public.is_roomi_admin()) with check (user_id=auth.uid() or public.is_roomi_admin());
drop policy if exists "Roomi profiles visible to members" on public.profiles;
create policy "Roomi profiles visible to members" on public.profiles for select to authenticated using (is_suspended=false or id=auth.uid() or public.is_roomi_admin());
drop policy if exists "Members create own profile" on public.profiles;
create policy "Members create own profile" on public.profiles for insert to authenticated with check (id=auth.uid() and role='user');
drop policy if exists "Members edit own profile or admins manage" on public.profiles;
create policy "Members edit own profile or admins manage" on public.profiles for update to authenticated using (id=auth.uid() or public.is_roomi_admin()) with check ((id=auth.uid() and role=(select p.role from public.profiles p where p.id=auth.uid())) or public.is_roomi_admin());
drop policy if exists "Members manage own likes" on public.likes;
drop policy if exists "Members see mutual like signals" on public.likes;
create policy "Members see mutual like signals" on public.likes for select to authenticated using (user_id=auth.uid() or liked_user_id=auth.uid() or public.is_roomi_admin());
create policy "Members manage own likes" on public.likes for all to authenticated using (user_id=auth.uid() or public.is_roomi_admin()) with check ((user_id=auth.uid() and not exists(select 1 from public.profiles where id=auth.uid() and is_suspended)) or public.is_roomi_admin());
drop policy if exists "Conversation participants read messages" on public.messages;
create policy "Conversation participants read messages" on public.messages for select to authenticated using (sender_id=auth.uid() or receiver_id=auth.uid() or public.is_roomi_admin());
drop policy if exists "Members send messages as themselves" on public.messages;
create policy "Members send messages as themselves" on public.messages for insert to authenticated with check (sender_id=auth.uid() and sender_id<>receiver_id and not exists(select 1 from public.profiles where id=sender_id and is_suspended));
drop policy if exists "Members read own notifications" on public.notifications;
create policy "Members read own notifications" on public.notifications for select to authenticated using (user_id=auth.uid() or public.is_roomi_admin());
drop policy if exists "Members update own notifications" on public.notifications;
create policy "Members update own notifications" on public.notifications for update to authenticated using (user_id=auth.uid() or public.is_roomi_admin()) with check (user_id=auth.uid() or public.is_roomi_admin());

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.profile_contacts to authenticated;
grant select, insert, delete on public.likes to authenticated;
grant select, insert on public.messages to authenticated;
grant select, update on public.notifications to authenticated;
grant execute on function public.is_roomi_admin() to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-photos','profile-photos',true,4194304,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=4194304;
drop policy if exists "Profile photos public read" on storage.objects;
create policy "Profile photos public read" on storage.objects for select using(bucket_id='profile-photos');
drop policy if exists "Members upload own photo" on storage.objects;
create policy "Members upload own photo" on storage.objects for insert to authenticated with check(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Members replace own photo" on storage.objects;
create policy "Members replace own photo" on storage.objects for update to authenticated using(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text) with check(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text);

-- Promote an admin after signing up with their own email:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='your-admin-email@example.com');
