import 'package:flutter/material.dart';
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/editor/editor_input.dart';
import '../widgets/editor/editor_scaffold.dart';
import '../widgets/editor/editor_section.dart';
import '../screens/dsl_wiki_screen.dart';

class ConditionEditor extends StatefulWidget {
  final IfAction action;
  final ValueChanged<IfAction> onSave;
  
  const ConditionEditor({super.key, required this.action, required this.onSave});
  
  static void show(BuildContext context, IfAction action, ValueChanged<IfAction> onSave) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ConditionEditor(action: action, onSave: onSave),
    );
  }

  @override
  State<ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends State<ConditionEditor> {
  late TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.action.conditionExpression);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(IfAction(
      conditionExpression: _ctl.text,
      trueFlow: widget.action.trueFlow,
      falseFlow: widget.action.falseFlow,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
      return EditorSheetScaffold(
          title: "Edit Condition",
          onSave: _save,
          body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                  EditorSection(
                      title: "Condition Expression",
                      hint: "Use variables like \$res.status in expressions.",
                      child: EditorTextField(
                          controller: _ctl,
                          hintText: "\$res.status == 200",
                          enableExpressionInput: true,
                      ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                      onPressed: () => DslWikiScreen.show(context),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('DSL syntax reference'),
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
