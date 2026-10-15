package com.schoolapp.school_app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "school_app/whatsapp"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
        val cleanPhone = phone.replace(Regex("\\D"), "")
        val formattedPhone = if (cleanPhone.startsWith("91")) cleanPhone else "91$cleanPhone"
        val encodedMessage = Uri.encode(message)
        val uri = Uri.parse("https://wa.me/$formattedPhone?text=$encodedMessage")
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

        val cleanPhone = phone.replace(Regex("\\D"), "")
        if (cleanPhone.isNotEmpty()) {
            val formattedPhone = if (cleanPhone.startsWith("91")) cleanPhone else "91$cleanPhone"
            intent.putExtra("jid", "$formattedPhone@s.whatsapp.net")
        }

        startActivity(intent)
    }
}

