package com.shortcuts.shortcuts.engine

import android.net.Uri
import android.util.Log
import java.util.*

/**
 * ExpressionEngine v3.5 - 高可靠性双栈 DSL 解析器
 * 支持：复杂括号嵌套优先级、四则运算、变量中划线、隐式字符串拼接
 */
object ExpressionEngine {

    private const val TAG = "ExpressionEngine"

    /**
     * 主入口：评估表达式
     */
    fun evaluate(expr: String?, cm: ContextManager): Any? {
        return try {
            val raw = expr?.trim() ?: return null
            if (raw.isEmpty()) return null
            innerEvaluate(raw, cm)
        } catch (e: Exception) {
            Log.e(TAG, "Evaluate Error: [expr: $expr] -> ${e.message}")
            null
        }
    }

    private fun innerEvaluate(raw: String, cm: ContextManager): Any? {
        // 1. 分词
        val tokens = tokenize(raw)
        if (tokens.isEmpty()) return null

        // 2. 预处理：解析变量/字面量 & 处理内置指令
        val resolved = mutableListOf<Any?>()
        var i = 0
        while (i < tokens.size) {
            val token = tokens[i]
            if (isInstruction(token)) {
                // 处理指令参数：抓取指令后直到遇到下一个控制符或括号之前的全部 token
                val args = mutableListOf<Any?>()
                var j = i + 1
                while (j < tokens.size && !isControlToken(tokens[j]) && tokens[j] != "(" && tokens[j] != ")") {
                    args.add(resolveToken(tokens[j], cm))
                    j++
                }
                resolved.add(executeCmd(token.uppercase(), args))
                i = j
            } else {
                resolved.add(resolveToken(token, cm))
                i++
            }
        }

        // 3. 隐式字符串拼接 (例如: "流量: " $res.status)
        val merged = mutableListOf<Any?>()
        for (item in resolved) {
            if (merged.isNotEmpty() && 
                !isControlToken(item) && item != "(" && item != ")" && 
                !isControlToken(merged.last()) && merged.last() != "(" && merged.last() != ")") {
                val last = merged.removeAt(merged.size - 1)
                merged.add(last.toString() + item.toString())
            } else {
                merged.add(item)
            }
        }

        // 4. 双栈求值 (调度场算法)
        return computeStack(merged)
    }

    /**
     * 增强分词器：修复了减号转义和括号拆分问题
     */
    private fun tokenize(input: String): List<String> {
        // 顺序极其重要：字符串 > 双字节符 > 数字 > 括号 > 变量(含连字符) > 单字节符
        val regex = Regex("""("[^"]*"|==|!=|>=|<=|\?\:|&&|\|\||\d+(\.\d+)?|\(|\)|\$?[a-zA-Z_][a-zA-Z0-9_-]*(\.[a-zA-Z0-9_-]+)*|[\+\-\*/=<>!&|?:])""")
        return regex.findAll(input).map { it.value }.toList()
    }

    private fun resolveToken(token: String, cm: ContextManager): Any? {
        if (isControlToken(token) || token == "(" || token == ")") return token
        return when {
            token.startsWith("$") -> resolveVariable(token.substring(1), cm)
            token.startsWith("\"") -> cm.interpolate(token.trim('"'))
            token == "true" -> true
            token == "false" -> false
            token == "null" -> null
            token.matches(Regex("""^-?\d+(\.\d+)?$""")) -> token.toDoubleOrNull()
            else -> token
        }
    }

    /**
     * 双栈求值逻辑 (操作数栈 + 操作符栈)
     */
    private fun computeStack(tokens: List<Any?>): Any? {
        val values = Stack<Any?>()
        val ops = Stack<String>()

        fun applyOp() {
            if (values.size < 2 || ops.isEmpty()) return
            val r = values.pop()
            val l = values.pop()
            val op = ops.pop()
            values.push(executeInfix(l, op, r))
        }

        for (token in tokens) {
            when (token) {
                null -> values.push(null)
                "(" -> ops.push("(")
                ")" -> {
                    while (ops.isNotEmpty() && ops.peek() != "(") applyOp()
                    if (ops.isNotEmpty() && ops.peek() == "(") ops.pop()
                }
                is String -> {
                    if (isInfixOp(token)) {
                        while (ops.isNotEmpty() && ops.peek() != "(" && precedence(ops.peek()) >= precedence(token)) {
                            applyOp()
                        }
                        ops.push(token)
                    } else {
                        values.push(token)
                    }
                }
                else -> values.push(token)
            }
        }

        while (ops.isNotEmpty()) {
            if (ops.peek() == "(") { ops.pop(); continue }
            applyOp()
        }
        return if (values.isNotEmpty()) values.peek() else null
    }

    private fun precedence(op: String): Int = when (op.uppercase()) {
        "||", "?:" -> 1
        "&&" -> 2
        "==", "!=" -> 3
        ">", "<", ">=", "<=" -> 4
        "+", "-" -> 5
        "*", "/" -> 6
        else -> 0
    }

    private fun executeInfix(l: Any?, op: String, r: Any?): Any? {
        val nL = (l as? Number)?.toDouble() ?: l?.toString()?.toDoubleOrNull()
        val nR = (r as? Number)?.toDouble() ?: r?.toString()?.toDoubleOrNull()
        val isNumeric = nL != null && nR != null

        val sL = l?.toString() ?: ""
        val sR = r?.toString() ?: ""

        return when (op.uppercase()) {
            "==" -> if (isNumeric) nL == nR else sL == sR
            "!=" -> if (isNumeric) nL != nR else sL != sR
            ">"  -> if (isNumeric) nL!! > nR!! else false
            "<"  -> if (isNumeric) nL!! < nR!! else false
            ">=" -> if (isNumeric) nL!! >= nR!! else false
            "<=" -> if (isNumeric) nL!! <= nR!! else false
            "+" -> if (isNumeric) nL!! + nR!! else l.toString() + r.toString()
            "-" -> if (isNumeric) nL!! - nR!! else 0.0
            "*" -> if (isNumeric) nL!! * nR!! else 0.0
            "/" -> if (isNumeric && nR != 0.0) nL!! / nR!! else 0.0
            "&&" -> isTruthy(l) && isTruthy(r)
            "||" -> isTruthy(l) || isTruthy(r)
            "?:" -> if (isTruthy(l)) l else r
            "CONTAINS" -> sL.contains(sR, ignoreCase = true)
            "STARTS_WITH" -> sL.startsWith(sR, ignoreCase = true)
            "ENDS_WITH" -> sL.endsWith(sR, ignoreCase = true)
            else -> null
        }
    }

    fun isTruthy(v: Any?): Boolean = when (v) {
        null -> false
        is Boolean -> v
        is String -> v.isNotEmpty() && v != "null" && v != "false"
        is Number -> v.toDouble() != 0.0
        is Collection<*> -> v.isNotEmpty()
        else -> true
    }

    private fun isControlToken(t: Any?): Boolean {
        if (t !is String) return false
        return isInfixOp(t) || isInstruction(t) || t in listOf("!", "&&", "||", "?:")
    }

    private fun isInfixOp(t: String): Boolean {
        return t.uppercase() in listOf("==", "!=", "CONTAINS", "STARTS_WITH", "ENDS_WITH", "+", "-", "*", "/", ">", "<", ">=", "<=", "&&", "||", "?:")
    }

    private fun isInstruction(t: String): Boolean {
        return t.uppercase() in listOf("GET_HOST", "GET_PARAM", "GET_PATH", "REPLACE", "UPPER", "LOWER", "TRIM", "LENGTH", "SUBSTRING", "EXTRACT")
    }

    private fun resolveVariable(path: String, cm: ContextManager): Any? {
        val parts = path.split(".")
        var current: Any? = cm.context[parts[0]]
        for (i in 1 until parts.size) {
            if (current is Map<*, *>) {
                current = current[parts[i]]
            } else {
                return null
            }
        }
        return current
    }

    private fun executeCmd(cmd: String, args: List<Any?>): Any? {
        val s1 = args.getOrNull(0)?.toString() ?: ""
        val s2 = args.getOrNull(1)?.toString() ?: ""
        val s3 = args.getOrNull(2)?.toString() ?: ""
        return when (cmd) {
            "GET_HOST" -> try { Uri.parse(s1).host } catch (e: Exception) { null }
            "GET_PATH" -> try { Uri.parse(s1).path } catch (e: Exception) { null }
            "GET_PARAM" -> try { Uri.parse(s1).getQueryParameter(s2) } catch (e: Exception) { null }
            "UPPER" -> s1.uppercase()
            "LOWER" -> s1.lowercase()
            "TRIM" -> s1.trim()
            "LENGTH" -> s1.length
            "REPLACE" -> s1.replace(s2, s3)
            "SUBSTRING" -> {
                val start = args.getOrNull(1)?.toString()?.toIntOrNull() ?: 0
                val end = args.getOrNull(2)?.toString()?.toIntOrNull() ?: s1.length
                try { s1.substring(start.coerceIn(0, s1.length), end.coerceIn(0, s1.length)) } catch (e: Exception) { "" }
            }
            "EXTRACT" -> {
                val result = mutableMapOf<String, Any?>()
                val sep = if (s2.isNotEmpty()) s2 else ";"
                val kvSep = if (s3.isNotEmpty()) s3 else "="
                s1.split(sep).forEach { chunk ->
                    val parts = chunk.split(kvSep, limit = 2)
                    if (parts.size == 2) {
                        val k = parts[0].trim().trim('"')
                        val rv = parts[1].trim()
                        result[k] = when {
                            rv == "true" -> true
                            rv == "false" -> false
                            rv.matches(Regex("""^-?\d+(\.\d+)?$""")) -> rv.toDoubleOrNull()?.let { if (it % 1.0 == 0.0) it.toLong() else it }
                            rv.startsWith("\"") -> rv.trim('"')
                            else -> rv
                        }
                    }
                }
                result
            }
            else -> null
        }
    }
}