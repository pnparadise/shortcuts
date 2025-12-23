import 'package:flutter/material.dart' hide Action;
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/editor/editor_input.dart';
import '../widgets/pickers/app_picker.dart';
import '../widgets/editor/editor_scaffold.dart';
import '../widgets/editor/editor_section.dart';

import '../widgets/editor/key_value_editor.dart';

class IntentEditorSheet extends StatefulWidget {
  final IntentAction action;
  final ValueChanged<IntentAction> onSave;

  const IntentEditorSheet({super.key, required this.action, required this.onSave});

  static void show(BuildContext context, IntentAction action, ValueChanged<IntentAction> onSave) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IntentEditorSheet(action: action, onSave: onSave),
    );
  }

  @override
  State<IntentEditorSheet> createState() => _IntentEditorSheetState();
}

class _IntentEditorSheetState extends State<IntentEditorSheet> {
  late TextEditingController _packageCtl;
  late TextEditingController _classCtl;
  late TextEditingController _dataUriCtl;
  late Map<String, String> _extras;

  @override
  void initState() {
    super.initState();
    _packageCtl = TextEditingController(text: widget.action.packageName);
    _classCtl = TextEditingController(text: widget.action.className ?? "");
    _dataUriCtl = TextEditingController(text: widget.action.dataUri);
    _extras = Map.from(widget.action.extras);
  }

  @override
  void dispose() {
    _packageCtl.dispose();
    _classCtl.dispose();
    _dataUriCtl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(widget.action.copyWith(
      action: widget.action.action, 
      packageName: _packageCtl.text,
      className: _classCtl.text.isEmpty ? null : _classCtl.text,
      dataUri: _dataUriCtl.text,
      extras: _extras,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return EditorSheetScaffold(
      title: "Intent Jump",
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EditorSection(
            title: "Package Name",
            child: Row(
              children: [
                Expanded(
                    child: EditorTextField(
                      controller: _packageCtl,
                      hintText: "com.example.app",
                    ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.apps),
                  onPressed: () async {
                    final app = await AppPicker.show(context);
                    if (app != null) {
                      setState(() {
                         _packageCtl.text = app['packageName']!;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          EditorSection(
            title: "Class Name (Optional)",
            child: EditorTextField(
              controller: _classCtl,
              hintText: "com.example.app.MainActivity",
            ),
          ),
          EditorSection(
            title: "Data URI (e.g. https://..., tel:10086, taobao://...)",
            child: EditorTextField(
              controller: _dataUriCtl,
              hintText: "taobao://m.taobao.com/",
            ),
          ),
          EditorSection(
            title: "Extras (Parameters)",
            child: KeyValueEditor(
              items: _extras,
              onChanged: (val) => setState(() => _extras = val),
              keyLabel: "Extra Key",
              valueLabel: "Value",
            ),
          ),
        ],
      ),
    );
  }
}

