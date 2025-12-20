package com.shortcuts.shortcuts

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import com.shortcuts.shortcuts.data.AppDatabase
import com.shortcuts.shortcuts.data.WidgetDefinition
import com.shortcuts.shortcuts.widget.LowCodeWidgetProvider
import com.google.gson.Gson
import com.shortcuts.shortcuts.utils.GsonHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.lowcode/widget"
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Extract widgetId from intent if available
        handleIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val scope = CoroutineScope(Dispatchers.Main)
            
            if (call.method == "getWidgetId") {
                result.success(appWidgetId)
            } else if (call.method == "saveWidgetConfig") {
                val logicId = (call.argument<Any>("widgetId") as? Number)?.toInt() ?: AppWidgetIdFallback(appWidgetId)
                val label = call.argument<String>("label") ?: "Widget"
                val jsonConfig = call.argument<String>("jsonConfig") ?: "[]"
                val iconId = call.argument<String>("iconId") ?: "TERMINAL"
                val colorObj = call.argument<Any>("color")
                val color = (colorObj as? Number)?.toLong() ?: 0xFF007BFFL
                
                android.util.Log.d("LowCode", "Saving: LogicID=$logicId, Label=$label, AppWidgetId=$appWidgetId")

                scope.launch {
                    val db = AppDatabase.getDatabase(applicationContext)
                    
                    // 1. Save Logic Definition
                    val widgetDef = WidgetDefinition(
                        widgetId = logicId,
                        label = label,
                        logicFlow = jsonConfig,
                        iconId = iconId,
                        themeColor = color
                    )
                    withContext(Dispatchers.IO) {
                        db.widgetDao().insertWidget(widgetDef)
                        
                        // 2. If we are configuring a specific Home Screen Widget (appWidgetId), map it!
                        if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                            val mapping = com.shortcuts.shortcuts.data.PinnedWidget(
                                appWidgetId = appWidgetId,
                                logicId = logicId
                            )
                            db.pinnedWidgetDao().insertPinnedWidget(mapping)
                            android.util.Log.d("LowCode", "Mapped AppWidget $appWidgetId -> Logic $logicId")
                            
                            // 3. IMPORTANT: Reset appWidgetId after successful mapping to prevent future accidental mappings
                            // appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID 
                            // (Commented out: User might want to edit it again immediately? 
                            //  But logically, the configuration session is 'consumed'. 
                            //  Ideally we should close activity, but we only do that if it was a cold start config.)
                        }
                    }
                    
                    // 3. Trigger Update
                    val targets = if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) intArrayOf(appWidgetId) else intArrayOf(logicId)
                    val intent = Intent(applicationContext, LowCodeWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, targets)
                    }
                    sendBroadcast(intent)

                    // Return result to Flutter
                    result.success(true)
                    
                    // If launched for configuration, finish the activity
                    if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                        val resultValue = Intent().apply {
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        }
                        setResult(Activity.RESULT_OK, resultValue)
                        finish()
                    }
                }
            } else if (call.method == "getWidget") {
                val widgetId = (call.argument<Any>("widgetId") as? Number)?.toInt() ?: -1
                android.util.Log.d("LowCode", "GetWidget: Requested ID=$widgetId")
                if (widgetId != -1) {
                    scope.launch {
                        val widget = withContext(Dispatchers.IO) {
                            AppDatabase.getDatabase(applicationContext).widgetDao().getWidgetById(widgetId)
                        }
                        if (widget != null) {
                             android.util.Log.d("LowCode", "GetWidget: Found $widget")
                            result.success(mapOf(
                                "widgetId" to widget.widgetId,
                                "label" to widget.label,
                                "iconId" to widget.iconId,
                                "themeColor" to widget.themeColor,
                                "logicFlow" to widget.logicFlow
                            ))
                        } else {
                            android.util.Log.e("LowCode", "GetWidget: Not Found")
                            result.error("NOT_FOUND", "Widget not found", null)
                        }
                    }
                } else {
                    result.error("INVALID_ID", "Invalid Widget ID", null)
                }
            } else if (call.method == "getAllWidgets") {
                scope.launch {
                    val widgets = withContext(Dispatchers.IO) {
                        AppDatabase.getDatabase(applicationContext).widgetDao().getAllWidgets()
                    }
                    android.util.Log.d("LowCode", "Fetched ${widgets.size} widgets")
                    val jsonList = widgets.map { 
                         mapOf(
                             "widgetId" to it.widgetId,
                             "label" to it.label,
                             "iconId" to it.iconId,
                             "themeColor" to it.themeColor
                         )
                    }
                    result.success(jsonList)
                }
            } else if (call.method == "pinWidget") {
                val widgetId = (call.argument<Any>("widgetId") as? Number)?.toInt() ?: -1
                android.util.Log.d("LowCode", "Pinning: ID=$widgetId")
                if (widgetId != -1) {
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val myProvider = android.content.ComponentName(context, LowCodeWidgetProvider::class.java)

                    if (appWidgetManager.isRequestPinAppWidgetSupported) {
                        // Create a PendingIntent to notify us when the widget is created
                        val successIntent = Intent(context, com.shortcuts.shortcuts.utils.PinReceiver::class.java)
                        successIntent.putExtra("SOURCE_WIDGET_ID", widgetId)
                        
                        val successPendingIntent = android.app.PendingIntent.getBroadcast(
                            context,
                            widgetId, // RequestCode
                            successIntent,
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                        )
                        
                        appWidgetManager.requestPinAppWidget(myProvider, null, successPendingIntent)
                        result.success(true)
                    } else {
                        result.error("UNSUPPORTED", "Pinning not supported on this device", null)
                    }
                } else {
                     result.error("INVALID_ID", "Invalid Widget ID", null)
                }
            } else if (call.method == "deleteWidget") {
                val widgetId = (call.argument<Any>("widgetId") as? Number)?.toInt() ?: -1
                if (widgetId != -1) {
                    scope.launch {
                        withContext(Dispatchers.IO) {
                            AppDatabase.getDatabase(applicationContext).widgetDao().deleteWidget(widgetId)
                        }
                        result.success(true)
                    }
                } else {
                    result.error("INVALID_ID", "Invalid Widget ID", null)
                }

            } else if (call.method == "testAction") {
                val actionMap = call.arguments as? Map<String, Any>
                if (actionMap != null) {
                     scope.launch {
                         try {
                             val jsonStr = Gson().toJson(actionMap)
                             val action = GsonHelper.gson.fromJson(jsonStr, com.shortcuts.shortcuts.dsl.Action::class.java)
                             
                             val contextManager = com.shortcuts.shortcuts.engine.ContextManager()
                             val engine = com.shortcuts.shortcuts.engine.LogicEngine(applicationContext)
                             
                             // Run single action as a flow
                             engine.executeFlow(listOf(action), contextManager)
                             
                             // Return the resulting context (e.g. "res" -> {status: 200...})
                             result.success(contextManager.context)
                         } catch (e: Exception) {
                             result.error("EXEC_ERROR", e.message, null)
                         }
                     }
                } else {
                    result.error("INVALID_ARGS", "Missing action arguments", null)
                }

            } else if (call.method == "clearAllWidgets") {
                scope.launch {
                    withContext(Dispatchers.IO) {
                        AppDatabase.getDatabase(applicationContext).widgetDao().deleteAllWidgets()
                    }
                    result.success(true)
                }
            } else {
                result.notImplemented()
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val extras = intent.extras
        
        if (extras != null && extras.containsKey(AppWidgetManager.EXTRA_APPWIDGET_ID)) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
            android.util.Log.d("LowCode", "MainActivity: Received New Widget ID: $appWidgetId")
        }
        
        // Also handle "configure://id/XYZ" deep links if valid
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_CONFIGURE) {
             android.util.Log.d("LowCode", "MainActivity: ACTION_APPWIDGET_CONFIGURE")
             
             // NOTIFY FLUTTER TO OPEN EDITOR
             // Note: flutterEngine might be null if called too early, but usually fine in onNewIntent
             flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                 android.widget.Toast.makeText(this, "Configuring Widget $appWidgetId", android.widget.Toast.LENGTH_SHORT).show()
                 MethodChannel(messenger, CHANNEL).invokeMethod("navigateToEditor", null)
             }
        }
    }
    
    private fun AppWidgetIdFallback(currentId: Int): Int {
         // Fallback logic if needed, or return currentId. 
         // If currentId is invalid, we might be in 'edit' mode from app icon, 
         // but for this flow let's assume valid ID or user entered ID.
         return if (currentId == AppWidgetManager.INVALID_APPWIDGET_ID) 0 else currentId
    }

    private suspend fun saveConfig(
        widgetId: Int,
        label: String,
        jsonConfig: String,
        iconId: String,
        color: Long
    ) {
        val db = AppDatabase.getDatabase(applicationContext)
        val widgetDef = WidgetDefinition(
            widgetId = widgetId,
            label = label,
            logicFlow = jsonConfig,
            iconId = iconId,
            themeColor = color
        )
        db.widgetDao().insertWidget(widgetDef)

        // Trigger Widget Update Immediately
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        // Manually trigger the Provider's onUpdate-like logic via broadcast
        // The LowCodeWidgetProvider.onUpdate typically spawns coroutines.
        // We can send the standard ACTION_APPWIDGET_UPDATE
        val ids = intArrayOf(widgetId)
        val intent = Intent(applicationContext, LowCodeWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        sendBroadcast(intent)
        
        // Also force a redraw by notifying widget data changed if strictly needed,
        // but ACTION_APPWIDGET_UPDATE should suffice if Provider handles it well.
    }
}
