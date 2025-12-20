import 'dart:convert';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';
import '../../models.dart';
import '../../theme.dart';
import '../variable_picker.dart';

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
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Scaffold(
          backgroundColor: AppColors.cardBg,
          appBar: AppBar(
            backgroundColor: AppColors.cardBg,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
                icon: const Icon(Icons.close, color: AppColors.textBody),
                onPressed: () => Navigator.pop(context),
            ),
            title: const Text("Configure Request", style: TextStyle(color: AppColors.textHeader, fontSize: 16, fontWeight: FontWeight.bold)),
            actions: [
                TextButton(
                    onPressed: _save,
                    child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
                )
            ],
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
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
      return ListView(
          padding: const EdgeInsets.all(20),
          children: [
              _buildSectionLabel("Method"),
              const SizedBox(height: 8),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                          value: _method,
                          isExpanded: true,
                          items: ["GET", "POST", "PUT", "DELETE", "PATCH"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (v) => setState(() => _method = v!),
                      ),
                  ),
              ),
              const SizedBox(height: 24),
              _buildSectionLabel("URL"),
              const SizedBox(height: 8),
              _buildTextFieldWithVar(_urlCtl, "https://api.example.com/v1/resource"),
              const SizedBox(height: 24),
              _buildSectionLabel("Target Variable"),
               const SizedBox(height: 8),
              _buildTextFieldWithVar(_targetCtl, "response"),
              const SizedBox(height: 8),
              const Text("Result will be stored in this variable (e.g. {{response.status}})", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
      );
  }

  Widget _buildHeadersTab() {
      return Stack(
          children: [
              ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                      if (_headers.isEmpty) 
                          const Center(
                              child: Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Text("No headers", style: TextStyle(color: Colors.grey)),
                              )
                          ),
                      ..._headers.entries.map((entry) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                              children: [
                                  Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(child: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () => setState(() => _headers.remove(entry.key)),
                                  )
                              ],
                          ),
                      )),
                      const SizedBox(height: 80), // Space for FAB
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
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  const Text("Request Body (JSON)", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                      child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                          ),
                          child: TextField(
                              controller: _bodyCtl,
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(fontFamily: "monospace", fontSize: 12),
                              decoration: const InputDecoration(border: InputBorder.none, hintText: "{\n  \"key\": \"value\"\n}"),
                          ),
                      ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                          icon: const Icon(Icons.data_object, size: 16),
                          label: const Text("Insert Variable"),
                          onPressed: () => VariablePicker.show(context, onSelect: (v) => _insertAtCursor(_bodyCtl, v)),
                      ),
                  )
              ],
          ),
      );
  }

  Widget _buildTestTab() {
      return Padding(
          padding: const EdgeInsets.all(20),
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
                          padding: const EdgeInsets.all(16),
                      ),
                      onPressed: _testing ? null : _runTest,
                  ),
                  const SizedBox(height: 24),
                  const Text("Response:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                      child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                              child: SelectableText(
                                  _testResult.isEmpty ? "No run data" : _testResult,
                                  style: const TextStyle(color: Colors.greenAccent, fontFamily: "monospace", fontSize: 12),
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

  Widget _buildSectionLabel(String text) {
      return Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBody));
  }

  Widget _buildTextFieldWithVar(TextEditingController ctl, String hint) {
      return TextField(
          controller: ctl,
          decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              isDense: true,
              suffixIcon: IconButton(
                  icon: const Icon(Icons.data_object, color: AppColors.primary),
                  onPressed: () => VariablePicker.show(context, onSelect: (v) => _insertAtCursor(ctl, v)),
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
