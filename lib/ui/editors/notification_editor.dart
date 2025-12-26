import 'package:flutter/material.dart';
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/editor/editor_input.dart';
import '../widgets/editor/editor_scaffold.dart';
import '../widgets/editor/editor_section.dart';

class NotificationEditor extends StatefulWidget {
  final NotificationAction action;
  final ValueChanged<NotificationAction> onSave;
  
  const NotificationEditor({super.key, required this.action, required this.onSave});

  static void show(BuildContext context, NotificationAction action, ValueChanged<NotificationAction> onSave) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => NotificationEditor(action: action, onSave: onSave),
    );
  }

  @override
  State<NotificationEditor> createState() => _NotificationEditorState();
}

class _NotificationEditorState extends State<NotificationEditor> {
  late TextEditingController _titleCtl;
  late TextEditingController _messageCtl;

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget.action.title);
    _messageCtl = TextEditingController(text: widget.action.message);
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _messageCtl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(widget.action.copyWith(
      title: _titleCtl.text,
      message: _messageCtl.text,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
      return EditorSheetScaffold(
          title: "Configure Notification",
          onSave: _save,
          body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                          'Please allow notification permission to show alerts.',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                  ),
                  EditorSection(
                      title: "Title",
                      hint: "Notification title (supports variables)",
                      child: EditorTextField(
                          controller: _titleCtl,
                          hintText: "Task Complete",
                          enableExpressionInput: true,
                      ),
                  ),
                  EditorSection(
                      title: "Message",
                      hint: "Notification body (supports variables)",
                      child: EditorTextField(
                          controller: _messageCtl,
                          lines: 3,
                          hintText: "Your task has been completed successfully.",
                          enableExpressionInput: true,
                      ),
                  ),
              ],
          ),
      );
  }
}
