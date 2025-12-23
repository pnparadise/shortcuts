import 'package:flutter/material.dart' hide Action;
import '../../models.dart';
import '../theme/theme.dart';

// Types of items in the flat list
enum FlatItemType {
  action,
  ifStart,
  thenMarker,
  elseMarker,
  endIfMarker,
  emptyPlaceholder,
}

class FlatItem {
  final String id;
  final FlatItemType type;
  final Action? action;
  final int depth;
  final String? parentId;
  final List<Color> ancestorLines; // Colors of vertical lines to draw on the left

  FlatItem({
    required this.id,
    required this.type,
    required this.depth,
    this.action,
    this.parentId,
    this.ancestorLines = const [],
  });
}

// Flattener Logic
class FlowFlattener {
  static List<FlatItem> flatten(List<Action> actions, {int depth = 0, List<Color> lines = const []}) {
    List<FlatItem> result = [];
    for (var i = 0; i < actions.length; i++) {
        final action = actions[i];
        final id = "${action.type}_${action.hashCode}_$i"; 
        
        if (action is IfAction) {
            // IF Header (No extra line, at current depth)
            result.add(FlatItem(
                id: "IF_START_$id",
                type: FlatItemType.ifStart,
                action: action,
                depth: depth,
                ancestorLines: lines
            ));

            // THEN Marker (Has Green line, acts as header of Green block)
            final greenLines = List<Color>.from(lines)..add(AppColors.success);
            result.add(FlatItem(
                id: "THEN_$id",
                type: FlatItemType.thenMarker,
                depth: depth + 1, // Indented
                parentId: id,
                ancestorLines: greenLines 
            ));
            
            // True Branch
            if (action.trueFlow.isEmpty) {
                result.add(FlatItem(
                    id: "EMPTY_TRUE_$id",
                    type: FlatItemType.emptyPlaceholder,
                    depth: depth + 1,
                    parentId: id,
                    ancestorLines: greenLines
                ));
            } else {
                result.addAll(flatten(action.trueFlow, depth: depth + 1, lines: greenLines));
            }
            
            // Else Marker (Has Red line, acts as header of Red block)
            final redLines = List<Color>.from(lines)..add(AppColors.danger);
            result.add(FlatItem(
                id: "ELSE_$id",
                type: FlatItemType.elseMarker,
                depth: depth + 1, // Indented
                parentId: id,
                ancestorLines: redLines
            ));
            
            // False Branch
            if (action.falseFlow.isEmpty) {
                result.add(FlatItem(
                    id: "EMPTY_FALSE_$id",
                    type: FlatItemType.emptyPlaceholder,
                    depth: depth + 1,
                    parentId: id,
                    ancestorLines: redLines
                ));
            } else {
                result.addAll(flatten(action.falseFlow, depth: depth + 1, lines: redLines));
            }
            
            // End Marker (Has Red line to close the visual block?)
            result.add(FlatItem(
                id: "END_$id",
                type: FlatItemType.endIfMarker,
                depth: depth + 1, // Indented
                parentId: id,
                ancestorLines: redLines
            ));
        } else {
            // Normal Action
            result.add(FlatItem(
                id: id,
                type: FlatItemType.action,
                action: action,
                depth: depth,
                ancestorLines: lines
            ));
        }
    }
    return result;
  }

  static List<Action> reconstruct(List<FlatItem> flatList) {
      // Recursive reconstruction
      // We consume items from the list until we hit an unexpected marker or end
      return _buildBlock(List.from(flatList)); // Pass copy to consume
  }

  static List<Action> _buildBlock(List<FlatItem> remaining) {
      List<Action> actions = [];
      
      while (remaining.isNotEmpty) {
          final item = remaining.first; // Peek
          
          if (item.type == FlatItemType.elseMarker || item.type == FlatItemType.endIfMarker) {
               // End of this block
               return actions;
          }
          
          // Consume current
          remaining.removeAt(0);
          
          if (item.type == FlatItemType.thenMarker) {
              // Just skip THEN markers, they are purely visual start of block
              continue; 
          }

          if (item.type == FlatItemType.action) {
              actions.add(item.action!);
          } else if (item.type == FlatItemType.ifStart) {
              // It's an IF. We need to satisfy True flow, then Else, then False flow, then End.
              final ifAction = item.action as IfAction;
              
              // 1. Build True Flow
              // We keep consuming until we hit Else or End (if implicit else, but we enforce explicit Else marker)
              List<Action> trueFlow = _buildBlock(remaining);
              
              // After returning, the next item in 'remaining' SHOULD be ElseMarker
              if (remaining.isNotEmpty && remaining.first.type == FlatItemType.elseMarker) {
                   remaining.removeAt(0); // Consume ELSE
                   
                   // 2. Build False Flow
                   List<Action> falseFlow = _buildBlock(remaining);
                   
                   // After returning, next should be EndMarker
                   if (remaining.isNotEmpty && remaining.first.type == FlatItemType.endIfMarker) {
                       remaining.removeAt(0); // Consume END
                   }
                   
                   actions.add(ifAction.copyWith(trueFlow: trueFlow, falseFlow: falseFlow));
              } else {
                   // Malformed structure (missing markers)? 
                   // Just add what we have, treat remaining as broken or implicitly closed?
                   // For robustness, assuming valid structure.
                   actions.add(ifAction.copyWith(trueFlow: trueFlow, falseFlow: []));
              }
          }
      }
      return actions;
  }
}
