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

class EditorScreen extends StatefulWidget {
  final int? widgetId;
  // For nested flows (IF block), we pass the initial actions and a callback
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
  
  List<Action> _actions = [];
  bool _loading = false;
  
  // Widget Meta
  late int _localWidgetId;
  String _iconId = "TERMINAL";
  String _label = "My Widget";
  
  bool get _isRoot => widget.widgetId != null || (widget.initialActions == null);

  @override
  void initState() {
    super.initState();
    if (widget.initialActions != null) {
        _actions = List.from(widget.initialActions!);
        _localWidgetId =  -1; // Not relevant for nested
    } else {
        if (widget.widgetId != null) {
            _localWidgetId = widget.widgetId!;
            _loadWidget();
        } else {
            // Generate Random ID for new widget
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
              _actions = Action.fromJsonList(logicJson);
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
    // If child flow, just notify parent
    if (!_isRoot) {
        widget.onFlowChanged?.call(_actions);
        Navigator.pop(context);
        return;
    }

    // Root Save
    final logicJson = jsonEncode(_actions.map((e) => e.toJson()).toList());
    try {
      // Use correct method name 'saveWidgetConfig'
      await platform.invokeMethod('saveWidgetConfig', {
        'widgetId': _localWidgetId,
        'label': _label,
        'iconId': _iconId,
        'jsonConfig': logicJson, // Native expects 'jsonConfig', not 'logic'
      });
      if (mounted) Navigator.pop(context, true);
    } on PlatformException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save Failed: ${e.message}")));
    }
  }

  void _editMetadata() {
      String tempName = _label;
      showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text("Widget Settings"),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  TextField(
                      decoration: const InputDecoration(labelText: "Widget Name"),
                      controller: TextEditingController(text: _label),
                      onChanged: (v) => tempName = v,
                  ),
                  const SizedBox(height: 16),
                  const Text("Icon", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                      spacing: 12,
                      children: IconMap.icons.keys.map((key) => InkWell(
                          onTap: () {
                              setState(() => _iconId = key);
                              Navigator.pop(context);
                              _editMetadata(); 
                          },
                          child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: _iconId == key ? AppColors.primary.withOpacity(0.2) : null,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _iconId == key ? AppColors.primary : Colors.transparent)
                              ),
                              child: Icon(IconMap.icons[key], color: _iconId == key ? AppColors.primary : Colors.grey),
                          ),
                      )).toList(),
                  )
              ],
          ),
          actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              TextButton(onPressed: () {
                  setState(() => _label = tempName);
                  Navigator.pop(context);
              }, child: const Text("Save")),
          ],
      ));
  }

  void _updateAction(int index, Action newAction) {
      setState(() {
          _actions[index] = newAction;
      });
      if (!_isRoot) widget.onFlowChanged?.call(_actions);
  }
  
  void _deleteAction(int index) {
      setState(() {
          _actions.removeAt(index);
      });
      if (!_isRoot) widget.onFlowChanged?.call(_actions);
  }

  void _openActionEditor(int index, Action action) {
      _openEditorWithCallback(action, (newAction) => _updateAction(index, newAction));
  }

  void _openEditorWithCallback(Action action, ValueChanged<Action> onSave) {
      if (action is FetchAction) {
          showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent, 
              builder: (_) => FetchEditorSheet(
                  action: action, 
                  onSave: onSave
              )
          );
      } else if (action is ToastAction) {
          ToastEditor.show(context, action, onSave);
      } else if (action is SetViewAction) {
          ViewEditor.show(context, action, onSave);
      } else if (action is IfAction) {
          _showIfOptions(action, onSave);
      }
  }
  
  void _showIfOptions(IfAction action, ValueChanged<Action> onSave) {
      showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.cardBg,
          builder: (ctx) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  ListTile(
                      leading: const Icon(Icons.settings, color: AppColors.primary),
                      title: const Text("Edit Condition"),
                      onTap: () {
                          Navigator.pop(ctx);
                          ConditionEditor.show(context, action, onSave);
                      }
                  ),
                  ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                      title: const Text("Edit TRUE Actions"),
                      trailing: Text("${action.trueFlow.length} steps", style: const TextStyle(color: Colors.grey)),
                      onTap: () {
                          Navigator.pop(ctx);
                          _navToNestedFlow("True Block", action.trueFlow, (newFlow) {
                              onSave(action.copyWith(trueFlow: newFlow));
                          });
                      },
                  ),
                  ListTile(
                      leading: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                      title: const Text("Edit FALSE Actions"),
                      trailing: Text("${action.falseFlow.length} steps", style: const TextStyle(color: Colors.grey)),
                      onTap: () {
                          Navigator.pop(ctx);
                          _navToNestedFlow("False Block", action.falseFlow, (newFlow) {
                              onSave(action.copyWith(falseFlow: newFlow));
                          });
                      },
                  ),
                  const SizedBox(height: 16),
              ],
          )
      );
  }
  
  void _navToNestedFlow(String title, List<Action> flow, ValueChanged<List<Action>> onChanged) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(
          title: title,
          initialActions: flow,
          onFlowChanged: onChanged,
      )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: InkWell(
            onTap: _isRoot ? _editMetadata : null,
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    if (_isRoot) ...[
                        Icon(IconMap.getIcon(_iconId), size: 20, color: AppColors.textHeader),
                        const SizedBox(width: 8),
                    ],
                    Text(_isRoot ? _label : widget.title, style: AppStyles.headerStyle),
                    if (_isRoot)
                        const Padding(
                           padding: EdgeInsets.only(left: 8),
                           child: Icon(Icons.edit, size: 14, color: Colors.grey),
                        ),
                ],
            ),
        ),
        backgroundColor: AppColors.cardBg,
        elevation: 1,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textHeader),
            onPressed: () => Navigator.pop(context),
        ),
        actions: [
            if (_isRoot)
                TextButton(
                    onPressed: _saveWidget, 
                    child: const Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold))
                )
        ],
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator()) 
          : _actions.isEmpty 
              ? Center(child: Text("Use + to add actions", style: TextStyle(color: Colors.grey[400])))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _actions.length,
                  onReorder: (oldIndex, newIndex) {
                      setState(() {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final item = _actions.removeAt(oldIndex);
                          _actions.insert(newIndex, item);
                      });
                      if (!_isRoot) widget.onFlowChanged?.call(_actions);
                  },
                  itemBuilder: (context, index) {
                      final action = _actions[index];
                      // ActionTile handles display.
                      // We wrap in a Container to give it a Key for reordering
                      return Container(
                          key: ValueKey("${action.type}_$index"), // Key must be unique-ish
                          margin: const EdgeInsets.only(bottom: 8), // Add vertical spacing
                          child: ActionTile(
                              index: index,
                              action: action,
                              onTap: () => _openActionEditor(index, action),
                              onDelete: () => _deleteAction(index),
                              onChanged: (newAction) => _updateAction(index, newAction),
                              onNavToFlow: _navToNestedFlow,
                              onEditNested: (subAction, onUpdate) => _openEditorWithCallback(subAction, onUpdate),
                          ),
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
                  builder: (_) => const ActionPicker(),
              );
              
              if (newAction != null) {
                  setState(() => _actions.add(newAction));
                  if (!_isRoot) widget.onFlowChanged?.call(_actions);
              }
          },
      ),
    );
  }

  void _handleIfEdit(int index, IfAction action, int part) {
      if (part == 0) {
          // Edit Condition
          ConditionEditor.show(context, action, (newAction) => _updateAction(index, newAction));
      } else if (part == 1) {
          // Edit True Flow
          _navToNestedFlow("True Block", action.trueFlow, (newFlow) {
              _updateAction(index, action.copyWith(trueFlow: newFlow));
          });
      } else if (part == 2) {
          // Edit False Flow
          _navToNestedFlow("False Block", action.falseFlow, (newFlow) {
              _updateAction(index, action.copyWith(falseFlow: newFlow));
          });
      }
  }
}
