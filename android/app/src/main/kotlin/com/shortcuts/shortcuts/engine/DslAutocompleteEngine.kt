package com.shortcuts.shortcuts.engine

/**
 * Suggestion type for different categories of autocompletion
 */
enum class SuggestionType {
    VARIABLE,   // $var, $obj.path
    COMMAND,    // GET_HOST, UPPER, etc.
    OPERATOR,   // CONTAINS, ==, !=, &&, ||, ?:
    KEYWORD     // true, false, null
}

/**
 * Represents a single completion suggestion
 */
data class CompletionSuggestion(
    val display: String,      // Display name in suggestion list
    val insertText: String,   // Actual text to insert
    val type: SuggestionType,
    val description: String? = null
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "display" to display,
        "insertText" to insertText,
        "type" to type.name,
        "description" to description
    )
}

/**
 * DSL Autocomplete Engine
 * 
 * Provides context-aware suggestions based on cursor position and input text.
 * 
 * Logic:
 * 1. If typing $ -> suggest variables from ContextManager
 * 2. If in string interpolation -> suggest variables
 * 3. If after a value (variable/number/string) -> suggest operators
 * 4. Otherwise -> suggest commands and keywords
 */
class DslAutocompleteEngine(private val contextManager: ContextManager) {

    companion object {
        val COMMANDS = listOf(
            "GET_HOST", "GET_PARAM", "GET_PATH", 
            "UPPER", "LOWER", "TRIM", "LENGTH", "REPLACE", "SUBSTRING"
        )

        val INFIX_OPERATORS = listOf(
            "CONTAINS", "STARTS_WITH", "ENDS_WITH", 
            "==", "!=", "&&", "||", "?:", ">", "<", ">=", "<="
        )

        val KEYWORDS = listOf("true", "false", "null")
    }

    /**
     * Get completion suggestions based on current input and cursor position
     * @param input Full text content
     * @param cursorIdx Cursor position (0-indexed)
     * @return List of completion suggestions
     */
    fun getSuggestions(input: String, cursorIdx: Int): List<CompletionSuggestion> {
        val safeIdx = cursorIdx.coerceIn(0, input.length)
        val prefix = input.substring(0, safeIdx)
        
        // Extract the last "word" being typed (split by common delimiters)
        val lastWord = prefix.split(Regex("[\\s()+\\-*/<>=!&|,]")).lastOrNull() ?: ""

        return when {
            // 1. Typing variable ($xxx or $obj.path)
            lastWord.startsWith("$") -> {
                val varPath = lastWord.substring(1)
                getVariableSuggestions(varPath)
            }

            // 2. Inside string interpolation ("text $xxx")
            isInInterpolation(prefix) -> {
                val varPath = lastWord.substringAfterLast("$", "")
                getVariableSuggestions(varPath)
            }

            // 3. After a value, expect operator
            isExpectOperator(prefix) -> {
                INFIX_OPERATORS.filter { 
                    lastWord.isEmpty() || it.startsWith(lastWord.uppercase()) 
                }.map { 
                    CompletionSuggestion(
                        display = it,
                        insertText = " $it ",
                        type = SuggestionType.OPERATOR,
                        description = getOperatorDescription(it)
                    )
                }
            }

            // 4. Default: commands, variable shortcuts, keywords
            else -> {
                val all = mutableListOf<CompletionSuggestion>()

                // Commands
                COMMANDS.filter { it.startsWith(lastWord.uppercase()) }
                    .forEach { 
                        all.add(CompletionSuggestion(
                            display = it,
                            insertText = "$it ",
                            type = SuggestionType.COMMAND,
                            description = getCommandDescription(it)
                        ))
                    }

                // Variable shortcuts (typing letters shows matching vars with $ prefix)
                if (lastWord.isNotEmpty()) {
                    getAllVariablePaths().filter { it.contains(lastWord, ignoreCase = true) }
                        .take(5)
                        .forEach {
                            all.add(CompletionSuggestion(
                                display = "$$it",
                                insertText = "$$it",
                                type = SuggestionType.VARIABLE
                            ))
                        }
                }

                // Keywords
                KEYWORDS.filter { it.startsWith(lastWord.lowercase()) }
                    .forEach {
                        all.add(CompletionSuggestion(
                            display = it,
                            insertText = it,
                            type = SuggestionType.KEYWORD
                        ))
                    }

                all
            }
        }
    }

    /**
     * Get variable suggestions based on partial path
     */
    private fun getVariableSuggestions(partialPath: String): List<CompletionSuggestion> {
        val allPaths = getAllVariablePaths()
        val parts = partialPath.split(".")
        
        return if (parts.size > 1) {
            // Nested path - show children of current level
            val parentPath = parts.dropLast(1).joinToString(".")
            val childPrefix = parts.last()
            
            allPaths.filter { 
                it.startsWith(parentPath, ignoreCase = true) && it.length > parentPath.length + 1
            }.mapNotNull { fullPath ->
                val remaining = fullPath.substring(parentPath.length + 1)
                val nextPart = remaining.split(".").firstOrNull()
                nextPart?.takeIf { it.startsWith(childPrefix, ignoreCase = true) }
            }.distinct().map { childName ->
                CompletionSuggestion(
                    display = childName,
                    insertText = childName,
                    type = SuggestionType.VARIABLE
                )
            }
        } else {
            // Top-level or partial match
            allPaths.filter { it.startsWith(partialPath, ignoreCase = true) }
                .map { path ->
                    // Show immediate next segment
                    val displayPath = if (path.contains(".")) {
                        path.split(".").first()
                    } else {
                        path
                    }
                    CompletionSuggestion(
                        display = "$$displayPath",
                        insertText = displayPath.substring(partialPath.length),
                        type = SuggestionType.VARIABLE
                    )
                }
                .distinctBy { it.display }
        }
    }

    /**
     * Recursively get all variable paths from ContextManager
     */
    private fun getAllVariablePaths(): List<String> {
        val result = mutableListOf<String>()
        
        fun traverse(map: Map<*, *>, prefix: String) {
            map.forEach { (key, value) ->
                val currentPath = if (prefix.isEmpty()) key.toString() else "$prefix.$key"
                result.add(currentPath)
                if (value is Map<*, *>) {
                    traverse(value, currentPath)
                }
            }
        }
        
        traverse(contextManager.context, "")
        return result
    }

    /**
     * Check if cursor is inside a string interpolation context
     */
    private fun isInInterpolation(prefix: String): Boolean {
        val quoteCount = prefix.count { it == '"' }
        if (quoteCount % 2 == 0) return false // Not inside string
        
        val lastQuoteIdx = prefix.lastIndexOf('"')
        val textSinceQuote = prefix.substring(lastQuoteIdx)
        return textSinceQuote.contains("$")
    }

    /**
     * Check if operator suggestion is expected
     */
    private fun isExpectOperator(prefix: String): Boolean {
        val trimmed = prefix.trim()
        if (trimmed.isEmpty()) return false
        
        // After closing quote, variable, number, boolean, or closing paren -> expect operator
        return trimmed.endsWith("\"") ||
               trimmed.endsWith(")") ||
               trimmed.split(Regex("\\s+")).lastOrNull()?.let { lastToken ->
                   lastToken.startsWith("$") ||
                   lastToken.matches(Regex("-?\\d+(\\.\\d+)?")) ||
                   lastToken == "true" ||
                   lastToken == "false"
               } == true
    }

    private fun getOperatorDescription(op: String): String? = when (op) {
        "CONTAINS" -> "Check if contains substring"
        "STARTS_WITH" -> "Check if starts with"
        "ENDS_WITH" -> "Check if ends with"
        "==" -> "Equals"
        "!=" -> "Not equals"
        "&&" -> "Logical AND"
        "||" -> "Logical OR"
        "?:" -> "Elvis (null coalescing)"
        else -> null
    }

    private fun getCommandDescription(cmd: String): String? = when (cmd) {
        "GET_HOST" -> "Extract host from URL"
        "GET_PARAM" -> "Get URL query parameter"
        "GET_PATH" -> "Extract path from URL"
        "UPPER" -> "Convert to uppercase"
        "LOWER" -> "Convert to lowercase"
        "TRIM" -> "Remove whitespace"
        "LENGTH" -> "Get string length"
        "REPLACE" -> "Replace substring"
        "SUBSTRING" -> "Extract substring"
        else -> null
    }
}
