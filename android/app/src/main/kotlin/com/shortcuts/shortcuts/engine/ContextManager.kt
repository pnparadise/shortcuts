package com.shortcuts.shortcuts.engine

import com.jayway.jsonpath.JsonPath
import com.jayway.jsonpath.PathNotFoundException
import java.util.regex.Pattern

class ContextManager {
    // The shared mutable context
    val context: MutableMap<String, Any> = mutableMapOf()

    /**
     * Interpolates a string template substituting {{ variable.path }} with values from the context.
     * Supports Elvis operator: {{ path ?: "default" }}
     * Uses JsonPath to resolve values from the map.
     */
    fun interpolate(template: String): String {
        if (!template.contains("{{")) return template

        val matcher = Pattern.compile("\\{\\{(.*?)\\}\\}").matcher(template)
        val sb = StringBuffer()

        while (matcher.find()) {
            val fullExpr = matcher.group(1)?.trim() ?: ""
            if (fullExpr.isNotEmpty()) {
                val value = resolveExpression(fullExpr)
                // Escape $ in replacement to avoid regex issues
                matcher.appendReplacement(sb, java.util.regex.Matcher.quoteReplacement(value.toString()))
            }
        }
        matcher.appendTail(sb)
        return sb.toString()
    }
    
    /**
     * Resolves an expression, supporting Elvis operator (?:)
     * Example: "res.data.name ?: \"default\""
     */
    private fun resolveExpression(expr: String): Any {
        // Check for Elvis operator
        if (expr.contains("?:")) {
            val parts = expr.split("?:", limit = 2)
            val path = parts[0].trim()
            val fallback = parts[1].trim().removeSurrounding("\"").removeSurrounding("'")
            
            val result = resolvePath(path)
            return if (result.toString().isEmpty() || result.toString() == "null") {
                fallback
            } else {
                result
            }
        }
        return resolvePath(expr)
    }
    
    /**
     * Resolves a single JsonPath expression against the context map.
     */
    fun resolve(expression: String): Any? {
         // If simpler variable reference provided directly
         return resolvePath(expression)
    }

    private fun resolvePath(path: String): Any {
        return try {
            val normalizedPath = if (path.startsWith("$")) path else "$.$path"
            android.util.Log.d("LowCode", "ContextManager: Resolving path='$path' normalized='$normalizedPath'")
            
            val result = JsonPath.read<Any>(context, normalizedPath)
            android.util.Log.d("LowCode", "ContextManager: Resolved to '$result'")
            result ?: ""
        } catch (e: PathNotFoundException) {
            android.util.Log.w("LowCode", "ContextManager: Path not found: $path")
            ""
        } catch (e: Exception) {
            android.util.Log.e("LowCode", "ContextManager: Error resolving path: $path", e)
            ""
        }
    }
}

