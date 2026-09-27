# Mardalan API Contract

Dokumen ini menjadi kontrak antara Android, Admin Dashboard, dan backend Supabase.

## Prinsip Produksi

- Android tidak boleh menulis data operasional sensitif tanpa identitas user.
- Dashboard tidak membaca `tracking_logs` mentah untuk live monitoring.
- Data live dibaca dari `latest_locations` atau view `dashboard_live_locations`.
- Data historis boleh membaca `tracking_logs`, tetapi wajib pakai filter tanggal, petugas, dan limit.
- Aksi admin seperti approve pengguna, import plotting, dan reset penugasan harus lewat backend/Edge Function.

## Auth

### Login Petugas

Target produksi:

```text
POST /auth/v1/token
```

Gunakan Supabase Auth email/password atau OTP. Setelah login, Android menyimpan access token dan mengirim request sebagai user authenticated.

Mapping user:

- `auth.users.id` harus terhubung ke `profiles.auth_user_id`.
- `profiles.status` harus `approved`.
- `profiles.role` menentukan akses.

Catatan implementasi Android:

- Aplikasi membaca `SUPABASE_URL` dan `SUPABASE_ANON_KEY` dari `dart-define`.
- Jika Supabase dikonfigurasi, login memakai email/password Supabase Auth.
- Access token disimpan lokal dan dipakai sebagai bearer untuk request REST.
- Jika Supabase belum dikonfigurasi, mode demo lokal masih tersedia.

## Android Endpoints

### Ambil Profil Aktif

```text
GET /rest/v1/profiles?select=id,officer_code,full_name,role,status,kecamatan&auth_user_id=eq.{auth.uid}
```

Response utama:

```json
{
  "id": "uuid",
  "officer_code": "P001",
  "full_name": "Nama Petugas",
  "role": "petugas",
  "status": "approved",
  "kecamatan": "Kualuh Hulu"
}
```

### Ambil Assignment Aktif

```text
GET /rest/v1/assignments?select=id,survey_type,kecamatan,desa,sls,status&officer_id=eq.{profile.id}&status=eq.active
```

### Kirim Tracking

Untuk MVP authenticated REST:

```text
POST /rest/v1/tracking_logs
```

Payload:

```json
{
  "officer_id": "uuid",
  "assignment_id": "uuid",
  "latitude": 2.3274,
  "longitude": 99.8492,
  "accuracy": 12.5,
  "speed": 0,
  "battery_level": 84,
  "event_type": "tracking",
  "sync_status": "synced",
  "recorded_at": "2026-06-21T08:00:00+07:00"
}
```

Target produksi yang lebih aman:

```text
POST /functions/v1/submit-tracking
```

Edge Function memvalidasi:

- token user
- `officer_id` milik user tersebut
- assignment aktif
- interval minimum tracking
- akurasi GPS
- payload duplikat

### Check-In

```text
POST /rest/v1/attendance_logs
```

Payload:

```json
{
  "officer_id": "uuid",
  "check_in_at": "2026-06-21T08:00:00+07:00",
  "check_in_latitude": 2.3274,
  "check_in_longitude": 99.8492,
  "status": "checked_in"
}
```

### Check-Out

Untuk produksi sebaiknya melalui Edge Function:

```text
POST /functions/v1/checkout-attendance
```

Alasan: update attendance harus memastikan hanya sesi milik petugas yang sedang berjalan yang dapat ditutup.

## Dashboard Endpoints

### Live Locations

```text
GET /rest/v1/dashboard_live_locations?select=*&profile_status=eq.approved
```

Filter opsional:

- `survey_type=eq.Sensus Ekonomi 2026 UB`
- `kecamatan=eq.KUALUH HULU`
- `desa=eq.NAMA DESA`
- `online_status=eq.online`
- `is_outside_sls=eq.true`

### Dashboard Summary

```text
POST /rest/v1/rpc/get_dashboard_summary
```

Payload:

```json
{
  "target_date": "2026-06-21"
}
```

### Riwayat Jejak

```text
GET /rest/v1/tracking_logs?select=*,profiles(officer_code,full_name),assignments(survey_type,kecamatan,desa,sls)&officer_id=eq.{id}&recorded_at=gte.{start}&recorded_at=lt.{end}&order=recorded_at.asc&limit=1000
```

### Riwayat Absensi

```text
GET /rest/v1/attendance_logs?select=*,profiles(officer_code,full_name,email,kecamatan)&check_in_at=gte.{start}&check_in_at=lt.{end}&order=check_in_at.desc&limit=200
```

## Role Access

| Role | Android | Dashboard | Data Scope |
| --- | --- | --- | --- |
| `petugas` | Ya | Tidak | Data sendiri |
| `supervisor` | Opsional | Ya | Tim/wilayah supervisi |
| `admin_kabkot` | Tidak wajib | Ya | Seluruh kabupaten |

## Endpoint yang Tidak Boleh Publik Anon

- Insert `tracking_logs`
- Insert/update `attendance_logs`
- Update `profiles`
- Insert/update/delete `assignments`
- Insert `activity_logs`
- Read semua petugas tanpa role
