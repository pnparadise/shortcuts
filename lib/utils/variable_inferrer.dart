import '../models.dart';

/// Global context for holding current logic flow for variable inference
class LogicContext {
  static List<Action> _currentFlow = [];
  
  /// Set the current logic flow (call when entering editor screen)
  static void setFlow(List<Action> flow) {
    _currentFlow = flow;
  }
  
  /// Clear the current logic flow
  static void clear() {
    _currentFlow = [];
  }
  
  /// Infer all available variables from the entire current logic flow
  static List<String> inferAllVariables() {
    final vars = <String>{'url'};  // Built-in: url from share intent
    
    for (final action in _currentFlow) {
      _collectVariablesRecursive(action, vars);
    }
    
    return vars.toList()..sort();
  }
  
  /// Recursively collect variables from an action and its nested flows
  static void _collectVariablesRecursive(Action action, Set<String> vars) {
    if (action is FetchAction) {
      final v = action.targetVar;
      if (v.isNotEmpty) {
        vars.addAll([v, '$v.status', '$v.data', '$v.headers']);
      }
    } else if (action is ClipboardAction && action.mode == 'READ') {
      final v = action.targetVar;
      if (v.isNotEmpty) {
        vars.add(v);
      }
    } else if (action is ExpressionAction) {
      _parseExpressionVars(action.script, vars);
    } else if (action is IfAction) {
      // Include vars from both branches
      for (final a in action.trueFlow) {
        _collectVariablesRecursive(a, vars);
      }
      for (final a in action.falseFlow) {
        _collectVariablesRecursive(a, vars);
      }
    }
  }
  
  /// Parse Expression script to extract assigned variable names
  static void _parseExpressionVars(String script, Set<String> vars) {
    for (final line in script.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('//')) continue;
      
      if (trimmed.contains('=')) {
        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          var target = parts.first.trim();
          if (target.startsWith('\$')) {
            target = target.substring(1);
          }
          if (target.isNotEmpty && RegExp(r'^\w+$').hasMatch(target)) {
            vars.add(target);
          }
        }
      }
    }
  }
}
