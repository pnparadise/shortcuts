import 'package:flutter/material.dart' hide Action;
import 'models.dart';
import 'theme.dart';

class ActionPicker extends StatelessWidget {
  const ActionPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffoldBg,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Add Action", style: AppStyles.headerStyle),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5, // rectangular "server-addon" look
            children: [
              _ActionOption(
                icon: Icons.public,
                label: "Fetch",
                description: "HTTP Request",
                onTap: () => Navigator.pop(context, FetchAction()),
              ),
              _ActionOption(
                icon: Icons.call_split,
                label: "If Condition",
                description: "Branch Logic",
                onTap: () => Navigator.pop(context, IfAction()),
              ),
              _ActionOption(
                icon: Icons.chat_bubble_outline,
                label: "Toast",
                description: "Show Message",
                onTap: () => Navigator.pop(context, ToastAction()),
              ),
              _ActionOption(
                icon: Icons.view_quilt_outlined,
                label: "Set View",
                description: "Update Widget",
                onTap: () => Navigator.pop(context, SetViewAction()),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ActionOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ActionOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyles.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(description, style: const TextStyle(color: AppColors.textBody, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
