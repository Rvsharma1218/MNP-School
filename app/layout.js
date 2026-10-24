import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800", "900"],
  display: "swap",
});

export const viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
  userScalable: true,
  themeColor: '#102747',
};

export const metadata = {
  title: "Mission Navodaya Public School | Mora, Bihar · Session 2026-27",
  description: "Official digital campus of Mission Navodaya Public School, Mora, Bihar. Quality education, discipline, creativity, holistic development, online admissions, and parent portal.",
  openGraph: {
    title: "Mission Navodaya Public School | Mora, Bihar · Session 2026-27",
    description: "Official digital campus of Mission Navodaya Public School, Mora, Bihar. Quality education, discipline, creativity, holistic development, online admissions, and parent portal.",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Mission Navodaya Public School | Mora, Bihar · Session 2026-27",
    description: "Official digital campus of Mission Navodaya Public School, Mora, Bihar. Quality education, discipline, creativity, holistic development, online admissions, and parent portal.",
  },
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={inter.variable} suppressHydrationWarning>
      <body className={`${inter.className} antialiased`}>{children}</body>
    </html>
  );
}
