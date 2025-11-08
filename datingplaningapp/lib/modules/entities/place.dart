import 'dart:math';

class Place {
  final String id;
  final String name;
  final String type;
  final double lat;
  final double lon;
  final String address;
  final String openHours;
  final String priceRange;
  final String distance;
  final String description;
  final double rating;
  final String imageUrl;

  Place({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lon,
    required this.address,
    required this.openHours,
    required this.priceRange,
    required this.distance,
    required this.description,
    required this.rating,
    required this.imageUrl,
  });

  // Parse từ OpenStreetMap data
  factory Place.fromOSM(Map<String, dynamic> element,
      {String? userLat, String? userLon}) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final lat = element['lat'] ?? element['center']?['lat'] ?? 0.0;
    final lon = element['lon'] ?? element['center']?['lon'] ?? 0.0;

    // Tính khoảng cách nếu có vị trí user
    String distance = 'Unknown';
    if (userLat != null && userLon != null) {
      final distanceKm = _calculateDistance(
        double.parse(userLat),
        double.parse(userLon),
        lat.toDouble(),
        lon.toDouble(),
      );
      distance = distanceKm < 1
          ? '${(distanceKm * 1000).toStringAsFixed(0)}m'
          : '${distanceKm.toStringAsFixed(1)}km';
    }

    return Place(
      id: element['id'].toString(),
      name:
          tags['name'] ?? tags['name:en'] ?? tags['name:vi'] ?? 'Unnamed Place',
      type: _getPlaceType(tags),
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      address: _getAddress(tags),
      openHours: tags['opening_hours'] ?? 'Not available',
      priceRange: _getPriceRange(tags),
      distance: distance,
      description: _getDescription(tags),
      rating:
          _getRandomRating(), // OSM không có rating, có thể integrate với Google Places API
      imageUrl: _getImageUrl(tags),
    );
  }

  static String _getPlaceType(Map<String, dynamic> tags) {
    if (tags['amenity'] == 'cafe') return 'Cafe';
    if (tags['amenity'] == 'restaurant') return 'Restaurant';
    if (tags['tourism'] == 'attraction') return 'Attraction';
    if (tags['leisure'] == 'park') return 'Park';
    return 'Place';
  }

  static String _getAddress(Map<String, dynamic> tags) {
    final parts = <String>[];

    if (tags['addr:housenumber'] != null) {
      parts.add(tags['addr:housenumber']);
    }
    if (tags['addr:street'] != null) {
      parts.add(tags['addr:street']);
    }
    if (tags['addr:subdistrict'] != null) {
      parts.add(tags['addr:subdistrict']);
    }
    if (tags['addr:city'] != null) {
      parts.add(tags['addr:city']);
    }
    if (tags['addr:province'] != null) {
      parts.add(tags['addr:province']);
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Address not available';
  }

  static String _getPriceRange(Map<String, dynamic> tags) {
    // OSM không có price range, có thể thêm logic dựa vào cuisine hoặc area
    if (tags['cuisine']?.toString().contains('coffee') == true) {
      return '20.000đ - 50.000đ';
    }
    return '30.000đ - 100.000đ';
  }

  static String _getDescription(Map<String, dynamic> tags) {
    final parts = <String>[];

    if (tags['cuisine'] != null) {
      parts.add('Cuisine: ${tags['cuisine']}');
    }
    if (tags['internet_access'] == 'wlan') {
      parts.add('Free WiFi available');
    }
    if (tags['outdoor_seating'] == 'yes') {
      parts.add('Outdoor seating available');
    }
    if (tags['diet:vegan'] == 'yes') {
      parts.add('Vegan options available');
    }
    if (tags['delivery'] == 'yes') {
      parts.add('Delivery service available');
    }
    if (tags['phone'] != null) {
      parts.add('Phone: ${tags['phone']}');
    }

    return parts.isNotEmpty
        ? parts.join('. ')
        : 'A lovely place to visit in ${tags['addr:city'] ?? 'the area'}';
  }

  static double _getRandomRating() {
    // Tạm thời random rating, nên integrate với Google Places API để có rating thật
    return 4.0 + (0.0 + (5.0 - 4.0) * (DateTime.now().millisecond % 10) / 10);
  }

  static String _getImageUrl(Map<String, dynamic> tags) {
    // OSM không có ảnh, có thể:
    // 1. Dùng Unsplash API với keyword
    // 2. Dùng Google Places API
    // 3. Dùng ảnh placeholder theo type

    if (tags['image'] != null) {
      return tags['image'];
    }

    // Placeholder images theo loại
    final cuisine = tags['cuisine']?.toString() ?? '';
    if (cuisine.contains('coffee') || tags['amenity'] == 'cafe') {
      return 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800';
    }
    if (tags['amenity'] == 'restaurant') {
      return 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800';
    }
    return 'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800';
  }

  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(min(1.0, sqrt(a)));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * 3.141592653589793 / 180;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'lat': lat,
      'lon': lon,
      'address': address,
      'openHours': openHours,
      'priceRange': priceRange,
      'distance': distance,
      'description': description,
      'rating': rating,
      'imageUrl': imageUrl,
    };
  }
}
