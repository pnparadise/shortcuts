import 'dart:convert';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/pickers/action_picker.dart';
import '../widgets/action_tile.dart';
import '../editors/request_editor.dart';
import '../editors/condition_editor.dart';
import '../editors/toast_editor.dart';
import '../editors/view_editor.dart';
import '../editors/clipboard_editor.dart';
import '../editors/intent_editor.dart';
import '../editors/notification_editor.dart';
import '../editors/expression_editor.dart';

import 'flat_editor_utils.dart';

class EditorScreen extends StatefulWidget {
  final int? widgetId;
  final List<Action>? initialActions; 
  final ValueChanged<List<Action>>? onFlowChanged;
  final String title;

  const EditorScreen({
      super.key, 
      this.widgetId, 
      this.initialActions,
      this.onFlowChanged,
      this.title = "Configure Logic",
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const platform = MethodChannel('com.example.lowcode/widget');
  
  List<FlatItem> _flatActions = []; // Flattened list
  bool _loading = false;
  Set<String> _collapsedBlocks = {}; // Track collapsed IF blocks by their ID
  
  // Widget Meta
  late int _localWidgetId;
  String _iconId = "TERMINAL";
  String _label = "My Widget";
  
  bool get _isRoot => widget.widgetId != null || (widget.initialActions == null);

  @override
  void initState() {
    super.initState();
    if (widget.initialActions != null) {
        _flatActions = FlowFlattener.flatten(widget.initialActions!);
        _localWidgetId =  -1;
    } else {
        if (widget.widgetId != null) {
            _localWidgetId = widget.widgetId!;
            _loadWidget();
        } else {
            _localWidgetId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        }
    }
  }

  Future<void> _loadWidget() async {
    setState(() => _loading = true);
    try {
      final result = await platform.invokeMethod('getWidget', {'widgetId': _localWidgetId});
      if (result != null) {
        final Map<dynamic, dynamic> data = result;
        setState(() {
          _iconId = data['iconId'] ?? 'TERMINAL';
          _label = data['label'] ?? 'Widget';
          final logicJson = data['logicFlow'] as String? ?? '[]';
          try {
              final actions = Action.fromJsonList(logicJson);
              _flatActions = FlowFlattener.flatten(actions);
          } catch (e) {
              debugPrint("JSON Parse Error: $e");
          }
        });
      }
    } catch (e) {
      debugPrint("Load Widget Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveWidget() async {
    final actions = FlowFlattener.reconstruct(_flatActions);

    if (!_isRoot) {
        widget.onFlowChanged?.call(actions);
        Navigator.pop(context);
        return;
    }

    final logicJson = jsonEncode(actions.map((e) => e.toJson()).toList());
    try {
      await platform.invokeMethod('saveWidgetConfig', {
        'widgetId': _localWidgetId,
        'label': _label,
        'iconId': _iconId,
        'jsonConfig': logicJson,
      });
      if (mounted) Navigator.pop(context, true);
    } on PlatformException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save Failed: ${e.message}")));
    }
  }

  // ... (Metadata editing methods omitted for brevity, assuming existing structure handles them or they are outside this block) ...
  // NOTE: Assuming _editMetadata is not in this replace scope or safe to keep. 
  // Wait, I need to make sure I don't delete _editMetadata if I replace from line 15.
  // The user provided file content shows _editMetadata at line 112. 
  // My EndLine is 320. I am replacing almost everything.
  // I MUST include _editMetadata and other methods.

  void _editMetadata() {
      // (Simplified reuse of existing logic)
      String tempName = _label;
      showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text("Widget Settings"),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  TextField(controller: TextEditingController(text: _label), onChanged: (v) => tempName = v, decoration: const InputDecoration(labelText: "Widget Name")),
                  const SizedBox(height: 16),
                  Wrap(spacing: 12, children: IconMap.icons.keys.map((key) => InkWell(
                      onTap: () { setState(() => _iconId = key); Navigator.pop(context); _editMetadata(); },
                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _iconId == key ? AppColors.primary.withOpacity(0.2) : null, borderRadius: BorderRadius.circular(8), border: Border.all(color: _iconId == key ? AppColors.primary : Colors.transparent)), child: Icon(IconMap.icons[key], color: _iconId == key ? AppColors.primary : Colors.grey)),
                  )).toList())
              ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")), TextButton(onPressed: () { setState(() => _label = tempName); Navigator.pop(context); }, child: const Text("Save"))],
      ));
  }

  void _updateActionInFlatList(String id, Action newAction) {
      final index = _flatActions.indexWhere((e) => e.id == id);
      if (index != -1) {
          setState(() {
              // Update item, preserving structure metadata
              final old = _flatActions[index];
              _flatActions[index] = FlatItem(
                  id: old.id,
                  type: old.type,
                  action: newAction,
                  depth: old.depth,
                  parentId: old.parentId
              );
              // If it was an IF, changing it might require re-flattening?
              // Usually Action attributes change, not structure (If -> SetView).
              // If type changes, we might need to remove children?
              // Assuming Editor only updates properties locally.
          });
          // Notify parent logic? Not needed for flattened view until Save/Back.
      }
  }
  
  void _deleteFlatItem(int index) {
      final item = _flatActions[index];
      setState(() {
          _flatActions.removeAt(index);
          // If IF Header, remove children block too?
          if (item.type == FlatItemType.ifStart) {
               // item.id is "IF_START_originalId"
               // children parentId is "originalId"
               final baseId = item.id.replaceFirst("IF_START_", "");
               _flatActions.removeWhere((e) => e.parentId == baseId);
          }
      });
  }

  void _openActionEditor(int index, Action action) {
       // Logic to edit...
       _openEditorWithCallback(action, (newAction) {
           // We need to find the item by index again as callback is async
           setState(() {
               if (index < _flatActions.length) { // Basic check
                    final old = _flatActions[index];
                    _flatActions[index] = FlatItem(id: old.id, type: old.type, action: newAction, depth: old.depth, parentId: old.parentId);
               }
           });
       });
  }

  // ... (include _openEditorWithCallback, _showIfOptions, _navToNestedFlow: OBSOLETE or MODIFIED) ...
  // Actually, with flattened view, "nested flow" is inline.
  // We can keep _openEditorWithCallback for generic editors.
  // _showIfOptions is likely NOT needed if we edit inline!
  // Or we use it to edit the Condition only.

  void _openEditorWithCallback(Action action, ValueChanged<Action> onSave) {
      if (action is FetchAction) {
          showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => FetchEditorSheet(action: action, onSave: onSave));
      } else if (action is ToastAction) {
          ToastEditor.show(context, action, onSave);
      } else if (action is SetViewAction) {
          ViewEditor.show(context, action, onSave);
      } else if (action is ClipboardAction) {
          ClipboardEditorSheet.show(context, action, onSave);
      } else if (action is IntentAction) {
          IntentEditorSheet.show(context, action, onSave);
      } else if (action is NotificationAction) {
          NotificationEditor.show(context, action, onSave);
      } else if (action is ExpressionAction) {
          ExpressionEditor.show(context, action, onSave);
      } else if (action is IfAction) {
          // Only edit condition
          ConditionEditor.show(context, action, onSave);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        leadingWidth: Navigator.canPop(context) ? 48 : 16, // Consistent left margin
        leading: Navigator.canPop(context) ? IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textHeader),
            onPressed: () => Navigator.pop(context),
        ) : const SizedBox(width: 16), // Spacer when no back button
        titleSpacing: 0, // Control spacing manually
        title: InkWell(
            onTap: _isRoot ? _editMetadata : null,
            child: Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                    if (_isRoot) ...[
                        Icon(IconMap.getIcon(_iconId), size: 20, color: AppColors.textHeader), 
                        const SizedBox(width: 10)
                    ], 
                    Flexible(
                        child: Text(
                            _isRoot ? _label : widget.title, 
                            style: AppStyles.headerStyle,
                            overflow: TextOverflow.ellipsis,
                        ),
                    ),
                    if (_isRoot) const Padding(
                        padding: EdgeInsets.only(left: 8), 
                        child: Icon(Icons.edit, size: 14, color: Colors.grey)
                    ),
                ],
            ),
        ),
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        actions: [
            if (_isRoot) IconButton(
                icon: const Icon(Icons.save, color: Colors.grey),
                onPressed: _saveWidget,
                tooltip: "Save",
            ),
            const SizedBox(width: 8), // Right margin
        ],
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator()) 
          : _flatActions.isEmpty 
              ? Center(child: Text("Use + to add actions", style: TextStyle(color: Colors.grey[400])))
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false, // We use custom handles
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _flatActions.length,
                  onReorder: (oldIndex, newIndex) {
                      setState(() {
                          if (oldIndex < newIndex) newIndex -= 1;
                          
                          final item = _flatActions[oldIndex];
                          // Block Move for IF Header
                          if (item.type == FlatItemType.ifStart) {
                              final baseId = item.id.replaceFirst("IF_START_", "");
                              final endIdx = _flatActions.indexWhere((e) => e.type == FlatItemType.endIfMarker && e.parentId == baseId);
                              
                              if (endIdx != -1) {
                                  // Prevent moving inside itself
                                  if (newIndex > oldIndex && newIndex <= endIdx) return;

                                  final count = endIdx - oldIndex + 1;
                                  final block = _flatActions.sublist(oldIndex, endIdx + 1);
                                  _flatActions.removeRange(oldIndex, endIdx + 1);
                                  
                                  // Adjust target index for removed block (excluding the one item Flutter accounted for)
                                  if (newIndex > oldIndex) {
                                      newIndex -= (count - 1);
                                  }
                                  // Safety clamp
                                  if (newIndex < 0) newIndex = 0;
                                  if (newIndex > _flatActions.length) newIndex = _flatActions.length;
                                  
                                  _flatActions.insertAll(newIndex, block);
                              }
                          } else if (item.type == FlatItemType.action) {
                              final moved = _flatActions.removeAt(oldIndex);
                              _flatActions.insert(newIndex, moved);
                          }

                          // Normalize depths and IDs
                          final tree = FlowFlattener.reconstruct(_flatActions);
                          _flatActions = FlowFlattener.flatten(tree);
                      });
                  },
                  itemBuilder: (context, index) {
                      final flatItem = _flatActions[index];
                      
                      // Check if this item should be hidden due to collapsed parent
                      if (flatItem.type != FlatItemType.ifStart) {
                          // Find the parent IF block
                          final parentIfId = _findParentIfId(flatItem);
                          if (parentIfId != null && _collapsedBlocks.contains(parentIfId)) {
                              // Parent is collapsed - hide this item
                              return SizedBox.shrink(key: ValueKey(flatItem.id));
                          }
                      }
                      
                      // Tighten IF bottom margin
                      double? customMargin;
                      if (flatItem.type == FlatItemType.ifStart) customMargin = 4.0;
                      
                      // Detect if this is the last item before a marker (ELSE or END)
                      bool isLastInBlock = false;
                      if (index + 1 < _flatActions.length) {
                          final nextItem = _flatActions[index + 1];
                          if (nextItem.type == FlatItemType.elseMarker || 
                              nextItem.type == FlatItemType.endIfMarker) {
                              isLastInBlock = true;
                          }
                      }
                      
                      return DepthedItemWrapper(
                          key: ValueKey(flatItem.id),
                          depth: flatItem.depth,
                          lineColors: flatItem.ancestorLines,
                          isBlockStart: flatItem.type == FlatItemType.thenMarker || flatItem.type == FlatItemType.elseMarker,
                          isBlockEnd: flatItem.type == FlatItemType.endIfMarker,
                          isLastInBlock: isLastInBlock,
                          customBottomMargin: customMargin,
                          child: _buildItemContent(index, flatItem),
                      );
                  },
              ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add),
          onPressed: () async {
              final newAction = await showModalBottomSheet<Action>(
                  context: context, 
                  backgroundColor: Colors.transparent, 
                  isScrollControlled: true,
                  builder: (_) => const ActionPicker()
              );
              if (newAction != null) {
                  setState(() {
                      _flatActions.addAll(FlowFlattener.flatten([newAction]));
                  });
              }
          },
      ),
    );
  }

  Widget _buildItemContent(int index, FlatItem flatItem) {
      if (flatItem.type == FlatItemType.action || flatItem.type == FlatItemType.ifStart) {
           final isIf = flatItem.type == FlatItemType.ifStart;
           final isCollapsed = isIf && _collapsedBlocks.contains(flatItem.id);
           
           return ActionTile(
               index: index,
               action: flatItem.action!,
               isReorderable: true,
               headerOnly: isIf, 
               isCollapsed: isCollapsed,
               onToggleCollapse: isIf ? () {
                   setState(() {
                       if (_collapsedBlocks.contains(flatItem.id)) {
                           _collapsedBlocks.remove(flatItem.id);
                       } else {
                           _collapsedBlocks.add(flatItem.id);
                       }
                   });
               } : null,
               onTap: () => _openEditorWithCallback(flatItem.action!, (newAction) {
                   setState(() {
                        // Update
                        final old = _flatActions[index];
                        _flatActions[index] = FlatItem(
                            id: old.id, type: old.type, action: newAction, depth: old.depth, parentId: old.parentId, ancestorLines: old.ancestorLines
                        );
                   });
               }),
               onChanged: (newAction) {
                   setState(() {
                        // Update when edited via inline edit button (e.g., IF condition edit icon)
                        final old = _flatActions[index];
                        _flatActions[index] = FlatItem(
                            id: old.id, type: old.type, action: newAction, depth: old.depth, parentId: old.parentId, ancestorLines: old.ancestorLines
                        );
                   });
               },
               onDelete: () => _deleteFlatItem(index),
           );
      } else {
           return _buildStructureTile(flatItem);
      }
  }

  Widget _buildStructureTile(FlatItem item) {
      if (item.type == FlatItemType.thenMarker) {
          final count = _countStepsInBlock(item);
          return _buildBranchHeader("THEN", AppColors.success, count, () => _openBranchEditor(item, true));
      } else if (item.type == FlatItemType.elseMarker) {
          final count = _countStepsInBlock(item);
          return _buildBranchHeader("ELSE", AppColors.danger, count, () => _openBranchEditor(item, false));
      } else if (item.type == FlatItemType.endIfMarker) {
           // Minimal height for END marker to reduce bottom spacing
           return const SizedBox(height: 4); 
      } else if (item.type == FlatItemType.emptyPlaceholder) {
           return Material(
               color: AppColors.cardBg.withOpacity(0.9),
               child: Container(
                   height: 56, // Fixed height standard for single line list item
                   padding: const EdgeInsets.symmetric(horizontal: 12),
                   alignment: Alignment.centerLeft, // Center vertically
                   child: Row(
                       children: [
                           Container(
                               padding: const EdgeInsets.all(6),
                               decoration: BoxDecoration(
                                   color: Colors.grey.withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(6),
                               ),
                               child: const Icon(Icons.do_not_disturb_on_outlined, color: Colors.grey, size: 18),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                               child: Column(
                                   mainAxisSize: MainAxisSize.min, // Center vertically
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                       Text("EMPTY", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey), maxLines: 1),
                                       Text("No actions in this block", style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1),
                                   ],
                               ),
                           ),
                       ],
                   ),
               ),
           );
      }
      return const SizedBox();
  }

  String? _findParentIfId(FlatItem item) {
      // For items that have a parentId, find the IF_START parent
      if (item.parentId != null) {
          return "IF_START_${item.parentId}";
      }
      // For nested actions inside THEN/ELSE, trace back through the list
      final idx = _flatActions.indexOf(item);
      for (int i = idx - 1; i >= 0; i--) {
          final prev = _flatActions[i];
          if (prev.type == FlatItemType.ifStart && prev.depth < item.depth) {
              return prev.id;
          }
      }
      return null;
  }

  int _countStepsInBlock(FlatItem marker) {
      int idx = _flatActions.indexOf(marker);
      if (idx == -1) return 0;
      int count = 0;
      for (int i = idx + 1; i < _flatActions.length; i++) {
          final next = _flatActions[i];
          // Stop when we hit a sibling marker (same depth) or parent (lower depth)
          if (next.depth < marker.depth) break; // Parent level - block ended
          if (next.depth == marker.depth && 
              (next.type == FlatItemType.elseMarker || 
               next.type == FlatItemType.endIfMarker ||
               next.type == FlatItemType.thenMarker)) break; // Sibling marker
          
          // Count actual actions (not markers or placeholders)
          if (next.type == FlatItemType.action || next.type == FlatItemType.ifStart) {
              count++;
          }
      }
      return count;
  }

  void _openBranchEditor(FlatItem marker, bool isTrueBranch) {
       // Find Parent IfAction
       // Parent ID is stored in item.parentId. 
       // Depending on structure, parent might be earlier in list.
       // Actually id format: THEN_IF_START_Intent_hash_idx
       // parentId should be the ID of the IF_START item?
       
       // Scan backwards for parentId? Or just item.parentId matches `id` of IfStart?
       // FlatItem definition: parentId stores the id of the parent item.
       
       try {
           // parentId is the raw ID, but ifStart has ID "IF_START_$id"
           final parentInfo = _flatActions.firstWhere((e) => e.id == "IF_START_${marker.parentId}" && e.type == FlatItemType.ifStart);
           final ifAction = parentInfo.action as IfAction;
           
           if (parentInfo.action == null) return;

           final subFlow = isTrueBranch ? ifAction.trueFlow : ifAction.falseFlow;
           
           Navigator.push(
               context,
               MaterialPageRoute(
                   builder: (context) => EditorScreen(
                       title: isTrueBranch ? "THEN Logic" : "ELSE Logic",
                       initialActions: subFlow,
                       onFlowChanged: (newFlow) {
                           // We need to update the parent IF action with the new flow
                           final newIf = isTrueBranch 
                               ? ifAction.copyWith(trueFlow: newFlow)
                               : ifAction.copyWith(falseFlow: newFlow);
                           
                           // Update the parent item in _flatActions provided we can find it by index/reference
                           // Easier: update the PARENT of the list? No, this is recursion.
                           // We are updating local state.
                           
                           // find index of parentInfo again
                           final pIdx = _flatActions.indexWhere((e) => e.id == parentInfo.id);
                           if (pIdx != -1) {
                               // Update the main list?
                               // Wait, simplest way: Just update the Action object and re-flatten everything?
                               // Or calling `onEditNested` logic?
                               
                               // We update the specific item in the flat list.
                               // But flat list copies actions.
                               
                               setState(() {
                                   // Update the action in the flat list
                                   // We need to reconstruct really to be safe, OR just re-flatten this Action.
                                   // But replacing the IF action implies replacing its children in flat list.
                                   // So:
                                   // 1. Remove the old IF block range.
                                   // 2. Flatten new IF action.
                                   // 3. Insert.
                                   
                                   // Find range:
                                   final endIdx = _flatActions.indexWhere((e) => e.type == FlatItemType.endIfMarker && e.parentId == parentInfo.id);
                                   if (endIdx != -1) {
                                       _flatActions.removeRange(pIdx, endIdx + 1);
                                       _flatActions.insertAll(pIdx, FlowFlattener.flatten([newIf], depth: parentInfo.depth, lines: parentInfo.ancestorLines));
                                   }
                               });
                           }
                       },
                   )
               )
           );

       } catch (e) {
           debugPrint("Error opening branch: $e");
       }
  }

  Widget _buildBranchHeader(String label, Color color, int stepCount, VoidCallback onTap) {
    return Material(
      color: AppColors.cardBg, 
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), // Adjusted vertical padding
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
                  Text("$stepCount steps", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
              ],
          ),
        ),
      ),
    );
  }
} // End of _EditorScreenState

class DepthedItemWrapper extends StatelessWidget {
    final int depth;
    final List<Color> lineColors;
    final bool isBlockStart;
    final bool isBlockEnd;
    final bool isLastInBlock;
    final double? customBottomMargin;
    final Widget child;

    const DepthedItemWrapper({
        super.key, 
        required this.depth, 
        required this.lineColors, 
        required this.child,
        this.isBlockStart = false,
        this.isBlockEnd = false,
        this.isLastInBlock = false,
        this.customBottomMargin,
    });

    @override
    Widget build(BuildContext context) {
        // Tighter indentation
        const double indentStep = 10.0; 
        
        // For End markers, we want minimal spacing
        double bottomMargin = depth > 0 ? 4.0 : 8.0;
        if (isBlockEnd) bottomMargin = 0; 
        if (customBottomMargin != null) bottomMargin = customBottomMargin!;

        return CustomPaint(
            painter: _DepthLinePainter(lineColors, indentStep, isBlockStart, isBlockEnd, isLastInBlock, bottomMargin),
            child: Padding(
                padding: EdgeInsets.only(left: depth * indentStep),
                child: Container(
                    margin: EdgeInsets.only(bottom: bottomMargin), 
                    child: child
                ),
            ),
        );
    }
}

class _DepthLinePainter extends CustomPainter {
    final List<Color> colors;
    final double step;
    final bool isBlockStart;
    final bool isBlockEnd;
    final bool isLastInBlock;
    final double bottomMargin;

    _DepthLinePainter(this.colors, this.step, this.isBlockStart, this.isBlockEnd, this.isLastInBlock, this.bottomMargin);

    @override
    void paint(Canvas canvas, Size size) {
        final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5; 

        for (int i = 0; i < colors.length; i++) {
            paint.color = colors[i];
            
            final x = (i * step) + step - 1; 
            
            double top = 0;
            double bottom = size.height;

            if (i == colors.length - 1) {
                if (isBlockStart) {
                   top = 0; 
                   bottom = size.height;
                }
                if (isBlockEnd) {
                   bottom = 0.0; 
                }
                // If this is the last item before a marker, don't extend into margin
                if (isLastInBlock) {
                   bottom = size.height - bottomMargin;
                }
            }
            
            canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
        }
    }

    @override
    bool shouldRepaint(covariant _DepthLinePainter oldDelegate) => 
        oldDelegate.colors != colors || 
        oldDelegate.step != step ||
        oldDelegate.isBlockStart != isBlockStart ||
        oldDelegate.isBlockEnd != isBlockEnd;
}
// Removed unused methods _handleIfEdit, _openClipboardEditor, _navToNestedFlow (no longer needed)
