import 'package:flutter/material.dart';
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/editor/editor_scaffold.dart';
import '../widgets/editor/editor_section.dart';
import '../widgets/editor/editor_input.dart';
import '../screens/dsl_wiki_screen.dart';

/// Expression editor with multi-line DSL input and auto-completion.
/// Uses the reusable EditorTextField component with DSL mode enabled.
class ExpressionEditor extends StatefulWidget {
  final ExpressionAction action;
  final ValueChanged<ExpressionAction> onSave;
  
  const ExpressionEditor({super.key, required this.action, required this.onSave});

  static void show(BuildContext context, ExpressionAction action, ValueChanged<ExpressionAction> onSave) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ExpressionEditor(action: action, onSave: onSave),
    );
  }

  @override
  State<ExpressionEditor> createState() => _ExpressionEditorState();
}

class _ExpressionEditorState extends State<ExpressionEditor> {
  late TextEditingController _scriptCtl;

  @override
  void initState() {
    super.initState();
    _scriptCtl = TextEditingController(text: widget.action.script);
  }

  @override
  void dispose() {
    _scriptCtl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(widget.action.copyWith(script: _scriptCtl.text));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return EditorSheetScaffold(
      title: "Expression Script",
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          EditorSection(
            title: "DSL Script",
            hint: "Multi-line expression script",
            child: EditorTextField(
              controller: _scriptCtl,
              maxLines: 10,
              hintText: '// 示例\nid = GET_PARAM \$url "id"\nname = UPPER \$res.data.name',
              enableDslInput: true,
              contextVariables: const ['url', 'res', 'res.data', 'res.status', 'item', 'item.id', 'clip'],
            ),
          ),
          const SizedBox(height: 16),
          // Help button
          OutlinedButton.icon(
            onPressed: () => DslWikiScreen.show(context),
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text("DSL 语法参考"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textBody,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}

