"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  AlertTriangle,
  BarChart3,
  CalendarCheck,
  CheckCircle2,
  ClipboardList,
  Database,
  Download,
  FileDown,
  FileSpreadsheet,
  Gauge,
  Import,
  Layers,
  LogOut,
  Mail,
  Map as MapIcon,
  MapPin,
  MapPinned,
  MicOff,
  Pencil,
  Phone,
  Play,
  Plus,
  RefreshCw,
  RotateCcw,
  Route,
  Search,
  Settings,
  ShieldCheck,
  Save,
  Target,
  Trash2,
  Upload,
  UserCheck,
  UserCog,
  X,
  UserPlus,
  Users,
  Zap
} from "lucide-react";
import "leaflet/dist/leaflet.css";
import * as XLSX from "xlsx";

import { hasSupabaseConfig, supabase } from "@/lib/supabaseClient";
import {
  laburaKecamatan,
  laburaRegions,
  surveyTypes
} from "@/lib/mockData";

const navGroups = [
  {
    title: "Monitoring",
    items: [
      ["dashboard-live", "Dashboard Live", Gauge],
      ["monitoring-operasional", "Monitoring Operasional", BarChart3],
      ["riwayat-jejak", "Riwayat Jejak", Route],
      ["riwayat-absensi", "Riwayat Absensi", CalendarCheck]
    ]
  },
  {
    title: "Master Data",
    items: [
      ["manajemen-pengguna", "Manajemen Pengguna", Users],
      ["wilayah-tugas", "Wilayah Tugas", Layers],
      ["plotting-tim", "Plotting Tim", UserCog]
    ]
  },
  {
    title: "Analytic & Admin",
    items: [
      ["titik-sasaran", "Titik Sasaran", Target],
      ["hak-akses", "Hak Akses (Roles)", ShieldCheck],
      ["pengaturan-sistem", "Pengaturan Sistem", Settings],
      ["log-aktivitas", "Log Aktivitas", ClipboardList]
    ]
  }
];

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

const pageMeta = {
  "dashboard-live": ["Dashboard Live Monitoring", ""],
  "monitoring-operasional": ["Monitoring Operasional", "Pantau capaian lapangan, kesehatan tracking, absensi, dan isu prioritas harian."],
  "riwayat-jejak": ["Riwayat Jejak", "Telusuri jalur petugas berdasarkan survei, wilayah, dan tanggal."],
  "riwayat-absensi": ["Riwayat Absensi", "Rekap check in dan check out petugas lapangan."],
  "manajemen-pengguna": ["Manajemen Pengguna", "Approval akun petugas dan pengelolaan pengguna dashboard."],
  "wilayah-tugas": ["Wilayah Tugas", "Alokasi survei, petugas, kecamatan, desa, dan SLS."],
  "plotting-tim": [""],
  "titik-sasaran": ["Titik Sasaran", "Kelola titik sasaran/prelist wilayah kerja Labura."],
  "hak-akses": ["Hak Akses (Roles)", "Atur kewenangan Admin Kab/Kot, Supervisor, dan Petugas."],
  "pengaturan-sistem": ["Pengaturan Sistem", "Parameter tracking background, akurasi GPS, dan sinkronisasi."],
  "log-aktivitas": ["Log Aktivitas", "Audit aktivitas pengguna dan perubahan data."]
};

export default function DashboardPage() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [showCommandCenter, setShowCommandCenter] = useState(false);
  const [activeView, setActiveView] = useState("dashboard-live");
  const [profiles, setProfiles] = useState([]);
  const [assignments, setAssignments] = useState([]);
  const [liveLocations, setLiveLocations] = useState([]);
  const [trackingLogs, setTrackingLogs] = useState([]);
  const [attendanceLogs, setAttendanceLogs] = useState([]);
  const [targetPoints, setTargetPoints] = useState([]);
  const [activityLogs, setActivityLogs] = useState([]);
  const [filters, setFilters] = useState({ kecamatan: "", desa: "", survey: "", officer: "" });
  const [showAssignmentModal, setShowAssignmentModal] = useState(false);

  useEffect(() => {
    checkSession();
  }, []);

  useEffect(() => {
    if (isAuthenticated) loadSupabaseData();
  }, [isAuthenticated]);

  async function checkSession() {
    if (!hasSupabaseConfig || !supabase) return;

    const { data } = await supabase.auth.getSession();
    if (data.session) setIsAuthenticated(true);
  }

  async function handleLogin({ email, password }) {
    if (!hasSupabaseConfig || !supabase) {
      setIsAuthenticated(true);
      return;
    }

    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    setIsAuthenticated(true);
  }

  async function loadSupabaseData() {
    if (!hasSupabaseConfig || !supabase) return;

    const [
      profilesResult,
      assignmentsResult,
      liveLocationsResult,
      trackingResult,
      attendanceResult,
      targetResult,
      activityResult
    ] = await Promise.all([
      supabase.from("profiles").select("*").order("created_at", { ascending: false }),
      supabase.from("assignments").select("*, profiles(officer_code, full_name)").order("created_at", { ascending: false }),
      supabase.from("dashboard_live_locations").select("*").order("recorded_at", { ascending: false }),
      supabase.from("tracking_logs").select("*, profiles(officer_code, full_name), assignments(survey_type,kecamatan,desa,sls)").order("recorded_at", { ascending: false }).limit(250),
      supabase.from("attendance_logs").select("*, profiles(officer_code, full_name,kecamatan)").order("check_in_at", { ascending: false }).limit(100),
      supabase.from("target_points").select("*").order("created_at", { ascending: false }),
      supabase.from("activity_logs").select("*").order("created_at", { ascending: false }).limit(100)
    ]);

    if (!profilesResult.error && profilesResult.data?.length) {
      setProfiles(
        profilesResult.data.map((item) => ({
          ...item,
          display_id: item.officer_code,
          full_name: item.full_name,
          kecamatan: item.kecamatan || "Labuhanbatu Utara"
        }))
      );
    }

    if (!assignmentsResult.error && assignmentsResult.data?.length) {
      setAssignments(
        assignmentsResult.data.map((item) => ({
          ...item,
          officer_id: item.profiles?.officer_code || item.officer_id,
          officer_name: item.profiles?.full_name || "Petugas",
          status: item.status
        }))
      );
    }

    if (!liveLocationsResult.error && liveLocationsResult.data?.length) {
      setLiveLocations(
        liveLocationsResult.data.map((item) => ({
          ...item,
          id: item.officer_code || item.officer_id,
          officer_id: item.officer_code || item.officer_id,
          profile_id: item.officer_id,
          officer_name: item.officer_name || "Petugas",
          survey_type: item.survey_type || "-",
          kecamatan: item.kecamatan || "-",
          desa: item.desa || "-",
          sls: item.sls || "-",
          is_outside_sls: item.is_outside_sls || false,
          geofence_status: item.geofence_status || "unknown",
          recorded_at: item.recorded_at
        }))
      );
    }

    if (!trackingResult.error && trackingResult.data?.length) {
      setTrackingLogs(
        trackingResult.data.map((item) => ({
          ...item,
          officer_id: item.profiles?.officer_code || item.officer_id,
          officer_name: item.profiles?.full_name || "Petugas",
          survey_type: item.assignments?.survey_type || "-",
          kecamatan: item.assignments?.kecamatan || "-",
          desa: item.assignments?.desa || "-",
          sls: item.assignments?.sls || "-",
          is_outside_sls: item.is_outside_sls || false,
          geofence_status: item.geofence_status || "unknown",
          recorded_at: item.recorded_at
        }))
      );
    }

    if (!attendanceResult.error && attendanceResult.data?.length) {
      setAttendanceLogs(
        attendanceResult.data.map((item) => ({
          ...item,
          officer_id: item.profiles?.officer_code || item.officer_id,
          officer_name: item.profiles?.full_name || "Petugas",
          kecamatan: item.profiles?.kecamatan || "-"
        }))
      );
    }

    if (!targetResult.error && targetResult.data?.length) setTargetPoints(targetResult.data);
    if (!activityResult.error && activityResult.data?.length) setActivityLogs(activityResult.data);
  }

  const filteredTracking = useMemo(() => {
    return trackingLogs.filter((item) => {
      if (filters.kecamatan && item.kecamatan !== filters.kecamatan) return false;
      if (filters.desa && item.desa !== filters.desa) return false;
      if (filters.survey && item.survey_type !== filters.survey) return false;
      if (filters.officer && item.officer_id !== filters.officer) return false;
      return true;
    });
  }, [filters, trackingLogs]);

  const latestByOfficer = useMemo(() => {
    if (liveLocations.length) return liveLocations;

    const map = new Map();
    filteredTracking.forEach((item) => {
      if (!map.has(item.officer_id)) map.set(item.officer_id, item);
    });
    return Array.from(map.values());
  }, [filteredTracking, liveLocations]);

  const stats = {
    approved: profiles.filter((item) => item.status === "approved").length,
    pending: profiles.filter((item) => item.status === "pending").length,
    online: latestByOfficer.length,
    outOfArea: latestByOfficer.filter((item) => item.accuracy > 30).length,
    fakeGps: 0,
    idle: Math.max(0, profiles.filter((item) => item.status === "approved").length - latestByOfficer.length)
  };

  const currentMeta = pageMeta[activeView];

  if (!isAuthenticated) {
    return <LoginPage onLogin={handleLogin} />;
  }

  if (showCommandCenter) {
    return (
      <CommandCenter
        latestByOfficer={latestByOfficer}
        profiles={profiles}
        attendanceLogs={attendanceLogs}
        assignments={assignments}
        targetPoints={targetPoints}
        stats={stats}
        onExit={() => setShowCommandCenter(false)}
        onOpenHistory={() => {
          setShowCommandCenter(false);
          setActiveView("riwayat-jejak");
        }}
      />
    );
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-logo">
            <img src="/bps.png" alt="BPS" />
          </div>
          <div>
            <h1 className="italic">MARDALAN</h1>
            <p>Monitoring Aktivitas dan Rute Petugas Lapangan</p>
          </div>
        </div>

        {navGroups.map((group) => (
          <div className="nav-group" key={group.title}>
            <div className="nav-title">{group.title}</div>
            {group.items.map(([id, label, Icon]) => (
              <button
                className={`nav-item ${activeView === id ? "active" : ""}`}
                key={id}
                onClick={() => setActiveView(id)}
              >
                <Icon size={16} />
                <span>{label}</span>
              </button>
            ))}
          </div>
        ))}

        <button
          className="nav-item logout"
          onClick={async () => {
            if (hasSupabaseConfig && supabase) await supabase.auth.signOut();
            setActiveView("dashboard-live");
            setIsAuthenticated(false);
          }}
        >
          <LogOut size={16} />
          <span>Keluar Aplikasi</span>
        </button>
      </aside>

      <main className="main">
        {activeView !== "riwayat-absensi" && (
          <header className="topbar">
            <div>
              <div className="eyebrow"></div>
              <h2>{currentMeta[0]}</h2>
              <p>{currentMeta[1]}</p>
            </div>
            <div className="top-actions">
              <span className={`connection ${hasSupabaseConfig ? "online" : "demo"}`}>
                <Database size={15} />
                {hasSupabaseConfig ? "Supabase Connected" : "Data Lokal Kosong"}
              </span>
              <button className="icon-btn" onClick={loadSupabaseData} title="Refresh data">
                <RefreshCw size={18} />
              </button>
            </div>
          </header>
        )}

        {activeView === "dashboard-live" && (
          <DashboardLive
            filters={filters}
            setFilters={setFilters}
            profiles={profiles}
            attendanceLogs={attendanceLogs}
            latestByOfficer={latestByOfficer}
            stats={stats}
            assignments={assignments}
            targetPoints={targetPoints}
            onEnterCommandCenter={() => setShowCommandCenter(true)}
          />
        )}

        {activeView === "monitoring-operasional" && (
          <MonitoringOperasional
            profiles={profiles}
            assignments={assignments}
            trackingLogs={trackingLogs}
            attendanceLogs={attendanceLogs}
            latestByOfficer={latestByOfficer}
            stats={stats}
          />
        )}

        {activeView === "riwayat-jejak" && <RiwayatJejak rows={filteredTracking} profiles={profiles} />}
        {activeView === "riwayat-absensi" && <RiwayatAbsensi rows={attendanceLogs} profiles={profiles} />}
        {activeView === "manajemen-pengguna" && <ManajemenPengguna profiles={profiles} setProfiles={setProfiles} />}
        {activeView === "wilayah-tugas" && (
          <WilayahTugas
            assignments={assignments}
            onAdd={() => setShowAssignmentModal(true)}
            onDelete={(id) => setAssignments((current) => current.filter((item) => item.id !== id))}
          />
        )}
        {activeView === "plotting-tim" && <PlottingTim profiles={profiles} assignments={assignments} />}
        {activeView === "titik-sasaran" && <TitikSasaran rows={targetPoints} />}
        {activeView === "hak-akses" && <HakAkses />}
        {activeView === "pengaturan-sistem" && <PengaturanSistem />}
        {activeView === "log-aktivitas" && <LogAktivitas rows={activityLogs} />}
      </main>

      {showAssignmentModal && (
        <AssignmentModal
          profiles={profiles}
          onClose={() => setShowAssignmentModal(false)}
          onSave={(item) => {
            setAssignments((current) => [item, ...current]);
            setShowAssignmentModal(false);
          }}
        />
      )}
    </div>
  );
}

function LoginPage({ onLogin }) {
  const [showPassword, setShowPassword] = useState(false);
  const [email, setEmail] = useState("admin@bps.go.id");
  const [password, setPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");

  async function submitLogin() {
    setError("");
    setIsSubmitting(true);
    try {
      await onLogin({ email: email.trim().toLowerCase(), password });
    } catch (loginError) {
      setError(loginError.message || "Login gagal. Periksa email dan kata sandi.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="login-page">
      <section className="login-hero">
        <div className="hero-art" aria-hidden="true" />
      </section>

      <section className="login-panel">
        <div className="login-card">
          <div className="login-logo">
            <img src="/bps.png" alt="BPS" />
          </div>
          <h2>mardalan</h2>
          <p>Monitoring Aktivitas dan Rute Petugas Lapangan</p>

          <label>
            Alamat Email
            <input value={email} onChange={(event) => setEmail(event.target.value)} type="email" />
          </label>
          <label>
            Kata Sandi
            <div className="password-field">
              <input value={password} onChange={(event) => setPassword(event.target.value)} type={showPassword ? "text" : "password"} />
              <button type="button" onClick={() => setShowPassword((value) => !value)}>
                {showPassword ? "Sembunyikan" : "Lihat"}
              </button>
            </div>
          </label>
          {error && <div className="login-error">{error}</div>}
          <button className="login-button" onClick={submitLogin} disabled={isSubmitting || !email || !password}>
            {isSubmitting ? "Memeriksa..." : "Masuk ke Sistem"}
          </button>

          <div className="login-footer">
            <span>Badan Pusat Statistik</span>
            <strong>Kabupaten Labuhanbatu Utara</strong>
          </div>
        </div>
      </section>
    </main>
  );
}

function DashboardLive({ filters, setFilters, profiles, attendanceLogs, latestByOfficer, stats, assignments, targetPoints, onEnterCommandCenter }) {
  const [mapLayers, setMapLayers] = useState({
    satellite: true,
    assignments: true,
    targets: false
  });
  const [audioEnabled, setAudioEnabled] = useState(false);
  const approvedProfiles = profiles.filter((item) => item.status === "approved");
  const petugasProfiles = approvedProfiles.filter((item) => item.role === "petugas" || !item.role);
  const pemeriksaProfiles = approvedProfiles.filter((item) => item.role === "supervisor" || item.role === "admin_kabkot" || item.role === "pemeriksa");
  const todayKey = new Date().toISOString().slice(0, 10);
  const attendanceTodayIds = new Set(
    attendanceLogs
      .filter((item) => (item.check_in_at || item.created_at || "").slice(0, 10) === todayKey)
      .map((item) => item.officer_id)
  );

  function profileForOfficer(officerId) {
    return profiles.find((item) => item.id === officerId || item.officer_code === officerId);
  }

  const onlinePetugas = latestByOfficer.filter((item) => {
    const profile = profileForOfficer(item.officer_id);
    return !profile || profile.role === "petugas" || !profile.role;
  }).length;
  const onlinePemeriksa = latestByOfficer.filter((item) => {
    const profile = profileForOfficer(item.officer_id);
    return profile && (profile.role === "supervisor" || profile.role === "admin_kabkot" || profile.role === "pemeriksa");
  }).length;
  const attendedPetugas = petugasProfiles.filter((item) => attendanceTodayIds.has(item.id) || attendanceTodayIds.has(item.officer_code)).length;
  const attendedPemeriksa = pemeriksaProfiles.filter((item) => attendanceTodayIds.has(item.id) || attendanceTodayIds.has(item.officer_code)).length;
  const notAttendedPetugas = Math.max(0, petugasProfiles.length - attendedPetugas);
  const notAttendedPemeriksa = Math.max(0, pemeriksaProfiles.length - attendedPemeriksa);

  function exportMetric(title, rows) {
    const csvContent = [
      ["metric", "kategori", "nilai"].join(","),
      ...rows.map((row) => [title, row.label, row.value].map((item) => `"${String(item).replaceAll('"', '""')}"`).join(","))
    ].join("\n");
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = `${title.toLowerCase().replaceAll(" ", "-")}.csv`;
    link.click();
    URL.revokeObjectURL(link.href);
  }

  function toggleLayer(key) {
    setMapLayers((current) => ({ ...current, [key]: !current[key] }));
  }

  function toggleAudio() {
    const nextValue = !audioEnabled;
    setAudioEnabled(nextValue);

    if (typeof window !== "undefined" && "speechSynthesis" in window) {
      const message = nextValue ? "Audio monitoring aktif" : "Audio monitoring nonaktif";
      window.speechSynthesis.cancel();
      window.speechSynthesis.speak(new SpeechSynthesisUtterance(message));
    }
  }

  return (
    <section>
      <div className="live-metric-grid">
        <LiveMetricCard
          title="Petugas Online"
          tone="blue"
          rows={[
            { label: "Petugas", value: onlinePetugas, total: petugasProfiles.length },
            { label: "Pemeriksa", value: onlinePemeriksa, total: pemeriksaProfiles.length }
          ]}
          onClick={() => exportMetric("Petugas Online", [
            { label: "Petugas", value: `${onlinePetugas}/${petugasProfiles.length}` },
            { label: "Pemeriksa", value: `${onlinePemeriksa}/${pemeriksaProfiles.length}` }
          ])}
        />
        <LiveMetricCard
          title="Keluar Wilayah"
          tone="orange"
          mainValue={stats.outOfArea}
          hint="Berada di luar batas SLS"
          onClick={() => exportMetric("Keluar Wilayah", [{ label: "Total", value: stats.outOfArea }])}
        />
        <LiveMetricCard
          title="Deteksi Fake GPS"
          tone="red"
          mainValue={stats.fakeGps}
          hint="Menggunakan Mock Location"
          onClick={() => exportMetric("Deteksi Fake GPS", [{ label: "Total", value: stats.fakeGps }])}
        />
        <LiveMetricCard
          title="Sudah Absen Hari Ini"
          tone="green"
          rows={[
            { label: "Petugas", value: attendedPetugas },
            { label: "Pemeriksa", value: attendedPemeriksa }
          ]}
          onClick={() => exportMetric("Sudah Absen Hari Ini", [
            { label: "Petugas", value: attendedPetugas },
            { label: "Pemeriksa", value: attendedPemeriksa }
          ])}
        />
        <LiveMetricCard
          title="Belum Absen Hari Ini"
          tone="yellow"
          rows={[
            { label: "Petugas", value: notAttendedPetugas },
            { label: "Pemeriksa", value: notAttendedPemeriksa }
          ]}
          onClick={() => exportMetric("Belum Absen Hari Ini", [
            { label: "Petugas", value: notAttendedPetugas },
            { label: "Pemeriksa", value: notAttendedPemeriksa }
          ])}
        />
      </div>

      <div className="filter-bar">
        <Select label="Jenis Sensus/Survei" value={filters.survey} onChange={(survey) => setFilters({ ...filters, survey })} options={surveyTypes} allLabel="Semua Survei" />
        <Select label="Kecamatan" value={filters.kecamatan} onChange={(kecamatan) => setFilters({ ...filters, kecamatan, desa: "" })} options={laburaKecamatan.map((item) => item.name)} allLabel="Semua Kecamatan" />
        <Select label="Desa" value={filters.desa} onChange={(desa) => setFilters({ ...filters, desa })} options={getDesaOptions(filters.kecamatan)} allLabel="Semua Desa" />
        <Select label="Petugas" value={filters.officer} onChange={(officer) => setFilters({ ...filters, officer })} options={latestByOfficer.map((item) => item.officer_id)} allLabel="Semua Petugas" />
      </div>

      <div className="live-layout">
        <div className="map-card">
          <div className="map-toolbar">
            <div className="layer-panel">
              <strong>Map Layers</strong>
              <label><input type="checkbox" checked={mapLayers.satellite} onChange={() => toggleLayer("satellite")} /> Satellite View</label>
              <label><input type="checkbox" checked={mapLayers.assignments} onChange={() => toggleLayer("assignments")} /> Wilayah Tugas</label>
              <label><input type="checkbox" checked={mapLayers.targets} onChange={() => toggleLayer("targets")} /> Titik Sasaran</label>
            </div>
            <div className="command-bar">
              <button>Show List</button>
              <button>Show Alerts</button>
              <button className="primary" onClick={toggleAudio}>{audioEnabled ? "Audio On" : "Audio Off"}</button>
              <button className="command-enter" onClick={onEnterCommandCenter}>Masuk Command Center</button>
            </div>
          </div>
          <LiveMap points={latestByOfficer} assignments={assignments} targetPoints={targetPoints} layers={mapLayers} />
        </div>

        <div className="side-panel">
          <div className="panel-heading">
            <h3>Petugas Aktif</h3>
            <span>{latestByOfficer.length} online</span>
          </div>
          <div className="officer-feed">
            {latestByOfficer.map((item) => (
              <div className="officer-card" key={item.id}>
                <div className="avatar">{item.officer_name?.[0] || "P"}</div>
                <div>
                  <strong>{item.officer_name}</strong>
                  <span>{item.kecamatan} - {item.desa}</span>
                  <small>Akurasi {item.accuracy}m | Baterai {item.battery_level}%</small>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

function MonitoringOperasional({ profiles, assignments, trackingLogs, attendanceLogs, latestByOfficer, stats }) {
  const checkedIn = attendanceLogs.filter((item) => item.status === "checked_in" || !item.check_out_at).length;
  const completedAttendance = attendanceLogs.filter((item) => item.status === "complete" || item.check_out_at).length;
  const lowAccuracy = latestByOfficer.filter((item) => Number(item.accuracy || 0) > 30).length;
  const healthyAccuracy = Math.max(0, latestByOfficer.length - lowAccuracy);
  const assignedOfficerIds = new Set(assignments.map((item) => item.officer_id));
  const unassigned = profiles.filter((item) => item.status === "approved" && (item.role === "petugas" || !item.role) && !assignedOfficerIds.has(item.id)).length;
  const averageBattery = latestByOfficer.length
    ? Math.round(latestByOfficer.reduce((sum, item) => sum + Number(item.battery_level || 0), 0) / latestByOfficer.length)
    : 0;
  const completionRate = profiles.length ? Math.round((stats.approved / profiles.length) * 100) : 0;
  const trackingBuckets = Array.from({ length: 8 }, (_, index) => {
    const hour = `${String(index * 3).padStart(2, "0")}:00`;
    const count = trackingLogs.filter((_, rowIndex) => rowIndex % 8 === index).length;
    return { label: hour, value: count };
  });
  const maxBucket = Math.max(1, ...trackingBuckets.map((item) => item.value));
  const statusSlices = [
    { label: "Online", value: stats.online, tone: "blue" },
    { label: "Idle", value: stats.idle, tone: "slate" },
    { label: "Keluar Wilayah", value: stats.outOfArea, tone: "orange" },
    { label: "Akurasi Rendah", value: lowAccuracy, tone: "red" }
  ];
  const issueRows = [
    ["Akurasi GPS rendah", lowAccuracy, "Cek perangkat dengan akurasi > 30 meter", lowAccuracy ? "Perlu Dicek" : "Aman"],
    ["Belum ada penugasan", unassigned, "Petugas aktif belum punya wilayah tugas", unassigned ? "Tindak Lanjut" : "Aman"],
    ["Absensi berjalan", checkedIn, "Petugas sudah check-in dan belum check-out", checkedIn ? "Dipantau" : "Kosong"],
    ["Petugas idle", stats.idle, "Offline atau belum bergerak lebih dari 15 menit", stats.idle ? "Perlu Dicek" : "Aman"]
  ];

  return (
    <section className="ops-page">
      <div className="ops-kpi-grid">
        <div className="ops-kpi">
          <span>Capaian Aktivasi</span>
          <strong>{completionRate}%</strong>
          <small>{stats.approved} akun aktif dari {profiles.length} pengguna</small>
        </div>
        <div className="ops-kpi">
          <span>Tracking Masuk</span>
          <strong>{trackingLogs.length}</strong>
          <small>Koordinat terbaru dalam buffer dashboard</small>
        </div>
        <div className="ops-kpi">
          <span>Absensi Selesai</span>
          <strong>{completedAttendance}</strong>
          <small>{checkedIn} sesi masih berjalan</small>
        </div>
        <div className="ops-kpi">
          <span>Rata-rata Baterai</span>
          <strong>{averageBattery}%</strong>
          <small>{latestByOfficer.length} petugas online terpantau</small>
        </div>
      </div>

      <div className="ops-grid">
        <Panel title="Tren Update Tracking">
          <div className="ops-bars">
            {trackingBuckets.map((item) => (
              <div className="ops-bar-item" key={item.label}>
                <div className="ops-bar-track"><span style={{ height: `${Math.max(8, (item.value / maxBucket) * 100)}%` }} /></div>
                <strong>{item.value}</strong>
                <small>{item.label}</small>
              </div>
            ))}
          </div>
        </Panel>

        <Panel title="Komposisi Status Operasional">
          <div className="ops-status-list">
            {statusSlices.map((item) => {
              const total = Math.max(1, stats.approved + stats.outOfArea + lowAccuracy);
              return (
                <div className="ops-status-row" key={item.label}>
                  <div>
                    <span className={`status-dot ${item.tone}`} />
                    <strong>{item.label}</strong>
                  </div>
                  <div className="ops-progress"><span className={item.tone} style={{ width: `${Math.min(100, (item.value / total) * 100)}%` }} /></div>
                  <b>{item.value}</b>
                </div>
              );
            })}
          </div>
        </Panel>

        <Panel title="Kesehatan GPS & Perangkat">
          <div className="ops-device-grid">
            <div><span>Akurasi Aman</span><strong>{healthyAccuracy}</strong></div>
            <div><span>Akurasi Rendah</span><strong>{lowAccuracy}</strong></div>
            <div><span>Fake GPS</span><strong>{stats.fakeGps}</strong></div>
            <div><span>Belum Ditugaskan</span><strong>{unassigned}</strong></div>
          </div>
        </Panel>

        <Panel title="Isu Prioritas Hari Ini">
          <DataTable
            headers={["Isu", "Jumlah", "Arahan", "Status"]}
            rows={issueRows.map((item, index) => [
              item[0],
              item[1],
              item[2],
              <Badge key={index} tone={item[3] === "Aman" ? "green" : item[3] === "Kosong" ? "blue" : "orange"}>{item[3]}</Badge>
            ])}
          />
        </Panel>
      </div>
    </section>
  );
}

function CommandCenter({ latestByOfficer, profiles = [], attendanceLogs = [], assignments, targetPoints, stats, onExit, onOpenHistory }) {
  const [selectedOfficer, setSelectedOfficer] = useState(latestByOfficer[0] || null);
  const [showList, setShowList] = useState(true);
  const [showAlerts, setShowAlerts] = useState(true);
  const [assistantVisible, setAssistantVisible] = useState(false);
  const [officerPopupVisible, setOfficerPopupVisible] = useState(Boolean(latestByOfficer[0]));
  const [audioEnabled, setAudioEnabled] = useState(true);
  const [mapLayers, setMapLayers] = useState({
    satellite: true,
    assignments: true,
    targets: false
  });
  const [ccFilters, setCcFilters] = useState({ survey: surveyTypes[0], kabupaten: "Kab. Labuhanbatu Utara", kecamatan: "", desa: "", role: "Pemeriksa", presence: "" });
  const [assistantQuery, setAssistantQuery] = useState("");
  const [assistantMessages, setAssistantMessages] = useState([
    {
      role: "assistant",
      text: "Mardalan Asistant siap. Tanyakan lokasi petugas, pelanggaran wilayah, status online, atau statistik hari ini."
    }
  ]);
  const supervised = latestByOfficer.slice(0, 9);
  const outsideOfficers = latestByOfficer.filter((item) => item.accuracy > 30 || item.is_outside_sls || item.geofence_status === "outside_sls");
  const approvedProfiles = profiles.filter((item) => item.status === "approved");
  const petugasProfiles = approvedProfiles.filter((item) => item.role === "petugas" || !item.role);
  const pemeriksaProfiles = approvedProfiles.filter((item) => item.role === "supervisor" || item.role === "admin_kabkot" || item.role === "pemeriksa");
  const todayKey = new Date().toISOString().slice(0, 10);
  const attendanceTodayIds = new Set(
    attendanceLogs
      .filter((item) => (item.check_in_at || item.created_at || "").slice(0, 10) === todayKey)
      .map((item) => item.officer_id)
  );

  function profileForOfficer(officerId) {
    return profiles.find((item) => item.id === officerId || item.officer_code === officerId);
  }

  const onlinePetugas = latestByOfficer.filter((item) => {
    const profile = profileForOfficer(item.officer_id);
    return !profile || profile.role === "petugas" || !profile.role;
  }).length;
  const onlinePemeriksa = latestByOfficer.filter((item) => {
    const profile = profileForOfficer(item.officer_id);
    return profile && (profile.role === "supervisor" || profile.role === "admin_kabkot" || profile.role === "pemeriksa");
  }).length;
  const attendedPetugas = petugasProfiles.filter((item) => attendanceTodayIds.has(item.id) || attendanceTodayIds.has(item.officer_code)).length;
  const attendedPemeriksa = pemeriksaProfiles.filter((item) => attendanceTodayIds.has(item.id) || attendanceTodayIds.has(item.officer_code)).length;
  const notAttendedPetugas = Math.max(0, petugasProfiles.length - attendedPetugas);
  const notAttendedPemeriksa = Math.max(0, pemeriksaProfiles.length - attendedPemeriksa);
  const liveNotifications = [
    ...outsideOfficers.slice(0, 4).map((item) => ({
      id: `outside-${item.id}`,
      title: "Pelanggaran Wilayah",
      message: `${item.officer_name} terdeteksi keluar dari batas wilayah tugas SLS`,
      time: formatTimeOnly(item.recorded_at),
      officer: item
    })),
    ...latestByOfficer.slice(0, 8).map((item) => ({
      id: `system-${item.id}`,
      title: "Notifikasi Sistem",
      message: `${item.officer_name} mulai tugas/absensi`,
      time: formatTimeOnly(item.recorded_at),
      officer: item
    }))
  ].slice(0, 8);

  useEffect(() => {
    if (!selectedOfficer && latestByOfficer.length > 0) {
      setSelectedOfficer(latestByOfficer[0]);
      setOfficerPopupVisible(true);
    }
  }, [latestByOfficer, selectedOfficer]);

  function selectCommandOfficer(officer) {
    setSelectedOfficer(officer);
    setOfficerPopupVisible(true);
  }

  function findOfficerFromQuestion(question) {
    const normalized = question.toLowerCase();
    return latestByOfficer.find((item) => {
      const name = (item.officer_name || "").toLowerCase();
      const id = (item.officer_id || "").toLowerCase();
      return normalized.includes(name) || normalized.includes(id) || name.split(/\s+/).some((part) => part.length > 2 && normalized.includes(part));
    });
  }

  function answerAssistant(question) {
    const normalized = question.toLowerCase();
    const matchedOfficer = findOfficerFromQuestion(question);

    if (matchedOfficer && /lokasi|dimana|di mana|posisi|koordinat/.test(normalized)) {
      selectCommandOfficer(matchedOfficer);
      return `${matchedOfficer.officer_name} saat ini berada di ${matchedOfficer.desa}, ${matchedOfficer.kecamatan}, Labuhanbatu Utara. Koordinat terakhir: ${Number(matchedOfficer.latitude).toFixed(5)}, ${Number(matchedOfficer.longitude).toFixed(5)}. Update terakhir ${formatDate(matchedOfficer.recorded_at)}, akurasi ${matchedOfficer.accuracy} m.`;
    }

    if (/pelanggaran|keluar|luar wilayah|out of/.test(normalized)) {
      if (!outsideOfficers.length) return "Saat ini tidak ada petugas yang terdeteksi keluar wilayah berdasarkan data tracking terbaru.";
      return `${outsideOfficers.length} petugas terindikasi perlu dicek: ${outsideOfficers.slice(0, 5).map((item) => item.officer_name).join(", ")}. Klik daftar/notifikasi untuk membuka detail marker.`;
    }

    if (/online|aktif|idle/.test(normalized)) {
      return `Petugas online ${stats.online} dari ${stats.approved}. Tidak aktif/idle ${stats.idle}. Fake GPS ${stats.fakeGps}.`;
    }

    if (/baterai|battery/.test(normalized)) {
      const averageBattery = latestByOfficer.length
        ? Math.round(latestByOfficer.reduce((sum, item) => sum + Number(item.battery_level || 0), 0) / latestByOfficer.length)
        : 0;
      return `Rata-rata baterai petugas online saat ini ${averageBattery}%.`;
    }

    if (matchedOfficer) {
      selectCommandOfficer(matchedOfficer);
      return `${matchedOfficer.officer_name} ditemukan. Status terakhir di ${matchedOfficer.desa}, ${matchedOfficer.kecamatan}; baterai ${matchedOfficer.battery_level}%, speed ${matchedOfficer.speed} km/h, update ${formatDate(matchedOfficer.recorded_at)}.`;
    }

    return "Saya belum menemukan petugas atau konteks yang dimaksud. Coba tulis nama petugas, misalnya: dimana lokasi Petugas Survei 2 saat ini?";
  }

  function sendAssistantMessage() {
    const question = assistantQuery.trim();
    if (!question) return;

    const answer = answerAssistant(question);
    setAssistantMessages((current) => [
      ...current,
      { role: "user", text: question },
      { role: "assistant", text: answer }
    ]);
    setAssistantQuery("");
  }

  function toggleCommandAudio() {
    const nextValue = !audioEnabled;
    setAudioEnabled(nextValue);

    if (typeof window !== "undefined" && "speechSynthesis" in window) {
      const alertText = nextValue
        ? `Audio command center aktif. ${stats.online} petugas online, ${stats.outOfArea} keluar wilayah.`
        : "Audio command center nonaktif.";
      window.speechSynthesis.cancel();
      window.speechSynthesis.speak(new SpeechSynthesisUtterance(alertText));
    }
  }

  function toggleCommandLayer(key) {
    setMapLayers((current) => ({ ...current, [key]: !current[key] }));
  }

  return (
    <main className="cc-shell">
      <div className="cc-map">
        <LiveMap points={latestByOfficer} assignments={assignments} targetPoints={targetPoints} layers={mapLayers} onSelectPoint={selectCommandOfficer} />
      </div>

      <div className="cc-top-stats">
        <LiveMetricCard
          title="Petugas Online"
          tone="blue"
          rows={[
            { label: "Petugas", value: onlinePetugas, total: petugasProfiles.length },
            { label: "Pemeriksa", value: onlinePemeriksa, total: pemeriksaProfiles.length }
          ]}
          onClick={() => setShowList(true)}
        />
        <LiveMetricCard
          title="Keluar Wilayah"
          tone="orange"
          mainValue={stats.outOfArea}
          hint="Berada di luar batas SLS"
          onClick={() => setShowAlerts(true)}
        />
        <LiveMetricCard
          title="Deteksi Fake GPS"
          tone="red"
          mainValue={stats.fakeGps}
          hint="Menggunakan Mock Location"
          onClick={() => {
            setAssistantVisible(true);
            setAssistantQuery("cek deteksi fake gps hari ini");
          }}
        />
        <LiveMetricCard
          title="Sudah Absen Hari Ini"
          tone="green"
          rows={[
            { label: "Petugas", value: attendedPetugas },
            { label: "Pemeriksa", value: attendedPemeriksa }
          ]}
          onClick={() => {
            setAssistantVisible(true);
            setAssistantQuery("statistik petugas yang sudah absen hari ini");
          }}
        />
        <LiveMetricCard
          title="Belum Absen Hari Ini"
          tone="yellow"
          rows={[
            { label: "Petugas", value: notAttendedPetugas },
            { label: "Pemeriksa", value: notAttendedPemeriksa }
          ]}
          onClick={() => {
            setAssistantVisible(true);
            setAssistantQuery("daftar petugas yang belum absen hari ini");
          }}
        />
      </div>

      <div className="cc-layer-panel">
        <strong>Map Layers</strong>
        <label><input type="checkbox" checked={mapLayers.satellite} onChange={() => toggleCommandLayer("satellite")} /> Satellite View</label>
        <label><input type="checkbox" checked={mapLayers.assignments} onChange={() => toggleCommandLayer("assignments")} /> Wilayah Tugas</label>
        <label><input type="checkbox" checked={mapLayers.targets} onChange={() => toggleCommandLayer("targets")} /> Titik Sasaran</label>
      </div>

      {showList && (
        <aside className="cc-left-sidebar">
          <div className="cc-filter-panel">
            <div className="cc-filter-title">
              <strong>Filter Wilayah</strong>
              <span>^</span>
            </div>
            <label>
              Survei
              <select value={ccFilters.survey} onChange={(event) => setCcFilters({ ...ccFilters, survey: event.target.value })}>
                {surveyTypes.map((item) => <option key={item} value={item}>{item}</option>)}
              </select>
            </label>
            <label>
              Kabupaten
              <select value={ccFilters.kabupaten} onChange={(event) => setCcFilters({ ...ccFilters, kabupaten: event.target.value })}>
                <option value="Kab. Labuhanbatu Utara">KAB. LABUHANBATU UTARA</option>
              </select>
            </label>
            <label>
              Kecamatan
              <select value={ccFilters.kecamatan} onChange={(event) => setCcFilters({ ...ccFilters, kecamatan: event.target.value, desa: "" })}>
                <option value="">Pilih Kecamatan</option>
                {laburaKecamatan.map((item) => <option key={item.name} value={item.name}>{item.name}</option>)}
              </select>
            </label>
            <label>
              Desa
              <select value={ccFilters.desa} onChange={(event) => setCcFilters({ ...ccFilters, desa: event.target.value })}>
                <option value="">Pilih Desa</option>
                {getDesaOptions(ccFilters.kecamatan).map((item) => <option key={item} value={item}>{item}</option>)}
              </select>
            </label>
            <label>
              Filter Role
              <select value={ccFilters.role} onChange={(event) => setCcFilters({ ...ccFilters, role: event.target.value })}>
                <option value="">Semua Role (Pemeriksa & Petugas)</option>
                <option>Pemeriksa</option>
                <option>Petugas</option>
                <option>Supervisor</option>
              </select>
            </label>
            <label>
              Status Presensi
              <select value={ccFilters.presence} onChange={(event) => setCcFilters({ ...ccFilters, presence: event.target.value })}>
                <option value="">Semua Status (Aktif & Offline)</option>
                <option value="hadir">Sudah Absen</option>
                <option value="belum">Belum Absen</option>
              </select>
            </label>
          </div>

          <div className="cc-left-list">
            <div>
              <strong>Daftar Pemeriksa</strong>
              <span>{latestByOfficer.length}</span>
            </div>
            <div className="cc-selected-pill">
              <span>Petugas Terpilih</span>
              <button onClick={() => setSelectedOfficer(latestByOfficer[0] || null)}>Tampilkan Semua</button>
            </div>
            {latestByOfficer.length ? latestByOfficer.map((item) => (
              <button className={selectedOfficer?.officer_id === item.officer_id ? "active" : ""} key={item.id} onClick={() => selectCommandOfficer(item)}>
                {item.officer_name}
              </button>
            )) : <p>Belum ada petugas online.</p>}
          </div>
        </aside>
      )}

      <div className="cc-actions">
        <button onClick={() => setShowList((value) => !value)}>{showList ? "Hide List" : "Show List"}</button>
        <button onClick={() => setShowAlerts((value) => !value)}>{showAlerts ? "Hide Alerts" : "Show Alerts"}</button>
        <button className="orange" onClick={() => setAssistantVisible((value) => !value)}>{assistantVisible ? "Hide Assistant" : "Show Assistant"}</button>
        <button className="teal" onClick={toggleCommandAudio}>{audioEnabled ? "Audio On" : "Audio Off"}</button>
        <button className="danger" onClick={onExit}>Exit CC</button>
      </div>

      {showAlerts && (
        <div className="cc-alert">
          <AlertTriangle size={17} />
          <strong>{selectedOfficer?.officer_name || "Belum ada petugas"}</strong>
          <span>{selectedOfficer ? "mulai tugas/absensi" : "tambahkan petugas dan tracking terlebih dahulu"}</span>
        </div>
      )}

      {showAlerts && liveNotifications.length > 0 && (
        <aside className="cc-notifications">
          <div>
            <strong>Notifikasi Live</strong>
            <button onClick={() => setShowAlerts(false)}>Tandai Dibaca</button>
          </div>
          {liveNotifications.map((item) => (
            <button key={item.id} onClick={() => selectCommandOfficer(item.officer)}>
              <AlertTriangle size={16} />
              <span>{item.title}</span>
              <strong>{item.message}</strong>
              <small>{item.time}</small>
            </button>
          ))}
        </aside>
      )}

      {officerPopupVisible && selectedOfficer && (
        <div className="cc-officer-popup">
          <button className="cc-close" onClick={() => setOfficerPopupVisible(false)}>x</button>
          <div className="watch-box">
            <strong>Info Pengawasan</strong>
            <span>Membawahi {supervised.length} Petugas</span>
            <ul>
              {supervised.map((item) => <li key={item.id}>{item.officer_name}</li>)}
            </ul>
          </div>
          <div className="cc-profile">
            <div className="avatar large">{selectedOfficer.officer_name?.[0] || "P"}</div>
            <div>
              <h3>{selectedOfficer.officer_name}</h3>
              <span>{formatDate(selectedOfficer.recorded_at)}</span>
            </div>
          </div>
          <div className="cc-detail-grid">
            <div><span>Baterai</span><strong>{selectedOfficer.battery_level}%</strong></div>
            <div><span>Speed</span><strong>{selectedOfficer.speed} km/h</strong></div>
            <div><span>Akurasi</span><strong>{selectedOfficer.accuracy} m</strong></div>
            <div><span>Last Update</span><strong>{formatDate(selectedOfficer.recorded_at)}</strong></div>
          </div>
          <div className="cc-location">{selectedOfficer.desa}, {selectedOfficer.kecamatan}, Labuhanbatu Utara</div>
          <div className="cc-popup-actions">
            <button className="whatsapp">WhatsApp</button>
            <button onClick={onOpenHistory}>Riwayat Jejak</button>
          </div>
        </div>
      )}

      {officerPopupVisible && !selectedOfficer && (
        <div className="cc-officer-popup empty">
          <button className="cc-close" onClick={() => setOfficerPopupVisible(false)}>x</button>
          <h3>Belum ada petugas online</h3>
          <p>Tambahkan petugas, alokasikan wilayah, lalu sambungkan tracking Android/Supabase untuk menampilkan posisi live.</p>
        </div>
      )}

      {assistantVisible && (
        <section className="cc-ai-assistant">
          <div className="cc-ai-header">
            <strong>Mardalan Asistant</strong>
            <button onClick={() => setAssistantVisible(false)}>x</button>
          </div>
          <div className="cc-ai-messages">
            {assistantMessages.map((message, index) => (
              <div className={`cc-ai-message ${message.role}`} key={`${message.role}-${index}`}>
                {message.text}
              </div>
            ))}
          </div>
          <div className="cc-ai-suggestions">
            <button onClick={() => setAssistantQuery("cek pelanggaran wilayah")}>Cek Pelanggaran Wilayah</button>
            <button onClick={() => setAssistantQuery("daftar petugas aktif")}>Daftar Petugas Aktif</button>
            <button onClick={() => setAssistantQuery("statistik hari ini")}>Statistik Hari Ini</button>
          </div>
          <div className="cc-ai-input">
            <button title="Voice input"><MicOff size={16} /></button>
            <input
              value={assistantQuery}
              onChange={(event) => setAssistantQuery(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") sendAssistantMessage();
              }}
              placeholder="Ketik perintah di sini..."
            />
            <button className="send" onClick={sendAssistantMessage}><RefreshCw size={16} /></button>
          </div>
        </section>
      )}

      <button className="cc-brand-pill" onClick={() => setAssistantVisible((value) => !value)}>mardalan Command Center<br /><span>BPS Kabupaten Labuhanbatu Utara</span></button>

      <div className="cc-bottom-ticker">
        <strong>Live AI Insights</strong>
        <span>Rata-rata baterai perangkat petugas lapangan aman. {stats.online} petugas sedang online dalam batas penugasan wilayah Labura.</span>
        <em></em>
      </div>
    </main>
  );
}

function LiveMap({ points, assignments = [], targetPoints = [], layers = { satellite: true, assignments: true, targets: false }, onSelectPoint }) {
  const mapRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const baseLayerRef = useRef(null);
  const overlayLayerRef = useRef(null);
  const [laburaGeoJson, setLaburaGeoJson] = useState(null);

  useEffect(() => {
    let cancelled = false;

    async function loadLaburaGeoJson() {
      try {
        const response = await fetch("/labura.geojson");
        if (!response.ok) return;
        const data = await response.json();
        const features = Array.isArray(data.features)
          ? data.features.filter((feature) => {
              const properties = JSON.stringify(feature.properties || {}).toLowerCase();
              return properties.includes("labuhanbatu utara") || properties.includes("labuhan batu utara");
            })
          : [];

        if (!cancelled) {
          setLaburaGeoJson({
            type: "FeatureCollection",
            features: features.length ? features : []
          });
        }
      } catch (error) {
        console.warn("Gagal memuat labura.geojson", error);
      }
    }

    loadLaburaGeoJson();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let mounted = true;

    async function setupMap() {
      const L = await import("leaflet");
      if (!mounted || !mapRef.current || mapInstanceRef.current) return;

      const map = L.map(mapRef.current, { zoomControl: true }).setView([2.3274, 99.8492], 11);
      baseLayerRef.current = L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
        attribution: "Tiles &copy; Esri"
      }).addTo(map);
      overlayLayerRef.current = L.layerGroup().addTo(map);
      mapInstanceRef.current = map;
    }

    setupMap();

    return () => {
      mounted = false;
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    async function renderMarkers() {
      if (!mapInstanceRef.current || !overlayLayerRef.current) return;
      const L = await import("leaflet");
      const map = mapInstanceRef.current;
      overlayLayerRef.current.clearLayers();

      if (baseLayerRef.current) {
        map.removeLayer(baseLayerRef.current);
      }

      baseLayerRef.current = layers.satellite
        ? L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
            attribution: "Tiles &copy; Esri"
          })
        : L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: "OpenStreetMap"
          });
      baseLayerRef.current.addTo(map);

      if (layers.assignments) {
        if (laburaGeoJson?.features?.length) {
          const geoLayer = L.geoJSON(laburaGeoJson, {
            style: {
              color: "#ff7a1a",
              weight: 3,
              opacity: 0.95,
              fillColor: "#ff7a1a",
              fillOpacity: 0.08
            },
            onEachFeature: (feature, layer) => {
              const name = feature.properties?.nama || feature.properties?.kab_kota || "Kabupaten Labuhanbatu Utara";
              layer.bindPopup(`<strong>Wilayah Tugas</strong><br/>${name}`);
            }
          }).addTo(overlayLayerRef.current);

          if (!points.length) {
            map.fitBounds(geoLayer.getBounds().pad(0.12));
          }
        } else {
          assignments.forEach((assignment, index) => {
            const region = laburaKecamatan.find((item) => item.name === assignment.kecamatan);
            if (!region?.center) return;
            const circle = L.circle(region.center, {
              radius: 1400 + (index % 4) * 380,
              color: "#ff7a1a",
              weight: 2,
              dashArray: "8 8",
              fillColor: "#ff7a1a",
              fillOpacity: 0.08
            }).addTo(overlayLayerRef.current);
            circle.bindPopup(`<strong>Wilayah Tugas</strong><br/>${assignment.officer_name || "Petugas"}<br/>${assignment.kecamatan}, ${assignment.desa}<br/>SLS ${assignment.sls}`);
          });
        }
      }

      if (layers.targets) {
        const visibleTargets = targetPoints.length
          ? targetPoints
          : laburaRegions.slice(0, 12).map((item, index) => ({
              id: `region-target-${index}`,
              label: item.sls,
              kecamatan: item.kecamatan,
              desa: item.desa
            }));

        visibleTargets.forEach((target) => {
          const region = laburaKecamatan.find((item) => item.name === target.kecamatan);
          const lat = Number(target.latitude) || region?.center?.[0];
          const lng = Number(target.longitude) || region?.center?.[1];
          if (!lat || !lng) return;
          const marker = L.circleMarker([lat, lng], {
            radius: 6,
            color: "#ffffff",
            weight: 2,
            fillColor: "#155eef",
            fillOpacity: 0.9
          }).addTo(overlayLayerRef.current);
          marker.bindPopup(`<strong>Titik Sasaran</strong><br/>${target.label || target.target_code || "-"}<br/>${target.kecamatan || "-"}, ${target.desa || "-"}`);
        });
      }

      const markers = points.map((point) => {
        const marker = L.circleMarker([point.latitude, point.longitude], {
          radius: 9,
          color: "#fff",
          weight: 3,
          fillColor: point.accuracy > 30 ? "#ff7a1a" : "#11b981",
          fillOpacity: 0.95
        }).addTo(overlayLayerRef.current);
        marker.bindPopup(`
          <strong>${point.officer_name}</strong><br/>
          ${point.kecamatan}, ${point.desa}<br/>
          Akurasi ${point.accuracy}m<br/>
          Update ${formatDate(point.recorded_at)}
        `);
        marker.on("click", () => onSelectPoint?.(point));
        return marker;
      });

      if (markers.length) {
        const group = L.featureGroup(markers);
        map.fitBounds(group.getBounds().pad(0.25));
      }
    }

    renderMarkers();
  }, [points, assignments, targetPoints, layers, laburaGeoJson]);

  return <div ref={mapRef} className="leaflet-map" />;
}

function HistoryMap({ points }) {
  const mapRef = useRef(null);
  const mapInstanceRef = useRef(null);

  useEffect(() => {
    let mounted = true;

    async function setupMap() {
      const L = await import("leaflet");
      if (!mounted || !mapRef.current || mapInstanceRef.current) return;

      const map = L.map(mapRef.current, { zoomControl: true }).setView([2.3274, 99.8492], 11);
      L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
        attribution: "Tiles &copy; Esri"
      }).addTo(map);
      mapInstanceRef.current = map;
    }

    setupMap();

    return () => {
      mounted = false;
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    async function renderTrack() {
      if (!mapInstanceRef.current) return;
      const L = await import("leaflet");
      const map = mapInstanceRef.current;

      map.eachLayer((layer) => {
        if (layer instanceof L.CircleMarker || layer instanceof L.Polyline) {
          map.removeLayer(layer);
        }
      });

      const orderedPoints = [...points].sort((a, b) => new Date(a.recorded_at) - new Date(b.recorded_at));
      const latlngs = orderedPoints.map((point) => [point.latitude, point.longitude]);

      if (latlngs.length > 1) {
        L.polyline(latlngs, {
          color: "#071426",
          weight: 9,
          opacity: 0.28
        }).addTo(map);
        L.polyline(latlngs, {
          color: "#ff7a1a",
          weight: 5,
          opacity: 0.95
        }).addTo(map);
      }

      const markers = orderedPoints.map((point, index) => {
        const isEdge = index === 0 || index === orderedPoints.length - 1;
        const marker = L.circleMarker([point.latitude, point.longitude], {
          radius: isEdge ? 9 : 6,
          color: "#ffffff",
          weight: isEdge ? 3 : 2,
          fillColor: point.is_outside_sls ? "#ef4444" : isEdge ? "#ff7a1a" : "#12b981",
          fillOpacity: 0.95
        }).addTo(map);
        marker.bindPopup(`
          <strong>${point.officer_name || "Petugas"}</strong><br/>
          ${point.kecamatan || "-"}, ${point.desa || "-"}<br/>
          SLS ${point.sls || "-"}<br/>
          Akurasi ${point.accuracy || 0}m<br/>
          Update ${formatDate(point.recorded_at)}
        `);
        return marker;
      });

      if (markers.length) {
        const group = L.featureGroup(markers);
        map.fitBounds(group.getBounds().pad(0.22));
      } else {
        map.setView([2.3274, 99.8492], 11);
      }
    }

    renderTrack();
  }, [points]);

  return <div ref={mapRef} className="history-map" />;
}

function RiwayatJejak({ rows, profiles }) {
  const [selectedOfficer, setSelectedOfficer] = useState("");
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().slice(0, 10));
  const [showTrack, setShowTrack] = useState(true);
  const officerOptions = profiles.filter((item) => item.role === "petugas" || !item.role);
  const selectedOfficerProfile = officerOptions.find((item) => item.id === selectedOfficer);
  const filteredRows = useMemo(() => {
    return rows.filter((item) => {
      const byOfficer = selectedOfficer ? item.officer_id === selectedOfficer : true;
      const byDate = selectedDate ? new Date(item.recorded_at).toISOString().slice(0, 10) === selectedDate : true;
      return byOfficer && byDate;
    });
  }, [rows, selectedOfficer, selectedDate]);
  const orderedRows = useMemo(() => {
    return [...filteredRows].sort((a, b) => new Date(a.recorded_at) - new Date(b.recorded_at));
  }, [filteredRows]);
  const totalAccuracy = filteredRows.reduce((sum, item) => sum + Number(item.accuracy || 0), 0);
  const averageAccuracy = filteredRows.length ? Math.round(totalAccuracy / filteredRows.length) : 0;
  const outsideCount = filteredRows.filter((item) => item.is_outside_sls || item.geofence_status === "outside_sls").length;
  const currentPoint = orderedRows[orderedRows.length - 1];
  const officerName = currentPoint?.officer_name || selectedOfficerProfile?.full_name || "Pilih petugas";
  const startAt = orderedRows[0]?.recorded_at;
  const endAt = orderedRows[orderedRows.length - 1]?.recorded_at;

  function exportTrackSummary() {
    const worksheet = XLSX.utils.json_to_sheet(filteredRows.map((item) => ({
      Waktu: formatDate(item.recorded_at),
      Petugas: item.officer_name || selectedOfficerProfile?.full_name || "-",
      Survei: item.survey_type || "-",
      Kecamatan: item.kecamatan || "-",
      Desa: item.desa || "-",
      SLS: item.sls || "-",
      Latitude: item.latitude,
      Longitude: item.longitude,
      Akurasi: item.accuracy || 0,
      Status: item.is_outside_sls || item.geofence_status === "outside_sls" ? "Di luar SLS" : "Dalam batas"
    })));
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, "Rekap Jejak");
    XLSX.writeFile(workbook, "rekap-jejak-petugas.xlsx");
  }

  return (
    <Panel title="Riwayat Jejak Petugas" action={<button className="btn ghost" onClick={exportTrackSummary}><FileDown size={16} /> Export</button>}>
      <div className="history-layout">
        <div className="history-map-shell">
          <HistoryMap points={showTrack ? orderedRows : []} />
          {currentPoint && showTrack && (
            <div className="history-point-card">
              <div className="history-point-avatar"><UserCheck size={18} /></div>
              <div>
                <strong>{officerName}</strong>
                <span>{formatTimeOnly(currentPoint.recorded_at)}</span>
              </div>
              <dl>
                <div><dt>Progres:</dt><dd>{outsideCount}/{filteredRows.length} ({filteredRows.length ? Math.round((outsideCount / filteredRows.length) * 100) : 0}%)</dd></div>
                <div><dt>Kecepatan:</dt><dd>{Number(currentPoint.speed || 0).toFixed(1)} km/h</dd></div>
                <div><dt>Akurasi:</dt><dd>{Number(currentPoint.accuracy || 0).toFixed(1)}m</dd></div>
              </dl>
            </div>
          )}
          {!filteredRows.length && (
            <div className="history-empty-state">
              <strong>Belum ada jejak pada filter ini</strong>
              <span>Pilih petugas/tanggal lain atau tunggu data tracking masuk dari aplikasi Android.</span>
            </div>
          )}
          <div className="history-playback">
            <button className="history-play-button" type="button" aria-label="Putar jejak"><Play size={18} fill="currentColor" /></button>
            <button className="history-reset-button" type="button" aria-label="Ulangi jejak"><RotateCcw size={18} /></button>
            <strong>{formatTimeOnly(endAt || startAt)}</strong>
            <div className="history-progress"><span style={{ width: filteredRows.length ? "94%" : "0%" }} /></div>
            <select aria-label="Kecepatan playback" defaultValue="1x Speed">
              <option>1x Speed</option>
              <option>2x Speed</option>
              <option>4x Speed</option>
            </select>
          </div>
        </div>

        <aside className="history-sidebar">
          <label>
            Pilih Kabupaten
            <select defaultValue="Kab. Labuhanbatu Utara">
              <option value="Kab. Labuhanbatu Utara">KAB. LABUHANBATU UTARA</option>
            </select>
          </label>

          <label>
            Pilih Petugas
            <select value={selectedOfficer} onChange={(event) => setSelectedOfficer(event.target.value)}>
              <option value="">Semua Petugas</option>
              {officerOptions.map((item) => <option key={item.id} value={item.id}>{item.full_name}</option>)}
            </select>
          </label>

          <label>
            Pilih Tanggal
            <input type="date" value={selectedDate} onChange={(event) => setSelectedDate(event.target.value)} />
          </label>

          <button className="btn primary history-submit" onClick={() => setShowTrack(true)}>
            <Search size={16} /> Tampilkan Jejak
          </button>

          <button className="btn outline history-export-all" onClick={exportTrackSummary}>
            <Download size={16} /> Export Rekap Semua
          </button>

          <button className="btn ghost history-toggle" onClick={() => setShowTrack((value) => !value)}>
            {showTrack ? "Sembunyikan Jejak" : "Lihat Jejak"}
          </button>

          <div className="history-summary">
            <h4><Zap size={15} /> Ringkasan Harian</h4>
            <div>
              <span>Total Titik</span>
              <strong>{filteredRows.length} koordinat</strong>
            </div>
            <div>
              <span>Rerata Akurasi</span>
              <strong>{averageAccuracy}m</strong>
            </div>
            <div>
              <span>Di Luar SLS</span>
              <strong>{outsideCount ? `${outsideCount} titik` : "Dalam Batas (0 menit)"}</strong>
            </div>
          </div>
        </aside>
      </div>

      <DataTable
        headers={["Waktu", "Petugas", "Survei", "Wilayah", "SLS", "Koordinat", "Status"]}
        rows={filteredRows.slice(0, 40).map((item) => [
          formatDate(item.recorded_at),
          item.officer_name,
          item.survey_type,
          `${item.kecamatan} / ${item.desa}`,
          item.sls,
          `${Number(item.latitude).toFixed(5)}, ${Number(item.longitude).toFixed(5)}`,
          <TrackingStatus key={item.id} item={item} />
        ])}
      />
    </Panel>
  );
}

function RiwayatAbsensi({ rows, profiles }) {
  const [selectedSurvey, setSelectedSurvey] = useState("");
  const [query, setQuery] = useState("");
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().slice(0, 10));
  const [rowLimit, setRowLimit] = useState("20");
  const profileById = new Map(profiles.map((item) => [item.id || item.officer_code, item]));
  const filteredRows = useMemo(() => {
    return rows.filter((item) => {
      const profile = profileById.get(item.officer_id) || {};
      const searchable = `${item.officer_name || ""} ${item.email || ""} ${profile.email || ""} ${item.officer_id || ""}`.toLowerCase();
      const bySurvey = selectedSurvey ? (item.survey_type || item.survey || "") === selectedSurvey : true;
      const byQuery = query ? searchable.includes(query.toLowerCase()) : true;
      const byDate = selectedDate ? (item.check_in_at || item.created_at || "").slice(0, 10) === selectedDate : true;
      return bySurvey && byQuery && byDate;
    });
  }, [rows, profileById, selectedSurvey, query, selectedDate]);
  const visibleRows = filteredRows.slice(0, Number(rowLimit));

  function resetFilters() {
    setSelectedSurvey("");
    setQuery("");
    setSelectedDate(new Date().toISOString().slice(0, 10));
    setRowLimit("20");
  }

  function exportAttendance(filename, dataRows) {
    const worksheet = XLSX.utils.json_to_sheet(dataRows);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, "Riwayat Absensi");
    XLSX.writeFile(workbook, filename);
  }

  function exportDetail() {
    exportAttendance("riwayat-absensi-detail.xlsx", filteredRows.map((item) => ({
      Petugas: item.officer_name || "-",
      Email: item.email || profileById.get(item.officer_id)?.email || "-",
      Tanggal: formatDateOnly(item.check_in_at || item.created_at),
      "Mulai Tracking": formatTimeOnly(item.check_in_at),
      "Selesai Tracking": item.check_out_at ? formatTimeOnly(item.check_out_at) : "-",
      "Status Sesi": item.status === "complete" ? "Selesai" : "Berjalan",
      Durasi: formatDuration(item.check_in_at, item.check_out_at)
    })));
  }

  function exportSummary() {
    const complete = filteredRows.filter((item) => item.status === "complete" || item.check_out_at).length;
    const running = Math.max(0, filteredRows.length - complete);
    exportAttendance("ringkasan-presensi.xlsx", [
      { Indikator: "Total Presensi", Nilai: filteredRows.length },
      { Indikator: "Sesi Selesai", Nilai: complete },
      { Indikator: "Sesi Berjalan", Nilai: running },
      { Indikator: "Tanggal", Nilai: selectedDate || "Semua Tanggal" }
    ]);
  }

  return (
    <section className="attendance-page">
      <div className="attendance-titlebar">
        <div>
          <h3>Riwayat Absensi</h3>
          <p>Pantau rekaman waktu check-in, check-out, dan durasi penugasan harian petugas secara dinamis.</p>
        </div>
        <button className="btn plain" onClick={resetFilters}><RefreshCw size={15} /> Refresh</button>
      </div>

      <div className="attendance-card">
        <div className="attendance-filters">
          <label>
            <span><Layers size={14} /> Kegiatan Survei</span>
            <select value={selectedSurvey} onChange={(event) => setSelectedSurvey(event.target.value)}>
              <option value="">Semua Survei</option>
              {surveyTypes.map((item) => <option key={item} value={item}>{item}</option>)}
            </select>
          </label>
          <label>
            <span><Search size={14} /> Cari Nama / Email</span>
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Ketik nama atau email..." />
          </label>
          <label>
            <span><CalendarCheck size={14} /> Tanggal</span>
            <input type="date" value={selectedDate} onChange={(event) => setSelectedDate(event.target.value)} />
          </label>
          <label>
            <span><ClipboardList size={14} /> Tampilkan Baris</span>
            <select value={rowLimit} onChange={(event) => setRowLimit(event.target.value)}>
              <option value="20">20 Baris</option>
              <option value="50">50 Baris</option>
              <option value="100">100 Baris</option>
            </select>
          </label>
        </div>

        <div className="attendance-actions">
          <button className="btn ghost" onClick={resetFilters}>Reset</button>
          <div>
            <button className="btn outline" onClick={exportDetail}><FileDown size={16} /> Export Detail XLS</button>
            <button className="btn dark" onClick={exportSummary}><FileDown size={16} /> Export Ringkasan Presensi</button>
          </div>
        </div>

        <div className="attendance-table table-wrap">
          <table>
            <thead>
              <tr>
                {["Petugas", "Tanggal", "Mulai Tracking", "Selesai Tracking", "Status Sesi", "Durasi"].map((header) => <th key={header}>{header}</th>)}
              </tr>
            </thead>
            <tbody>
              {visibleRows.length ? visibleRows.map((item) => (
                <tr key={item.id || `${item.officer_id}-${item.check_in_at}`}>
                  <td>{item.officer_name || "-"}</td>
                  <td>{formatDateOnly(item.check_in_at || item.created_at)}</td>
                  <td>{formatTimeOnly(item.check_in_at)}</td>
                  <td>{item.check_out_at ? formatTimeOnly(item.check_out_at) : "-"}</td>
                  <td><Badge tone={item.status === "complete" ? "green" : "orange"}>{item.status === "complete" ? "Selesai" : "Berjalan"}</Badge></td>
                  <td>{formatDuration(item.check_in_at, item.check_out_at)}</td>
                </tr>
              )) : (
                <tr>
                  <td colSpan={6}>
                    <div className="attendance-loading">
                      <span />
                      <strong>Menyelaraskan data absensi...</strong>
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}

function ManajemenPengguna({ profiles, setProfiles }) {
  const [query, setQuery] = useState("");
  const [kabupatenFilter, setKabupatenFilter] = useState("Kab. Labuhanbatu Utara");
  const [kecamatanFilter, setKecamatanFilter] = useState("");
  const [desaFilter, setDesaFilter] = useState("");
  const [surveyFilter, setSurveyFilter] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [form, setForm] = useState({
    full_name: "",
    email: "",
    password: "",
    id: "",
    phone: "",
    role: "petugas",
    survey_type: surveyTypes[0],
    kabupaten: "Kab. Labuhanbatu Utara",
    kecamatan_code: "",
    desa_code: "",
    kecamatan: laburaKecamatan[0].name,
    desa: laburaKecamatan[0].desa[0]
  });
  const importRef = useRef(null);
  const desaOptions = getDesaOptions(kecamatanFilter);
  const formDesaOptions = getDesaOptions(form.kecamatan);
  const roleOptions = [
    ["petugas", "Petugas"],
    ["pegawai", "Pegawai"],
    ["supervisor", "Supervisor"],
    ["admin_kabkot", "Admin Kab/Kot"]
  ];

  const filteredProfiles = profiles.filter((item) => {
    const search = `${item.full_name || ""} ${item.email || ""} ${item.id || ""}`.toLowerCase();
    const byQuery = query ? search.includes(query.toLowerCase()) : true;
    const byKabupaten = kabupatenFilter ? (item.kabupaten || "Kab. Labuhanbatu Utara") === kabupatenFilter : true;
    const byKecamatan = kecamatanFilter ? item.kecamatan === kecamatanFilter : true;
    const byDesa = desaFilter ? item.desa === desaFilter : true;
    const bySurvey = surveyFilter ? item.survey_type === surveyFilter : true;
    const byStatus = statusFilter === "all"
      ? true
      : statusFilter === "petugas"
        ? item.role === "petugas"
        : statusFilter === "pending"
          ? item.status === "pending"
          : item.status === statusFilter;
    return byQuery && byKabupaten && byKecamatan && byDesa && bySurvey && byStatus;
  });

  async function approve(id) {
    if (hasSupabaseConfig && supabase) {
      const { error } = await supabase
        .from("profiles")
        .update({ status: "approved", approved_at: new Date().toISOString() })
        .eq("id", id);
      if (error) {
        alert(`Gagal approve akun: ${error.message}`);
        return;
      }
    }
    setProfiles((current) => current.map((item) => item.id === id ? { ...item, status: "approved" } : item));
  }

  async function approveAll() {
    const pendingIds = profiles.filter((item) => item.status === "pending").map((item) => item.id);
    if (!pendingIds.length) return;

    if (hasSupabaseConfig && supabase) {
      const { error } = await supabase
        .from("profiles")
        .update({ status: "approved", approved_at: new Date().toISOString() })
        .in("id", pendingIds);
      if (error) {
        alert(`Gagal approve semua akun: ${error.message}`);
        return;
      }
    }
    setProfiles((current) => current.map((item) => item.status === "pending" ? { ...item, status: "approved" } : item));
  }

  function removeUser(id) {
    setProfiles((current) => current.filter((item) => item.id !== id));
  }

  async function addUser() {
    if (!form.full_name || !form.email || !form.password || !form.role) {
      alert("Nama, email, password, dan role wajib diisi.");
      return;
    }

    if (form.password.length < 6) {
      alert("Password minimal 6 karakter.");
      return;
    }

    const normalizedEmail = form.email.trim().toLowerCase();
    const officerCode = (form.id || normalizedEmail.split("@")[0] || `USR-${Date.now()}`).toUpperCase();
    let authUserId = null;

    if (hasSupabaseConfig && supabase && supabaseUrl && supabaseAnonKey) {
      const signupResponse = await fetch(`${supabaseUrl}/auth/v1/signup`, {
        method: "POST",
        headers: {
          apikey: supabaseAnonKey,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          email: normalizedEmail,
          password: form.password
        })
      });

      if (signupResponse.status === 429) {
        alert("Supabase menolak signup karena terlalu banyak percobaan. Tunggu beberapa menit atau buat user manual di Supabase Auth.");
        return;
      }

      if (signupResponse.ok) {
        const authData = await signupResponse.json();
        authUserId = authData.id || authData.user?.id || null;
      } else {
        const loginResponse = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
          method: "POST",
          headers: {
            apikey: supabaseAnonKey,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            email: normalizedEmail,
            password: form.password
          })
        });

        if (!loginResponse.ok) {
          const errorText = await loginResponse.text();
          alert(`Gagal membuat Auth user: ${errorText}`);
          return;
        }

        const loginData = await loginResponse.json();
        authUserId = loginData.user?.id || null;
      }

      if (!authUserId) {
        alert("Auth user berhasil dibuat, tetapi ID user tidak terbaca.");
        return;
      }

      const payload = {
        auth_user_id: authUserId,
        officer_code: officerCode,
        full_name: form.full_name,
        email: normalizedEmail,
        phone: form.phone || null,
        role: form.role === "pegawai" ? "petugas" : form.role,
        status: "approved",
        kecamatan: form.kecamatan || "Labuhanbatu Utara",
        approved_at: new Date().toISOString()
      };

      const { data, error } = await supabase
        .from("profiles")
        .upsert(payload, { onConflict: "email" })
        .select("*")
        .single();

      if (error) {
        alert(`Gagal menyimpan profile: ${error.message}`);
        return;
      }

      setProfiles((current) => [
        {
          ...data,
          display_id: data.officer_code,
          kabupaten: form.kabupaten || "Kab. Labuhanbatu Utara",
          survey_type: form.survey_type,
          desa: form.desa,
          kecamatan: data.kecamatan || form.kecamatan
        },
        ...current.filter((item) => item.email !== normalizedEmail)
      ]);
    } else {
      setProfiles((current) => [
        {
          ...form,
          id: `local-${Date.now()}`,
          display_id: officerCode,
          role: form.role,
          kabupaten: form.kabupaten || "Kab. Labuhanbatu Utara",
          status: "approved",
          created_at: new Date().toISOString()
        },
        ...current
      ]);
    }

    setForm({
      full_name: "",
      email: "",
      password: "",
      id: "",
      phone: "",
      role: "petugas",
      survey_type: surveyTypes[0],
      kabupaten: "Kab. Labuhanbatu Utara",
      kecamatan_code: "",
      desa_code: "",
      kecamatan: laburaKecamatan[0].name,
      desa: laburaKecamatan[0].desa[0]
    });
    setShowCreateModal(false);
  }

  function exportUsers() {
    const headers = ["id", "full_name", "email", "phone", "role", "kabupaten", "kecamatan", "desa", "survey_type", "status"];
    const rows = profiles.map((item) => headers.map((key) => `"${String(item[key] ?? "").replaceAll('"', '""')}"`).join(","));
    const csvContent = [headers.join(","), ...rows].join("\n");
    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a");
    link.href = URL.createObjectURL(blob);
    link.download = "pengguna-mardalan-labura.csv";
    link.click();
    URL.revokeObjectURL(link.href);
  }

  function valueFrom(record, keys) {
    const foundKey = keys.find((key) => record[key] !== undefined && record[key] !== null && record[key] !== "");
    return foundKey ? String(record[foundKey]).trim() : "";
  }

  function normalizeImportedUser(record, index) {
    const kecamatanCode = valueFrom(record, ["Kode Kecamatan", "kode_kecamatan", "kecamatan_code"]);
    const desaCode = valueFrom(record, ["Kode Desa", "kode_desa", "desa_code"]);
    const role = valueFrom(record, ["Nama Role (pegawai/petugas)", "role", "Nama Role"]) || "petugas";
    const kecamatan = valueFrom(record, ["Kecamatan", "kecamatan"]) || laburaKecamatan[0].name;

    return {
      id: valueFrom(record, ["id", "ID", "NIP", "NIK"]) || `USR-${Date.now()}-${index + 1}`,
      full_name: valueFrom(record, ["Nama Lengkap", "full_name", "nama_lengkap", "Nama"]) || "Petugas Baru",
      email: valueFrom(record, ["Email", "email"]),
      password: valueFrom(record, ["Password (Min 6 Karakter)", "password", "Password"]),
      phone: valueFrom(record, ["No HP", "phone", "No. HP", "Nomor HP"]),
      role,
      kabupaten: valueFrom(record, ["Kabupaten", "kabupaten"]) || "Kab. Labuhanbatu Utara",
      kabupaten_code: valueFrom(record, ["Kode Kabupaten", "kode_kabupaten", "kabupaten_code"]),
      kecamatan_code: kecamatanCode,
      desa_code: desaCode,
      kecamatan,
      desa: valueFrom(record, ["Desa", "desa"]) || getDesaOptions(kecamatan)[0] || "",
      survey_type: valueFrom(record, ["survey_type", "Survei"]) || surveyTypes[0],
      status: valueFrom(record, ["status", "Status"]) || "pending",
      created_at: new Date().toISOString()
    };
  }

  async function importUsers(event) {
    const file = event.target.files?.[0];
    if (!file) return;

    const buffer = await file.arrayBuffer();
    const workbook = XLSX.read(buffer, { type: "array" });
    const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
    const records = XLSX.utils.sheet_to_json(firstSheet, { defval: "" });
    const imported = records
      .map((record, index) => normalizeImportedUser(record, index))
      .filter((record) => record.full_name || record.email);

    if (imported.length) {
      setProfiles((current) => [...imported, ...current]);
    }

    event.target.value = "";
  }

  return (
    <div className="user-management">
      <div className="user-header-actions">
        <button className="btn success" onClick={approveAll}><CheckCircle2 size={16} /> Setujui Semua</button>
        <button className="btn ghost" onClick={() => importRef.current?.click()}><Database size={16} /> Import Pengguna</button>
        <a className="btn ghost" href="/template_import_pengguna.xlsx" download><FileSpreadsheet size={16} /> Template</a>
        <button className="btn ghost" onClick={exportUsers}><FileDown size={16} /> Export Pengguna</button>
        <button className="btn dark" onClick={() => setShowCreateModal(true)}><UserPlus size={16} /> Tambah Pengguna</button>
        <input ref={importRef} type="file" accept=".xlsx,.xls,.csv,text/csv" hidden onChange={importUsers} />
      </div>

      <Panel>
        <div className="user-toolbar user-toolbar-primary">
          <div className="search-box"><Search size={16} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Cari nama atau email..." /></div>
          <label className="toolbar-select"><MapPin size={16} /><select value={kabupatenFilter} onChange={(event) => setKabupatenFilter(event.target.value)}><option value="">Semua Kabupaten</option><option value="Kab. Labuhanbatu Utara">KAB. LABUHANBATU UTARA</option></select></label>
          <label className="toolbar-select"><MapPin size={16} /><select value={kecamatanFilter} onChange={(event) => { setKecamatanFilter(event.target.value); setDesaFilter(""); }}><option value="">Semua Kecamatan</option>{laburaKecamatan.map((item) => <option key={item.name} value={item.name}>{item.name}</option>)}</select></label>
          <label className="toolbar-select"><MapPin size={16} /><select value={desaFilter} onChange={(event) => setDesaFilter(event.target.value)}><option value="">Semua Desa</option>{desaOptions.map((item) => <option key={item} value={item}>{item}</option>)}</select></label>
        </div>

        <div className="user-toolbar user-toolbar-secondary">
          <label className="toolbar-select"><Layers size={16} /><select value={surveyFilter} onChange={(event) => setSurveyFilter(event.target.value)}><option value="">Semua Survei</option>{surveyTypes.map((item) => <option key={item} value={item}>{item}</option>)}</select></label>
          <div className="segmented-control">
            <button className={statusFilter === "all" ? "active" : ""} onClick={() => setStatusFilter("all")}>Semua</button>
            <button className={statusFilter === "petugas" ? "active" : ""} onClick={() => setStatusFilter("petugas")}>Petugas</button>
            <button className={statusFilter === "pending" ? "active" : ""} onClick={() => setStatusFilter("pending")}>Menunggu Aktivasi</button>
          </div>
        </div>

        <div className="user-table-shell">
          <DataTable
            headers={["Pengguna", "Kontak", "Akses & Wilayah", "Status", "Aksi"]}
            rows={filteredProfiles.map((item) => [
              <div key={`${item.id}-user`} className="user-cell">
                <span className="avatar user-avatar">{(item.full_name || "P").charAt(0)}</span>
                <div><strong>{item.full_name}</strong><small>#{item.display_id || item.officer_code || item.id}</small></div>
              </div>,
              <div key={`${item.id}-contact`} className="contact-cell">
                <span><Mail size={13} /> {item.email}</span>
                <span><Phone size={13} /> {item.phone || "-"}</span>
              </div>,
              <div key={`${item.id}-access`} className="access-cell">
                <strong><ShieldCheck size={13} /> {roleOptions.find(([value]) => value === item.role)?.[1] || item.role || "Petugas"}</strong>
                <span><MapPin size={13} /> {item.kabupaten || "KAB. LABUHANBATU UTARA"}</span>
              </div>,
              <Badge key={`${item.id}-status`} tone={item.status === "approved" ? "green" : item.status === "pending" ? "orange" : "red"}>
                {item.status === "approved" ? "Aktif" : item.status === "pending" ? "Menunggu" : item.status}
              </Badge>,
              <div key={`${item.id}-actions`} className="row-actions">
                {item.status === "pending" && <button className="icon-btn success-icon" onClick={() => approve(item.id)} title="Approve"><CheckCircle2 size={16} /></button>}
                <button className="icon-btn" title="Edit"><Pencil size={15} /></button>
                <button className="icon-btn danger-icon" onClick={() => removeUser(item.id)} title="Hapus"><Trash2 size={15} /></button>
              </div>
            ])}
          />
        </div>
      </Panel>

      {showCreateModal && (
        <div className="modal-backdrop user-modal-backdrop">
          <div className="modal user-create-modal">
            <div className="modal-header">
              <h3>Tambah Pengguna Baru</h3>
              <button className="icon-btn modal-close" onClick={() => setShowCreateModal(false)} title="Tutup"><X size={20} /></button>
            </div>
            <div className="user-form-grid">
              <label className="field full">
                <span>Nama Lengkap *</span>
                <input value={form.full_name} onChange={(event) => setForm({ ...form, full_name: event.target.value })} placeholder="Contoh: Budi Santoso" />
              </label>
              <label className="field">
                <span>Email *</span>
                <input type="email" value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} placeholder="user@bps.go.id" />
              </label>
              <label className="field">
                <span>No. HP</span>
                <input value={form.phone} onChange={(event) => setForm({ ...form, phone: event.target.value })} placeholder="0812..." />
              </label>
              <label className="field">
                <span>Password *</span>
                <input type="password" value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} placeholder="Min. 6 karakter" />
              </label>
              <label className="field">
                <span>Role *</span>
                <select value={form.role} onChange={(event) => setForm({ ...form, role: event.target.value })}>
                  <option value="">Pilih Hak Akses</option>
                  {roleOptions.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
              </label>
            </div>
            <div className="assignment-section">
              <h4><MapPin size={16} /> Lokasi Penugasan</h4>
              <div className="user-form-grid user-location-grid">
                <label className="field">
                  <span>Kabupaten</span>
                  <select value={form.kabupaten} onChange={(event) => setForm({ ...form, kabupaten: event.target.value })}>
                    <option value="Kab. Labuhanbatu Utara">KAB. LABUHANBATU UTARA</option>
                  </select>
                </label>
                <label className="field">
                  <span>Kecamatan (Kode)</span>
                  <input value={form.kecamatan_code} onChange={(event) => setForm({ ...form, kecamatan_code: event.target.value })} placeholder="Contoh: 1201060" />
                </label>
                <label className="field">
                  <span>Desa (Kode)</span>
                  <input value={form.desa_code} onChange={(event) => setForm({ ...form, desa_code: event.target.value })} placeholder="Contoh: 1201060015" />
                </label>
                <label className="field">
                  <span>Kecamatan</span>
                  <select value={form.kecamatan} onChange={(event) => setForm({ ...form, kecamatan: event.target.value, desa: getDesaOptions(event.target.value)[0] || "" })}>
                    {laburaKecamatan.map((item) => <option key={item.name} value={item.name}>{item.name}</option>)}
                  </select>
                </label>
                <label className="field">
                  <span>Desa</span>
                  <select value={form.desa} onChange={(event) => setForm({ ...form, desa: event.target.value })}>
                    {formDesaOptions.map((item) => <option key={item} value={item}>{item}</option>)}
                  </select>
                </label>
                <label className="field">
                  <span>Survei</span>
                  <select value={form.survey_type} onChange={(event) => setForm({ ...form, survey_type: event.target.value })}>
                    {surveyTypes.map((item) => <option key={item} value={item}>{item}</option>)}
                  </select>
                </label>
              </div>
            </div>
            <div className="modal-actions user-modal-actions">
              <button className="btn plain" onClick={() => setShowCreateModal(false)}>Batal</button>
              <button className="btn dark" onClick={addUser}><Save size={16} /> Simpan Pengguna</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function WilayahTugas({ assignments, onAdd, onDelete }) {
  return (
    <Panel title="Manajemen Wilayah Tugas" action={<button className="btn primary" onClick={onAdd}><Plus size={16} /> Tambah Penugasan</button>}>
      <p className="note">Alokasi wilayah tugas hanya bisa dilakukan jika petugas sudah terdaftar dan sudah di-approve sebagai pengguna.</p>
      <DataTable
        headers={["Nama Petugas", "Survei Operasional", "Wilayah Kerja", "SLS", "Status", "Aksi"]}
        rows={assignments.map((item) => [
          item.officer_name,
          item.survey_type,
          `${item.kecamatan} / ${item.desa}`,
          item.sls,
          <Badge key={`${item.id}-status`} tone="blue">{item.status}</Badge>,
          <div key={`${item.id}-actions`} className="row-actions">
            <button className="icon-btn danger-icon" onClick={() => onDelete(item.id)} title="Hapus penugasan"><Trash2 size={15} /></button>
          </div>
        ])}
      />
    </Panel>
  );
}

function PlottingTim({ profiles, assignments }) {
  const [activeTab, setActiveTab] = useState("peta");
  const [teamQuery, setTeamQuery] = useState("");
  const [officerQuery, setOfficerQuery] = useState("");
  const [slsQuery, setSlsQuery] = useState("");
  const [selectedTeam, setSelectedTeam] = useState(assignments[0]?.officer_id || "");
  const [selectedPlotOfficer, setSelectedPlotOfficer] = useState(null);
  const [selectedSlsKey, setSelectedSlsKey] = useState("");
  const [showImportModal, setShowImportModal] = useState(false);
  const [showTeamManagerModal, setShowTeamManagerModal] = useState(false);
  const [importSurvey, setImportSurvey] = useState(surveyTypes[0]);
  const [importSummary, setImportSummary] = useState("");
  const plottingImportRef = useRef(null);

  const approvedOfficers = profiles.filter((item) => item.status === "approved" && (item.role === "petugas" || !item.role));
  const teams = approvedOfficers.map((officer, index) => {
    const officerAssignments = assignments.filter((item) => item.officer_id === officer.id);
    return {
      ...officer,
      assignmentCount: officerAssignments.length || 7 + (index % 3),
      survey: officerAssignments[0]?.survey_type || surveyTypes[index % surveyTypes.length]
    };
  });
  const filteredTeams = teams.filter((item) => `${item.full_name} ${item.id}`.toLowerCase().includes(teamQuery.toLowerCase()));
  const filteredOfficers = approvedOfficers.filter((item) => `${item.full_name} ${item.email}`.toLowerCase().includes(officerQuery.toLowerCase()));
  const slsItems = laburaRegions
    .filter((item) => `${item.sls} ${item.kecamatan} ${item.desa} ${item.kdsubsls || ""}`.toLowerCase().includes(slsQuery.toLowerCase()))
    .slice(0, 24);
  const selectedOfficer = approvedOfficers.find((item) => item.id === selectedTeam) || approvedOfficers[0];
  const plottingOfficer = selectedPlotOfficer || selectedOfficer;
  const selectedTeamIndex = Math.max(0, teams.findIndex((item) => item.id === selectedTeam));
  const selectedTeamMembers = approvedOfficers
    .filter((item) => item.id !== selectedTeam)
    .slice(selectedTeamIndex, selectedTeamIndex + 4);

  function selectOfficerForPlotting(officer) {
    setSelectedPlotOfficer(officer);
    setSelectedTeam(officer.id);
    setActiveTab("peta");
  }

  function resetPlotting() {
    setSelectedPlotOfficer(null);
    setSelectedSlsKey("");
    setOfficerQuery("");
    setSlsQuery("");
    setActiveTab("peta");
  }

  function openTeamManager() {
    setShowTeamManagerModal(true);
  }

  function chooseTeamManager(mode) {
    setActiveTab(mode);
    setOfficerQuery("");
    setShowTeamManagerModal(false);
  }

  async function importPlottingFile(event) {
    const file = event.target.files?.[0];
    if (!file) return;

    const buffer = await file.arrayBuffer();
    const workbook = XLSX.read(buffer, { type: "array" });
    const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
    const records = XLSX.utils.sheet_to_json(firstSheet, { defval: "" });
    setImportSummary(`${records.length} baris data plotting siap diproses untuk ${importSurvey}.`);
    event.target.value = "";
  }

  return (
    <div className="plotting-page">
      <section className="plotting-head">
        <div className="plotting-title">
          <UserCheck size={20} />
          <div>
            <h3>Plotting Tim & Penugasan</h3>
            <p>Klik ikon target pada petugas untuk memplotting wilayah kerja di peta.</p>
          </div>
        </div>
        <div className="plotting-controls">
          <label className="field compact">
            <span>Pilih Survei</span>
            <select defaultValue={surveyTypes[0]}>
              {surveyTypes.map((item) => <option key={item} value={item}>{item}</option>)}
            </select>
          </label>
          <label className="field compact">
            <span>Kabupaten</span>
            <select defaultValue="Kab. Labuhanbatu Utara">
              <option value="Kab. Labuhanbatu Utara">KAB. LABUHANBATU UTARA</option>
            </select>
          </label>
          <button className="btn ghost" data-testid="plotting-export"><Download size={16} /> Export</button>
          <button className="btn dark" data-testid="plotting-import" onClick={() => setShowImportModal(true)}><Import size={16} /> Import Data</button>
          <button className="btn danger-outline" data-testid="plotting-reset" onClick={resetPlotting}><Trash2 size={16} /> Reset Penugasan</button>
        </div>
      </section>

      <section className="plotting-workspace">
        <aside className="team-panel">
          <div className="team-panel-head">
            <strong><Users size={14} /> Daftar Tim</strong>
            <span>{filteredTeams.length} Pemeriksa</span>
            <button className="btn mini" data-testid="plotting-manage-team" onClick={openTeamManager}><UserCog size={14} /> Kelola</button>
          </div>
          <div className="search-box slim"><Search size={15} /><input value={teamQuery} onChange={(event) => setTeamQuery(event.target.value)} placeholder="Cari pemeriksa..." /></div>
          {!filteredTeams.length && (
            <div className="plotting-empty">Belum ada tim pemeriksa. Import plotting atau tambahkan petugas aktif terlebih dahulu.</div>
          )}
          <div className="team-list">
            {filteredTeams.map((item) => (
              <div className={`team-card ${selectedTeam === item.id ? "active" : ""}`} key={item.id}>
                <button className="team-card-main" onClick={() => setSelectedTeam(item.id)}>
                <span className="team-avatar">{(item.full_name || "P").charAt(0)}</span>
                <span><strong>{item.full_name}</strong><small>{item.assignmentCount} Petugas</small></span>
                <span className="team-arrow">{selectedTeam === item.id ? "v" : ">"}</span>
                </button>
                {selectedTeam === item.id && (
                  <div className="team-member-list">
                    {(selectedTeamMembers.length ? selectedTeamMembers : [item]).map((member) => (
                      <div className="team-member-row" key={`${item.id}-${member.id}`}>
                        <span>{member.full_name || "Petugas"}</span>
                        <button className="icon-btn" onClick={() => selectOfficerForPlotting(member)} title="Set sebagai target plotting wilayah"><Target size={14} /></button>
                        <button className="icon-btn danger-icon" onClick={() => setSelectedPlotOfficer(null)} title="Hapus dari tim"><Trash2 size={14} /></button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        </aside>

        <div className="plotting-main">
          <div className="plotting-tabs">
            <button className={activeTab === "petugas" ? "active" : ""} data-testid="plotting-tab-petugas" onClick={() => setActiveTab("petugas")}><UserCheck size={16} /> Petugas Bebas</button>
            <button className={activeTab === "peta" ? "active" : ""} data-testid="plotting-tab-peta" onClick={() => setActiveTab("peta")}><MapIcon size={16} /> Peta Wilayah</button>
          </div>

          {activeTab === "petugas" ? (
            <div className="free-officers">
              <div className="section-line">
                <strong>Petugas Tersedia ({filteredOfficers.length})</strong>
                {selectedOfficer && <span>Tim aktif: {selectedOfficer.full_name}</span>}
              </div>
              <div className="search-box plotting-search"><Search size={15} /><input value={officerQuery} onChange={(event) => setOfficerQuery(event.target.value)} placeholder="Cari..." /></div>
              {!filteredOfficers.length && (
                <div className="plotting-empty wide">Belum ada petugas aktif. Tambahkan pengguna atau import data pengguna terlebih dahulu.</div>
              )}
              <div className="officer-grid">
                {filteredOfficers.map((item) => (
                  <div className="officer-tile" key={item.id}>
                    <span className="officer-initial">{(item.full_name || "P").charAt(0)}</span>
                    <strong>{item.full_name}</strong>
                <button className="icon-btn" onClick={() => selectOfficerForPlotting(item)} title="Plotting petugas"><Target size={15} /></button>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="map-plotting">
              <aside className="sls-panel">
                <h4><MapPin size={16} /> Daftar Sub-SLS</h4>
                <div className="search-box slim"><Search size={15} /><input value={slsQuery} onChange={(event) => setSlsQuery(event.target.value)} placeholder="Cari nama/kode SLS..." /></div>
                <div className="sls-list">
                  {slsItems.map((item) => {
                    const slsKey = `${item.kecamatan}-${item.desa}-${item.sls}-${item.kdsubsls}`;
                    return (
                    <button key={slsKey} className={`sls-card ${selectedSlsKey === slsKey ? "active" : ""}`} onClick={() => setSelectedSlsKey(slsKey)}>
                      <strong>{item.sls}</strong>
                      <span>{item.desa}</span>
                      <small>{item.kecamatan} {item.kdsubsls ? `- ${item.kdsubsls}` : ""}</small>
                    </button>
                    );
                  })}
                </div>
              </aside>
              <div className="plotting-map-preview">
                <Target size={46} />
                <strong>
                  {plottingOfficer
                    ? `${plottingOfficer.full_name} siap diplotting. Pilih Sub-SLS di kiri untuk menandai wilayah kerja.`
                    : "Pilih petugas di kiri dengan ikon target untuk mulai memplotting wilayah."}
                </strong>
              </div>
            </div>
          )}
        </div>
      </section>

      {showImportModal && (
        <div className="modal-backdrop user-modal-backdrop">
          <div className="modal plotting-import-modal">
            <div className="modal-header">
              <h3><Upload size={22} /> Import Plotting Tim & Wilayah</h3>
              <button className="icon-btn modal-close" onClick={() => setShowImportModal(false)} title="Tutup"><X size={20} /></button>
            </div>
            <label className="field">
              <span>Survei Sasaran Import</span>
              <select value={importSurvey} onChange={(event) => setImportSurvey(event.target.value)}>
                {surveyTypes.map((item) => <option key={item} value={item}>{item}</option>)}
              </select>
            </label>
            <div className="import-dropzone">
              <FileSpreadsheet size={58} />
              <h4>Pilih File Data Plotting</h4>
              <p>Gunakan template Excel untuk melakukan import massal hubungan Petugas-Pemeriksa dan Plotting Wilayah SLS secara bersamaan.</p>
              <div className="dropzone-actions">
                <a className="btn ghost" href="/template_plotting_tim.xlsx" download><Download size={16} /> Unduh Template</a>
                <button className="btn dark" onClick={() => plottingImportRef.current?.click()}><Upload size={16} /> Pilih File Excel</button>
                <input ref={plottingImportRef} type="file" accept=".xlsx,.xls,.csv" hidden onChange={importPlottingFile} />
              </div>
              {importSummary && <span className="import-summary">{importSummary}</span>}
            </div>
          </div>
        </div>
      )}

      {showTeamManagerModal && (
        <div className="modal-backdrop user-modal-backdrop">
          <div className="modal plotting-manage-modal">
            <div className="modal-header">
              <h3><UserCog size={22} /> Pilih Kelola Tim Pemeriksa</h3>
              <button className="icon-btn modal-close" onClick={() => setShowTeamManagerModal(false)} title="Tutup"><X size={20} /></button>
            </div>
            <div className="manage-team-options">
              <button onClick={() => chooseTeamManager("petugas")}>
                <UserCheck size={24} />
                <strong>Kelola Petugas Bebas</strong>
                <span>Pilih petugas yang akan dimasukkan ke tim pemeriksa.</span>
              </button>
              <button onClick={() => chooseTeamManager("peta")}>
                <MapPinned size={24} />
                <strong>Kelola Plotting Wilayah</strong>
                <span>Pilih Sub-SLS dan wilayah tugas untuk tim aktif.</span>
              </button>
            </div>
            <div className="modal-actions">
              <button className="btn plain" onClick={() => setShowTeamManagerModal(false)}>Batal</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function AssignmentModal({ profiles, onClose, onSave }) {
  const approvedProfiles = profiles.filter((item) => item.status === "approved" && (item.role === "petugas" || !item.role));
  const [form, setForm] = useState({
    survey_type: surveyTypes[0],
    officer_id: approvedProfiles[0]?.id || "",
    kecamatan: laburaKecamatan[0].name,
    desa: laburaKecamatan[0].desa[0],
    sls: ""
  });

  const desaOptions = getDesaOptions(form.kecamatan);
  const slsOptions = getSlsOptions(form.kecamatan, form.desa);
  const selectedOfficer = approvedProfiles.find((item) => item.id === form.officer_id);
  const selectedSls = slsOptions.find((item) => item.value === form.sls);

  useEffect(() => {
    if (!form.officer_id && approvedProfiles[0]?.id) {
      setForm((current) => ({ ...current, officer_id: approvedProfiles[0].id }));
    }
  }, [approvedProfiles, form.officer_id]);

  async function save() {
    if (!selectedOfficer) {
      alert("Tambahkan dan approve petugas terlebih dahulu sebelum membuat penugasan.");
      return;
    }

    if (!form.sls.trim()) {
      alert("SLS wajib diisi sebelum menyimpan penugasan.");
      return;
    }

    const assignmentPayload = {
      survey_type: form.survey_type,
      officer_id: form.officer_id,
      kecamatan: form.kecamatan,
      desa: form.desa,
      sls: selectedSls?.sls || form.sls.trim(),
      status: "active"
    };

    let savedAssignment = {
      id: `ASG-${Date.now()}`,
      ...assignmentPayload,
      sls_label: selectedSls?.label || form.sls.trim(),
      kdsubsls: selectedSls?.kdsubsls || "",
      idsubsls: selectedSls?.idsubsls || "",
      officer_name: selectedOfficer?.full_name || "Petugas",
      profiles: {
        officer_code: selectedOfficer?.officer_code || selectedOfficer?.display_id,
        full_name: selectedOfficer?.full_name
      }
    };

    if (hasSupabaseConfig && supabase) {
      const { data, error } = await supabase
        .from("assignments")
        .insert(assignmentPayload)
        .select("*, profiles(officer_code, full_name)")
        .single();

      if (error) {
        alert(`Gagal menyimpan penugasan: ${error.message}`);
        return;
      }

      savedAssignment = {
        ...data,
        officer_id: data.profiles?.officer_code || data.officer_id,
        profile_id: data.officer_id,
        officer_name: data.profiles?.full_name || selectedOfficer?.full_name || "Petugas",
        sls_label: selectedSls?.label || data.sls,
        kdsubsls: selectedSls?.kdsubsls || "",
        idsubsls: selectedSls?.idsubsls || ""
      };
    }

    onSave(savedAssignment);
  }

  return (
    <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-header">
          <h3>Tambah Penugasan Wilayah</h3>
          <button className="icon-btn" onClick={onClose}>x</button>
        </div>
        <div className="form-grid">
          <Select label="Survei" value={form.survey_type} onChange={(survey_type) => setForm({ ...form, survey_type })} options={surveyTypes} />
          {approvedProfiles.length ? (
            <Select label="Petugas" value={form.officer_id} onChange={(officer_id) => setForm({ ...form, officer_id })} options={approvedProfiles.map((item) => item.id)} format={(id) => approvedProfiles.find((item) => item.id === id)?.full_name || id} />
          ) : (
            <p className="note">Belum ada petugas aktif. Tambahkan petugas di Manajemen Pengguna terlebih dahulu.</p>
          )}
          <div className="master-filter">
            <strong>Filter Wilayah Master</strong>
            <Select label="Kecamatan" value={form.kecamatan} onChange={(kecamatan) => {
              const nextDesa = getDesaOptions(kecamatan)[0] || "";
              setForm({ ...form, kecamatan, desa: nextDesa, sls: "" });
            }} options={laburaKecamatan.map((item) => item.name)} />
            <Select label="Desa" value={form.desa} onChange={(desa) => setForm({ ...form, desa, sls: "" })} options={desaOptions} />
            <Select label="SLS" value={form.sls} onChange={(sls) => setForm({ ...form, sls })} options={slsOptions.map((item) => item.value)} allLabel="-- Pilih SLS --" format={(value) => slsOptions.find((item) => item.value === value)?.label || value} />
          </div>
          <div className="modal-actions">
            <button className="btn ghost" onClick={onClose}>Batal</button>
            <button className="btn primary" onClick={save}>Simpan Penugasan</button>
          </div>
        </div>
      </div>
    </div>
  );
}

function TitikSasaran({ rows }) {
  const [targets, setTargets] = useState(rows);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({
    target_code: "",
    label: "",
    survey_type: surveyTypes[0],
    kecamatan: laburaKecamatan[0].name,
    desa: laburaKecamatan[0].desa[0],
    sls: "",
    latitude: "",
    longitude: "",
    status: "active"
  });

  useEffect(() => {
    setTargets(rows);
  }, [rows]);

  const desaOptions = getDesaOptions(form.kecamatan);
  const slsOptions = getSlsOptions(form.kecamatan, form.desa);

  async function saveTarget() {
    if (!form.label.trim()) {
      alert("Label titik wajib diisi.");
      return;
    }
    if (!form.sls.trim()) {
      alert("SLS wajib dipilih.");
      return;
    }

    const selectedSls = slsOptions.find((item) => item.value === form.sls);
    const targetCode = form.target_code.trim() || `TGT-${Date.now()}`;
    const payload = {
      target_code: targetCode,
      label: form.label.trim(),
      survey_type: form.survey_type,
      kecamatan: form.kecamatan,
      desa: form.desa,
      sls: selectedSls?.sls || form.sls,
      latitude: form.latitude === "" ? null : Number(form.latitude),
      longitude: form.longitude === "" ? null : Number(form.longitude),
      status: form.status
    };

    let saved = { id: targetCode, ...payload };
    if (hasSupabaseConfig && supabase) {
      const { data, error } = await supabase
        .from("target_points")
        .insert(payload)
        .select("*")
        .single();

      if (error) {
        alert(`Gagal menyimpan titik sasaran: ${error.message}`);
        return;
      }
      saved = data;
    }

    setTargets((current) => [saved, ...current]);
    setShowModal(false);
    setForm({
      target_code: "",
      label: "",
      survey_type: surveyTypes[0],
      kecamatan: laburaKecamatan[0].name,
      desa: laburaKecamatan[0].desa[0],
      sls: "",
      latitude: "",
      longitude: "",
      status: "active"
    });
  }

  return (
    <>
      <Panel title="Titik Sasaran" action={<button className="btn primary" onClick={() => setShowModal(true)}><Plus size={16} /> Tambah Titik</button>}>
        <DataTable
          headers={["ID", "Label", "Survei", "Wilayah", "SLS", "Status"]}
          rows={targets.map((item) => [
            item.target_code || item.id,
            item.label,
            item.survey_type,
            `${item.kecamatan} / ${item.desa}`,
            item.sls,
            <Badge key={item.id || item.target_code} tone={item.status === "active" ? "green" : "orange"}>{item.status}</Badge>
          ])}
        />
      </Panel>

      {showModal && (
        <div className="modal-backdrop">
          <div className="modal">
            <div className="modal-header">
              <h3>Tambah Titik Sasaran</h3>
              <button className="icon-btn" onClick={() => setShowModal(false)}>x</button>
            </div>
            <div className="form-grid">
              <label>Kode Titik<input value={form.target_code} onChange={(event) => setForm({ ...form, target_code: event.target.value })} placeholder="Otomatis jika kosong" /></label>
              <label>Label<input value={form.label} onChange={(event) => setForm({ ...form, label: event.target.value })} placeholder="Nama titik sasaran" /></label>
              <Select label="Survei" value={form.survey_type} onChange={(survey_type) => setForm({ ...form, survey_type })} options={surveyTypes} />
              <Select label="Kecamatan" value={form.kecamatan} onChange={(kecamatan) => {
                const nextDesa = getDesaOptions(kecamatan)[0] || "";
                setForm({ ...form, kecamatan, desa: nextDesa, sls: "" });
              }} options={laburaKecamatan.map((item) => item.name)} />
              <Select label="Desa" value={form.desa} onChange={(desa) => setForm({ ...form, desa, sls: "" })} options={desaOptions} />
              <Select label="SLS" value={form.sls} onChange={(sls) => setForm({ ...form, sls })} options={slsOptions.map((item) => item.value)} allLabel="-- Pilih SLS --" format={(value) => slsOptions.find((item) => item.value === value)?.label || value} />
              <label>Latitude<input value={form.latitude} onChange={(event) => setForm({ ...form, latitude: event.target.value })} placeholder="Opsional" /></label>
              <label>Longitude<input value={form.longitude} onChange={(event) => setForm({ ...form, longitude: event.target.value })} placeholder="Opsional" /></label>
              <div className="modal-actions">
                <button className="btn ghost" onClick={() => setShowModal(false)}>Batal</button>
                <button className="btn primary" onClick={saveTarget}>Simpan Titik</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

function HakAkses() {
  return (
    <Panel title="Hak Akses (Roles)">
      <DataTable
        headers={["Role", "Monitoring", "Master Data", "Admin", "Status"]}
        rows={[
          ["Admin Kab/Kot", "Penuh", "Penuh", "Penuh", <Badge key="a" tone="green">Aktif</Badge>],
          ["Supervisor", "Lihat & export", "Wilayah tugas", "Terbatas", <Badge key="s" tone="green">Aktif</Badge>],
          ["Petugas", "Data sendiri", "Tidak ada", "Tidak ada", <Badge key="p" tone="green">Aktif</Badge>]
        ]}
      />
    </Panel>
  );
}

function PengaturanSistem() {
  return (
    <Panel title="Pengaturan Sistem">
      <div className="settings-grid">
        <label>Interval Tracking Background<select><option>45 detik</option><option>60 detik</option></select></label>
        <label>Batas Akurasi GPS<input defaultValue="30 meter" /></label>
        <label>Mode Sinkronisasi<select><option>Otomatis saat online</option><option>Manual</option></select></label>
        <label>Scope Wilayah<input defaultValue="Kabupaten Labuhanbatu Utara" readOnly /></label>
      </div>
    </Panel>
  );
}

function LogAktivitas({ rows }) {
  return (
    <Panel title="Log Aktivitas">
      <DataTable
        headers={["Waktu", "Pengguna", "Aktivitas", "Modul"]}
        rows={rows.map((item) => [formatDate(item.created_at), item.actor || item.actor_name, item.action, item.module])}
      />
    </Panel>
  );
}

function LiveMetricCard({ title, tone, rows, mainValue, hint, onClick }) {
  return (
    <button className={`live-metric-card ${tone}`} onClick={onClick} type="button">
      <span className="live-metric-title">{title}</span>
      {rows ? (
        <div className="live-metric-rows">
          {rows.map((row) => (
            <div key={row.label}>
              <span>{row.label}</span>
              <strong>
                {row.value}
                {row.total !== undefined && <small> / {row.total}</small>}
              </strong>
            </div>
          ))}
        </div>
      ) : (
        <strong className="live-metric-main">{mainValue}</strong>
      )}
      <small className="live-metric-hint">{hint || "Klik untuk detail & ekspor"}</small>
    </button>
  );
}

function Metric({ label, value, tone }) {
  return (
    <div className={`metric ${tone}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{tone === "blue" ? "Sedang mengirim lokasi" : tone === "orange" ? "Berada di luar batas SLS" : tone === "red" ? "Menggunakan mock location" : "Offline atau belum aktif"}</small>
    </div>
  );
}

function Panel({ title, action, children }) {
  return (
    <section className="panel">
      <div className="panel-title">
        <h3>{title}</h3>
        {action}
      </div>
      {children}
    </section>
  );
}

function DataTable({ headers, rows }) {
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>{headers.map((header) => <th key={header}>{header}</th>)}</tr>
        </thead>
        <tbody>
          {rows.length ? rows.map((row, index) => (
            <tr key={index}>{row.map((cell, cellIndex) => <td key={cellIndex}>{cell}</td>)}</tr>
          )) : (
            <tr><td colSpan={headers.length}>Belum ada data.</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}

function Select({ label, value, onChange, options, allLabel, format }) {
  return (
    <label className="select-field">
      {label}
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        {allLabel && <option value="">{allLabel}</option>}
        {options.map((option) => <option key={option} value={option}>{format ? format(option) : option}</option>)}
      </select>
    </label>
  );
}

function Badge({ children, tone }) {
  return <span className={`badge ${tone}`}>{children}</span>;
}

function TrackingStatus({ item }) {
  if (item.is_outside_sls || item.geofence_status === "outside_sls") {
    return <Badge tone="red">Di luar SLS</Badge>;
  }

  if (item.accuracy > 30) {
    return <Badge tone="orange">Akurasi rendah</Badge>;
  }

  return <Badge tone="green">Dalam wilayah</Badge>;
}

function getDesaOptions(kecamatan) {
  if (!kecamatan) return laburaKecamatan.flatMap((item) => item.desa);
  return laburaKecamatan.find((item) => item.name === kecamatan)?.desa || [];
}

function getSlsOptions(kecamatan, desa) {
  return laburaRegions
    .filter((item) => {
      const byKec = kecamatan ? item.kecamatan === kecamatan : true;
      const byDesa = desa ? item.desa === desa : true;
      return byKec && byDesa;
    })
    .map((item) => ({
      value: item.idsubsls || `${item.kecamatan}|${item.desa}|${item.sls}|${item.kdsubsls}`,
      label: `${item.sls}${item.kdsubsls ? ` - ${item.kdsubsls}` : ""}`,
      ...item
    }));
}

function formatDate(value) {
  if (!value) return "-";
  return new Intl.DateTimeFormat("id-ID", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

function formatDateOnly(value) {
  if (!value) return "-";
  return new Intl.DateTimeFormat("id-ID", {
    day: "2-digit",
    month: "short",
    year: "numeric"
  }).format(new Date(value));
}

function formatTimeOnly(value) {
  if (!value) return "-";
  return new Intl.DateTimeFormat("id-ID", {
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

function formatDuration(start, end) {
  if (!start || !end) return "-";
  const diffMs = new Date(end).getTime() - new Date(start).getTime();
  if (diffMs < 0) return "-";
  const totalMinutes = Math.floor(diffMs / 60000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours <= 0) return `${minutes} menit`;
  return `${hours} jam ${minutes} menit`;
}
