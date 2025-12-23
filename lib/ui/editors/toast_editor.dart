import 'package:flutter/material.dart';
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/pickers/variable_picker.dart';
import '../widgets/editor/editor_scaffold.dart';
import '../widgets/editor/editor_section.dart';

import '../widgets/editor/editor_input.dart';

class ToastEditor extends StatefulWidget {
  final ToastAction action;
  final ValueChanged<ToastAction> onSave;
  const ToastEditor({super.key, required this.action, required this.onSave});

  static void show(BuildContext context, ToastAction action, ValueChanged<ToastAction> onSave) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ToastEditor(action: action, onSave: onSave),
    );
  }

  @override
  State<ToastEditor> createState() => _ToastEditorState();
}

class _ToastEditorState extends State<ToastEditor> {
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
          title: "Configure Toast",
          onSave: _save,
          body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                  EditorSection(
                      title: "Message Template",
                      hint: "Supports variables like {{res.data.message}}.",
                      child: EditorTextField(
                          controller: _ctl,
                          maxLines: 4,
                          hintText: "Operation successful!",
                      ),
                  ),
              ],
          ),
      );
  }
}
