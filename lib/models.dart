import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

String _newId() => "${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}";

// Must sync with android/app/src/main/kotlin/com/shortcuts/shortcuts/data/WidgetDefinition.kt (IconEnum)
class IconMap {
  static const Map<String, IconData> icons = {
    'TERMINAL': Icons.play_arrow, // Play Triangle
    'CLOUD': Icons.refresh, // Refresh/Sync
    'BOLT': Icons.power_settings_new, // Power Button/Trigger
    'DATABASE': Icons.vpn_key, // Key/Secure
  };
  
  static IconData getIcon(String id) => icons[id] ?? Icons.help_outline;
}


abstract class Action {
  String get type;
  String get id;
  Map<String, dynamic> toJson();

  static List<Action> fromJsonList(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => Action.fromJson(e)).toList();
  }

  static Action fromJson(Map<String, dynamic> json) {
    String? type = json['type'];
    
    // Type Inference for Legacy Data
    if (type == null) {
        if (json.containsKey('url') || json.containsKey('method')) {
            type = 'Fetch';
        } else if (json.containsKey('conditionExpression')) {
            type = 'If';
        } else if (json.containsKey('messageTemplate')) {
            type = 'Toast';
        } else if (json.containsKey('textTemplate')) {
            type = 'SetView';
        }
    }

    switch (type) {
      case 'Fetch':
      case 'fetch': // Handle casing
        return FetchAction.fromJson(json);
      case 'If':
      case 'if':
        return IfAction.fromJson(json);
      case 'SetView':
      case 'setView':
        return SetViewAction.fromJson(json);
      case 'Toast':
      case 'toast':
        return ToastAction.fromJson(json);
      case 'Clipboard':
      case 'clipboard':
        return ClipboardAction.fromJson(json);
      case 'Intent':
      case 'intent':
        return IntentAction.fromJson(json);
      case 'Return':
      case 'return':
        return ReturnAction.fromJson(json);
      case 'Notification':
      case 'notification':
        return NotificationAction.fromJson(json);
      case 'Expression':
      case 'expression':
        return ExpressionAction.fromJson(json);
      default:
        // Return dummy/empty or throw? 
        // Throwing breaks the whole list. Better to return a Toast with error?
        // Or just throw and let valid items show? No, fromJsonList maps.
        debugPrint("Unknown Action Type: $type in $json");
        return ToastAction(messageTemplate: "Error: Unknown Action Type");
    }
  }
}

class FetchAction extends Action {
  final String id;
  final String url;
  final String method;
  final String targetVar;
  final Map<String, String> headers;
  final String? body;

  FetchAction({
    String? id,
    this.url = '',
    this.method = 'GET',
    this.targetVar = 'response',
    this.headers = const {},
    this.body,
  }) : id = id ?? _newId();

  @override
  String get type => 'Fetch';

  factory FetchAction.fromJson(Map<String, dynamic> json) {
    return FetchAction(
      id: json['id'],
      url: json['url'] ?? '',
      method: json['method'] ?? 'GET',
      targetVar: json['targetVar'] ?? 'response',
      headers: (json['headers'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? const {},
      body: json['body'],
    );
  }

  FetchAction copyWith({
    String? id,
    String? url,
    String? method,
    String? targetVar,
    Map<String, String>? headers,
    String? body,
  }) {
    return FetchAction(
      id: id ?? this.id,
      url: url ?? this.url,
      method: method ?? this.method,
      targetVar: targetVar ?? this.targetVar,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'url': url,
        'method': method,
        'targetVar': targetVar,
        'headers': headers,
        'body': body,
      };
}

class IfAction extends Action {
  final String id;
  final String conditionExpression;
  final List<Action> trueFlow;
  final List<Action> falseFlow;

  IfAction({
    String? id,
    this.conditionExpression = '',
    this.trueFlow = const [],
    this.falseFlow = const [],
  }) : id = id ?? _newId();

  @override
  String get type => 'If';

  factory IfAction.fromJson(Map<String, dynamic> json) {
    return IfAction(
      id: json['id'],
      conditionExpression: json['conditionExpression'] ?? '',
      trueFlow: (json['trueFlow'] as List?)?.map((e) => Action.fromJson(e)).toList() ?? [],
      falseFlow: (json['falseFlow'] as List?)?.map((e) => Action.fromJson(e)).toList() ?? [],
    );
  }

  IfAction copyWith({
    String? id,
    String? conditionExpression,
    List<Action>? trueFlow,
    List<Action>? falseFlow,
  }) {
    return IfAction(
      id: id ?? this.id,
      conditionExpression: conditionExpression ?? this.conditionExpression,
      trueFlow: trueFlow ?? this.trueFlow,
      falseFlow: falseFlow ?? this.falseFlow,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'conditionExpression': conditionExpression,
        'trueFlow': trueFlow.map((e) => e.toJson()).toList(),
        'falseFlow': falseFlow.map((e) => e.toJson()).toList(),
      };
}

class SetViewAction extends Action {
  final String id;
  final String textTemplate;

  SetViewAction({
    String? id,
    this.textTemplate = ''
  }) : id = id ?? _newId();

  @override
  String get type => 'SetView';

  factory SetViewAction.fromJson(Map<String, dynamic> json) {
    return SetViewAction(
      id: json['id'],
      textTemplate: json['textTemplate'] ?? ''
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'textTemplate': textTemplate,
      };
}

class ToastAction extends Action {
  final String id;
  final String messageTemplate;

  ToastAction({
    String? id,
    this.messageTemplate = ''
  }) : id = id ?? _newId();

  @override
  String get type => 'Toast';

  factory ToastAction.fromJson(Map<String, dynamic> json) {
    return ToastAction(
      id: json['id'],
      messageTemplate: json['messageTemplate'] ?? ''
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'messageTemplate': messageTemplate,
      };
}

class ReturnAction extends Action {
  final String id;
  final bool stop;

  ReturnAction({
    String? id,
    this.stop = true
  }) : id = id ?? _newId();

  @override
  String get type => 'Return';

  factory ReturnAction.fromJson(Map<String, dynamic> json) {
    return ReturnAction(
        id: json['id'],
        stop: json['stop'] ?? true, // Default to true if missing
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'stop': stop,
      };
}

class ClipboardAction extends Action {
  final String id;
  final String mode; // 'READ' or 'WRITE'
  final String targetVar; // Used for READ
  final String textTemplate; // Used for WRITE

  ClipboardAction({
    String? id,
    this.mode = 'READ',
    this.targetVar = 'clip',
    this.textTemplate = '',
  }) : id = id ?? _newId();

  @override
  String get type => 'Clipboard';

  factory ClipboardAction.fromJson(Map<String, dynamic> json) {
    return ClipboardAction(
      id: json['id'],
      mode: json['mode'] ?? 'READ',
      targetVar: json['targetVar'] ?? 'clip',
      textTemplate: json['textTemplate'] ?? '',
    );
  }

  ClipboardAction copyWith({
    String? id,
    String? mode,
    String? targetVar,
    String? textTemplate,
  }) {
    return ClipboardAction(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      targetVar: targetVar ?? this.targetVar,
      textTemplate: textTemplate ?? this.textTemplate,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'mode': mode,
        'targetVar': targetVar,
        'textTemplate': textTemplate,
      };
}

class IntentAction extends Action {
  final String id;
  final String action;
  final String packageName;
  final String? className;
  final String dataUri; // Data URI for intent.setData()
  final Map<String, String> extras;

  IntentAction({
    String? id,
    this.action = 'android.intent.action.VIEW',
    this.packageName = '',
    this.className,
    this.dataUri = '',
    this.extras = const {},
  }) : id = id ?? _newId();

  @override
  String get type => 'Intent';

  factory IntentAction.fromJson(Map<String, dynamic> json) {
    return IntentAction(
      id: json['id'],
      action: json['action'] ?? 'android.intent.action.VIEW',
      packageName: json['packageName'] ?? '',
      className: json['className'],
      dataUri: json['dataUri'] ?? '',
      extras: (json['extras'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? const {},
    );
  }

  IntentAction copyWith({
    String? id,
    String? action,
    String? packageName,
    String? className,
    String? dataUri,
    Map<String, String>? extras,
  }) {
    return IntentAction(
      id: id ?? this.id,
      action: action ?? this.action,
      packageName: packageName ?? this.packageName,
      className: className ?? this.className,
      dataUri: dataUri ?? this.dataUri,
      extras: extras ?? this.extras,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'action': action,
        'packageName': packageName,
        'className': className,
        'dataUri': dataUri,
        'extras': extras,
      };
}

class NotificationAction extends Action {
  final String id;
  final String title;
  final String message;
  final String channelId;

  NotificationAction({
    String? id,
    this.title = '',
    this.message = '',
    this.channelId = 'shortcuts',
  }) : id = id ?? _newId();

  @override
  String get type => 'Notification';

  factory NotificationAction.fromJson(Map<String, dynamic> json) {
    return NotificationAction(
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      channelId: json['channelId'] ?? 'shortcuts',
    );
  }

  NotificationAction copyWith({
    String? id,
    String? title,
    String? message,
    String? channelId,
  }) {
    return NotificationAction(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      channelId: channelId ?? this.channelId,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'title': title,
        'message': message,
        'channelId': channelId,
      };
}

class ExpressionAction extends Action {
  final String id;
  final String script;

  ExpressionAction({
    String? id,
    this.script = ''
  }) : id = id ?? _newId();

  @override
  String get type => 'Expression';

  factory ExpressionAction.fromJson(Map<String, dynamic> json) {
    return ExpressionAction(
      id: json['id'],
      script: json['script'] ?? ''
    );
  }

  ExpressionAction copyWith({String? id, String? script}) {
    return ExpressionAction(
      id: id ?? this.id,
      script: script ?? this.script
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'script': script,
      };
}
