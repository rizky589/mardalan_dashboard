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

create or replace function public.is_admin_kabkot()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'admin_kabkot', false);
$$;

insert into public.profiles (
  auth_user_id,
  officer_code,
  full_name,
  email,
  phone,
  role,
  status,
  kecamatan,
  approved_at
)
select
  id,
  'ADMIN-BPS',
  'Admin BPS',
  'admin@bps.go.id',
  null,
  'admin_kabkot',
  'approved',
  'Labuhanbatu Utara',
  now()
from auth.users
where email = 'admin@bps.go.id'
on conflict (email) do update set
  auth_user_id = excluded.auth_user_id,
  officer_code = excluded.officer_code,
  full_name = excluded.full_name,
  role = excluded.role,
  status = excluded.status,
  kecamatan = excluded.kecamatan,
  approved_at = coalesce(public.profiles.approved_at, now()),
  updated_at = now();

drop policy if exists "profiles admin insert" on public.profiles;
create policy "profiles admin insert"
  on public.profiles
  for insert
  to authenticated
  with check (public.is_admin_kabkot());

drop policy if exists "profiles admin delete" on public.profiles;
create policy "profiles admin delete"
  on public.profiles
  for delete
  to authenticated
  using (public.is_admin_kabkot());
