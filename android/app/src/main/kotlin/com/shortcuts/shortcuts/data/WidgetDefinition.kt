package com.shortcuts.shortcuts.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.shortcuts.shortcuts.R

@Entity(tableName = "widgets")
data class WidgetDefinition(
    @PrimaryKey val widgetId: Int,
    val label: String = "New Widget",
    val iconId: String = IconEnum.TERMINAL.name,
    val themeColor: Long = 0xFF007BFFL, // Default Blue
    val gradientId: String = GradientEnum.BLUE.name, // Gradient background scheme
    val logicFlow: String = "[]" // JSON of List<Action>
)

enum class IconEnum(val resId: Int) {
    TERMINAL(R.drawable.ic_play), 
    CLOUD(R.drawable.ic_refresh),
    BOLT(R.drawable.ic_flash),
    DATABASE(R.drawable.ic_key);

    companion object {
        fun fromId(id: String): IconEnum? = entries.find { it.name == id }
    }
}

enum class GradientEnum(val resId: Int) {
    BLUE(R.drawable.gradient_blue),
    PURPLE(R.drawable.gradient_purple),
    GREEN(R.drawable.gradient_green),
    ORANGE(R.drawable.gradient_orange),
    RED(R.drawable.gradient_red);

    companion object {
        fun fromId(id: String): GradientEnum? = entries.find { it.name == id }
    }
}

