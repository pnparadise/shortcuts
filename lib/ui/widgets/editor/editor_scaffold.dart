import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import 'expression_assistant.dart';

class EditorSheetScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final VoidCallback? onSave;
  final String saveLabel;
  final PreferredSizeWidget? bottom;
  final double heightFactor;
  final bool centerTitle;

  const EditorSheetScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onSave,
    this.saveLabel = 'Save',
    this.bottom,
    this.heightFactor = 0.85,
    this.centerTitle = false,
  });

  @override
  State<EditorSheetScaffold> createState() => _EditorSheetScaffoldState();
}

class _EditorSheetScaffoldState extends State<EditorSheetScaffold> {
  final ExpressionAssistantController _assistantController = ExpressionAssistantController();
  @override
  void initState() {
    super.initState();
    _assistantController.addListener(_onAssistantChange);
  }

  @override
  void dispose() {
    _assistantController.removeListener(_onAssistantChange);
    _assistantController.dispose();
    super.dispose();
  }

  void _onAssistantChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: widget.heightFactor,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: ExpressionAssistantScope(
          controller: _assistantController,
          child: Scaffold(
            backgroundColor: AppColors.scaffoldBg,
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              backgroundColor: AppColors.cardBg,
              elevation: 0,
              centerTitle: widget.centerTitle,
              leading: IconButton(
                icon: const Icon(Icons.close, color: AppColors.textBody),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                widget.title,
                style: AppStyles.headerStyle,
              ),
              actions: [
                if (widget.onSave != null)
                  TextButton(
                    onPressed: widget.onSave,
                    child: Text(
                      widget.saveLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
              bottom: widget.bottom,
            ),
            body: Column(
              children: [
                Expanded(child: widget.body),
                if (_assistantController.isActive)
                  _assistantController.buildPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


