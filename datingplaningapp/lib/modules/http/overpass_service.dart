import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class OverpassService {
  static const String baseUrl = 'https://overpass-api.de/api/interpreter';

  Future<List<Map<String, dynamic>>> fetchPlaces(
    double latitude,
    double longitude,
    String amenityType,
  ) async {
    print('Fetching places of type $amenityType near ($latitude, $longitude)');

    final overpassQuery = _buildQuery(latitude, longitude, amenityType);

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeQueryComponent(overpassQuery)}',
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

  String _buildQuery(double lat, double lon, String type) {
    final radius = 10000; // 10km

    switch (type.toLowerCase()) {
      case 'park':
        return '''
          [out:json][timeout:25];
          (
            node["leisure"="park"](around:$radius,$lat,$lon);
            way["leisure"="park"](around:$radius,$lat,$lon);
          );
          out center;
        ''';
      case 'museum':
        return '''
          [out:json][timeout:25];
          (
            node["tourism"="museum"](around:$radius,$lat,$lon);
            way["tourism"="museum"](around:$radius,$lat,$lon);
          );
          out center;
        ''';
      default:
        return '''
          [out:json][timeout:25];
          (
            node["amenity"="$type"](around:$radius,$lat,$lon);
            way["amenity"="$type"](around:$radius,$lat,$lon);
          );
          out center;
        ''';
    }
  }

  List<Map<String, dynamic>> _parseOverpassData(
    Map<String, dynamic> jsonData,
    String amenityType,
    double currentLat,
    double currentLon,
  ) {
    List<Map<String, dynamic>> places = [];
    final elements = jsonData['elements'] as List<dynamic>;

    for (var element in elements) {
      final tags = element['tags'] as Map<String, dynamic>?;
      if (tags == null || tags['name'] == null) {
        continue; // Bỏ qua các địa điểm không có tên
      }

      // Lấy tọa độ (dùng center cho way/relation)
      double lat =
          (element['lat'] ?? element['center']?['lat'] ?? 0.0).toDouble();
      double lon =
          (element['lon'] ?? element['center']?['lon'] ?? 0.0).toDouble();

      // Tính khoảng cách bằng Haversine formula
      final distanceKm = _calculateDistance(currentLat, currentLon, lat, lon);

      // Thêm vào list với calculatedDistance để Place model xử lý
      places.add({
        'id': element['id'],
        'lat': lat,
        'lon': lon,
        'tags': tags,
        'calculatedDistance': distanceKm, // Thêm field này
      });
    }

    // Sắp xếp theo khoảng cách
    places.sort((a, b) {
      final distA = a['calculatedDistance'] as double;
      final distB = b['calculatedDistance'] as double;
      return distA.compareTo(distB);
    });

    // Giới hạn 50 kết quả gần nhất
    final limitedPlaces = places.take(50).toList();

    print(
        'Found ${elements.length} places, returning ${limitedPlaces.length} closest');

    return limitedPlaces;
  }

  // Tính khoảng cách giữa 2 điểm (Haversine formula)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Trả về km
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}
