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
  metadataBase: new URL('https://mnpschool.in'),
  title: {
    default: "MNP School | Mission Navodaya Public School, Mora, Bihar",
    template: "%s | MNP School"
  },
  description: "Official portal of Mission Navodaya Public School (MNP School), Mora, Bihar. Online Admissions, Student Results, Parent Portal, Academic Calendar, and Quality Education.",
  keywords: [
    "mnpschool",
    "mnp school",
    "mnpschool.in",
    "mission navodaya public school",
    "mnp school mora",
    "mnp school bihar",
    "mnp school admission",
    "mnp school result",
    "mission navodaya school"
  ],
  authors: [{ name: "Mission Navodaya Public School" }],
  creator: "Mission Navodaya Public School",
  publisher: "Mission Navodaya Public School",
  alternates: {
    canonical: "https://mnpschool.in"
  },
  icons: {
    icon: [
      { url: '/logo.png', type: 'image/png' },
      { url: '/logo.png', sizes: '32x32', type: 'image/png' },
      { url: '/logo.png', sizes: '192x192', type: 'image/png' },
    ],
    shortcut: '/logo.png',
    apple: '/logo.png',
  },
  openGraph: {
    title: "MNP School | Mission Navodaya Public School, Mora, Bihar",
    description: "Official portal of Mission Navodaya Public School (MNP School), Mora, Bihar. Online Admissions, Student Results, Parent Portal, and Academic Updates.",
    url: "https://mnpschool.in",
    siteName: "MNP School",
    locale: "en_IN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "MNP School | Mission Navodaya Public School, Mora, Bihar",
    description: "Official portal of Mission Navodaya Public School (MNP School), Mora, Bihar.",
  },
  verification: {
    google: "DucDVR_DeLe1mqmmL8JQZ8sl3SiSav2Ux1Tyie_9CqA",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
};

export default function RootLayout({ children }) {
  const schoolJsonLd = {
    "@context": "https://schema.org",
    "@type": "School",
    "name": "Mission Navodaya Public School",
    "alternateName": "MNP School",
    "url": "https://mnpschool.in",
    "logo": "https://mnpschool.in/logo.png",
    "address": {
      "@type": "PostalAddress",
      "addressLocality": "Mora",
      "addressRegion": "Bihar",
      "addressCountry": "IN"
    },
    "sameAs": [
      "https://mnpschool.in"
    ]
  };

  return (
    <html lang="en" className={inter.variable} suppressHydrationWarning>
      <head>
        <link rel="icon" type="image/png" sizes="32x32" href="/logo.png" />
        <link rel="apple-touch-icon" href="/logo.png" />
        <meta name="google-site-verification" content="DucDVR_DeLe1mqmmL8JQZ8sl3SiSav2Ux1Tyie_9CqA" />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(schoolJsonLd) }}
        />
      </head>
      <body className={`${inter.className} antialiased`}>{children}</body>
    </html>
  );
}
