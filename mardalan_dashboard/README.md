# mardalan Dashboard

Dashboard monitoring untuk BPS Kabupaten Labuhanbatu Utara.

## Jalankan Lokal

```powershell
cd C:\Users\Admin\tracking_simple\mardalan_dashboard
npm.cmd install
npm.cmd run dev
```

Buka:

```text
http://127.0.0.1:3000
```

## Supabase

1. Buat project Supabase.
2. Jalankan SQL di `supabase/schema.sql` lewat Supabase SQL Editor.
3. Jalankan SQL hardening awal di `supabase/001_production_foundation.sql`.
4. Setelah Supabase Auth dan `profiles.auth_user_id` siap, jalankan
   `supabase/002_auth_rls_production.sql`.
5. Copy `.env.example` menjadi `.env.local`.
6. Isi `NEXT_PUBLIC_SUPABASE_URL` dan `NEXT_PUBLIC_SUPABASE_ANON_KEY`.

Jika env belum diisi, dashboard berjalan dengan data lokal kosong. Gunakan menu
Manajemen Pengguna untuk mencoba memasukkan 1 petugas terlebih dahulu.

## Data Wilayah SLS

Agar warning luar SLS akurat, Supabase harus diisi batas polygon SLS Kabupaten
Labuhanbatu Utara pada tabel `master_regions.geom`. Data alokasi Excel hanya
menentukan petugas mendapat kecamatan/desa/SLS mana; polygon SLS tetap perlu
diimpor dari GeoJSON atau Shapefile.

File `..\data peta petugas.xlsx` sudah dikonversi menjadi:

- `lib/laburaRegions.js` untuk dropdown kecamatan/desa/SLS di dashboard.
- `supabase/master_regions_seed.csv` untuk bahan import master wilayah ke
  Supabase.

Alur produksi:

1. Import polygon SLS Labuhanbatu Utara ke `master_regions`.
2. Import alokasi petugas dari Excel sesuai format
   `supabase/template_alokasi_petugas.csv`.
3. Android mengirim `assignment_id`, latitude, longitude, akurasi, baterai, dan
   waktu tracking ke `tracking_logs`.
4. Trigger Supabase mengecek titik GPS terhadap polygon SLS dan mengisi
   `geofence_status`, `is_outside_sls`, serta `warning_message`.
5. Dashboard menampilkan badge `Di luar SLS` jika titik petugas keluar dari
   wilayah tugas.

## Android Tracking Ke Supabase

Aplikasi Android membaca konfigurasi Supabase dari `dart-define`, jadi jalankan
Flutter seperti ini:

```powershell
flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=ANON_KEY
```

Untuk build APK:

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=ANON_KEY
```

Sebelum mencoba tracking, pastikan Supabase sudah berisi:

1. `profiles.officer_code` yang sama dengan ID login Android.
2. Status petugas `approved`.
3. Minimal satu assignment aktif untuk petugas tersebut.

## Roadmap Produksi

Dokumen teknis produksi ada di:

- `docs/api-contract.md`
- `docs/production-roadmap.md`

Untuk live skala produksi, dashboard sebaiknya membaca `dashboard_live_locations`
dan `get_dashboard_summary`, bukan membaca seluruh `tracking_logs` mentah.
