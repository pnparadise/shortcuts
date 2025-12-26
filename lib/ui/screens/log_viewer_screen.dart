import 'package:flutter/material.dart';
import '../../services/log_service.dart';
import '../theme/theme.dart';
import 'package:intl/intl.dart';

class LogViewerScreen extends StatefulWidget {
  final int logicId;
  final String title;

  const LogViewerScreen({
    super.key,
    required this.logicId,
    required this.title,
  });

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
         _isLoading = true;
         _error = null;
    });
    try {
        final logs = await LogService.getLogs(widget.logicId);
        if (mounted) {
          setState(() {
            _logs = logs;
            _isLoading = false;
          });
        }
    } catch (e) {
        if (mounted) {
            setState(() {
                _isLoading = false;
                _error = e.toString();
            });
        }
    }
  }

  Future<void> _clearLogs() async {
    await LogService.clearLogs(widget.logicId);
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Run Logs', style: AppStyles.headerStyle),
            Text('${widget.title} (ID: ${widget.logicId})', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textHeader),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.cardBg,
                  title: Text('Clear logs', style: TextStyle(color: AppColors.textHeader)),
                  content: Text('Clear all history for this widget?', style: TextStyle(color: AppColors.textBody)),
                  actions: [
                    TextButton(
                      child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    TextButton(
                      child: Text('Clear', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                _clearLogs();
              }
            },
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Load failed: $_error', style: const TextStyle(color: Colors.red))))
              : _logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text('No logs (#${widget.logicId})', style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final level = log['level'] ?? 'INFO';
                    final isError = level == 'ERROR';
                    final time = DateTime.fromMillisecondsSinceEpoch(log['timestamp'] as int);
                    final timeStr = DateFormat('HH:mm:ss.SSS').format(time);
                    final details = log['details'] as String?;
                    final widgetId = log['widgetId'] as int?;
                    final actionId = log['actionId'] as String?;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (widgetId != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text('W$widgetId', style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace')),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isError ? Colors.redAccent : AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(level, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Text(timeStr, style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontFamily: 'monospace')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            log['message'] ?? '',
                            style: TextStyle(
                              color: isError ? Colors.redAccent : AppColors.textBody,
                              fontSize: 14,
                            ),
                          ),
                          if (details != null && details.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F3FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                details,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
