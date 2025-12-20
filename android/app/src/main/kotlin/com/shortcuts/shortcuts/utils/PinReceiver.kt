package com.shortcuts.shortcuts.utils

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.shortcuts.shortcuts.data.AppDatabase
import com.shortcuts.shortcuts.widget.LowCodeWidgetProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class PinReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingId = intent.getIntExtra("SOURCE_WIDGET_ID", -1)
        val newWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)

        Log.d("PinReceiver", "Pinned: Source=$pendingId, New=$newWidgetId")

        if (pendingId != -1 && newWidgetId != -1) {
            val pendingResult = goAsync()
            val scope = CoroutineScope(Dispatchers.IO)
            scope.launch {
                try {
                    val db = AppDatabase.getDatabase(context)
                    // pendingId is the Logic ID (from dashboard)
                    // newWidgetId is the AppWidget ID (from Launcher)
                    
                    val mapping = com.shortcuts.shortcuts.data.PinnedWidget(
                        appWidgetId = newWidgetId,
                        logicId = pendingId
                    )
                    db.pinnedWidgetDao().insertPinnedWidget(mapping)
                    
                    Log.d("PinReceiver", "Mapped AppWidget $newWidgetId -> Logic $pendingId")
                    
                    // Trigger update for the new widget
                        val appWidgetManager = AppWidgetManager.getInstance(context)
                        val providerIntent = Intent(context, LowCodeWidgetProvider::class.java)
                        providerIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        providerIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(newWidgetId))
                        context.sendBroadcast(providerIntent)
                } catch (e: Exception) {
                    e.printStackTrace()
                } finally {
                    pendingResult.finish()
                }
            }
        }
    }
}
