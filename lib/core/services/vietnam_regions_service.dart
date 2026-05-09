import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/vietnam_regions.dart';

class VietnamRegionsService {
  static const String baseUrl = 'https://provinces.open-api.vn/api';

  // Get all provinces (online first, then offline static fallback)
  static Future<List<Map<String, dynamic>>> getProvinces() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/p/')).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final list = data.map((item) => {
          'name': item['name'] as String,
          'code': item['code'] as int,
        }).toList();
        if (list.isNotEmpty) {
          // Put 'Khác (Nhập thủ công)' at the end if we have it locally
          list.add({'name': 'Khác (Nhập thủ công)', 'code': -1});
          return list;
        }
      }
    } catch (_) {}

    // Offline fallback
    return vietnamRegions.keys.map((name) => {
      'name': name,
      'code': -1, // static fallback
    }).toList();
  }

  // Get districts of a province (online first, then offline static fallback)
  static Future<List<Map<String, dynamic>>> getDistricts(String provinceName, int provinceCode) async {
    if (provinceCode != -1) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/p/$provinceCode?depth=2')).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
          final List<dynamic> districts = data['districts'] ?? [];
          final list = districts.map((item) => {
            'name': item['name'] as String,
            'code': item['code'] as int,
          }).toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      } catch (_) {}
    }

    // Offline fallback
    final staticProvince = vietnamRegions[provinceName];
    if (staticProvince != null) {
      return staticProvince.keys.map((name) => {
        'name': name,
        'code': -1,
      }).toList();
    }

    return [];
  }

  // Get wards of a district (online first, then offline static fallback)
  static Future<List<Map<String, dynamic>>> getWards(String provinceName, String districtName, int districtCode) async {
    if (districtCode != -1) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/d/$districtCode?depth=2')).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
          final List<dynamic> wards = data['wards'] ?? [];
          final list = wards.map((item) => {
            'name': item['name'] as String,
            'code': item['code'] as int,
          }).toList();
          if (list.isNotEmpty) {
            return list;
          }
        }
      } catch (_) {}
    }

    // Offline fallback
    final staticProvince = vietnamRegions[provinceName];
    if (staticProvince != null) {
      final staticDistrict = staticProvince[districtName];
      if (staticDistrict != null) {
        return staticDistrict.map((name) => {
          'name': name,
          'code': -1,
        }).toList();
      }
    }

    return [];
  }
}
