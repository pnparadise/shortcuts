import 'package:flutter/material.dart';
import '../theme.dart';

class VariablePicker extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final List<String> availableVariables; // e.g. ["res.status", "res.data"]

  const VariablePicker({
    super.key, 
    required this.onSelect,
    this.availableVariables = const [],
  });

  static void show(BuildContext context, {
    required ValueChanged<String> onSelect, 
    List<String> suggestions = const ['res.status', 'res.data.message', 'res.headers']
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => VariablePicker(onSelect: onSelect, availableVariables: suggestions),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text("Insert Variable", style: AppStyles.headerStyle),
            const SizedBox(height: 16),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                    ...availableVariables.map((v) => _buildChip(context, v)),
                    // Common helpers
                    _buildChip(context, "timestamp"),
                    _buildChip(context, "uuid"),
                ],
            ),
            const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String value) {
      return ActionChip(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          label: Text("{{$value}}", style: const TextStyle(color: AppColors.primary)),
          onPressed: () {
              onSelect("{{$value}}");
              Navigator.pop(context);
          },
      );
  }
}
