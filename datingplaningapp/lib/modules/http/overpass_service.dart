import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // Sử dụng thư viện geolocator để lấy vị trí

class OverpassService {
  // static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<Map<String, dynamic>>> fetchPlaces(
      double latitude, double longitude, String amenityType) async {
    print('Fetching places of type $amenityType near ($latitude, $longitude)');

    // Overpass QL query với limit 50
    final overpassQuery = '''
      [out:json][timeout:25];
      (
        node["amenity"="$amenityType"](around:10000,$latitude,$longitude);
        way["amenity"="$amenityType"](around:10000,$latitude,$longitude);
        relation["amenity"="$amenityType"](around:10000,$latitude,$longitude);
      );
      out center 50;
      ''';

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'data=${Uri.encodeQueryComponent(overpassQuery)}', // encode đúng cách
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseOverpassData(data, amenityType, latitude, longitude);
      } else {
        throw Exception(
            'Failed to load places. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to Overpass API: $e');
    }
  }

  // Hàm chuyển đổi dữ liệu JSON từ Overpass sang định dạng mong muốn
  List<Map<String, dynamic>> _parseOverpassData(Map<String, dynamic> jsonData,
      String amenityType, double currentLat, double currentLon) {
    List<Map<String, dynamic>> places = [];
    final elements = jsonData['elements'] as List<dynamic>;

    for (var element in elements) {
      final tags = element['tags'] as Map<String, dynamic>?;
      if (tags == null || tags['name'] == null) {
        continue; // Bỏ qua các đối tượng không có tên
      }

      // Xác định tọa độ chính xác của địa điểm (dùng center cho way/relation)
      double lat = element['lat'] ?? element['center']['lat'];
      double lon = element['lon'] ?? element['center']['lon'];

      // Tính khoảng cách từ vị trí hiện tại đến địa điểm
      final distanceInMeters = Geolocator.distanceBetween(
        currentLat,
        currentLon,
        lat,
        lon,
      );

      // Chuyển đổi khoảng cách sang định dạng "X km"
      final distanceFormatted =
          (distanceInMeters / 1000).toStringAsFixed(1) + ' km';

      // Xây dựng map dữ liệu
      places.add({
        'id': element['id'].toString(),
        'name': tags['name'] ?? 'Tên không xác định',
        'address': _getAddressFromTags(tags),
        'rating': 4.0,
        'distance': distanceInMeters, // lưu số, không phải String
        'distanceFormatted': distanceFormatted, // dùng để hiển thị
        'imageUrl': _getImageUrlForType(amenityType),
        'priceRange': _getPriceRangeForType(amenityType),
        'description': tags['cuisine'] ?? 'Không có mô tả',
        'openHours': tags['opening_hours'] ?? 'Không có thông tin giờ mở cửa',
        'type': amenityType.substring(0, 1).toUpperCase() +
            amenityType.substring(1),
      });
    }

    return places;
  }

  // Hàm tạo địa chỉ từ các tag của OSM (đơn giản hóa)
  String _getAddressFromTags(Map<String, dynamic> tags) {
    List<String> addressParts = [];
    if (tags['addr:housenumber'] != null) {
      addressParts.add(tags['addr:housenumber']);
    }
    if (tags['addr:street'] != null) {
      addressParts.add(tags['addr:street']);
    }
    // Có thể thêm các trường khác như 'addr:city', 'addr:district'
    return addressParts.join(' ');
  }

  // Hàm gán URL hình ảnh ngẫu nhiên hoặc mặc định dựa trên loại địa điểm
  String _getImageUrlForType(String type) {
    switch (type) {
      case 'cafe':
        return 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=400';
      case 'restaurant':
        return 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400';
      case 'cinema':
        return 'https://images.unsplash.com/photo-1489185078844-8d5d2e5a2e7e?w=400';
      case 'park':
        return 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400';
      case 'museum':
        return 'https://images.unsplash.com/photo-1551632436-cbf8dd35adfa?w=400';
      default:
        return 'https://images.unsplash.com/photo-1502602898686-2169727409c9?w=400';
    }
  }

  // Hàm gán giá tiền ngẫu nhiên hoặc mặc định
  String _getPriceRangeForType(String type) {
    if (type == 'park' || type == 'museum') return 'Free';
    return '₫₫'; // Giá mặc định
  }
}
