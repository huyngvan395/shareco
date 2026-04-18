class AppRegex {
  static final email = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  static final password = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$');
}
