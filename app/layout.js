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
  themeColor: '#1f108e',
};

export const metadata = {
  title: "School Management",
  description: "Complete student administration, attendance register, fee collection & receipts, marksheet results, and ID card generator.",
  openGraph: {
    title: "School Management",
    description: "Complete student administration, attendance register, fee collection & receipts, marksheet results, and ID card generator.",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "School Management",
    description: "Complete student administration, attendance register, fee collection & receipts, marksheet results, and ID card generator.",
  },
};

export default function RootLayout({ children }) {
  return (
    <html lang="en" className={inter.variable} suppressHydrationWarning>
      <body className={`${inter.className} antialiased`}>{children}</body>
    </html>
  );
}
