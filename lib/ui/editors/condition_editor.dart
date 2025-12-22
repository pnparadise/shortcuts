import 'package:flutter/material.dart';
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/pickers/variable_picker.dart';
import '../widgets/editor/editor_scaffold.dart';
import '../widgets/editor/editor_section.dart';
import '../widgets/editor/input_decoration.dart';

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

  void _insertAtCursor(TextEditingController controller, String text) {
    final selection = controller.selection;
    final currentText = controller.text;
    final newText = selection.baseOffset >= 0
        ? currentText.replaceRange(selection.start, selection.end, text)
        : currentText + text;
    controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
            offset: (selection.baseOffset >= 0 ? selection.start : currentText.length) + text.length),
    );
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
                      hint: "Use variables like {{res.status}} in expressions.",
                      child: TextField(
                          controller: _ctl,
                          style: const TextStyle(fontFamily: "monospace", fontSize: 13),
                          decoration: editorInputDecoration(
                              hintText: "{{res.status}} == 200",
                              suffixIcon: IconButton(
                                  icon: const Icon(Icons.data_object, color: AppColors.primary),
                                  onPressed: () => VariablePicker.show(
                                      context,
                                      onSelect: (v) => _insertAtCursor(_ctl, v),
                                  ),
                              ),
                          ),
                      ),
                  ),
                  EditorSection(
                      title: "Operators",
                      child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ["==", "!=", ">", "<", ">=", "<=", "&&", "||"]
                              .map((op) => ActionChip(
                                  backgroundColor: AppColors.inputBg,
                                  label: Text(op, style: const TextStyle(color: AppColors.textHeader)),
                                  onPressed: () => _ctl.text = "${_ctl.text} $op ",
                              ))
                              .toList(),
                      ),
                  ),
              ],
          ),
      );
  }
}
