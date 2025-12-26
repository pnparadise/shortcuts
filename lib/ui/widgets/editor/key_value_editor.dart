import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import 'editor_input.dart';

class KeyValueEditor extends StatefulWidget {
  final Map<String, String> items;
  final ValueChanged<Map<String, String>> onChanged;
  final String keyLabel;
  final String valueLabel;
  final List<String> keySuggestions;
  final List<String> Function(String key)? valueSuggestions;
  final bool enableDslValue;

  const KeyValueEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.keyLabel = "Key",
    this.valueLabel = "Value",
    this.keySuggestions = const [],
    this.valueSuggestions,
    this.enableDslValue = true,
  });

  @override
  State<KeyValueEditor> createState() => _KeyValueEditorState();
}

class _KeyValueEditorState extends State<KeyValueEditor> {
  late List<_ItemRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.items.entries
        .map((e) => _ItemRow(key: e.key, value: e.value))
        .toList();
    // Always keep an empty row at the end for adding new items
    if (_rows.isEmpty || _rows.last.key.isNotEmpty || _rows.last.value.isNotEmpty) {
      _rows.add(_ItemRow());
    }
  }

  void _update() {
    final Map<String, String> newItems = {};
    for (var row in _rows) {
      if (row.key.isNotEmpty) {
        newItems[row.key] = row.value;
      }
    }
    widget.onChanged(newItems);
  }

  void _onRowChanged(int index, String key, String value) {
    setState(() {
      _rows[index].key = key;
      _rows[index].value = value;
      
      // If editing last row and it's not empty anymore, add a new empty row
      if (index == _rows.length - 1 && (key.isNotEmpty || value.isNotEmpty)) {
        _rows.add(_ItemRow());
      }
    });
    _update();
  }

  void _deleteRow(int index) {
    setState(() {
      _rows.removeAt(index);
      if (_rows.isEmpty) {
        _rows.add(_ItemRow()); // Always have one
      }
    });
    _update();
  }

  Widget _buildValueField(int index) {
    final controller = TextEditingController(text: _rows[index].value)
      ..selection = TextSelection.collapsed(offset: _rows[index].value.length);

    return EditorTextField(
      controller: controller,
      hintText: widget.valueLabel,
      autofillHints: widget.valueSuggestions?.call(_rows[index].key) ?? const [],
      enableExpressionInput: widget.enableDslValue,
      onChanged: (v) => _onRowChanged(index, _rows[index].key, v),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: EditorTextField(
                    controller: TextEditingController(text: _rows[i].key)
                      ..selection = TextSelection.collapsed(offset: _rows[i].key.length),
                    hintText: widget.keyLabel,
                    autofillHints: widget.keySuggestions,
                    onChanged: (v) => _onRowChanged(i, v, _rows[i].value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildValueField(i),
                ),
                // Only show delete button for non-last rows or if it's the only row but has content
                if (i < _rows.length - 1)
                   IconButton(
                     icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                     onPressed: () => _deleteRow(i),
                   )
                else
                   const SizedBox(width: 48) // Placeholder for alignment
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemRow {
  String key;
  String value;
  _ItemRow({this.key = "", this.value = ""});
}

