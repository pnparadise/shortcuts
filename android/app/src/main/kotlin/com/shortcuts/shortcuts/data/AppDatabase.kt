package com.shortcuts.shortcuts.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase

@Dao
interface WidgetDao {
    @Query("SELECT * FROM widgets WHERE widgetId = :widgetId")
    suspend fun getWidgetById(widgetId: Int): WidgetDefinition?

    @Query("SELECT * FROM widgets")
    suspend fun getAllWidgets(): List<WidgetDefinition>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertWidget(widget: WidgetDefinition)

    @Query("DELETE FROM widgets WHERE widgetId = :widgetId")
    suspend fun deleteWidget(widgetId: Int)

    @Query("DELETE FROM widgets")
    suspend fun deleteAllWidgets()
}

@Dao
interface PinnedWidgetDao {
    @Query("SELECT * FROM pinned_widgets WHERE appWidgetId = :appWidgetId")
    suspend fun getPinnedWidget(appWidgetId: Int): PinnedWidget?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPinnedWidget(pinnedWidget: PinnedWidget)

    @Query("DELETE FROM pinned_widgets WHERE appWidgetId = :appWidgetId")
    suspend fun deletePinnedWidget(appWidgetId: Int)
}

@Database(entities = [WidgetDefinition::class, PinnedWidget::class], version = 2, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun widgetDao(): WidgetDao
    abstract fun pinnedWidgetDao(): PinnedWidgetDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "shortcuts_db"
                )
                .fallbackToDestructiveMigration()
                .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
