import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../pickers/variable_picker.dart';

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
  final bool enableVariablePicker;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final Iterable<String> autofillHints;

  const EditorTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.enableVariablePicker = true,
    this.maxLines = 1,
    this.onChanged,
    this.autofillHints = const [],
  });

  @override
  State<EditorTextField> createState() => _EditorTextFieldState();
}

class _EditorTextFieldState extends State<EditorTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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
                child: Row(
                  crossAxisAlignment: widget.maxLines == 1 ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                    ),
                    if (widget.enableVariablePicker)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: const Icon(Icons.data_object, color: AppColors.primary, size: 20),
                          onPressed: () => VariablePicker.show(context, onSelect: _insertAtCursor),
                          tooltip: "Insert Variable",
                        ),
                      ),
                  ],
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
