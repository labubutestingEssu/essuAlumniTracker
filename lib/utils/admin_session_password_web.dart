import 'dart:html' as html;

class AdminSessionPassword {
  static Future<void> setPassword(String password) async {
    html.window.sessionStorage['admin_password'] = password;
  }

  static Future<String?> getPassword() async {
    return html.window.sessionStorage['admin_password'];
  }

  static Future<void> clearPassword() async {
    html.window.sessionStorage.remove('admin_password');
  }
}
