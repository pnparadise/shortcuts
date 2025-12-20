import 'package:flutter/material.dart' hide Action;
import '../../models.dart';
import '../../theme.dart';
import '../variable_picker.dart';
import 'editor_ui.dart';

class CommonSheets {

  static void showIfEditor(BuildContext context, IfAction action, ValueChanged<IfAction> onSave) {
    _showSheet(context, (ctx) => _IfEditor(action: action, onSave: onSave));
  }

  static void showToastEditor(BuildContext context, ToastAction action, ValueChanged<ToastAction> onSave) {
    _showSheet(context, (ctx) => _ToastEditor(action: action, onSave: onSave));
  }
  
  static void showSetViewEditor(BuildContext context, SetViewAction action, ValueChanged<SetViewAction> onSave) {
      _showSheet(context, (ctx) => _SetViewEditor(action: action, onSave: onSave));
  }

  static void _showSheet(BuildContext context, WidgetBuilder childBuilder) {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => childBuilder(ctx),
      );
  }
}

// ---------------------------------------------------------------------------
// IF EDITOR
// ---------------------------------------------------------------------------
class _IfEditor extends StatefulWidget {
  final IfAction action;
  final ValueChanged<IfAction> onSave;
  const _IfEditor({required this.action, required this.onSave});
  @override
  State<_IfEditor> createState() => _IfEditorState();
}

class _IfEditorState extends State<_IfEditor> {
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

// ---------------------------------------------------------------------------
// TOAST EDITOR
// ---------------------------------------------------------------------------
class _ToastEditor extends StatefulWidget {
  final ToastAction action;
  final ValueChanged<ToastAction> onSave;
  const _ToastEditor({required this.action, required this.onSave});
  @override
  State<_ToastEditor> createState() => _ToastEditorState();
}

class _ToastEditorState extends State<_ToastEditor> {
  late TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.action.messageTemplate);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(ToastAction(messageTemplate: _ctl.text));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
      return EditorSheetScaffold(
          title: "Configure Toast",
          onSave: _save,
          body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                  EditorSection(
                      title: "Message Template",
                      hint: "Supports variables like {{res.data.message}}.",
                      child: TextField(
                          controller: _ctl,
                          maxLines: 4,
                          decoration: editorInputDecoration(
                              hintText: "Operation successful!",
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
              ],
          ),
      );
  }
}

// ---------------------------------------------------------------------------
// SET VIEW EDITOR
// ---------------------------------------------------------------------------
class _SetViewEditor extends StatefulWidget {
  final SetViewAction action;
  final ValueChanged<SetViewAction> onSave;
  const _SetViewEditor({required this.action, required this.onSave});
  @override
  State<_SetViewEditor> createState() => _SetViewEditorState();
}

class _SetViewEditorState extends State<_SetViewEditor> {
  late TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.action.textTemplate);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(SetViewAction(textTemplate: _ctl.text));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
      return EditorSheetScaffold(
          title: "Configure View",
          onSave: _save,
          body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                  EditorSection(
                      title: "View Content",
                      hint: "Markdown or plain text. Use variables like {{res.status}}.",
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              SizedBox(
                                  height: 220,
                                  child: TextField(
                                      controller: _ctl,
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: editorInputDecoration(
                                          hintText: "# Dashboard\nStatus: {{res.status}}",
                                      ),
                                  ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                      icon: const Icon(Icons.data_object, size: 18),
                                      label: const Text("Insert Variable"),
                                      onPressed: () => VariablePicker.show(
                                          context,
                                          onSelect: (v) => _insertAtCursor(_ctl, v),
                                      ),
                                  ),
                              ),
                          ],
                      ),
                  ),
              ],
          ),
      );
  }
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
