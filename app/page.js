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
import SecurityPermissionModal from '../components/SecurityPermissionModal';
import NotificationHistoryModal from '../components/NotificationHistoryModal';
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
import ConnectedDevicesView from '../components/ConnectedDevicesView';

function AppContent() {
  const {
    currentPath,
    currentUser,
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
    securityConfig,
    showToast,
    logout
  } = useSchoolStore();

  const [isMobileNavOpen, setIsMobileNavOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [isNotifHistoryOpen, setIsNotifHistoryOpen] = useState(false);
  const [isAudioModalOpen, setIsAudioModalOpen] = useState(false);

  useEffect(() => {
    const handleOpenNotifHistory = () => setIsNotifHistoryOpen(true);
    const handleOpenAudioModal = () => setIsAudioModalOpen(true);
    const handleOpenHelpFeedback = () => setIsHelpFeedbackOpen(true);
    window.addEventListener('school_open_notification_history', handleOpenNotifHistory);
    window.addEventListener('school_open_audio_modal', handleOpenAudioModal);
    window.addEventListener('school_open_help_feedback', handleOpenHelpFeedback);
    return () => {
      window.removeEventListener('school_open_notification_history', handleOpenNotifHistory);
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
    // 1. Force Sign In if unauthenticated
    if (!currentUser) {
      if (!['/signin', '/signup', '/forgot-password'].includes(currentPath)) {
        navigate('/signin');
      }
      return;
    }

    // 2. Redirect to Dashboard if logged in user visits signin/signup/forgot
    if (['/signin', '/signup', '/forgot-password'].includes(currentPath)) {
      navigate('/dashboard');
      return;
    }

    // 3. Dynamic teacher permission access routing
    if (currentUser.role === 'teacher') {
      const strictlyAdmin = ['/users', '/teachers', '/settings', '/subscription'];
      if (strictlyAdmin.includes(currentPath)) {
        navigate('/access-denied');
        return;
      }
      if (currentPath === '/fees' && !teacherPermissions?.canCollectFees) {
        navigate('/access-denied');
        return;
      }
      if (currentPath === '/reports' && !teacherPermissions?.canExportReports) {
        navigate('/access-denied');
        return;
      }
      if (currentPath === '/students' && teacherPermissions?.canViewStudents === false) {
        navigate('/access-denied');
        return;
      }
      if (currentPath === '/attendance' && teacherPermissions?.canMarkAttendance === false) {
        navigate('/access-denied');
        return;
      }
      if (currentPath === '/results' && teacherPermissions?.canEnterResults === false) {
        navigate('/access-denied');
        return;
      }
      if (currentPath === '/classes' && teacherPermissions?.canManageClasses === false) {
        navigate('/access-denied');
        return;
      }
      if (currentPath === '/timetable' && teacherPermissions?.canManageTimetable === false) {
        navigate('/access-denied');
        return;
      }
      if (currentPath === '/idcards' && teacherPermissions?.canViewIdCards === false) {
        navigate('/access-denied');
        return;
      }
      if (currentPath === '/admitcards' && teacherPermissions?.canViewAdmitCards === false) {
        navigate('/access-denied');
        return;
      }
    }

    // 4. Default route redirect
    if (currentPath === '/' || currentPath === '/setup') {
      navigate('/dashboard');
    }
  }, [currentUser, currentPath, teacherPermissions]);

  // ── Render 1: Public full-screen auth routes
  const isPublicRoute = ['/signin', '/signup', '/forgot-password'].includes(currentPath);
  if (!currentUser && isPublicRoute) {
    return (
      <>
        {currentPath === '/signin' && <SignInView />}
        {currentPath === '/signup' && <SignUpView />}
        {currentPath === '/forgot-password' && <ForgotPasswordView />}
      </>
    );
  }

  // ── Render 2: Onboarding Setup Wizard
  if (currentUser && currentPath === '/setup' && !settings.isSetupComplete) {
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
        <main className="flex-1 overflow-x-hidden p-4 sm:p-6 lg:p-8">
          <div className="w-full max-w-[1600px] mx-auto">
            {currentPath === '/dashboard' && <DashboardView />}
            {currentPath === '/notices' && (
              <NoticeBoardView
                onOpenPublish={() => { setEditingNotice(null); setIsAddNoticeOpen(true); }}
                onOpenView={(n) => setViewingNotice(n)}
                onOpenEdit={(n) => { setEditingNotice(n); setIsAddNoticeOpen(true); }}
              />
            )}
            {currentPath === '/students' && <StudentsView />}
            {currentPath === '/fees' && ((currentUser.role === 'principal' || teacherPermissions?.canCollectFees) ? <FeesView /> : <AccessDeniedView />)}
            {currentPath === '/attendance' && <AttendanceView />}
            {currentPath === '/results' && <ResultsView />}
            {currentPath === '/idcards' && <IdCardView />}
            {currentPath === '/admitcards' && <AdmitCardView />}
            {currentPath === '/timetable' && <TimetableView />}
            {currentPath === '/classes' && <ClassesView />}
            {currentPath === '/teachers' && <TeachersView />}
            {currentPath === '/reports' && ((currentUser.role === 'principal' || teacherPermissions?.canExportReports) ? <ReportsView /> : <AccessDeniedView />)}
            {currentPath === '/documents' && ((currentUser.role === 'principal' || teacherPermissions?.canExportReports) ? <ReportsView /> : <AccessDeniedView />)}
            {currentPath === '/import-export' && ((currentUser.role === 'principal' || teacherPermissions?.canExportReports) ? <ReportsView /> : <AccessDeniedView />)}
            {currentPath === '/qrscanner' && <QrScannerView />}
            {currentPath === '/settings' && <SettingsView />}
            {currentPath === '/subscription' && <SubscriptionView />}
            {currentPath === '/users' && <UserManagementView />}
            {currentPath === '/profile' && <ProfileView />}
            {currentPath === '/complaints' && <ParentComplaintsView />}
            {currentPath === '/devices' && <ConnectedDevicesView />}
            {currentPath === '/access-denied' && <AccessDeniedView />}
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
        <PrintResultModal result={printResultData.result} student={printResultData.student} onClose={() => setPrintResultData(null)} />
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

      {/* Super Admin Controlled Security & Device Telemetry Modal */}
      <SecurityPermissionModal
        securityConfig={securityConfig}
        schoolId={settings?.schoolId || currentUser?.schoolId || 'SCHOOL_001'}
        schoolName={settings?.schoolName || settings?.instituteName || 'School Management'}
        currentUser={currentUser}
        showToast={showToast}
        onAutoLogout={logout}
      />

      {/* Device Notifications History Modal */}
      <NotificationHistoryModal
        isOpen={isNotifHistoryOpen}
        onClose={() => setIsNotifHistoryOpen(false)}
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

export default function Home() {
  return (
    <SchoolProvider>
      <AppContent />
    </SchoolProvider>
  );
}
