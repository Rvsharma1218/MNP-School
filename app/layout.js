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
  metadataBase: new URL('https://www.mnpschool.in'),
  title: {
    default: "MNP School | Mission Navodaya Public School, Mora-Mairi, Siwan, Bihar",
    template: "%s | MNP School"
  },
  description: "Official website of Mission Navodaya Public School (MNP School), Mora-Mairi, Siwan, Bihar. Founded by Chairman Uday Shankar Patel (Uday Sir) & Director Vishal Patel (Vishal Sir). Features 24/7 Online Admissions, Live Student Attendance, Exam Results, Fee Portal & Mobile App for Parents.",
  keywords: [
    // Brand & Variations (English)
    "mnp school",
    "mnpschool",
    "mnpschool.in",
    "www.mnpschool.in",
    "mission navodaya public school",
    "mission navodaya school mora",
    "mission navodaya school",
    "mnp public school",
    "mnp",
    "mnp school mora",
    "mnp school siwan",
    "mnp school bihar",

    // Brand & Variations (Hindi - Devanagari)
    "मिशन नवोदय पब्लिक स्कूल",
    "मिशन नवोदय पब्लिक स्कूल मोरा",
    "मिशन नवोदय स्कूल",
    "मिशन नवोदय स्कूल मोरा",
    "एमएनपी स्कूल",
    "एमएनपी स्कूल मोरा",
    "एमएनपी पब्लिक स्कूल",
    "एमएनपी स्कूल सीवान",
    "एम एन पी स्कूल",

    // Mora & Village Keywords (English)
    "mora school",
    "mora shool",
    "school in mora",
    "school in mora siwan",
    "best school in mora",
    "top school in mora",
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

    // Mora & Village Localities (Hindi)
    "मोरा स्कूल",
    "मोरा का स्कूल",
    "मोरा में स्कूल",
    "मोरा बाजार स्कूल",
    "मोरा पब्लिक स्कूल",
    "मोरा नवोदय स्कूल",
    "मोरा सीवान स्कूल",

    // Mairi & Nearby Localities (English & Hindi)
    "mora mairi school",
    "mairi school",
    "mora mairwa school",
    "mairi ka school",
    "mairi school bihar",
    "school in mairi",
    "मोरा मैरी स्कूल",
    "मैरी स्कूल",
    "मैरी का स्कूल",

    // Ratauli & Nearby Localities (English & Hindi)
    "mora ratauli ka school",
    "mora ratauli school",
    "ratauli school",
    "ratauli ka school",
    "ratauli mora school",
    "school in ratauli",
    "मोरा रतौली स्कूल",
    "रतौली स्कूल",
    "रतौली का स्कूल",

    // Surrounding Villages & Local Area
    "patel tola mora school",
    "pipra school siwan",
    "barka gaon school",
    "nautan school siwan",
    "mairwa school",
    "darauli school",
    "guthani school",
    "पटेल टोला मोरा",
    "मैरवा स्कूल",
    "दरौली स्कूल",
    "गुठनी स्कूल",

    // Siwan District & Bihar (English & Hindi)
    "siwan school",
    "siwan sschool",
    "best school in siwan",
    "best cbse school in siwan",
    "top 10 schools in siwan",
    "school in siwan bihar",
    "top school in siwan",
    "siwan bihar school",
    "private school in siwan",
    "english medium school in siwan",
    "सीवान स्कूल",
    "सीवान का सबसे अच्छा स्कूल",
    "सीवान में बेस्ट स्कूल",
    "सीवान बिहार स्कूल",

    // Founders & Leadership Known Locally (English & Hindi)
    "vishal sir school",
    "vishal sir ka school",
    "vishal sir mora school",
    "director vishal patel school",
    "vishal patel mnp school",
    "uday sir ka school",
    "uday sir school",
    "uday patel school mora",
    "chairman uday shankar patel school",
    "uday shankar patel mnp school",
    "विशाल सर का स्कूल",
    "विशाल सर मोरा स्कूल",
    "उदय सर का स्कूल",
    "उदय सर मोरा",
    "उदय शंकर पटेल स्कूल",
    "विशाल पटेल स्कूल",

    // Academic & Services (English & Hindi)
    "mnp school admission",
    "mnp school admission 2026",
    "mnp school admission 2026-27",
    "mnp school online admission",
    "mnp school result",
    "mnp school result 2026",
    "mnp school fees",
    "mnp school fee structure",
    "mnp school parent portal",
    "mnp school app download",
    "navodaya vidyalaya coaching mora",
    "navodaya entrance exam preparation siwan",
    "cbse pattern school in mora",
    "nursery to 8th school in mora siwan",
    "मिशन नवोदय स्कूल एडमिशन",
    "मिशन नवोदय स्कूल रिजल्ट",
    "मिशन नवोदय स्कूल फीस"
  ],
  authors: [{ name: "Mission Navodaya Public School" }],
  creator: "Mission Navodaya Public School",
  publisher: "Mission Navodaya Public School",
  alternates: {
    canonical: "https://www.mnpschool.in"
  },
  icons: {
    icon: [
      { url: '/favicon.ico', sizes: 'any' },
      { url: '/favicon-48x48.png', sizes: '48x48', type: 'image/png' },
      { url: '/favicon-96x96.png', sizes: '96x96', type: 'image/png' },
      { url: '/favicon-192x192.png', sizes: '192x192', type: 'image/png' },
      { url: '/logo.png', sizes: '512x512', type: 'image/png' },
    ],
    shortcut: '/favicon.ico',
    apple: '/logo.png',
  },
  openGraph: {
    title: "MNP School | Mission Navodaya Public School, Mora-Mairi, Siwan, Bihar",
    description: "Official website of Mission Navodaya Public School (MNP School), Mora-Mairi, Siwan. Features 24/7 Online Admissions, Live Student Attendance, Exam Results, Fee Portal & Mobile App for Parents.",
    url: "https://www.mnpschool.in",
    siteName: "MNP School",
    locale: "en_IN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "MNP School | Mission Navodaya Public School, Mora-Mairi, Siwan, Bihar",
    description: "Official website of Mission Navodaya Public School (MNP School), Mora-Mairi, Siwan. Features 24/7 Online Admissions, Live Student Attendance, Exam Results, Fee Portal & Mobile App for Parents.",
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
      "Mission Navodaya School Mora",
      "मिशन नवोदय पब्लिक स्कूल",
      "मिशन नवोदय स्कूल मोरा",
      "एमएनपी स्कूल",
      "Mora School",
      "मोरा स्कूल",
      "Vishal Sir School",
      "विशाल सर का स्कूल",
      "Uday Sir Ka School",
      "उदय सर का स्कूल",
      "Mora Mairi School",
      "मोरा मैरी स्कूल",
      "Mora Ratauli School",
      "मोरा रतौली स्कूल",
      "Mora Bazaar School"
    ],
    "url": "https://www.mnpschool.in",
    "logo": "https://www.mnpschool.in/logo.png",
    "image": "https://www.mnpschool.in/logo.png",
    "telephone": "+918603481865",
    "email": "mnps@mnpschool.in",
    "description": "Official website of Mission Navodaya Public School (MNP School), Mora-Mairi, Siwan, Bihar. Premier CBSE pattern English Medium school from Nursery to 8th grade founded by Chairman Uday Shankar Patel (Uday Sir) and Director Vishal Patel (Vishal Sir). Features online admissions, live student attendance, exam results, fee portal, digital report cards, and parent mobile app.",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "Mora Bazar, Near Mairi - Ratauli Road, Post - Mora",
      "addressLocality": "Mora-Mairi, Siwan",
      "addressRegion": "Bihar",
      "postalCode": "841226",
      "addressCountry": "IN"
    },
    "areaServed": [
      "Mora",
      "Mora Bazar",
      "Mairi",
      "Ratauli",
      "Patel Tola",
      "Pipra",
      "Barka Gaon",
      "Nautan",
      "Mairwa",
      "Darauli",
      "Guthani",
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
        <link rel="icon" href="/favicon.ico" sizes="any" />
        <link rel="icon" type="image/png" sizes="48x48" href="https://www.mnpschool.in/favicon-48x48.png" />
        <link rel="icon" type="image/png" sizes="96x96" href="https://www.mnpschool.in/favicon-96x96.png" />
        <link rel="icon" type="image/png" sizes="192x192" href="https://www.mnpschool.in/favicon-192x192.png" />
        <link rel="apple-touch-icon" href="https://www.mnpschool.in/logo.png" />
        <meta name="google-site-verification" content="DucDVR_DeLe1mqmmL8JQZ8sl3SiSav2Ux1Tyie_9CqA" />
        <meta name="keywords" content="Mission Navodaya Public School, MNP School, mnpschool.in, Mora School, Mora Mairi School, Siwan School, Vishal Sir School, Uday Sir School, मिशन नवोदय पब्लिक स्कूल, मोरा स्कूल, सीवान स्कूल, Best School in Mora Siwan, MNP School Admission, MNP School Result" />
        <meta name="geo.region" content="IN-BR" />
        <meta name="geo.placename" content="Mora, Siwan, Bihar" />
        <meta name="geo.position" content="26.115207;84.622157" />
        <meta name="ICBM" content="26.115207, 84.622157" />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(schoolJsonLd) }}
        />
      </head>
      <body className={`${inter.className} antialiased`}>{children}</body>
    </html>
  );
}
