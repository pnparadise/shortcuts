import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Suggestion type for DSL completion items
enum DslSuggestionType { variable, command, operator, keyword }

/// Completion suggestion model for DSL input
class DslSuggestion {
  final String display;
  final String insertText;
  final DslSuggestionType type;

  const DslSuggestion({
    required this.display,
    required this.insertText,
    required this.type,
  });

  IconData get icon => switch (type) {
    DslSuggestionType.variable => Icons.attach_money,
    DslSuggestionType.command => Icons.terminal,
    DslSuggestionType.operator => Icons.compare_arrows,
    DslSuggestionType.keyword => Icons.key,
  };

  Color get color => switch (type) {
    DslSuggestionType.variable => const Color(0xFF0EA5E9),  // Sky blue
    DslSuggestionType.command => const Color(0xFF6366F1),   // Indigo
    DslSuggestionType.operator => const Color(0xFF64748B),  // Slate
    DslSuggestionType.keyword => const Color(0xFF8B5CF6),   // Violet
  };
}

/// DSL Overlay that appears above keyboard with quick symbols and suggestions
class DslOverlay {
  // DSL v2.0 Commands
  static const List<String> commands = [
    'GET_HOST', 'GET_PARAM', 'GET_PATH',
    'UPPER', 'LOWER', 'TRIM', 'LENGTH', 'REPLACE', 'SUBSTRING',
  ];

  // Infix operators
  static const List<String> operators = [
    'CONTAINS', 'STARTS_WITH', 'ENDS_WITH',
    '==', '!=', '&&', '||', '?:', '>', '<', '>=', '<=',
  ];

  // Keywords
  static const List<String> keywords = ['true', 'false', 'null'];

  // Quick symbols for mobile keyboard
  static const List<String> quickSymbols = ['\$', '.', '"', '=', '?:', '&&', '||', '(', ')'];

  /// Build the overlay widget
  static Widget build({
    required List<DslSuggestion> suggestions,
    required void Function(String symbol) onInsertSymbol,
    required void Function(DslSuggestion suggestion) onApplySuggestion,
  }) {
    return Builder(
      builder: (overlayContext) {
        final viewInsets = MediaQuery.of(overlayContext).viewInsets;
        final screenWidth = MediaQuery.of(overlayContext).size.width;
        
        return Positioned(
          left: 0,
          right: 0,
          bottom: viewInsets.bottom,
          child: Material(
            elevation: 8,
            color: AppColors.cardBg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 1, color: AppColors.border),
                // Quick symbol bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: quickSymbols.map((symbol) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => onInsertSymbol(symbol),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            symbol,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: AppColors.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                // Suggestions row - borderless blue style
                if (suggestions.isNotEmpty)
                  Container(
                    height: 44,
                    width: screenWidth,
                    color: AppColors.primary.withOpacity(0.05),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: suggestions.length,
                      itemBuilder: (ctx, index) {
                        final suggestion = suggestions[index];
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: InkWell(
                              onTap: () => onApplySuggestion(suggestion),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      suggestion.icon,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
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
          ),
        );
      },
    );
  }
}
