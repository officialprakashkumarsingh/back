package com.ahamai.app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.StringWriter
import java.io.PrintWriter
import java.util.regex.Pattern
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
            "python", "py" -> executePythonSimulator(code, startTime)
            "java" -> executeJavaSimulator(code, startTime)
            "dart" -> executeDartAnalyzer(code, startTime)
            else -> mapOf(
                "output" to "",
                "error" to "Language '$language' not supported",
                "executionTime" to 0
            )
        }
    }
    
    private fun executeDart(code: String, startTime: Long): Map<String, Any> {
        try {
            // Create temporary Dart file
            val tempFile = File.createTempFile("temp_dart", ".dart")
            tempFile.writeText(code)
            
            // Execute using dart command
            val process = ProcessBuilder("dart", tempFile.absolutePath)
                .redirectErrorStream(true)
                .start()
            
            val output = process.inputStream.bufferedReader().readText()
            val success = process.waitFor(10, TimeUnit.SECONDS) && process.exitValue() == 0
            
            tempFile.delete()
            
            val executionTime = System.currentTimeMillis() - startTime
            
            return if (success) {
                mapOf(
                    "output" to output.trim(),
                    "error" to "",
                    "executionTime" to executionTime
                )
            } else {
                mapOf(
                    "output" to "",
                    "error" to output.trim(),
                    "executionTime" to executionTime
                )
            }
        } catch (e: Exception) {
            return mapOf(
                "output" to "",
                "error" to "Dart execution failed: ${e.message}\n\nNote: Dart SDK must be installed on the device",
                "executionTime" to System.currentTimeMillis() - startTime
            )
        }
    }
    
    private fun executePython(code: String, startTime: Long): Map<String, Any> {
        try {
            // Create temporary Python file
            val tempFile = File.createTempFile("temp_python", ".py")
            tempFile.writeText(code)
            
            // Try python3 first, then python
            var process = try {
                ProcessBuilder("python3", tempFile.absolutePath)
                    .redirectErrorStream(true)
                    .start()
            } catch (e: IOException) {
                ProcessBuilder("python", tempFile.absolutePath)
                    .redirectErrorStream(true)
                    .start()
            }
            
            val output = process.inputStream.bufferedReader().readText()
            val success = process.waitFor(10, TimeUnit.SECONDS) && process.exitValue() == 0
            
            tempFile.delete()
            
            val executionTime = System.currentTimeMillis() - startTime
            
            return if (success) {
                mapOf(
                    "output" to output.trim(),
                    "error" to "",
                    "executionTime" to executionTime
                )
            } else {
                mapOf(
                    "output" to "",
                    "error" to output.trim(),
                    "executionTime" to executionTime
                )
            }
        } catch (e: Exception) {
            return mapOf(
                "output" to "",
                "error" to "Python execution failed: ${e.message}\n\nNote: Python must be installed on the device",
                "executionTime" to System.currentTimeMillis() - startTime
            )
        }
    }
    
    private fun executeJava(code: String, startTime: Long): Map<String, Any> {
        try {
            // Extract class name from code
            val classNameRegex = Regex("public\\s+class\\s+(\\w+)")
            val classMatch = classNameRegex.find(code)
            val className = classMatch?.groupValues?.get(1) ?: "TempClass"
            
            // Create temporary Java file
            val tempFile = File.createTempFile(className, ".java")
            tempFile.writeText(code)
            
            // Compile Java code
            val compileProcess = ProcessBuilder("javac", tempFile.absolutePath)
                .redirectErrorStream(true)
                .start()
            
            val compileOutput = compileProcess.inputStream.bufferedReader().readText()
            val compileSuccess = compileProcess.waitFor(10, TimeUnit.SECONDS) && compileProcess.exitValue() == 0
            
            if (!compileSuccess) {
                tempFile.delete()
                return mapOf(
                    "output" to "",
                    "error" to "Compilation failed:\n$compileOutput",
                    "executionTime" to System.currentTimeMillis() - startTime
                )
            }
            
            // Execute compiled Java code
            val runProcess = ProcessBuilder("java", "-cp", tempFile.parent, className)
                .redirectErrorStream(true)
                .start()
            
            val output = runProcess.inputStream.bufferedReader().readText()
            val success = runProcess.waitFor(10, TimeUnit.SECONDS) && runProcess.exitValue() == 0
            
            // Clean up files
            tempFile.delete()
            File(tempFile.parent, "$className.class").delete()
            
            val executionTime = System.currentTimeMillis() - startTime
            
            return if (success) {
                mapOf(
                    "output" to output.trim(),
                    "error" to "",
                    "executionTime" to executionTime
                )
            } else {
                mapOf(
                    "output" to "",
                    "error" to output.trim(),
                    "executionTime" to executionTime
                )
            }
        } catch (e: Exception) {
            return mapOf(
                "output" to "",
                "error" to "Java execution failed: ${e.message}\n\nNote: Java SDK must be installed on the device",
                "executionTime" to System.currentTimeMillis() - startTime
            )
        }
    }
    
    private fun executeJavaScript(code: String, startTime: Long): Map<String, Any> {
        try {
            // Create temporary JavaScript file
            val tempFile = File.createTempFile("temp_js", ".js")
            tempFile.writeText(code)
            
            // Execute using node
            val process = ProcessBuilder("node", tempFile.absolutePath)
                .redirectErrorStream(true)
                .start()
            
            val output = process.inputStream.bufferedReader().readText()
            val success = process.waitFor(10, TimeUnit.SECONDS) && process.exitValue() == 0
            
            tempFile.delete()
            
            val executionTime = System.currentTimeMillis() - startTime
            
            return if (success) {
                mapOf(
                    "output" to output.trim(),
                    "error" to "",
                    "executionTime" to executionTime
                )
            } else {
                mapOf(
                    "output" to "",
                    "error" to output.trim(),
                    "executionTime" to executionTime
                )
            }
        } catch (e: Exception) {
            return mapOf(
                "output" to "",
                "error" to "JavaScript execution failed: ${e.message}\n\nNote: Node.js must be installed on the device",
                "executionTime" to System.currentTimeMillis() - startTime
            )
        }
    }
}