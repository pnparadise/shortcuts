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
      case 'Return':
      case 'return':
        return ReturnAction.fromJson(json);
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
