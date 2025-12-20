import 'dart:convert';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';
import '../../models.dart';
import '../../theme.dart';
import '../variable_picker.dart';
import 'editor_ui.dart';

class FetchEditorSheet extends StatefulWidget {
  final FetchAction action;
  final ValueChanged<FetchAction> onSave;

  const FetchEditorSheet({super.key, required this.action, required this.onSave});

  @override
  State<FetchEditorSheet> createState() => _FetchEditorSheetState();
}

class _FetchEditorSheetState extends State<FetchEditorSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _urlCtl;
  late TextEditingController _targetCtl;
  late TextEditingController _bodyCtl;
  
  String _method = "GET";
  Map<String, String> _headers = {};

  // Test Runner State
  bool _testing = false;
  String _testResult = "";

  static const platform = MethodChannel('com.example.lowcode/widget');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _urlCtl = TextEditingController(text: widget.action.url);
    _targetCtl = TextEditingController(text: widget.action.targetVar);
    _bodyCtl = TextEditingController(text: widget.action.body);
    _method = widget.action.method;
    _headers = Map.from(widget.action.headers);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlCtl.dispose();
    _targetCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
  }

  void _save() {
      widget.onSave(widget.action.copyWith(
          url: _urlCtl.text,
          method: _method,
          targetVar: _targetCtl.text.isEmpty ? "response" : _targetCtl.text,
          headers: _headers,
          body: _bodyCtl.text.isEmpty ? null : _bodyCtl.text,
      ));
      Navigator.pop(context);
  }

  Future<void> _runTest() async {
      setState(() { _testing = true; _testResult = "Running..."; });
      try {
          // Serialize current state as standard action
          final tempAction = widget.action.copyWith(
              url: _urlCtl.text,
              method: _method,
              headers: _headers,
              body: _bodyCtl.text.isEmpty ? null : _bodyCtl.text,
          );
          
          final result = await platform.invokeMethod('testAction', tempAction.toJson());
          setState(() {
              _testResult = const JsonEncoder.withIndent('  ').convert(result);
          });
      } on PlatformException catch (e) {
          setState(() => _testResult = "Error: ${e.message}");
      } catch (e) {
          setState(() => _testResult = "Error: $e");
      } finally {
          setState(() => _testing = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return EditorSheetScaffold(
        title: "Configure Request",
        onSave: _save,
        heightFactor: 0.9,
        bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textBody,
            indicatorColor: AppColors.primary,
            tabs: const [
                Tab(text: "General"),
                Tab(text: "Headers"),
                Tab(text: "Body"),
                Tab(text: "Test"),
            ],
        ),
        body: TabBarView(
            controller: _tabController,
            children: [
                _buildGeneralTab(),
                _buildHeadersTab(),
                _buildBodyTab(),
                _buildTestTab(),
            ],
        ),
    );
  }

  Widget _buildGeneralTab() {
      return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          children: [
              EditorSection(
                  title: "Method",
                  compact: true,
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                              value: _method,
                              isExpanded: true,
                              isDense: true,
                              items: ["GET", "POST", "PUT", "DELETE", "PATCH"]
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (v) => setState(() => _method = v!),
                          ),
                      ),
                  ),
              ),
              EditorSection(
                  title: "URL",
                  compact: true,
                  child: _buildTextFieldWithVar(_urlCtl, "https://api.example.com/v1/resource"),
              ),
              EditorSection(
                  title: "Target Variable",
                  hint: "Result will be stored here (e.g. {{response.status}}).",
                  compact: true,
                  child: _buildTextFieldWithVar(_targetCtl, "response"),
              ),
          ],
      );
  }

  Widget _buildHeadersTab() {
      return Stack(
          children: [
              ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  children: [
                      EditorSection(
                          title: "Headers",
                          hint: "Add key/value pairs for your request.",
                          compact: true,
                          child: Column(
                              children: [
                                  if (_headers.isEmpty)
                                      const Padding(
                                          padding: EdgeInsets.only(top: 12),
                                          child: Text("No headers yet", style: TextStyle(color: AppColors.textMuted)),
                                      ),
                                  ..._headers.entries.map((entry) => Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: AppColors.inputBg,
                                          border: Border.all(color: AppColors.border),
                                          borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                          children: [
                                              Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold))),
                                              Expanded(child: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                              IconButton(
                                                  icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                                                  onPressed: () => setState(() => _headers.remove(entry.key)),
                                              )
                                          ],
                                      ),
                                  )),
                              ],
                          ),
                      ),
                      const SizedBox(height: 64), // Space for FAB
                  ],
              ),
              Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton(
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.add),
                      onPressed: () => _showAddHeaderDialog(),
                  ),
              )
          ],
      );
  }

  Widget _buildBodyTab() {
      return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  EditorSection(
                      title: "Request Body (JSON)",
                      hint: "Optional. Supports variables.",
                      compact: true,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              SizedBox(
                                  height: 200,
                                  child: TextField(
                                      controller: _bodyCtl,
                                      maxLines: null,
                                      expands: true,
                                      style: const TextStyle(fontFamily: "monospace", fontSize: 12),
                                      decoration: editorInputDecoration(
                                          hintText: "{\n  \"key\": \"value\"\n}",
                                      ),
                                  ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                      icon: const Icon(Icons.data_object, size: 16),
                                      label: const Text("Insert Variable"),
                                      onPressed: () => VariablePicker.show(
                                          context,
                                          onSelect: (v) => _insertAtCursor(_bodyCtl, v),
                                      ),
                                  ),
                              ),
                          ],
                      ),
                  ),
              ],
          ),
      );
  }

  Widget _buildTestTab() {
      return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  ElevatedButton.icon(
                      icon: _testing 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Icon(Icons.play_arrow),
                      label: Text(_testing ? "Running..." : "Test Request"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _testing ? null : _runTest,
                  ),
                  const SizedBox(height: 16),
                  const Text("Response", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                      child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: AppColors.codeBg,
                              borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                              child: SelectableText(
                                  _testResult.isEmpty ? "No run data" : _testResult,
                                  style: const TextStyle(color: AppColors.codeText, fontFamily: "monospace", fontSize: 12),
                              ),
                          ),
                      ),
                  ),
              ],
          ),
      );
  }

  void _showAddHeaderDialog() {
      String k = "", v = "";
      showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text("Add Header"),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  TextField(decoration: const InputDecoration(labelText: "Key"), onChanged: (s) => k = s),
                  TextField(decoration: const InputDecoration(labelText: "Value"), onChanged: (s) => v = s),
              ],
          ),
          actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              TextButton(onPressed: () {
                  if (k.isNotEmpty) setState(() => _headers[k] = v);
                  Navigator.pop(context);
              }, child: const Text("Add")),
          ],
      ));
  }

  Widget _buildTextFieldWithVar(TextEditingController ctl, String hint) {
      return TextField(
          controller: ctl,
          decoration: editorInputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.data_object, color: AppColors.primary),
                  onPressed: () => VariablePicker.show(
                      context,
                      onSelect: (v) => _insertAtCursor(ctl, v),
                  ),
              ),
          ),
      );
  }

  void _insertAtCursor(TextEditingController controller, String text) {
      final selection = controller.selection;
      final currentText = controller.text;
      final newText = selection.baseOffset >= 0
          ? currentText.replaceRange(selection.start, selection.end, text)
          : currentText + text;
      controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: (selection.baseOffset >= 0 ? selection.start : currentText.length) + text.length),
      );
  }
}
