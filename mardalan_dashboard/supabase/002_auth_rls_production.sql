-- Mardalan production RLS migration
-- Prasyarat:
-- 1. Semua user Android/Dashboard sudah dibuat di Supabase Auth.
-- 2. profiles.auth_user_id sudah terhubung ke auth.users.id.
-- 3. Admin dashboard memakai login Supabase Auth, bukan login lokal dummy.
--
-- Setelah migration ini dijalankan, anon tidak boleh lagi insert tracking.

create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.profiles
  where auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.profiles
  where auth_user_id = auth.uid()
    and status = 'approved'
  limit 1;
$$;

create or replace function public.current_user_kecamatan()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select kecamatan
  from public.profiles
  where auth_user_id = auth.uid()
    and status = 'approved'
  limit 1;
$$;

create or replace function public.is_admin_kabkot()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'admin_kabkot', false);
$$;

create or replace function public.is_supervisor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'supervisor', false);
$$;

create or replace function public.is_petugas()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'petugas', false);
$$;

-- Remove development/pilot policies.
drop policy if exists "authenticated read profiles" on public.profiles;
drop policy if exists "authenticated read regions" on public.master_regions;
drop policy if exists "authenticated read assignments" on public.assignments;
drop policy if exists "authenticated read tracking" on public.tracking_logs;
drop policy if exists "authenticated read attendance" on public.attendance_logs;
drop policy if exists "authenticated read targets" on public.target_points;
drop policy if exists "authenticated read logs" on public.activity_logs;
drop policy if exists "authenticated read settings" on public.system_settings;
drop policy if exists "authenticated read latest locations" on public.latest_locations;
drop policy if exists "petugas read own latest location" on public.latest_locations;

drop policy if exists "pilot anon read approved profiles" on public.profiles;
drop policy if exists "pilot anon read active assignments" on public.assignments;
drop policy if exists "pilot anon insert tracking" on public.tracking_logs;

drop policy if exists "profiles select by role" on public.profiles;
create policy "profiles select by role"
  on public.profiles
  for select
  to authenticated
  using (
    public.is_admin_kabkot()
    or auth_user_id = auth.uid()
    or (
      public.is_supervisor()
      and kecamatan = public.current_user_kecamatan()
    )
  );

drop policy if exists "profiles admin update" on public.profiles;
create policy "profiles admin update"
  on public.profiles
  for update
  to authenticated
  using (public.is_admin_kabkot())
  with check (public.is_admin_kabkot());

drop policy if exists "regions select authenticated" on public.master_regions;
create policy "regions select authenticated"
  on public.master_regions
  for select
  to authenticated
  using (true);

drop policy if exists "assignments select by role" on public.assignments;
create policy "assignments select by role"
  on public.assignments
  for select
  to authenticated
  using (
    public.is_admin_kabkot()
    or officer_id = public.current_profile_id()
    or (
      public.is_supervisor()
      and kecamatan = public.current_user_kecamatan()
    )
  );

drop policy if exists "assignments admin write" on public.assignments;
create policy "assignments admin write"
  on public.assignments
  for all
  to authenticated
  using (public.is_admin_kabkot())
  with check (public.is_admin_kabkot());

drop policy if exists "tracking select by role" on public.tracking_logs;
create policy "tracking select by role"
  on public.tracking_logs
  for select
  to authenticated
  using (
    public.is_admin_kabkot()
    or officer_id = public.current_profile_id()
    or exists (
      select 1
      from public.assignments a
      where a.id = tracking_logs.assignment_id
        and public.is_supervisor()
        and a.kecamatan = public.current_user_kecamatan()
    )
  );

drop policy if exists "petugas insert own tracking" on public.tracking_logs;
create policy "petugas insert own tracking"
  on public.tracking_logs
  for insert
  to authenticated
  with check (
    officer_id = public.current_profile_id()
    and exists (
      select 1
      from public.assignments a
      where a.id = assignment_id
        and a.officer_id = officer_id
        and a.status = 'active'
    )
  );

drop policy if exists "attendance select by role" on public.attendance_logs;
create policy "attendance select by role"
  on public.attendance_logs
  for select
  to authenticated
  using (
    public.is_admin_kabkot()
    or officer_id = public.current_profile_id()
    or exists (
      select 1
      from public.profiles p
      where p.id = attendance_logs.officer_id
        and public.is_supervisor()
        and p.kecamatan = public.current_user_kecamatan()
    )
  );

drop policy if exists "petugas insert own attendance" on public.attendance_logs;
create policy "petugas insert own attendance"
  on public.attendance_logs
  for insert
  to authenticated
  with check (officer_id = public.current_profile_id());

drop policy if exists "petugas update own running attendance" on public.attendance_logs;
create policy "petugas update own running attendance"
  on public.attendance_logs
  for update
  to authenticated
  using (
    officer_id = public.current_profile_id()
    and check_out_at is null
  )
  with check (officer_id = public.current_profile_id());

drop policy if exists "targets select authenticated" on public.target_points;
create policy "targets select authenticated"
  on public.target_points
  for select
  to authenticated
  using (true);

drop policy if exists "targets admin write" on public.target_points;
create policy "targets admin write"
  on public.target_points
  for all
  to authenticated
  using (public.is_admin_kabkot())
  with check (public.is_admin_kabkot());

drop policy if exists "activity select admin" on public.activity_logs;
create policy "activity select admin"
  on public.activity_logs
  for select
  to authenticated
  using (public.is_admin_kabkot());

drop policy if exists "activity insert authenticated" on public.activity_logs;
create policy "activity insert authenticated"
  on public.activity_logs
  for insert
  to authenticated
  with check (actor_id = public.current_profile_id() or public.is_admin_kabkot());

drop policy if exists "settings select authenticated" on public.system_settings;
create policy "settings select authenticated"
  on public.system_settings
  for select
  to authenticated
  using (true);

drop policy if exists "settings admin write" on public.system_settings;
create policy "settings admin write"
  on public.system_settings
  for all
  to authenticated
  using (public.is_admin_kabkot())
  with check (public.is_admin_kabkot());

drop policy if exists "latest locations select by role" on public.latest_locations;
create policy "latest locations select by role"
  on public.latest_locations
  for select
  to authenticated
  using (
    public.is_admin_kabkot()
    or officer_id = public.current_profile_id()
    or exists (
      select 1
      from public.assignments a
      where a.id = latest_locations.assignment_id
        and public.is_supervisor()
        and a.kecamatan = public.current_user_kecamatan()
    )
  );
