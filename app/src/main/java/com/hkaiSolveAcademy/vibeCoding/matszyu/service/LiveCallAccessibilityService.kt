package com.hkaiSolveAcademy.vibeCoding.matszyu.service

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import com.hkaiSolveAcademy.vibeCoding.matszyu.engine.SkepticismEngine
import java.util.Locale

class LiveCallAccessibilityService : AccessibilityService() {

    private var speechRecognizer: SpeechRecognizer? = null
    private var isRecognizerListening = false
    private val skepticismEngine = SkepticismEngine()

    override fun onCreate() {
        super.onCreate()
        initializeSpeechRecognizer()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // Accessibility can monitor screen text if the phone dialer displays live transcription
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            val sourceNode = event.source
            sourceNode?.let { node ->
                // Scan the phone screen text for suspicious keywords if the system does live speech-to-text natively
                findSuspiciousTextInNodes(node)
            }
        }
    }

    override fun onInterrupt() {
        stopSpeechRecognition()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "START_REAL_TIME_TRANSCRIPTION") {
            startSpeechRecognition()
        } else if (action == "STOP_REAL_TIME_TRANSCRIPTION") {
            stopSpeechRecognition()
        }
        return super.onStartCommand(intent, flags, startId)
    }

    private fun initializeSpeechRecognizer() {
        if (SpeechRecognizer.isRecognitionAvailable(this)) {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {}
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}
                    override fun onEndOfSpeech() {}
                    override fun onError(error: Int) {
                        Log.e("LiveAccessibility", "Speech recognition error: $error")
                        // Restart listener if error occurs during active call
                        if (isRecognizerListening) {
                            startSpeechRecognition()
                        }
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!matches.isNullOrEmpty()) {
                            val recognizedText = matches[0]
                            processRecognizedSpeech(recognizedText)
                        }
                        // Continue listening
                        if (isRecognizerListening) {
                            startSpeechRecognition()
                        }
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!matches.isNullOrEmpty()) {
                            val partialText = matches[0]
                            broadcastTranscriptionBubble("Spammer", partialText, isFinal = false)
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
            }
        }
    }

    private fun startSpeechRecognition() {
        speechRecognizer?.let { recognizer ->
            isRecognizerListening = true
            val sharedPrefs = getSharedPreferences("GuardCallPrefs", Context.MODE_PRIVATE)
            val selectedLangCode = sharedPrefs.getString("speech_language_code", "zh-HK") ?: "zh-HK"
            
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, selectedLangCode)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, selectedLangCode)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }
            recognizer.startListening(intent)
        }
    }

    private fun stopSpeechRecognition() {
        isRecognizerListening = false
        speechRecognizer?.stopListening()
    }

    private fun processRecognizedSpeech(text: String) {
        // Send final text bubble
        broadcastTranscriptionBubble("Spammer", text, isFinal = true)

        // Evaluate via SkepticismEngine
        val analysis = skepticismEngine.analyzeDialogue(this, text)
        if (analysis.riskScore > 0) {
            broadcastSkepticismAlert(analysis)
        }
    }

    private fun findSuspiciousTextInNodes(node: android.view.accessibility.AccessibilityNodeInfo) {
        // Traverses the screen UI nodes recursively to intercept active dialer transcriptions
        val text = node.text?.toString() ?: ""
        if (text.isNotEmpty() && text.length > 5) {
            val analysis = skepticismEngine.analyzeDialogue(this, text)
            if (analysis.riskScore > 50) {
                broadcastSkepticismAlert(analysis)
            }
        }
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                findSuspiciousTextInNodes(child)
            }
        }
    }

    private fun broadcastTranscriptionBubble(speaker: String, text: String, isFinal: Boolean) {
        val intent = Intent("com.hkaiSolveAcademy.vibeCoding.matszyu.TRANSCRIPTION_BUBBLE").apply {
            putExtra("EXTRA_SPEAKER", speaker)
            putExtra("EXTRA_TEXT", text)
            putExtra("EXTRA_IS_FINAL", isFinal)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }

    private fun broadcastSkepticismAlert(analysis: SkepticismEngine.AnalysisResult) {
        val intent = Intent("com.hkaiSolveAcademy.vibeCoding.matszyu.SKEPTICISM_ALERT").apply {
            putExtra("EXTRA_RISK_SCORE", analysis.riskScore)
            putExtra("EXTRA_ADVICE", analysis.advice)
            putExtra("EXTRA_CONTRADICTION", analysis.contradictionFound)
            putExtra("EXTRA_WARNING_TEXT", analysis.warningText)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
    }
}
