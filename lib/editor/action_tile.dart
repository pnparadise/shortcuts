import 'package:flutter/material.dart' hide Action;
import '../models.dart';
import '../theme.dart';

class ActionTile extends StatefulWidget {
  final Action action;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(int part)? onEditIf; // 0=Condition, 1=True, 2=False
  final int index;

  const ActionTile({
    super.key,
    required this.action,
    required this.onTap,
    required this.onDelete,
    this.onEditIf,
    required this.index,
  });

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // IF BLOCK Special Handling
    if (widget.action is IfAction) {
        return _buildIfTile(context, widget.action as IfAction);
    }

    // Standard Tile
    IconData icon = Icons.code;
    Color iconColor = AppColors.textBody;
    String title = widget.action.type.toUpperCase();
    String subtitle = "";

    if (widget.action is FetchAction) {
        final f = widget.action as FetchAction;
        icon = Icons.public;
        iconColor = Colors.blue;
        title = "${f.method} ${f.url.isEmpty ? 'Untargeted' : f.url}";
        subtitle = "Target: ${f.targetVar}";
    } else if (widget.action is ToastAction) {
        icon = Icons.chat_bubble_outline;
        iconColor = Colors.orange;
        subtitle = (widget.action as ToastAction).messageTemplate;
    } else if (widget.action is SetViewAction) {
        icon = Icons.view_quilt;
        iconColor = Colors.purple;
        subtitle = "Update UI: ${(widget.action as SetViewAction).textTemplate.replaceAll('\n', ' ')}";
    }

    return Dismissible(
        key: ValueKey(widget.action.hashCode), // Should use stable ID if possible
        direction: DismissDirection.endToStart,
        onDismissed: (_) => widget.onDelete(),
        background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
            ),
            color: AppColors.cardBg,
            child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onTap,
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                        children: [
                            Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, color: iconColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textHeader), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        if (subtitle.isNotEmpty)
                                            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textBody), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                        ],
                    ),
                ),
            ),
        ),
    );
  }

  Widget _buildIfTile(BuildContext context, IfAction ifAction) {
      return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
          ),
          color: AppColors.cardBg,
          child: Column(
              children: [
                  // Header
                  InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(12)),
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                              children: [
                                  Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.call_split, color: Colors.amber, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                              const Text("IF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textHeader)),
                                              Text(ifAction.conditionExpression.isEmpty ? "No condition" : ifAction.conditionExpression, 
                                                  style: const TextStyle(fontSize: 12, fontFamily: "monospace", color: AppColors.primary)),
                                          ],
                                      ),
                                  ),
                                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey, size: 18),
                              ],
                          ),
                      ),
                  ),
                  // Expanded Content
                  if (_isExpanded)
                      Container(
                          decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppColors.border)),
                              color: Color(0xFFFAFAFA), // Slightly distinct background
                          ),
                          child: Column(
                              children: [
                                  _buildIfRow(
                                      Icons.settings, 
                                      "Condition", 
                                      ifAction.conditionExpression.isEmpty ? "Not Set" : ifAction.conditionExpression,
                                      Colors.grey,
                                      () => widget.onEditIf?.call(0)
                                  ),
                                  const Divider(height: 1),
                                  _buildIfRow(
                                      Icons.check_circle_outline, 
                                      "True Flow", 
                                      "${ifAction.trueFlow.length} Actions",
                                      Colors.green,
                                      () => widget.onEditIf?.call(1)
                                  ),
                                  const Divider(height: 1),
                                  _buildIfRow(
                                      Icons.cancel_outlined, 
                                      "False Flow", 
                                      "${ifAction.falseFlow.length} Actions",
                                      Colors.red,
                                      () => widget.onEditIf?.call(2)
                                  ),
                              ],
                          ),
                      )
              ],
          ),
      );
  }

  Widget _buildIfRow(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
      return InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                  children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 12),
                      SizedBox(
                          width: 80, 
                          child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textHeader))
                      ),
                      Expanded(
                          child: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textBody), overflow: TextOverflow.ellipsis)
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  ],
              ),
          ),
      );
  }
}
