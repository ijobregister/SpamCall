package com.hkaiSolveAcademy.vibeCoding.matszyu.service

import android.content.Intent
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import androidx.annotation.RequiresApi
import com.hkaiSolveAcademy.vibeCoding.matszyu.data.AppDatabase
import com.hkaiSolveAcademy.vibeCoding.matszyu.data.ScamNumber
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@RequiresApi(Build.VERSION_CODES.Q)
class CallScreeningServiceImpl : CallScreeningService() {

    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Main + serviceJob)

    override fun onScreenCall(callDetails: Call.Details) {
        // Only screen incoming calls
        if (callDetails.callDirection != Call.Details.DIRECTION_INCOMING) {
            return
        }

        val handle = callDetails.handle
        val phoneNumber = handle?.schemeSpecificPart ?: ""
        
        serviceScope.launch {
            val scamRecord = checkPhoneNumberInBlacklist(phoneNumber)
            val response = CallResponse.Builder()

            if (scamRecord != null) {
                // Number found in blacklist: block the call
                response.setDisallowCall(true)
                response.setRejectCall(true)
                response.setSkipNotification(true)
                response.setSkipCallLog(false) // Still log it so the user knows they were protected

                // Broadcast local event to show custom system overlay alert
                sendOverlayAlertBroadcast(phoneNumber, scamRecord.entityName, "Kowloon City, HK")
            } else {
                // Allow call, but check for suspicion rules (e.g., country code mismatch)
                response.setDisallowCall(false)
                response.setRejectCall(false)
                response.setSkipNotification(false)

                // If number is unknown mobile number, launch warning overlay to watch out for AI skepticism
                if (phoneNumber.startsWith("+") && !phoneNumber.startsWith("+852")) {
                    sendOverlayAlertBroadcast(phoneNumber, "Unknown International Caller", "Foreign Carrier")
                }
            }

            respondToCall(callDetails, response.build())
        }
    }

    private suspend fun checkPhoneNumberInBlacklist(phoneNumber: String): ScamNumber? = withContext(Dispatchers.IO) {
        val database = AppDatabase.getDatabase(applicationContext, serviceScope)
        // Check exact match or strip country code for regional check
        val cleanNumber = phoneNumber.replace(" ", "").replace("-", "")
        
        // Simple matching logic
        val allNumbers = database.scamDao().checkNumber(cleanNumber)
        if (allNumbers != null) return@withContext allNumbers

        // Fallback: check matching substrings
        return@withContext null
    }

    private fun sendOverlayAlertBroadcast(number: String, tag: String, location: String) {
        val intent = Intent("com.hkaiSolveAcademy.vibeCoding.matszyu.SHOW_CALL_ALERT").apply {
            putExtra("EXTRA_NUMBER", number)
            putExtra("EXTRA_TAG", tag)
            putExtra("EXTRA_LOCATION", location)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceJob.cancel()
    }
}
