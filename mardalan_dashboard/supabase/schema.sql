-- mardalan Supabase schema
-- Scope: BPS Kabupaten Labuhanbatu Utara

create extension if not exists "uuid-ossp";
create extension if not exists postgis;

create type public.profile_status as enum ('pending', 'approved', 'rejected', 'inactive');
create type public.user_role as enum ('admin_kabkot', 'supervisor', 'petugas');
create type public.assignment_status as enum ('active', 'inactive', 'completed');
create type public.attendance_status as enum ('checked_in', 'complete', 'late', 'outside_area');

create table public.profiles (
  id uuid primary key default uuid_generate_v4(),
  auth_user_id uuid references auth.users(id) on delete set null,
  officer_code text unique not null,
  full_name text not null,
  email text unique not null,
  phone text,
  role public.user_role not null default 'petugas',
  status public.profile_status not null default 'pending',
  kecamatan text,
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.master_regions (
  id uuid primary key default uuid_generate_v4(),
  kecamatan text not null,
  desa text not null,
  sls text not null,
  source_code text,
  polygon_geojson jsonb,
  geom geometry(MultiPolygon, 4326),
  created_at timestamptz not null default now(),
  unique (kecamatan, desa, sls)
);

create table public.assignments (
  id uuid primary key default uuid_generate_v4(),
  survey_type text not null,
  officer_id uuid not null references public.profiles(id) on delete cascade,
  kecamatan text not null,
  desa text not null,
  sls text not null,
  status public.assignment_status not null default 'active',
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.tracking_logs (
  id uuid primary key default uuid_generate_v4(),
  officer_id uuid not null references public.profiles(id) on delete cascade,
  assignment_id uuid references public.assignments(id) on delete set null,
  latitude double precision not null,
  longitude double precision not null,
  location geography(point, 4326) generated always as (st_makepoint(longitude, latitude)::geography) stored,
  accuracy double precision,
  speed double precision,
  battery_level integer,
  event_type text not null default 'tracking',
  sync_status text not null default 'synced',
  geofence_status text not null default 'unchecked',
  is_outside_sls boolean not null default false,
  warning_message text,
  recorded_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table public.attendance_logs (
  id uuid primary key default uuid_generate_v4(),
  officer_id uuid not null references public.profiles(id) on delete cascade,
  check_in_at timestamptz not null,
  check_out_at timestamptz,
  check_in_latitude double precision,
  check_in_longitude double precision,
  check_out_latitude double precision,
  check_out_longitude double precision,
  status public.attendance_status not null default 'checked_in',
  created_at timestamptz not null default now()
);

create table public.target_points (
  id uuid primary key default uuid_generate_v4(),
  target_code text unique not null,
  label text not null,
  survey_type text not null,
  kecamatan text not null,
  desa text not null,
  sls text not null,
  latitude double precision,
  longitude double precision,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table public.activity_logs (
  id uuid primary key default uuid_generate_v4(),
  actor_id uuid references public.profiles(id) on delete set null,
  actor_name text,
  module text not null,
  action text not null,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create table public.system_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

create index tracking_logs_officer_recorded_idx on public.tracking_logs (officer_id, recorded_at desc);
create index tracking_logs_assignment_idx on public.tracking_logs (assignment_id);
create index attendance_logs_officer_idx on public.attendance_logs (officer_id, check_in_at desc);
create index assignments_officer_idx on public.assignments (officer_id, status);
create index master_regions_geom_idx on public.master_regions using gist (geom);

create or replace function public.evaluate_tracking_geofence()
returns trigger
language plpgsql
as $$
declare
  assigned_region record;
  current_point geometry(Point, 4326);
begin
  current_point := st_setsrid(st_makepoint(new.longitude, new.latitude), 4326);

  select r.id, r.geom
    into assigned_region
  from public.assignments a
  join public.master_regions r
    on lower(r.kecamatan) = lower(a.kecamatan)
   and lower(r.desa) = lower(a.desa)
   and lower(r.sls) = lower(a.sls)
  where a.id = new.assignment_id
    and a.officer_id = new.officer_id
    and a.status = 'active'
  limit 1;

  if assigned_region.id is null or assigned_region.geom is null then
    new.geofence_status := 'unchecked';
    new.is_outside_sls := false;
    new.warning_message := null;
    return new;
  end if;

  if st_covers(assigned_region.geom, current_point) then
    new.geofence_status := 'inside_sls';
    new.is_outside_sls := false;
    new.warning_message := null;
  else
    new.geofence_status := 'outside_sls';
    new.is_outside_sls := true;
    new.warning_message := 'Petugas berada di luar SLS tugas';
  end if;

  return new;
end;
$$;

create trigger set_tracking_geofence_status
before insert or update of latitude, longitude, assignment_id, officer_id
on public.tracking_logs
for each row
execute function public.evaluate_tracking_geofence();

alter table public.profiles enable row level security;
alter table public.master_regions enable row level security;
alter table public.assignments enable row level security;
alter table public.tracking_logs enable row level security;
alter table public.attendance_logs enable row level security;
alter table public.target_points enable row level security;
alter table public.activity_logs enable row level security;
alter table public.system_settings enable row level security;

-- Development policies. Tighten these before public production launch.
create policy "authenticated read profiles" on public.profiles for select to authenticated using (true);
create policy "authenticated read regions" on public.master_regions for select to authenticated using (true);
create policy "authenticated read assignments" on public.assignments for select to authenticated using (true);
create policy "authenticated read tracking" on public.tracking_logs for select to authenticated using (true);
create policy "authenticated read attendance" on public.attendance_logs for select to authenticated using (true);
create policy "authenticated read targets" on public.target_points for select to authenticated using (true);
create policy "authenticated read logs" on public.activity_logs for select to authenticated using (true);
create policy "authenticated read settings" on public.system_settings for select to authenticated using (true);

-- Pilot Android REST sync policies. Replace with per-user Supabase Auth before public production.
create policy "pilot anon read approved profiles" on public.profiles
  for select to anon
  using (status = 'approved');

create policy "pilot anon read active assignments" on public.assignments
  for select to anon
  using (status = 'active');

create policy "pilot anon insert tracking" on public.tracking_logs
  for insert to anon
  with check (
    exists (
      select 1
      from public.profiles p
      join public.assignments a on a.officer_id = p.id
      where p.id = tracking_logs.officer_id
        and a.id = tracking_logs.assignment_id
        and p.status = 'approved'
        and a.status = 'active'
    )
  );

create policy "petugas insert own tracking" on public.tracking_logs
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.profiles p
      where p.auth_user_id = auth.uid()
        and p.id = officer_id
        and p.status = 'approved'
    )
  );

create policy "petugas insert own attendance" on public.attendance_logs
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.profiles p
      where p.auth_user_id = auth.uid()
        and p.id = officer_id
        and p.status = 'approved'
    )
  );

insert into public.system_settings (key, value)
values
  ('tracking_interval_seconds', '45'),
  ('max_gps_accuracy_meter', '30'),
  ('kabupaten_scope', '"Labuhanbatu Utara"')
on conflict (key) do nothing;
