package com.shortcuts.shortcuts.engine

import com.jayway.jsonpath.JsonPath
import com.jayway.jsonpath.PathNotFoundException
import java.util.regex.Pattern

class ContextManager {
    // The shared mutable context
    val context: MutableMap<String, Any?> = mutableMapOf()

    /**
     * Interpolates a string template substituting $variable or $obj.path with values from the context.
     * Supports nested paths like $res.data.name
     * 
     * Examples:
     * - "Hello $name" -> "Hello World"
     * - "Status: $res.status" -> "Status: 200"
     * - "https://example.com/$id" -> "https://example.com/123"
     */
    fun interpolate(template: String): String {
        if (!template.contains("$")) return template

        // Match $variable or $obj.path.nested
        val regex = Regex("""\$(\w+(?:\.\w+)*)""")
        return regex.replace(template) { matchResult ->
            val varPath = matchResult.groupValues[1]
            val value = resolvePath(varPath)
            value?.toString() ?: ""
        }
    }
    
    /**
     * Resolves a single path expression against the context map.
     * Supports nested paths like "res.data.name"
     */
    fun resolve(expression: String): Any? {
         return resolvePath(expression)
    }

    /**
     * Resolve a path (e.g., "res.data.name") from the context
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
                    // Try JsonPath for complex objects
                    try {
                        val normalizedPath = "\$." + parts.drop(i).joinToString(".")
                        JsonPath.read<Any?>(current, normalizedPath)
                    } catch (e: Exception) {
                        null
                    }
                }
            }
            if (i < parts.size - 1 && current == null) return null
        }
        
        return current
    }
}

