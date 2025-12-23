import 'dart:convert';
import 'package:flutter/material.dart';

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
  final String url;
  final String method;
  final String targetVar;
  final Map<String, String> headers;
  final String? body;

  FetchAction({
    this.url = '',
    this.method = 'GET',
    this.targetVar = 'response',
    this.headers = const {},
    this.body,
  });

  @override
  String get type => 'Fetch';

  factory FetchAction.fromJson(Map<String, dynamic> json) {
    return FetchAction(
      url: json['url'] ?? '',
      method: json['method'] ?? 'GET',
      targetVar: json['targetVar'] ?? 'response',
      headers: (json['headers'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? const {},
      body: json['body'],
    );
  }

  FetchAction copyWith({
    String? url,
    String? method,
    String? targetVar,
    Map<String, String>? headers,
    String? body,
  }) {
    return FetchAction(
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
        'url': url,
        'method': method,
        'targetVar': targetVar,
        'headers': headers,
        'body': body,
      };
}

class IfAction extends Action {
  final String conditionExpression;
  final List<Action> trueFlow;
  final List<Action> falseFlow;

  IfAction({
    this.conditionExpression = '',
    this.trueFlow = const [],
    this.falseFlow = const [],
  });

  @override
  String get type => 'If';

  factory IfAction.fromJson(Map<String, dynamic> json) {
    return IfAction(
      conditionExpression: json['conditionExpression'] ?? '',
      trueFlow: (json['trueFlow'] as List?)?.map((e) => Action.fromJson(e)).toList() ?? [],
      falseFlow: (json['falseFlow'] as List?)?.map((e) => Action.fromJson(e)).toList() ?? [],
    );
  }

  IfAction copyWith({
    String? conditionExpression,
    List<Action>? trueFlow,
    List<Action>? falseFlow,
  }) {
    return IfAction(
      conditionExpression: conditionExpression ?? this.conditionExpression,
      trueFlow: trueFlow ?? this.trueFlow,
      falseFlow: falseFlow ?? this.falseFlow,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'conditionExpression': conditionExpression,
        'trueFlow': trueFlow.map((e) => e.toJson()).toList(),
        'falseFlow': falseFlow.map((e) => e.toJson()).toList(),
      };
}

class SetViewAction extends Action {
  final String textTemplate;

  SetViewAction({this.textTemplate = ''});

  @override
  String get type => 'SetView';

  factory SetViewAction.fromJson(Map<String, dynamic> json) {
    return SetViewAction(textTemplate: json['textTemplate'] ?? '');
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'textTemplate': textTemplate,
      };
}

class ToastAction extends Action {
  final String messageTemplate;

  ToastAction({this.messageTemplate = ''});

  @override
  String get type => 'Toast';

  factory ToastAction.fromJson(Map<String, dynamic> json) {
    return ToastAction(messageTemplate: json['messageTemplate'] ?? '');
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'messageTemplate': messageTemplate,
      };
}

class ReturnAction extends Action {
  final bool stop;

  ReturnAction({this.stop = true});

  @override
  String get type => 'Return';

  factory ReturnAction.fromJson(Map<String, dynamic> json) {
    return ReturnAction(
        stop: json['stop'] ?? true, // Default to true if missing
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'stop': stop,
      };
}

class ClipboardAction extends Action {
  final String mode; // 'READ' or 'WRITE'
  final String targetVar; // Used for READ
  final String textTemplate; // Used for WRITE

  ClipboardAction({
    this.mode = 'READ',
    this.targetVar = 'clip',
    this.textTemplate = '',
  });

  @override
  String get type => 'Clipboard';

  factory ClipboardAction.fromJson(Map<String, dynamic> json) {
    return ClipboardAction(
      mode: json['mode'] ?? 'READ',
      targetVar: json['targetVar'] ?? 'clip',
      textTemplate: json['textTemplate'] ?? '',
    );
  }

  ClipboardAction copyWith({
    String? mode,
    String? targetVar,
    String? textTemplate,
  }) {
    return ClipboardAction(
      mode: mode ?? this.mode,
      targetVar: targetVar ?? this.targetVar,
      textTemplate: textTemplate ?? this.textTemplate,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'mode': mode,
        'targetVar': targetVar,
        'textTemplate': textTemplate,
      };
}

class IntentAction extends Action {
  final String action;
  final String packageName;
  final String? className;
  final String dataUri; // Data URI for intent.setData()
  final Map<String, String> extras;

  IntentAction({
    this.action = 'android.intent.action.VIEW',
    this.packageName = '',
    this.className,
    this.dataUri = '',
    this.extras = const {},
  });

  @override
  String get type => 'Intent';

  factory IntentAction.fromJson(Map<String, dynamic> json) {
    return IntentAction(
      action: json['action'] ?? 'android.intent.action.VIEW',
      packageName: json['packageName'] ?? '',
      className: json['className'],
      dataUri: json['dataUri'] ?? '',
      extras: (json['extras'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? const {},
    );
  }

  IntentAction copyWith({
    String? action,
    String? packageName,
    String? className,
    String? dataUri,
    Map<String, String>? extras,
  }) {
    return IntentAction(
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
        'action': action,
        'packageName': packageName,
        'className': className,
        'dataUri': dataUri,
        'extras': extras,
      };
}

class NotificationAction extends Action {
  final String title;
  final String message;
  final String channelId;

  NotificationAction({
    this.title = '',
    this.message = '',
    this.channelId = 'shortcuts',
  });

  @override
  String get type => 'Notification';

  factory NotificationAction.fromJson(Map<String, dynamic> json) {
    return NotificationAction(
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      channelId: json['channelId'] ?? 'shortcuts',
    );
  }

  NotificationAction copyWith({
    String? title,
    String? message,
    String? channelId,
  }) {
    return NotificationAction(
      title: title ?? this.title,
      message: message ?? this.message,
      channelId: channelId ?? this.channelId,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'message': message,
        'channelId': channelId,
      };
}

class ExpressionAction extends Action {
  final String script;

  ExpressionAction({this.script = ''});

  @override
  String get type => 'Expression';

  factory ExpressionAction.fromJson(Map<String, dynamic> json) {
    return ExpressionAction(script: json['script'] ?? '');
  }

  ExpressionAction copyWith({String? script}) {
    return ExpressionAction(script: script ?? this.script);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'script': script,
      };
}
