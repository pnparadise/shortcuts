package com.shortcuts.shortcuts.engine

import com.jayway.jsonpath.JsonPath
import java.text.DecimalFormat

/**
 * ContextManager - 状态管理与字符串插值器
 * 负责数值展示的优化和变量路径解析
 */
class ContextManager {
    val context: MutableMap<String, Any?> = mutableMapOf()

    // 优化：使用 DecimalFormat 彻底解决科学计数法 (E11) 问题，且最多展示两位小数
    private val numberFormatter = DecimalFormat("0.##").apply {
        isGroupingUsed = false // 不使用千分位，确保大数字完整
    }

    /**
     * 格式化输出数值：整数显整数，小数显2位
     */
    private fun formatValueForDisplay(value: Any?): String {
        return when (value) {
            null -> ""
            is Number -> numberFormatter.format(value.toDouble())
            else -> value.toString()
        }
    }

    /**
     * 字符串插值：将 "$var" 替换为真实值
     */
    fun interpolate(template: String): String {
        if (!template.contains("$")) return template

        // 正则支持带中划线的变量路径
        val regex = Regex("""\$([a-zA-Z_][a-zA-Z0-9_-]*(?:\.[a-zA-Z0-9_-]+)*)""")
        return regex.replace(template) { matchResult ->
            val varPath = matchResult.groupValues[1]
            val value = resolvePath(varPath)
            formatValueForDisplay(value)
        }
    }

    fun resolve(expression: String): Any? {
        return resolvePath(expression)
    }

    /**
     * 变量解析逻辑：优先 Map 查找，失败则尝试 JsonPath
     */
    private fun resolvePath(path: String): Any? {
        val parts = path.split(".")
        if (parts.isEmpty()) return null

        var current: Any? = context[parts[0]]

        for (i in 1 until parts.size) {
            if (current == null) return null
            current = when (current) {
                is Map<*, *> -> current[parts[i]]
                else -> {
                    try {
                        val normalizedPath = "\$." + parts.drop(i).joinToString(".")
                        JsonPath.read<Any?>(current, normalizedPath)
                    } catch (e: Exception) {
                        null
                    }
                }
            }
        }
        return current
    }
}