'use client';

import React, { useState, useEffect } from 'react';
import { SchoolProvider, useSchoolStore } from '../lib/store';
import Sidebar from '../components/Sidebar';
import Header from '../components/Header';
import DashboardView from '../components/DashboardView';
import StudentsView from '../components/StudentsView';
import FeesView from '../components/FeesView';
import AttendanceView from '../components/AttendanceView';
import ResultsView from '../components/ResultsView';
import IdCardView from '../components/IdCardView';
import AdmitCardView from '../components/AdmitCardView';
import TimetableView from '../components/TimetableView';
import ClassesView from '../components/ClassesView';
import TeachersView from '../components/TeachersView';
import ReportsView from '../components/ReportsView';
import QrScannerView from '../components/QrScannerView';
import SettingsView from '../components/SettingsView';
import TeacherPermissionsModal from '../components/TeacherPermissionsModal';
import SubscriptionView from '../components/SubscriptionView';
import PrintReceiptModal from '../components/PrintReceiptModal';
import PrintResultModal from '../components/PrintResultModal';
import PrintIdCardsModal from '../components/PrintIdCardsModal';
import GlobalSearchModal from '../components/GlobalSearchModal';
import AddEditStudentModal from '../components/AddEditStudentModal';
import StudentProfileModal from '../components/StudentProfileModal';
import CollectFeeModal from '../components/CollectFeeModal';
import StudentFeeDetailModal from '../components/StudentFeeDetailModal';
import PromoteStudentsModal from '../components/PromoteStudentsModal';
import WhatsAppReminderModal from '../components/WhatsAppReminderModal';
import NoticeBoardView from '../components/NoticeBoardView';
import AddEditNoticeModal from '../components/AddEditNoticeModal';
import NoticeDetailModal from '../components/NoticeDetailModal';
import { ToastContainer, ConfirmDialog } from '../components/ToastNotification';
import AudioVoiceNoteModal from '../components/AudioVoiceNoteModal';
import HelpAndFeedbackModal from '../components/HelpAndFeedbackModal';

// Auth Components
import SignInView from '../components/SignInView';
import SignUpView from '../components/SignUpView';
import ForgotPasswordView from '../components/ForgotPasswordView';
import SetupWizardView from '../components/SetupWizardView';
import AccessDeniedView from '../components/AccessDeniedView';
import UserManagementView from '../components/UserManagementView';
import ProfileView from '../components/ProfileView';
import ParentPortalView from '../components/ParentPortalView';
import ParentComplaintsView from '../components/ParentComplaintsView';
import OnlineEnquiriesModal from '../components/OnlineEnquiriesModal';

const KNOWN_APP_PATHS = [
  '/', '/dashboard', '/notices', '/students', '/fees', '/attendance',
  '/results', '/idcards', '/admitcards', '/timetable', '/classes',
  '/teachers', '/reports', '/documents', '/import-export', '/qrscanner',
  '/scanner', '/subscription', '/users', '/profile', '/complaints', '/access-denied'
];

function AppContent() {
  const {
    currentPath,
    currentUser,
    isPrincipal,
    isTeacher,
    students,
    settings,
    teacherPermissions,
    navigate,
    isAddStudentOpen, setIsAddStudentOpen,
    editingStudent, setEditingStudent,
    viewingStudentProfile, setViewingStudentProfile,
    collectFeeStudent, setCollectFeeStudent,
    feeDetailStudent, setFeeDetailStudent,
    isFeeDetailSelectorOpen, setIsFeeDetailSelectorOpen,
    printReceiptData, setPrintReceiptData,
    printResultData,  setPrintResultData,
    printIdCardsData, setPrintIdCardsData,
    whatsAppReminderData, setWhatsAppReminderData,
    isPromoteModalOpen, setIsPromoteModalOpen,
    isGlobalSearchOpen, setIsGlobalSearchOpen,
    isAddNoticeOpen, setIsAddNoticeOpen,
    editingNotice, setEditingNotice,
    viewingNotice, setViewingNotice,
    isTeacherPermissionsModalOpen, setIsTeacherPermissionsModalOpen,
    isHelpFeedbackOpen, setIsHelpFeedbackOpen,
    isEnquiriesModalOpen, setIsEnquiriesModalOpen,
    enquiriesModalTab,
    securityConfig,
    showToast,
    logout
  } = useSchoolStore();

  const [isMobileNavOpen, setIsMobileNavOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [isAudioModalOpen, setIsAudioModalOpen] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  useEffect(() => {
    const handleOpenAudioModal = () => setIsAudioModalOpen(true);
    const handleOpenHelpFeedback = () => setIsHelpFeedbackOpen(true);
    window.addEventListener('school_open_audio_modal', handleOpenAudioModal);
    window.addEventListener('school_open_help_feedback', handleOpenHelpFeedback);
    return () => {
      window.removeEventListener('school_open_audio_modal', handleOpenAudioModal);
      window.removeEventListener('school_open_help_feedback', handleOpenHelpFeedback);
    };
  }, [setIsHelpFeedbackOpen]);

  const prevModalOpenRef = React.useRef(false);

  // Register Background Notification Service Worker
  useEffect(() => {
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      navigator.serviceWorker
        .register('/sw.js')
        .catch((err) => {
          console.warn('SW registration note:', err.message);
        });
    }
  }, []);

  // Mobile Back Button / Gesture Navigation Support
  useEffect(() => {
    if (typeof window === 'undefined') return;

    const isAnyModalOpen = !!(
      isAddStudentOpen ||
      editingStudent ||
      viewingStudentProfile ||
      collectFeeStudent ||
      feeDetailStudent ||
      printReceiptData ||
      printResultData ||
      printIdCardsData ||
      isGlobalSearchOpen ||
      isMobileNavOpen ||
      isAddNoticeOpen ||
      editingNotice ||
      viewingNotice ||
      isPromoteModalOpen ||
      whatsAppReminderData
    );

    if (isAnyModalOpen && !prevModalOpenRef.current) {
      window.history.pushState({ modalOpen: true }, '');
    }
    prevModalOpenRef.current = isAnyModalOpen;

    const handlePopState = () => {
      // 1. If any modal or drawer is open, close it first on Back!
      if (whatsAppReminderData) {
        setWhatsAppReminderData(null);
        return;
      }
      if (viewingStudentProfile) {
        setViewingStudentProfile(null);
        return;
      }
      if (isPromoteModalOpen) {
        setIsPromoteModalOpen(false);
        return;
      }
      if (isAddNoticeOpen || editingNotice) {
        setIsAddNoticeOpen(false);
        setEditingNotice(null);
        return;
      }
      if (viewingNotice) {
        setViewingNotice(null);
        return;
      }
      if (isMobileNavOpen) {
        setIsMobileNavOpen(false);
        return;
      }
      if (isAddStudentOpen || editingStudent) {
        setIsAddStudentOpen(false);
        setEditingStudent(null);
        return;
      }
      if (collectFeeStudent) {
        setCollectFeeStudent(null);
        return;
      }
      if (feeDetailStudent) {
        setFeeDetailStudent(null);
        setIsFeeDetailSelectorOpen(false);
        return;
      }
      if (printReceiptData) {
        setPrintReceiptData(null);
        return;
      }
      if (printResultData) {
        setPrintResultData(null);
        return;
      }
      if (printIdCardsData) {
        setPrintIdCardsData(null);
        return;
      }
      if (isGlobalSearchOpen) {
        setIsGlobalSearchOpen(false);
        return;
      }

      // 2. If no modal is open, update view route from browser history path!
      const targetPath = window.location.pathname || '/dashboard';
      if (targetPath && targetPath !== currentPath) {
        navigate(targetPath);
      }
    };

    window.addEventListener('popstate', handlePopState);
    return () => {
      window.removeEventListener('popstate', handlePopState);
    };
  }, [
    isAddStudentOpen,
    editingStudent,
    viewingStudentProfile,
    collectFeeStudent,
    feeDetailStudent,
    printReceiptData,
    printResultData,
    printIdCardsData,
    isGlobalSearchOpen,
    isMobileNavOpen,
    isAddNoticeOpen,
    editingNotice,
    viewingNotice,
    isPromoteModalOpen,
    whatsAppReminderData,
    currentPath
  ]);

  // Security route guards
  useEffect(() => {
    if (!mounted) return;
    const cleanPath = (currentPath || '').split('?')[0].split('#')[0].replace(/\/+$/, '') || '/';

    // 1. Force Sign In if unauthenticated
    if (!currentUser) {
      if (!['/signin', '/signup', '/forgot-password'].includes(cleanPath)) {
        navigate('/signin');
      }
      return;
    }

    // 2. Redirect to Dashboard if logged in user visits signin/signup/forgot
    if (['/signin', '/signup', '/forgot-password'].includes(cleanPath)) {
      navigate('/dashboard');
      return;
    }

    // 3. Dynamic teacher permission access routing
    if (currentUser.role === 'teacher') {
      const strictlyAdmin = ['/users', '/teachers', '/subscription'];
      if (strictlyAdmin.includes(cleanPath) || cleanPath.startsWith('/settings')) {
        navigate('/access-denied');
        return;
      }
      if (cleanPath === '/fees' && !teacherPermissions?.canCollectFees) {
        navigate('/access-denied');
        return;
      }
      if (cleanPath === '/reports' && !teacherPermissions?.canExportReports) {
        navigate('/access-denied');
        return;
      }
      if (cleanPath === '/students' && teacherPermissions?.canViewStudents === false) {
        navigate('/access-denied');
        return;
      }
      if (cleanPath === '/attendance' && teacherPermissions?.canMarkAttendance === false) {
        navigate('/access-denied');
        return;
      }
      if (cleanPath === '/results' && teacherPermissions?.canEnterResults === false) {
        navigate('/access-denied');
        return;
      }
      if (cleanPath === '/classes' && teacherPermissions?.canManageClasses === false) {
        navigate('/access-denied');
        return;
      }
      if (cleanPath === '/timetable' && teacherPermissions?.canManageTimetable === false) {
        navigate('/access-denied');
        return;
      }
      if (cleanPath === '/idcards' && teacherPermissions?.canViewIdCards === false) {
        navigate('/access-denied');
        return;
      }
      if (cleanPath === '/admitcards' && teacherPermissions?.canViewAdmitCards === false) {
        navigate('/access-denied');
        return;
      }
    }

    // 4. Default route redirect
    if (cleanPath === '/' || (cleanPath === '/setup' && settings.isSetupComplete)) {
      navigate('/dashboard');
    }
  }, [currentUser, currentPath, teacherPermissions]);

  // Prevent hydration mismatch between server SSR and client localStorage/session
  if (!mounted) {
    return (
      <div className="min-h-screen bg-[#f8fafc] flex items-center justify-center">
        <div className="w-8 h-8 border-4 border-[#0c2340] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  // ── Render 1: Public full-screen auth routes
  const cleanPath = (currentPath || '').split('?')[0].split('#')[0].replace(/\/+$/, '') || '/';
  if (!currentUser) {
    if (cleanPath === '/signup') return <SignUpView />;
    if (cleanPath === '/forgot-password') return <ForgotPasswordView />;
    return <SignInView />;
  }

  // ── Render 2: Onboarding Setup Wizard
  if (currentUser && currentPath === '/setup' && !settings?.isSetupComplete) {
    return <SetupWizardView />;
  }

  // ── Render 2.5: Parent Portal (Dedicated Student & Parent Experience)
  if (currentUser?.role === 'parent') {
    return (
      <>
        <ParentPortalView />
        {printReceiptData && (
          <PrintReceiptModal
            payment={printReceiptData.payment || printReceiptData}
            student={printReceiptData.student || currentUser.student || students.find(s => s.id === printReceiptData.studentId)}
            onClose={() => setPrintReceiptData(null)}
          />
        )}
        {printResultData && (
          <PrintResultModal
            result={printResultData.result || printResultData}
            student={printResultData.student || currentUser.student || students.find(s => s.id === printResultData.studentId)}
            data={printResultData}
            onClose={() => setPrintResultData(null)}
          />
        )}
        <ToastContainer />
      </>
    );
  }

  // ── Render 3: Authenticated App Frame (Sidebar & Header)
  return (
    <div className="min-h-screen bg-bg text-text font-sans transition-colors duration-200 flex">

      {/* Fixed Sidebar — passes collapse state up via callback */}
      <Sidebar
        isOpen={isMobileNavOpen}
        onClose={() => setIsMobileNavOpen(false)}
        collapsed={sidebarCollapsed}
        onCollapseChange={setSidebarCollapsed}
      />

      {/* Spacer — matches sidebar width */}
      <div
        className={`hidden lg:block flex-shrink-0 transition-all duration-300 ${sidebarCollapsed ? 'w-[72px]' : 'w-72'}`}
        aria-hidden="true"
      />

      {/* Main Content */}
      <div className="flex-1 min-w-0 flex flex-col min-h-screen">
        <Header onMenuClick={() => setIsMobileNavOpen(true)} />
        <main className="flex-1 overflow-x-hidden px-3 py-4 sm:p-6 lg:p-8">
          <div className="w-full max-w-[1600px] mx-auto">
            {(cleanPath === '/' || cleanPath === '/dashboard') && <DashboardView />}
            {cleanPath === '/notices' && (
              <NoticeBoardView
                onOpenPublish={() => { setEditingNotice(null); setIsAddNoticeOpen(true); }}
                onOpenView={(n) => setViewingNotice(n)}
                onOpenEdit={(n) => { setEditingNotice(n); setIsAddNoticeOpen(true); }}
              />
            )}
            {cleanPath === '/students' && <StudentsView />}
            {cleanPath === '/fees' && ((isPrincipal || teacherPermissions?.canCollectFees) ? <FeesView /> : <AccessDeniedView />)}
            {cleanPath === '/attendance' && <AttendanceView />}
            {cleanPath === '/results' && <ResultsView />}
            {cleanPath === '/idcards' && <IdCardView />}
            {cleanPath === '/admitcards' && <AdmitCardView />}
            {cleanPath === '/timetable' && <TimetableView />}
            {cleanPath === '/classes' && <ClassesView />}
            {cleanPath === '/teachers' && (isPrincipal ? <SafeView><TeachersView /></SafeView> : <AccessDeniedView />)}
            {cleanPath === '/reports' && ((isPrincipal || teacherPermissions?.canExportReports) ? <ReportsView /> : <AccessDeniedView />)}
            {cleanPath === '/documents' && ((isPrincipal || teacherPermissions?.canExportReports) ? <ReportsView /> : <AccessDeniedView />)}
            {cleanPath === '/import-export' && ((isPrincipal || teacherPermissions?.canExportReports) ? <ReportsView /> : <AccessDeniedView />)}
            {(cleanPath === '/qrscanner' || cleanPath === '/scanner') && <QrScannerView />}
            {cleanPath.startsWith('/settings') && (isPrincipal ? <SettingsView /> : <AccessDeniedView />)}
            {cleanPath === '/subscription' && (isPrincipal ? <SubscriptionView /> : <AccessDeniedView />)}
            {cleanPath === '/users' && (isPrincipal ? <UserManagementView /> : <AccessDeniedView />)}
            {cleanPath === '/profile' && <ProfileView />}
            {cleanPath === '/complaints' && <ParentComplaintsView />}
            {cleanPath === '/access-denied' && <AccessDeniedView />}
            {!KNOWN_APP_PATHS.includes(cleanPath) && !cleanPath.startsWith('/settings') && <DashboardView />}
          </div>
        </main>
      </div>

      {/* Modals */}
      {isTeacherPermissionsModalOpen && (
        <TeacherPermissionsModal
          isOpen={isTeacherPermissionsModalOpen}
          onClose={() => setIsTeacherPermissionsModalOpen(false)}
        />
      )}
      {isAddStudentOpen && (
        <AddEditStudentModal
          isOpen={isAddStudentOpen}
          student={editingStudent}
          onClose={() => { setIsAddStudentOpen(false); setEditingStudent(null); }}
        />
      )}
      {viewingStudentProfile && (
        <StudentProfileModal
          student={viewingStudentProfile}
          onClose={() => setViewingStudentProfile(null)}
        />
      )}
      {collectFeeStudent && (currentUser?.role === 'principal' || teacherPermissions?.canCollectFees) && (
        <CollectFeeModal
          isOpen={!!collectFeeStudent}
          student={collectFeeStudent}
          onClose={() => setCollectFeeStudent(null)}
        />
      )}
      {feeDetailStudent && (currentUser?.role === 'principal' || teacherPermissions?.canCollectFees) && (
        <StudentFeeDetailModal
          isOpen={!!feeDetailStudent}
          student={feeDetailStudent}
          onClose={() => {
            setFeeDetailStudent(null);
            setIsFeeDetailSelectorOpen(false);
          }}
        />
      )}
      {printReceiptData && (
        <PrintReceiptModal payment={printReceiptData.payment} student={printReceiptData.student} onClose={() => setPrintReceiptData(null)} />
      )}
      {printResultData && (
        <PrintResultModal result={printResultData.result || printResultData} student={printResultData.student} data={printResultData} onClose={() => setPrintResultData(null)} />
      )}
      {printIdCardsData && (
        <PrintIdCardsModal students={printIdCardsData.students} template={printIdCardsData.template} onClose={() => setPrintIdCardsData(null)} />
      )}
      {isGlobalSearchOpen && (
        <GlobalSearchModal isOpen={isGlobalSearchOpen} onClose={() => setIsGlobalSearchOpen(false)} />
      )}
      {isPromoteModalOpen && (
        <PromoteStudentsModal isOpen={isPromoteModalOpen} onClose={() => setIsPromoteModalOpen(false)} />
      )}
      {whatsAppReminderData && (
        <WhatsAppReminderModal isOpen={!!whatsAppReminderData} onClose={() => setWhatsAppReminderData(null)} {...(whatsAppReminderData || {})} />
      )}

      {/* Notice Board Modals */}
      {isAddNoticeOpen && (
        <AddEditNoticeModal
          isOpen={isAddNoticeOpen}
          noticeToEdit={editingNotice}
          onClose={() => { setIsAddNoticeOpen(false); setEditingNotice(null); }}
        />
      )}
      {viewingNotice && (
        <NoticeDetailModal
          notice={viewingNotice}
          onClose={() => setViewingNotice(null)}
          onEdit={(n) => { setViewingNotice(null); setEditingNotice(n); setIsAddNoticeOpen(true); }}
        />
      )}


            {/* Online Enquiries & Admissions Desk Modal */}
      <OnlineEnquiriesModal
        isOpen={isEnquiriesModalOpen}
        onClose={() => setIsEnquiriesModalOpen(false)}
        initialTab={enquiriesModalTab}
      />

{/* Oral Voice Note & Viva Recording Modal */}
      <AudioVoiceNoteModal
        isOpen={isAudioModalOpen}
        onClose={() => setIsAudioModalOpen(false)}
        onSave={() => {
          showToast('✓ Voice response recorded successfully!', 'success');
        }}
      />

      {/* Help and Feedback Modal (Exact app design) */}
      <HelpAndFeedbackModal
        isOpen={isHelpFeedbackOpen}
        onClose={() => setIsHelpFeedbackOpen(false)}
      />

      {/* Global Theme-matched Toast Notifications & Confirmation Dialog */}
      <ToastContainer />
      <ConfirmDialog />
    </div>
  );
}


class SafeView extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  componentDidCatch(error, errorInfo) {
    console.error('SafeView caught sub-view error:', error, errorInfo);
  }
  render() {
    if (this.state.hasError) {
      return (
        <div className="p-6 bg-card border border-rose-500/20 rounded-2xl text-center space-y-3 my-4">
          <div className="w-10 h-10 bg-rose-500/10 text-rose-500 rounded-full flex items-center justify-center mx-auto font-black text-lg">!</div>
          <p className="text-sm font-bold text-text">Display update recovered</p>
          <p className="text-xs text-text-muted">{this.state.error?.message || 'Temporary display glitch'}</p>
          <button
            type="button"
            onClick={() => this.setState({ hasError: false, error: null })}
            className="px-4 py-1.5 bg-primary hover:bg-primary-hover text-white rounded-xl text-xs font-bold cursor-pointer transition-all"
          >
            Retry View
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

class RootErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  componentDidCatch(error, errorInfo) {
    console.error('RootErrorBoundary caught error:', error, errorInfo);
  }
  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-[#0b1c30] text-white flex items-center justify-center p-4">
          <div className="max-w-md w-full bg-[#102747] border border-white/10 rounded-2xl p-6 text-center shadow-2xl">
            <div className="w-12 h-12 bg-amber-500/20 text-amber-400 rounded-full flex items-center justify-center mx-auto mb-4 font-black text-xl">
              !
            </div>
            <h2 className="text-lg font-black text-white mb-2">School Portal Recovered</h2>
            <p className="text-xs text-white/70 mb-5 leading-relaxed">
              We encountered a temporary display issue. Tap reload to return to the active campus dashboard.
            </p>
            <div className="flex gap-2 justify-center">
              <button
                type="button"
                onClick={() => {
                  this.setState({ hasError: false, error: null });
                  if (typeof window !== 'undefined') {
                    window.location.href = '/dashboard';
                  }
                }}
                className="px-4 py-2 bg-gradient-to-r from-amber-500 to-amber-600 text-white font-bold rounded-xl text-xs shadow-md cursor-pointer hover:brightness-110 transition-all"
              >
                Go to Dashboard
              </button>
              <button
                type="button"
                onClick={() => {
                  if (typeof window !== 'undefined') {
                    window.location.reload();
                  }
                }}
                className="px-4 py-2 bg-white/10 hover:bg-white/20 text-white font-bold rounded-xl text-xs border border-white/20 cursor-pointer transition-all"
              >
                Reload
              </button>
            </div>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

export default function Home() {
  return (
    <RootErrorBoundary>
      <SchoolProvider>
        <AppContent />
      </SchoolProvider>
    </RootErrorBoundary>
  );
}
