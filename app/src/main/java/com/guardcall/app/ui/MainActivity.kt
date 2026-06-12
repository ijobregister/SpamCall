package com.guardcall.app.ui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.annotation.RequiresApi
import androidx.compose.animation.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.guardcall.app.data.AppDatabase
import com.guardcall.app.data.CallIncidentReport
import com.guardcall.app.data.OfficialProcedure
import com.guardcall.app.data.ScamNumber
import com.guardcall.app.data.ScamPattern
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.os.Environment

class MainActivity : ComponentActivity(), TextToSpeech.OnInitListener {

    private lateinit var appDatabase: AppDatabase
    private var textToSpeech: TextToSpeech? = null
    private val mainScope = CoroutineScope(Dispatchers.Main)

    // Live monitor states
    private val liveTranscript = mutableStateListOf<TranscriptItem>()
    private var liveRiskScore by mutableIntStateOf(0)
    private var liveAdvice by mutableStateOf("Ready. Waiting for call simulation...")
    private var activeWarningBanner by mutableStateOf<String?>(null)
    private var isCallActive by mutableStateOf(false)
    private var activeCallerNumber by mutableStateOf("")
    private var activeCallerName by mutableStateOf("")
    private var isSmsMode by mutableStateOf(false)
    private var smsBodyText by mutableStateOf("")
    private var smsLinkUrl by mutableStateOf("")
    private var isLinkBlocked by mutableStateOf(false)
    private var isLinkApprovedByThirdParty by mutableStateOf(false)
    private var showLinkReleaseRequest by mutableStateOf(false)
    private var currentIncidentReportId by mutableStateOf<Long?>(null)

    // Geotracking State
    private var spammerIpAddress by mutableStateOf("")
    private var spammerGeographicalLoc by mutableStateOf("")
    private var spammerIspCarrier by mutableStateOf("")
    private var spammerDeviceUserAgent by mutableStateOf("")

    data class TranscriptItem(val speaker: String, val text: String, val timestamp: Long = System.currentTimeMillis())

    private val eventReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.guardcall.app.SHOW_CALL_ALERT" -> {
                    activeCallerNumber = intent.getStringExtra("EXTRA_NUMBER") ?: ""
                    activeCallerName = intent.getStringExtra("EXTRA_TAG") ?: "Suspected Spam Call"
                    isCallActive = true
                    liveRiskScore = 60
                    liveAdvice = "Caller found in Scam Blacklist! Screen showing potential warning."
                }
                "com.guardcall.app.SMS_INTERCEPTED" -> {
                    val sender = intent.getStringExtra("EXTRA_SENDER") ?: ""
                    val body = intent.getStringExtra("EXTRA_BODY") ?: ""
                    val url = intent.getStringExtra("EXTRA_URL") ?: ""
                    val repId = intent.getLongExtra("EXTRA_REPORT_ID", -1L)

                    activeCallerNumber = sender
                    activeCallerName = "SMS Link Alert"
                    smsBodyText = body
                    smsLinkUrl = url
                    isSmsMode = true
                    isLinkBlocked = true
                    showLinkReleaseRequest = true
                    if (repId != -1L) currentIncidentReportId = repId
                }
                "com.guardcall.app.TRANSCRIPTION_BUBBLE" -> {
                    val speaker = intent.getStringExtra("EXTRA_SPEAKER") ?: "Spammer"
                    val text = intent.getStringExtra("EXTRA_TEXT") ?: ""
                    val isFinal = intent.getBooleanExtra("EXTRA_IS_FINAL", true)
                    
                    if (isFinal) {
                        liveTranscript.add(TranscriptItem(speaker, text))
                    }
                }
                "com.guardcall.app.SKEPTICISM_ALERT" -> {
                    liveRiskScore = intent.getIntExtra("EXTRA_RISK_SCORE", 0)
                    liveAdvice = intent.getStringExtra("EXTRA_ADVICE") ?: ""
                    val warning = intent.getStringExtra("EXTRA_WARNING_TEXT")
                    if (warning != null) {
                        activeWarningBanner = warning
                        speakWarningAlert(warning)
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appDatabase = AppDatabase.getDatabase(applicationContext, mainScope)
        textToSpeech = TextToSpeech(this, this)

        // Register local broadcasts from screening services
        val filter = IntentFilter().apply {
            addAction("com.guardcall.app.SHOW_CALL_ALERT")
            addAction("com.guardcall.app.SMS_INTERCEPTED")
            addAction("com.guardcall.app.TRANSCRIPTION_BUBBLE")
            addAction("com.guardcall.app.SKEPTICISM_ALERT")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(eventReceiver, filter, RECEIVER_EXPORTED)
        } else {
            registerReceiver(eventReceiver, filter)
        }

        setContent {
            ScamCallAppTheme {
                MainLayout()
            }
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = textToSpeech?.setLanguage(Locale("zh", "HK"))
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                // Fallback to Chinese if HK is not available
                textToSpeech?.language = Locale.CHINESE
            }
        }
    }

    private fun speakWarningAlert(message: String) {
        val voiceAlertEnabled = getSharedPreferences("GuardCallPrefs", MODE_PRIVATE)
            .getBoolean("voice_alert_enabled", true)
        if (voiceAlertEnabled) {
            textToSpeech?.speak(message, TextToSpeech.QUEUE_FLUSH, null, "WarningTTS")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(eventReceiver)
        textToSpeech?.shutdown()
    }

    @OptIn(ExperimentalMaterial3Api::class)
    @Composable
    fun MainLayout() {
        var selectedTab by remember { mutableStateOf(0) }
        val titles = listOf("實時監控", "知識庫", "事件報告", "設置")

        Scaffold(
            topBar = {
                TopAppBar(
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.Shield,
                                contentDescription = "ScamCall Logo",
                                tint = Color(0xFFE53935),
                                modifier = Modifier.size(32.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(
                                    "防騙衛士 (ScamCall)",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 18.sp,
                                    color = Color.White
                                )
                                Text(
                                    "實時詐騙攔截與懷疑引擎",
                                    fontSize = 11.sp,
                                    color = Color.LightGray
                                )
                            }
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF1E1E1E))
                )
            },
            bottomBar = {
                NavigationBar(containerColor = Color(0xFF1E1E1E)) {
                    titles.forEachIndexed { index, title ->
                        NavigationBarItem(
                            selected = selectedTab == index,
                            onClick = { selectedTab = index },
                            label = { Text(title, fontSize = 11.sp) },
                            icon = {
                                Icon(
                                    imageVector = when (index) {
                                        0 -> Icons.Default.Call
                                        1 -> Icons.Default.Edit
                                        2 -> Icons.Default.List
                                        else -> Icons.Default.Settings
                                    },
                                    contentDescription = title
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = Color.White,
                                selectedTextColor = Color.White,
                                indicatorColor = Color(0xFFD32F2F),
                                unselectedIconColor = Color.Gray,
                                unselectedTextColor = Color.Gray
                            )
                        )
                    }
                }
            }
        ) { paddingValues ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .background(Color(0xFF121212))
            ) {
                when (selectedTab) {
                    0 -> LiveMonitorScreen()
                    1 -> KnowledgeBaseScreen()
                    2 -> IncidentReportsScreen()
                    3 -> SettingsScreen()
                }
            }
        }
    }

    // ==========================================
    // TAB 1: LIVE MONITOR SCREEN (SIMULATOR)
    // ==========================================
    @Composable
    fun LiveMonitorScreen() {
        val scope = rememberCoroutineScope()
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Scenario Selection
            item {
                Text(
                    "模擬詐騙場景",
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = { triggerSimulatedCall("alipay_scam") },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32)),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("支付寶客服", fontSize = 12.sp)
                    }
                    Button(
                        onClick = { triggerSimulatedCall("police_scam") },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFC62828)),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("香港警察", fontSize = 12.sp)
                    }
                    Button(
                        onClick = { triggerSimulatedSMS("hsbc_phish") },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1565C0)),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("匯豐短訊", fontSize = 12.sp)
                    }
                }
            }

            // Warnings Box
            if (activeWarningBanner != null) {
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFD32F2F)),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Warning, contentDescription = "警告", tint = Color.White)
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(activeWarningBanner!!, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        }
                    }
                }
            }

            // Real-Time Transcript Panel
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("對話實時轉錄", fontWeight = FontWeight.Bold, color = Color.White)
                            if (isCallActive) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(8.dp)
                                            .clip(CircleShape)
                                            .background(Color.Red)
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("實時分析中", color = Color.Red, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                        
                        Spacer(modifier = Modifier.height(12.dp))
                        
                        if (liveTranscript.isEmpty()) {
                            Text(
                                "暫無通話記錄。請選擇上方場景開始模擬通話攔截檢測。",
                                color = Color.Gray,
                                fontSize = 13.sp,
                                modifier = Modifier.padding(vertical = 32.dp),
                                textAlign = TextAlign.Center
                            )
                        } else {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                liveTranscript.forEach { item ->
                                    val isSpammer = item.speaker == "Spammer" || item.speaker == "騙徒"
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = if (isSpammer) Arrangement.Start else Arrangement.End
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .clip(RoundedCornerShape(8.dp))
                                                .background(if (isSpammer) Color(0xFF333333) else Color(0xFFC62828))
                                                .padding(10.dp)
                                        ) {
                                            Text(
                                                text = "${if (item.speaker == "Spammer") "騙徒" else if (item.speaker == "Receiver") "受話人" else item.speaker}: ${item.text}",
                                                color = Color.White,
                                                fontSize = 13.sp
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Risk & Skepticism Meter
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("AI 懷疑指數", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 14.sp)
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                "${liveRiskScore}%",
                                fontSize = 32.sp,
                                fontWeight = FontWeight.Black,
                                color = if (liveRiskScore > 75) Color.Red else if (liveRiskScore > 40) Color.Yellow else Color.Green
                            )
                            Spacer(modifier = Modifier.width(16.dp))
                            Text(
                                text = if (liveRiskScore > 75) "偵測到嚴重詐騙風險" else if (liveRiskScore > 40) "對話內容可疑" else "通話安全",
                                fontWeight = FontWeight.Bold,
                                color = Color.LightGray,
                                fontSize = 12.sp
                            )
                        }
                        Spacer(modifier = Modifier.height(6.dp))
                        LinearProgressIndicator(
                            progress = liveRiskScore / 100f,
                            color = if (liveRiskScore > 75) Color.Red else if (liveRiskScore > 40) Color.Yellow else Color.Green,
                            trackColor = Color(0xFF333333),
                            modifier = Modifier.fillMaxWidth()
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("分析邏輯：", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 12.sp)
                        Text(liveAdvice, color = Color.LightGray, fontSize = 12.sp)
                    }
                }
            }

            // Geolocation Radar Sim
            if (isCallActive && spammerIpAddress.isNotEmpty()) {
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("誘餌 IP 追蹤器已啟動", fontWeight = FontWeight.Bold, color = Color.White)
                            Spacer(modifier = Modifier.height(8.dp))
                            Row {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text("IP: $spammerIpAddress", color = Color.Red, fontFamily = FontFamily.Monospace, fontSize = 13.sp)
                                    Text("預計位置: $spammerGeographicalLoc", color = Color.White, fontSize = 13.sp)
                                    Text("營運商: $spammerIspCarrier", color = Color.Gray, fontSize = 13.sp)
                                }
                                Box(
                                    modifier = Modifier
                                        .size(100.dp)
                                        .background(Color.Black, shape = CircleShape)
                                ) {
                                    Canvas(modifier = Modifier.fillMaxSize()) {
                                        drawCircle(
                                            color = Color.Green,
                                            radius = size.minDimension / 2,
                                            style = Stroke(width = 2f)
                                        )
                                        drawCircle(
                                            color = Color.Green,
                                            radius = size.minDimension / 4,
                                            style = Stroke(width = 1f)
                                        )
                                        // Draw simulated ping
                                        drawCircle(
                                            color = Color.Red,
                                            radius = 8f,
                                            center = Offset(size.width * 0.7f, size.height * 0.3f)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Link Blocking / Request Release Box
            if (isSmsMode && showLinkReleaseRequest) {
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF221111)),
                        modifier = Modifier.fillMaxWidth(),
                        border = CardDefaults.outlinedCardBorder().copy(brush = Brush.linearGradient(listOf(Color.Red, Color.DarkGray)))
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("偵測到釣魚連結！", fontWeight = FontWeight.Bold, color = Color.Red)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("網域: $smsLinkUrl", color = Color.LightGray, fontSize = 13.sp)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                "已鎖定。正等待受信任聯絡人 (Gabriel) 或遠程點擊批准。",
                                color = Color.Gray,
                                fontSize = 12.sp
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(
                                    onClick = { 
                                        respondToRelease(approved = false)
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color.DarkGray),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text("拒絕", fontSize = 12.sp)
                                }
                                Button(
                                    onClick = { 
                                        respondToRelease(approved = true)
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32)),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text("批准並釋放", fontSize = 11.sp)
                                }
                            }
                        }
                    }
                }
            }

            // Control Buttons
            if (isCallActive || isSmsMode) {
                item {
                    Button(
                        onClick = { hangupActiveSession() },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD32F2F)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("結束模擬 / 掛斷", fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }

    private fun triggerSimulatedCall(scenario: String) {
        hangupActiveSession()
        isCallActive = true
        if (scenario == "alipay_scam") {
            activeCallerNumber = "+852 6124 9901"
            activeCallerName = "Unknown Mobile Number"
            mainScope.launch {
                liveTranscript.add(TranscriptItem("Spammer", "你好，我係支付寶客服。系統檢測到你個賬戶有異常轉賬，需要立即處理。"))
                liveRiskScore = 35
                liveAdvice = "Matching introductory greeting phrases..."
                
                kotlinx.coroutines.delay(2000)
                liveTranscript.add(TranscriptItem("Receiver", "我今日冇做過轉賬喎，咩事？"))
                
                kotlinx.coroutines.delay(2000)
                liveTranscript.add(TranscriptItem("Spammer", "為咗確保資金安全，你需要向我哋個安全賬戶做資產審查轉賬，或者提供你張卡嘅驗證碼。"))
                
                // Triggers engine matching
                val analysis = appDatabase.scamDao().getAllProceduresList().firstOrNull { it.institution.contains("Alipay") }
                if (analysis != null) {
                    liveRiskScore = 95
                    activeWarningBanner = analysis.warningText
                    liveAdvice = "CRITICAL MATCH: Alipay official procedures state they will NEVER ask for verification codes or transfers. This is a scam!"
                    speakWarningAlert(analysis.warningText)
                }

                // Spammer asks to click link, so we trigger honeypot consent link automatically
                spammerIpAddress = "42.200.180.12"
                spammerGeographicalLoc = "Sham Shui Po, Hong Kong"
                spammerIspCarrier = "China Mobile Hong Kong"
                spammerDeviceUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X)"
            }
        } else if (scenario == "police_scam") {
            activeCallerNumber = "+852 5678 1234"
            activeCallerName = "Fake HK Police Fraud Unit"
            mainScope.launch {
                liveTranscript.add(TranscriptItem("Spammer", "你好，呢度係香港警務處反詐騙小組。你涉嫌參與一宗跨境刑事洗錢案。"))
                liveRiskScore = 40
                liveAdvice = "Matching legal/police keywords..."

                kotlinx.coroutines.delay(2000)
                liveTranscript.add(TranscriptItem("Receiver", "啊？我點會參與洗錢案？"))

                kotlinx.coroutines.delay(2000)
                liveTranscript.add(TranscriptItem("Spammer", "依家法庭要求你將你嘅實體銀行卡，用快遞郵寄黎我哋反詐中心進行清查。"))

                val analysis = appDatabase.scamDao().getAllProceduresList().firstOrNull { it.institution.contains("Police") }
                if (analysis != null) {
                    liveRiskScore = 100
                    activeWarningBanner = analysis.warningText
                    liveAdvice = "CRITICAL MATCH: Police never ask you to mail physical bank cards! Hand card over or mail requests are 100% scam."
                    speakWarningAlert(analysis.warningText)
                }

                spammerIpAddress = "202.40.137.9"
                spammerGeographicalLoc = "Mong Kok, Hong Kong"
                spammerIspCarrier = "HKT Netvigator"
                spammerDeviceUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0"
            }
        }
    }

    private fun triggerSimulatedSMS(scenario: String) {
        hangupActiveSession()
        isSmsMode = true
        if (scenario == "hsbc_phish") {
            activeCallerNumber = "+852 9123 4567"
            smsBodyText = "Dear customer, abnormal transactions were detected. Please click the link to verify: "
            smsLinkUrl = "https://scam-verify-alipay.com"
            isLinkBlocked = true
            showLinkReleaseRequest = true
            liveRiskScore = 80
            liveAdvice = "SMS contains unverified link. Automatically intercepting domain click routing."
        }
    }

    private fun respondToRelease(approved: Boolean) {
        showLinkReleaseRequest = false
        if (approved) {
            isLinkApprovedByThirdParty = true
            isLinkBlocked = false
            Toast.makeText(this, "Link Released by Trusted Third Party!", Toast.LENGTH_LONG).show()
        } else {
            isLinkApprovedByThirdParty = false
            Toast.makeText(this, "Link Blocked Permanently.", Toast.LENGTH_SHORT).show()
        }
    }

    private fun hangupActiveSession() {
        if (isCallActive || isSmsMode) {
            // Write incident report to Database
            mainScope.launch(Dispatchers.IO) {
                val transcriptText = liveTranscript.map { "${it.speaker}: ${it.text}" }.joinToString("\n")
                val engine = com.guardcall.app.engine.SkepticismEngine()
                val detectedPaymentsList = engine.detectTargetedPayments(applicationContext, if (isSmsMode) smsBodyText else transcriptText)
                val paymentsString = if (detectedPaymentsList.isNotEmpty()) detectedPaymentsList.joinToString(", ") else null

                val transcriptJson = liveTranscript.map { "{\"speaker\":\"${it.speaker}\",\"text\":\"${it.text}\"}" }.joinToString(",")
                appDatabase.scamDao().insertReport(
                    CallIncidentReport(
                        callerNumber = activeCallerNumber,
                        carrierLocation = if (isSmsMode) "SMS Carrier" else "Kowloon City, HK",
                        riskScore = liveRiskScore,
                        dialogTranscript = if (isSmsMode) smsBodyText else "[$transcriptJson]",
                        linkIntercepted = if (isSmsMode) smsLinkUrl else null,
                        spammerIp = if (spammerIpAddress.isNotEmpty()) spammerIpAddress else null,
                        spammerLocation = if (spammerGeographicalLoc.isNotEmpty()) spammerGeographicalLoc else null,
                        spammerUa = if (spammerDeviceUserAgent.isNotEmpty()) spammerDeviceUserAgent else null,
                        paymentMethodsTargeted = paymentsString
                    )
                )
            }
        }

        isCallActive = false
        isSmsMode = false
        liveTranscript.clear()
        liveRiskScore = 0
        liveAdvice = "Ready. Waiting for call simulation..."
        activeWarningBanner = null
        spammerIpAddress = ""
        spammerGeographicalLoc = ""
        spammerIspCarrier = ""
        spammerDeviceUserAgent = ""
        showLinkReleaseRequest = false
        currentIncidentReportId = null
    }

    // ==========================================
    // TAB 2: KNOWLEDGE BASE SCREEN (CRUD EDITOR)
    // ==========================================
    @Composable
    fun KnowledgeBaseScreen() {
        val scope = rememberCoroutineScope()
        var proceduresList by remember { mutableStateOf(emptyList<OfficialProcedure>()) }
        var patternsList by remember { mutableStateOf(emptyList<ScamPattern>()) }
        var blacklistList by remember { mutableStateOf(emptyList<ScamNumber>()) }

        // Form Inputs
        var newInst by remember { mutableStateOf("") }
        var newRule by remember { mutableStateOf("") }
        var newWarn by remember { mutableStateOf("") }

        var newSource by remember { mutableStateOf("") }
        var newKeywords by remember { mutableStateOf("") }
        var newAdvice by remember { mutableStateOf("") }

        var newBlackNum by remember { mutableStateOf("") }
        var newBlackTag by remember { mutableStateOf("") }

        var editingProcedure by remember { mutableStateOf<OfficialProcedure?>(null) }
        var editingPattern by remember { mutableStateOf<ScamPattern?>(null) }
        var editingBlacklist by remember { mutableStateOf<ScamNumber?>(null) }

        // Query databases
        LaunchedEffect(Unit) {
            scope.launch {
                appDatabase.scamDao().getAllProcedures().collect { proceduresList = it }
            }
            scope.launch {
                appDatabase.scamDao().getAllPatterns().collect { patternsList = it }
            }
            scope.launch {
                appDatabase.scamDao().getAllScamNumbers().collect { blacklistList = it }
            }
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Official Procedures CRUD
            item {
                Text("官方流程庫 (用戶可編輯)", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                proceduresList.forEach { proc ->
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                    ) {
                        Row(modifier = Modifier.padding(12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(proc.institution, fontWeight = FontWeight.Bold, color = Color.White)
                                Text("禁止事項: ${proc.forbiddenAction}", color = Color.Gray, fontSize = 12.sp)
                                Text("警告內容: ${proc.warningText}", color = Color.Red, fontSize = 11.sp)
                            }
                            Row {
                                IconButton(onClick = {
                                    editingProcedure = proc
                                    newInst = proc.institution
                                    newRule = proc.forbiddenAction
                                    newWarn = proc.warningText
                                }) {
                                    Icon(Icons.Default.Edit, contentDescription = "編輯", tint = Color.Gray)
                                }
                                IconButton(onClick = {
                                    scope.launch(Dispatchers.IO) { appDatabase.scamDao().deleteProcedure(proc) }
                                }) {
                                    Icon(Icons.Default.Delete, contentDescription = "刪除", tint = Color.Gray)
                                }
                            }
                        }
                    }
                }

                // Add Form
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF151515)), modifier = Modifier.padding(top = 8.dp)) {
                    Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = if (editingProcedure != null) "編輯官方規則" else "新增官方規則",
                            fontWeight = FontWeight.Bold,
                            color = Color.LightGray,
                            fontSize = 13.sp
                        )
                        OutlinedTextField(
                            value = newInst, onValueChange = { newInst = it },
                            label = { Text("機構名稱", color = Color.Gray) },
                            colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = newRule, onValueChange = { newRule = it },
                            label = { Text("禁止程序規則", color = Color.Gray) },
                            colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = newWarn, onValueChange = { newWarn = it },
                            label = { Text("AI 彈出警告文字", color = Color.Gray) },
                            colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.align(Alignment.End)
                        ) {
                            if (editingProcedure != null) {
                                Button(
                                    onClick = {
                                        editingProcedure = null
                                        newInst = ""; newRule = ""; newWarn = ""
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color.DarkGray)
                                ) {
                                    Text("取消")
                                }
                            }
                            Button(
                                onClick = {
                                    if (newInst.isNotEmpty() && newRule.isNotEmpty()) {
                                        scope.launch(Dispatchers.IO) {
                                            val procToSave = if (editingProcedure != null) {
                                                OfficialProcedure(id = editingProcedure!!.id, institution = newInst, forbiddenAction = newRule, warningText = newWarn)
                                            } else {
                                                OfficialProcedure(institution = newInst, forbiddenAction = newRule, warningText = newWarn)
                                            }
                                            appDatabase.scamDao().insertProcedure(procToSave)
                                            newInst = ""; newRule = ""; newWarn = ""
                                            editingProcedure = null
                                        }
                                    }
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFC62828))
                            ) {
                                Text(if (editingProcedure != null) "更新規則" else "儲存規則")
                            }
                        }
                    }
                }
            }

            // News Scam Patterns CRUD
            item {
                Text("新聞詐騙詞組模式", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                patternsList.forEach { pattern ->
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                    ) {
                        Row(modifier = Modifier.padding(12.dp)) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(pattern.source, fontWeight = FontWeight.Bold, color = Color.White)
                                Text("關鍵字: ${pattern.keywords}", color = Color.Yellow, fontSize = 12.sp)
                                Text("建議: ${pattern.advice}", color = Color.LightGray, fontSize = 12.sp)
                            }
                            Row {
                                IconButton(onClick = {
                                    editingPattern = pattern
                                    newSource = pattern.source
                                    newKeywords = pattern.keywords
                                    newAdvice = pattern.advice
                                }) {
                                    Icon(Icons.Default.Edit, contentDescription = "編輯", tint = Color.Gray)
                                }
                                IconButton(onClick = {
                                    scope.launch(Dispatchers.IO) { appDatabase.scamDao().deletePattern(pattern) }
                                }) {
                                    Icon(Icons.Default.Delete, contentDescription = "刪除", tint = Color.Gray)
                                }
                            }
                        }
                    }
                }

                // Add Form
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF151515)), modifier = Modifier.padding(top = 8.dp)) {
                    Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = if (editingPattern != null) "編輯新聞/警方警告" else "新增新聞/警方警告",
                            fontWeight = FontWeight.Bold,
                            color = Color.LightGray,
                            fontSize = 13.sp
                        )
                        OutlinedTextField(
                            value = newSource, onValueChange = { newSource = it },
                            label = { Text("新聞/警方警告來源", color = Color.Gray) },
                            colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = newKeywords, onValueChange = { newKeywords = it },
                            label = { Text("關鍵字 (逗號分隔)", color = Color.Gray) },
                            colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = newAdvice, onValueChange = { newAdvice = it },
                            label = { Text("建議訊息", color = Color.Gray) },
                            colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.align(Alignment.End)
                        ) {
                            if (editingPattern != null) {
                                Button(
                                    onClick = {
                                        editingPattern = null
                                        newSource = ""; newKeywords = ""; newAdvice = ""
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color.DarkGray)
                                ) {
                                    Text("取消")
                                }
                            }
                            Button(
                                onClick = {
                                    if (newSource.isNotEmpty() && newKeywords.isNotEmpty()) {
                                        scope.launch(Dispatchers.IO) {
                                            val patternToSave = if (editingPattern != null) {
                                                ScamPattern(id = editingPattern!!.id, source = newSource, keywords = newKeywords, advice = newAdvice)
                                            } else {
                                                ScamPattern(source = newSource, keywords = newKeywords, advice = newAdvice)
                                            }
                                            appDatabase.scamDao().insertPattern(patternToSave)
                                            newSource = ""; newKeywords = ""; newAdvice = ""
                                            editingPattern = null
                                        }
                                    }
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFC62828))
                            ) {
                                Text(if (editingPattern != null) "更新模式" else "儲存模式")
                            }
                        }
                    }
                }
            }

            // Blacklist Numbers CRUD
            item {
                Text("黑名單號碼", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                blacklistList.forEach { item ->
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp)
                    ) {
                        Row(modifier = Modifier.padding(12.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Column {
                                Text(item.phoneNumber, fontWeight = FontWeight.Bold, color = Color.White)
                                Text(item.entityName, color = Color.Gray, fontSize = 12.sp)
                            }
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                IconButton(onClick = {
                                    editingBlacklist = item
                                    newBlackNum = item.phoneNumber
                                    newBlackTag = item.entityName
                                }) {
                                    Icon(Icons.Default.Edit, contentDescription = "編輯", tint = Color.Gray)
                                }
                                IconButton(onClick = {
                                    scope.launch(Dispatchers.IO) { appDatabase.scamDao().deleteScamNumber(item) }
                                }) {
                                    Icon(Icons.Default.Delete, contentDescription = "刪除", tint = Color.Gray)
                                }
                            }
                        }
                    }
                }

                // Add Form
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF151515)), modifier = Modifier.padding(top = 8.dp)) {
                    Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = if (editingBlacklist != null) "編輯電話黑名單" else "新增電話黑名單",
                            fontWeight = FontWeight.Bold,
                            color = Color.LightGray,
                            fontSize = 13.sp
                        )
                        OutlinedTextField(
                            value = newBlackNum, onValueChange = { newBlackNum = it },
                            label = { Text("電話號碼", color = Color.Gray) },
                            colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = newBlackTag, onValueChange = { newBlackTag = it },
                            label = { Text("舉報實體標籤", color = Color.Gray) },
                            colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.align(Alignment.End)
                        ) {
                            if (editingBlacklist != null) {
                                Button(
                                    onClick = {
                                        editingBlacklist = null
                                        newBlackNum = ""; newBlackTag = ""
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color.DarkGray)
                                ) {
                                    Text("取消")
                                }
                            }
                            Button(
                                onClick = {
                                    if (newBlackNum.isNotEmpty()) {
                                        scope.launch(Dispatchers.IO) {
                                            val blacklistToSave = if (editingBlacklist != null) {
                                                ScamNumber(id = editingBlacklist!!.id, phoneNumber = newBlackNum, entityName = newBlackTag)
                                            } else {
                                                ScamNumber(phoneNumber = newBlackNum, entityName = newBlackTag)
                                            }
                                            appDatabase.scamDao().insertScamNumber(blacklistToSave)
                                            newBlackNum = ""; newBlackTag = ""
                                            editingBlacklist = null
                                        }
                                    }
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFC62828))
                            ) {
                                Text(if (editingBlacklist != null) "更新黑名單" else "加入黑名單")
                            }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // TAB 3: INCIDENT REPORTS SCREEN
    // ==========================================
    @Composable
    fun IncidentReportsScreen() {
        val scope = rememberCoroutineScope()
        val context = LocalContext.current
        var reportsList by remember { mutableStateOf(emptyList<CallIncidentReport>()) }
        var selectedReport by remember { mutableStateOf<CallIncidentReport?>(null) }

        LaunchedEffect(Unit) {
            scope.launch {
                appDatabase.scamDao().getAllReports().collect { reportsList = it }
            }
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Text("通話後事件報告", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(4.dp))
                Text("移交文件已準備就緒，包含警方座標及轉錄詳情。", color = Color.Gray, fontSize = 12.sp)
            }

            if (selectedReport == null) {
                // List View
                items(reportsList) { report ->
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selectedReport = report }
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                                Text(report.callerNumber, fontWeight = FontWeight.Bold, color = Color.White)
                                Text(
                                    text = "${report.riskScore}% 風險",
                                    color = if (report.riskScore > 75) Color.Red else Color.Green,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("日期: ${SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(report.timestamp))}", color = Color.Gray, fontSize = 12.sp)
                            Text("偵測位置: ${report.carrierLocation}", color = Color.LightGray, fontSize = 12.sp)
                        }
                    }
                }
            } else {
                // Detail Report View
                val report = selectedReport!!
                item {
                    Button(
                        onClick = { selectedReport = null },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.DarkGray)
                    ) {
                        Text("← 返回報告列表", fontSize = 12.sp)
                    }
                }
                
                item {
                    Card(
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("事件詳情 - ${report.callerNumber}", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 18.sp)
                            Text("風險評級: ${report.riskScore}%", color = Color.Red, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            Spacer(modifier = Modifier.height(12.dp))
                            Text("營運商位置: ${report.carrierLocation}", color = Color.White, fontSize = 13.sp)
                            
                            if (report.paymentMethodsTargeted != null) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text("目標支付管道：", fontWeight = FontWeight.Bold, color = Color.Yellow, fontSize = 13.sp)
                                Text(report.paymentMethodsTargeted, color = Color.White, fontSize = 13.sp)
                            }
                            
                            if (report.spammerIp != null) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text("誘餌 IP 抓取器記錄的地理位置詳情：", fontWeight = FontWeight.Bold, color = Color.Yellow, fontSize = 13.sp)
                                Text("騙徒 IP: ${report.spammerIp}", color = Color.Red, fontSize = 13.sp, fontFamily = FontFamily.Monospace)
                                Text("計算位置: ${report.spammerLocation}", color = Color.White, fontSize = 13.sp)
                                Text("瀏覽器代理: ${report.spammerUa}", color = Color.Gray, fontSize = 11.sp)
                            }
                            
                            Spacer(modifier = Modifier.height(12.dp))
                            Text("分角色對話轉錄：", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 13.sp)
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(Color.Black)
                                    .padding(8.dp)
                            ) {
                                Text(
                                    text = report.dialogTranscript.replace("[", "").replace("]", "").replace("{\"", "").replace("\"}", ""),
                                    color = Color.Green,
                                    fontSize = 12.sp,
                                    fontFamily = FontFamily.Monospace
                                )
                            }

                            Spacer(modifier = Modifier.height(16.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(
                                    onClick = { 
                                        exportReportToHandoverTxt(context, report)
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1565C0)),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text("TXT", fontSize = 10.sp)
                                }
                                Button(
                                    onClick = { 
                                        exportReportToPdf(context, report)
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32)),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text("PDF", fontSize = 10.sp)
                                }
                                Button(
                                    onClick = { 
                                        triggerPoliceHandoverAlert(context, report)
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFC62828)),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Text("移交警方", fontSize = 10.sp)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private fun exportReportToHandoverTxt(context: Context, report: CallIncidentReport) {
        val fileContent = """
            ==================================================
            SCAMCALL AI - SPAM CALL INCIDENT REPORT
            ==================================================
            Date Generated: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())}
            Incident Timestamp: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(report.timestamp))}
            Target Region: Hong Kong (Cantonese Core Engine)
            
            CALL METADATA:
            - Caller Number: ${report.callerNumber}
            - Carrier Geocode Location: ${report.carrierLocation}
            - Scam Risk Rating: ${report.riskScore}% Risk
            
            HONEYPOT IP-TRACKER CONSENT LOGS:
            - Spammer IP Tracked: ${report.spammerIp ?: "Not Grabbed"}
            - Estimated Location: ${report.spammerLocation ?: "N/A"}
            - User-Agent details: ${report.spammerUa ?: "N/A"}
            
            CONVERSATION DIARIZATION TRANSCRIPT:
            ${report.dialogTranscript}
            
            ==================================================
            Handover package generated successfully. Copy to police files.
        """.trimIndent()

        try {
            val fileName = "Police_Handover_${report.callerNumber}_${report.timestamp}.txt"
            val file = File(context.getExternalFilesDir(null), fileName)
            FileOutputStream(file).use {
                it.write(fileContent.toByteArray())
            }
            Toast.makeText(context, "Report exported to: ${file.absolutePath}", Toast.LENGTH_LONG).show()
        } catch (e: Exception) {
            Toast.makeText(context, "Failed to export text file: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun exportReportToPdf(context: Context, report: CallIncidentReport) {
        val pdfDocument = PdfDocument()
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas

        val paint = Paint()
        paint.textSize = 12f
        paint.color = android.graphics.Color.BLACK

        var y = 40f

        // Header
        paint.textSize = 18f
        paint.isFakeBoldText = true
        canvas.drawText("SCAMCALL - 防騙衛士 REPORT", 50f, y, paint)
        y += 25f

        paint.textSize = 10f
        paint.isFakeBoldText = false
        paint.color = android.graphics.Color.GRAY
        canvas.drawText("Generated: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())}", 50f, y, paint)
        y += 20f

        // Line
        paint.color = android.graphics.Color.BLACK
        paint.strokeWidth = 2f
        canvas.drawLine(50f, y, 545f, y, paint)
        y += 25f

        // Metadata
        paint.textSize = 12f
        paint.isFakeBoldText = true
        canvas.drawText("Incident Metadata", 50f, y, paint)
        y += 18f

        paint.isFakeBoldText = false
        canvas.drawText("Caller Number: ${report.callerNumber}", 50f, y, paint)
        y += 15f
        canvas.drawText("Risk Rating: ${report.riskScore}% Risk", 50f, y, paint)
        y += 15f
        canvas.drawText("Carrier Location: ${report.carrierLocation}", 50f, y, paint)
        y += 15f
        canvas.drawText("Date/Time: ${SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date(report.timestamp))}", 50f, y, paint)
        y += 15f
        canvas.drawText("Targeted Payment Channels: ${report.paymentMethodsTargeted ?: "None Detected"}", 50f, y, paint)
        y += 15f
        if (report.spammerIp != null) {
            canvas.drawText("Spammer IP: ${report.spammerIp} (${report.spammerLocation})", 50f, y, paint)
            y += 15f
        }

        y += 15f
        canvas.drawLine(50f, y, 545f, y, paint)
        y += 25f

        // Dialogue Title
        paint.isFakeBoldText = true
        canvas.drawText("Diarized Call Transcript", 50f, y, paint)
        y += 20f

        paint.isFakeBoldText = false
        // Draw transcript line-by-line with text wrapping
        val lines = report.dialogTranscript.replace("[", "").replace("]", "").split("},")
        for (line in lines) {
            if (line.trim().isEmpty()) continue
            // Parse speaker and text
            val speaker = if (line.contains("Spammer") || line.contains("騙徒")) "騙徒" else "受話人"
            val rawText = line.substringAfter("\"text\":\"").substringBefore("\"")

            // Draw speaker label
            paint.isFakeBoldText = true
            val speakerLabel = "[$speaker]: "
            canvas.drawText(speakerLabel, 50f, y, paint)

            val labelWidth = paint.measureText(speakerLabel)
            paint.isFakeBoldText = false

            // Wrap text to fit canvas width (limit to 400f width)
            val charLimit = 25
            var start = 0
            while (start < rawText.length) {
                val end = (start + charLimit).coerceAtMost(rawText.length)
                val segment = rawText.substring(start, end)
                canvas.drawText(segment, 50f + labelWidth, y, paint)
                y += 15f
                start = end
                if (y > 800f) break
            }
            y += 5f

            if (y > 800f) {
                break
            }
        }

        pdfDocument.finishPage(page)

        try {
            val fileName = "Police_Handover_${report.callerNumber}_${report.timestamp}.pdf"
            val file = File(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), fileName)
            pdfDocument.writeTo(FileOutputStream(file))
            Toast.makeText(context, "PDF Report exported to: ${file.absolutePath}", Toast.LENGTH_LONG).show()
        } catch (e: Exception) {
            Toast.makeText(context, "Failed to export PDF: ${e.message}", Toast.LENGTH_SHORT).show()
        } finally {
            pdfDocument.close()
        }
    }

    private fun triggerPoliceHandoverAlert(context: Context, report: CallIncidentReport) {
        Toast.makeText(context, "Handover Package for ${report.callerNumber} sent to HKPF CyberSecurity Bureau!", Toast.LENGTH_LONG).show()
    }

    // ==========================================
    // TAB 4: SETTINGS SCREEN
    // ==========================================
    @Composable
    fun SettingsScreen() {
        val context = LocalContext.current
        val sharedPrefs = remember { context.getSharedPreferences("GuardCallPrefs", MODE_PRIVATE) }
        var isVoiceAlertsEnabled by remember { mutableStateOf(sharedPrefs.getBoolean("voice_alert_enabled", true)) }
        var contactName by remember { mutableStateOf(sharedPrefs.getString("auth_contact_name", "Gabriel (孫子)") ?: "") }
        var contactPhone by remember { mutableStateOf(sharedPrefs.getString("auth_contact_phone", "+852 9876 5432") ?: "") }
        var selectedRegion by remember { mutableStateOf(sharedPrefs.getString("region_policy", "HK") ?: "HK") }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Text("系統設置", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 18.sp)

            // Voice Alerts Accessibility
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("語音警報 (無障礙功能)", fontWeight = FontWeight.Bold, color = Color.White)
                    Text("在通話過程中為視障用戶朗讀警告文字。", color = Color.Gray, fontSize = 12.sp)
                }
                Switch(
                    checked = isVoiceAlertsEnabled,
                    onCheckedChange = {
                        isVoiceAlertsEnabled = it
                        sharedPrefs.edit().putBoolean("voice_alert_enabled", it).apply()
                    },
                    colors = SwitchDefaults.colors(checkedThumbColor = Color.Red, checkedTrackColor = Color(0xFFC62828))
                )
            }

            HorizontalDivider(color = Color.DarkGray)

            // Protected Payment Channels Selection
            val defaultPayments = setOf("Bank Apps", "Internet Banking", "Visa", "FPS", "Octopus", "7-Eleven", "Circle K", "Alipay", "WeChat Pay")
            var protectedPayments by remember {
                mutableStateOf(sharedPrefs.getStringSet("protected_payments", defaultPayments) ?: defaultPayments)
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("受防護支付管道 (Payment Protection)", fontWeight = FontWeight.Bold, color = Color.White)
                Text("選擇需要防護與追蹤的交易方式（偵測到對話提及時將自動在報告與PDF中記錄）。", color = Color.Gray, fontSize = 12.sp)
                
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    val p1 = "Bank Apps"
                    val isS1 = protectedPayments.contains(p1)
                    Button(
                        onClick = {
                            val newSet = protectedPayments.toMutableSet()
                            if (isS1) newSet.remove(p1) else newSet.add(p1)
                            protectedPayments = newSet
                            sharedPrefs.edit().putStringSet("protected_payments", newSet).apply()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isS1) Color(0xFFC62828) else Color.DarkGray),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("銀行App", fontSize = 10.sp)
                    }

                    val p2 = "Internet Banking"
                    val isS2 = protectedPayments.contains(p2)
                    Button(
                        onClick = {
                            val newSet = protectedPayments.toMutableSet()
                            if (isS2) newSet.remove(p2) else newSet.add(p2)
                            protectedPayments = newSet
                            sharedPrefs.edit().putStringSet("protected_payments", newSet).apply()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isS2) Color(0xFFC62828) else Color.DarkGray),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("網上銀行", fontSize = 10.sp)
                    }

                    val p3 = "Visa"
                    val isS3 = protectedPayments.contains(p3)
                    Button(
                        onClick = {
                            val newSet = protectedPayments.toMutableSet()
                            if (isS3) newSet.remove(p3) else newSet.add(p3)
                            protectedPayments = newSet
                            sharedPrefs.edit().putStringSet("protected_payments", newSet).apply()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isS3) Color(0xFFC62828) else Color.DarkGray),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Visa卡", fontSize = 10.sp)
                    }
                }

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    val p4 = "FPS"
                    val isS4 = protectedPayments.contains(p4)
                    Button(
                        onClick = {
                            val newSet = protectedPayments.toMutableSet()
                            if (isS4) newSet.remove(p4) else newSet.add(p4)
                            protectedPayments = newSet
                            sharedPrefs.edit().putStringSet("protected_payments", newSet).apply()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isS4) Color(0xFFC62828) else Color.DarkGray),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("轉數快", fontSize = 10.sp)
                    }

                    val p5 = "Octopus"
                    val isS5 = protectedPayments.contains(p5)
                    Button(
                        onClick = {
                            val newSet = protectedPayments.toMutableSet()
                            if (isS5) newSet.remove(p5) else newSet.add(p5)
                            protectedPayments = newSet
                            sharedPrefs.edit().putStringSet("protected_payments", newSet).apply()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isS5) Color(0xFFC62828) else Color.DarkGray),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("八達通", fontSize = 10.sp)
                    }

                    val p8 = "Alipay"
                    val isS8 = protectedPayments.contains(p8)
                    Button(
                        onClick = {
                            val newSet = protectedPayments.toMutableSet()
                            if (isS8) newSet.remove(p8) else newSet.add(p8)
                            protectedPayments = newSet
                            sharedPrefs.edit().putStringSet("protected_payments", newSet).apply()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isS8) Color(0xFFC62828) else Color.DarkGray),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("支付寶", fontSize = 10.sp)
                    }
                }

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    val p9 = "WeChat Pay"
                    val isS9 = protectedPayments.contains(p9)
                    Button(
                        onClick = {
                            val newSet = protectedPayments.toMutableSet()
                            if (isS9) newSet.remove(p9) else newSet.add(p9)
                            protectedPayments = newSet
                            sharedPrefs.edit().putStringSet("protected_payments", newSet).apply()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isS9) Color(0xFFC62828) else Color.DarkGray),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("微信支付", fontSize = 10.sp)
                    }

                    val p6 = "7-Eleven"
                    val isS6 = protectedPayments.contains(p6)
                    Button(
                        onClick = {
                            val newSet = protectedPayments.toMutableSet()
                            if (isS6) newSet.remove(p6) else newSet.add(p6)
                            protectedPayments = newSet
                            sharedPrefs.edit().putStringSet("protected_payments", newSet).apply()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isS6) Color(0xFFC62828) else Color.DarkGray),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("7-11", fontSize = 10.sp)
                    }

                    val p7 = "Circle K"
                    val isS7 = protectedPayments.contains(p7)
                    Button(
                        onClick = {
                            val newSet = protectedPayments.toMutableSet()
                            if (isS7) newSet.remove(p7) else newSet.add(p7)
                            protectedPayments = newSet
                            sharedPrefs.edit().putStringSet("protected_payments", newSet).apply()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isS7) Color(0xFFC62828) else Color.DarkGray),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Circle K", fontSize = 10.sp)
                    }
                }
            }

            HorizontalDivider(color = Color.DarkGray)

            // Trusted Contact config
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("受信任第三方授權聯絡人", fontWeight = FontWeight.Bold, color = Color.White)
                Text("授權遠程釋放被攔截的短訊/通話釣魚連結的聯絡人。", color = Color.Gray, fontSize = 12.sp)
                
                OutlinedTextField(
                    value = contactName,
                    onValueChange = {
                        contactName = it
                        sharedPrefs.edit().putString("auth_contact_name", it).apply()
                    },
                    label = { Text("聯絡人姓名", color = Color.Gray) },
                    colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = contactPhone,
                    onValueChange = {
                        contactPhone = it
                        sharedPrefs.edit().putString("auth_contact_phone", it).apply()
                    },
                    label = { Text("電話號碼", color = Color.Gray) },
                    colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            HorizontalDivider(color = Color.DarkGray)

            // Region Selector
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("區域目標國家/規則政策 (Region Rules)", fontWeight = FontWeight.Bold, color = Color.White)
                Text("選擇當前防護的國家地區（決定程序驗證數據庫的檢查規則）。", color = Color.Gray, fontSize = 12.sp)
                
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf("HK", "SG", "UK", "US", "CA", "AU").forEach { region ->
                        val isSelected = selectedRegion == region
                        Button(
                            onClick = {
                                selectedRegion = region
                                sharedPrefs.edit().putString("region_policy", region).apply()
                                Toast.makeText(context, "規則數據庫已切換至 $region 政策！", Toast.LENGTH_SHORT).show()
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (isSelected) Color(0xFFC62828) else Color.DarkGray
                            ),
                            contentPadding = PaddingValues(horizontal = 6.dp),
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(region, fontSize = 9.sp)
                        }
                    }
                }
            }

            HorizontalDivider(color = Color.DarkGray)

            // Speech Recognition and Translation language selector
            var speechLang by remember { mutableStateOf(sharedPrefs.getString("speech_language_code", "zh-HK") ?: "zh-HK") }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("語音偵測及翻譯語言 (Speech & Translation Language)", fontWeight = FontWeight.Bold, color = Color.White)
                Text("選擇通話實時聽取及翻譯的目標語言（支援廣東話、普通話及英文）。", color = Color.Gray, fontSize = 12.sp)

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    val langs = listOf(
                        Triple("zh-HK", "廣東話 (HK)", "Cantonese"),
                        Triple("zh-CN", "普通話 (CN)", "Mandarin"),
                        Triple("en-US", "英語 (US)", "English")
                    )

                    langs.forEach { lang ->
                        val isSelected = speechLang == lang.first
                        Button(
                            onClick = {
                                speechLang = lang.first
                                sharedPrefs.edit().putString("speech_language_code", lang.first).apply()
                                Toast.makeText(context, "語音檢測已切換至 ${lang.second}！", Toast.LENGTH_SHORT).show()
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (isSelected) Color(0xFFC62828) else Color.DarkGray
                            ),
                            modifier = Modifier.weight(1f),
                            contentPadding = PaddingValues(horizontal = 4.dp)
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(lang.second, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                                Text(lang.third, fontSize = 8.sp, color = Color.LightGray)
                            }
                        }
                    }
                }
            }
        }
    }
}

// Minimal Theme wrapper
@Composable
fun ScamCallAppTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Color(0xFFC62828),
            background = Color(0xFF121212),
            surface = Color(0xFF1E1E1E),
            onPrimary = Color.White,
            onBackground = Color.White,
            onSurface = Color.White
        ),
        content = content
    )
}
