import 'package:shareco/core/utils/regex.dart';

class Validators {
  static String? email(String? email){
    if (AppRegex.email.hasMatch(email!)){
      return "Email không hợp lệ!";
    }
    return null;
  }

  static String? password(String? pass) {
    if (AppRegex.password.hasMatch(pass!)) {
      return "Mật khẩu phải có ít nhất 8 ký tự và phải chứa cả chữ và số!";
    }
    return null;
  }
}