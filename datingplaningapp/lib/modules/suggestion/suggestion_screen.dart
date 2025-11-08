import 'package:datingplaningapp/modules/http/overpass_service.dart';
import 'package:datingplaningapp/modules/suggestion/placeDetailBottomSheet.dart';
import 'package:datingplaningapp/modules/entities/place.dart'; // Import Place model
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class SuggestionScreen extends StatefulWidget {
  final String suggestionType;
  final String suggestionName;

  const SuggestionScreen({
    super.key,
    required this.suggestionType,
    required this.suggestionName,
  });

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  final service = OverpassService();

  List<Map<String, dynamic>> nearbyPlaces = [];
  bool isLoading = true;
  Position? currentPosition;
  String searchQuery = '';
  List<Map<String, dynamic>> selectedPlaces = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _getCurrentLocation();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          isLoading = false;
        });
        _showError('Location permission denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        isLoading = false;
      });
      _showError('Location permission permanently denied');
      return;
    }
    try {
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print(
          'Current position: ${currentPosition?.latitude}, ${currentPosition?.longitude}');
      await _loadNearbyPlaces();
    } catch (e) {
      print('Error getting location: $e');
      _showError('Failed to get current location');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadNearbyPlaces() async {
    if (currentPosition == null) {
      _showError('Location not available');
      return;
    }

    setState(() {
      isLoading = true;
    });

    await _fetchPlacesFromApi(widget.suggestionType);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchPlacesFromApi(String type) async {
    print('Fetching places for type: $type');
    print(
        'Current position: ${currentPosition?.latitude}, ${currentPosition?.longitude}');

    if (currentPosition == null) {
      _showError('Location not available');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final places = await service.fetchPlaces(
        currentPosition!.latitude,
        currentPosition!.longitude,
        type,
      );

      print('Fetched ${places.length} places from API');

      // Chuyển đổi dữ liệu từ OSM sang Place model
      List<Map<String, dynamic>> processedPlaces = [];

      for (var element in places) {
        try {
          // Parse place từ OSM data
          final place = Place.fromOSM(
            element,
            userLat: currentPosition!.latitude.toString(),
            userLon: currentPosition!.longitude.toString(),
          );

          // Convert sang Map để sử dụng với UI hiện tại
          processedPlaces.add(place.toMap());
        } catch (e) {
          print('Error parsing place: $e');
          // Skip place này và tiếp tục
        }
      }

      setState(() {
        nearbyPlaces = processedPlaces;
        isLoading = false;
      });

      if (processedPlaces.isEmpty) {
        _showError('No places found nearby. Try another location or type.');
      }
    } catch (e) {
      print('Error fetching places: $e');
      _showError('Failed to fetch places: ${e.toString()}');
      setState(() {
        nearbyPlaces = [];
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cafe':
        return '☕';
      case 'restaurant':
        return '🍽️';
      case 'cinema':
        return '🎬';
      case 'park':
        return '🌳';
      case 'museum':
        return '🏛️';
      default:
        return '📍';
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'cafe':
        return Colors.brown;
      case 'restaurant':
        return Colors.orange;
      case 'cinema':
        return Colors.purple;
      case 'park':
        return Colors.green;
      case 'museum':
        return Colors.indigo;
      default:
        return const Color(0xffFFC8DD);
    }
  }

  List<Map<String, dynamic>> get filteredPlaces {
    if (searchQuery.isEmpty) return nearbyPlaces;
    return nearbyPlaces.where((place) {
      final name = place['name']?.toString().toLowerCase() ?? '';
      final address = place['address']?.toString().toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();
      return name.contains(query) || address.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _addToSelectedPlaces(Map<String, dynamic> place) async {
    setState(() {
      if (!selectedPlaces.any((p) => p['id'] == place['id'])) {
        selectedPlaces.add(place);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Added ${place['name']} to selection')),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addSelectedPlacesToPlan() async {
    if (selectedPlaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one place'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddToPlanDialog(
        selectedPlaces: selectedPlaces,
        onPlacesAdded: () {
          Navigator.pop(context);
          Navigator.pop(context, selectedPlaces);
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search for places...',
          prefixIcon: const Icon(Icons.search, color: Color(0xffFFC8DD)),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => searchQuery = ''),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final isSelected = selectedPlaces.any((p) => p['id'] == place['id']);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    _getTypeColor(place['type'] ?? widget.suggestionType)
                        .withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getTypeColor(place['type'] ?? widget.suggestionType)
                        .withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showPlaceDetail(place),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image with overlay
                        Stack(
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: Image.network(
                                place['imageUrl'] ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image_not_supported,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          place['name'] ?? 'Place',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                        color: _getTypeColor(place['type'] ??
                                            widget.suggestionType),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getTypeColor(
                                      place['type'] ?? widget.suggestionType),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getTypeIcon(place['type'] ??
                                          widget.suggestionType),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      place['type'] ?? widget.suggestionType,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (place['distance'] != null &&
                                place['distance'] != 'Unknown')
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        place['distance'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      place['name'] ?? 'Unknown Place',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          (place['rating'] ?? 4.0)
                                              .toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              if (place['address'] != null &&
                                  place['address'] != 'Address not available')
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        place['address'],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 8),

                              if (place['description'] != null)
                                Text(
                                  place['description'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  if (place['priceRange'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        place['priceRange'],
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (place['priceRange'] != null &&
                                      place['openHours'] != null &&
                                      place['openHours'] != 'Not available')
                                    const SizedBox(width: 8),
                                  if (place['openHours'] != null &&
                                      place['openHours'] !=
                                          'Not available') ...[
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        place['openHours'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: isSelected
                                          ? null
                                          : () => _addToSelectedPlaces(place),
                                      icon: Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.add_circle_outline,
                                        size: 18,
                                      ),
                                      label: Text(
                                        isSelected ? 'Selected' : 'Add to Plan',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSelected
                                            ? Colors.grey
                                            : _getTypeColor(place['type'] ??
                                                widget.suggestionType),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _showPlaceDetail(place),
                                    icon: const Icon(Icons.info_outline,
                                        size: 18),
                                    label: const Text('Details'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: _getTypeColor(
                                          place['type'] ??
                                              widget.suggestionType),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: _getTypeColor(place['type'] ??
                                              widget.suggestionType),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPlaceDetail(Map<String, dynamic> place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlaceDetailBottomSheet(
        place: place,
        typeColor: _getTypeColor(place['type'] ?? widget.suggestionType),
        onAddToSelection: () {
          Navigator.pop(context);
          _addToSelectedPlaces(place);
        },
        isSelected: selectedPlaces.any((p) => p['id'] == place['id']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: _getTypeColor(widget.suggestionType),
        elevation: 0,
        title: Text(
          '${_getTypeIcon(widget.suggestionType)} ${widget.suggestionName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (selectedPlaces.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${selectedPlaces.length}',
                    style: TextStyle(
                      color: _getTypeColor(widget.suggestionType),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.favorite,
                    color: _getTypeColor(widget.suggestionType),
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xffFFC8DD)),
                    ),
                  )
                : filteredPlaces.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No places found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try searching in a different area',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNearbyPlaces,
                        color: _getTypeColor(widget.suggestionType),
                        child: ListView.builder(
                          itemCount: filteredPlaces.length,
                          itemBuilder: (context, index) =>
                              _buildPlaceCard(filteredPlaces[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: selectedPlaces.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _addSelectedPlacesToPlan,
              backgroundColor: _getTypeColor(widget.suggestionType),
              icon: const Icon(Icons.add_task, color: Colors.white),
              label: Text(
                'Add ${selectedPlaces.length} to Plan',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}

// Add to Plan Dialog (giữ nguyên phần này)
class AddToPlanDialog extends StatefulWidget {
  final List<Map<String, dynamic>> selectedPlaces;
  final VoidCallback onPlacesAdded;

  const AddToPlanDialog({
    super.key,
    required this.selectedPlaces,
    required this.onPlacesAdded,
  });

  @override
  State<AddToPlanDialog> createState() => _AddToPlanDialogState();
}

class _AddToPlanDialogState extends State<AddToPlanDialog> {
  List<Map<String, dynamic>> userPlans = [];
  bool isLoading = true;
  String? selectedPlanId;

  @override
  void initState() {
    super.initState();
    _loadUserPlans();
  }

  Future<void> _loadUserPlans() async {
    try {
      // Replace with actual current user ID
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc("currentUserId") // TODO: Replace with actual user ID
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final List<dynamic> planIds = data["plans"] ?? [];

        if (planIds.isNotEmpty) {
          final snapshot = await FirebaseFirestore.instance
              .collection("plans")
              .where(FieldPath.documentId, whereIn: planIds.take(10).toList())
              .orderBy("date", descending: true)
              .get();

          userPlans = snapshot.docs
              .map((doc) => {"id": doc.id, ...doc.data()})
              .toList();
        }
      }
    } catch (e) {
      print('Error loading plans: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _addPlacesToPlan() async {
    if (selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a plan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final newItineraryItems = widget.selectedPlaces
          .map((place) => {
                'name': place['name'] ?? 'Unknown',
                'address': place['address'] ?? '',
                'description': place['description'] ?? '',
                'type': place['type'] ?? '',
                'completed': false,
                'memoryPhotos': [],
                'addedAt': Timestamp.now(),
              })
          .toList();

      final planDoc = await FirebaseFirestore.instance
          .collection('plans')
          .doc(selectedPlanId)
          .get();

      if (planDoc.exists) {
        final currentItinerary =
            List<Map<String, dynamic>>.from(planDoc.data()!['itinerary'] ?? []);
        currentItinerary.addAll(newItineraryItems);

        await FirebaseFirestore.instance
            .collection('plans')
            .doc(selectedPlanId)
            .update({'itinerary': currentItinerary});

        widget.onPlacesAdded();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Added ${widget.selectedPlaces.length} places to your plan!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding places: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.add_task, color: Color(0xffFFC8DD)),
          SizedBox(width: 8),
          Text('Add to Plan'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add ${widget.selectedPlaces.length} selected places to which plan?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (userPlans.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.calendar_today, size: 50, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No plans available',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Create a plan first to add places',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    children: userPlans.map((plan) {
                      final isSelected = selectedPlanId == plan['id'];
                      final date = (plan['date'] as Timestamp).toDate();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<String>(
                          value: plan['id'],
                          groupValue: selectedPlanId,
                          onChanged: (value) {
                            setState(() {
                              selectedPlanId = value;
                            });
                          },
                          activeColor: const Color(0xffFFC8DD),
                          title: Text(
                            plan['title'] ?? 'Date Plan',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          tileColor: isSelected
                              ? const Color(0xffFFC8DD).withOpacity(0.1)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: userPlans.isEmpty ? null : _addPlacesToPlan,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xffFFC8DD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Add Places',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}


// import 'package:datingplaningapp/modules/entities/track_asia_place.dart';
// import 'package:datingplaningapp/modules/http/overpass_service.dart';
// import 'package:datingplaningapp/modules/services/track_asia_service.dart';
// import 'package:datingplaningapp/modules/suggestion/placeDetailBottomSheet.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';
// import 'dart:math';

// class SuggestionScreen extends StatefulWidget {
//   final String suggestionType;
//   final String suggestionName;

//   const SuggestionScreen({
//     super.key,
//     required this.suggestionType,
//     required this.suggestionName,
//   });

//   @override
//   State<SuggestionScreen> createState() => _SuggestionScreenState();
// }

// class _SuggestionScreenState extends State<SuggestionScreen>
//     with TickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _slideAnimation;
//   late Animation<double> _fadeAnimation;
//   final service = OverpassService();
//   final trackAsiaService = TrackAsiaService();

//   List<Map<String, dynamic>> nearbyPlaces = [];
//   bool isLoading = true;
//   Position? currentPosition;
//   String searchQuery = '';
//   List<Map<String, dynamic>> selectedPlaces = [];

//   @override
//   void initState() {
//     super.initState();
//     _setupAnimations();
//     _getCurrentLocation();
//   }

//   void _setupAnimations() {
//     _animationController = AnimationController(
//       duration: const Duration(milliseconds: 1000),
//       vsync: this,
//     );
//     _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
//     );
//     _animationController.forward();
//   }

//   Future<void> _getCurrentLocation() async {
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         setState(() {
//           isLoading = false;
//         });
//         _showError('Location permission denied');
//         return;
//       }
//     }
//     if (permission == LocationPermission.deniedForever) {
//       setState(() {
//         isLoading = false;
//       });
//       _showError('Location permission permanently denied');
//       return;
//     }
//     try {
//       currentPosition = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       print(
//           'Current position: ${currentPosition?.latitude}, ${currentPosition?.longitude}');
//       await _loadNearbyPlaces();
//     } catch (e) {
//       print('Error getting location: $e');
//       _showError('Failed to get current location');
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> _loadNearbyPlaces() async {
//     if (currentPosition == null) {
//       _showError('Location not available');
//       return;
//     }

//     setState(() {
//       isLoading = true;
//     });

//     await _fetchPlacesFromApi(widget.suggestionType);

//     setState(() {
//       isLoading = false;
//     });
//   }

//   Future<void> _fetchPlacesFromApi(String type) async {
//     print('Fetching places for type: $type');

//     if (currentPosition == null) {
//       _showError('Location not available');
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       final places = await trackAsiaService.nearbySearch(
//         latitude: currentPosition!.latitude,
//         longitude: currentPosition!.longitude,
//         type: type,
//         radius: 5000, // 5km
//       );

//       print('Fetched ${places.length} places from TrackAsia API');

//       // Parse places
//       List<Map<String, dynamic>> processedPlaces = [];

//       for (var data in places) {
//         try {
//           final place = TrackAsiaPlace.fromTrackAsia(
//             data,
//             TrackAsiaService.apiKey,
//           );
//           processedPlaces.add(place.toMap());
//         } catch (e) {
//           print('Error parsing place: $e');
//         }
//       }

//       setState(() {
//         nearbyPlaces = processedPlaces;
//         isLoading = false;
//       });

//       if (processedPlaces.isEmpty) {
//         _showError('No places found nearby. Try another location or type.');
//       } else {
//         print('Successfully processed ${processedPlaces.length} places');
//       }
//     } catch (e) {
//       print('Error fetching places: $e');
//       _showError('Failed to fetch places: ${e.toString()}');
//       setState(() {
//         nearbyPlaces = [];
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> _searchPlacesByName(String query) async {
//     if (query.isEmpty) {
//       await _loadNearbyPlaces();
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       final places = await trackAsiaService.textSearch(query: query);

//       print('Found ${places.length} places for query: $query');

//       // Parse and add distance if we have current position
//       List<Map<String, dynamic>> processedPlaces = [];

//       for (var data in places) {
//         try {
//           // Add distance calculation if we have current position
//           if (currentPosition != null) {
//             final geometry = data['geometry'];
//             if (geometry != null && geometry['location'] != null) {
//               final location = geometry['location'];
//               final placeLat = location['lat'].toDouble();
//               final placeLng = location['lng'].toDouble();

//               final distance = _calculateDistance(
//                 currentPosition!.latitude,
//                 currentPosition!.longitude,
//                 placeLat,
//                 placeLng,
//               );

//               data['calculatedDistance'] = distance;
//             }
//           }

//           final place = TrackAsiaPlace.fromTrackAsia(
//             data,
//             TrackAsiaService.apiKey,
//           );
//           processedPlaces.add(place.toMap());
//         } catch (e) {
//           print('Error parsing place: $e');
//         }
//       }

//       setState(() {
//         nearbyPlaces = processedPlaces;
//         isLoading = false;
//       });

//       if (processedPlaces.isEmpty) {
//         _showError('No places found for "$query"');
//       }
//     } catch (e) {
//       print('Error searching places: $e');
//       _showError('Failed to search: ${e.toString()}');
//       setState(() {
//         nearbyPlaces = [];
//         isLoading = false;
//       });
//     }
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

//   double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;

//   void _showError(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             const Icon(Icons.error_outline, color: Colors.white),
//             const SizedBox(width: 8),
//             Expanded(child: Text(message)),
//           ],
//         ),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   String _getTypeIcon(String type) {
//     switch (type.toLowerCase()) {
//       case 'cafe':
//         return '☕';
//       case 'restaurant':
//         return '🍽️';
//       case 'cinema':
//         return '🎬';
//       case 'park':
//         return '🌳';
//       case 'museum':
//         return '🏛️';
//       default:
//         return '📍';
//     }
//   }

//   Color _getTypeColor(String type) {
//     switch (type.toLowerCase()) {
//       case 'cafe':
//         return Colors.brown;
//       case 'restaurant':
//         return Colors.orange;
//       case 'cinema':
//         return Colors.purple;
//       case 'park':
//         return Colors.green;
//       case 'museum':
//         return Colors.indigo;
//       default:
//         return const Color(0xffFFC8DD);
//     }
//   }

//   List<Map<String, dynamic>> get filteredPlaces {
//     if (searchQuery.isEmpty) return nearbyPlaces;
//     return nearbyPlaces.where((place) {
//       final name = place['name']?.toString().toLowerCase() ?? '';
//       final address = place['address']?.toString().toLowerCase() ?? '';
//       final query = searchQuery.toLowerCase();
//       return name.contains(query) || address.contains(query);
//     }).toList();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   Future<void> _addToSelectedPlaces(Map<String, dynamic> place) async {
//     setState(() {
//       if (!selectedPlaces.any((p) => p['id'] == place['id'])) {
//         selectedPlaces.add(place);
//       }
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             const Icon(Icons.check_circle, color: Colors.white),
//             const SizedBox(width: 8),
//             Expanded(child: Text('Added ${place['name']} to selection')),
//           ],
//         ),
//         backgroundColor: Colors.green,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   Future<void> _addSelectedPlacesToPlan() async {
//     if (selectedPlaces.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please select at least one place'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     showDialog(
//       context: context,
//       builder: (context) => AddToPlanDialog(
//         selectedPlaces: selectedPlaces,
//         onPlacesAdded: () {
//           Navigator.pop(context);
//           Navigator.pop(context, selectedPlaces);
//         },
//       ),
//     );
//   }

//   Widget _buildSearchBar() {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(25),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.2),
//             blurRadius: 10,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: TextField(
//         onChanged: (value) => setState(() => searchQuery = value),
//         decoration: InputDecoration(
//           hintText: 'Search for places...',
//           prefixIcon: const Icon(Icons.search, color: Color(0xffFFC8DD)),
//           suffixIcon: searchQuery.isNotEmpty
//               ? IconButton(
//                   icon: const Icon(Icons.clear),
//                   onPressed: () => setState(() => searchQuery = ''),
//                 )
//               : null,
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(vertical: 16),
//         ),
//       ),
//     );
//   }

//   Widget _buildPlaceCard(Map<String, dynamic> place) {
//     final isSelected = selectedPlaces.any((p) => p['id'] == place['id']);

//     return AnimatedBuilder(
//       animation: _animationController,
//       builder: (context, child) {
//         return Transform.translate(
//           offset: Offset(0, _slideAnimation.value),
//           child: FadeTransition(
//             opacity: _fadeAnimation,
//             child: Container(
//               margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(20),
//                 gradient: LinearGradient(
//                   colors: [
//                     Colors.white,
//                     _getTypeColor(place['type'] ?? widget.suggestionType)
//                         .withOpacity(0.05),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 boxShadow: [
//                   BoxShadow(
//                     color: _getTypeColor(place['type'] ?? widget.suggestionType)
//                         .withOpacity(0.1),
//                     blurRadius: 15,
//                     offset: const Offset(0, 5),
//                   ),
//                 ],
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(20),
//                 child: Material(
//                   color: Colors.transparent,
//                   child: InkWell(
//                     onTap: () => _showPlaceDetail(place),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Image with overlay
//                         Stack(
//                           children: [
//                             Container(
//                               height: 180,
//                               width: double.infinity,
//                               color: Colors.grey[200],
//                               child: Image.network(
//                                 place['imageUrl'] ?? '',
//                                 fit: BoxFit.cover,
//                                 errorBuilder: (context, error, stackTrace) {
//                                   return Container(
//                                     color: Colors.grey[200],
//                                     child: Column(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.center,
//                                       children: [
//                                         Icon(
//                                           Icons.image_not_supported,
//                                           size: 48,
//                                           color: Colors.grey[400],
//                                         ),
//                                         const SizedBox(height: 8),
//                                         Text(
//                                           place['name'] ?? 'Place',
//                                           style: TextStyle(
//                                             color: Colors.grey[600],
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 },
//                                 loadingBuilder:
//                                     (context, child, loadingProgress) {
//                                   if (loadingProgress == null) return child;
//                                   return Container(
//                                     color: Colors.grey[200],
//                                     child: Center(
//                                       child: CircularProgressIndicator(
//                                         value: loadingProgress
//                                                     .expectedTotalBytes !=
//                                                 null
//                                             ? loadingProgress
//                                                     .cumulativeBytesLoaded /
//                                                 loadingProgress
//                                                     .expectedTotalBytes!
//                                             : null,
//                                         color: _getTypeColor(place['type'] ??
//                                             widget.suggestionType),
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//                             Positioned(
//                               top: 12,
//                               right: 12,
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 12, vertical: 6),
//                                 decoration: BoxDecoration(
//                                   color: _getTypeColor(
//                                       place['type'] ?? widget.suggestionType),
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 child: Row(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     Text(
//                                       _getTypeIcon(place['type'] ??
//                                           widget.suggestionType),
//                                       style: const TextStyle(fontSize: 16),
//                                     ),
//                                     const SizedBox(width: 4),
//                                     Text(
//                                       place['type'] ?? widget.suggestionType,
//                                       style: const TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                             if (place['distance'] != null &&
//                                 place['distance'] != 'Unknown')
//                               Positioned(
//                                 bottom: 12,
//                                 left: 12,
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 12, vertical: 6),
//                                   decoration: BoxDecoration(
//                                     color: Colors.black.withOpacity(0.7),
//                                     borderRadius: BorderRadius.circular(15),
//                                   ),
//                                   child: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       const Icon(
//                                         Icons.location_on,
//                                         color: Colors.white,
//                                         size: 16,
//                                       ),
//                                       const SizedBox(width: 4),
//                                       Text(
//                                         place['distance'],
//                                         style: const TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),

//                         // Content
//                         Padding(
//                           padding: const EdgeInsets.all(16),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: Text(
//                                       place['name'] ?? 'Unknown Place',
//                                       style: const TextStyle(
//                                         fontSize: 18,
//                                         fontWeight: FontWeight.bold,
//                                         color: Colors.black87,
//                                       ),
//                                     ),
//                                   ),
//                                   Container(
//                                     padding: const EdgeInsets.symmetric(
//                                         horizontal: 8, vertical: 4),
//                                     decoration: BoxDecoration(
//                                       color: Colors.orange,
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     child: Row(
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: [
//                                         const Icon(
//                                           Icons.star,
//                                           color: Colors.white,
//                                           size: 14,
//                                         ),
//                                         const SizedBox(width: 2),
//                                         Text(
//                                           (place['rating'] ?? 4.0)
//                                               .toStringAsFixed(1),
//                                           style: const TextStyle(
//                                             color: Colors.white,
//                                             fontSize: 12,
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               const SizedBox(height: 8),

//                               if (place['address'] != null &&
//                                   place['address'] != 'Address not available')
//                                 Row(
//                                   children: [
//                                     Icon(
//                                       Icons.location_on_outlined,
//                                       size: 16,
//                                       color: Colors.grey[600],
//                                     ),
//                                     const SizedBox(width: 4),
//                                     Expanded(
//                                       child: Text(
//                                         place['address'],
//                                         style: TextStyle(
//                                           color: Colors.grey[600],
//                                           fontSize: 14,
//                                         ),
//                                         maxLines: 2,
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                     ),
//                                   ],
//                                 ),

//                               const SizedBox(height: 8),

//                               if (place['description'] != null)
//                                 Text(
//                                   place['description'],
//                                   style: const TextStyle(
//                                     fontSize: 14,
//                                     color: Colors.black87,
//                                     height: 1.3,
//                                   ),
//                                   maxLines: 2,
//                                   overflow: TextOverflow.ellipsis,
//                                 ),

//                               const SizedBox(height: 12),

//                               Row(
//                                 children: [
//                                   if (place['priceRange'] != null)
//                                     Container(
//                                       padding: const EdgeInsets.symmetric(
//                                           horizontal: 8, vertical: 4),
//                                       decoration: BoxDecoration(
//                                         color: Colors.green.withOpacity(0.1),
//                                         borderRadius: BorderRadius.circular(8),
//                                       ),
//                                       child: Text(
//                                         place['priceRange'],
//                                         style: TextStyle(
//                                           color: Colors.green[700],
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                       ),
//                                     ),
//                                   if (place['priceRange'] != null &&
//                                       place['openHours'] != null &&
//                                       place['openHours'] != 'Not available')
//                                     const SizedBox(width: 8),
//                                   if (place['openHours'] != null &&
//                                       place['openHours'] !=
//                                           'Not available') ...[
//                                     Icon(
//                                       Icons.access_time,
//                                       size: 14,
//                                       color: Colors.grey[500],
//                                     ),
//                                     const SizedBox(width: 4),
//                                     Expanded(
//                                       child: Text(
//                                         place['openHours'],
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: Colors.grey[600],
//                                         ),
//                                         maxLines: 1,
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                     ),
//                                   ],
//                                 ],
//                               ),

//                               const SizedBox(height: 16),

//                               // Action buttons
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: ElevatedButton.icon(
//                                       onPressed: isSelected
//                                           ? null
//                                           : () => _addToSelectedPlaces(place),
//                                       icon: Icon(
//                                         isSelected
//                                             ? Icons.check_circle
//                                             : Icons.add_circle_outline,
//                                         size: 18,
//                                       ),
//                                       label: Text(
//                                         isSelected ? 'Selected' : 'Add to Plan',
//                                         style: const TextStyle(
//                                             fontWeight: FontWeight.bold),
//                                       ),
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: isSelected
//                                             ? Colors.grey
//                                             : _getTypeColor(place['type'] ??
//                                                 widget.suggestionType),
//                                         foregroundColor: Colors.white,
//                                         padding: const EdgeInsets.symmetric(
//                                             vertical: 16),
//                                         shape: RoundedRectangleBorder(
//                                           borderRadius:
//                                               BorderRadius.circular(12),
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(width: 12),
//                                   ElevatedButton.icon(
//                                     onPressed: () => _showPlaceDetail(place),
//                                     icon: const Icon(Icons.info_outline,
//                                         size: 18),
//                                     label: const Text('Details'),
//                                     style: ElevatedButton.styleFrom(
//                                       backgroundColor: Colors.white,
//                                       foregroundColor: _getTypeColor(
//                                           place['type'] ??
//                                               widget.suggestionType),
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(12),
//                                         side: BorderSide(
//                                           color: _getTypeColor(place['type'] ??
//                                               widget.suggestionType),
//                                         ),
//                                       ),
//                                       padding: const EdgeInsets.symmetric(
//                                           horizontal: 20, vertical: 16),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _showPlaceDetail(Map<String, dynamic> place) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => PlaceDetailBottomSheet(
//         place: place,
//         typeColor: _getTypeColor(place['type'] ?? widget.suggestionType),
//         onAddToSelection: () {
//           Navigator.pop(context);
//           _addToSelectedPlaces(place);
//         },
//         isSelected: selectedPlaces.any((p) => p['id'] == place['id']),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       appBar: AppBar(
//         backgroundColor: _getTypeColor(widget.suggestionType),
//         elevation: 0,
//         title: Text(
//           '${_getTypeIcon(widget.suggestionType)} ${widget.suggestionName}',
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         actions: [
//           if (selectedPlaces.isNotEmpty)
//             Container(
//               margin: const EdgeInsets.only(right: 8),
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     '${selectedPlaces.length}',
//                     style: TextStyle(
//                       color: _getTypeColor(widget.suggestionType),
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(width: 4),
//                   Icon(
//                     Icons.favorite,
//                     color: _getTypeColor(widget.suggestionType),
//                     size: 16,
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//       body: Column(
//         children: [
//           _buildSearchBar(),
//           Expanded(
//             child: isLoading
//                 ? const Center(
//                     child: CircularProgressIndicator(
//                       valueColor:
//                           AlwaysStoppedAnimation<Color>(Color(0xffFFC8DD)),
//                     ),
//                   )
//                 : filteredPlaces.isEmpty
//                     ? Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               Icons.search_off,
//                               size: 80,
//                               color: Colors.grey[400],
//                             ),
//                             const SizedBox(height: 16),
//                             Text(
//                               'No places found',
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 color: Colors.grey[600],
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               'Try searching in a different area',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey[500],
//                               ),
//                             ),
//                           ],
//                         ),
//                       )
//                     : RefreshIndicator(
//                         onRefresh: _loadNearbyPlaces,
//                         color: _getTypeColor(widget.suggestionType),
//                         child: ListView.builder(
//                           itemCount: filteredPlaces.length,
//                           itemBuilder: (context, index) =>
//                               _buildPlaceCard(filteredPlaces[index]),
//                         ),
//                       ),
//           ),
//         ],
//       ),
//       floatingActionButton: selectedPlaces.isNotEmpty
//           ? FloatingActionButton.extended(
//               onPressed: _addSelectedPlacesToPlan,
//               backgroundColor: _getTypeColor(widget.suggestionType),
//               icon: const Icon(Icons.add_task, color: Colors.white),
//               label: Text(
//                 'Add ${selectedPlaces.length} to Plan',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             )
//           : null,
//     );
//   }
// }

// // Add to Plan Dialog (giữ nguyên phần này)
// class AddToPlanDialog extends StatefulWidget {
//   final List<Map<String, dynamic>> selectedPlaces;
//   final VoidCallback onPlacesAdded;

//   const AddToPlanDialog({
//     super.key,
//     required this.selectedPlaces,
//     required this.onPlacesAdded,
//   });

//   @override
//   State<AddToPlanDialog> createState() => _AddToPlanDialogState();
// }

// class _AddToPlanDialogState extends State<AddToPlanDialog> {
//   List<Map<String, dynamic>> userPlans = [];
//   bool isLoading = true;
//   String? selectedPlanId;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserPlans();
//   }

//   Future<void> _loadUserPlans() async {
//     try {
//       // Replace with actual current user ID
//       final userDoc = await FirebaseFirestore.instance
//           .collection("users")
//           .doc("currentUserId") // TODO: Replace with actual user ID
//           .get();

//       if (userDoc.exists) {
//         final data = userDoc.data() as Map<String, dynamic>;
//         final List<dynamic> planIds = data["plans"] ?? [];

//         if (planIds.isNotEmpty) {
//           final snapshot = await FirebaseFirestore.instance
//               .collection("plans")
//               .where(FieldPath.documentId, whereIn: planIds.take(10).toList())
//               .orderBy("date", descending: true)
//               .get();

//           userPlans = snapshot.docs
//               .map((doc) => {"id": doc.id, ...doc.data()})
//               .toList();
//         }
//       }
//     } catch (e) {
//       print('Error loading plans: $e');
//     }

//     setState(() {
//       isLoading = false;
//     });
//   }

//   Future<void> _addPlacesToPlan() async {
//     if (selectedPlanId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please select a plan'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     try {
//       final newItineraryItems = widget.selectedPlaces
//           .map((place) => {
//                 'name': place['name'] ?? 'Unknown',
//                 'address': place['address'] ?? '',
//                 'description': place['description'] ?? '',
//                 'type': place['type'] ?? '',
//                 'completed': false,
//                 'memoryPhotos': [],
//                 'addedAt': Timestamp.now(),
//               })
//           .toList();

//       final planDoc = await FirebaseFirestore.instance
//           .collection('plans')
//           .doc(selectedPlanId)
//           .get();

//       if (planDoc.exists) {
//         final currentItinerary =
//             List<Map<String, dynamic>>.from(planDoc.data()!['itinerary'] ?? []);
//         currentItinerary.addAll(newItineraryItems);

//         await FirebaseFirestore.instance
//             .collection('plans')
//             .doc(selectedPlanId)
//             .update({'itinerary': currentItinerary});

//         widget.onPlacesAdded();

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(
//                   'Added ${widget.selectedPlaces.length} places to your plan!'),
//               backgroundColor: Colors.green,
//               behavior: SnackBarBehavior.floating,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error adding places: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       title: const Row(
//         children: [
//           Icon(Icons.add_task, color: Color(0xffFFC8DD)),
//           SizedBox(width: 8),
//           Text('Add to Plan'),
//         ],
//       ),
//       content: SizedBox(
//         width: double.maxFinite,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'Add ${widget.selectedPlaces.length} selected places to which plan?',
//               style: const TextStyle(fontSize: 16),
//             ),
//             const SizedBox(height: 16),
//             if (isLoading)
//               const Center(child: CircularProgressIndicator())
//             else if (userPlans.isEmpty)
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(15),
//                 ),
//                 child: const Column(
//                   children: [
//                     Icon(Icons.calendar_today, size: 50, color: Colors.grey),
//                     SizedBox(height: 12),
//                     Text(
//                       'No plans available',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.grey,
//                       ),
//                     ),
//                     Text(
//                       'Create a plan first to add places',
//                       style: TextStyle(color: Colors.grey),
//                     ),
//                   ],
//                 ),
//               )
//             else
//               Container(
//                 constraints: const BoxConstraints(maxHeight: 200),
//                 child: SingleChildScrollView(
//                   child: Column(
//                     children: userPlans.map((plan) {
//                       final isSelected = selectedPlanId == plan['id'];
//                       final date = (plan['date'] as Timestamp).toDate();

//                       return Container(
//                         margin: const EdgeInsets.only(bottom: 8),
//                         child: RadioListTile<String>(
//                           value: plan['id'],
//                           groupValue: selectedPlanId,
//                           onChanged: (value) {
//                             setState(() {
//                               selectedPlanId = value;
//                             });
//                           },
//                           activeColor: const Color(0xffFFC8DD),
//                           title: Text(
//                             plan['title'] ?? 'Date Plan',
//                             style: const TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                           subtitle: Text(
//                             '${date.day}/${date.month}/${date.year}',
//                             style: TextStyle(color: Colors.grey[600]),
//                           ),
//                           tileColor: isSelected
//                               ? const Color(0xffFFC8DD).withOpacity(0.1)
//                               : null,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: Text(
//             'Cancel',
//             style: TextStyle(color: Colors.grey[600]),
//           ),
//         ),
//         ElevatedButton(
//           onPressed: userPlans.isEmpty ? null : _addPlacesToPlan,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: const Color(0xffFFC8DD),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//           ),
//           child: const Text(
//             'Add Places',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//         ),
//       ],
//     );
//   }
// }
