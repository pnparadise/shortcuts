import 'package:flutter/material.dart';
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/pickers/variable_picker.dart';
import '../widgets/editor/editor_scaffold.dart';
import '../widgets/editor/editor_section.dart';
import '../widgets/editor/input_decoration.dart';

class ViewEditor extends StatefulWidget {
  final SetViewAction action;
  final ValueChanged<SetViewAction> onSave;
  const ViewEditor({super.key, required this.action, required this.onSave});

  static void show(BuildContext context, SetViewAction action, ValueChanged<SetViewAction> onSave) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ViewEditor(action: action, onSave: onSave),
    );
  }

  @override
  State<ViewEditor> createState() => _ViewEditorState();
}

class _ViewEditorState extends State<ViewEditor> {
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
