import 'package:flutter/material.dart' hide Action;
import '../../models.dart';
import '../../theme.dart';
import '../variable_picker.dart';

class CommonSheets {

  static void showIfEditor(BuildContext context, IfAction action, ValueChanged<IfAction> onSave) {
    _showSheet(context, "Configure Logic", (ctx) => _IfEditor(action: action, onSave: onSave));
  }

  static void showToastEditor(BuildContext context, ToastAction action, ValueChanged<ToastAction> onSave) {
    _showSheet(context, "Configure Toast", (ctx) => _ToastEditor(action: action, onSave: onSave));
  }
  
  static void showSetViewEditor(BuildContext context, SetViewAction action, ValueChanged<SetViewAction> onSave) {
      _showSheet(context, "Configure View", (ctx) => _SetViewEditor(action: action, onSave: onSave));
  }

  static void _showSheet(BuildContext context, String title, WidgetBuilder childBuilder) {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.cardBg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (ctx) => FractionallySizedBox(
              heightFactor: 0.8,
              child: Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(icon: const Icon(Icons.close, color: AppColors.textBody), onPressed: () => Navigator.pop(ctx)),
                      title: Text(title, style: const TextStyle(color: AppColors.textHeader, fontSize: 16)),
                  ),
                  body: childBuilder(ctx),
              ),
          ),
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
  Widget build(BuildContext context) {
      return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  const Text("Condition Expression", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _ctl,
                      decoration: InputDecoration(
                          hintText: "{{res.status}} == 200",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: IconButton(
                              icon: const Icon(Icons.data_object, color: AppColors.primary),
                              onPressed: () => VariablePicker.show(context, onSelect: (v) => _ctl.text = v), // Simple replace for now
                          ),
                      ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                      spacing: 8,
                      children: ["==", "!=", ">", "<", "&&", "||"].map((op) => ActionChip(
                          label: Text(op),
                          onPressed: () => _ctl.text = _ctl.text + " $op ",
                      )).toList(),
                  ),
                  const Spacer(),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(16)),
                      onPressed: () {
                          widget.onSave(IfAction(
                              conditionExpression: _ctl.text,
                              trueFlow: widget.action.trueFlow,
                              falseFlow: widget.action.falseFlow,
                          ));
                          Navigator.pop(context);
                      },
                      child: const Text("Save"),
                  )
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
  Widget build(BuildContext context) {
      return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  const Text("Message Template", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _ctl,
                      maxLines: 3,
                      decoration: InputDecoration(
                          hintText: "Operation successful!",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: IconButton(
                              icon: const Icon(Icons.data_object, color: AppColors.primary),
                              onPressed: () => VariablePicker.show(context, onSelect: (v) => _ctl.text += v),
                          ),
                      ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(16)),
                      onPressed: () {
                          widget.onSave(ToastAction(messageTemplate: _ctl.text));
                          Navigator.pop(context);
                      },
                      child: const Text("Save"),
                  )
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
  Widget build(BuildContext context) {
      return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  const Text("View Content (Markdown/Text)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                      child: TextField(
                          controller: _ctl,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                              hintText: "# Dashboard\nStatus: {{res.status}}",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                      ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                          icon: const Icon(Icons.data_object),
                          label: const Text("Insert Variable"),
                          onPressed: () => VariablePicker.show(context, onSelect: (v) => _ctl.text += v),
                      ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.all(16)),
                      onPressed: () {
                          widget.onSave(SetViewAction(textTemplate: _ctl.text));
                          Navigator.pop(context);
                      },
                      child: const Text("Save"),
                  )
              ],
          ),
      );
  }
}
