import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import 'dsl_overlay.dart';

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
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _focusNode.hasFocus) {
          _showOverlay();
        }
      });
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
    
    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => DslOverlay.build(
        suggestions: _suggestions,
        onInsertSymbol: _insertSymbol,
        onApplySuggestion: _applySuggestion,
      ),
    );
    overlayState.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
    final parts = prefix.split(RegExp(r'[\s()+\-*/<>=!&|,]'));
    final lastWord = parts.isNotEmpty ? parts.last : '';

    List<DslSuggestion> suggestions;

    if (lastWord.startsWith('\$')) {
      suggestions = _getVariableSuggestions(lastWord.substring(1));
    } else if (_isInInterpolation(prefix)) {
      final varPath = lastWord.contains('\$') 
          ? lastWord.substring(lastWord.lastIndexOf('\$') + 1)
          : '';
      suggestions = _getVariableSuggestions(varPath);
    } else if (_isExpectOperator(prefix)) {
      suggestions = DslOverlay.operators
          .where((op) => lastWord.isEmpty || op.toUpperCase().startsWith(lastWord.toUpperCase()))
          .map((op) => DslSuggestion(display: op, insertText: ' $op ', type: DslSuggestionType.operator))
          .toList();
    } else {
      suggestions = _getDefaultSuggestions(filter: lastWord);
    }

    if (mounted) {
      setState(() => _suggestions = suggestions.take(10).toList());
      if (_overlayEntry == null && _focusNode.hasFocus) {
        _showOverlay();
      } else {
        _overlayEntry?.markNeedsBuild();
      }
    }
  }

  List<DslSuggestion> _getDefaultSuggestions({String filter = ''}) {
    final all = <DslSuggestion>[];
    for (final cmd in DslOverlay.commands) {
      if (filter.isEmpty || cmd.toUpperCase().startsWith(filter.toUpperCase())) {
        all.add(DslSuggestion(display: cmd, insertText: '$cmd ', type: DslSuggestionType.command));
      }
    }
    for (final kw in DslOverlay.keywords) {
      if (filter.isEmpty || kw.startsWith(filter.toLowerCase())) {
        all.add(DslSuggestion(display: kw, insertText: kw, type: DslSuggestionType.keyword));
      }
    }
    return all;
  }

  List<DslSuggestion> _getVariableSuggestions(String partialPath) {
    return widget.contextVariables
        .where((v) => partialPath.isEmpty || v.toLowerCase().contains(partialPath.toLowerCase()))
        .map((v) => DslSuggestion(display: v, insertText: v, type: DslSuggestionType.variable))
        .toList();
  }

  bool _isInInterpolation(String prefix) {
    final quoteCount = prefix.split('"').length - 1;
    if (quoteCount % 2 == 0) return false;
    return prefix.substring(prefix.lastIndexOf('"')).contains('\$');
  }

  bool _isExpectOperator(String prefix) {
    final trimmed = prefix.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.endsWith('"') || trimmed.endsWith(')')) return true;
    final lastToken = trimmed.split(RegExp(r'\s+')).last;
    return lastToken.startsWith('\$') ||
           RegExp(r'^-?\d+(\.\d+)?$').hasMatch(lastToken) ||
           lastToken == 'true' || lastToken == 'false';
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
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: replaceStart + insertText.length),
    );
    _focusNode.requestFocus();
    _updateSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enableDslInput) {
      return CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          height: widget.maxLines == 1 ? EditorInputTheme.height : null,
          decoration: const BoxDecoration(color: EditorInputTheme.fillColor),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            maxLines: widget.maxLines,
            minLines: widget.maxLines == null ? 4 : 1,
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
              height: widget.maxLines == 1 ? EditorInputTheme.height : null,
              decoration: const BoxDecoration(color: EditorInputTheme.fillColor),
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
