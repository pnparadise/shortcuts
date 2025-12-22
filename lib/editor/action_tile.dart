import 'package:flutter/material.dart' hide Action;
import 'sheets/common_sheets.dart';
import '../models.dart';
import '../theme.dart';

class ActionTile extends StatefulWidget {
  final Action action;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(Action subAction, ValueChanged<Action> onUpdate)? onEditNested;
  final Function(String title, List<Action> flow, ValueChanged<List<Action>> onUpdate)? onNavToFlow;
  final ValueChanged<Action>? onChanged;
  final int index;

  const ActionTile({
    super.key,
    required this.action,
    required this.onTap,
    required this.onDelete,
    this.onEditNested,
    this.onNavToFlow,
    this.onChanged,
    required this.index,
  });

  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  double _swipeOffset = 0;
  bool _isDragging = false;
  bool _isExpanded = true;

  static const double _actionExtent = 88;
  static const double _maxSwipeExtent = 120;
  static const Duration _snapDuration = Duration(milliseconds: 180);

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
      key: ValueKey("action_${widget.index}"),
      onDelete: widget.onDelete,
      child: Material(
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
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textBody), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
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
    return Column(
      children: [
        // Main IF Header (Swipeable)
        _buildSwipeWrapper(
            key: ValueKey("if_header_${widget.index}"),
            onDelete: widget.onDelete,
            child: Material(
              color: AppColors.cardBg,
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                      InkWell(
                        onTap: () {
                             // Direct Edit Condition
                             CommonSheets.showIfEditor(context, ifAction, (updatedAction) {
                                  widget.onChanged?.call(updatedAction);
                             });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.edit, size: 16, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ),

        // Blocks
        if (_isExpanded) ...[
        _buildBranchBlock(
            label: "THEN", 
            color: AppColors.success, 
            flow: ifAction.trueFlow,
            onTap: () {
                 widget.onNavToFlow?.call("True Branch", ifAction.trueFlow, (newFlow) {
                      widget.onChanged?.call(ifAction.copyWith(trueFlow: newFlow));
                 });
            },
            branchIndex: 1,
        ),
        _buildBranchBlock(
            label: "ELSE", 
            color: AppColors.danger, 
            flow: ifAction.falseFlow,
            onTap: () {
                 widget.onNavToFlow?.call("False Branch", ifAction.falseFlow, (newFlow) {
                      widget.onChanged?.call(ifAction.copyWith(falseFlow: newFlow));
                 });
            },
            branchIndex: 2,
        ),
        ],
      ],
    );
  }

  Widget _buildBranchBlock({
    required String label,
    required Color color,
    required List<Action> flow,
    required VoidCallback onTap,
    required int branchIndex,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 6, top: 4), 
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color.withOpacity(0.5), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBranchHeader(
             label: label, 
             color: color, 
             count: flow.length, 
             onTap: onTap
          ),
          _buildRecursiveBranch(flow, branchIndex),
        ],
      ),
    );
  }

  Widget _buildBranchHeader({
      required String label, 
      required Color color, 
      required int count, 
      required VoidCallback onTap, 
  }) {
    // Taller header (vertical: 10)
    return Material(
        color: AppColors.cardBg,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10), 
                child: Row(
                    children: [
                        Text(
                            label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                                letterSpacing: 0.5,
                            ),
                        ),
                        const Spacer(),
                        Text(
                            "$count steps",
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
                    ],
                ),
            ),
        ),
    );
  }

  Widget _buildRecursiveBranch(List<Action> actions, int branchIndex) {
    if (actions.isEmpty) {
        return Padding(
             padding: const EdgeInsets.only(top: 4),
             child: Material(
                 color: AppColors.cardBg,
                 child: InkWell(
                     onTap: () {
                          String label = branchIndex == 1 ? "True Branch" : "False Branch";
                          widget.onNavToFlow?.call(label, actions, (newFlow) => _notifyParentUpdate(newFlow, branchIndex));
                     },
                     child: Padding(
                         padding: const EdgeInsets.all(12),
                         child: Row(
                            children: [
                               Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.add, size: 20, color: AppColors.textMuted),
                               ),
                               const SizedBox(width: 12),
                               const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       Text("Tap to add action", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textHeader)),
                                       SizedBox(height: 4),
                                       Text("点击添加动作", style: TextStyle(fontSize: 11, color: AppColors.textBody)),
                                    ],
                                  ),
                               ),
                            ],
                         ),
                     ),
                 ),
            ),
        );
    }

    return Column(
        children: actions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            return Padding(
                padding: const EdgeInsets.only(top: 4), 
                child: ActionTile(
                    key: ValueKey(action),
                    action: action,
                    index: index, 
                    // Direct Edit for Leaf Nodes (Toast, etc) -> handled by ConfigScreen via onEditNested wrapper
                    onTap: () {
                         widget.onEditNested?.call(action, (updatedAction) {
                              setState(() {
                                  actions[index] = updatedAction;
                              });
                              _notifyParentUpdate(actions, branchIndex);
                         });
                    },
                    onDelete: () {
                        setState(() {
                             actions.removeAt(index);
                        });
                        _notifyParentUpdate(actions, branchIndex);
                    },
                    // Recurse navigation
                    onNavToFlow: widget.onNavToFlow,
                    // Recurse updates
                    onChanged: (updatedChild) {
                         setState(() {
                             actions[index] = updatedChild;
                         });
                         _notifyParentUpdate(actions, branchIndex);
                    },
                    onEditNested: widget.onEditNested, 
                ),
            );
        }).toList(),
    );
  }

  void _notifyParentUpdate(List<Action> modifiedBranch, int branchIndex) {
      if (widget.action is! IfAction) return;
      final parent = widget.action as IfAction;
      IfAction updated;
      if (branchIndex == 1) {
           updated = parent.copyWith(trueFlow: modifiedBranch);
      } else {
           updated = parent.copyWith(falseFlow: modifiedBranch);
      }
      widget.onChanged?.call(updated);
  } 


  Widget _buildSwipeWrapper({required Key key, required VoidCallback onDelete, required Widget child}) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: AppColors.danger,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: _buildDeleteButton(onDelete),
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
                color: AppColors.cardBg,
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
    setState(() => _isDragging = true);
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
}
