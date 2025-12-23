package com.shortcuts.shortcuts.engine

import android.net.Uri

/**
 * ExpressionEngine v2.0 - DSL Parser and Evaluator
 * 
 * Syntax:
 * - Variables: $var, $item.id
 * - Strings: "text" with interpolation "id=$id"
 * - Literals: true, false, null, 123.4
 * - Implicit concatenation: "id=" $id or $id ".jpg"
 * - Operators: ?:, ||, &&, !, ==, !=, CONTAINS, +, -, >, <
 * - Commands: GET_PARAM, GET_HOST, UPPER, REPLACE
 */
object ExpressionEngine {

    /**
     * Main entry point for expression evaluation
     */
    fun evaluate(expr: String?, cm: ContextManager): Any? {
        val raw = expr?.trim() ?: return null
        if (raw.isEmpty()) return null

        // 1. Handle high-priority logical operators (recursive)
        if (raw.contains("?:")) {
            val p = splitByFirstOp(raw, "?:")
            val l = evaluate(p[0], cm)
            return if (isTruthy(l)) l else evaluate(p[1], cm)
        }
        if (raw.contains("||")) {
            return raw.split("||").any { isTruthy(evaluate(it, cm)) }
        }
        if (raw.contains("&&")) {
            return raw.split("&&").all { isTruthy(evaluate(it, cm)) }
        }

        // 2. Tokenize (enhanced regex: supports no-space splitting)
        val tokens = tokenize(raw)
        if (tokens.isEmpty()) return null

        // 3. Variable resolution and interpolation
        val resolvedTokens = tokens.map { resolve(it, cm) }

        // 4. Handle prefix negation (! $var)
        if (resolvedTokens.isNotEmpty() && resolvedTokens[0] == "!" && resolvedTokens.size >= 2) {
            return !isTruthy(resolvedTokens[1])
        }

        // 5. Handle implicit concatenation (consecutive values without operator)
        val mergedTokens = mutableListOf<Any?>()
        for (token in resolvedTokens) {
            if (mergedTokens.isNotEmpty() && !isOp(token) && !isOp(mergedTokens.last())) {
                val prev = mergedTokens.removeAt(mergedTokens.size - 1)
                mergedTokens.add(prev.toString() + token.toString())
            } else {
                mergedTokens.add(token)
            }
        }

        // 6. Handle infix operators ($a CONTAINS $b or $a+$b)
        if (mergedTokens.size >= 3 && isInfix(mergedTokens[1].toString())) {
            return executeInfix(mergedTokens[0], mergedTokens[1].toString().uppercase(), mergedTokens[2])
        }

        // 7. Handle command functions (CMD arg1 arg2)
        val firstToken = mergedTokens[0].toString()
        if (isInstruction(firstToken)) {
            return executeCmd(firstToken.uppercase(), mergedTokens.drop(1))
        }

        return mergedTokens[0]
    }

    /**
     * Tokenize input into discrete tokens
     * Matches: quoted strings | multi-char operators | variables/words | single-char operators
     */
    private fun tokenize(input: String): List<String> {
        val regex = Regex("""("[^"]*"|==|!=|>=|<=|\?\:|&&|\|\||[+\-*/=<>!&|?:]|\$?\w+(\.\w+)*)""")
        return regex.findAll(input).map { it.value }.toList()
    }

    /**
     * Resolve a token to its actual value
     */
    private fun resolve(token: String, cm: ContextManager): Any? {
        return when {
            // Variable resolution ($var or $obj.prop)
            token.startsWith("$") -> resolveVariable(token.substring(1), cm)
            // String with interpolation
            token.startsWith("\"") -> {
                val content = token.trim('"')
                cm.interpolate(content)
            }
            // Boolean literals
            token == "true" -> true
            token == "false" -> false
            token == "null" -> null
            // Numeric literals
            token.matches(Regex("""^-?\d+(\.\d+)?$""")) -> token.toDouble()
            // Pass through (operators, commands)
            else -> token
        }
    }

    /**
     * Resolve nested variable path like $item.id or $res.data.name
     */
    private fun resolveVariable(path: String, cm: ContextManager): Any? {
        val parts = path.split(".")
        var current: Any? = cm.context[parts[0]]
        
        for (i in 1 until parts.size) {
            if (current == null) return null
            current = when (current) {
                is Map<*, *> -> current[parts[i]]
                else -> null
            }
        }
        return current
    }

    // Helper: check if token is an operator
    private fun isOp(t: Any?): Boolean {
        return t is String && (isInfix(t) || isInstruction(t) || t in listOf("!", "&&", "||", "?:"))
    }

    // Helper: check if token is an infix operator
    private fun isInfix(op: String): Boolean {
        return op.uppercase() in listOf("==", "!=", "CONTAINS", "STARTS_WITH", "ENDS_WITH", "+", "-", "*", "/", ">", "<", ">=", "<=")
    }

    // Helper: check if token is a command instruction
    private fun isInstruction(cmd: String): Boolean {
        return cmd.uppercase() in listOf("GET_HOST", "GET_PARAM", "GET_PATH", "REPLACE", "UPPER", "LOWER", "TRIM", "LENGTH", "SUBSTRING")
    }

    /**
     * Check if a value is truthy
     */
    fun isTruthy(v: Any?): Boolean = when (v) {
        null -> false
        is Boolean -> v
        is String -> v.isNotEmpty() && v != "null" && v != "false"
        is Number -> v.toDouble() != 0.0
        is Collection<*> -> v.isNotEmpty()
        else -> true
    }

    /**
     * Split string by first occurrence of operator
     */
    private fun splitByFirstOp(raw: String, op: String): List<String> {
        val index = raw.indexOf(op)
        if (index == -1) return listOf(raw, "")
        return listOf(raw.substring(0, index), raw.substring(index + op.length))
    }

    /**
     * Execute infix operator
     */
    private fun executeInfix(l: Any?, op: String, r: Any?): Any? {
        val sL = l?.toString() ?: ""
        val sR = r?.toString() ?: ""
        
        return when (op) {
            // String/Number addition
            "+" -> {
                if (l is Number && r is Number) {
                    l.toDouble() + r.toDouble()
                } else {
                    sL + sR
                }
            }
            // Arithmetic
            "-" -> (l as? Number)?.toDouble()?.minus((r as? Number)?.toDouble() ?: 0.0) ?: 0.0
            "*" -> (l as? Number)?.toDouble()?.times((r as? Number)?.toDouble() ?: 1.0) ?: 0.0
            "/" -> {
                val divisor = (r as? Number)?.toDouble() ?: 1.0
                if (divisor != 0.0) (l as? Number)?.toDouble()?.div(divisor) ?: 0.0 else 0.0
            }
            // Comparison
            "==" -> sL == sR
            "!=" -> sL != sR
            ">" -> (l as? Number)?.toDouble()?.let { it > ((r as? Number)?.toDouble() ?: 0.0) } ?: false
            "<" -> (l as? Number)?.toDouble()?.let { it < ((r as? Number)?.toDouble() ?: 0.0) } ?: false
            ">=" -> (l as? Number)?.toDouble()?.let { it >= ((r as? Number)?.toDouble() ?: 0.0) } ?: false
            "<=" -> (l as? Number)?.toDouble()?.let { it <= ((r as? Number)?.toDouble() ?: 0.0) } ?: false
            // String operations
            "CONTAINS" -> sL.contains(sR, ignoreCase = true)
            "STARTS_WITH" -> sL.startsWith(sR, ignoreCase = true)
            "ENDS_WITH" -> sL.endsWith(sR, ignoreCase = true)
            else -> null
        }
    }

    /**
     * Execute command function
     */
    private fun executeCmd(cmd: String, args: List<Any?>): Any? {
        val s1 = args.getOrNull(0)?.toString() ?: ""
        val s2 = args.getOrNull(1)?.toString() ?: ""
        val s3 = args.getOrNull(2)?.toString() ?: ""
        
        return when (cmd) {
            // URL operations
            "GET_HOST" -> try { Uri.parse(s1).host } catch (e: Exception) { null }
            "GET_PATH" -> try { Uri.parse(s1).path } catch (e: Exception) { null }
            "GET_PARAM" -> try { Uri.parse(s1).getQueryParameter(s2) } catch (e: Exception) { null }
            
            // String operations
            "UPPER" -> s1.uppercase()
            "LOWER" -> s1.lowercase()
            "TRIM" -> s1.trim()
            "LENGTH" -> s1.length
            "REPLACE" -> s1.replace(s2, s3)
            "SUBSTRING" -> {
                val start = args.getOrNull(1)?.toString()?.toIntOrNull() ?: 0
                val end = args.getOrNull(2)?.toString()?.toIntOrNull() ?: s1.length
                s1.substring(start.coerceIn(0, s1.length), end.coerceIn(start, s1.length))
            }
            
            else -> null
        }
    }
}
