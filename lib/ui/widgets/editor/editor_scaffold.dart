import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class EditorSheetScaffold extends StatelessWidget {
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
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Scaffold(
          backgroundColor: AppColors.cardBg,
          appBar: AppBar(
            backgroundColor: AppColors.cardBg,
            elevation: 0,
            centerTitle: centerTitle,
            leading: IconButton(
              icon: const Icon(Icons.close, color: AppColors.textBody),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: AppColors.textHeader,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (onSave != null)
                TextButton(
                  onPressed: onSave,
                  child: Text(
                    saveLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
            bottom: bottom,
          ),
          body: body,
        ),
      ),
    );
  }
}
