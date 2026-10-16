import React from 'react';
import { useSchoolStore } from '../lib/store';
import { QRCodeSVG } from 'qrcode.react';
import { Printer, X, Download, FileText } from 'lucide-react';
import { exportIdCardsPDF, exportIdCardPNG } from '../lib/exportUtils';

export default function PrintIdCardsModal({ students, template, onClose }) {
  const { settings, showToast } = useSchoolStore();

  if (!students || students.length === 0) return null;

  const handlePrint = () => {
    window.print();
  };

  const handleSavePDF = async () => {
    await exportIdCardsPDF(students, settings);
    showToast(`Saved ${students.length} ID cards to PDF successfully!`, 'success');
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-card border border-border w-full max-w-6xl rounded-3xl shadow-2xl overflow-hidden my-8 animate-in fade-in zoom-in-95 duration-200">
        {/* Header (Hidden during Print) */}
        <div className="p-4 border-b border-border flex items-center justify-between bg-surface2/60 print:hidden">
          <div>
            <h3 className="font-extrabold text-sm text-text">
              Batch Student ID Cards Print Preview ({students.length})
            </h3>
            <p className="text-xs text-text-secondary">
              Official front and back print layout optimized for standard card stock.
            </p>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handleSavePDF}
              className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs flex items-center gap-1.5 shadow-xs cursor-pointer transition-all active:scale-95"
            >
              <FileText className="w-3.5 h-3.5" />
              <span>Save PDF ({students.length})</span>
            </button>

            <button
              onClick={handlePrint}
              className="px-4 py-2 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-xs flex items-center gap-1.5 shadow-xs cursor-pointer transition-all active:scale-95"
            >
              <Printer className="w-3.5 h-3.5" />
              <span>Print All ({students.length})</span>
            </button>

            <button
              onClick={onClose}
              className="p-2 rounded-xl text-text-secondary hover:text-text hover:bg-surface2 transition-colors cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* ─── BATCH ID CARDS PRINT GRID ─── */}
        <div className="p-6 overflow-y-auto max-h-[75vh] bg-surface2/30 print:bg-white print:p-0 print:overflow-visible">
          <div className="grid grid-cols-1 gap-8 justify-items-center print:block print:space-y-6">
            {students.map((student) => (
              <div
                key={student.id}
                className="flex flex-col sm:flex-row gap-4 items-center print:flex-row print:gap-4 print:page-break-inside-avoid print:justify-center"
              >
                {/* ─── FRONT SIDE OF ID CARD ─── */}
                <div className="w-[400px] h-[252px] rounded-xl shadow-xl overflow-hidden flex flex-col border border-amber-400/40 bg-gradient-to-br from-[#0A1128] to-[#1C2541] text-white select-none print:shadow-none print:border">
                  {/* Top Gold Accent Bar */}
                  <div className="bg-[#FFD700] text-[#0A1128] px-3.5 py-0.5 flex items-center justify-between text-[9px] font-black tracking-wider uppercase">
                    <span>OFFICIAL STUDENT ID</span>
                    <span>SESSION {student.session || settings.currentSession || '2026-27'}</span>
                  </div>

                  {/* Institute Header */}
                  <div className="bg-[#0A1128] px-3 py-1.5 text-center border-b border-[#FFD700]/40 flex items-center justify-center gap-2.5">
                    {settings.logoUrl || settings.logoPath || settings.logo ? (
                      <img
                        src={settings.logoUrl || settings.logoPath || settings.logo}
                        alt="Logo"
                        className="w-8 h-8 object-contain rounded-md bg-white/10 p-0.5 flex-shrink-0"
                        onError={(e) => { e.currentTarget.style.display = 'none'; }}
                      />
                    ) : null}
                    <div className="min-w-0 flex-1">
                      <h3 className="font-black text-[13px] tracking-wide uppercase text-white leading-tight truncate">
                        {settings.instituteName || "MISSION NAVODAYA PUBLIC SCHOOL"}
                      </h3>
                      <p className="text-[8.5px] text-[#FFD700] tracking-wide truncate mt-0.5 font-semibold">
                        {settings.address || "Mora Mairi, Bhagwaanpur, Siwan, Bihar 841507"}
                      </p>
                    </div>
                  </div>

                  {/* Body Content */}
                  <div className="flex-1 p-3 flex items-center gap-3">
                    {/* Photo */}
                    <div className="flex flex-col items-center flex-shrink-0">
                      <div className="w-[84px] h-[98px] rounded-lg border-2 border-[#FFD700] overflow-hidden bg-[#0A1128] flex items-center justify-center shadow-md">
                        {student.photoPath ? (
                          <img src={student.photoPath} alt={student.name} className="w-full h-full object-cover" />
                        ) : (
                          <span className="text-2xl font-black text-white">{student.name?.charAt(0) || 'S'}</span>
                        )}
                      </div>
                      <div className="mt-1 bg-[#FFD700] text-[#0A1128] text-[8px] font-black uppercase px-2 py-0.5 rounded shadow-2xs">
                        STUDENT
                      </div>
                    </div>

                    {/* Details */}
                    <div className="flex-1 min-w-0 space-y-1 text-[10.5px]">
                      <h4 className="font-black text-sm uppercase text-white tracking-wide truncate mb-1">
                        {student.name}
                      </h4>
                      <div className="flex"><span className="w-16 font-extrabold text-amber-300 text-[10px]">ID NO:</span><span className="font-bold text-white text-[10.5px]">{student.studentId}</span></div>
                      <div className="flex"><span className="w-16 font-extrabold text-amber-300 text-[10px]">ADM NO:</span><span className="font-bold text-white text-[10.5px]">{student.admissionNumber || student.studentId}</span></div>
                      <div className="flex">
                        <span className="w-16 font-extrabold text-amber-300 text-[10px]">{student.studentType === 'school' ? 'CLASS:' : 'COURSE:'}</span>
                        <span className="font-bold text-white text-[10.5px]">{student.studentType === 'school' ? `Class ${student.className || ''} - ${student.section || 'A'}` : student.course}</span>
                      </div>
                      <div className="flex"><span className="w-16 font-extrabold text-amber-300 text-[10px]">FATHER:</span><span className="font-bold text-white text-[10.5px] truncate">{student.fatherName || '—'}</span></div>
                      <div className="flex"><span className="w-16 font-extrabold text-amber-300 text-[10px]">MOBILE:</span><span className="font-bold text-white text-[10.5px]">{student.mobile}</span></div>
                    </div>

                    {/* QR Code */}
                    <div className="flex flex-col items-center flex-shrink-0 bg-white/5 p-1 rounded-lg border border-white/10">
                      <div className="p-0.5 bg-white rounded">
                        <QRCodeSVG
                          value={`ID:${student.studentId}|Name:${student.name}|Mobile:${student.mobile}`}
                          size={52}
                          level="M"
                        />
                      </div>
                      <span className="text-[6.5px] text-slate-400 mt-1 uppercase font-bold tracking-widest">
                        SCAN TO VERIFY
                      </span>
                    </div>
                  </div>

                  {/* Bottom Footer Bar */}
                  <div className="bg-[#05091E] px-3.5 py-1 flex items-center justify-between text-[7.5px] border-t border-[#FFD700]/20 relative">
                    <span className="text-slate-400 font-semibold uppercase truncate max-w-[220px]">
                      PROPERTY OF {settings.instituteName || "MISSION NAVODAYA PUBLIC SCHOOL"}
                    </span>
                    <div className="relative flex items-center justify-end">
                      {settings.principalSignature || settings.signatureUrl ? (
                        <img
                          src={settings.principalSignature || settings.signatureUrl}
                          alt="Sign"
                          className="absolute -top-7 right-0 h-9 max-w-[100px] object-contain pointer-events-none"
                          onError={(e) => { e.currentTarget.style.display = 'none'; }}
                        />
                      ) : null}
                      <span className="text-[#FFD700] font-black uppercase tracking-wider text-[7.5px]">
                        AUTH SIGNATURE
                      </span>
                    </div>
                  </div>
                </div>

                {/* ─── BACK SIDE OF ID CARD ─── */}
                <div className="w-[400px] h-[250px] rounded-lg shadow-xl overflow-hidden flex flex-col border border-amber-400/40 bg-[#0A1128] text-white select-none print:shadow-none print:border">
                  {/* Top Bar Spacer */}
                  <div className="h-2 bg-[#FFD700]" />

                  {/* Back content */}
                  <div className="flex-1 p-5 flex flex-col justify-between">
                    <div className="space-y-2">
                      <h4 className="font-bold text-xs uppercase text-[#FFD700] tracking-wider">
                        Terms & Conditions
                      </h4>
                      <ol className="list-decimal pl-4 text-[9.5px] text-slate-300 space-y-1 leading-snug">
                        <li>This card is non-transferable and must be presented upon request.</li>
                        <li>If found, please return to the institute address below.</li>
                        <li>Loss of this card must be reported immediately.</li>
                      </ol>
                    </div>

                    <div className="w-full h-0.5 bg-[#FFD700]/40 my-2" />

                    <div className="flex items-end justify-between text-[8.5px] text-slate-300">
                      <div className="space-y-0.5 leading-tight max-w-[220px]">
                        <p className="font-bold text-white text-[10px]">
                          {settings.instituteName || "Mission Navodaya Public School"}
                        </p>
                        <p>Ph: {settings.mobile || "9876543210"}</p>
                        <p className="truncate">{settings.address || "Mora Mairi, Bhagwaanpur, Siwan, Bihar 841507"}</p>
                      </div>

                      <div className="text-center flex-shrink-0 relative">
                        {settings.principalSignature || settings.signatureUrl ? (
                          <img
                            src={settings.principalSignature || settings.signatureUrl}
                            alt="Signature"
                            className="absolute -top-8 left-1/2 -translate-x-1/2 h-10 max-w-[120px] object-contain pointer-events-none"
                            onError={(e) => { e.currentTarget.style.display = 'none'; }}
                          />
                        ) : null}
                        <div className="w-28 border-t border-white/60 mb-0.5" />
                        <span className="text-[8px] uppercase font-bold text-slate-400">Principal Sign</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
