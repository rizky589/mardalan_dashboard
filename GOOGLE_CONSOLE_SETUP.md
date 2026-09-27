# 🔧 Setup Google Console untuk Google Sheets API

## 📋 Langkah-langkah Setup

### 1. Buat Project di Google Cloud Console
1. Buka [Google Cloud Console](https://console.cloud.google.com/)
2. Klik **"Select a project"** → **"New Project"**
3. Nama project: `tracking-petugas-survey`
4. Klik **"Create"**

### 2. Enable Google Sheets API
1. Di dashboard project, pilih **"APIs & Services"** → **"Library"**
2. Cari **"Google Sheets API"**
3. Klik **"Enable"**

### 3. Buat Service Account
1. Pilih **"APIs & Services"** → **"Credentials"**
2. Klik **"+ Create Credentials"** → **"Service Account"**
3. Service account name: `sheets-tracker`
4. Service account ID: `sheets-tracker`
5. Klik **"Create and Continue"**
6. Role: **"Editor"** (atau "Google Sheets API > Sheets Editor")
7. Klik **"Continue"** → **"Done"**

### 4. Download Service Account Key
1. Di halaman **"Credentials"**, klik service account yang baru dibuat
2. Tab **"Keys"** → **"Add Key"** → **"Create new key"**
3. Pilih **"JSON"** → **"Create"**
4. File JSON akan terdownload otomatis
5. **SIMPAN FILE INI DENGAN AMAN!**

### 5. Share Spreadsheet dengan Service Account
1. Buka file JSON yang didownload
2. Copy email dari field `"client_email"` (contoh: `sheets-tracker@tracking-petugas-survey.iam.gserviceaccount.com`)
3. Buka spreadsheet Anda: https://docs.google.com/spreadsheets/d/1pk0GzWrTnw9SG4OZJx9_TT4BARSMPuQYkZW_a-mvFfc/edit
4. Klik **"Share"** → Paste email service account
5. Pilih role **"Editor"** → **"Send"**

### 6. Setup Sheets Structure
Buat 3 sheets dengan nama dan header berikut:

#### Sheet 1: `officers`
```
id | name | phone | status | created_at
```

#### Sheet 2: `surveys`  
```
survey_id | officer_id | officer_name | start_time | end_time | start_lat | start_lng | end_lat | end_lng | duration_minutes | status
```

#### Sheet 3: `tracking_logs`
```
timestamp | officer_id | survey_id | latitude | longitude | accuracy | type
```

### 7. Update Kode Flutter
1. Buka file `lib/services/sheets_service.dart`
2. Ganti bagian TODO dengan credentials dari file JSON:

```dart
final credentials = ServiceAccountCredentials.fromJson({
  "type": "service_account",
  "project_id": "tracking-petugas-survey",
  "private_key_id": "COPY_DARI_JSON",
  "private_key": "-----BEGIN PRIVATE KEY-----\nCOPY_DARI_JSON\n-----END PRIVATE KEY-----\n",
  "client_email": "sheets-tracker@tracking-petugas-survey.iam.gserviceaccount.com",
  "client_id": "COPY_DARI_JSON",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/sheets-tracker%40tracking-petugas-survey.iam.gserviceaccount.com"
});
```

3. Uncomment kode yang ada di method `initialize()`

### 8. Test Koneksi
1. Jalankan aplikasi: `flutter run -d chrome`
2. Login sebagai petugas
3. Klik "Mulai Survey" 
4. Cek spreadsheet - data harus muncul otomatis!

## 🔒 Keamanan
- **JANGAN** commit file JSON ke Git
- Simpan credentials di environment variables untuk production
- Gunakan `.gitignore` untuk file credentials

## 🚨 Troubleshooting
- **Error 403**: Pastikan service account sudah di-share ke spreadsheet
- **Error 404**: Cek spreadsheet ID di kode
- **Error 401**: Cek format credentials JSON

## 📊 Monitoring
Setelah setup, Anda bisa:
- Lihat data real-time di Google Sheets
- Buat dashboard di Looker Studio
- Export data untuk analisis
