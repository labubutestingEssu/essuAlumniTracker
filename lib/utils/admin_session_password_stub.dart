class AdminSessionPassword {
  static String? _password;

  static Future<void> setPassword(String password) async {
    _password = password;
  }

  static Future<String?> getPassword() async {
    return _password;
  }

  static Future<void> clearPassword() async {
    _password = null;
  }
}
