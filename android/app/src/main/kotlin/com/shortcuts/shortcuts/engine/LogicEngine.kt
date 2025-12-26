package com.shortcuts.shortcuts.engine

import android.content.Context
import com.shortcuts.shortcuts.data.LogRepository
import com.shortcuts.shortcuts.dsl.Action
import com.shortcuts.shortcuts.utils.GsonHelper
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import java.io.IOException

class LogicEngine(
    private val androidContext: Context, 
    private val logRepository: LogRepository? = null,
    private val logicId: Int = -1,
    private val widgetId: Int = -1
) {

    private val client = OkHttpClient()

    private fun log(actionId: String, message: String, level: String = "INFO", details: String? = null) {
        android.util.Log.d("LowCode", "[$level] $message (LogicID: $logicId, WidgetID: $widgetId, ActionID: $actionId)")
        try {
            logRepository?.addLog(logicId, widgetId, actionId, level, message, details)
        } catch (e: Exception) {
            android.util.Log.e("LowCode", "Failed to write log to DB", e)
        }
    }

    suspend fun executeFlow(actions: List<Action>, contextManager: ContextManager): Boolean {
        android.util.Log.d("LowCode", "LogicEngine: executeFlow with ${actions.size} actions. Actions: $actions")
        for ((index, action) in actions.withIndex()) {
            android.util.Log.d("LowCode", "LogicEngine: Processing action #$index type=${action::class.java.simpleName}")
            // Log start of action
            log(action.id, "Started execution of ${action.type}", "INFO")
            
            try {
                val shouldStop = when (action) {
                    is Action.Fetch -> { executeFetch(action, contextManager); false }
                    is Action.If -> executeIf(action, contextManager)
                    is Action.SetView -> { executeSetView(action, contextManager); false }
                    is Action.Toast -> { executeToast(action, contextManager); false }
                    is Action.Return -> true
                    is Action.Clipboard -> { executeClipboard(action, contextManager); false }
                    is Action.Intent -> { executeIntent(action, contextManager); false }
                    is Action.Notification -> { executeNotification(action, contextManager); false }
                    is Action.Expression -> { executeExpression(action, contextManager); false }
                }
                
                log(action.id, "Completed successfully", "INFO")
                
                if (shouldStop) {
                    android.util.Log.d("LowCode", "LogicEngine: Flow stopped by Return action at index $index")
                    log(action.id, "Flow stopped by Return action", "INFO")
                    return true
                }
            } catch (e: Exception) {
                 android.util.Log.e("LowCode", "LogicEngine: Error executing action #$index", e)
                 log(action.id, "Execution Failed: ${e.message}", "ERROR", e.stackTraceToString())
            }
        }
        return false
    }

    private fun executeFetch(action: Action.Fetch, cm: ContextManager) {
        log(action.id, "Fetching URL: ${action.url} [${action.method}]")
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
                log(action.id, "Response Code: $code", "INFO", "Body preview: ${bodyStr.take(200)}...")
            }
        } catch (e: Exception) {
            // Write error to context with consistent structure
            cm.context[action.targetVar] = mapOf(
                "status" to -1,
                "data" to mapOf("error" to (e.message ?: "Unknown Error")),
                "message" to (e.toString())
            )
            throw e // Re-throw to be caught by executeFlow and logged properly
        }
    }

    private suspend fun executeIf(action: Action.If, cm: ContextManager): Boolean {
        val rawExpression = action.conditionExpression
        log(action.id, "Evaluating condition: $rawExpression")
        android.util.Log.d("LowCode", "LogicEngine: IF expression='$rawExpression'")

        // Use ExpressionEngine for evaluation
        val result = ExpressionEngine.evaluate(rawExpression, cm)
        val isTrue = ExpressionEngine.isTruthy(result)
        
        log(action.id, "Condition result: $isTrue", "INFO", "Value: $result")
        android.util.Log.d("LowCode", "LogicEngine: IF result=$isTrue (value=$result)")

        return if (isTrue) {
            executeFlow(action.trueFlow, cm)
        } else {
            executeFlow(action.falseFlow, cm)
        }
    }


    private fun executeSetView(action: Action.SetView, cm: ContextManager) {
        val text = cm.interpolate(action.textTemplate)
        // Store in special context key for WidgetProvider to pick up?
        // Or Broadcast?
        // ContextManager is shared. We can just write to it. 
        // Provider will check this key after execution.
        cm.context["_view_text"] = text
        log(action.id, "Set view text: $text")
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
                log(action.id, "Showed Toast: $msg")
            } catch (e: Exception) {
                android.util.Log.e("LowCode", "LogicEngine: Failed to start ToastActivity", e)
                throw e
            }
        }
    }

    private fun executeClipboard(action: Action.Clipboard, cm: ContextManager) {
        val clipboard = androidContext.getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
        
        if (action.mode.equals("WRITE", ignoreCase = true)) {
            val text = cm.interpolate(action.textTemplate)
            val clip = android.content.ClipData.newPlainText("LowCode", text)
            clipboard.setPrimaryClip(clip)
            android.util.Log.d("LowCode", "LogicEngine: Clipboard Write: $text")
            log(action.id, "Copied to clipboard: $text")
        } else {
            // READ
            val item = clipboard.primaryClip?.getItemAt(0)
            val text = item?.text?.toString() ?: ""
            cm.context[action.targetVar] = text
            android.util.Log.d("LowCode", "LogicEngine: Clipboard Read: $text -> ${action.targetVar}")
            log(action.id, "Read from clipboard to \$${action.targetVar}", "INFO", text)
        }
    }

    private fun executeIntent(action: Action.Intent, cm: ContextManager) {
        try {
            val intent = android.content.Intent()
            
            // Use VIEW action if no action specified (action config removed from UI)
            if (action.action.isNotEmpty()) {
                intent.action = action.action
            } else {
                intent.action = android.content.Intent.ACTION_VIEW
            }
            
            // Set Data URI if provided
            if (action.dataUri.isNotEmpty()) {
                val interpolatedUri = cm.interpolate(action.dataUri)
                intent.data = android.net.Uri.parse(interpolatedUri)
            }
            
            if (action.packageName.isNotEmpty()) {
                 if (action.className != null && action.className.isNotEmpty()) {
                     intent.setClassName(action.packageName, action.className)
                 } else {
                     intent.setPackage(action.packageName)
                 }
            }
            
            action.extras.forEach { (k, v) ->
                intent.putExtra(cm.interpolate(k), cm.interpolate(v))
            }
            
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            
            androidContext.startActivity(intent)
            android.util.Log.d("LowCode", "LogicEngine: Started Intent: ${action.packageName}/${intent.action} data=${intent.data}")
            log(action.id, "Launched Intent: ${intent.action}", "INFO", "Pkg: ${action.packageName}, Data: ${intent.data}")
        } catch (e: Exception) {
            android.util.Log.e("LowCode", "LogicEngine: Failed to start Intent", e)
             cm.context["_error"] = e.toString()
             throw e
        }
    }

    private fun executeNotification(action: Action.Notification, cm: ContextManager) {
        try {
            val title = cm.interpolate(action.title)
            val message = cm.interpolate(action.message)
            val channelId = action.channelId
            
            val notificationManager = androidContext.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            
            // Create notification channel for Android O+
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    channelId,
                    "Shortcuts Notifications",
                    android.app.NotificationManager.IMPORTANCE_DEFAULT
                )
                notificationManager.createNotificationChannel(channel)
            }
            
            val notification = android.app.Notification.Builder(androidContext, channelId)
                .setContentTitle(title)
                .setContentText(message)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setAutoCancel(true)
                .build()
            
            val notificationId = System.currentTimeMillis().toInt()
            notificationManager.notify(notificationId, notification)
            
            android.util.Log.d("LowCode", "LogicEngine: Posted notification: $title - $message")
            log(action.id, "Posted Notification", "INFO", "Title: $title, Msg: $message")
        } catch (e: Exception) {
            android.util.Log.e("LowCode", "LogicEngine: Failed to post notification", e)
            cm.context["_error"] = e.toString()
            throw e
        }
    }

    private fun executeExpression(action: Action.Expression, cm: ContextManager) {
        android.util.Log.d("LowCode", "LogicEngine: Executing Expression script")
        log(action.id, "Executing script", "INFO", action.script)
        
        // Parse multi-line script, each line is an assignment: target = expression
        action.script.split("\n").forEach { line ->
            val trimmedLine = line.trim()
            if (trimmedLine.isEmpty() || trimmedLine.startsWith("//")) {
                return@forEach // Skip empty lines and comments
            }
            
            if (trimmedLine.contains("=")) {
                val parts = trimmedLine.split("=", limit = 2)
                val rawTarget = parts[0].trim()
                
                // Strict Check: Variable declaration MUST start with $
                if (!rawTarget.startsWith("$")) {
                    android.util.Log.w("LowCode", "LogicEngine: Invalid variable assignment '$rawTarget'. Must start with '$'.")
                    return@forEach
                }

                val target = rawTarget.removePrefix("$")
                val expr = parts[1].trim()
                
                // Evaluate expression and store in context
                val result = ExpressionEngine.evaluate(expr, cm)
                cm.context[target] = result
                android.util.Log.d("LowCode", "LogicEngine: Expression assigned $target = $result")
                // log(action.id, "Assigned \$$target = $result") // Optional: might be too verbose
            }
        }
    }
}
