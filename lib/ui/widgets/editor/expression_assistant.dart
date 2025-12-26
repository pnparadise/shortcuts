import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/theme.dart';
import '../../../utils/variable_inferrer.dart';

/// Suggestion type for Expression Assistant completion items
enum ExpressionSuggestionType { variable, command, operator, keyword }

/// Completion suggestion model for Expression Assistant input
class ExpressionSuggestion {
  final String display;
  final String insertText;
  final ExpressionSuggestionType type;
  final int replaceStart;
  final int replaceEnd;

  const ExpressionSuggestion({
    required this.display,
    required this.insertText,
    required this.type,
    required this.replaceStart,
    required this.replaceEnd,
  });

  IconData? get icon => switch (type) {
    ExpressionSuggestionType.variable => null,
    ExpressionSuggestionType.command => Icons.terminal,
    ExpressionSuggestionType.operator => null,
    ExpressionSuggestionType.keyword => null,
  };

  Color get color => switch (type) {
    ExpressionSuggestionType.variable => const Color(0xFF0EA5E9),
    ExpressionSuggestionType.command => const Color(0xFF6366F1),
    ExpressionSuggestionType.operator => const Color(0xFF64748B),
    ExpressionSuggestionType.keyword => const Color(0xFF8B5CF6),
  };
}

/// Controller for managing Expression Assistant panel state across widgets
class ExpressionAssistantController extends ChangeNotifier {
  List<ExpressionSuggestion> _suggestions = [];
  bool _isActive = false;
  void Function(String)? _onInsertSymbol;
  void Function(ExpressionSuggestion)? _onApplySuggestion;

  bool get isActive => _isActive;
  List<ExpressionSuggestion> get suggestions => _suggestions;
  void Function(String)? get onInsertSymbol => _onInsertSymbol;
  void Function(ExpressionSuggestion)? get onApplySuggestion => _onApplySuggestion;


  // No fallback/quick symbols needed since Native Engine is source of truth
  
  /// Generate suggestions based on current text and cursor position
  Future<void> generateSuggestions(String text, TextSelection selection) async {
    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _suggestions = [];
      notifyListeners();
      return;
    }

    try {
      final variables = LogicContext.inferAllVariables();
      const channel = MethodChannel('com.shortcuts.shortcuts/widget');
      final List<dynamic>? result = await channel.invokeMethod('getDslSuggestions', {
        'text': text,
        'cursorIndex': selection.baseOffset,
        'variables': variables,
      });

      if (result != null) {
        _suggestions = result.map((item) {
          final map = Map<String, dynamic>.from(item);
          final typeStr = map['type'] as String;
          return ExpressionSuggestion(
            display: map['display'],
            insertText: map['insertText'],
            type: ExpressionSuggestionType.values.firstWhere(
              (e) => e.name.toUpperCase() == typeStr,
              orElse: () => ExpressionSuggestionType.keyword
            ),
            replaceStart: map['replaceStart'] as int,
            replaceEnd: map['replaceEnd'] as int,
          );
        }).toList();
      } else {
        _suggestions = [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('DSL Engine Error: $e');
      _suggestions = [];
      notifyListeners();
    }
  }

  void show({
    required void Function(String) onInsertSymbol,
    required void Function(ExpressionSuggestion) onApplySuggestion,
  }) {
    _onInsertSymbol = onInsertSymbol;
    _onApplySuggestion = onApplySuggestion;
    _isActive = true;
    notifyListeners();
  }

  void updateSuggestions(List<ExpressionSuggestion> suggestions) {
    _suggestions = suggestions;
    notifyListeners();
  }

  void hide() {
    _isActive = false;
    _suggestions = [];
    _onInsertSymbol = null;
    _onApplySuggestion = null;
    notifyListeners();
  }

  /// Build the Assistant panel widget
  Widget buildPanel() {
    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Material(
          elevation: 8,
          color: AppColors.cardBg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Suggestions row
              if (_suggestions.isNotEmpty)
                Container(
                  height: 44,
                  width: screenWidth,
                  color: AppColors.primary.withOpacity(0.05),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _suggestions.length,
                    itemBuilder: (ctx, index) {
                      final suggestion = _suggestions[index];
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: InkWell(
                            onTap: () => _onApplySuggestion?.call(suggestion),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (suggestion.icon != null) ...[
                                    Icon(
                                      suggestion.icon,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    suggestion.display,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// InheritedWidget to provide ExpressionAssistantController down the tree
class ExpressionAssistantScope extends InheritedNotifier<ExpressionAssistantController> {
  const ExpressionAssistantScope({
    super.key,
    required ExpressionAssistantController controller,
    required super.child,
  }) : super(notifier: controller);

  static ExpressionAssistantController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ExpressionAssistantScope>()?.notifier;
  }

  static ExpressionAssistantController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ExpressionAssistantScope>()?.notifier;
  }
}
