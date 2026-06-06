package com.guardcall.app.service

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log
import com.guardcall.app.data.AppDatabase
import com.guardcall.app.data.CallIncidentReport
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.regex.Pattern

class SmsReceiver : BroadcastReceiver() {

    private val receiverJob = SupervisorJob()
    private val receiverScope = CoroutineScope(Dispatchers.IO + receiverJob)

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        for (message in messages) {
            val sender = message.originatingAddress ?: "Unknown"
            val body = message.messageBody ?: ""

            Log.d("SmsReceiver", "Received SMS from $sender: $body")

            // Scan for URL links
            val urls = extractUrls(body)
            if (urls.isNotEmpty()) {
                val firstUrl = urls[0]
                
                receiverScope.launch {
                    val db = AppDatabase.getDatabase(context.applicationContext, receiverScope)
                    
                    // 1. Log incident report as high-risk phishing SMS
                    val reportId = db.scamDao().insertReport(
                        CallIncidentReport(
                            callerNumber = sender,
                            carrierLocation = "SMS Network Carrier",
                            riskScore = 85, // Automated high score for unverified link SMS
                            dialogTranscript = "[SMS Received]: $body",
                            linkIntercepted = firstUrl
                        )
                    )

                    // 2. Broadcast SMS blocking notification to MainActivity / System UI Overlay
                    broadcastSmsIntercept(context, sender, body, firstUrl, reportId)

                    // 3. Automatically reply with Spammer Consent IP-Tracker Link (Honeypot)
                    // The link asks them to consent to geolocation sharing
                    val consentLink = "https://guardcall.link/consent-${reportId}"
                    sendSmsReply(sender, "Please review and accept our security tracking policy first to continue transfer authorization: $consentLink")
                }
            }
        }
    }

    private fun extractUrls(text: String): List<String> {
        val containedUrls = ArrayList<String>()
        val urlRegex = "((https?|ftp|gopher|telnet|file):((//)|(\\\\))+[\\w\\d:#@%/;\$()~_?\\+-=\\\\\\.&]*)"
        val pattern = Pattern.compile(urlRegex, Pattern.CASE_INSENSITIVE)
        val urlMatcher = pattern.matcher(text)

        while (urlMatcher.find()) {
            containedUrls.add(text.substring(urlMatcher.start(0), urlMatcher.end(0)))
        }
        return containedUrls
    }

    private fun sendSmsReply(toAddress: String, message: String) {
        try {
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(toAddress, null, message, null, null)
            Log.d("SmsReceiver", "Sent honeypot consent SMS reply to $toAddress")
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Failed to send SMS reply: ${e.message}")
        }
    }

    private fun broadcastSmsIntercept(context: Context, sender: String, body: String, url: String, reportId: Long) {
        val intent = Intent("com.guardcall.app.SMS_INTERCEPTED").apply {
            putExtra("EXTRA_SENDER", sender)
            putExtra("EXTRA_BODY", body)
            putExtra("EXTRA_URL", url)
            putExtra("EXTRA_REPORT_ID", reportId)
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }
}
