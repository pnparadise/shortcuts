import 'package:flutter/material.dart' hide Action;
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/pickers/variable_picker.dart';
import '../widgets/editor/editor_scaffold.dart';
import '../widgets/editor/editor_section.dart';

import '../widgets/editor/editor_input.dart';

class ClipboardEditorSheet extends StatefulWidget {
  final ClipboardAction action;
  final ValueChanged<ClipboardAction> onSave;

  const ClipboardEditorSheet({super.key, required this.action, required this.onSave});

  static void show(BuildContext context, ClipboardAction action, ValueChanged<ClipboardAction> onSave) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipboardEditorSheet(action: action, onSave: onSave),
    );
  }

  @override
  State<ClipboardEditorSheet> createState() => _ClipboardEditorSheetState();
}

class _ClipboardEditorSheetState extends State<ClipboardEditorSheet> {
  late String _mode;
  late TextEditingController _targetCtl;
  late TextEditingController _textCtl;

  @override
  void initState() {
    super.initState();
    _mode = widget.action.mode;
    _targetCtl = TextEditingController(text: widget.action.targetVar);
    _textCtl = TextEditingController(text: widget.action.textTemplate);
  }

  @override
  void dispose() {
    _targetCtl.dispose();
    _textCtl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(widget.action.copyWith(
      mode: _mode,
      targetVar: _targetCtl.text.isEmpty ? 'clip' : _targetCtl.text,
      textTemplate: _textCtl.text,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return EditorSheetScaffold(
      title: "Clipboard Action",
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EditorSection(
            title: "Operation Mode",
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'READ', label: Text("Read"), icon: Icon(Icons.download_rounded)),
                ButtonSegment(value: 'WRITE', label: Text("Write"), icon: Icon(Icons.upload_rounded)),
              ],
              selected: {_mode},
              onSelectionChanged: (val) => setState(() => _mode = val.first),
            ),
          ),
          if (_mode == 'READ')
            EditorSection(
              title: "Target Variable",
              hint: "Store clipboard content into: {{var}}",
              child: EditorTextField(
                controller: _targetCtl,
                hintText: "e.g. clip_data",
              ),
            ),
          if (_mode == 'WRITE')
            EditorSection(
              title: "Text Template",
              hint: "Text to write to clipboard. Supports variables.",
              child: EditorTextField(
                  controller: _textCtl,
                  maxLines: 3,
                  hintText: "Enter text or {{var}}",
              ),
            ),
        ],
      ),
    );
  }
}
