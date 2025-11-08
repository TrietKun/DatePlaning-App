// lib/modules/http/trackasia_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class TrackAsiaService {
  static const String apiKey = '5361762004175e59d4ef01ce6d24300eeb';
  static const String baseUrl = 'https://maps.track-asia.com/api/v2/place';

  /// Tìm kiếm địa điểm theo text
  Future<List<Map<String, dynamic>>> textSearch({
    required String query,
    String language = 'vi',
  }) async {
    print('🔍 Searching for: $query');

    try {
      final url = Uri.parse('$baseUrl/textsearch/json').replace(
        queryParameters: {
          'query': query,
          'language': language,
          'key': apiKey,
        },
      );

      print('📍 Request URL: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List? ?? [];

        print('✅ Found ${results.length} results');

        return results.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in textSearch: $e');
      rethrow;
    }
  }

  /// Tìm kiếm địa điểm gần vị trí hiện tại theo loại
  // lib/modules/http/trackasia_service.dart
  Future<List<Map<String, dynamic>>> nearbySearch({
    required double latitude,
    required double longitude,
    required String type,
    int radius = 5000, // 5km
    String language = 'vi',
  }) async {
    print('🔍 Searching $type near ($latitude, $longitude) within ${radius}m');

    try {
      // Sử dụng location parameter trực tiếp
      final url = Uri.parse('$baseUrl/nearbysearch/json').replace(
        queryParameters: {
          'location': '$latitude,$longitude',
          'radius': radius.toString(),
          'type': _getPlaceTypeForAPI(type),
          'language': language,
          'key': apiKey,
        },
      );

      print('📍 Request URL: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response: ${data.toString().substring(0, 200)}...');

        final results = (data['results'] as List? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        print('✅ Found ${results.length} results');

        // Tính khoảng cách và sort
        final placesWithDistance = results.map((Map<String, dynamic> place) {
          final geometry = place['geometry'] as Map<String, dynamic>?;
          if (geometry != null && geometry['location'] != null) {
            final location = geometry['location'] as Map<String, dynamic>;
            final placeLat = (location['lat'] as num).toDouble();
            final placeLng = (location['lng'] as num).toDouble();

            final distance = _calculateDistance(
              latitude,
              longitude,
              placeLat,
              placeLng,
            );

            return {
              ...place,
              'calculatedDistance': distance,
            };
          }
          return place;
        }).toList();

        // Sort by distance
        placesWithDistance.sort((a, b) {
          final distA = a['calculatedDistance'] as double? ?? 999999;
          final distB = b['calculatedDistance'] as double? ?? 999999;
          return distA.compareTo(distB);
        });

        print(
            '✅ Returning ${placesWithDistance.length} places sorted by distance');

        return placesWithDistance;
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in nearbySearch: $e');
      rethrow;
    }
  }

  String _getPlaceTypeForAPI(String type) {
    switch (type.toLowerCase()) {
      case 'cafe':
        return 'cafe';
      case 'restaurant':
        return 'restaurant';
      case 'cinema':
        return 'movie_theater';
      case 'park':
        return 'park';
      case 'museum':
        return 'museum';
      default:
        return type;
    }
  }

  /// Lấy chi tiết địa điểm
  Future<Map<String, dynamic>?> getPlaceDetails({
    required String placeId,
    String language = 'vi',
  }) async {
    print('🔍 Getting details for place: $placeId');

    try {
      final url = Uri.parse('$baseUrl/detail/json').replace(
        queryParameters: {
          'placeid': placeId,
          'language': language,
          'key': apiKey,
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['result'] != null) {
          print('✅ Got place details');
          return data['result'];
        }
      }
    } catch (e) {
      print('❌ Error getting place details: $e');
    }

    return null;
  }

  /// Autocomplete - gợi ý địa điểm khi gõ
  Future<List<Map<String, dynamic>>> autocomplete({
    required String input,
    double? latitude,
    double? longitude,
    int radius = 50000, // 50km
    String language = 'vi',
  }) async {
    print('🔍 Autocomplete for: $input');

    try {
      final queryParams = {
        'input': input,
        'language': language,
        'key': apiKey,
      };

      // Thêm location nếu có
      if (latitude != null && longitude != null) {
        queryParams['location'] = '$latitude,$longitude';
        queryParams['radius'] = radius.toString();
      }

      final url = Uri.parse('$baseUrl/autocomplete/json').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List? ?? [];

        print('✅ Found ${predictions.length} suggestions');

        return predictions.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      print('❌ Error in autocomplete: $e');
    }

    return [];
  }

  /// Lấy URL ảnh từ photo reference
  String getPhotoUrl(String photoReference, {int maxWidth = 800}) {
    return 'https://maps.track-asia.com/api/v2/place/photo?'
        'maxwidth=$maxWidth&photoreference=$photoReference&key=$apiKey';
  }

  /// Build location query string
  String _buildLocationQuery(double lat, double lon, int radius) {
    // TrackAsia có thể cần format khác, test và adjust
    return 'near $lat,$lon within ${radius}m';
  }

  /// Get type query cho TrackAsia
  String _getTypeQuery(String type) {
    switch (type.toLowerCase()) {
      case 'cafe':
        return 'quán cà phê coffee cafe';
      case 'restaurant':
        return 'nhà hàng restaurant quán ăn';
      case 'cinema':
        return 'rạp chiếu phim cinema theater';
      case 'park':
        return 'công viên park';
      case 'museum':
        return 'bảo tàng museum';
      default:
        return type;
    }
  }

  /// Calculate distance using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // km
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}
