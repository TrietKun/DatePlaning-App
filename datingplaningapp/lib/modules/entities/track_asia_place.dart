// lib/modules/entities/trackasia_place.dart
class TrackAsiaPlace {
  final String id;
  final String placeId;
  final String name;
  final String type;
  final double lat;
  final double lng;
  final String address;
  final String openHours;
  final String priceRange;
  final String distance;
  final String description;
  final double rating;
  final int userRatingsTotal;
  final String imageUrl;
  final List<String> photoUrls;
  final bool isOpen;

  TrackAsiaPlace({
    required this.id,
    required this.placeId,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.address,
    required this.openHours,
    required this.priceRange,
    required this.distance,
    required this.description,
    required this.rating,
    required this.userRatingsTotal,
    required this.imageUrl,
    required this.photoUrls,
    required this.isOpen,
  });

  factory TrackAsiaPlace.fromTrackAsia(
    Map<String, dynamic> data,
    String apiKey,
  ) {
    // Get geometry
    final geometry = data['geometry'];
    final location = geometry?['location'] ?? {};
    final lat = location['lat']?.toDouble() ?? 0.0;
    final lng = location['lng']?.toDouble() ?? 0.0;

    // Get photos
    String imageUrl =
        'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800';
    List<String> photoUrls = [];

    if (data['photos'] != null && (data['photos'] as List).isNotEmpty) {
      final photos = data['photos'] as List;

      // Main photo
      final mainPhotoRef = photos[0]['photo_reference'];
      imageUrl =
          'https://maps.track-asia.com/api/v2/place/photo?maxwidth=800&photoreference=$mainPhotoRef&key=$apiKey';

      // All photos
      photoUrls = photos.map((photo) {
        final photoRef = photo['photo_reference'];
        return 'https://maps.track-asia.com/api/v2/place/photo?maxwidth=800&photoreference=$photoRef&key=$apiKey';
      }).toList();
    }

    // Opening hours
    String openHours = 'Not available';
    bool isOpen = false;
    if (data['opening_hours'] != null) {
      isOpen = data['opening_hours']['open_now'] ?? false;
      openHours = isOpen ? '🟢 Currently open' : '🔴 Currently closed';

      if (data['opening_hours']['weekday_text'] != null) {
        final weekdayText = data['opening_hours']['weekday_text'] as List;
        openHours = weekdayText.join('\n');
      }
    }

    // Price level
    String priceRange = 'Not available';
    if (data['price_level'] != null) {
      final priceLevel = data['price_level'] as int;
      switch (priceLevel) {
        case 0:
          priceRange = 'Miễn phí';
          break;
        case 1:
          priceRange = '15.000đ - 40.000đ';
          break;
        case 2:
          priceRange = '40.000đ - 100.000đ';
          break;
        case 3:
          priceRange = '100.000đ - 300.000đ';
          break;
        case 4:
          priceRange = '300.000đ+';
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
    String description = '';

    if (data['rating'] != null) {
      final ratingVal = data['rating'];
      final totalRatings = data['user_ratings_total'] ?? 0;
      description += '⭐ $ratingVal/5 từ $totalRatings đánh giá. ';
    }

    if (data['vicinity'] != null) {
      description += '📍 ${data['vicinity']}. ';
    } else if (data['formatted_address'] != null) {
      description += '📍 ${data['formatted_address']}. ';
    }

    if (isOpen) {
      description += '🟢 Đang mở cửa';
    } else if (data['opening_hours'] != null) {
      description += '🔴 Đã đóng cửa';
    }

    return TrackAsiaPlace(
      id: data['place_id'] ?? data['id'] ?? '',
      placeId: data['place_id'] ?? data['id'] ?? '',
      name: data['name'] ?? 'Unnamed Place',
      type: _getPlaceType(types),
      lat: lat,
      lng: lng,
      address: data['vicinity'] ??
          data['formatted_address'] ??
          'Address not available',
      openHours: openHours,
      priceRange: priceRange,
      distance: distance,
      description: description,
      rating: (data['rating'] ?? 0.0).toDouble(),
      userRatingsTotal: data['user_ratings_total'] ?? 0,
      imageUrl: imageUrl,
      photoUrls: photoUrls,
      isOpen: isOpen,
    );
  }

  static String _getPlaceType(List types) {
    if (types.contains('cafe')) return 'Cafe';
    if (types.contains('restaurant')) return 'Restaurant';
    if (types.contains('movie_theater')) return 'Cinema';
    if (types.contains('park')) return 'Park';
    if (types.contains('museum')) return 'Museum';
    if (types.isNotEmpty) return types[0].toString();
    return 'Place';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'placeId': placeId,
      'name': name,
      'type': type,
      'lat': lat,
      'lon': lng, // Keep as 'lon' for compatibility with existing code
      'address': address,
      'openHours': openHours,
      'priceRange': priceRange,
      'distance': distance,
      'description': description,
      'rating': rating,
      'userRatingsTotal': userRatingsTotal,
      'imageUrl': imageUrl,
      'photoUrls': photoUrls,
      'isOpen': isOpen,
    };
  }
}