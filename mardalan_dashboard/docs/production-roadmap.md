# Production Roadmap Mardalan

## Status Saat Ini

Layak untuk MVP internal/pilot terbatas, belum layak produksi besar.

Yang sudah ada:

- Flutter Android dengan GPS tracking, offline storage, dan sync.
- Admin Dashboard Next.js.
- Supabase schema dengan PostGIS, RLS dasar, trigger geofence.
- Template import pengguna dan plotting.

Yang masih kurang untuk produksi:

- Android masih memakai anon key sebagai bearer untuk REST sync.
- Dashboard masih membaca beberapa tabel mentah langsung dari client.
- RLS masih terlalu longgar untuk role produksi.
- Belum ada Edge Function untuk aksi sensitif.
- Belum ada observability, backup, dan runbook incident.

## Tahap 1 - Fondasi Data dan API

Target:

- Tambah `latest_locations`.
- Tambah view `dashboard_live_locations`.
- Tambah summary RPC `get_dashboard_summary`.
- Dokumentasikan kontrak API Android/Dashboard.
- Siapkan policy produksi dan matikan anon write setelah Android Auth siap.

File:

- `supabase/001_production_foundation.sql`
- `docs/api-contract.md`

## Tahap 2 - Auth dan RLS Produksi

Target:

- Android login via Supabase Auth.
- `profiles.auth_user_id` wajib terisi.
- Hapus policy pilot anon.
- Policy select/insert/update dibuat per role.

File:

- `supabase/002_auth_rls_production.sql`
- `lib/services/supabase_auth_service.dart`

Prioritas policy:

- Petugas hanya bisa insert tracking dirinya.
- Petugas hanya bisa melihat profil/assignment dirinya.
- Supervisor hanya bisa melihat petugas di tim/wilayahnya.
- Admin kabupaten bisa mengelola seluruh data kabupaten.

## Tahap 3 - Backend Edge Functions

Target function:

- `submit-tracking`
- `checkin-attendance`
- `checkout-attendance`
- `approve-user`
- `import-users`
- `import-plotting`
- `reset-assignment`

Validasi wajib:

- token user
- role user
- ownership petugas
- assignment aktif
- payload schema
- rate limit sederhana

## Tahap 4 - Dashboard Refactor

Pecah `app/page.js` menjadi:

- `components/layout`
- `components/dashboard-live`
- `components/command-center`
- `components/users`
- `components/plotting`
- `services/supabaseDashboard.js`
- `hooks/useDashboardData.js`

Dashboard live harus membaca:

- `dashboard_live_locations`
- `get_dashboard_summary`
- `attendance_logs` hanya untuk halaman riwayat/filter

## Tahap 5 - Android Hardening

Target:

- Auth session Supabase.
- Background tracking service yang tahan app minimize.
- Retry queue dengan exponential backoff.
- Kolom local `sync_attempts`, `last_error`, `server_id`.
- Deteksi battery optimization.
- Manual sync dan status sinkronisasi jelas.

## Tahap 6 - Operasional Produksi

Checklist:

- Staging dan production Supabase terpisah.
- Backup database aktif.
- Retention policy tracking logs.
- Dashboard error logging.
- Alert ketika sync gagal massal.
- Dokumentasi deploy.
- SOP reset akun dan import data.
