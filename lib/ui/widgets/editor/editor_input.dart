import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import 'expression_assistant.dart';

class EditorInputTheme {
  static const double height = 48.0;
  static const Color fillColor = AppColors.inputBg;
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 14);
  static const TextStyle textStyle = TextStyle(fontSize: 14, color: AppColors.textBody);
  static const TextStyle hintStyle = TextStyle(fontSize: 14, color: AppColors.textMuted);
}

class EditorTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool enableExpressionInput;
  /// Number of lines to display. Default 1 (single line).
  /// When > 1, field auto-expands with this as minimum height.
  final int lines;
  final ValueChanged<String>? onChanged;
  final Iterable<String> autofillHints;

  const EditorTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.enableExpressionInput = false,
    this.lines = 1,
    this.onChanged,
    this.autofillHints = const [],
  });

  @override
  State<EditorTextField> createState() => _EditorTextFieldState();
}

class _EditorTextFieldState extends State<EditorTextField> with WidgetsBindingObserver {
  late FocusNode _focusNode;
  bool _keyboardVisible = false;
  ExpressionAssistantController? _assistantController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    if (widget.enableExpressionInput) {
      widget.controller.addListener(_onTextChanged);
      _focusNode.addListener(_onFocusChanged);
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _assistantController = ExpressionAssistantScope.maybeOf(context);
  }

  @override
  void dispose() {
    // Schedule hide for next frame to avoid calling notifyListeners during dispose
    final controller = _assistantController;
    if (controller?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller?.hide();
      });
    }
    if (widget.enableExpressionInput) {
      widget.controller.removeListener(_onTextChanged);
      _focusNode.removeListener(_onFocusChanged);
      WidgetsBinding.instance.removeObserver(this);
    }
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!widget.enableExpressionInput) return;
    
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;
    
    if (isKeyboardVisible != _keyboardVisible) {
      _keyboardVisible = isKeyboardVisible;
      if (_keyboardVisible && _focusNode.hasFocus) {
        // Ensure we have controller
        _assistantController ??= ExpressionAssistantScope.maybeOf(context);
        _showAssistantPanel();
      } else if (!_keyboardVisible) {
        _hideAssistantPanel();
      }
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Check if keyboard is visible when gaining focus
      final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
      if (bottomInset > 0) {
        _keyboardVisible = true;
        _showAssistantPanel();
      }
    } else {
      _hideAssistantPanel();
    }
  }

  void _onTextChanged() {
    _updateSuggestions();
    widget.onChanged?.call(widget.controller.text);
  }

  void _showAssistantPanel() {
    if (!widget.enableExpressionInput) return;
    // Ensure we have the controller
    _assistantController ??= ExpressionAssistantScope.maybeOf(context);
    if (_assistantController == null) return;
    
    _assistantController!.show(
      onInsertSymbol: _insertSymbol,
      onApplySuggestion: _applySuggestion,
    );
    _updateSuggestions();
  }

  void _hideAssistantPanel() {
    _assistantController?.hide();
  }

  void _insertSymbol(String symbol) {
    final pos = widget.controller.selection.baseOffset;
    final text = widget.controller.text;
    
    String insertText = symbol;
    int cursorOffset = symbol.length;
    
    if (symbol == '"') {
      final beforeCursor = pos >= 0 ? text.substring(0, pos) : text;
      final quoteCount = beforeCursor.split('"').length - 1;
      if (quoteCount % 2 == 0) {
        insertText = '""';
        cursorOffset = 1;
      }
    }
    
    final newText = pos >= 0 
        ? text.substring(0, pos) + insertText + text.substring(pos)
        : text + insertText;
    
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (pos >= 0 ? pos : text.length) + cursorOffset),
    );
    _focusNode.requestFocus();
  }

  void _updateSuggestions() {
    if (!widget.enableExpressionInput) return;

    if (_assistantController == null) {
      _assistantController = ExpressionAssistantScope.maybeOf(context);
    }
    
    // Delegate suggestion generation to the engine
    if (_assistantController != null) {
      _assistantController!.generateSuggestions(
        widget.controller.text, 
        widget.controller.selection
      );
    }
  }

  void _applySuggestion(ExpressionSuggestion suggestion) {
    final text = widget.controller.text;
    
    // Use replacement range provided exclusively by the native engine
    final int start = suggestion.replaceStart;
    final int end = suggestion.replaceEnd;
    
    if (start < 0 || start > text.length || end < start || end > text.length) {
      return; 
    }

    final newText = text.replaceRange(start, end, suggestion.insertText);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + suggestion.insertText.length),
    );
    
    _focusNode.requestFocus();
    _updateSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enableExpressionInput) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: const BoxDecoration(color: EditorInputTheme.fillColor),
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: IntrinsicWidth(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      maxLines: widget.lines == 1 ? 1 : null,
                      minLines: widget.lines,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: AppColors.textBody),
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
                ),
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: (textEditingValue) {
            // Show all options when empty, filter when typing
            if (textEditingValue.text.isEmpty) {
              return widget.autofillHints;
            }
            return widget.autofillHints.where((opt) => opt.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (selection) {
            widget.controller.text = selection;
            widget.onChanged?.call(selection);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: AppColors.cardBg,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: options.map((opt) => InkWell(
                        onTap: () => onSelected(opt),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(
                            opt,
                            style: EditorInputTheme.textStyle,
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return Container(
              height: widget.lines == 1 ? EditorInputTheme.height : null,
              decoration: const BoxDecoration(color: EditorInputTheme.fillColor),
              child: TextField(
                controller: widget.controller,
                maxLines: widget.lines == 1 ? 1 : null,
                minLines: widget.lines,
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
          },
        );
      },
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
      decoration: const BoxDecoration(color: EditorInputTheme.fillColor),
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
