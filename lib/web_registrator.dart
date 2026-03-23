import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void registerChartWeb(String viewID, String url) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewID,
    (int viewId) => html.IFrameElement()
      ..width = '100%'
      ..height = '100%'
      ..src = url
      ..style.border = 'none',
  );
}
