package com.smsgateway.sms_gateway

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "sms_gateway/sms"
    private val BACKGROUND_SERVICE_CHANNEL = "sms_gateway/background_service"
    private val SMS_PERMISSION_REQUEST = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // SMS Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val recipient = call.argument<String>("recipient")
                    val message = call.argument<String>("message")
                    val messageId = call.argument<String>("messageId")
                    
                    if (recipient != null && message != null && messageId != null) {
                        sendSMS(recipient, message, messageId, result)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Background Service Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    HttpServerService.startService(this)
                    result.success(true)
                }
                "stopService" -> {
                    HttpServerService.stopService(this)
                    result.success(true)
                }
                "isServiceRunning" -> {
                    // For now, we'll assume service is running if it was started
                    // In a real implementation, you'd check the actual service status
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendSMS(recipient: String, message: String, messageId: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_REQUEST)
            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
            return
        }

        try {
            val smsManager = SmsManager.getDefault()
            
            // Check if message is longer than 160 characters
            if (message.length > 160) {
                // Use multipart SMS for long messages
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(recipient, null, parts, null, null)
                result.success("Multipart SMS sent successfully (${parts.size} parts)")
            } else {
                // Use single SMS for short messages
                smsManager.sendTextMessage(recipient, null, message, null, null)
                result.success("SMS sent successfully")
            }
        } catch (e: Exception) {
            result.error("SMS_FAILED", "Failed to send SMS: ${e.message}", null)
        }
    }
}
