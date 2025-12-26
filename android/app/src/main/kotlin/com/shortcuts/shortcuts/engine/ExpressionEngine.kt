package com.shortcuts.shortcuts.engine

import android.net.Uri
import android.util.Log

/**
 * ExpressionEngine v2.2 - 高可靠性 DSL 解析器
 * 支持：变量解析、数值计算、字符串插值、逻辑运算、内置指令
 */
object ExpressionEngine {

    private const val TAG = "ExpressionEngine"

    /**
     * 主入口：评估表达式
     * 无论发生什么错误，都会返回一个值或 null，不会抛出异常
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

    /**
     * 内部解析逻辑
     */
    private fun innerEvaluate(raw: String, cm: ContextManager): Any? {
        // 1. 处理低优先级逻辑运算符 (?:, ||, &&)
        if (raw.contains("?:")) {
            val p = splitByFirstOp(raw, "?:")
            val l = innerEvaluate(p[0], cm)
            return if (isTruthy(l)) l else innerEvaluate(p[1], cm)
        }
        if (raw.contains("||")) {
            return raw.split("||").any { isTruthy(innerEvaluate(it, cm)) }
        }
        if (raw.contains("&&")) {
            val parts = raw.split("&&")
            if (parts.isEmpty()) return false
            return parts.all { isTruthy(innerEvaluate(it, cm)) }
        }

        // 2. 分词 (支持无空格写法，如 $res.status==200)
        val tokens = tokenize(raw)
        if (tokens.isEmpty()) return null

        // 3. 变量与字面量解析
        val resolved = tokens.map { resolveToken(it, cm) }

        // 4. 单目运算符处理 (取反 !)
        if (resolved.size >= 2 && resolved[0] == "!") {
            return !isTruthy(resolved[1])
        }

        // 5. 隐式字符串拼接 (例如: "Code: " $res.status)
        val merged = mutableListOf<Any?>()
        for (item in resolved) {
            if (merged.isNotEmpty() && !isControlToken(item) && !isControlToken(merged.last())) {
                val last = merged.removeAt(merged.size - 1)
                merged.add(last.toString() + item.toString())
            } else {
                merged.add(item)
            }
        }

        if (merged.isEmpty()) return null

        // 6. 中缀运算符 ($a == $b, $a + $b)
        if (merged.size >= 3 && isInfixOp(merged[1])) {
            return executeInfix(merged[0], merged[1].toString().uppercase(), merged[2])
        }

        // 7. 指令/函数执行 (UPPER $var)
        val first = merged[0].toString()
        if (isInstruction(first)) {
            return executeCmd(first.uppercase(), merged.drop(1))
        }

        return merged[0]
    }

    /**
     * 分词器：通过正则提取变量、字符串、数字、运算符
     */
    private fun tokenize(input: String): List<String> {
        // 修改点：将 \w 扩展为 [a-zA-Z0-9_-]，并确保变量名匹配更健壮
        val regex = Regex("""("[^"]*"|==|!=|>=|<=|\?\:|&&|\|\||[+\-*/=<>!&|?:]|\$?[a-zA-Z_][a-zA-Z0-9_-]*(\.[a-zA-Z0-9_-]+)*)""")
        return regex.findAll(input).map { it.value }.toList()
    }

    /**
     * 解析 Token 为实际对象
     */
    private fun resolveToken(token: String, cm: ContextManager): Any? {
        return when {
            token.startsWith("$") -> resolveVariable(token.substring(1), cm)
            token.startsWith("\"") -> cm.interpolate(token.trim('"'))
            token == "true" -> true
            token == "false" -> false
            token == "null" -> null
            // 重点：将所有数字字面量统一转为 Double 方便后续比较
            token.matches(Regex("""^-?\d+(\.\d+)?$""")) -> token.toDoubleOrNull()
            else -> token // 操作符、指令名等
        }
    }

    /**
     * 深度解析变量路径，支持 Map
     */
    private fun resolveVariable(path: String, cm: ContextManager): Any? {
        val parts = path.split(".")
        var current: Any? = cm.context[parts[0]]
        for (i in 1 until parts.size) {
            if (current == null) return null
            current = if (current is Map<*, *>) current[parts[i]] else null
        }
        return current
    }

    /**
     * 核心：执行比较和运算
     */
    private fun executeInfix(l: Any?, op: String, r: Any?): Any? {
        // 数值标准化：尝试将左右两边都转为 Double
        val nL = (l as? Number)?.toDouble() ?: l?.toString()?.toDoubleOrNull()
        val nR = (r as? Number)?.toDouble() ?: r?.toString()?.toDoubleOrNull()
        val isNumeric = nL != null && nR != null

        val sL = l?.toString() ?: ""
        val sR = r?.toString() ?: ""

        return when (op) {
            "==" -> if (isNumeric) nL == nR else sL == sR
            "!=" -> if (isNumeric) nL != nR else sL != sR
            ">"  -> if (isNumeric) nL!! > nR!! else false
            "<"  -> if (isNumeric) nL!! < nR!! else false
            ">=" -> if (isNumeric) nL!! >= nR!! else false
            "<=" -> if (isNumeric) nL!! <= nR!! else false
            "+"  -> if (isNumeric) nL!! + nR!! else sL + sR
            "-"  -> if (isNumeric) nL!! - nR!! else 0.0
            "*"  -> if (isNumeric) nL!! * nR!! else 0.0
            "/"  -> if (isNumeric && nR != 0.0) nL!! / nR!! else 0.0
            "CONTAINS" -> sL.contains(sR, ignoreCase = true)
            "STARTS_WITH" -> sL.startsWith(sR, ignoreCase = true)
            "ENDS_WITH" -> sL.endsWith(sR, ignoreCase = true)
            else -> null
        }
    }

    /**
     * 判断真值
     */
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

    private fun isInfixOp(t: Any?): Boolean {
        val s = t?.toString()?.uppercase() ?: return false
        return s in listOf("==", "!=", "CONTAINS", "STARTS_WITH", "ENDS_WITH", "+", "-", "*", "/", ">", "<", ">=", "<=")
    }

    private fun isInstruction(t: Any?): Boolean {
        val s = t?.toString()?.uppercase() ?: return false
        return s in listOf("GET_HOST", "GET_PARAM", "GET_PATH", "REPLACE", "UPPER", "LOWER", "TRIM", "LENGTH", "SUBSTRING", "EXTRACT")
    }

    private fun splitByFirstOp(raw: String, op: String): List<String> {
        val idx = raw.indexOf(op)
        if (idx == -1) return listOf(raw, "")
        return listOf(raw.substring(0, idx).trim(), raw.substring(idx + op.length).trim())
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
                val target = s1
                val separator = if (s2.isNotEmpty()) s2 else ";"
                val kvSeparator = if (s3.isNotEmpty()) s3 else "="
                val result = mutableMapOf<String, Any?>()

                target.split(separator).forEach { chunk ->
                    if (chunk.isBlank()) return@forEach
                    val parts = chunk.split(kvSeparator, limit = 2)
                    if (parts.size == 2) {
                        val key = parts[0].trim().trim('"')
                        val rawValue = parts[1].trim()

                        val value: Any? = when {
                            rawValue == "true" -> true
                            rawValue == "false" -> false
                            rawValue == "null" -> null
                            rawValue.matches(Regex("""^-?\d+(\.\d+)?$""")) -> {
                                val d = rawValue.toDoubleOrNull()
                                if (d != null && d % 1.0 == 0.0) d.toLong() else d
                            }
                            rawValue.startsWith("\"") && rawValue.endsWith("\"") -> rawValue.trim('"')
                            else -> rawValue
                        }
                        result[key] = value
                    }
                }
                result
            }
            else -> null
        }
    }
}