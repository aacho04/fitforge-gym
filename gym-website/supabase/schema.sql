create table if not exists public.gym_members (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  name text not null,
  phone text not null default '',
  package text check (package in ('Basic', 'Pro', 'Elite')),
  joining_date date not null default current_date,
  membership_start date,
  membership_end date,
  age text not null default '',
  weight text not null default '',
  height text not null default '',
  goal text not null default '',
  referred_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gym_membership_dates_check
    check (
      (package is null and membership_start is null and membership_end is null)
      or (package is not null and membership_start is not null and membership_end is not null)
    )
);

-- Keep existing installations aligned with the customer fields used by the app:
-- name, phone, joining_date, and package.
alter table public.gym_members
  add column if not exists name text not null default '',
  add column if not exists phone text not null default '',
  add column if not exists package text,
  add column if not exists joining_date date not null default current_date,
  add column if not exists created_at timestamptz not null default now();

alter table public.gym_members
  add column if not exists id uuid;

update public.gym_members as members
set id = users.id
from auth.users as users
where members.id is null
  and members.email is not null
  and lower(members.email) = lower(users.email);

update public.gym_members
set id = gen_random_uuid()
where id is null;

alter table public.gym_members
  alter column id set default gen_random_uuid(),
  alter column id set not null,
  alter column email drop not null,
  drop constraint if exists gym_members_id_fkey;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.gym_members'::regclass
      and contype = 'p'
  ) then
    alter table public.gym_members
      add constraint gym_members_pkey primary key (id);
  elsif not exists (
    select 1 from pg_constraint
    where conrelid = 'public.gym_members'::regclass
      and contype = 'p'
      and conkey = array[
        (select attnum from pg_attribute
         where attrelid = 'public.gym_members'::regclass
           and attname = 'id')
      ]::smallint[]
  ) then
    raise exception 'public.gym_members has a primary key other than id; inspect before migrating';
  end if;
end;
$$;

update public.gym_members
set name = coalesce(nullif(btrim(name), ''), nullif(split_part(email, '@', 1), ''), id::text),
    phone = coalesce(phone, ''),
    joining_date = coalesce(joining_date, (created_at at time zone 'utc')::date, current_date)
where name is null or btrim(name) = '' or phone is null or joining_date is null;

alter table public.gym_members
  alter column name set default '',
  alter column name set not null,
  alter column phone set default '',
  alter column phone set not null,
  alter column joining_date set default current_date,
  alter column joining_date set not null;

comment on column public.gym_members.joining_date is 'Gym joining date shown as Joined in the admin dashboard.';
comment on column public.gym_members.package is 'Gym package assigned to the customer.';
comment on column public.gym_members.name is 'Customer name shown in member and admin views.';
comment on column public.gym_members.phone is 'Customer contact number shown in member and admin views.';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'gym_members_package_check'
      and conrelid = 'public.gym_members'::regclass
  ) then
    alter table public.gym_members
      add constraint gym_members_package_check
      check (package is null or package in ('Basic', 'Pro', 'Elite'));
  end if;
end;
$$;

create table if not exists public.gym_membership_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.gym_members (id) on delete cascade,
  package text not null check (package in ('Basic', 'Pro', 'Elite')),
  requested_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected'))
);

create index if not exists gym_membership_requests_pending_idx
  on public.gym_membership_requests (requested_at desc)
  where status = 'pending';

create unique index if not exists gym_membership_requests_one_pending_per_member_idx
  on public.gym_membership_requests (member_id)
  where status = 'pending';

alter table public.gym_members enable row level security;
alter table public.gym_membership_requests enable row level security;

revoke all on public.gym_members from anon, authenticated;
revoke all on public.gym_membership_requests from anon, authenticated;
grant select on public.gym_members to authenticated;
grant select on public.gym_membership_requests to authenticated;
grant insert (member_id, package) on public.gym_membership_requests to authenticated;

drop policy if exists "Members read own profile" on public.gym_members;
create policy "Members read own profile"
  on public.gym_members for select to authenticated
  using (id = (select auth.uid()));

drop policy if exists "Gym admins read all members" on public.gym_members;
create policy "Gym admins read all members"
  on public.gym_members for select to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

drop policy if exists "Members read own package requests" on public.gym_membership_requests;
create policy "Members read own package requests"
  on public.gym_membership_requests for select to authenticated
  using (member_id = (select auth.uid()));

drop policy if exists "Gym admins read package requests" on public.gym_membership_requests;
create policy "Gym admins read package requests"
  on public.gym_membership_requests for select to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

drop policy if exists "Members request packages" on public.gym_membership_requests;
create policy "Members request packages"
  on public.gym_membership_requests for insert to authenticated
  with check (
    member_id = (select auth.uid())
    and status = 'pending'
  );

create or replace function public.create_gym_member_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is null then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    update public.gym_members
    set email = lower(new.email),
        updated_at = now()
    where id = new.id;

    if not found then
      insert into public.gym_members (id, email, name, phone, referred_by, joining_date)
      values (
        new.id,
        lower(new.email),
        coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), split_part(new.email, '@', 1)),
        coalesce(new.raw_user_meta_data ->> 'phone', ''),
        nullif(new.raw_user_meta_data ->> 'referred_by', ''),
        coalesce((new.created_at at time zone 'utc')::date, current_date)
      );
    end if;
    return new;
  end if;

  insert into public.gym_members (id, email, name, phone, referred_by, joining_date)
  values (
    new.id,
    lower(new.email),
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    nullif(new.raw_user_meta_data ->> 'referred_by', ''),
    coalesce((new.created_at at time zone 'utc')::date, current_date)
  )
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_gym_member on auth.users;
create trigger on_auth_user_created_gym_member
  after insert or update on auth.users
  for each row execute function public.create_gym_member_from_auth();

create or replace function public.delete_gym_member_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.gym_members where id = old.id;
  return old;
end;
$$;

drop trigger if exists on_auth_user_deleted_gym_member on auth.users;
create trigger on_auth_user_deleted_gym_member
  after delete on auth.users
  for each row execute function public.delete_gym_member_from_auth();

-- Backfill users that existed before the profile trigger was installed.
insert into public.gym_members (id, email, name, phone, referred_by, joining_date)
select
  users.id,
  lower(users.email),
  coalesce(nullif(users.raw_user_meta_data ->> 'full_name', ''), split_part(users.email, '@', 1)),
  coalesce(users.raw_user_meta_data ->> 'phone', ''),
  nullif(users.raw_user_meta_data ->> 'referred_by', ''),
  coalesce((users.created_at at time zone 'utc')::date, current_date)
from auth.users as users
where users.email is not null
on conflict (id) do update
  set email = excluded.email,
      updated_at = now();

create or replace function public.admin_set_gym_package(
  target_member_id uuid,
  target_package text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.jwt() -> 'app_metadata' ->> 'role') is distinct from 'gym_admin' then
    raise exception 'Only gym admins can assign packages';
  end if;

  if target_package is not null and target_package not in ('Basic', 'Pro', 'Elite') then
    raise exception 'Invalid gym package';
  end if;

  update public.gym_members
  set package = target_package,
      membership_start = case when target_package is null then null else current_date end,
      membership_end = case when target_package is null then null else current_date + 30 end,
      updated_at = now()
  where id = target_member_id;

  if not found then
    raise exception 'Gym member not found';
  end if;
end;
$$;

create or replace function public.admin_create_gym_member(
  target_name text,
  target_phone text,
  target_joining_date date,
  target_package text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_member_id uuid;
begin
  if (select auth.jwt() -> 'app_metadata' ->> 'role') is distinct from 'gym_admin' then
    raise exception 'Only gym admins can add gym members';
  end if;

  if nullif(btrim(target_name), '') is null then
    raise exception 'Customer name is required';
  end if;

  if nullif(btrim(target_phone), '') is null then
    raise exception 'Customer phone number is required';
  end if;

  if target_joining_date is null then
    raise exception 'Gym joining date is required';
  end if;

  if target_package is not null and target_package not in ('Basic', 'Pro', 'Elite') then
    raise exception 'Invalid gym package';
  end if;

  insert into public.gym_members (
    name, phone, joining_date, package, membership_start, membership_end
  )
  values (
    btrim(target_name),
    btrim(target_phone),
    target_joining_date,
    target_package,
    case when target_package is null then null else target_joining_date end,
    case when target_package is null then null else target_joining_date + 30 end
  )
  returning id into new_member_id;

  return new_member_id;
end;
$$;

create or replace function public.admin_resolve_membership_request(
  request_id uuid,
  approve_request boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_request public.gym_membership_requests%rowtype;
begin
  if (select auth.jwt() -> 'app_metadata' ->> 'role') is distinct from 'gym_admin' then
    raise exception 'Only gym admins can resolve package requests';
  end if;

  select * into selected_request
  from public.gym_membership_requests
  where id = request_id and status = 'pending'
  for update;

  if not found then
    raise exception 'Pending package request not found';
  end if;

  if approve_request then
    update public.gym_members
    set package = selected_request.package,
        membership_start = current_date,
        membership_end = current_date + 30,
        updated_at = now()
    where id = selected_request.member_id;
    update public.gym_membership_requests set status = 'approved' where id = request_id;
  else
    update public.gym_membership_requests set status = 'rejected' where id = request_id;
  end if;
end;
$$;

create or replace function public.delete_gym_member(target_member_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.jwt() -> 'app_metadata' ->> 'role') is distinct from 'gym_admin' then
    raise exception 'Only gym admins can delete members';
  end if;

  if exists (select 1 from auth.users where id = target_member_id) then
    delete from auth.users where id = target_member_id;
  else
    delete from public.gym_members where id = target_member_id;
    if not found then
      raise exception 'Gym member not found';
    end if;
  end if;
end;
$$;

create or replace function public.set_gym_member_profile(
  target_name text,
  target_phone text,
  target_age text,
  target_weight text,
  target_height text,
  target_goal text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.gym_members
  set name = target_name,
      phone = target_phone,
      age = target_age,
      weight = target_weight,
      height = target_height,
      goal = target_goal,
      updated_at = now()
  where id = (select auth.uid());

  if not found then
    raise exception 'Gym member profile not found';
  end if;
end;
$$;

revoke all on function public.admin_set_gym_package(uuid, text) from public;
revoke all on function public.admin_create_gym_member(text, text, date, text) from public;
revoke all on function public.admin_resolve_membership_request(uuid, boolean) from public;
revoke all on function public.delete_gym_member(uuid) from public;
revoke all on function public.set_gym_member_profile(text, text, text, text, text, text) from public;

grant execute on function public.admin_set_gym_package(uuid, text) to authenticated;
grant execute on function public.admin_create_gym_member(text, text, date, text) to authenticated;
grant execute on function public.admin_resolve_membership_request(uuid, boolean) to authenticated;
grant execute on function public.delete_gym_member(uuid) to authenticated;
grant execute on function public.set_gym_member_profile(text, text, text, text, text, text) to authenticated;

-- =====================================================================
-- 1. GYM CLASSES
-- =====================================================================
create table if not exists public.gym_classes (
  id bigint primary key generated always as identity,
  title text not null,
  time text not null,
  price numeric not null default 0,
  capacity integer not null default 15,
  category text not null default 'General',
  description text not null default '',
  image_url text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Seed default gym classes if table is newly created
insert into public.gym_classes (id, title, time, price, capacity, category, description, image_url, is_active)
overriding system value
values
  (1, 'HIIT Training', 'Mon, Wed, Fri - 7:00 AM', 300, 15, 'Cardio', 'High intensity interval training to burn fat fast.', 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=500', true),
  (2, 'Yoga Flow', 'Tue, Thu - 6:00 PM', 250, 20, 'Flexibility', 'Improve flexibility and reduce stress with guided yoga.', 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=500', true),
  (3, 'Strength Training', 'Mon to Sat - 8:00 AM', 350, 12, 'Strength', 'Build muscle with free weights and resistance machines.', 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=500', true),
  (4, 'Zumba Dance', 'Wed, Sat - 5:00 PM', 250, 18, 'Dance', 'Fun cardio dance workout to upbeat music.', 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=500', true)
on conflict (id) do nothing;

-- Ensure identity sequence is advanced past the max seeded id so subsequent inserts succeed
select setval(
  pg_get_serial_sequence('public.gym_classes', 'id'),
  coalesce((select max(id) from public.gym_classes), 1)
);

alter table public.gym_classes enable row level security;
grant select on public.gym_classes to anon, authenticated;
grant insert, update, delete on public.gym_classes to authenticated;

drop policy if exists "Anyone can read active gym classes" on public.gym_classes;
create policy "Anyone can read active gym classes"
  on public.gym_classes for select to anon, authenticated
  using (true);

drop policy if exists "Gym admins can insert classes" on public.gym_classes;
create policy "Gym admins can insert classes"
  on public.gym_classes for insert to authenticated
  with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

drop policy if exists "Gym admins can update classes" on public.gym_classes;
create policy "Gym admins can update classes"
  on public.gym_classes for update to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin')
  with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

drop policy if exists "Gym admins can delete classes" on public.gym_classes;
create policy "Gym admins can delete classes"
  on public.gym_classes for delete to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

-- =====================================================================
-- 2. GYM BOOKINGS (Which member joined which class)
-- =====================================================================
create table if not exists public.gym_bookings (
  id text primary key default ('BK-' || substr(gen_random_uuid()::text, 1, 8)),
  member_id uuid references public.gym_members (id) on delete set null,
  member_email text not null,
  member_name text not null default '',
  class_id bigint references public.gym_classes (id) on delete cascade,
  class_title text not null,
  class_time text not null,
  payment_id text,
  booked_on date not null default current_date,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.gym_bookings
  alter column id set default ('BK-' || substr(gen_random_uuid()::text, 1, 8));

alter table public.gym_bookings
  add column if not exists member_name text not null default '';

update public.gym_bookings as bookings
set member_name = members.name
from public.gym_members as members
where bookings.member_name = ''
  and (
    bookings.member_id = members.id
    or lower(bookings.member_email) = lower(members.email)
  );

comment on column public.gym_bookings.member_name is 'Member name captured when the class booking was created.';

create index if not exists gym_bookings_member_email_idx on public.gym_bookings (member_email);
create index if not exists gym_bookings_class_id_idx on public.gym_bookings (class_id);

alter table public.gym_bookings enable row level security;
grant select, insert, delete on public.gym_bookings to authenticated;

drop policy if exists "Members read own bookings" on public.gym_bookings;
create policy "Members read own bookings"
  on public.gym_bookings for select to authenticated
  using (
    member_id = (select auth.uid())
    or member_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

drop policy if exists "Members insert own bookings" on public.gym_bookings;
create policy "Members insert own bookings"
  on public.gym_bookings for insert to authenticated
  with check (
    member_id = (select auth.uid())
    or member_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

drop policy if exists "Members cancel own bookings" on public.gym_bookings;
create policy "Members cancel own bookings"
  on public.gym_bookings for delete to authenticated
  using (
    member_id = (select auth.uid())
    or member_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

-- =====================================================================
-- 3. GYM TRAINER REQUESTS (1-on-1 personal session requests)
-- =====================================================================
create table if not exists public.gym_trainer_requests (
  id text primary key default ('TR-' || substr(gen_random_uuid()::text, 1, 8)),
  member_id uuid references public.gym_members (id) on delete set null,
  member_email text not null,
  trainer text not null,
  requested_date date not null,
  requested_time time not null,
  note text not null default '',
  status text not null default 'Pending' check (status in ('Pending', 'Confirmed', 'Declined')),
  created_on date not null default current_date,
  payment_id text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.gym_trainer_requests
  alter column id set default ('TR-' || substr(gen_random_uuid()::text, 1, 8));

create index if not exists gym_trainer_requests_member_email_idx on public.gym_trainer_requests (member_email);

alter table public.gym_trainer_requests enable row level security;
grant select, insert, update, delete on public.gym_trainer_requests to authenticated;

drop policy if exists "Members read own trainer requests" on public.gym_trainer_requests;
create policy "Members read own trainer requests"
  on public.gym_trainer_requests for select to authenticated
  using (
    member_id = (select auth.uid())
    or member_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

drop policy if exists "Members insert own trainer requests" on public.gym_trainer_requests;
create policy "Members insert own trainer requests"
  on public.gym_trainer_requests for insert to authenticated
  with check (
    member_id = (select auth.uid())
    or member_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

drop policy if exists "Gym admins update trainer requests" on public.gym_trainer_requests;
create policy "Gym admins update trainer requests"
  on public.gym_trainer_requests for update to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin')
  with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

drop policy if exists "Gym admins delete trainer requests" on public.gym_trainer_requests;
create policy "Gym admins delete trainer requests"
  on public.gym_trainer_requests for delete to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

-- =====================================================================
-- 4. GYM INQUIRIES (Customer questions & chat messages)
-- =====================================================================
create table if not exists public.gym_inquiries (
  id text primary key default ('INQ-' || substr(gen_random_uuid()::text, 1, 8)),
  member_id uuid references public.gym_members (id) on delete set null,
  customer_name text not null,
  customer_phone text not null default '',
  customer_email text,
  message text not null,
  inquiry_date date not null default current_date,
  status text not null default 'Open' check (status in ('Open', 'Resolved')),
  reply text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.gym_inquiries
  alter column id set default ('INQ-' || substr(gen_random_uuid()::text, 1, 8));

create index if not exists gym_inquiries_customer_email_idx on public.gym_inquiries (customer_email);

alter table public.gym_inquiries enable row level security;
grant select, insert, update, delete on public.gym_inquiries to authenticated;
grant insert on public.gym_inquiries to anon;

drop policy if exists "Anyone can submit inquiry" on public.gym_inquiries;
create policy "Anyone can submit inquiry"
  on public.gym_inquiries for insert to anon, authenticated
  with check (true);

drop policy if exists "Members and admins read inquiries" on public.gym_inquiries;
create policy "Members and admins read inquiries"
  on public.gym_inquiries for select to authenticated
  using (
    member_id = (select auth.uid())
    or customer_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

drop policy if exists "Gym admins update inquiries" on public.gym_inquiries;
create policy "Gym admins update inquiries"
  on public.gym_inquiries for update to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin')
  with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

drop policy if exists "Gym admins delete inquiries" on public.gym_inquiries;
create policy "Gym admins delete inquiries"
  on public.gym_inquiries for delete to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

-- =====================================================================
-- 5. GYM PAYMENTS
-- =====================================================================
create table if not exists public.gym_payments (
  id text primary key default ('PF' || substr(gen_random_uuid()::text, 1, 8)),
  member_id uuid references public.gym_members (id) on delete set null,
  member_email text not null,
  title text not null,
  amount numeric not null default 0,
  method text not null,
  detail text not null default '',
  status text not null default 'Pending',
  kind text not null default '',
  date date not null default current_date,
  created_at timestamptz not null default now()
);

create index if not exists gym_payments_member_email_idx on public.gym_payments (member_email);

alter table public.gym_payments enable row level security;
grant select, insert, update, delete on public.gym_payments to authenticated;

drop policy if exists "Members read own payments" on public.gym_payments;
create policy "Members read own payments"
  on public.gym_payments for select to authenticated
  using (
    member_id = (select auth.uid())
    or member_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

drop policy if exists "Members insert own payments" on public.gym_payments;
create policy "Members insert own payments"
  on public.gym_payments for insert to authenticated
  with check (
    member_id = (select auth.uid())
    or member_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

drop policy if exists "Gym admins update payments" on public.gym_payments;
create policy "Gym admins update payments"
  on public.gym_payments for update to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin')
  with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

drop policy if exists "Gym admins delete payments" on public.gym_payments;
create policy "Gym admins delete payments"
  on public.gym_payments for delete to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

-- =====================================================================
-- 6. GYM ATTENDANCE
-- =====================================================================
create table if not exists public.gym_attendance (
  id text primary key default ('ATT-' || substr(gen_random_uuid()::text, 1, 8)),
  member_id uuid references public.gym_members (id) on delete set null,
  member_name text not null default '',
  member_email text not null,
  date date not null default current_date,
  time text not null default '',
  ref text not null default 'gym',
  type text not null default 'Gym',
  label text not null default 'Gym visit',
  created_at timestamptz not null default now()
);

create index if not exists gym_attendance_member_email_idx on public.gym_attendance (member_email);
create index if not exists gym_attendance_date_idx on public.gym_attendance (date);

alter table public.gym_attendance enable row level security;
grant select, insert, delete on public.gym_attendance to authenticated;

drop policy if exists "Members read own attendance" on public.gym_attendance;
create policy "Members read own attendance"
  on public.gym_attendance for select to authenticated
  using (
    member_id = (select auth.uid())
    or member_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

drop policy if exists "Members insert own checkins" on public.gym_attendance;
create policy "Members insert own checkins"
  on public.gym_attendance for insert to authenticated
  with check (
    member_id = (select auth.uid())
    or member_email = (select auth.jwt() ->> 'email')
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin'
  );

drop policy if exists "Gym admins delete attendance" on public.gym_attendance;
create policy "Gym admins delete attendance"
  on public.gym_attendance for delete to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

-- ============================================================================
-- FITFORGE EXPANDED ENTITIES: PLANS, WORKOUTS, PROGRESS, TRAINERS & NUTRITION
-- ============================================================================

-- 7. MEMBERSHIP PLANS (Admin created & customizable)
create table if not exists public.gym_plans (
  id text primary key,
  title text not null,
  price integer not null,
  duration_months integer not null default 1,
  description text not null default '',
  perks text[] not null default '{}',
  is_featured boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.gym_plans enable row level security;
grant select on public.gym_plans to anon, authenticated;
grant all on public.gym_plans to authenticated;

drop policy if exists "Anyone can read active gym plans" on public.gym_plans;
create policy "Anyone can read active gym plans"
  on public.gym_plans for select to anon, authenticated
  using (is_active = true or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

drop policy if exists "Gym admins manage plans" on public.gym_plans;
create policy "Gym admins manage plans"
  on public.gym_plans for all to authenticated
  using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'gym_admin');

-- 8. WORKOUT LIBRARY & ROUTINES
create table if not exists public.gym_workouts (
  id text primary key,
  title text not null,
  category text not null, -- 'Strength', 'Hypertrophy', 'HIIT', 'Fat Loss', 'Endurance', 'Beginner'
  split_type text not null default 'Full Body', -- 'Push Pull Legs', 'Upper Lower', 'Full Body', 'Isolated'
  difficulty text not null default 'Intermediate', -- 'Beginner', 'Intermediate', 'Advanced'
  duration_minutes integer not null default 45,
  target_muscles text[] not null default '{}',
  exercises jsonb not null default '[]'::jsonb,
  created_by text not null default 'FitForge Team',
  created_at timestamptz not null default now()
);

alter table public.gym_workouts enable row level security;
grant select on public.gym_workouts to anon, authenticated;
grant all on public.gym_workouts to authenticated;

-- 9. MEMBER WORKOUT SESSIONS & LOGS
create table if not exists public.gym_workout_logs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references public.gym_members (id) on delete cascade,
  member_email text not null,
  workout_id text not null,
  workout_title text not null,
  duration_minutes integer not null default 0,
  total_volume_kg numeric not null default 0,
  exercise_logs jsonb not null default '[]'::jsonb,
  logged_at timestamptz not null default now()
);

create index if not exists gym_workout_logs_member_email_idx on public.gym_workout_logs (member_email);
create index if not exists gym_workout_logs_logged_at_idx on public.gym_workout_logs (logged_at desc);

alter table public.gym_workout_logs enable row level security;
grant select, insert, delete on public.gym_workout_logs to authenticated;

drop policy if exists "Members read own workout logs" on public.gym_workout_logs;
create policy "Members read own workout logs"
  on public.gym_workout_logs for select to authenticated
  using (member_email = (select auth.jwt() ->> 'email') or (select auth.jwt() -> 'app_metadata' ->> 'role') in ('gym_admin', 'trainer'));

drop policy if exists "Members insert own workout logs" on public.gym_workout_logs;
create policy "Members insert own workout logs"
  on public.gym_workout_logs for insert to authenticated
  with check (member_email = (select auth.jwt() ->> 'email'));

-- 10. BODY PROGRESS RECORDS (Measurements & Trends)
create table if not exists public.gym_progress_records (
  id uuid primary key default gen_random_uuid(),
  member_id uuid references public.gym_members (id) on delete cascade,
  member_email text not null,
  date date not null default current_date,
  weight numeric not null,
  waist_inches numeric,
  chest_inches numeric,
  hips_inches numeric,
  notes text default '',
  created_at timestamptz not null default now()
);

create index if not exists gym_progress_records_member_email_idx on public.gym_progress_records (member_email);
alter table public.gym_progress_records enable row level security;
grant select, insert, delete on public.gym_progress_records to authenticated;

drop policy if exists "Members read own progress records" on public.gym_progress_records;
create policy "Members read own progress records"
  on public.gym_progress_records for select to authenticated
  using (member_email = (select auth.jwt() ->> 'email') or (select auth.jwt() -> 'app_metadata' ->> 'role') in ('gym_admin', 'trainer'));

drop policy if exists "Members insert own progress records" on public.gym_progress_records;
create policy "Members insert own progress records"
  on public.gym_progress_records for insert to authenticated
  with check (member_email = (select auth.jwt() ->> 'email'));

-- 11. TRAINER ASSIGNED WORKOUTS
create table if not exists public.gym_trainer_assignments (
  id uuid primary key default gen_random_uuid(),
  trainer_email text not null,
  trainer_name text not null,
  member_email text not null,
  member_name text not null,
  workout_title text not null,
  notes text default '',
  status text not null default 'Active', -- 'Active', 'Completed', 'Archived'
  assigned_at timestamptz not null default now()
);

alter table public.gym_trainer_assignments enable row level security;
grant select, insert, update, delete on public.gym_trainer_assignments to authenticated;

-- Seed default initial plans if not already present
insert into public.gym_plans (id, title, price, duration_months, description, perks, is_featured)
values
  ('Basic', 'Basic Foundation', 3000, 1, 'Essential gym access with standard equipment and locker rooms.', array['Full gym floor access', 'Locker room & showers', '2 Group classes / month', 'Fitness onboarding guide'], false),
  ('Pro', 'Pro Performance', 5000, 1, 'The most popular plan for dedicated lifters and group training enthusiasts.', array['Unlimited 24/7 gym access', 'Unlimited group classes (HIIT, Yoga, Zumba)', '1 Trainer consultation / week', 'Personalized nutrition guide', 'Steam & sauna access'], true),
  ('Elite', 'Elite Transformation', 8000, 1, 'Complete all-inclusive access with dedicated trainer and diet counseling.', array['Unlimited all gym areas', 'Dedicated 1-on-1 personal trainer', 'Custom bespoke Indian diet plan', 'Weekly body composition scanning', 'All premium classes included', 'Priority booking'], false)
on conflict (id) do update
set price = excluded.price,
    description = excluded.description,
    perks = excluded.perks;
