import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class EditorSection extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget child;
  final bool compact;

  const EditorSection({
    super.key,
    required this.title,
    required this.child,
    this.hint,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = compact ? 12 : 20;
    final double hintGap = compact ? 2 : 4;
    final double fieldGap = compact ? 10 : 8;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textHeader,
            ),
          ),
          if (hint != null) ...[
            SizedBox(height: hintGap),
            Text(
              hint!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textBody,
              ),
            ),
          ],
          SizedBox(height: fieldGap),
          child,
        ],
      ),
    );
  }
}
