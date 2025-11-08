// // lib/modules/http/google_places_service.dart
// import 'dart:convert';
// import 'dart:math';
// import 'package:http/http.dart' as http;

// class GooglePlacesService {
//   static const String apiKey =
//       'AIzaSyCxcphLRe8GZOJn79Yl5obpQLU68XNvZXo'; // Thay bằng API key thật
//   static const String nearbySearchUrl =
//       'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
//   static const String photoUrl =
//       'https://maps.googleapis.com/maps/api/place/photo';

//   Future<List<Map>> fetchNearbyPlaces({
//     required double latitude,
//     required double longitude,
//     required String type,
//     int radius = 5000,
//   }) async {
//     print('Fetching places of type $type near ($latitude, $longitude)');

//     try {
//       final url = Uri.parse(nearbySearchUrl).replace(queryParameters: {
//         'location': '$latitude,$longitude',
//         'radius': radius.toString(),
//         'type': _getGooglePlaceType(type),
//         'key': apiKey,
//         'language': 'vi',
//       });

//       print('Request URL: $url');

//       final response = await http.get(url);

//       print('Response status: ${response.statusCode}');
//       print('Response body: ${response.body}');

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         final status = data['status'];

//         print('API Status: $status');

//         if (status == 'OK') {
//           final results = data['results'] as List;
//           print('Found ${results.length} places');

//           // Add distance to each place
//           final placesWithDistance = results.map((place) {
//             final location = place['geometry']['location'];
//             final placeLat = location['lat'].toDouble();
//             final placeLon = location['lng'].toDouble();

//             final distance = _calculateDistance(
//               latitude,
//               longitude,
//               placeLat,
//               placeLon,
//             );

//             return {
//               ...place,
//               'calculatedDistance': distance,
//             };
//           }).toList();

//           // Sort by distance
//           placesWithDistance.sort((a, b) {
//             final distA = a['calculatedDistance'] as double;
//             final distB = b['calculatedDistance'] as double;
//             return distA.compareTo(distB);
//           });

//           return placesWithDistance;
//         } else if (status == 'ZERO_RESULTS') {
//           print('No places found');
//           return [];
//         } else if (status == 'REQUEST_DENIED') {
//           final errorMessage = data['error_message'] ?? 'Unknown error';
//           throw Exception('REQUEST_DENIED: $errorMessage\n\n'
//               'Solutions:\n'
//               '1. Enable Places API in Google Cloud Console\n'
//               '2. Wait 5-10 minutes after enabling\n'
//               '3. Check API key restrictions\n'
//               '4. Set API restrictions to "None" for testing');
//         } else if (status == 'OVER_QUERY_LIMIT') {
//           throw Exception('Query limit exceeded. Please try again later.');
//         } else {
//           throw Exception('Google Places API error: $status');
//         }
//       } else {
//         throw Exception('HTTP Error: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error in fetchNearbyPlaces: $e');
//       rethrow;
//     }
//   }

//   String _getGooglePlaceType(String type) {
//     switch (type.toLowerCase()) {
//       case 'cafe':
//         return 'cafe';
//       case 'restaurant':
//         return 'restaurant';
//       case 'cinema':
//         return 'movie_theater';
//       case 'park':
//         return 'park';
//       case 'museum':
//         return 'museum';
//       default:
//         return type;
//     }
//   }

//   String getPhotoUrl(String photoReference, {int maxWidth = 800}) {
//     return '$photoUrl?maxwidth=$maxWidth&photo_reference=$photoReference&key=$apiKey';
//   }

//   double _calculateDistance(
//       double lat1, double lon1, double lat2, double lon2) {
//     const double earthRadius = 6371;
//     final dLat = _toRadians(lat2 - lat1);
//     final dLon = _toRadians(lon2 - lon1);

//     final a = sin(dLat / 2) * sin(dLat / 2) +
//         cos(_toRadians(lat1)) *
//             cos(_toRadians(lat2)) *
//             sin(dLon / 2) *
//             sin(dLon / 2);

//     final c = 2 * atan2(sqrt(a), sqrt(1 - a));
//     return earthRadius * c;
//   }

//   double _toRadians(double degrees) {
//     return degrees * pi / 180;
//   }
// }
