package com.ahamai.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import javax.script.ScriptEngineManager
import javax.script.ScriptException

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
        
        return when (language.lowercase()) {
            "javascript", "js" -> executeJavaScriptEmbedded(code, startTime)
            else -> mapOf(
                "output" to "",
                "error" to "Language '$language' not supported for execution",
                "executionTime" to 0
            )
        }
    }
    
    private fun executeJavaScriptEmbedded(code: String, startTime: Long): Map<String, Any> {
        return try {
            val engine = ScriptEngineManager().getEngineByName("javascript")
            
            // Capture console.log output
            val outputCapture = StringBuilder()
            
            // Add console.log functionality
            val jsCode = """
                var console = {
                    log: function() {
                        var args = Array.prototype.slice.call(arguments);
                        outputBuffer += args.join(' ') + '\n';
                    }
                };
                var outputBuffer = '';
                
                $code
                
                outputBuffer;
            """.trimIndent()
            
            val result = engine.eval(jsCode)
            val executionTime = System.currentTimeMillis() - startTime
            
            mapOf(
                "output" to (result?.toString() ?: "").trim(),
                "error" to "",
                "executionTime" to executionTime
            )
        } catch (e: ScriptException) {
            mapOf(
                "output" to "",
                "error" to "JavaScript Error: ${e.message}",
                "executionTime" to System.currentTimeMillis() - startTime
            )
        } catch (e: Exception) {
            mapOf(
                "output" to "",
                "error" to "Execution failed: ${e.message}",
                "executionTime" to System.currentTimeMillis() - startTime
            )
        }
    }
    

    

}