package com.smsgateway.sms_gateway

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Boot receiver triggered with action: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                Log.d(TAG, "Device boot completed or app updated - Starting SMS Gateway service")
                
                try {
                    // Start the background HTTP server service
                    HttpServerService.startService(context)
                    Log.d(TAG, "SMS Gateway background service started successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start SMS Gateway service on boot", e)
                }
            }
            else -> {
                Log.d(TAG, "Unhandled action: ${intent.action}")
            }
        }
    }
}