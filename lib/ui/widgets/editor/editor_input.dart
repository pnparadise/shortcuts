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

class EditorInputTheme {
  // Shared styling constants
  static const double height = 48.0;
  static const Color fillColor = AppColors.inputBg;
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 14);
  static const TextStyle textStyle = TextStyle(fontSize: 14, color: AppColors.textBody);
  static const TextStyle hintStyle = TextStyle(fontSize: 14, color: AppColors.textMuted);
}

class EditorTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool enableDslInput;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final Iterable<String> autofillHints;
  final List<String> contextVariables;

  const EditorTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.enableDslInput = false,
    this.maxLines = 1,
    this.onChanged,
    this.autofillHints = const [],
    this.contextVariables = const ['res', 'res.data', 'res.status', 'clip', 'url'],
  });

  @override
  State<EditorTextField> createState() => _EditorTextFieldState();
}

class _EditorTextFieldState extends State<EditorTextField> {
  late FocusNode _focusNode;
  List<DslSuggestion> _suggestions = [];
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  // DSL v2.0 Commands
  static const List<String> _commands = [
    'GET_HOST', 'GET_PARAM', 'GET_PATH',
    'UPPER', 'LOWER', 'TRIM', 'LENGTH', 'REPLACE', 'SUBSTRING',
  ];

  // Infix operators
  static const List<String> _operators = [
    'CONTAINS', 'STARTS_WITH', 'ENDS_WITH',
    '==', '!=', '&&', '||', '?:', '>', '<', '>=', '<=',
  ];

  // Keywords
  static const List<String> _keywords = ['true', 'false', 'null'];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    if (widget.enableDslInput) {
      widget.controller.addListener(_onTextChanged);
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    if (widget.enableDslInput) {
      widget.controller.removeListener(_onTextChanged);
      _focusNode.removeListener(_onFocusChanged);
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _updateSuggestions();
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onTextChanged() {
    _updateSuggestions();
    widget.onChanged?.call(widget.controller.text);
  }

  void _showOverlay() {
    if (_overlayEntry != null || !widget.enableDslInput) return;
    if (_suggestions.isEmpty) return;
    
    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildSuggestionsOverlay(),
    );
    
    overlayState.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsOverlay() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      width: MediaQuery.of(context).size.width,
      bottom: MediaQuery.of(context).viewInsets.bottom,
      child: Material(
        elevation: 8,
        color: AppColors.cardBg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 1, color: AppColors.border),
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.inputBg,
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _suggestions.length,
                itemBuilder: (ctx, index) {
                  final suggestion = _suggestions[index];
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => _applySuggestion(suggestion),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: suggestion.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: suggestion.color.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                suggestion.icon,
                                size: 14,
                                color: suggestion.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                suggestion.display,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  color: suggestion.color,
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
  }

  void _updateSuggestions() {
    if (!widget.enableDslInput) return;

    final text = widget.controller.text;
    final selection = widget.controller.selection;
    
    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      if (mounted) {
        setState(() => _suggestions = _getDefaultSuggestions());
        _overlayEntry?.markNeedsBuild();
      }
      return;
    }

    final cursorPos = selection.baseOffset;
    final prefix = text.substring(0, cursorPos);
    
    // Extract last word
    final parts = prefix.split(RegExp(r'[\s()+\-*/<>=!&|,]'));
    final lastWord = parts.isNotEmpty ? parts.last : '';

    List<DslSuggestion> suggestions;

    if (lastWord.startsWith('\$')) {
      // Variable completion
      final varPath = lastWord.substring(1);
      suggestions = _getVariableSuggestions(varPath);
    } else if (_isInInterpolation(prefix)) {
      // String interpolation
      final varPath = lastWord.contains('\$') 
          ? lastWord.substring(lastWord.lastIndexOf('\$') + 1)
          : '';
      suggestions = _getVariableSuggestions(varPath);
    } else if (_isExpectOperator(prefix)) {
      // Operator expected
      suggestions = _operators
          .where((op) => lastWord.isEmpty || op.toUpperCase().startsWith(lastWord.toUpperCase()))
          .map((op) => DslSuggestion(
            display: op,
            insertText: ' $op ',
            type: DslSuggestionType.operator,
          ))
          .toList();
    } else {
      // Default: commands and keywords
      suggestions = _getDefaultSuggestions(filter: lastWord);
    }

    if (mounted) {
      setState(() => _suggestions = suggestions.take(10).toList());
      if (_suggestions.isNotEmpty && _overlayEntry == null && _focusNode.hasFocus) {
        _showOverlay();
      } else if (_suggestions.isEmpty) {
        _removeOverlay();
      } else {
        _overlayEntry?.markNeedsBuild();
      }
    }
  }

  List<DslSuggestion> _getDefaultSuggestions({String filter = ''}) {
    final all = <DslSuggestion>[];

    // Commands
    for (final cmd in _commands) {
      if (filter.isEmpty || cmd.toUpperCase().startsWith(filter.toUpperCase())) {
        all.add(DslSuggestion(
          display: cmd,
          insertText: '$cmd ',
          type: DslSuggestionType.command,
        ));
      }
    }

    // Keywords
    for (final kw in _keywords) {
      if (filter.isEmpty || kw.startsWith(filter.toLowerCase())) {
        all.add(DslSuggestion(
          display: kw,
          insertText: kw,
          type: DslSuggestionType.keyword,
        ));
      }
    }

    return all;
  }

  List<DslSuggestion> _getVariableSuggestions(String partialPath) {
    return widget.contextVariables
        .where((v) => partialPath.isEmpty || v.toLowerCase().contains(partialPath.toLowerCase()))
        .map((v) => DslSuggestion(
          display: v,
          insertText: v,
          type: DslSuggestionType.variable,
        ))
        .toList();
  }

  bool _isInInterpolation(String prefix) {
    final quoteCount = prefix.split('"').length - 1;
    if (quoteCount % 2 == 0) return false;
    final lastQuoteIdx = prefix.lastIndexOf('"');
    return prefix.substring(lastQuoteIdx).contains('\$');
  }

  bool _isExpectOperator(String prefix) {
    final trimmed = prefix.trim();
    if (trimmed.isEmpty) return false;
    
    if (trimmed.endsWith('"') || trimmed.endsWith(')')) return true;
    
    final lastToken = trimmed.split(RegExp(r'\s+')).last;
    return lastToken.startsWith('\$') ||
           RegExp(r'^-?\d+(\.\d+)?$').hasMatch(lastToken) ||
           lastToken == 'true' ||
           lastToken == 'false';
  }

  void _applySuggestion(DslSuggestion suggestion) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) return;

    final beforeCursor = text.substring(0, cursorPos);
    final afterCursor = text.substring(cursorPos);

    int replaceStart = cursorPos;
    String insertText = suggestion.insertText;

    if (suggestion.type == DslSuggestionType.variable) {
      final dollarIdx = beforeCursor.lastIndexOf('\$');
      if (dollarIdx >= 0) {
        replaceStart = dollarIdx + 1;
      } else {
        replaceStart = cursorPos;
        insertText = '\$$insertText';
      }
    } else {
      final delimiters = RegExp(r'[\s()+\-*/<>=!&|,\$]');
      for (int i = cursorPos - 1; i >= 0; i--) {
        if (delimiters.hasMatch(text[i])) {
          replaceStart = i + 1;
          break;
        }
        if (i == 0) replaceStart = 0;
      }
    }

    final newText = text.substring(0, replaceStart) + insertText + afterCursor;
    final newCursor = replaceStart + insertText.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    // Keep focus but update suggestions
    _focusNode.requestFocus();
    _updateSuggestions();
  }

  void _insertAtCursor(String text) {
    final selection = widget.controller.selection;
    final currentText = widget.controller.text;
    final newText = selection.baseOffset >= 0
        ? currentText.replaceRange(selection.start, selection.end, text)
        : currentText + text;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (selection.baseOffset >= 0 ? selection.start : currentText.length) + text.length),
    );
    widget.onChanged?.call(newText);
  }

  @override
  Widget build(BuildContext context) {
    // If DSL input is enabled, use a simpler TextField with DSL overlay
    if (widget.enableDslInput) {
      return CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          height: widget.maxLines == 1 ? EditorInputTheme.height : null,
          decoration: BoxDecoration(
            color: EditorInputTheme.fillColor,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            maxLines: widget.maxLines,
            minLines: widget.maxLines == null ? 4 : 1,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: AppColors.textBody,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: EditorInputTheme.hintStyle,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EditorInputTheme.contentPadding,
              isDense: true,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      );
    }

    // Original Autocomplete-based implementation
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<String>(
           textEditingController: widget.controller,
           focusNode: _focusNode,
           optionsBuilder: (TextEditingValue textEditingValue) {
             if (textEditingValue.text == '') {
               return widget.autofillHints;
             }
             return widget.autofillHints.where((String option) {
               return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
             });
           },
           onSelected: (String selection) {
              widget.controller.text = selection;
              widget.onChanged?.call(selection);
           },
           fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              return Container(
                height: widget.maxLines == 1 ? EditorInputTheme.height : null,
                decoration: BoxDecoration(
                  color: EditorInputTheme.fillColor,
                  // No border, No radius
                ),
                child: TextField(
                  controller: widget.controller,
                  maxLines: widget.maxLines,
                  minLines: widget.maxLines == null ? 4 : 1,
                  style: EditorInputTheme.textStyle,
                  focusNode: widget.autofillHints.isNotEmpty ? focusNode : null,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: EditorInputTheme.hintStyle,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EditorInputTheme.contentPadding,
                    isDense: true,
                  ),
                  onChanged: widget.onChanged,
                ),
              );
           }
        );
      }
    );
  }
}


class EditorSelectField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;

  const EditorSelectField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: EditorInputTheme.height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: EditorInputTheme.fillColor,
        // No border, No radius
      ),
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          style: EditorInputTheme.textStyle,
          dropdownColor: AppColors.cardBg,
          hint: hintText != null ? Text(hintText!, style: EditorInputTheme.hintStyle) : null,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
