package com.shortcuts.shortcuts.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONObject

data class ActionLog(
    val id: Long = 0,
    val logicId: Int,      // Primary query key - the logicflow definition ID
    val widgetId: Int,     // The appWidgetId (shortcut instance ID)
    val actionId: String,  // The specific action's UUID
    val timestamp: Long,
    val level: String,
    val message: String,
    val details: String? = null
)

class LogRepository(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_NAME = "action_logs.db"
        const val DATABASE_VERSION = 3  // Bumped for schema change (Force recreate)
        const val TABLE_LOGS = "logs"
        
        const val COL_ID = "id"
        const val COL_LOGIC_ID = "logic_id"
        const val COL_WIDGET_ID = "widget_id"
        const val COL_ACTION_ID = "action_id"
        const val COL_TIMESTAMP = "timestamp"
        const val COL_LEVEL = "level" // INFO, ERROR
        const val COL_MESSAGE = "message"
        const val COL_DETAILS = "details" // JSON or Stacktrace
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTable = """
            CREATE TABLE $TABLE_LOGS (
                $COL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_LOGIC_ID INTEGER NOT NULL,
                $COL_WIDGET_ID INTEGER NOT NULL,
                $COL_ACTION_ID TEXT NOT NULL,
                $COL_TIMESTAMP INTEGER NOT NULL,
                $COL_LEVEL TEXT NOT NULL,
                $COL_MESSAGE TEXT NOT NULL,
                $COL_DETAILS TEXT
            )
        """
        db.execSQL(createTable)
        // Index for faster queries by logic_id (primary query key)
        db.execSQL("CREATE INDEX idx_logic_id ON $TABLE_LOGS ($COL_LOGIC_ID)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Simple migration: drop and recreate (logs are not critical data)
        db.execSQL("DROP TABLE IF EXISTS $TABLE_LOGS")
        onCreate(db)
    }

    fun addLog(logicId: Int, widgetId: Int, actionId: String, level: String, message: String, details: String? = null) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COL_LOGIC_ID, logicId)
            put(COL_WIDGET_ID, widgetId)
            put(COL_ACTION_ID, actionId)
            put(COL_TIMESTAMP, System.currentTimeMillis())
            put(COL_LEVEL, level)
            put(COL_MESSAGE, message)
            put(COL_DETAILS, details)
        }
        val rowId = db.insert(TABLE_LOGS, null, values)
        android.util.Log.d("LogRepository", "addLog: logicId=$logicId, widgetId=$widgetId, actionId=$actionId, rowId=$rowId")
    }

    fun getLogs(logicId: Int): List<Map<String, Any?>> {
        android.util.Log.d("LogRepository", "getLogs: Querying for logicId=$logicId")
        val db = readableDatabase
        val cursor = db.query(
            TABLE_LOGS, 
            null, 
            "$COL_LOGIC_ID = ?", 
            arrayOf(logicId.toString()), 
            null, 
            null, 
            "$COL_TIMESTAMP DESC" // Newest first
        )
        
        val logs = mutableListOf<Map<String, Any?>>()
        with(cursor) {
            while (moveToNext()) {
                logs.add(mapOf(
                    "id" to getLong(getColumnIndexOrThrow(COL_ID)),
                    "logicId" to getInt(getColumnIndexOrThrow(COL_LOGIC_ID)),
                    "widgetId" to getInt(getColumnIndexOrThrow(COL_WIDGET_ID)),
                    "actionId" to getString(getColumnIndexOrThrow(COL_ACTION_ID)),
                    "timestamp" to getLong(getColumnIndexOrThrow(COL_TIMESTAMP)),
                    "level" to getString(getColumnIndexOrThrow(COL_LEVEL)),
                    "message" to getString(getColumnIndexOrThrow(COL_MESSAGE)),
                    "details" to getString(getColumnIndexOrThrow(COL_DETAILS))
                ))
            }
        }
        cursor.close()
        android.util.Log.d("LogRepository", "getLogs: Found ${logs.size} logs for logicId=$logicId")
        return logs
    }

    fun clearLogs(logicId: Int) {
        val db = writableDatabase
        db.delete(TABLE_LOGS, "$COL_LOGIC_ID = ?", arrayOf(logicId.toString()))
    }
}
