import "./globals.css";

export const metadata = {
  title: "mardalan Dashboard",
  description: "Monitoring Aktivitas dan Rute Petugas Lapangan BPS Kabupaten Labuhanbatu Utara",
  icons: {
    icon: "/favicon.png",
    apple: "/icon-192.png"
  }
};

export default function RootLayout({ children }) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
