package com.guardcall.app.engine

import android.content.Context
import com.guardcall.app.data.AppDatabase
import com.guardcall.app.data.OfficialProcedure
import com.guardcall.app.data.ScamPattern
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking

class SkepticismEngine {

    private val engineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    data class AnalysisResult(
        val riskScore: Int,
        val advice: String,
        val contradictionFound: String?,
        val warningText: String?
    )

    fun analyzeDialogue(context: Context, text: String): AnalysisResult {
        // Query database synchronously for analysis since this is called on-demand by accessibility service thread
        val database = AppDatabase.getDatabase(context.applicationContext, engineScope)
        
        var calculatedRisk = 0
        val advices = mutableListOf<String>()
        var contradiction: String? = null
        var warningText: String? = null

        runBlocking(Dispatchers.IO) {
            val procedures = database.scamDao().getAllProceduresList()
            val patterns = database.scamDao().getAllPatternsList()

            // 1. Scan for Scam Patterns / Keywords (News & Police alerts)
            for (pattern in patterns) {
                val keywordsList = pattern.keywords.split(",")
                var matchCount = 0
                for (kw in keywordsList) {
                    val trimmed = kw.trim()
                    if (trimmed.isNotEmpty() && text.contains(trimmed, ignoreCase = true)) {
                        matchCount++
                    }
                }
                
                if (matchCount > 0) {
                    calculatedRisk += 25 * matchCount
                    advices.add(pattern.advice)
                }
            }

            // 2. Scan for Procedure Inconsistencies (What official organizations NEVER do)
            // e.g. Spammer says: "郵寄你張銀行卡" (mail your bank card)
            // Procedure says: Police will "never ask you to mail physical bank cards"
            for (proc in procedures) {
                // If text contains the forbidden actions or keywords associated with the institution
                val matchesInstitution = containsInstitutionRef(text, proc.institution)
                val matchesForbiddenAction = containsForbiddenActionKeywords(text, proc.forbiddenAction)

                if (matchesInstitution && matchesForbiddenAction) {
                    calculatedRisk += 60
                    contradiction = "${proc.institution} contradiction: claimed procedure involves ${proc.forbiddenAction}."
                    warningText = proc.warningText
                    advices.add("Inconsistency Detected: ${proc.warningText}")
                }
            }
        }

        // Cap risk score at 100%
        val finalRiskScore = calculatedRisk.coerceAtMost(100)
        val finalAdvice = if (advices.isNotEmpty()) advices.distinct().joinToString("\n") else "No immediate contradictions found. Keep listening."

        return AnalysisResult(
            riskScore = finalRiskScore,
            advice = finalAdvice,
            contradictionFound = contradiction,
            warningText = warningText
        )
    }

    private fun containsInstitutionRef(text: String, institutionName: String): Boolean {
        // Simple heuristic matching for institution names in HK/English
        val aliases = when {
            institutionName.contains("Police", ignoreCase = true) -> listOf("Police", "警察", "警局", "公安", "反詐")
            institutionName.contains("Alipay", ignoreCase = true) -> listOf("Alipay", "支付寶", "支寶")
            institutionName.contains("HSBC", ignoreCase = true) -> listOf("HSBC", "滙豐", "匯豐", "銀行")
            else -> listOf(institutionName)
        }
        return aliases.any { text.contains(it, ignoreCase = true) }
    }

    private fun containsForbiddenActionKeywords(text: String, forbiddenAction: String): Boolean {
        // Map common forbidden actions to Cantonese/English keywords
        val keywords = when {
            forbiddenAction.contains("mail", ignoreCase = true) || forbiddenAction.contains("card", ignoreCase = true) -> 
                listOf("郵寄", "寄過嚟", "寄黎", "銀行卡", "提款卡", "密碼", "mail", "post", "card")
            forbiddenAction.contains("transfer", ignoreCase = true) || forbiddenAction.contains("account", ignoreCase = true) -> 
                listOf("轉賬", "安全賬戶", "安全賬戶", "匯款", "過數", "轉帳", "transfer", "account", "fund")
            forbiddenAction.contains("security code", ignoreCase = true) || forbiddenAction.contains("verification", ignoreCase = true) -> 
                listOf("驗證碼", "安全編碼", "一次性密碼", "安全碼", "verification", "otp", "code")
            else -> forbiddenAction.split(" ")
        }
        return keywords.any { text.contains(it, ignoreCase = true) }
    }
}
