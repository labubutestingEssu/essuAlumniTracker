import 'dart:html' as html;

void updateBrowserUrl(String path) {
  html.window.history.pushState(null, '', path);
} 