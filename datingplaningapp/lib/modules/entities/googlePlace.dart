// lib/modules/entities/google_place.dart
class GooglePlace {
  final String id;
  final String placeId;
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
  final int userRatingsTotal;
  final String imageUrl;
  final bool isOpen;

  GooglePlace({
    required this.id,
    required this.placeId,
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
    required this.userRatingsTotal,
    required this.imageUrl,
    required this.isOpen,
  });

  factory GooglePlace.fromGoogle(Map<String, dynamic> data, String apiKey) {
    final geometry = data['geometry'];
    final location = geometry['location'];
    
    // Get photo URL
    String imageUrl = 'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800';
    if (data['photos'] != null && (data['photos'] as List).isNotEmpty) {
      final photoReference = data['photos'][0]['photo_reference'];
      imageUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoReference&key=$apiKey';
    }

    // Parse opening hours
    String openHours = 'Not available';
    bool isOpen = false;
    if (data['opening_hours'] != null) {
      isOpen = data['opening_hours']['open_now'] ?? false;
      if (data['opening_hours']['weekday_text'] != null) {
        final weekdayText = data['opening_hours']['weekday_text'] as List;
        openHours = weekdayText.join('\n');
      }
    }

    // Parse price level
    String priceRange = 'Not available';
    if (data['price_level'] != null) {
      final priceLevel = data['price_level'] as int;
      switch (priceLevel) {
        case 0:
          priceRange = 'Free';
          break;
        case 1:
          priceRange = '₫ (Rẻ)';
          break;
        case 2:
          priceRange = '₫₫ (Trung bình)';
          break;
        case 3:
          priceRange = '₫₫₫ (Đắt)';
          break;
        case 4:
          priceRange = '₫₫₫₫ (Rất đắt)';
          break;
      }
    }

    // Distance
    String distance = 'Unknown';
    if (data['calculatedDistance'] != null) {
      final distanceKm = data['calculatedDistance'] as double;
      distance = distanceKm < 1
          ? '${(distanceKm * 1000).toStringAsFixed(0)}m'
          : '${distanceKm.toStringAsFixed(1)}km';
    }

    // Description
    final types = data['types'] as List? ?? [];
    String description = 'A nice place to visit';
    if (data['rating'] != null) {
      description = 'Rated ${data['rating']}/5 by ${data['user_ratings_total'] ?? 0} people. ';
    }
    if (types.isNotEmpty) {
      description += 'Type: ${types.take(3).join(', ')}. ';
    }
    if (isOpen) {
      description += 'Currently open!';
    }

    return GooglePlace(
      id: data['place_id'],
      placeId: data['place_id'],
      name: data['name'] ?? 'Unnamed Place',
      type: _getPlaceType(types),
      lat: location['lat'].toDouble(),
      lon: location['lng'].toDouble(),
      address: data['vicinity'] ?? data['formatted_address'] ?? 'Address not available',
      openHours: openHours,
      priceRange: priceRange,
      distance: distance,
      description: description,
      rating: (data['rating'] ?? 0.0).toDouble(),
      userRatingsTotal: data['user_ratings_total'] ?? 0,
      imageUrl: imageUrl,
      isOpen: isOpen,
    );
  }

  static String _getPlaceType(List types) {
    if (types.contains('cafe')) return 'Cafe';
    if (types.contains('restaurant')) return 'Restaurant';
    if (types.contains('movie_theater')) return 'Cinema';
    if (types.contains('park')) return 'Park';
    if (types.contains('museum')) return 'Museum';
    return 'Place';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'placeId': placeId,
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
      'userRatingsTotal': userRatingsTotal,
      'imageUrl': imageUrl,
      'isOpen': isOpen,
    };
  }
}