import 'package:flutter/services.dart';

class LogService {
  static const MethodChannel _channel = MethodChannel('com.shortcuts.shortcuts/widget');

  static Future<List<Map<String, dynamic>>> getLogs(int logicId) async {
    final List<dynamic> result = await _channel.invokeMethod('getLogs', {'logicId': logicId});
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> clearLogs(int logicId) async {
    try {
      await _channel.invokeMethod('clearLogs', {'logicId': logicId});
    } on PlatformException catch (e) {
      print("Failed to clear logs: '${e.message}'.");
    }
  }

  static Future<void> deleteLogs(int logicId) async {
    try {
      await _channel.invokeMethod('deleteLogs', {'logicId': logicId});
    } on PlatformException catch (e) {
      print("Failed to delete logs: '${e.message}'.");
    }
  }
}
