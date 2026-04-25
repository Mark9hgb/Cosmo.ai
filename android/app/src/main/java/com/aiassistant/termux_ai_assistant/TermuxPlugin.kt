package com.aiassistant.termux_ai_assistant

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger

class TermuxPlugin : FlutterPlugin, EventChannel.StreamHandler {
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    
    companion object {
        const val CHANNEL = "com.aiassistant.termux_ai_assistant/termux_output"
        const val EVENT_CHANNEL = "com.aiassistant.termux_ai_assistant/termux_events"
    }
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendCommand" -> {
                    val command = call.argument<String>("command")
                    val workdir = call.argument<String?>("workdir")
                    if (command != null) {
                        sendTermuxCommand(command, workdir)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Command is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        eventChannel = EventChannel(messenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel.setStreamHandler(null)
    }
    
    private fun sendTermuxCommand(command: String, workdir: String?) {
        val intent = Intent("com.termux.RUN_COMMAND").apply {
            setPackage("com.termux")
            putExtra("com.termux.extra.command", command)
            putExtra("com.termux.extra.run.id", "ai_${System.currentTimeMillis()}")
            workdir?.let { putExtra("com.termux.extra.workdir", it) }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        
        try {
            val context = android.app.Application()
            context.startActivity(intent)
        } catch (e: Exception) {
            eventSink?.error("TERMUX_NOT_FOUND", "Termux not installed", null)
        }
    }
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}

class TermuxCommandReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == "com.termux.RUN_COMMAND_OUTPUT") {
            val runId = intent.getStringExtra("com.termux.extra.run.id")
            val output = intent.getStringExtra("com.termux.extra.output")
            val exitCode = intent.getIntExtra("com.termux.extra.exit_code", -1)
            
            val result = Intent("com.aiassistant.termux.RUN_COMMAND_OUTPUT").apply {
                putExtra("runId", runId)
                putExtra("output", output)
                putExtra("exitCode", exitCode)
            }
            context?.sendBroadcast(result)
        }
    }
}