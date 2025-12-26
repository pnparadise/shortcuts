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
        elevation: 0,
        centerTitle: false,
        title: const Text('DSL 2.0 Syntax Reference', style: AppStyles.headerStyle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textHeader),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildSection('Variable syntax', [
            _SyntaxItem("\$var", 'Simple variable reference', "\$url, \$id"),
            _SyntaxItem("\$obj.prop", 'Nested property access', "\$res.data.name"),
            _SyntaxItem("\"text \$var\"", 'String interpolation', "\"id=\$id\""),
          ]),
          _buildSection('Literals', [
            _SyntaxItem("true / false", 'Boolean', ''),
            _SyntaxItem('null', 'Null', ''),
            _SyntaxItem('123.4', 'Number', ''),
            _SyntaxItem("\"text\"", 'String', "\"hello world\""),
          ]),
          _buildSection('Logical operators', [
            _SyntaxItem("?:", 'Elvis (null fallback)', "\$url ?: \"default\""),
            _SyntaxItem("||", 'Logical OR', "\$a || \$b"),
            _SyntaxItem("&&", 'Logical AND', "\$a && \$b"),
            _SyntaxItem("!", 'Not', "! \$error"),
          ]),
          _buildSection('Comparison operators', [
            _SyntaxItem("==", 'Equals', "\$status == 200"),
            _SyntaxItem("!=", 'Not equals', "\$type != \"error\""),
            _SyntaxItem("> / <", 'Greater / less than', "\$count > 0"),
            _SyntaxItem(">= / <=", 'Greater or equal / less or equal', "\$age >= 18"),
          ]),
          _buildSection('String operators', [
            _SyntaxItem("CONTAINS", 'Contains', "\$url CONTAINS \"taobao\""),
            _SyntaxItem("STARTS_WITH", 'Starts with', "\$name STARTS_WITH \"A\""),
            _SyntaxItem("ENDS_WITH", 'Ends with', "\$file ENDS_WITH \".jpg\""),
            _SyntaxItem("+", 'Concatenate', "\$a + \$b or implicit concat \$a \$b"),
          ]),
          _buildSection('Arithmetic operators', [
            _SyntaxItem("+", 'Addition', "\$a + \$b"),
            _SyntaxItem("-", 'Subtraction', "\$a - \$b"),
            _SyntaxItem("*", 'Multiplication', "\$a * \$b"),
            _SyntaxItem("/", 'Division', "\$a / \$b"),
          ]),
          _buildSection('URL functions', [
            _SyntaxItem("GET_HOST", 'Get host', "GET_HOST \$url"),
            _SyntaxItem("GET_PATH", 'Get path', "GET_PATH \$url"),
            _SyntaxItem("GET_PARAM", 'Get param', "GET_PARAM \$url \"id\""),
          ]),
          _buildSection('String functions', [
            _SyntaxItem("UPPER", 'Uppercase', "UPPER \$text"),
            _SyntaxItem("LOWER", 'Lowercase', "LOWER \$text"),
            _SyntaxItem("TRIM", 'Trim', "TRIM \$text"),
            _SyntaxItem("LENGTH", 'Length', "LENGTH \$text"),
            _SyntaxItem("REPLACE", 'Replace', "REPLACE \$text \"old\" \"new\""),
            _SyntaxItem("SUBSTRING", 'Substring', "SUBSTRING \$text 0 5"),
            _SyntaxItem("EXTRACT", 'Extract key-value to JSON', "EXTRACT \$str \";\" \"=\""),
          ]),
          _buildSection('Expression examples', [
            _SyntaxItem('Assignment', 'Assign expression result to a variable', "\$id = GET_PARAM \$url \"id\""),
            _SyntaxItem('Concatenate', 'Build a new string', "\$link = \"https://tb.cn/\" \$id"),
            _SyntaxItem('Calculation', 'Numeric calculation', "\$total = \$price * \$count"),
          ]),
          _buildSection('If condition examples', [
            _SyntaxItem('Status check', 'Check a success status', "\$res.status == 200"),
            _SyntaxItem('Multiple conditions', 'Combine with OR', "\$url CONTAINS \"taobao\" || \$url CONTAINS \"tmall\""),
            _SyntaxItem('Null check', 'Guard against empty values', "\$data && ! \$error"),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_SyntaxItem> items) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      rows.add(_buildSyntaxRow(items[i]));
      if (i != items.length - 1) {
        rows.add(const SizedBox(height: 10));
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(children: rows),
        ],
      ),
    );
  }

  Widget _buildSyntaxRow(_SyntaxItem item) {
    return Container(
      color: const Color(0xFFF5F9FF),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 112,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            color: const Color(0xFFE2EEFF),
            child: Center(
              child: Text(
                item.syntax,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
