package com.shortcuts.shortcuts.engine

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import com.shortcuts.shortcuts.dsl.Action
import com.shortcuts.shortcuts.utils.GsonHelper
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import java.io.IOException

class LogicEngine(private val androidContext: Context) {

    private val client = OkHttpClient()


    suspend fun executeFlow(actions: List<Action>, contextManager: ContextManager) {
        android.util.Log.d("LowCode", "LogicEngine: executeFlow with ${actions.size} actions. Actions: $actions")
        for ((index, action) in actions.withIndex()) {
            android.util.Log.d("LowCode", "LogicEngine: Processing action #$index type=${action::class.java.simpleName}")
            try {
                when (action) {
                    is Action.Fetch -> executeFetch(action, contextManager)
                    is Action.If -> executeIf(action, contextManager)
                    is Action.SetView -> executeSetView(action, contextManager)
                    is Action.Toast -> executeToast(action, contextManager)
                }
            } catch (e: Exception) {
                 android.util.Log.e("LowCode", "LogicEngine: Error executing action #$index", e)
            }
        }
    }

    private fun executeFetch(action: Action.Fetch, cm: ContextManager) {
        try {
            val url = cm.interpolate(action.url)
            val builder = Request.Builder().url(url)
            
            if (action.headers.isNotEmpty()) {
                for ((k, v) in action.headers) {
                    builder.addHeader(cm.interpolate(k), cm.interpolate(v))
                }
            }

            if (action.method.equals("POST", ignoreCase = true) || action.method.equals("PUT", ignoreCase = true)) {
                val bodyContent = action.body?.let { cm.interpolate(it) } ?: ""
                val mediaType = action.headers["Content-Type"]?.let { cm.interpolate(it) }?.toMediaTypeOrNull() 
                    ?: "application/json".toMediaTypeOrNull()
                builder.method(action.method, bodyContent.toRequestBody(mediaType))
            } else {
                builder.method(action.method, null)
            }

            client.newCall(builder.build()).execute().use { response ->
                val bodyStr = response.body?.string() ?: ""
                val code = response.code

                // Parse body as JSON if possible to allow object navigation
                val parsedBody = try {
                    GsonHelper.gson.fromJson(bodyStr, Any::class.java)
                } catch (e: Exception) {
                    bodyStr // Fallback to string if not JSON
                }

                val resultObj = mapOf(
                    "status" to code,
                    "data" to parsedBody,
                    "headers" to response.headers.toMap()
                )
                
                // Write to Context
                cm.context[action.targetVar] = resultObj
            }
        } catch (e: Exception) {
            e.printStackTrace()
            // Write error to context with consistent structure
            cm.context[action.targetVar] = mapOf(
                "status" to -1,
                "data" to null,
                "message" to (e.message ?: "Unknown Error")
            )
        }
    }

    private suspend fun executeIf(action: Action.If, cm: ContextManager) {
        val rawExpression = action.conditionExpression
        // Interpolate first to resolve variables
        val resolved = cm.interpolate(rawExpression)
        android.util.Log.d("LowCode", "LogicEngine: IF expression raw='$rawExpression' resolved='$resolved'")

        val isTrue = try {
            evaluateExpression(resolved)
        } catch (e: Exception) {
            android.util.Log.e("LowCode", "LogicEngine: Expression evaluation failed", e)
            false
        }

        android.util.Log.d("LowCode", "LogicEngine: IF result=$isTrue")

        if (isTrue) {
            executeFlow(action.trueFlow, cm)
        } else {
            executeFlow(action.falseFlow, cm)
        }
    }

    private fun evaluateExpression(expr: String): Boolean {
        // 1. Handle OR (||) - Lowest precedence, split first
        if (expr.contains("||")) {
            val parts = expr.split("||")
            // If ANY part is true, return true
            return parts.any { evaluateExpression(it.trim()) }
        }

        // 2. Handle AND (&&) - Higher precedence than OR
        if (expr.contains("&&")) {
            val parts = expr.split("&&")
            // If ALL parts are true, return true
            return parts.all { evaluateExpression(it.trim()) }
        }

        // 3. Handle Atomic Logic (==, !=, >, <, etc)
        return evaluateAtomic(expr.trim())
    }

    private fun evaluateAtomic(resolved: String): Boolean {
        return when {
            resolved.contains("==") -> {
                val parts = resolved.split("==", limit = 2)
                parts[0].trim() == parts[1].trim()
            }
            resolved.contains("!=") -> {
                val parts = resolved.split("!=", limit = 2)
                parts[0].trim() != parts[1].trim()
            }
            resolved.contains(">=") -> {
                val parts = resolved.split(">=", limit = 2)
                parts[0].trim().toDouble() >= parts[1].trim().toDouble()
            }
            resolved.contains("<=") -> {
                val parts = resolved.split("<=", limit = 2)
                parts[0].trim().toDouble() <= parts[1].trim().toDouble()
            }
            resolved.contains(">") -> {
                val parts = resolved.split(">", limit = 2)
                parts[0].trim().toDouble() > parts[1].trim().toDouble()
            }
            resolved.contains("<") -> {
                val parts = resolved.split("<", limit = 2)
                parts[0].trim().toDouble() < parts[1].trim().toDouble()
            }
            else -> {
                // Fallback to Truthy check
                when (resolved.lowercase()) {
                    "true" -> true
                    "false" -> false
                    "null" -> false
                    "" -> false
                    "0" -> false
                    else -> true
                }
            }
        }
    }

    private fun executeSetView(action: Action.SetView, cm: ContextManager) {
        val text = cm.interpolate(action.textTemplate)
        // Store in special context key for WidgetProvider to pick up?
        // Or Broadcast?
        // ContextManager is shared. We can just write to it. 
        // Provider will check this key after execution.
        cm.context["_view_text"] = text
    }

    private suspend fun executeToast(action: Action.Toast, cm: ContextManager) {
        android.util.Log.d("LowCode", "LogicEngine: executeToast template='${action.messageTemplate}'")
        val msg = cm.interpolate(action.messageTemplate)
        android.util.Log.d("LowCode", "LogicEngine: executeToast interpolated='$msg'")
        
        if (msg.isNotEmpty()) {
            try {
                val intent = android.content.Intent(androidContext, com.shortcuts.shortcuts.utils.ToastActivity::class.java).apply {
                    putExtra("message", msg)
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_NO_ANIMATION
                }
                androidContext.startActivity(intent)
                android.util.Log.d("LowCode", "LogicEngine: Started ToastActivity")
            } catch (e: Exception) {
                android.util.Log.e("LowCode", "LogicEngine: Failed to start ToastActivity", e)
            }
        }
    }
}
