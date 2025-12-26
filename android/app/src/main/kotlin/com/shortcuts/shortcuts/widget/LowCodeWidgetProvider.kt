package com.shortcuts.shortcuts.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.util.Log
import com.shortcuts.shortcuts.R
import com.shortcuts.shortcuts.data.AppDatabase
import com.shortcuts.shortcuts.data.GradientEnum
import com.shortcuts.shortcuts.data.IconEnum
import com.shortcuts.shortcuts.data.WidgetDefinition
import com.shortcuts.shortcuts.dsl.Action
import com.shortcuts.shortcuts.engine.ContextManager
import com.shortcuts.shortcuts.engine.LogicEngine
import com.shortcuts.shortcuts.utils.GsonHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LowCodeWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_RUN_LOGIC = "com.shortcuts.shortcuts.ACTION_RUN_LOGIC"
        const val EXTRA_WIDGET_ID = "extra_widget_id"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        // Just refresh the visuals for static state
        val scope = CoroutineScope(Dispatchers.IO)
        scope.launch {
            val db = AppDatabase.getDatabase(context)
            for (appWidgetId in appWidgetIds) {
                 updateAppWidget(context, appWidgetManager, appWidgetId, isLoading = false)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("LowCodeWidget", "onReceive: Action=${intent.action} Data=${intent.data} Extras=${intent.extras}")
        super.onReceive(context, intent)
        
        // Handle Logic Execution
        if (intent.action == ACTION_RUN_LOGIC) {
            val widgetId = intent.getIntExtra(
                EXTRA_WIDGET_ID,
                intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            )
            Log.d("LowCodeWidget", "onReceive: ACTION_RUN_LOGIC for widgetId=$widgetId")
            
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val pendingResult = goAsync()
                val scope = CoroutineScope(Dispatchers.IO)
                scope.launch {
                    try {
                        runLogic(context, widgetId)
                    } finally {
                        pendingResult.finish()
                    }
                }
            } else {
                Log.e("LowCodeWidget", "onReceive: Invalid Widget ID received")
            }
        } 
        // Force re-bind on standard widget updates to ensure click listeners are active
        else if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE || 
                 intent.action == AppWidgetManager.ACTION_APPWIDGET_OPTIONS_CHANGED) {
             
             val appWidgetManager = AppWidgetManager.getInstance(context)
             val ids = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS) 
                ?: appWidgetManager.getAppWidgetIds(android.content.ComponentName(context, LowCodeWidgetProvider::class.java))
             
             if (ids != null && ids.isNotEmpty()) {
                 Log.d("LowCodeWidget", "onReceive: Forcing update for ids=${ids.joinToString()}")
                 val scope = CoroutineScope(Dispatchers.IO)
                 scope.launch {
                     val db = AppDatabase.getDatabase(context)
                     for (id in ids) {
                         updateAppWidget(context, appWidgetManager, id, isLoading = false)
                     }
                 }
             }
        }
    }

    private suspend fun getDefinition(context: Context, appWidgetId: Int): WidgetDefinition? {
        val db = AppDatabase.getDatabase(context)
        // 1. Try to find mapping [AppWidgetID -> LogicID]
        val pinned = db.pinnedWidgetDao().getPinnedWidget(appWidgetId)
        Log.d("LowCodeWidget", "getDefinition: appWidgetId=$appWidgetId -> found pinned=$pinned")
        
        val logicId = pinned?.logicId ?: appWidgetId // Fallback to same ID if not mapped (e.g. preview)
        
        // 2. Fetch definition by Logic ID
        return db.widgetDao().getWidgetById(logicId)
    }

    private suspend fun runLogic(context: Context, appWidgetId: Int) {
        Log.d("LowCodeWidget", "runLogic: START appWidgetId=$appWidgetId")
        val appWidgetManager = AppWidgetManager.getInstance(context)

        // 1. Set Loading State (VISUAL FEEDBACK: Icon GONE, Progress VISIBLE)
        // Use partial update for speed
        toggleLoading(context, appWidgetManager, appWidgetId, true)

        try {
            // 2. Load Config & Logic by resolving definition
            val widgetDef = getDefinition(context, appWidgetId)
            
            if (widgetDef != null) {
                Log.d("LowCodeWidget", "runLogic: Found definition for logicId=${widgetDef.widgetId}")
                val actions = try {
                    val type = object : com.google.gson.reflect.TypeToken<List<Action>>() {}.type
                    GsonHelper.gson.fromJson<List<Action>>(widgetDef.logicFlow, type)
                } catch (e: Exception) {
                    Log.e("LowCodeWidget", "runLogic: JSON Error", e)
                    emptyList()
                }
                
                Log.d("LowCodeWidget", "runLogic: Executing ${actions.size} actions")
                val contextManager = ContextManager()
                
                // 3. Execute Flow (pass logicId and widgetId for logging)
                val logicId = widgetDef.widgetId
                LogicEngine(
                    context, 
                    com.shortcuts.shortcuts.data.LogRepository(context),
                    logicId,
                    appWidgetId
                ).executeFlow(actions, contextManager)
                
                // 4. Handle "SetView" result
                val newLabel = contextManager.context["_view_text"] as? String
                // Update text if changed?
                if (newLabel != null) {
                    Log.d("LowCodeWidget", "runLogic: Updating label to '$newLabel'")
                    updateAppWidget(context, appWidgetManager, appWidgetId, isLoading = false, overrideLabel = newLabel)
                    return 
                }
            } else {
                Log.e("LowCodeWidget", "runLogic: No definition found!")
                // Optional: Show toast indicating configuration is missing
            }
        } catch (e: Exception) {
            Log.e("LowCodeWidget", "runLogic: Exception", e)
            e.printStackTrace()
        } finally {
             // 5. Revert to Idle State
            toggleLoading(context, appWidgetManager, appWidgetId, false)
            Log.d("LowCodeWidget", "runLogic: END")
        }
    }

    private fun toggleLoading(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        isLoading: Boolean
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_1x1)
        if (isLoading) {
            views.setProgressBar(R.id.progress_bar, 100, 0, true)
        } else {
            views.setProgressBar(R.id.progress_bar, 100, 100, false)
        }
        views.setViewVisibility(R.id.iv_icon, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.progress_bar, android.view.View.VISIBLE)
        appWidgetManager.partiallyUpdateAppWidget(appWidgetId, views)
    }

    private suspend fun updateAppWidget(
        context: Context, 
        appWidgetManager: AppWidgetManager, 
        appWidgetId: Int, 
        isLoading: Boolean, 
        overrideLabel: String? = null
    ) {
        Log.d("LowCodeWidget", "updateAppWidget: appWidgetId=$appWidgetId isLoading=$isLoading")
        var widgetDef = getDefinition(context, appWidgetId)
        
        val views = RemoteViews(context.packageName, R.layout.widget_1x1)
        
        // Render Visuals
        if (widgetDef == null) {
             Log.w("LowCodeWidget", "updateAppWidget: Unconfigured widget $appWidgetId. Showing Setup UI.")
             // Render "Setup" State
             views.setTextViewText(R.id.tv_label, "Setup")
             // Standard White Text with Shadow handles all wallpapers
             views.setTextColor(R.id.tv_label, android.graphics.Color.WHITE)
             
             views.setImageViewResource(R.id.iv_icon, android.R.drawable.ic_menu_add)
             // Use White for contrast on Blue BG
             views.setInt(R.id.iv_icon, "setColorFilter", android.graphics.Color.WHITE)
        } else {
            // Render "Active" State
            // Text
            val labelText = overrideLabel ?: widgetDef.label
            views.setTextViewText(R.id.tv_label, labelText)
            // KEEP LABEL WHITE for Home Screen readability standards
            views.setTextColor(R.id.tv_label, android.graphics.Color.WHITE)
            
            // Icon
            val iconRes = IconEnum.fromId(widgetDef.iconId)?.resId ?: android.R.drawable.ic_menu_edit
            views.setImageViewResource(R.id.iv_icon, iconRes)
            // Tint the ICON White
            views.setInt(R.id.iv_icon, "setColorFilter", android.graphics.Color.WHITE)
            
            // Gradient Background
            val gradientRes = GradientEnum.fromId(widgetDef.gradientId)?.resId ?: R.drawable.gradient_blue
            views.setInt(R.id.icon_bg_container, "setBackgroundResource", gradientRes)
        }
        
        // VISIBILITY TOGGLE (Ensure correct state during full update)
        // State Logic
        if (isLoading) {
            views.setProgressBar(R.id.progress_bar, 100, 0, true)
        } else {
            views.setProgressBar(R.id.progress_bar, 100, 100, false)
        }
        views.setViewVisibility(R.id.iv_icon, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.progress_bar, android.view.View.VISIBLE)

        // Click Handling
        val pendingIntent = if (widgetDef == null) {
            // Unconfigured -> Open Config Activity
            val configIntent = Intent(context, com.shortcuts.shortcuts.MainActivity::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_CONFIGURE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = android.net.Uri.parse("configure://id/$appWidgetId") // Ensure uniqueness
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            PendingIntent.getActivity(
                context,
                appWidgetId,
                configIntent,
                pendingIntentFlags()
            )
        } else {
            // Configured -> Run Logic (Broadcast)
            val logicIntent = Intent(context, LowCodeWidgetProvider::class.java).apply {
                action = ACTION_RUN_LOGIC
                putExtra(EXTRA_WIDGET_ID, appWidgetId)
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = android.net.Uri.parse("widget://id/$appWidgetId")
                `package` = context.packageName 
            }
            PendingIntent.getBroadcast(
                context,
                appWidgetId,
                logicIntent,
                pendingIntentFlags()
            )
        }

        // Apply Click Listener to all views
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
        views.setOnClickPendingIntent(R.id.iv_icon, pendingIntent)
        views.setOnClickPendingIntent(R.id.tv_label, pendingIntent)
        
        Log.d("LowCodeWidget", "updateAppWidget: Applied PendingIntent for $appWidgetId")

        withContext(Dispatchers.Main) {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun pendingIntentFlags(): Int {
        val mutableFlag = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.FLAG_UPDATE_CURRENT or mutableFlag
    }
}
