package com.smsgateway.sms_gateway

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.*
import java.net.*
import org.json.JSONObject
import org.json.JSONArray
import java.util.concurrent.Executors

class HttpServerService : Service() {
    companion object {
        private const val CHANNEL_ID = "SMS_GATEWAY_SERVICE"
        private const val NOTIFICATION_ID = 1
        
        @Volatile
        private var instance: HttpServerService? = null
        
        fun startService(context: Context) {
            val intent = Intent(context, HttpServerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, HttpServerService::class.java)
            context.stopService(intent)
        }
    }
    
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var httpServer: java.net.ServerSocket? = null
    private var isServerRunning = false
    private var serverThread: Thread? = null
    
    override fun onCreate() {
        super.onCreate()
        
        // Stop any existing instance
        instance?.let { existingInstance ->
            existingInstance.stopHttpServer()
        }
        instance = this
        
        createNotificationChannel()
        acquireWakeLocks()
        Log.d("HttpServerService", "Service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Acquire wake locks to keep service running in background
        acquireWakeLocks()
        
        Log.d("HttpServerService", "Foreground service started (HTTP server handled by Dart)")
        
        return START_STICKY // Restart service if killed by system
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopHttpServer()
        releaseWakeLocks()
        instance = null
    }
    
    private fun startHttpServer() {
        if (isServerRunning) {
            Log.d("HttpServerService", "HTTP server already running")
            return
        }
        
        serverThread = Thread {
            try {
                // Try to close any existing server first
                httpServer?.close()
                Thread.sleep(1000) // Give time for port to be released
                
                // Try different ports if 8080 is in use
                var port = 8080
                var serverSocket: ServerSocket? = null
                var attempts = 0
                
                while (serverSocket == null && attempts < 5) {
                    try {
                        serverSocket = ServerSocket(port, 50, InetAddress.getByName("0.0.0.0"))
                        Log.d("HttpServerService", "HTTP server started on port $port, listening on all interfaces")
                        break
                    } catch (e: Exception) {
                        Log.w("HttpServerService", "Port $port in use, trying ${port + 1}")
                        port++
                        attempts++
                        if (attempts >= 5) {
                            throw e
                        }
                    }
                }
                
                httpServer = serverSocket
                isServerRunning = true
                
                val executor = Executors.newFixedThreadPool(10)
                
                while (isServerRunning && httpServer?.isClosed == false) {
                    try {
                        val clientSocket = httpServer?.accept()
                        clientSocket?.let { socket ->
                            executor.submit {
                                handleHttpRequest(socket)
                            }
                        }
                    } catch (e: Exception) {
                        if (isServerRunning) {
                            Log.e("HttpServerService", "Error accepting connection", e)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("HttpServerService", "Error starting HTTP server", e)
                isServerRunning = false
            }
        }
        serverThread?.start()
    }
    
    private fun stopHttpServer() {
        isServerRunning = false
        try {
            httpServer?.close()
            serverThread?.interrupt()
            Log.d("HttpServerService", "HTTP server stopped")
        } catch (e: Exception) {
            Log.e("HttpServerService", "Error stopping HTTP server", e)
        }
    }
    
    private fun handleHttpRequest(socket: Socket) {
        try {
            val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
            val writer = OutputStreamWriter(socket.getOutputStream())
            
            // Read the HTTP request
            val requestLine = reader.readLine()
            if (requestLine == null) {
                socket.close()
                return
            }
            
            Log.d("HttpServerService", "Received request: $requestLine")
            
            // Read headers
            var contentLength = 0
            var line: String?
            while (reader.readLine().also { line = it } != null && line!!.isNotEmpty()) {
                if (line!!.startsWith("Content-Length:")) {
                    contentLength = line!!.substring(15).trim().toInt()
                }
            }
            
            // Parse request
            val parts = requestLine.split(" ")
            if (parts.size >= 2) {
                val method = parts[0]
                val path = parts[1]
                
                when {
                    method == "POST" && path == "/send-sms" -> {
                        handleSendSms(reader, writer, contentLength)
                    }
                    method == "POST" && path == "/send-bulk-sms" -> {
                        handleSendBulkSms(reader, writer, contentLength)
                    }
                    method == "GET" && path == "/status" -> {
                        handleStatus(writer)
                    }
                    else -> {
                        sendHttpResponse(writer, 404, "Not Found", "Endpoint not found")
                    }
                }
            } else {
                sendHttpResponse(writer, 400, "Bad Request", "Invalid request format")
            }
            
            socket.close()
        } catch (e: Exception) {
            Log.e("HttpServerService", "Error handling HTTP request", e)
            try {
                socket.close()
            } catch (closeException: Exception) {
                Log.e("HttpServerService", "Error closing socket", closeException)
            }
        }
    }
    
    private fun handleSendSms(reader: BufferedReader, writer: OutputStreamWriter, contentLength: Int) {
        try {
            // Read request body
            val bodyChars = CharArray(contentLength)
            reader.read(bodyChars, 0, contentLength)
            val body = String(bodyChars)
            
            Log.d("HttpServerService", "SMS request body: $body")
            
            // Parse JSON
            val json = JSONObject(body)
            val recipient = json.getString("recipient")
            val message = json.getString("message")
            val messageId = json.optString("messageId", java.util.UUID.randomUUID().toString())
            
            // Send SMS
            val success = sendSmsMessage(recipient, message, messageId)
            
            if (success) {
                val response = JSONObject()
                response.put("success", true)
                response.put("messageId", messageId)
                response.put("message", "SMS sent successfully")
                sendHttpResponse(writer, 200, "OK", response.toString())
            } else {
                val response = JSONObject()
                response.put("success", false)
                response.put("error", "Failed to send SMS")
                sendHttpResponse(writer, 500, "Internal Server Error", response.toString())
            }
        } catch (e: Exception) {
            Log.e("HttpServerService", "Error handling send SMS request", e)
            val response = JSONObject()
            response.put("success", false)
            response.put("error", "Invalid request: ${e.message}")
            sendHttpResponse(writer, 400, "Bad Request", response.toString())
        }
    }
    
    private fun handleSendBulkSms(reader: BufferedReader, writer: OutputStreamWriter, contentLength: Int) {
        try {
            // Read request body
            val bodyChars = CharArray(contentLength)
            reader.read(bodyChars, 0, contentLength)
            val body = String(bodyChars)
            
            Log.d("HttpServerService", "Bulk SMS request body: $body")
            
            // Parse JSON
            val json = JSONObject(body)
            val messages = json.getJSONArray("messages")
            val results = mutableListOf<JSONObject>()
            
            for (i in 0 until messages.length()) {
                val messageObj = messages.getJSONObject(i)
                val recipient = messageObj.getString("recipient")
                val message = messageObj.getString("message")
                val messageId = messageObj.optString("messageId", java.util.UUID.randomUUID().toString())
                
                val success = sendSmsMessage(recipient, message, messageId)
                
                val result = JSONObject()
                result.put("messageId", messageId)
                result.put("recipient", recipient)
                result.put("success", success)
                if (!success) {
                    result.put("error", "Failed to send SMS")
                }
                results.add(result)
            }
            
            val response = JSONObject()
            response.put("success", true)
            response.put("results", results)
            sendHttpResponse(writer, 200, "OK", response.toString())
        } catch (e: Exception) {
            Log.e("HttpServerService", "Error handling bulk SMS request", e)
            val response = JSONObject()
            response.put("success", false)
            response.put("error", "Invalid request: ${e.message}")
            sendHttpResponse(writer, 400, "Bad Request", response.toString())
        }
    }
    
    private fun handleStatus(writer: OutputStreamWriter) {
        val response = JSONObject()
        response.put("status", "running")
        response.put("server", "SMS Gateway")
        response.put("port", 8080)
        sendHttpResponse(writer, 200, "OK", response.toString())
    }
    
    private fun sendHttpResponse(writer: OutputStreamWriter, statusCode: Int, statusText: String, body: String) {
        val response = "HTTP/1.1 $statusCode $statusText\r\n" +
                "Content-Type: application/json\r\n" +
                "Content-Length: ${body.length}\r\n" +
                "Access-Control-Allow-Origin: *\r\n" +
                "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                "Access-Control-Allow-Headers: Content-Type\r\n" +
                "\r\n" +
                body
        
        writer.write(response)
        writer.flush()
    }
    
    private fun sendSmsMessage(recipient: String, message: String, messageId: String): Boolean {
        return try {
            // Check SMS permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                Log.e("HttpServerService", "SMS permission not granted")
                return false
            }
            
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(recipient, null, message, null, null)
            Log.d("HttpServerService", "SMS sent to $recipient: $message")
            true
        } catch (e: Exception) {
            Log.e("HttpServerService", "Error sending SMS", e)
            false
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SMS Gateway Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps SMS Gateway HTTP server running in background"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SMS Gateway Active")
            .setContentText("Background service running - Ready to receive messages")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    

    
    private fun acquireWakeLocks() {
        try {
            // Acquire CPU wake lock to keep the service running
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "SMSGateway::BackgroundService"
            )
            wakeLock?.acquire()
            Log.d("HttpServerService", "CPU wake lock acquired")
            
            // Acquire WiFi lock to maintain network connectivity
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiLock = wifiManager.createWifiLock(
                WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                "SMSGateway::NetworkLock"
            )
            wifiLock?.acquire()
            Log.d("HttpServerService", "WiFi lock acquired")
            
        } catch (e: Exception) {
            Log.e("HttpServerService", "Failed to acquire wake locks: ${e.message}")
        }
    }
    
    private fun releaseWakeLocks() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d("HttpServerService", "CPU wake lock released")
                }
            }
            wakeLock = null
            
            wifiLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d("HttpServerService", "WiFi lock released")
                }
            }
            wifiLock = null
            
        } catch (e: Exception) {
            Log.e("HttpServerService", "Failed to release wake locks: ${e.message}")
        }
    }
}