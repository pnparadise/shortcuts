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
    val description: String? = null,
    val replaceStart: Int,    // Start index to replace in original text
    val replaceEnd: Int       // End index to replace
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "display" to display,
        "insertText" to insertText,
        "type" to type.name,
        "description" to description,
        "replaceStart" to replaceStart,
        "replaceEnd" to replaceEnd
    )
}

/**
 * DSL Autocomplete Engine
 * 提供上下文感知的自动补全建议
 */
class DslAutocompleteEngine(private val contextManager: ContextManager) {

    private var explicitVariables: List<String> = emptyList()

    fun setExplicitVariables(vars: List<String>) {
        this.explicitVariables = vars
    }

    companion object {
        val COMMANDS = listOf(
            "GET_HOST", "GET_PARAM", "GET_PATH",
            "UPPER", "LOWER", "TRIM", "LENGTH", "REPLACE", "SUBSTRING", "EXTRACT"
        )

        val INFIX_OPERATORS = listOf(
            "CONTAINS", "STARTS_WITH", "ENDS_WITH",
            "==", "!=", "&&", "||", "?:", ">", "<", ">=", "<=",
            "+", "-", "*", "/", "%"
        )

        val KEYWORDS = listOf("true", "false", "null")

        val QUICK_SYMBOLS = listOf("$", ".", "\"", "=", "?:", "&&", "||", "(", ")")
    }

    /**
     * 获取补全建议主入口
     */
    fun getSuggestions(input: String, cursorIdx: Int): List<CompletionSuggestion> {
        val safeIdx = cursorIdx.coerceIn(0, input.length)
        val prefix = input.substring(0, safeIdx)

        // 提取当前正在输入的词。注意：从正则中移除了 '-' 以支持 $var-name 格式
        val lastWord = prefix.split(Regex("[\\s()\"+*/<>=!&|,]")).lastOrNull() ?: ""
        val lastWordStart = (safeIdx - lastWord.length).coerceAtLeast(0)

        // 实时解析当前脚本中定义的变量 ($var =)
        val scriptVariables = extractScriptVariables(input)

        // 智能插入空格辅助函数
        fun getSmartOpInsertText(op: String, startIdx: Int): String {
            val charBefore = if (startIdx > 0) prefix[startIdx - 1] else ' '
            val needsSpace = !charBefore.isWhitespace()
            return if (needsSpace) " $op " else "$op "
        }

        val suggestions = when {
            // 1. 输入变量 ($xxx 或 $obj.path)
            lastWord.startsWith("$") -> {
                val varPath = lastWord.substring(1)
                val varSuggestions = getVariableSuggestions(varPath, lastWordStart, safeIdx, scriptVariables).toMutableList()

                // 检查是否是 变量+运算符 连写 (例如 $varSTA -> $var STARTS_WITH)
                val allPaths = getAllVariablePaths(scriptVariables)
                val matchingVar = allPaths.filter { varPath.startsWith(it, ignoreCase = true) }.maxByOrNull { it.length }

                if (matchingVar != null && varPath.length > matchingVar.length) {
                    val potentialOp = varPath.substring(matchingVar.length)
                    val opSuggestions = INFIX_OPERATORS.filter { it.startsWith(potentialOp.uppercase()) }.map {
                        val opStart = lastWordStart + 1 + matchingVar.length
                        CompletionSuggestion(
                            display = it,
                            insertText = getSmartOpInsertText(it, opStart),
                            type = SuggestionType.OPERATOR,
                            description = getOperatorDescription(it),
                            replaceStart = opStart,
                            replaceEnd = safeIdx
                        )
                    }
                    varSuggestions.addAll(opSuggestions)
                }
                varSuggestions
            }

            // 2. 字符串插值内部 ("text $xxx")
            isInInterpolation(prefix) -> {
                val varPath = lastWord.substringAfterLast("$", "")
                val interpolationStart = safeIdx - varPath.length - (if (lastWord.endsWith("$" + varPath)) 1 else 0)
                getVariableSuggestions(varPath, interpolationStart, safeIdx, scriptVariables)
            }

            // 3. 在数值/变量/字符串后，提示运算符
            isExpectOperator(prefix.substring(0, lastWordStart)) -> {
                INFIX_OPERATORS.filter {
                    lastWord.isEmpty() || it.startsWith(lastWord.uppercase())
                }.map {
                    CompletionSuggestion(
                        display = it,
                        insertText = getSmartOpInsertText(it, lastWordStart),
                        type = SuggestionType.OPERATOR,
                        description = getOperatorDescription(it),
                        replaceStart = lastWordStart,
                        replaceEnd = safeIdx
                    )
                }
            }

            // 4. 默认：提示指令、变量快捷方式、关键字
            else -> {
                val all = mutableListOf<CompletionSuggestion>()

                COMMANDS.filter { it.startsWith(lastWord.uppercase()) }
                    .forEach {
                        all.add(CompletionSuggestion(
                            display = it,
                            insertText = "$it ",
                            type = SuggestionType.COMMAND,
                            description = getCommandDescription(it),
                            replaceStart = lastWordStart,
                            replaceEnd = safeIdx
                        ))
                    }

                if (lastWord.isNotEmpty()) {
                    getAllVariablePaths(scriptVariables).filter { it.contains(lastWord, ignoreCase = true) }
                        .take(5)
                        .forEach {
                            all.add(CompletionSuggestion(
                                display = "$$it",
                                insertText = "$$it",
                                type = SuggestionType.VARIABLE,
                                replaceStart = lastWordStart,
                                replaceEnd = safeIdx
                            ))
                        }
                }

                KEYWORDS.filter { it.startsWith(lastWord.lowercase()) }
                    .forEach {
                        all.add(CompletionSuggestion(
                            display = it,
                            insertText = it,
                            type = SuggestionType.KEYWORD,
                            replaceStart = lastWordStart,
                            replaceEnd = safeIdx
                        ))
                    }
                all
            }
        }

        // 附加快速符号
        val existingDisplays = suggestions.map { it.display }.toHashSet()
        val quickSuggestions = QUICK_SYMBOLS.filter { !existingDisplays.contains(it) }
            .map {
                CompletionSuggestion(
                    display = it,
                    insertText = it,
                    type = SuggestionType.KEYWORD,
                    replaceStart = safeIdx,
                    replaceEnd = safeIdx
                )
            }

        val combined = suggestions + quickSuggestions

        // 排序逻辑：变量 > 核心符号 > 词类运算符 > 其他
        return combined.sortedWith(compareBy<CompletionSuggestion> {
            val isSymbolic = it.display.any { char -> !char.isLetter() }
            val isTopPriority = it.display in setOf("==", "!=", "&&", "||", "?:")

            when {
                it.type == SuggestionType.VARIABLE -> 0
                isTopPriority -> 1
                isSymbolic -> 2
                it.type == SuggestionType.OPERATOR -> 3
                else -> 4
            }
        }.thenBy { it.display })
    }

    /**
     * 实时提取脚本中的赋值变量 ($var-name =)
     */
    private fun extractScriptVariables(content: String): List<String> {
        val found = mutableListOf<String>()
        val assignmentRegex = Regex("""\$([-a-zA-Z0-9_]+)\s*=""")
        assignmentRegex.findAll(content).forEach {
            found.add(it.groupValues[1])
        }
        return found
    }

    /**
     * 获取所有可用的变量路径（整合 ContextManager 和 实时脚本变量）
     */
    private fun getAllVariablePaths(scriptVars: List<String> = emptyList()): List<String> {
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
        result.addAll(explicitVariables)
        result.addAll(scriptVars)
        return result.distinct()
    }

    /**
     * 获取变量建议列表
     */
    private fun getVariableSuggestions(
        partialPath: String,
        baseStart: Int,
        replaceEnd: Int,
        scriptVars: List<String>
    ): List<CompletionSuggestion> {
        val allPaths = getAllVariablePaths(scriptVars)
        val parts = partialPath.split(".")

        return if (parts.size > 1) {
            val parentPath = parts.dropLast(1).joinToString(".")
            val childPrefix = parts.last()
            val childReplaceStart = baseStart + 1 + parentPath.length + 1

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
                    type = SuggestionType.VARIABLE,
                    replaceStart = childReplaceStart,
                    replaceEnd = replaceEnd
                )
            }
        } else {
            allPaths.filter { it.startsWith(partialPath, ignoreCase = true) }
                .map { path ->
                    val displayPath = if (path.contains(".")) path.split(".").first() else path
                    CompletionSuggestion(
                        display = "$$displayPath",
                        insertText = "$$displayPath",
                        type = SuggestionType.VARIABLE,
                        replaceStart = baseStart,
                        replaceEnd = replaceEnd
                    )
                }
                .distinctBy { it.display }
        }
    }

    private fun isInInterpolation(prefix: String): Boolean {
        val quoteCount = prefix.count { it == '"' }
        if (quoteCount % 2 == 0) return false
        val lastQuoteIdx = prefix.lastIndexOf('"')
        return prefix.substring(lastQuoteIdx).contains("$")
    }

    private fun isExpectOperator(prefix: String): Boolean {
        val trimmed = prefix.trim()
        if (trimmed.isEmpty() || trimmed.endsWith(".")) return false

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
        ">" -> "Greater than"
        "<" -> "Less than"
        "+" -> "Add / Concatenate"
        else -> null
    }

    private fun getCommandDescription(cmd: String): String? = when (cmd) {
        "GET_HOST" -> "Extract host from URL"
        "GET_PARAM" -> "Get URL query parameter"
        "UPPER" -> "Convert to uppercase"
        "TRIM" -> "Remove whitespace"
        "REPLACE" -> "Replace substring"
        "EXTRACT" -> "Parse delimited string to JSON"
        else -> null
    }
}