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
) values (
  'c3ff4d1b-3a35-46aa-bd52-bda52e2bbbe4',
  'ADMIN-BPS',
  'Admin BPS',
  'admin@bps.go.id',
  null,
  'admin_kabkot',
  'approved',
  'Labuhanbatu Utara',
  now()
)
on conflict (email) do update set
  auth_user_id = excluded.auth_user_id,
  officer_code = excluded.officer_code,
  full_name = excluded.full_name,
  role = excluded.role,
  status = excluded.status,
  kecamatan = excluded.kecamatan,
  approved_at = coalesce(public.profiles.approved_at, now()),
  updated_at = now();
