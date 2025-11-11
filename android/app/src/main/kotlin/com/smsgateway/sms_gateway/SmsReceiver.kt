package com.smsgateway.sms_gateway

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.telephony.SmsMessage
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        private const val SMS_RECEIVED_ACTION = "android.provider.Telephony.SMS_RECEIVED"
        private val multipartMessages = mutableMapOf<String, MutableMap<Int, String>>()
        private val multipartCounts = mutableMapOf<String, Int>()
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "SMS Receiver triggered")
        
        if (intent.action != SMS_RECEIVED_ACTION) {
            Log.d(TAG, "Not an SMS received action: ${intent.action}")
            return
        }

        val bundle = intent.extras ?: return
        val pdus = bundle.get("pdus") as? Array<*> ?: return
        val format = bundle.getString("format")

        Log.d(TAG, "Processing ${pdus.size} SMS PDUs")

        val messages = mutableListOf<SmsMessage>()
        
        // Parse all PDUs
        for (pdu in pdus) {
            try {
                val smsMessage = if (format != null) {
                    SmsMessage.createFromPdu(pdu as ByteArray, format)
                } else {
                    SmsMessage.createFromPdu(pdu as ByteArray)
                }
                
                if (smsMessage != null) {
                    messages.add(smsMessage)
                    Log.d(TAG, "Parsed SMS from ${smsMessage.originatingAddress}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing SMS PDU", e)
            }
        }

        if (messages.isEmpty()) {
            Log.w(TAG, "No valid SMS messages parsed")
            return
        }

        // Process messages (handle multipart)
        processMessages(context, messages)
    }

    private fun processMessages(context: Context, messages: List<SmsMessage>) {
        val groupedMessages = mutableMapOf<String, MutableList<SmsMessage>>()
        
        // Group messages by sender
        for (message in messages) {
            val sender = message.originatingAddress ?: "Unknown"
            groupedMessages.getOrPut(sender) { mutableListOf() }.add(message)
        }

        // Process each sender's messages
        for ((sender, senderMessages) in groupedMessages) {
            processSenderMessages(context, sender, senderMessages)
        }
    }

    private fun processSenderMessages(context: Context, sender: String, messages: List<SmsMessage>) {
        // Check if this is a multipart message
        val firstMessage = messages.first()
        
        if (messages.size == 1 && firstMessage.messageBody != null) {
            // Single part message
            val receivedSms = ReceivedSms(
                sender = sender,
                message = firstMessage.messageBody,
                timestamp = firstMessage.timestampMillis,
                simSlot = getSimSlot(firstMessage)
            )
            
            Log.d(TAG, "Single SMS from $sender: ${firstMessage.messageBody}")
            storeSmsMessage(context, receivedSms)
        } else {
            // Potential multipart message
            handleMultipartMessage(context, sender, messages)
        }
    }

    private fun handleMultipartMessage(context: Context, sender: String, messages: List<SmsMessage>) {
        // Enhanced multipart handling with proper message reconstruction
        val messageKey = "$sender-${messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()}"
        
        // Check if this is a proper multipart message by looking at reference numbers
        val referenceNumber = messages.firstOrNull()?.let { msg ->
            try {
                // Try to get reference number from PDU (this is implementation-specific)
                msg.pdu?.let { pdu ->
                    if (pdu.size > 5) pdu[3].toInt() and 0xFF else null
                }
            } catch (e: Exception) {
                null
            }
        }
        
        // Sort messages by index for proper reconstruction
        val sortedMessages = messages.sortedBy { msg ->
            try {
                // Try to get the part index from the message
                msg.indexOnIcc
            } catch (e: Exception) {
                0
            }
        }
        
        // Combine all message parts
        val combinedMessage = StringBuilder()
        var timestamp = 0L
        var simSlot = 0
        
        for (message in sortedMessages) {
            message.messageBody?.let { body ->
                combinedMessage.append(body)
            }
            if (timestamp == 0L) {
                timestamp = message.timestampMillis
                simSlot = getSimSlot(message)
            }
        }

        val fullMessage = combinedMessage.toString()
        if (fullMessage.isNotEmpty()) {
            val receivedSms = ReceivedSms(
                sender = sender,
                message = fullMessage,
                timestamp = timestamp,
                simSlot = simSlot
            )
            
            Log.d(TAG, "Enhanced multipart SMS from $sender (${messages.size} parts, ref: $referenceNumber): $fullMessage")
            storeSmsMessage(context, receivedSms)
        }
    }

    private fun getSimSlot(message: SmsMessage): Int {
        return try {
            // Try to get SIM slot information
            // Note: subscriptionId is not directly available in SmsMessage
            // For now, return 0 as default SIM slot
            0
        } catch (e: Exception) {
            Log.w(TAG, "Could not determine SIM slot", e)
            0
        }
    }

    private fun storeSmsMessage(context: Context, receivedSms: ReceivedSms) {
        // Use coroutine to store message asynchronously
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Store in database via HttpServerService
                val serviceIntent = Intent(context, HttpServerService::class.java).apply {
                    action = "STORE_RECEIVED_SMS"
                    putExtra("sender", receivedSms.sender)
                    putExtra("message", receivedSms.message)
                    putExtra("timestamp", receivedSms.timestamp)
                    putExtra("sim_slot", receivedSms.simSlot)
                }
                
                // Start service to handle storage
                context.startService(serviceIntent)
                
                Log.d(TAG, "SMS storage request sent to HttpServerService")
            } catch (e: Exception) {
                Log.e(TAG, "Error storing SMS message", e)
            }
        }
    }

    data class ReceivedSms(
        val sender: String,
        val message: String,
        val timestamp: Long,
        val simSlot: Int
    )
}