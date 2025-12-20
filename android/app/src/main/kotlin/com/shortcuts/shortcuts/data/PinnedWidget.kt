package com.shortcuts.shortcuts.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "pinned_widgets")
data class PinnedWidget(
    @PrimaryKey val appWidgetId: Int,
    val logicId: Int // References WidgetDefinition.widgetId
)
