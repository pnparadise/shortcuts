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
  double _swipeOffset = 0;
  bool _isDragging = false;

  static const double _actionExtent = 88;
  static const double _maxSwipeExtent = 120;
  static const Duration _snapDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    // IF BLOCK Special Handling
    if (widget.action is IfAction) {
        return _buildSwipeWrapper(_buildIfTile(context, widget.action as IfAction));
    }

    // Standard Tile
    IconData icon = Icons.code;
    Color iconColor = AppColors.textBody;
    String title = widget.action.type.toUpperCase();
    String subtitle = "";

    if (widget.action is FetchAction) {
        final f = widget.action as FetchAction;
        icon = Icons.public;
        iconColor = AppColors.primary;
        title = "${f.method} ${f.url.isEmpty ? 'Untargeted' : f.url}";
        subtitle = "Target: ${f.targetVar}";
    } else if (widget.action is ToastAction) {
        icon = Icons.chat_bubble_outline;
        iconColor = AppColors.warning;
        subtitle = (widget.action as ToastAction).messageTemplate;
    } else if (widget.action is SetViewAction) {
        icon = Icons.view_quilt;
        iconColor = AppColors.success;
        subtitle = "Update UI: ${(widget.action as SetViewAction).textTemplate.replaceAll('\n', ' ')}";
    } else if (widget.action is ReturnAction) {
        icon = Icons.stop_circle_outlined;
        iconColor = AppColors.danger;
        title = "RETURN / STOP";
        subtitle = "Ends execution immediately";
    }

    return _buildSwipeWrapper(
        Material(
            color: AppColors.cardBg,
            child: InkWell(
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
      return Material(
          color: AppColors.cardBg,
          child: Column(
              children: [
                  // Header
                  InkWell(
                      onTap: () => widget.onEditIf?.call(0),
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                              children: [
                                  Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: AppColors.warning.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.call_split, color: AppColors.warning, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text.rich(
                                          TextSpan(
                                              children: [
                                                  const TextSpan(
                                                      text: "IF ",
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 13,
                                                          color: AppColors.textHeader,
                                                      ),
                                                  ),
                                                  TextSpan(
                                                      text: ifAction.conditionExpression.isEmpty
                                                          ? "Set condition"
                                                          : ifAction.conditionExpression,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontFamily: "monospace",
                                                          color: ifAction.conditionExpression.isEmpty
                                                              ? AppColors.textMuted
                                                              : AppColors.primary,
                                                      ),
                                                  ),
                                              ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                      ),
                                  ),
                                  const Icon(Icons.edit, size: 14, color: Colors.grey),
                              ],
                          ),
                      ),
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.scaffoldBg), // Separator matches item gaps
                  Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                          children: [
                              _buildBranchPreview(
                                  label: "True Branch",
                                  icon: Icons.check_circle_outline,
                                  color: AppColors.success,
                                  flow: ifAction.trueFlow,
                                  onTap: () => widget.onEditIf?.call(1),
                              ),
                              const SizedBox(height: 8),
                              _buildBranchPreview(
                                  label: "False Branch",
                                  icon: Icons.cancel_outlined,
                                  color: AppColors.danger,
                                  flow: ifAction.falseFlow,
                                  onTap: () => widget.onEditIf?.call(2),
                              ),
                          ],
                      ),
                  ),
              ],
          ),
      );
  }

  Widget _buildSwipeWrapper(Widget child) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 1), // Generic separator
          child: Stack( // Removed ClipRRect to remove radius
                  children: [
                      Positioned.fill(
                          child: Container(
                              color: AppColors.danger,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: _buildDeleteAction(),
                          ),
                      ),
                      AnimatedContainer(
                          duration: _isDragging ? Duration.zero : _snapDuration,
                          curve: Curves.easeOutCubic,
                          transform: Matrix4.translationValues(_swipeOffset, 0, 0),
                          child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragStart: _handleDragStart,
                              onHorizontalDragUpdate: _handleDragUpdate,
                              onHorizontalDragEnd: _handleDragEnd,
                              onHorizontalDragCancel: _handleDragCancel,
                              child: IgnorePointer(
                                  ignoring: _swipeOffset.abs() > 1,
                                  child: Container(
                                      color: AppColors.cardBg, // Ensure opaque background for swipe
                                      child: child
                                  ),
                              ),
                          ),
                      ),
                  ],
              ),
      );
  }

  Widget _buildDeleteAction() {
      return Material(
          color: Colors.transparent,
          child: InkWell(
              onTap: widget.onDelete,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                      "Delete",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                      ),
                  ),
              ),
          ),
      );
  }

  void _handleDragStart(DragStartDetails details) {
      _isDragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
      final delta = details.primaryDelta ?? 0;
      final next = (_swipeOffset + delta).clamp(-_maxSwipeExtent, 0.0);
      setState(() => _swipeOffset = next);
  }

  void _handleDragEnd(DragEndDetails details) {
      _isDragging = false;
      final velocity = details.primaryVelocity ?? 0;
      final shouldOpen = _swipeOffset <= -_actionExtent / 2 || velocity < -600;
      setState(() => _swipeOffset = shouldOpen ? -_actionExtent : 0);
  }

  void _handleDragCancel() {
      _isDragging = false;
      final shouldOpen = _swipeOffset <= -_actionExtent / 2;
      setState(() => _swipeOffset = shouldOpen ? -_actionExtent : 0);
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
                      if (subtitle.isNotEmpty)
                          Expanded(
                              child: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textBody), overflow: TextOverflow.ellipsis)
                          )
                      else
                          const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  ],
              ),
          ),
      );
  }

  Widget _buildBranchPreview({
      required String label,
      required IconData icon,
      required Color color,
      required List<Action> flow,
      VoidCallback? onTap,
  }) {
      final count = flow.length;

      return Material(
          color: Colors.transparent,
          child: InkWell(
              onTap: onTap,
              child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          Container(width: 3, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                      children: [
                                          Icon(icon, size: 16, color: color),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                      Row(
                                                          children: [
                                                              Expanded(
                                                                  child: Text(
                                                                      label,
                                                                      style: const TextStyle(
                                                                          fontSize: 12,
                                                                          fontWeight: FontWeight.bold,
                                                                          color: AppColors.textHeader,
                                                                      ),
                                                                  ),
                                                              ),
                                                              Text(
                                                                  "$count step${count == 1 ? '' : 's'}",
                                                                  style: const TextStyle(fontSize: 11, color: AppColors.textBody),
                                                              ),
                                                          ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      ...flow.take(3).map((a) => Padding(
                                                          padding: const EdgeInsets.only(top: 2),
                                                          child: Text(
                                                              "• ${_actionSummary(a)}", 
                                                              style: const TextStyle(fontSize: 11, color: AppColors.textBody),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                          ),
                                                      )).toList(),
                                                      if (flow.length > 3)
                                                          Padding(
                                                              padding: const EdgeInsets.only(top: 2),
                                                              child: Text(
                                                                  "  + ${flow.length - 3} more...",
                                                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                                              ),
                                                          ),
                                                      if (flow.isEmpty)
                                                          const Text(
                                                              "No actions yet",
                                                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                          ),
                                                  ],
                                              ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                      ],
                                  ),
                              ),
                          ),
                      ],
                  ),
              ),
          ),
      );
  }

  String _actionSummary(Action action) {
      if (action is FetchAction) {
          final url = action.url.isEmpty ? "fetch" : action.url;
          return "${action.method} ${_truncate(url, 22)}";
      }
      if (action is ToastAction) {
          return "Toast ${_truncate(action.messageTemplate, 22)}";
      }
      if (action is SetViewAction) {
          final clean = action.textTemplate.replaceAll('\n', ' ');
          return "View ${_truncate(clean, 22)}";
      }
      if (action is IfAction) {
          return "IF ${_truncate(action.conditionExpression, 22)}";
      }
      return action.type;
  }

  String _truncate(String text, int max) {
      if (text.isEmpty) return "Untitled";
      final clean = text.replaceAll('\n', ' ').trim();
      if (clean.length <= max) return clean;
      return "${clean.substring(0, max - 3)}...";
  }
}
