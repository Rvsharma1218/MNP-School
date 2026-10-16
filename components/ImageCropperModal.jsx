'use client';

import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  X,
  Check,
  RotateCw,
  FlipHorizontal,
  ZoomIn,
  ZoomOut,
  Maximize2,
  Crop,
  Sparkles,
  RefreshCcw,
  Sliders,
  Move
} from 'lucide-react';

/**
 * ImageCropperModal:
 * High-performance, touch & mouse enabled image cropper for Student Photos & School Logos.
 * Automatically fits the entire photo on open so it is never over-zoomed or cut off.
 */
export default function ImageCropperModal({
  isOpen,
  imageSrc,
  title = 'Crop & Frame Image',
  initialAspect = '3:4',
  onCropComplete,
  onClose
}) {
  const [aspect, setAspect] = useState(initialAspect);
  const [zoom, setZoom] = useState(1);
  const [rotation, setRotation] = useState(0); // 0, 90, 180, 270
  const [flipH, setFlipH] = useState(false);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });

  const containerRef = useRef(null);
  const imageRef = useRef(null);
  const [imgNaturalSize, setImgNaturalSize] = useState({ width: 0, height: 0 });

  // Reset state and measure natural dimensions when imageSrc changes or modal opens
  useEffect(() => {
    if (isOpen && imageSrc) {
      setAspect(initialAspect);
      setZoom(1);
      setRotation(0);
      setFlipH(false);
      setPan({ x: 0, y: 0 });

      const img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = () => {
        setImgNaturalSize({
          width: img.naturalWidth || img.width || 400,
          height: img.naturalHeight || img.height || 400
        });
      };
      img.src = imageSrc;
    }
  }, [isOpen, imageSrc, initialAspect]);

  // Handle Drag / Pan with mouse & touch
  const handlePointerDown = (e) => {
    setIsDragging(true);
    const clientX = e.clientX ?? e.touches?.[0]?.clientX ?? 0;
    const clientY = e.clientY ?? e.touches?.[0]?.clientY ?? 0;
    setDragStart({ x: clientX - pan.x, y: clientY - pan.y });
  };

  const handlePointerMove = useCallback((e) => {
    if (!isDragging) return;
    const clientX = e.clientX ?? e.touches?.[0]?.clientX ?? 0;
    const clientY = e.clientY ?? e.touches?.[0]?.clientY ?? 0;
    setPan({
      x: clientX - dragStart.x,
      y: clientY - dragStart.y
    });
  }, [isDragging, dragStart]);

  const handlePointerUp = () => {
    setIsDragging(false);
  };

  // Mouse wheel zoom
  const handleWheel = (e) => {
    e.preventDefault();
    const zoomFactor = e.deltaY < 0 ? 0.08 : -0.08;
    setZoom((prev) => Math.min(3.5, Math.max(0.2, Number((prev + zoomFactor).toFixed(2)))));
  };

  // Aspect ratio dimensions for crop box on screen
  let cropBoxWidth = 240;
  let cropBoxHeight = 320;
  if (aspect === '1:1') {
    cropBoxWidth = 260;
    cropBoxHeight = 260;
  } else if (aspect === '4:3') {
    cropBoxWidth = 320;
    cropBoxHeight = 240;
  } else if (aspect === 'free') {
    cropBoxWidth = 280;
    cropBoxHeight = 280;
  }

  // Base dimensions calculation: fit image naturally inside the crop box
  let baseWidth = 240;
  let baseHeight = 320;
  if (imgNaturalSize.width > 0 && imgNaturalSize.height > 0) {
    const scale = Math.min(
      cropBoxWidth / imgNaturalSize.width,
      cropBoxHeight / imgNaturalSize.height
    );
    // Ensure base dimensions match the photo's true proportions scaled to fit
    baseWidth = Math.max(80, Math.round(imgNaturalSize.width * scale));
    baseHeight = Math.max(80, Math.round(imgNaturalSize.height * scale));
  }

  // Perform Final Crop on Canvas
  const handleApplyCrop = () => {
    if (!imageRef.current || !containerRef.current) return;

    const img = imageRef.current;
    const cropBoxEl = containerRef.current.querySelector('.crop-box-target');
    if (!cropBoxEl) return;

    const cropBoxRect = cropBoxEl.getBoundingClientRect();
    const imgRect = img.getBoundingClientRect();

    // Target export resolution (optimized for crisp ID card & ~50 KB size)
    let targetWidth = 480;
    let targetHeight = 640;
    if (aspect === '1:1') {
      targetWidth = 480;
      targetHeight = 480;
    } else if (aspect === '4:3') {
      targetWidth = 640;
      targetHeight = 480;
    } else if (aspect === 'free') {
      targetWidth = Math.min(600, Math.round(cropBoxRect.width * 2));
      targetHeight = Math.min(800, Math.round(cropBoxRect.height * 2));
    }

    const canvas = document.createElement('canvas');
    canvas.width = targetWidth;
    canvas.height = targetHeight;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Clean background
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, targetWidth, targetHeight);

    const scaleX = targetWidth / cropBoxRect.width;
    const scaleY = targetHeight / cropBoxRect.height;

    const offsetX = (imgRect.left - cropBoxRect.left) * scaleX;
    const offsetY = (imgRect.top - cropBoxRect.top) * scaleY;
    const renderWidth = imgRect.width * scaleX;
    const renderHeight = imgRect.height * scaleY;

    ctx.save();
    const imgCenterX = offsetX + renderWidth / 2;
    const imgCenterY = offsetY + renderHeight / 2;

    ctx.translate(imgCenterX, imgCenterY);
    if (rotation !== 0) {
      ctx.rotate((rotation * Math.PI) / 180);
    }
    if (flipH) {
      ctx.scale(-1, 1);
    }

    ctx.drawImage(
      img,
      -renderWidth / 2,
      -renderHeight / 2,
      renderWidth,
      renderHeight
    );
    ctx.restore();

    // Adaptive compressor targeting ~40KB - 55KB for fast Firebase sync
    let quality = 0.82;
    let croppedDataUrl = canvas.toDataURL('image/jpeg', quality);
    let sizeInKb = Math.round((croppedDataUrl.length * 3 / 4) / 1024);
    if (sizeInKb > 60) {
      quality = 0.74;
      croppedDataUrl = canvas.toDataURL('image/jpeg', quality);
    }

    if (onCropComplete) {
      onCropComplete(croppedDataUrl);
    }
    onClose();
  };

  if (!isOpen || !imageSrc) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/85 backdrop-blur-md animate-in fade-in duration-200 select-none">
      <div className="bg-[#0F172A] border border-slate-700/90 rounded-3xl w-full max-w-xl shadow-2xl overflow-hidden flex flex-col my-auto text-white">
        {/* Header */}
        <div className="px-5 py-3.5 border-b border-slate-800 flex items-center justify-between bg-slate-900/90">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-amber-400/20 text-amber-300 flex items-center justify-center border border-amber-400/30">
              <Crop className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-bold text-sm text-white tracking-wide">{title}</h3>
              <p className="text-[10px] text-slate-400">Drag to center &bull; Use slider to zoom in/out &bull; Crop entire photo</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Aspect Ratio Selector Pills */}
        <div className="px-5 py-2 bg-slate-900/60 border-b border-slate-800/80 flex items-center justify-between gap-2 overflow-x-auto custom-scrollbar">
          <span className="text-[11px] font-bold text-slate-400 flex items-center gap-1 flex-shrink-0">
            <Sliders className="w-3.5 h-3.5 text-amber-400" />
            <span>Preset:</span>
          </span>
          <div className="flex items-center gap-1.5 flex-nowrap">
            {[
              { id: '3:4', label: '3:4 (ID Photo / Full Face)' },
              { id: '1:1', label: '1:1 (Square / Logo)' },
              { id: '4:3', label: '4:3 (Landscape)' },
              { id: 'free', label: 'Free Frame' }
            ].map((p) => (
              <button
                key={p.id}
                type="button"
                onClick={() => setAspect(p.id)}
                className={`px-2.5 py-1 rounded-lg text-xs font-bold transition-all cursor-pointer whitespace-nowrap ${
                  aspect === p.id
                    ? 'bg-amber-400 text-slate-950 shadow-xs'
                    : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                }`}
              >
                {p.label}
              </button>
            ))}
          </div>
        </div>

        {/* Main Crop Viewport Container */}
        <div
          ref={containerRef}
          onMouseDown={handlePointerDown}
          onMouseMove={handlePointerMove}
          onMouseUp={handlePointerUp}
          onTouchStart={handlePointerDown}
          onTouchMove={handlePointerMove}
          onTouchEnd={handlePointerUp}
          onWheel={handleWheel}
          className="relative w-full h-[360px] sm:h-[400px] bg-[#070B19] overflow-hidden flex items-center justify-center cursor-grab active:cursor-grabbing"
        >
          {/* Target Image being manipulated */}
          {imageSrc && (
            <img
              ref={imageRef}
              src={imageSrc}
              alt="Crop target"
              draggable={false}
              style={{
                width: `${baseWidth}px`,
                height: `${baseHeight}px`,
                transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom}) rotate(${rotation}deg) scaleX(${flipH ? -1 : 1})`,
                transition: isDragging ? 'none' : 'transform 0.1s ease-out',
                maxWidth: 'none',
                maxHeight: 'none',
                userSelect: 'none',
                pointerEvents: 'none'
              }}
              className="absolute pointer-events-none"
            />
          )}

          {/* Dark Overlay around Crop Box (Box-shadow mask) */}
          <div
            className="crop-box-target absolute border-2 border-amber-400 rounded-xl pointer-events-none shadow-[0_0_0_9999px_rgba(5,10,25,0.78)]"
            style={{
              width: `${cropBoxWidth}px`,
              height: `${cropBoxHeight}px`
            }}
          >
            {/* Grid overlay lines (Rule of Thirds) */}
            <div className="w-full h-full grid grid-cols-3 grid-rows-3 pointer-events-none opacity-50">
              <div className="border-r border-b border-amber-400/40" />
              <div className="border-r border-b border-amber-400/40" />
              <div className="border-b border-amber-400/40" />
              <div className="border-r border-b border-amber-400/40" />
              <div className="border-r border-b border-amber-400/40" />
              <div className="border-b border-amber-400/40" />
              <div className="border-r border-b border-amber-400/40" />
              <div className="border-r border-b border-amber-400/40" />
              <div />
            </div>

            {/* Corner Markers */}
            <div className="absolute -top-1 -left-1 w-4 h-4 border-t-3 border-l-3 border-amber-300 rounded-tl" />
            <div className="absolute -top-1 -right-1 w-4 h-4 border-t-3 border-r-3 border-amber-300 rounded-tr" />
            <div className="absolute -bottom-1 -left-1 w-4 h-4 border-b-3 border-l-3 border-amber-300 rounded-bl" />
            <div className="absolute -bottom-1 -right-1 w-4 h-4 border-b-3 border-r-3 border-amber-300 rounded-br" />

            {/* Frame Aspect Label */}
            <div className="absolute bottom-2 left-2 bg-black/80 px-2 py-0.5 rounded-md text-[9px] font-black text-amber-300 tracking-wider uppercase border border-amber-400/30">
              {aspect === '3:4' ? 'Student ID Frame' : aspect === '1:1' ? 'Square Logo' : aspect}
            </div>

            {/* Drag hint overlay */}
            <div className="absolute top-2 right-2 bg-black/60 px-1.5 py-0.5 rounded text-[8.5px] font-bold text-slate-300 flex items-center gap-1">
              <Move className="w-2.5 h-2.5" />
              <span>Drag to Pan</span>
            </div>
          </div>
        </div>

        {/* Toolbar Controls: Zoom & Rotate */}
        <div className="px-5 py-3 bg-slate-900 border-t border-slate-800 flex flex-col gap-3">
          <div className="flex items-center justify-between gap-4">
            {/* Zoom Slider */}
            <div className="flex items-center gap-2 flex-1">
              <button
                type="button"
                onClick={() => setZoom((prev) => Math.max(0.2, Number((prev - 0.1).toFixed(2))))}
                className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 cursor-pointer"
                title="Zoom Out (Show more photo)"
              >
                <ZoomOut className="w-4 h-4" />
              </button>
              <input
                type="range"
                min="0.2"
                max="3"
                step="0.05"
                value={zoom}
                onChange={(e) => setZoom(parseFloat(e.target.value))}
                className="w-full accent-amber-400 cursor-pointer h-2 bg-slate-700 rounded-lg"
              />
              <button
                type="button"
                onClick={() => setZoom((prev) => Math.min(3.5, Number((prev + 0.1).toFixed(2))))}
                className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 cursor-pointer"
                title="Zoom In"
              >
                <ZoomIn className="w-4 h-4" />
              </button>
              <span className="text-[11px] font-bold text-amber-400 w-12 text-right font-mono">
                {Math.round(zoom * 100)}%
              </span>
            </div>

            {/* Rotate & Flip & Reset */}
            <div className="flex items-center gap-1.5 flex-shrink-0 border-l border-slate-700/80 pl-3">
              <button
                type="button"
                onClick={() => setRotation((r) => (r + 90) % 360)}
                className="px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold flex items-center gap-1 cursor-pointer transition-colors"
                title="Rotate 90° Clockwise"
              >
                <RotateCw className="w-3.5 h-3.5 text-amber-400" />
                <span className="hidden sm:inline">Rotate</span>
              </button>
              <button
                type="button"
                onClick={() => setFlipH(!flipH)}
                className={`p-1.5 rounded-lg text-xs font-bold cursor-pointer transition-colors ${
                  flipH ? 'bg-amber-400 text-slate-950' : 'bg-slate-800 hover:bg-slate-700 text-slate-200'
                }`}
                title="Flip Horizontal"
              >
                <FlipHorizontal className="w-3.5 h-3.5" />
              </button>
              <button
                type="button"
                onClick={() => {
                  setZoom(1);
                  setRotation(0);
                  setFlipH(false);
                  setPan({ x: 0, y: 0 });
                }}
                className="px-2 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-bold flex items-center gap-1 cursor-pointer"
                title="Fit full photo to frame"
              >
                <RefreshCcw className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Fit Photo</span>
              </button>
            </div>
          </div>
        </div>

        {/* Modal Action Buttons */}
        <div className="px-5 py-3.5 bg-slate-950 border-t border-slate-800/80 flex items-center justify-between">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-bold text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleApplyCrop}
            className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-amber-400 to-amber-500 hover:from-amber-500 hover:to-amber-600 text-slate-950 font-black text-xs shadow-lg flex items-center gap-1.5 cursor-pointer transition-all active:scale-95"
          >
            <Check className="w-4 h-4" />
            <span>Crop & Apply Photo</span>
          </button>
        </div>
      </div>
    </div>
  );
}
