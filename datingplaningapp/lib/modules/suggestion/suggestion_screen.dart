import 'package:datingplaningapp/modules/http/overpass_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

// import 'package:datingplaningapp/modules/entities/app_user.dart';

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
    //nếu không được phép thì yêu cầu cấp quyền
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Quyền bị từ chối, không thể lấy vị trí
        setState(() {
          isLoading = false;
        });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Quyền bị từ chối vĩnh viễn, không thể lấy vị trí
      setState(() {
        isLoading = false;
      });
      return;
    }
    try {
      currentPosition = await Geolocator.getCurrentPosition();
      print('Current position: $currentPosition');
      await _loadNearbyPlaces();
    } catch (e) {
      await _loadNearbyPlaces();
    }
  }

  Future<void> _loadNearbyPlaces() async {
    setState(() {
      isLoading = true;
    });

    // Simulate API call with mock data based on suggestion type
    await Future.delayed(const Duration(milliseconds: 800));

    _fetchPlacesFromApi(widget.suggestionType);

    setState(() {
      isLoading = false;
    });
  }

  // gọi api để lấy các địa điểm gần đây dựa trên loại địa điểm, truyền String type
  Future<void> _fetchPlacesFromApi(String type) async {
    print('Fetching places for type: $type');
    //in ra currentPosition
    print('Current position: $currentPosition');
    if (currentPosition == null) return;
    setState(() {
      isLoading = true;
    });

    try {
      final places = await service.fetchPlaces(
        currentPosition!.latitude,
        currentPosition!.longitude,
        type,
      );

      // Chuyển đổi dữ liệu từ Overpass API sang định dạng mong muốn
      nearbyPlaces = places.map((place) {
        return {
          'id': place['id'].toString(),
          'name': place['tags']?['name'] ?? 'Unknown',
          'address': _formatAddress(place['tags'] ?? {}),
          'rating': (3 + (place['tags']?['rating'] ?? 0)).clamp(1, 5),
          'distance': place['distance'] != null
              ? '${(place['distance'] / 1000).toStringAsFixed(2)} km'
              : 'N/A',
          'imageUrl': _getTypeImageUrl(widget.suggestionType),
          'priceRange': '₫₫', // Placeholder
          'description': place['tags']?['description'] ??
              'A nice place to visit.', // Placeholder
          'openHours': place['tags']?['opening_hours'] ?? 'N/A',
          'type': widget.suggestionType[0].toUpperCase() +
              widget.suggestionType.substring(1),
        };
      }).toList();
    } catch (e) {
      print('Error fetching places: $e');
      nearbyPlaces = [];
    }

    setState(() {
      isLoading = false;
    });
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
      return place['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          place['address'].toLowerCase().contains(searchQuery.toLowerCase());
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
                    _getTypeColor(place['type']).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getTypeColor(place['type']).withOpacity(0.1),
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
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(place['imageUrl']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getTypeColor(place['type']),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getTypeIcon(place['type']),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      place['type'],
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
                                      place['name'],
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
                                          place['rating'].toString(),
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
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

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
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    place['openHours'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
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
                                            : _getTypeColor(place['type']),
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
                                      foregroundColor:
                                          _getTypeColor(place['type']),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: _getTypeColor(place['type']),
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
        typeColor: _getTypeColor(place['type']),
        onAddToSelection: () => _addToSelectedPlaces(place),
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
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredPlaces.length,
                        itemBuilder: (context, index) =>
                            _buildPlaceCard(filteredPlaces[index]),
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

  _getTypeImageUrl(String suggestionType) {
    switch (suggestionType) {
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
        return 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400';
    }
  }
}

String _formatAddress(Map<String, dynamic> tags) {
  List<String> addressParts = [];
  if (tags.containsKey('addr:housenumber')) {
    addressParts.add(tags['addr:housenumber']);
  }
  if (tags.containsKey('addr:street')) {
    addressParts.add(tags['addr:street']);
  }
  // Có thể thêm các trường khác như 'addr:city', 'addr:district'
  return addressParts.join(' ');
}

// Add to Plan Dialog
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
      // Note: currentUser needs to be imported/defined properly in your app
      // This assumes you have a currentUser instance available
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc("currentUserId") // Replace with actual current user ID
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
      // Convert selected places to itinerary items
      final newItineraryItems = widget.selectedPlaces
          .map((place) => {
                'name': place['name'],
                'address': place['address'],
                'description': place['description'],
                'type': place['type'],
                'completed': false,
                'memoryPhotos': [],
                'addedAt': Timestamp.now(),
              })
          .toList();

      // Get current plan
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Added ${widget.selectedPlaces.length} places to your plan!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding places: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

// Place Detail Bottom Sheet Widget
class PlaceDetailBottomSheet extends StatelessWidget {
  final Map<String, dynamic> place;
  final Color typeColor;
  final VoidCallback onAddToSelection;
  final bool isSelected;

  const PlaceDetailBottomSheet({
    super.key,
    required this.place,
    required this.typeColor,
    required this.onAddToSelection,
    required this.isSelected,
  });

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: typeColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Container(
                        height: 250,
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(
                            image: NetworkImage(place['imageUrl']),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Details
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place['name'],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.star,
                                    color: Colors.orange, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  '${place['rating']} rating',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: typeColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    place['type'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                                Icons.location_on, 'Address', place['address']),
                            _buildDetailRow(Icons.access_time, 'Open Hours',
                                place['openHours']),
                            _buildDetailRow(Icons.attach_money, 'Price Range',
                                place['priceRange']),
                            _buildDetailRow(Icons.directions_walk, 'Distance',
                                place['distance']),
                            const SizedBox(height: 16),
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              place['description'],
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isSelected ? null : onAddToSelection,
                                icon: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.add_circle_outline,
                                ),
                                label: Text(
                                  isSelected
                                      ? 'Already Selected'
                                      : 'Add to Plan',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isSelected ? Colors.grey : typeColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
