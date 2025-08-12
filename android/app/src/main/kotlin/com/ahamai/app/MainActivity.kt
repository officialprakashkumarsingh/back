package com.ahamai.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ahamai.app/code_execution"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "executeCode" -> {
                    val code = call.argument<String>("code") ?: ""
                    val language = call.argument<String>("language") ?: ""
                    
                    try {
                        val executionResult = executeCode(code, language)
                        result.success(executionResult)
                    } catch (e: Exception) {
                        result.success(mapOf(
                            "output" to "",
                            "error" to "Execution failed: ${e.message}",
                            "executionTime" to 0
                        ))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun executeCode(code: String, language: String): Map<String, Any> {
        val startTime = System.currentTimeMillis()
        
        // Code execution not supported on Android without external dependencies
        return mapOf(
            "output" to "",
            "error" to "Code execution is not available on this platform",
            "executionTime" to System.currentTimeMillis() - startTime
        )
    }
}