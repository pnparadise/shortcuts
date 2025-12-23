import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// DSL 2.0 Quick Reference Wiki Page
class DslWikiScreen extends StatelessWidget {
  const DslWikiScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DslWikiScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        title: const Text("DSL 2.0 语法参考", style: AppStyles.headerStyle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textHeader),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection("变量语法", [
            _SyntaxItem("\$var", "简单变量引用", "\$url, \$id"),
            _SyntaxItem("\$obj.prop", "嵌套属性访问", "\$res.data.name"),
            _SyntaxItem("\"text \$var\"", "字符串内插值", "\"id=\$id\""),
          ]),
          _buildSection("字面量", [
            _SyntaxItem("true / false", "布尔值", ""),
            _SyntaxItem("null", "空值", ""),
            _SyntaxItem("123.4", "数字", ""),
            _SyntaxItem("\"text\"", "字符串", "\"hello world\""),
          ]),
          _buildSection("逻辑运算符", [
            _SyntaxItem("?:", "Elvis (空值回退)", "\$url ?: \"default\""),
            _SyntaxItem("||", "逻辑或", "\$a || \$b"),
            _SyntaxItem("&&", "逻辑与", "\$a && \$b"),
            _SyntaxItem("!", "取反", "! \$error"),
          ]),
          _buildSection("比较运算符", [
            _SyntaxItem("==", "等于", "\$status == 200"),
            _SyntaxItem("!=", "不等于", "\$type != \"error\""),
            _SyntaxItem("> / <", "大于 / 小于", "\$count > 0"),
            _SyntaxItem(">= / <=", "大于等于 / 小于等于", "\$age >= 18"),
          ]),
          _buildSection("字符串运算符", [
            _SyntaxItem("CONTAINS", "包含", "\$url CONTAINS \"taobao\""),
            _SyntaxItem("STARTS_WITH", "以...开头", "\$name STARTS_WITH \"张\""),
            _SyntaxItem("ENDS_WITH", "以...结尾", "\$file ENDS_WITH \".jpg\""),
            _SyntaxItem("+", "拼接", "\$a + \$b 或隐式拼接 \$a \$b"),
          ]),
          _buildSection("算术运算符", [
            _SyntaxItem("+", "加法", "\$a + \$b"),
            _SyntaxItem("-", "减法", "\$a - \$b"),
            _SyntaxItem("*", "乘法", "\$a * \$b"),
            _SyntaxItem("/", "除法", "\$a / \$b"),
          ]),
          _buildSection("URL 函数", [
            _SyntaxItem("GET_HOST", "获取域名", "GET_HOST \$url"),
            _SyntaxItem("GET_PATH", "获取路径", "GET_PATH \$url"),
            _SyntaxItem("GET_PARAM", "获取参数", "GET_PARAM \$url \"id\""),
          ]),
          _buildSection("字符串函数", [
            _SyntaxItem("UPPER", "转大写", "UPPER \$text"),
            _SyntaxItem("LOWER", "转小写", "LOWER \$text"),
            _SyntaxItem("TRIM", "去空格", "TRIM \$text"),
            _SyntaxItem("LENGTH", "获取长度", "LENGTH \$text"),
            _SyntaxItem("REPLACE", "替换", "REPLACE \$text \"old\" \"new\""),
            _SyntaxItem("SUBSTRING", "截取", "SUBSTRING \$text 0 5"),
          ]),
          _buildSection("Expression 组件示例", [
            _SyntaxItem("赋值", "将表达式结果存入变量", "id = GET_PARAM \$url \"id\""),
            _SyntaxItem("拼接", "构建新字符串", "link = \"https://tb.cn/\" \$id"),
            _SyntaxItem("计算", "数值运算", "total = \$price * \$count"),
          ]),
          _buildSection("If 条件示例", [
            _SyntaxItem("状态判断", "", "\$res.status == 200"),
            _SyntaxItem("多条件", "", "\$url CONTAINS \"taobao\" || \$url CONTAINS \"tmall\""),
            _SyntaxItem("空值检查", "", "\$data && ! \$error"),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_SyntaxItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(title, style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          )),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return _buildSyntaxRow(e.value, isLast);
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSyntaxRow(_SyntaxItem item, bool isLast) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              item.syntax,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.teal,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textBody,
                )),
                if (item.example.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.example, style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyntaxItem {
  final String syntax;
  final String description;
  final String example;

  _SyntaxItem(this.syntax, this.description, this.example);
}
