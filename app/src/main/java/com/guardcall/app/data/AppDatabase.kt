package com.guardcall.app.data

import android.content.Context
import androidx.room.*
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch

// ==========================================
// 1. ROOM ENTITIES
// ==========================================

@Entity(tableName = "scam_numbers")
data class ScamNumber(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    @ColumnInfo(name = "phone_number") val phoneNumber: String,
    @ColumnInfo(name = "entity_name") val entityName: String,
    @ColumnInfo(name = "date_added") val dateAdded: Long = System.currentTimeMillis()
)

@Entity(tableName = "official_procedures")
data class OfficialProcedure(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    @ColumnInfo(name = "institution") val institution: String,
    @ColumnInfo(name = "forbidden_action") val forbiddenAction: String,
    @ColumnInfo(name = "warning_text") val warningText: String
)

@Entity(tableName = "scam_patterns")
data class ScamPattern(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    @ColumnInfo(name = "source") val source: String,
    @ColumnInfo(name = "keywords") val keywords: String, // Comma-separated, e.g., "轉賬,驗證碼,安全賬戶"
    @ColumnInfo(name = "advice") val advice: String
)

@Entity(tableName = "call_incident_reports")
data class CallIncidentReport(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    @ColumnInfo(name = "timestamp") val timestamp: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "caller_number") val callerNumber: String,
    @ColumnInfo(name = "carrier_location") val carrierLocation: String,
    @ColumnInfo(name = "risk_score") val riskScore: Int,
    @ColumnInfo(name = "dialog_transcript") val dialogTranscript: String, // Diarized JSON or plain text
    @ColumnInfo(name = "link_intercepted") val linkIntercepted: String? = null,
    @ColumnInfo(name = "spammer_ip") val spammerIp: String? = null,
    @ColumnInfo(name = "spammer_location") val spammerLocation: String? = null,
    @ColumnInfo(name = "spammer_ua") val spammerUa: String? = null,
    @ColumnInfo(name = "payment_methods_targeted") val paymentMethodsTargeted: String? = null
)

// ==========================================
// 2. DATA ACCESS OBJECTS (DAOs)
// ==========================================

@Dao
interface ScamDao {
    // Blacklist Numbers
    @Query("SELECT * FROM scam_numbers ORDER BY date_added DESC")
    fun getAllScamNumbers(): Flow<List<ScamNumber>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertScamNumber(scamNumber: ScamNumber)

    @Delete
    suspend fun deleteScamNumber(scamNumber: ScamNumber)

    @Query("SELECT * FROM scam_numbers WHERE phone_number = :number LIMIT 1")
    suspend fun checkNumber(number: String): ScamNumber?

    // Official Procedures
    @Query("SELECT * FROM official_procedures")
    fun getAllProcedures(): Flow<List<OfficialProcedure>>

    @Query("SELECT * FROM official_procedures")
    suspend fun getAllProceduresList(): List<OfficialProcedure>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProcedure(procedure: OfficialProcedure)

    @Delete
    suspend fun deleteProcedure(procedure: OfficialProcedure)

    // Scam Patterns
    @Query("SELECT * FROM scam_patterns")
    fun getAllPatterns(): Flow<List<ScamPattern>>

    @Query("SELECT * FROM scam_patterns")
    suspend fun getAllPatternsList(): List<ScamPattern>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPattern(pattern: ScamPattern)

    @Delete
    suspend fun deletePattern(pattern: ScamPattern)

    // Incident Reports
    @Query("SELECT * FROM call_incident_reports ORDER BY timestamp DESC")
    fun getAllReports(): Flow<List<CallIncidentReport>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertReport(report: CallIncidentReport): Long

    @Update
    suspend fun updateReport(report: CallIncidentReport)

    @Delete
    suspend fun deleteReport(report: CallIncidentReport)
}

// ==========================================
// 3. ROOM DATABASE CLASS
// ==========================================

@Database(
    entities = [ScamNumber::class, OfficialProcedure::class, ScamPattern::class, CallIncidentReport::class],
    version = 2,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun scamDao(): ScamDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getDatabase(context: Context, scope: CoroutineScope): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "guardcall_database"
                )
                    .fallbackToDestructiveMigration()
                    .addCallback(AppDatabaseCallback(scope))
                    .build()
                INSTANCE = instance
                instance
            }
        }
    }

    private class AppDatabaseCallback(
        private val scope: CoroutineScope
    ) : RoomDatabase.Callback() {

        override fun onCreate(db: SupportSQLiteDatabase) {
            super.onCreate(db)
            INSTANCE?.let { database ->
                scope.launch(Dispatchers.IO) {
                    prepopulateDatabase(database.scamDao())
                }
            }
        }

        private suspend fun prepopulateDatabase(scamDao: ScamDao) {
            // Prepopulate Blacklist Numbers
            scamDao.insertScamNumber(ScamNumber(phoneNumber = "+852 6124 9901", entityName = "Reported Alipay Impersonator"))
            scamDao.insertScamNumber(ScamNumber(phoneNumber = "+852 9123 4567", entityName = "Suspected Phishing SMS Sender"))
            scamDao.insertScamNumber(ScamNumber(phoneNumber = "+852 5678 1234", entityName = "Fake HK Police Fraud Unit"))

            // Prepopulate HK Official Procedures
            scamDao.insertProcedure(
                OfficialProcedure(
                    institution = "Hong Kong Police (香港警務處)",
                    forbiddenAction = "mail bank card or transfer funds to secure accounts",
                    warningText = "🚨 警務處絕不會要求你郵寄銀行卡或轉賬。請拒絕要求並掛斷電話！"
                )
            )
            scamDao.insertProcedure(
                OfficialProcedure(
                    institution = "Alipay Customer Service (支付寶客服)",
                    forbiddenAction = "ask for verification code or transfer money to cancel services",
                    warningText = "🚨 支付寶客服絕不會索要驗證碼或要求私下轉賬。小心賬戶被盜用！"
                )
            )
            scamDao.insertProcedure(
                OfficialProcedure(
                    institution = "HSBC (滙豐銀行)",
                    forbiddenAction = "send links requesting your security code or full passwords",
                    warningText = "🚨 滙豐不會發送鏈接要求輸入密碼或安全編碼。切勿點擊鏈接！"
                )
            )

            // Prepopulate News & Police Scam Patterns
            scamDao.insertPattern(
                ScamPattern(
                    source = "Anti-Deception Coordination Centre (反詐騙協調中心)",
                    keywords = "安全賬戶,郵寄,資產審查,刑事案件,凍結資金",
                    advice = "提及「資金審查」或要求「郵寄銀行卡」為典型假冒公安詐騙手法。"
                )
            )
            scamDao.insertPattern(
                ScamPattern(
                    source = "HK Police Anti-Deception Alert",
                    keywords = "客服,開通服務,收費,取消訂閱,驗證碼",
                    advice = "以「取消扣費服務」為由索要驗證碼，是盜取支付寶/信用卡憑證的手法。"
                )
            )
            scamDao.insertPattern(
                ScamPattern(
                    source = "Consumer Council Warning (消費者委員會)",
                    keywords = "快遞,包裹受阻,海關,罰款,違禁品",
                    advice = "假冒快遞客服稱郵包有違禁品，要求配合公安調查並轉賬，是常見套路。"
                )
            )

            // Prepopulate a sample report for historical view
            scamDao.insertReport(
                CallIncidentReport(
                    callerNumber = "+852 6124 9901",
                    carrierLocation = "Kowloon City, HK",
                    riskScore = 92,
                    dialogTranscript = """
                        [{"speaker":"Spammer","text":"你好，我係支付寶客服。系統檢測到你嘅賬戶有異常扣費，請配合作資產審查。"},
                         {"speaker":"Receiver","text":"我冇用過你哋個扣費服務喎。"},
                         {"speaker":"Spammer","text":"你要即刻郵寄你張銀行卡去反詐中心，或者轉賬去我哋個安全賬戶先可以取消扣費。"}]
                    """.trimIndent(),
                    linkIntercepted = "https://scam-verify-alipay.com",
                    spammerIp = "42.200.180.12",
                    spammerLocation = "Sham Shui Po, Hong Kong",
                    spammerUa = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X)"
                )
            )
        }
    }
}
