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

  static const platform = MethodChannel('com.shortcuts.shortcuts/widget');

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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                    lines: 2, // Allow wrapping but looks like input
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                        switch (key.toLowerCase()) {
                          case 'content-type':
                            return const [
                              "application/json", 
                              "application/x-www-form-urlencoded", 
                              "multipart/form-data",
                              "text/plain",
                              "text/html",
                              "application/xml",
                            ];
                          case 'accept':
                            return const [
                              "application/json",
                              "*/*",
                              "text/html",
                              "text/plain",
                              "application/xml",
                            ];
                          case 'authorization':
                            return const [
                              "Bearer ",
                              "Basic ",
                            ];
                          case 'cache-control':
                            return const [
                              "no-cache",
                              "no-store",
                              "max-age=0",
                              "max-age=3600",
                            ];
                          case 'connection':
                            return const ["keep-alive", "close"];
                          case 'accept-encoding':
                            return const ["gzip, deflate, br", "gzip", "identity"];
                          case 'accept-language':
                            return const ["zh-CN,zh;q=0.9,en;q=0.8", "en-US,en;q=0.9"];
                          default:
                            return [];
                        }
                      },
                      onChanged: (newHeaders) => setState(() => _headers = newHeaders),
                   ),
              ),
          ],
      );
  }

  Widget _buildBodyTab() {
      return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
             const SizedBox(height: 8),
             if (_bodyType == BodyType.json)
                EditorSection(
                    title: "JSON Content",
                    compact: true,
                    child: EditorTextField(
                        controller: _jsonBodyCtl,
                        lines: 10, // TextArea mode
                        hintText: "{\n  \"key\": \"value\"\n}",
                        enableExpressionInput: true,
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
      return Column(
          children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                        icon: _testing 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
                            : const Icon(Icons.play_arrow, size: 18),
                        label: Text(_testing ? "Testing..." : "Run Test", style: const TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: _testing ? null : _runTest,
                    ),
                    const Spacer(),
                    if (_testResultData != null) ...[
                      _buildStatusBadge(),
                    ],
                  ],
                ),
              ),
              Expanded(
                  child: _buildTestResult(),
              ),
          ],
      );
  }

  Widget _buildStatusBadge() {
    final status = _testResultData?['status'] as int? ?? 0;
    Color statusColor = Colors.grey;
    if (status >= 200 && status < 300) {
      statusColor = Colors.green;
    } else if (status >= 400 && status < 500) {
      statusColor = Colors.orange;
    } else if (status >= 500) {
      statusColor = Colors.red;
    }
    
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
       decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor),
       ),
       child: Text("$status", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
  
  Widget _buildTestResult() {
      if (_testing) {
          return const Center(child: Text("Waiting for response...", style: TextStyle(color: AppColors.textMuted)));
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

      return LayoutBuilder(
        builder: (context, constraints) => Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(minWidth: constraints.maxWidth - 32),
          decoration: const BoxDecoration(
              color: AppColors.inputBg,
          ),
          child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicWidth(
                  child: _JsonNode(data: _testResultData, indent: 0),
              ),
          ),
        ),
      );
  }
}

// Collapsible JSON viewer widget
class _JsonNode extends StatefulWidget {
  final dynamic data;
  final int indent;
  final String? keyName;

  const _JsonNode({required this.data, this.indent = 0, this.keyName});

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  bool _expanded = true;

  static const _keyStyle = TextStyle(color: Color(0xFF0066CC), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600);
  static const _stringStyle = TextStyle(color: Color(0xFF067D17), fontFamily: 'monospace', fontSize: 12);
  static const _numberStyle = TextStyle(color: Color(0xFF1750EB), fontFamily: 'monospace', fontSize: 12);
  static const _boolStyle = TextStyle(color: Color(0xFF0033B3), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600);
  static const _nullStyle = TextStyle(color: Color(0xFF808080), fontFamily: 'monospace', fontSize: 12, fontStyle: FontStyle.italic);
  static const _braceStyle = TextStyle(color: Color(0xFF333333), fontFamily: 'monospace', fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    if (data is Map) {
      final entries = data.entries.toList();
      if (data.isEmpty) {
        return _buildLine(widget.keyName, '{}');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: _buildLine(widget.keyName, _expanded ? '{' : '{...}', suffix: !_expanded ? ' // ${data.length}' : null),
          ),
          if (_expanded) ...[
            ...entries.asMap().entries.map((e) {
              final isLast = e.key == entries.length - 1;
              return Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: _JsonNodeWithComma(data: e.value.value, keyName: e.value.key.toString(), showComma: !isLast),
              );
            }),
            const Text('}', style: _braceStyle),
          ],
        ],
      );
    } else if (data is List) {
      if (data.isEmpty) {
        return _buildLine(widget.keyName, '[]');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: _buildLine(widget.keyName, _expanded ? '[' : '[...]', suffix: !_expanded ? ' // ${data.length}' : null),
          ),
          if (_expanded) ...[
            ...data.asMap().entries.map((e) {
              final isLast = e.key == data.length - 1;
              return Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: _JsonNodeWithComma(data: e.value, showComma: !isLast),
              );
            }),
            const Text(']', style: _braceStyle),
          ],
        ],
      );
    } else {
      // Primitive value
      String valueText;
      TextStyle valueStyle;
      if (data is String) {
        valueStyle = _stringStyle;
        valueText = '"$data"';
      } else if (data is num) {
        valueStyle = _numberStyle;
        valueText = data.toString();
      } else if (data is bool) {
        valueStyle = _boolStyle;
        valueText = data.toString();
      } else {
        valueStyle = _nullStyle;
        valueText = 'null';
      }
      
      return Row(
        children: [
          if (widget.keyName != null) Text('"${widget.keyName}": ', style: _keyStyle),
          SelectableText(valueText, style: valueStyle),
        ],
      );
    }
  }

  Widget _buildLine(String? key, String bracket, {String? suffix}) {
    return Row(
      children: [
        if (key != null) Text('"$key": ', style: _keyStyle),
        Text(bracket, style: _braceStyle),
        if (suffix != null) Text(suffix, style: _nullStyle),
      ],
    );
  }
}

class _JsonNodeWithComma extends StatelessWidget {
  final dynamic data;
  final String? keyName;
  final bool showComma;

  const _JsonNodeWithComma({required this.data, this.keyName, this.showComma = false});

  @override
  Widget build(BuildContext context) {
    // For objects/arrays, comma goes after the closing bracket - handled by parent
    // For primitives, add comma inline
    if (data is Map || data is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _JsonNode(data: data, keyName: keyName),
          if (showComma) ...[],  // Comma will be on the closing bracket line
        ],
      );
    }
    
    // Primitive - add comma inline
    String valueText;
    TextStyle valueStyle;
    if (data is String) {
      valueStyle = const TextStyle(color: Color(0xFF067D17), fontFamily: 'monospace', fontSize: 12);
      valueText = '"$data"';
    } else if (data is num) {
      valueStyle = const TextStyle(color: Color(0xFF1750EB), fontFamily: 'monospace', fontSize: 12);
      valueText = data.toString();
    } else if (data is bool) {
      valueStyle = const TextStyle(color: Color(0xFF0033B3), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600);
      valueText = data.toString();
    } else {
      valueStyle = const TextStyle(color: Color(0xFF808080), fontFamily: 'monospace', fontSize: 12, fontStyle: FontStyle.italic);
      valueText = 'null';
    }
    
    const keyStyle = TextStyle(color: Color(0xFF0066CC), fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600);
    const braceStyle = TextStyle(color: Color(0xFF333333), fontFamily: 'monospace', fontSize: 12);
    
    return Row(
      children: [
        if (keyName != null) Text('"$keyName": ', style: keyStyle),
        SelectableText(valueText, style: valueStyle),
        if (showComma) const Text(',', style: braceStyle),
      ],
    );
  }
}


