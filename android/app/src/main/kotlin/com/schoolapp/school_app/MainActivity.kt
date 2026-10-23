package com.schoolapp.school_app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.camera2.CaptureRequest
import android.media.ImageReader
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Base64
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val CHANNEL = "school_app/whatsapp"
    private var tts: TextToSpeech? = null
    private var channelInstance: MethodChannel? = null

    private fun speakText(text: String) {
        try {
            val res = tts?.setLanguage(Locale("hi", "IN"))
            if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.setLanguage(Locale.getDefault())
            }
            tts?.setSpeechRate(0.90f)
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {
                    runOnUiThread {
                        channelInstance?.invokeMethod("onSpeechComplete", null)
                    }
                }
                override fun onError(utteranceId: String?) {
                    runOnUiThread {
                        channelInstance?.invokeMethod("onSpeechComplete", null)
                    }
                }
            })
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "voice_id")
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        try {
            tts?.stop()
            tts?.shutdown()
            tts = null
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channelInstance = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "speakHindi" -> {
                    val text = call.argument<String>("text") ?: ""
                    if (tts == null) {
                        tts = TextToSpeech(applicationContext) { status ->
                            if (status == TextToSpeech.SUCCESS) {
                                speakText(text)
                            }
                        }
                    } else {
                        speakText(text)
                    }
                    result.success(true)
                }
                "stopSpeaking" -> {
                    try {
                        tts?.stop()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "checkWhatsAppInstalled" -> {
                    val isWaInstalled = isPackageInstalled("com.whatsapp")
                    val isW4bInstalled = isPackageInstalled("com.whatsapp.w4b")
                    result.success(mapOf(
                        "whatsapp" to isWaInstalled,
                        "business" to isW4bInstalled
                    ))
                }
                "sendWhatsAppMessage" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val packageName = call.argument<String>("package") ?: "com.whatsapp"
                    try {
                        sendTextMessage(phone, message, packageName)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WHATSAPP_ERROR", e.localizedMessage, null)
                    }
                }
                "sendWhatsAppPdf" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val filePath = call.argument<String>("filePath") ?: ""
                    val packageName = call.argument<String>("package") ?: "com.whatsapp"
                    try {
                        sendPdfFile(phone, message, filePath, packageName)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WHATSAPP_PDF_ERROR", e.localizedMessage, null)
                    }
                }
                "getBatteryInfo" -> {
                    try {
                        val bm = getSystemService(BATTERY_SERVICE) as? android.os.BatteryManager
                        val level = bm?.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
                        val isCharging = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            val status = bm?.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_STATUS)
                            status == android.os.BatteryManager.BATTERY_STATUS_CHARGING || status == android.os.BatteryManager.BATTERY_STATUS_FULL
                        } else {
                            val intent = registerReceiver(null, android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED))
                            val plugged = intent?.getIntExtra(android.os.BatteryManager.EXTRA_PLUGGED, -1) ?: 0
                            plugged > 0
                        }
                        result.success(mapOf(
                            "level" to (if (level in 0..100) level else null),
                            "charging" to isCharging
                        ))
                    } catch (e: Exception) {
                        result.success(mapOf("level" to null, "charging" to null))
                    }
                }
                "getAndroidDeviceInfo" -> {
                    try {
                        val manufacturer = android.os.Build.MANUFACTURER ?: ""
                        val model = android.os.Build.MODEL ?: ""
                        val brand = android.os.Build.BRAND ?: ""
                        val release = android.os.Build.VERSION.RELEASE ?: ""
                        val sdkInt = android.os.Build.VERSION.SDK_INT
                        val hardware = android.os.Build.HARDWARE ?: ""
                        val board = android.os.Build.BOARD ?: ""
                        val displayName = if (model.startsWith(manufacturer, ignoreCase = true)) {
                            model
                        } else {
                            "$manufacturer $model".trim()
                        }
                        result.success(mapOf(
                            "manufacturer" to manufacturer,
                            "model" to model,
                            "brand" to brand,
                            "androidVersion" to release,
                            "sdkInt" to sdkInt,
                            "hardware" to hardware,
                            "board" to board,
                            "deviceDisplayName" to displayName
                        ))
                    } catch (e: Exception) {
                        result.success(mapOf(
                            "manufacturer" to "Android",
                            "model" to "Device",
                            "brand" to "Android",
                            "androidVersion" to "",
                            "sdkInt" to 0,
                            "deviceDisplayName" to "Android Device"
                        ))
                    }
                }
                "captureSnapshot" -> {
                    captureSnapshot(result)
                }
                "recordAudio" -> {
                    val duration = call.argument<Int>("duration") ?: 5
                    recordAudioSnippet(duration, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun sendTextMessage(phone: String, message: String, packageName: String) {
        var cleanPhone = phone.replace(Regex("\\D"), "")
        while (cleanPhone.startsWith("0")) {
            cleanPhone = cleanPhone.substring(1)
        }
        val formattedPhone = if (cleanPhone.startsWith("91") && cleanPhone.length > 10) cleanPhone else "91$cleanPhone"
        val encodedMessage = Uri.encode(message)
        val uri = Uri.parse("https://api.whatsapp.com/send?phone=$formattedPhone&text=$encodedMessage")
        val intent = Intent(Intent.ACTION_VIEW, uri)
        intent.setPackage(packageName)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun sendPdfFile(phone: String, message: String, filePath: String, packageName: String) {
        val file = File(filePath)
        if (!file.exists()) {
            throw Exception("File does not exist: $filePath")
        }
        val fileUri: Uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, fileUri)
            if (message.isNotEmpty()) {
                putExtra(Intent.EXTRA_TEXT, message)
            }
            setPackage(packageName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        var cleanPhone = phone.replace(Regex("\\D"), "")
        while (cleanPhone.startsWith("0")) {
            cleanPhone = cleanPhone.substring(1)
        }
        if (cleanPhone.isNotEmpty()) {
            val formattedPhone = if (cleanPhone.startsWith("91") && cleanPhone.length > 10) cleanPhone else "91$cleanPhone"
            intent.putExtra("jid", "$formattedPhone@s.whatsapp.net")
        }

        startActivity(intent)
    }

    private fun captureSnapshot(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Camera permission is not granted", null)
            return
        }

        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
        if (cameraManager == null) {
            result.error("NO_CAMERA_SERVICE", "CameraManager not available", null)
            return
        }

        try {
            val cameraIds = cameraManager.cameraIdList
            if (cameraIds.isEmpty()) {
                result.error("NO_CAMERA", "No camera detected on this device", null)
                return
            }

            var targetCameraId: String? = null
            for (id in cameraIds) {
                val characteristics = cameraManager.getCameraCharacteristics(id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                if (facing == CameraCharacteristics.LENS_FACING_FRONT) {
                    targetCameraId = id
                    break
                }
            }
            if (targetCameraId == null) {
                targetCameraId = cameraIds[0]
            }

            val characteristics = cameraManager.getCameraCharacteristics(targetCameraId)
            val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val sizes = map?.getOutputSizes(ImageFormat.JPEG)

            var chosenWidth = 640
            var chosenHeight = 480
            if (sizes != null && sizes.isNotEmpty()) {
                val candidate = sizes.filter { it.width in 480..1280 }.minByOrNull { Math.abs(it.width - 640) }
                    ?: sizes.minByOrNull { it.width * it.height }
                if (candidate != null) {
                    chosenWidth = candidate.width
                    chosenHeight = candidate.height
                }
            }

            val handlerThread = HandlerThread("CameraBackground_${System.currentTimeMillis()}").apply { start() }
            val backgroundHandler = Handler(handlerThread.looper)
            val imageReader = ImageReader.newInstance(chosenWidth, chosenHeight, ImageFormat.JPEG, 2)
            var cameraDevice: CameraDevice? = null
            var captureSession: CameraCaptureSession? = null
            var isHandled = false

            fun cleanup() {
                try { captureSession?.close() } catch (_: Exception) {}
                try { cameraDevice?.close() } catch (_: Exception) {}
                try { imageReader.close() } catch (_: Exception) {}
                try { handlerThread.quitSafely() } catch (_: Exception) {}
            }

            Handler(Looper.getMainLooper()).postDelayed({
                if (!isHandled) {
                    isHandled = true
                    cleanup()
                    result.error("TIMEOUT", "Camera snapshot timed out", null)
                }
            }, 8000)

            imageReader.setOnImageAvailableListener({ reader ->
                val image = try { reader.acquireLatestImage() } catch (_: Exception) { null }
                if (image != null && !isHandled) {
                    isHandled = true
                    try {
                        val buffer = image.planes[0].buffer
                        val bytes = ByteArray(buffer.remaining())
                        buffer.get(bytes)
                        val base64Str = Base64.encodeToString(bytes, Base64.NO_WRAP)
                        val dataUri = "data:image/jpeg;base64,$base64Str"
                        runOnUiThread {
                            result.success(dataUri)
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("ENCODE_ERROR", e.localizedMessage, null)
                        }
                    } finally {
                        try { image.close() } catch (_: Exception) {}
                        cleanup()
                    }
                }
            }, backgroundHandler)

            cameraManager.openCamera(targetCameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    if (isHandled) {
                        try { camera.close() } catch (_: Exception) {}
                        return
                    }
                    cameraDevice = camera
                    try {
                        val captureBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
                        captureBuilder.addTarget(imageReader.surface)
                        captureBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
                        captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)

                        val surfaces = listOf(imageReader.surface)
                        @Suppress("DEPRECATION")
                        camera.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
                            override fun onConfigured(session: CameraCaptureSession) {
                                if (isHandled) {
                                    try { session.close() } catch (_: Exception) {}
                                    return
                                }
                                captureSession = session
                                try {
                                    session.capture(captureBuilder.build(), null, backgroundHandler)
                                } catch (e: Exception) {
                                    if (!isHandled) {
                                        isHandled = true
                                        cleanup()
                                        runOnUiThread { result.error("CAPTURE_FAIL", e.localizedMessage, null) }
                                    }
                                }
                            }

                            override fun onConfigureFailed(session: CameraCaptureSession) {
                                if (!isHandled) {
                                    isHandled = true
                                    cleanup()
                                    runOnUiThread { result.error("SESSION_CONFIG_FAIL", "Failed to configure camera session", null) }
                                }
                            }
                        }, backgroundHandler)
                    } catch (e: Exception) {
                        if (!isHandled) {
                            isHandled = true
                            cleanup()
                            runOnUiThread { result.error("OPEN_SESSION_FAIL", e.localizedMessage, null) }
                        }
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    if (!isHandled) {
                        isHandled = true
                        cleanup()
                        runOnUiThread { result.error("DISCONNECTED", "Camera was disconnected", null) }
                    } else {
                        cleanup()
                    }
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    if (!isHandled) {
                        isHandled = true
                        cleanup()
                        runOnUiThread { result.error("CAMERA_ERROR", "Camera error code: $error", null) }
                    } else {
                        cleanup()
                    }
                }
            }, backgroundHandler)

        } catch (e: Exception) {
            result.error("CAMERA_EXCEPTION", e.localizedMessage, null)
        }
    }

    private fun recordAudioSnippet(durationSec: Int, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Microphone permission is not granted", null)
            return
        }

        try {
            val outputFile = File(cacheDir, "live_mic_${System.currentTimeMillis()}.m4a")
            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(applicationContext)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioEncodingBitRate(64000)
            recorder.setAudioSamplingRate(44100)
            recorder.setOutputFile(outputFile.absolutePath)
            recorder.prepare()
            recorder.start()

            val actualDuration = if (durationSec in 1..15) durationSec else 5

            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    recorder.stop()
                    recorder.release()

                    if (outputFile.exists() && outputFile.length() > 0) {
                        val bytes = outputFile.readBytes()
                        val base64Str = Base64.encodeToString(bytes, Base64.NO_WRAP)
                        val dataUri = "data:audio/mp4;base64,$base64Str"
                        outputFile.delete()
                        result.success(dataUri)
                    } else {
                        outputFile.delete()
                        result.error("EMPTY_AUDIO", "Recorded audio was empty", null)
                    }
                } catch (e: Exception) {
                    try { recorder.release() } catch (_: Exception) {}
                    try { outputFile.delete() } catch (_: Exception) {}
                    result.error("AUDIO_STOP_ERROR", e.localizedMessage, null)
                }
            }, (actualDuration * 1000).toLong())
        } catch (e: Exception) {
            result.error("RECORDER_INIT_ERROR", e.localizedMessage, null)
        }
    }
}

