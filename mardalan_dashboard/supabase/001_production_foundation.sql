-- Mardalan production foundation migration
-- Jalankan setelah supabase/schema.sql.
-- Tujuan: menyiapkan data model scalable untuk dashboard live tanpa query seluruh tracking_logs.

create extension if not exists postgis;

create table if not exists public.latest_locations (
  officer_id uuid primary key references public.profiles(id) on delete cascade,
  assignment_id uuid references public.assignments(id) on delete set null,
  latitude double precision not null,
  longitude double precision not null,
  location geography(point, 4326) generated always as (st_makepoint(longitude, latitude)::geography) stored,
  accuracy double precision,
  speed double precision,
  battery_level integer,
  event_type text not null default 'tracking',
  geofence_status text not null default 'unchecked',
  is_outside_sls boolean not null default false,
  warning_message text,
  recorded_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create index if not exists latest_locations_recorded_idx
  on public.latest_locations (recorded_at desc);

create index if not exists latest_locations_geofence_idx
  on public.latest_locations (geofence_status, is_outside_sls);

create index if not exists latest_locations_location_idx
  on public.latest_locations using gist (location);

create or replace function public.upsert_latest_location()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.latest_locations (
    officer_id,
    assignment_id,
    latitude,
    longitude,
    accuracy,
    speed,
    battery_level,
    event_type,
    geofence_status,
    is_outside_sls,
    warning_message,
    recorded_at,
    updated_at
  )
  values (
    new.officer_id,
    new.assignment_id,
    new.latitude,
    new.longitude,
    new.accuracy,
    new.speed,
    new.battery_level,
    new.event_type,
    new.geofence_status,
    new.is_outside_sls,
    new.warning_message,
    new.recorded_at,
    now()
  )
  on conflict (officer_id) do update set
    assignment_id = excluded.assignment_id,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    accuracy = excluded.accuracy,
    speed = excluded.speed,
    battery_level = excluded.battery_level,
    event_type = excluded.event_type,
    geofence_status = excluded.geofence_status,
    is_outside_sls = excluded.is_outside_sls,
    warning_message = excluded.warning_message,
    recorded_at = excluded.recorded_at,
    updated_at = now()
  where public.latest_locations.recorded_at <= excluded.recorded_at;

  return new;
end;
$$;

drop trigger if exists sync_latest_location_after_tracking on public.tracking_logs;

create trigger sync_latest_location_after_tracking
after insert or update of latitude, longitude, accuracy, speed, battery_level, geofence_status, is_outside_sls, warning_message, recorded_at
on public.tracking_logs
for each row
execute function public.upsert_latest_location();

create or replace view public.dashboard_live_locations as
select
  l.officer_id,
  p.officer_code,
  p.full_name as officer_name,
  p.email,
  p.phone,
  p.role,
  p.status as profile_status,
  l.assignment_id,
  a.survey_type,
  a.kecamatan,
  a.desa,
  a.sls,
  l.latitude,
  l.longitude,
  l.accuracy,
  l.speed,
  l.battery_level,
  l.event_type,
  l.geofence_status,
  l.is_outside_sls,
  l.warning_message,
  l.recorded_at,
  l.updated_at,
  case
    when l.recorded_at >= now() - interval '5 minutes' then 'online'
    when l.recorded_at >= now() - interval '30 minutes' then 'idle'
    else 'offline'
  end as online_status
from public.latest_locations l
join public.profiles p on p.id = l.officer_id
left join public.assignments a on a.id = l.assignment_id;

create or replace view public.daily_attendance_summary as
select
  date_trunc('day', coalesce(check_in_at, created_at))::date as attendance_date,
  count(*) as total_sessions,
  count(*) filter (where check_out_at is not null or status = 'complete') as complete_sessions,
  count(*) filter (where check_out_at is null and status <> 'complete') as running_sessions,
  count(distinct officer_id) as attended_officers
from public.attendance_logs
group by 1;

create or replace function public.get_dashboard_summary(target_date date default current_date)
returns table (
  approved_profiles bigint,
  online_officers bigint,
  idle_officers bigint,
  out_of_area bigint,
  fake_gps bigint,
  attended_today bigint,
  not_attended_today bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with approved as (
    select id
    from public.profiles
    where status = 'approved'
  ),
  live as (
    select officer_id, online_status, is_outside_sls
    from public.dashboard_live_locations
  ),
  attended as (
    select distinct officer_id
    from public.attendance_logs
    where date_trunc('day', coalesce(check_in_at, created_at))::date = target_date
  )
  select
    (select count(*) from approved) as approved_profiles,
    (select count(*) from live where online_status = 'online') as online_officers,
    (select count(*) from approved a where not exists (
      select 1 from live l where l.officer_id = a.id and l.online_status = 'online'
    )) as idle_officers,
    (select count(*) from live where is_outside_sls = true) as out_of_area,
    0::bigint as fake_gps,
    (select count(*) from attended) as attended_today,
    (select count(*) from approved a where not exists (
      select 1 from attended t where t.officer_id = a.id
    )) as not_attended_today;
$$;

alter table public.latest_locations enable row level security;

drop policy if exists "authenticated read latest locations" on public.latest_locations;
create policy "authenticated read latest locations"
  on public.latest_locations
  for select
  to authenticated
  using (true);

drop policy if exists "petugas read own latest location" on public.latest_locations;
create policy "petugas read own latest location"
  on public.latest_locations
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.auth_user_id = auth.uid()
        and p.id = latest_locations.officer_id
    )
  );

-- Produksi: anon tidak boleh menulis tracking/attendance.
-- Aktifkan setelah Android memakai Supabase Auth atau Edge Function server-side.
-- drop policy if exists "pilot anon insert tracking" on public.tracking_logs;
-- drop policy if exists "pilot anon read approved profiles" on public.profiles;
-- drop policy if exists "pilot anon read active assignments" on public.assignments;
