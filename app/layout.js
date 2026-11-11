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
    default: "MNP School | Mission Navodaya Public School, Mora-Mairi, Siwan, Bihar",
    template: "%s | MNP School"
  },
  description: "Official portal of Mission Navodaya Public School (MNP School), Mora-Mairi, Siwan, Bihar. Top English Medium school in Mora-Mairi, Mora Bazar, Mairi, Ratauli & Siwan. Founded by Chairman Uday Shankar Patel (Uday Sir) & Director Vishal Patel (Vishal Sir). Online Admissions, Student Results & Quality Education.",
  keywords: [
    // Brand & Variations
    "mnp school",
    "mnpschool",
    "mnpschool.in",
    "mission navodaya public school",
    "mission navodaya school mora",
    "mission navodaya school",
    "mnp public school",
    "mnp",

    // Mora & Village Keywords
    "mora school",
    "mora shool",
    "school in mora",
    "mora ka school",
    "mora mai school",
    "mora bihar school",
    "mora public school",
    "mora navodaya school",

    // Mora Bazaar & Nearby Markets
    "mora bazaar school",
    "mora bazar school",
    "moara bazaar school",
    "mora market school",

    // Mairi & Nearby Localities
    "mora mairi school",
    "mairi school",
    "mora mairwa school",
    "mairi ka school",
    "mairi school bihar",

    // Ratauli & Nearby Localities
    "mora ratauli ka school",
    "mora ratauli school",
    "ratauli school",
    "ratauli ka school",
    "ratauli mora school",

    // Siwan District
    "siwan school",
    "siwan sschool",
    "best school in siwan",
    "school in siwan bihar",
    "top school in siwan",
    "siwan bihar school",

    // Founders & Leadership Known Locally
    "vishal sir school",
    "vishal sir ka school",
    "vishal sir mora school",
    "director vishal patel school",
    "uday sir ka school",
    "uday sir school",
    "uday patel school mora",
    "chairman uday shankar patel school",

    // Academic & Services
    "mnp school admission",
    "mnp school result",
    "mnp school fees",
    "mnp school parent portal"
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
    title: "MNP School | Mission Navodaya Public School, Mora-Mairi, Siwan, Bihar",
    description: "Official portal of Mission Navodaya Public School (MNP School), Mora-Mairi, Siwan, Bihar. Serving Mora, Mairi, Ratauli, Mora Bazar, and Siwan. Online Admissions & Results.",
    url: "https://mnpschool.in",
    siteName: "MNP School",
    locale: "en_IN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "MNP School | Mission Navodaya Public School, Mora-Mairi, Siwan, Bihar",
    description: "Official portal of Mission Navodaya Public School (MNP School), Mora-Mairi, Siwan, Bihar. Serving Mora, Mairi, Ratauli, Mora Bazar, and Siwan.",
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
    "alternateName": [
      "MNP School",
      "MNP Public School",
      "Mora School",
      "Vishal Sir School",
      "Uday Sir Ka School",
      "Mora Mairi School",
      "Mora Ratauli School",
      "Mora Bazaar School"
    ],
    "url": "https://mnpschool.in",
    "logo": "https://mnpschool.in/logo.png",
    "image": "https://mnpschool.in/logo.png",
    "description": "Mission Navodaya Public School (MNP School) located in Mora, Bihar. Serving students across Mora, Mairi, Ratauli, Mora Bazar, and Siwan district.",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "Mora Bazar, Near Mairi - Ratauli Road",
      "addressLocality": "Mora-Mairi",
      "addressRegion": "Bihar",
      "addressCountry": "IN"
    },
    "areaServed": [
      "Mora",
      "Mora Bazar",
      "Mairi",
      "Ratauli",
      "Siwan",
      "Bihar"
    ],
    "founder": [
      {
        "@type": "Person",
        "name": "Uday Shankar Patel",
        "jobTitle": "Chairman"
      },
      {
        "@type": "Person",
        "name": "Vishal Patel",
        "jobTitle": "Director"
      }
    ],
    "geo": {
      "@type": "GeoCoordinates",
      "latitude": 26.115206775039834,
      "longitude": 84.62215723091671
    },
    "hasMap": "https://www.google.com/maps?q=26.115206775039834,84.62215723091671",
    "sameAs": [
      "https://mnpschool.in",
      "https://www.mnpschool.in"
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
