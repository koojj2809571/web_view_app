import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_view_app/web_page/webview_model.dart';

typedef CustomJavaScriptInterface = Function(InAppWebViewController);

const userAgent = '';

class WebViewPage extends StatefulWidget {
  const WebViewPage({
    Key? key,
    required this.url,
    this.navHidden = false,
    this.params,
    this.shareDataCall,
    this.onClickShare,
    this.customJavaScriptInterface,
  }) : super(key: key);
  final String url;
  final bool navHidden;
  final CustomJavaScriptInterface? customJavaScriptInterface;
  final Map<String, String>? params;
  final Function(Map<String, dynamic> data)? shareDataCall;
  final Function()? onClickShare;

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage>
    with AutomaticKeepAliveClientMixin {
  late final String url;
  bool navHidden = false;
  String _title = '';
  var _backColor = Colors.white;
  var _titleColor = Colors.white;
  var _statusStyle = SystemUiOverlayStyle.dark;
  String? _bgUrl;
  var _bgColor = const Color(0xFFB81728);
  InAppWebViewController? controller;
  bool _isWebViewLoaded = false;

  bool get showShare {
    return needShowShare && share && !navHidden;
  }

  bool share = false;
  bool needShowShare = false;

  @override
  void initState() {
    _isWebViewLoaded = false;
    url = Uri.decodeFull(widget.url);
    navHidden = widget.navHidden == false
        ? (widget.params?['navHidden']?.toString() == 'true')
        : navHidden;
    share = widget.params?['shared']?.toString() == 'true';
    print('${navHidden}   ${share}');
    super.initState();
  }

  _navReset() {
    _backColor = Colors.white;
    _titleColor = Colors.white;
    _statusStyle = SystemUiOverlayStyle.dark;
    navHidden = widget.navHidden;
    _bgUrl = null;
    _bgColor = const Color(0xFFB81728);
    setState(() {});
  }

  Widget shareBtn() {
    return InkWell(
      onTap: () {
        widget.onClickShare?.call();
      },
      child: Padding(
        padding: const EdgeInsets.all((44 - 28) / 2),
        child: Icon(
          Icons.share,
          size: 26,
          color: _backColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _statusStyle.copyWith(
        systemNavigationBarColor: (_statusStyle == SystemUiOverlayStyle.light
                ? const Color(0xFF000000)
                : Colors.white)
            .withOpacity(0.8),
        systemNavigationBarIconBrightness:
            _statusStyle == SystemUiOverlayStyle.light
                ? Brightness.light
                : Brightness.dark,
      ),
      child: Scaffold(
          appBar: navHidden ? null : _appbar,
          backgroundColor: const Color(0xFFF6F3F0),
          body: Material(child: _webView(context))),
    );
  }

  _back(context) async {
    final result = await controller?.canGoBack();
    if (result ?? false) {
      controller?.goBack();
    } else {
      Navigator.pop(context);
    }
  }

  Widget _webView(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url)),
          onTitleChanged: (controller, title) async {
            _title = title ?? '';
            setState(() {});
          },
          contextMenu: null,
          onLongPressHitTestResult: (controller, hitTestResult) async {
            if (hitTestResult.extra == null ||
                (hitTestResult.extra?.isEmpty ?? true)) {
              return;
            }

            if (hitTestResult.extra!.startsWith('data:image/png')) {
              _save(hitTestResult.extra!);
            }
          },
          onUpdateVisitedHistory: (controller, uri, androidIsReload) {
            _navReset();
          },
          initialSettings: InAppWebViewSettings(
              userAgent: userAgent,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              useShouldOverrideUrlLoading: true,
              iframeAllowFullscreen: true),
          // onConsoleMessage: (InAppWebViewController controller, ConsoleMessage consoleMessage){
          //   print(consoleMessage.message);
          // },

          onLoadStop: (_controller, url) async {
            _isWebViewLoaded = true;
            setState(() {});
          },

          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri != null) {
              if (uri.scheme == 'vivinochina') {
                await launchUrl(uri);
                return NavigationActionPolicy.CANCEL;
              } else if (await canLaunchExternalUrl(uri)) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationActionPolicy.CANCEL;
              }
            }
            return NavigationActionPolicy.ALLOW;
          },

          onWebViewCreated: (controller) {
            this.controller = controller;
            // _isWebViewLoaded=true;
            widget.customJavaScriptInterface?.call(controller);
            controller.addJavaScriptHandler(
                handlerName: 'close',
                callback: (arg) {
                  final result = WebViewResult(code: 200, data: {});
                  Navigator.of(context).maybePop();
                  return result.json;
                });
            controller.addJavaScriptHandler(
                handlerName: 'setShareData',
                callback: (arg) {
                  final WebViewReceivedMessage? params = message(arg);
                  if (params == null) {
                    return WebViewResult(code: 500, data: {}).json;
                  }
                  final model = {
                    'webPageUrl': params.params['webPageUrl'].toString(),
                    'title': params.params['title'].toString(),
                    'description': params.params['description'].toString(),
                    'thumbnail': params.params['thumbnail'].toString(),
                  };
                  widget.shareDataCall?.call(model);
                  needShowShare = true;
                  setState(() {});
                });
            controller.addJavaScriptHandler(
                handlerName: 'setNavigationBar',
                callback: (arg) {
                  WebViewReceivedMessage? params = message(arg);
                  final args = params?.params ?? {};
                  final backColor = args['backColor']?.toString();
                  final titleColor = args['titleColor']?.toString();
                  final bgUrl = args['bgUrl']?.toString();
                  final bgColor = args['bgColor']?.toString();
                  final navHidden = args['navHidden'] ?? false;
                  final statusStyle = args['statusStyle'] ?? false;
                  this.navHidden = navHidden;
                  _statusStyle = statusStyle
                      ? SystemUiOverlayStyle.dark
                      : SystemUiOverlayStyle.light;
                  if (bgUrl != null) {
                    _bgUrl = bgUrl;
                    _bgColor = Colors.transparent;
                  }
                  if (bgColor != null) {
                    final rgba = bgColor
                        .split(',')
                        .map((e) => double.tryParse(e) ?? 255)
                        .toList();
                    _bgColor = Color.fromRGBO(rgba[0].toInt(), rgba[1].toInt(),
                        rgba[2].toInt(), rgba[3]);
                  }
                  if (backColor != null) {
                    final rgba = backColor
                        .split(',')
                        .map((e) => double.tryParse(e) ?? 255)
                        .toList();
                    _backColor = Color.fromRGBO(rgba[0].toInt(),
                        rgba[1].toInt(), rgba[2].toInt(), rgba[3]);
                  }
                  if (titleColor != null) {
                    final rgba = titleColor
                        .split(',')
                        .map((e) => double.tryParse(e) ?? 255)
                        .toList();
                    _titleColor = Color.fromRGBO(rgba[0].toInt(),
                        rgba[1].toInt(), rgba[2].toInt(), rgba[3]);
                  }
                  setState(() {});
                  final result = WebViewResult(code: 200, data: {});
                  return result.json;
                });
          },
        ),
        if (!_isWebViewLoaded)
          Container(
            color: Colors.white,
          ),
      ],
    );
  }

  bool canLaunchExternalUrl(Uri uri) {
    return !uri.host.contains('vivino');
  }

  _save(String data) async {
    final photoStatus = await Permission.photos.request();
    final storageStatus = await Permission.storage.request();
    bool success = () {
      if (Platform.isAndroid) {
        return storageStatus.isGranted;
      } else if (Platform.isIOS) {
        return photoStatus.isGranted;
      } else {
        return false;
      }
    }();
    if (success) {
      final result = await ImageGallerySaver.saveImage(
        base64.decode(data.split(',')[1]),
        quality: 80,
        name: 'vivino_' + '${DateTime.now().millisecondsSinceEpoch}',
      );
      if (result == null) {
        Fluttertoast.showToast(msg: '保存失败 请截屏保存');
      }
      if (result['filePath'] != null || result['isSuccess']) {
        Fluttertoast.showToast(msg: '已保存到相册');
      } else {
        Fluttertoast.showToast(msg: '保存失败 请检查是否开启相册存储权限或者请截屏保存');
      }
    } else {
      Fluttertoast.showToast(msg: '需要开启相册储权权限 才能保存到相册');
    }
  }

  WebViewReceivedMessage? message(List<dynamic> args) {
    if (args.isNotEmpty) {
      final p = args.first as Map<String, dynamic>?;
      if (p != null) {
        return WebViewReceivedMessage.fromJson(p);
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  PreferredSizeWidget get _appbar => AppBar(
        title: Text(
          _title,
          style: TextStyle(color: _titleColor, fontSize: 17),
        ),
        elevation: 0.0,
        centerTitle: true,
        flexibleSpace: _bgUrl == null
            ? null
            : Image(
                height: MediaQuery.of(context).padding.top + kToolbarHeight,
                image: Image.network(_bgUrl!, fit: BoxFit.cover).image,
                fit: BoxFit.cover,
              ),
        backgroundColor: _bgColor,
        leading: GestureDetector(
            onTap: () async {
              _back(context);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.only(left: 10),
              height: 44,
              width: 40,
              alignment: Alignment.centerLeft,
              child: Icon(Icons.arrow_back, size: 20, color: _backColor),
            )),
        actions: [if (showShare) shareBtn()],
      );

  @override
  bool get wantKeepAlive => true;
}
