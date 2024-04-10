import 'dart:convert';

class WebViewReceivedMessage {
  final String callback;
  Map<String, dynamic> params;
  WebViewReceivedMessage({required this.callback, required this.params});

  factory WebViewReceivedMessage.fromJson(Map<String, dynamic> json) =>
      WebViewReceivedMessage(
          callback: json["callback"] ??= '', params: json['params'] ?? {});

  factory WebViewReceivedMessage.fromJsonString(String jsonString) {
    final map = json.decode(jsonString);
    final callback = map["callback"] ??= '';
    final params = map['params'] ?? {};
    return WebViewReceivedMessage(callback: callback, params: params);
  }
}

class WebViewResult {
  final int code;
  final String? status;
  final Map<String, dynamic> data;

  WebViewResult({required this.code, this.status = '', required this.data});

  Map<String, dynamic> get json =>
      {'code': code, 'status': status, 'data': data};
}