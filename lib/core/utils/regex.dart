abstract class AppRegex {
  static final email = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final username = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');
  static final password = RegExp(r'^.{6,}$');
  static final url = RegExp(r'https?://[^\s/$.?#].[^\s]*');
}