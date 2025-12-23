import 'dart:convert';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';
import '../../models.dart';
import '../theme/theme.dart';
import '../widgets/editor/editor_scaffold.dart';
import '../widgets/editor/editor_section.dart';
import '../widgets/editor/key_value_editor.dart';
import '../widgets/editor/editor_input.dart';

class FetchEditorSheet extends StatefulWidget {
  final FetchAction action;
  final ValueChanged<FetchAction> onSave;

  const FetchEditorSheet({super.key, required this.action, required this.onSave});

  @override
  State<FetchEditorSheet> createState() => _FetchEditorSheetState();
}

enum BodyType { none, json, formData }

class _FetchEditorSheetState extends State<FetchEditorSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _urlCtl;
  late TextEditingController _targetCtl;
  late TextEditingController _jsonBodyCtl;
  
  String _method = "GET";
  Map<String, String> _headers = {};
  Map<String, String> _queryParams = {};
  
  BodyType _bodyType = BodyType.none;
  Map<String, String> _formData = {};

  // Test Runner State
  bool _testing = false;
  Map<String, dynamic>? _testResultData;
  String _testError = "";

  static const platform = MethodChannel('com.example.lowcode/widget');

  static const List<String> _commonHeaders = [
    "Content-Type", "Accept", "Authorization", "User-Agent", "Cache-Control", 
    "X-Requested-With", "Host", "Connection", "Accept-Encoding", "Accept-Language",
    "Origin", "Referer", "Cookie", "Date", "If-Modified-Since"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _urlCtl = TextEditingController(text: widget.action.url);
    _targetCtl = TextEditingController(text: widget.action.targetVar);
    _jsonBodyCtl = TextEditingController();
    
    _method = widget.action.method;
    _headers = Map.from(widget.action.headers);

    // Initialize Body
    if (widget.action.body != null && widget.action.body!.isNotEmpty) {
      String? contentType = _headers.entries.firstWhere((e) => e.key.toLowerCase() == 'content-type', orElse: () => const MapEntry('', '')).value;
      
      if (contentType != null && contentType.contains('application/x-www-form-urlencoded')) {
        _bodyType = BodyType.formData;
        _formData = Uri.splitQueryString(widget.action.body!);
      } else {
        _bodyType = BodyType.json;
        _jsonBodyCtl.text = widget.action.body!;
      }
    }

    _parseUrlParams();
    _urlCtl.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    try {
      final uri = Uri.parse(_urlCtl.text);
      if (uri.hasQuery) {
        setState(() {
          _queryParams = Map.from(uri.queryParameters);
        });
      } else {
        if (_queryParams.isNotEmpty) {
           setState(() { _queryParams = {}; });
        }
      }
    } catch (e) {
      // Ignore invalid URL
    }
  }

  void _updateUrlFromParams() {
    try {
      final uri = Uri.parse(_urlCtl.text);
      final newUri = uri.replace(queryParameters: _queryParams.isEmpty ? null : _queryParams);
      
      final newText = newUri.toString();
      if (newText != _urlCtl.text) {
          _urlCtl.removeListener(_onUrlChanged);
          _urlCtl.text = newText;
          _urlCtl.addListener(_onUrlChanged);
      }
    } catch (e) {
      // Ignore
    }
  }

  void _parseUrlParams() {
    try {
      final uri = Uri.parse(widget.action.url);
      _queryParams = Map.from(uri.queryParameters);
    } catch (e) {
      _queryParams = {};
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlCtl.dispose();
    _targetCtl.dispose();
    _jsonBodyCtl.dispose();
    super.dispose();
  }

  String? _buildBody() {
    switch (_bodyType) {
      case BodyType.none: return null;
      case BodyType.json: return _jsonBodyCtl.text.isEmpty ? null : _jsonBodyCtl.text;
      case BodyType.formData: 
        if (_formData.isEmpty) return null;
        return Uri(queryParameters: _formData).query; 
    }
  }

  void _ensureContentType() {
    String ctKey = "Content-Type";
    String? existingKey = _headers.keys.firstWhere((k) => k.toLowerCase() == 'content-type', orElse: () => "");
    if (existingKey.isNotEmpty) ctKey = existingKey;

    if (_bodyType == BodyType.json) {
       if (!_headers.containsKey(ctKey)) {
         _headers[ctKey] = "application/json";
       }
    } else if (_bodyType == BodyType.formData) {
       if (!_headers.containsKey(ctKey)) {
         _headers[ctKey] = "application/x-www-form-urlencoded";
       }
    }
  }

  void _save() {
      _ensureContentType();
      widget.onSave(widget.action.copyWith(
          url: _urlCtl.text,
          method: _method,
          targetVar: _targetCtl.text.isEmpty ? "response" : _targetCtl.text,
          headers: _headers,
          body: _buildBody(),
      ));
      Navigator.pop(context);
  }

  Future<void> _runTest() async {
      setState(() { 
        _testing = true; 
        _testResultData = null; 
        _testError = ""; 
      });
      
      try {
          final body = _buildBody();
          final headers = Map<String, String>.from(_headers);
          
          if (_bodyType == BodyType.json && !headers.keys.any((k) => k.toLowerCase() == 'content-type')) {
             headers['Content-Type'] = 'application/json';
          } else if (_bodyType == BodyType.formData && !headers.keys.any((k) => k.toLowerCase() == 'content-type')) {
             headers['Content-Type'] = 'application/x-www-form-urlencoded';
          }

          final tempAction = widget.action.copyWith(
              url: _urlCtl.text,
              method: _method,
              headers: headers,
              body: body,
          );
          
          final result = await platform.invokeMethod('testAction', tempAction.toJson());
          setState(() {
              _testResultData = Map<String, dynamic>.from(result);
          });
      } on PlatformException catch (e) {
          setState(() => _testError = "Platform Error: ${e.message}");
      } catch (e) {
          setState(() => _testError = "Error: $e");
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
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: EditorSection(
                      title: "Method",
                      compact: true,
                      child: EditorSelectField<String>(
                        value: _method,
                        items: ["GET", "POST", "PUT", "DELETE", "PATCH"]
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setState(() => _method = v!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EditorSection(
                      title: "Target Variable Name",
                      compact: true,
                      child: EditorTextField(
                        controller: _targetCtl, 
                        hintText: "response",
                      ),
                    ),
                  ),
                ],
              ),
              EditorSection(
                  title: "URL",
                  compact: true,
                  child: EditorTextField(
                    controller: _urlCtl,
                    hintText: "https://api.example.com",
                    maxLines: null, // Allow wrapping but looks like input
                  ),
              ),
              EditorSection(
                  title: "Query Parameters",
                  hint: "Dynamic URL parameters",
                  compact: true,
                  child: KeyValueEditor(
                     items: _queryParams,
                     keyLabel: "Param",
                     valueLabel: "Value",
                     onChanged: (newParams) {
                        setState(() => _queryParams = newParams);
                        _updateUrlFromParams();
                     },
                  ),
              ),
          ],
      );
  }

  Widget _buildHeadersTab() {
      return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          children: [
              EditorSection(
                  title: "Request Headers",
                  hint: "Common headers like Content-Type, Authorization",
                  compact: true,
                  child: KeyValueEditor(
                      items: _headers,
                      keyLabel: "Header",
                      valueLabel: "Value",
                      keySuggestions: _commonHeaders,
                      valueSuggestions: (key) {
                        if (key.toLowerCase() == 'content-type') {
                          return const [
                            "application/json", 
                            "application/x-www-form-urlencoded", 
                            "multipart/form-data",
                            "text/plain",
                            "text/html",
                            "application/xml",
                            "application/javascript"
                          ];
                        }
                        return [];
                      },
                      onChanged: (newHeaders) => setState(() => _headers = newHeaders),
                  ),
              ),
          ],
      );
  }

  Widget _buildBodyTab() {
      return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          children: [
             EditorSection(
                 title: "Body Type",
                 compact: true,
                 child: SegmentedButton<BodyType>(
                    segments: const [
                       ButtonSegment(value: BodyType.none, label: Text("None")),
                       ButtonSegment(value: BodyType.json, label: Text("JSON")),
                       ButtonSegment(value: BodyType.formData, label: Text("Form Data")),
                    ],
                    selected: {_bodyType},
                    onSelectionChanged: (s) => setState(() => _bodyType = s.first),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                       visualDensity: VisualDensity.compact,
                       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                       shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                       backgroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) {
                             return AppColors.primary.withOpacity(0.2);
                          }
                          return AppColors.inputBg;
                       }),
                       foregroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) {
                             return AppColors.primary;
                          }
                          return AppColors.textBody;
                       }),
                    ),
                 ),
             ),
             const SizedBox(height: 16),
             if (_bodyType == BodyType.json)
                EditorSection(
                    title: "JSON Content",
                    compact: true,
                    child: EditorTextField(
                        controller: _jsonBodyCtl,
                        maxLines: 15, // TextArea mode
                        hintText: "{\n  \"key\": \"value\"\n}",
                    ),
                )
             else if (_bodyType == BodyType.formData)
                EditorSection(
                    title: "Form Data",
                    compact: true,
                    child: KeyValueEditor(
                        items: _formData,
                        keyLabel: "Field",
                        valueLabel: "Value",
                        onChanged: (newData) => setState(() => _formData = newData),
                    ),
                )
             else
                const Center(
                   child: Padding(
                     padding: EdgeInsets.all(32),
                     child: Text("No body will be sent.", style: TextStyle(color: AppColors.textMuted)),
                   ),
                ),
          ],
      );
  }

  Widget _buildTestTab() {
      // ... No text fields in test tab, just viewer ...
      // Keeping existing code for that part
      return Column(
          children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                      icon: _testing 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Icon(Icons.play_arrow),
                      label: Text(_testing ? "Sending Request..." : "Run Test"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _testing ? null : _runTest,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                  child: _buildTestResult(),
              ),
          ],
      );
  }
  
  Widget _buildTestResult() {
      if (_testing) {
          return const Center(child: Text("Waiting for response..."));
      }
      if (_testError.isNotEmpty) {
          return Center(
             child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_testError, style: const TextStyle(color: AppColors.danger)),
             )
          );
      }
      if (_testResultData == null) {
          return const Center(child: Text("Run a test to see results.", style: TextStyle(color: AppColors.textMuted)));
      }

      final status = _testResultData!['status'] as int? ?? 0;
      final headers = _testResultData!['headers'] as Map? ?? {};
      final data = _testResultData!['data'];
      
      Color statusColor = Colors.grey;
      if (status >= 200 && status < 300) statusColor = Colors.green;
      else if (status >= 400 && status < 500) statusColor = Colors.orange;
      else if (status >= 500) statusColor = Colors.red;

      String formattedBody = "null";
      try {
         formattedBody = const JsonEncoder.withIndent('  ').convert(data);
      } catch (e) {
         formattedBody = data.toString();
      }

      return ListView(
          padding: const EdgeInsets.all(16),
          children: [
              Row(
                 children: [
                    Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor),
                       ),
                       child: Text("Status: $status", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                 ],
              ),
              const SizedBox(height: 16),
              const Text("Response Body", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                    color: AppColors.codeBg,
                    borderRadius: BorderRadius.circular(8),
                 ),
                 child: SelectableText(
                    formattedBody,
                    style: const TextStyle(color: AppColors.codeText, fontFamily: "monospace", fontSize: 12),
                 ),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                  title: const Text("Response Headers", style: TextStyle(fontSize: 14)),
                  tilePadding: EdgeInsets.zero,
                  children: headers.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                             Expanded(flex: 1, child: Text(e.key.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                             Expanded(flex: 2, child: Text(e.value.toString(), style: const TextStyle(fontSize: 12))),
                         ],
                      ),
                  )).toList(),
              ),
          ],
      );
  }
}
