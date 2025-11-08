import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datingplaningapp/modules/entities/app_user.dart';
import 'package:datingplaningapp/modules/plan/create_plan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

String currentUserId = currentUser!.uid;

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Colors
  final Color darkBg = const Color(0xFF0D0D0D);
  final Color cardBg = const Color(0xFF1A1A1A);
  final Color primaryPink = const Color(0xFFFF6B9D);
  final Color lightPink = const Color(0xFFFFB6C1);
  final Color accentPurple = const Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchUserPlans() async {
    final userDoc =
        await _firestore.collection("users").doc(currentUserId).get();
    if (!userDoc.exists) return [];

    final data = userDoc.data() as Map<String, dynamic>;
    final List<dynamic> planIds = data["plans"] ?? [];
    if (planIds.isEmpty) return [];

    if (planIds.length <= 10) {
      final snapshot = await _firestore
          .collection("plans")
          .where(FieldPath.documentId, whereIn: planIds)
          .get();

      final plans =
          snapshot.docs.map((doc) => {"id": doc.id, ...doc.data()}).toList();
      plans.sort((a, b) {
        final aDate = (a['date'] as Timestamp).toDate();
        final bDate = (b['date'] as Timestamp).toDate();
        return bDate.compareTo(aDate);
      });
      return plans;
    }

    final futures = planIds.map((id) async {
      final doc = await _firestore.collection("plans").doc(id).get();
      if (doc.exists) {
        return {"id": doc.id, ...doc.data()!};
      }
      return null;
    }).toList();

    final results = await Future.wait(futures);
    final plans = results.whereType<Map<String, dynamic>>().toList();
    plans.sort((a, b) {
      final aDate = (a['date'] as Timestamp).toDate();
      final bDate = (b['date'] as Timestamp).toDate();
      return bDate.compareTo(aDate);
    });
    return plans;
  }

  void _showPlanDetailDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => PlanDetailDialog(
        plan: plan,
        onPlanUpdated: () {
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchUserPlans(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryPink),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your plans...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyUI();
              }

              final plans = snapshot.data!;

              return CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == plans.length) {
                            return const SizedBox(height: 100);
                          }
                          return SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: _buildPlanCard(plans[index], index),
                            ),
                          );
                        },
                        childCount: plans.length + 1,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fadeAnimation,
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreatePlan()),
            ).then((_) => setState(() {}));
          },
          backgroundColor: primaryPink,
          elevation: 8,
          icon: const Icon(Icons.add, color: Colors.white, size: 24),
          label: const Text(
            'New Plan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 150,
      floating: false,
      pinned: true,
      backgroundColor: darkBg,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'My Date Plans',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryPink.withOpacity(0.3),
                accentPurple.withOpacity(0.3),
              ],
            ),
          ),
          child: Center(
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primaryPink, lightPink],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryPink.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, int index) {
    final date = (plan['date'] as Timestamp).toDate();
    final time = (plan['time'] as Timestamp).toDate();
    final isCompleted = plan['completed'] ?? false;
    final itinerary = List<Map<String, dynamic>>.from(plan['itinerary'] ?? []);
    final completedCount =
        itinerary.where((item) => item['completed'] == true).length;

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: 0.9 + (value * 0.1),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCompleted
                ? [
                    Colors.green.withOpacity(0.2),
                    Colors.green.withOpacity(0.1),
                  ]
                : [
                    primaryPink.withOpacity(0.15),
                    accentPurple.withOpacity(0.15),
                  ],
          ),
          border: Border.all(
            color: isCompleted
                ? Colors.green.withOpacity(0.3)
                : primaryPink.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isCompleted ? Colors.green : primaryPink).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCompleted
                            ? [Colors.green, Colors.green.shade700]
                            : [primaryPink, lightPink],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (isCompleted ? Colors.green : primaryPink)
                              .withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.schedule,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCompleted ? 'Completed' : 'Upcoming',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.white),
                    color: cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          _showPlanDetailDialog(plan);
                          break;
                        case 'delete':
                          _deletePlan(plan['id']);
                          break;
                        case 'complete':
                          _togglePlanCompletion(plan['id'], !isCompleted);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, color: primaryPink),
                            const SizedBox(width: 12),
                            const Text('View Details',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'complete',
                        child: Row(
                          children: [
                            Icon(
                              isCompleted ? Icons.undo : Icons.check_circle,
                              color: isCompleted ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isCompleted ? 'Mark Incomplete' : 'Mark Complete',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, color: Colors.red),
                            const SizedBox(width: 12),
                            const Text('Delete',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Banner Image
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: Container(
                height: 180,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: plan['bannerImage'] != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            plan['bannerImage'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildDefaultBanner(),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : _buildDefaultBanner(),
              ),
            ),

            // Plan Details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan['title'] ?? 'Date Plan',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildInfoRow(
                    Icons.calendar_today,
                    DateFormat('EEEE, dd MMMM yyyy').format(date),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.access_time,
                    DateFormat('HH:mm').format(time),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.location_on,
                    plan['pickup'] ?? 'Not specified',
                  ),

                  const SizedBox(height: 20),

                  // Progress Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryPink.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.route, color: primaryPink, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$completedCount/${itinerary.length}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryPink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(
                              begin: 0,
                              end: itinerary.isNotEmpty
                                  ? completedCount / itinerary.length
                                  : 0,
                            ),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeInOut,
                            builder: (context, double value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(primaryPink),
                                minHeight: 8,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPlanDetailDialog(plan),
                      icon: const Icon(Icons.visibility, size: 20),
                      label: const Text(
                        'View Full Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: primaryPink.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryPink, accentPurple],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 50),
            SizedBox(height: 12),
            Text(
              'Date Plan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryPink.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryPink, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deletePlan(String planId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Plan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this plan? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection('plans').doc(planId).delete();
      await _firestore.collection('users').doc(currentUserId).update({
        'plans': FieldValue.arrayRemove([planId])
      });
      if (currentUser!.partnerId != null) {
        await _firestore
            .collection('users')
            .doc(currentUser!.partnerId)
            .update({
          'plans': FieldValue.arrayRemove([planId])
        });
      }
      setState(() {});
    }
  }

  Future<void> _togglePlanCompletion(String planId, bool completed) async {
    await _firestore
        .collection('plans')
        .doc(planId)
        .update({'completed': completed});
    setState(() {});
  }

  Widget _buildEmptyUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryPink.withOpacity(0.2),
                        accentPurple.withOpacity(0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryPink.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 80,
                    color: primaryPink,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          FadeTransition(
            opacity: _fadeAnimation,
            child: const Text(
              'No Date Plans Yet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Create your first romantic plan\nand make unforgettable memories together',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.6),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 40),
          ScaleTransition(
            scale: _fadeAnimation,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreatePlan()),
                ).then((_) => setState(() {}));
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 24),
              label: const Text(
                'Create First Plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 12,
                shadowColor: primaryPink.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Plan Detail Dialog continues in next part...
class PlanDetailDialog extends StatefulWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onPlanUpdated;

  const PlanDetailDialog({
    super.key,
    required this.plan,
    required this.onPlanUpdated,
  });

  @override
  State<PlanDetailDialog> createState() => _PlanDetailDialogState();
}

class _PlanDetailDialogState extends State<PlanDetailDialog>
    with TickerProviderStateMixin {
  late List<Map<String, dynamic>> itinerary;
  late bool isPlanCompleted;
  bool isUploading = false;

  final Color darkBg = const Color(0xFF0D0D0D);
  final Color cardBg = const Color(0xFF1A1A1A);
  final Color primaryPink = const Color(0xFFFF6B9D);
  final Color lightPink = const Color(0xFFFFB6C1);
  final Color accentPurple = const Color(0xFF8B5CF6);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    itinerary = List<Map<String, dynamic>>.from(widget.plan['itinerary'] ?? []);
    isPlanCompleted = widget.plan['completed'] ?? false;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _updateItinerary() async {
    await FirebaseFirestore.instance
        .collection('plans')
        .doc(widget.plan['id'])
        .update({
      'itinerary': itinerary,
      'completed': isPlanCompleted,
    });
    widget.onPlanUpdated();
  }

  Future<void> _addMemoryPhoto(int index) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        isUploading = true;
      });

      final String fileName =
          'plan_memories/${widget.plan['id']}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref(fileName);

      final bytes = await File(image.path).readAsBytes();
      final UploadTask uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        itinerary[index]['memoryPhotos'] = [
          ...(itinerary[index]['memoryPhotos'] ?? []),
          downloadUrl,
        ];
        isUploading = false;
      });

      await _updateItinerary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Memory photo added! 📸'),
            backgroundColor: primaryPink,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMemoryPhoto(int itemIndex, int photoIndex) async {
    try {
      final photoUrl = itinerary[itemIndex]['memoryPhotos'][photoIndex];

      try {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(photoUrl);
        await storageRef.delete();
      } catch (e) {
        print('Error deleting from storage: $e');
      }

      setState(() {
        (itinerary[itemIndex]['memoryPhotos'] as List).removeAt(photoIndex);
      });

      await _updateItinerary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo deleted'),
            backgroundColor: primaryPink,
          ),
        );
      }
    } catch (e) {
      print('Error deleting photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: darkBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: primaryPink.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryPink.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryPink, accentPurple],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.plan['title'] ?? 'Date Plan Details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: itinerary.length,
                  itemBuilder: (context, index) {
                    final item = itinerary[index];
                    final isCompleted = item['completed'] ?? false;
                    final memoryPhotos =
                        List<String>.from(item['memoryPhotos'] ?? []);

                    return TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      curve: Curves.easeOut,
                      builder: (context, double value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCompleted
                                ? Colors.green.withOpacity(0.5)
                                : primaryPink.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isCompleted ? Colors.green : primaryPink)
                                  .withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: InkWell(
                              onTap: () {
                                setState(() {
                                  itinerary[index]['completed'] = !isCompleted;
                                });
                                _updateItinerary();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isCompleted
                                        ? [Colors.green, Colors.green.shade700]
                                        : [
                                            primaryPink.withOpacity(0.3),
                                            accentPurple.withOpacity(0.3),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCompleted
                                        ? Colors.green
                                        : primaryPink.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  isCompleted
                                      ? Icons.check
                                      : Icons.circle_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            title: Text(
                              item['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCompleted
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: primaryPink,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item['address'],
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            iconColor: Colors.white,
                            collapsedIconColor: Colors.white,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item['description']?.isNotEmpty == true)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: darkBg,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          item['description'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            height: 1.5,
                                          ),
                                        ),
                                      ),

                                    const SizedBox(height: 20),

                                    // Memory Photos Header
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.photo_library,
                                          color: primaryPink,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Memory Photos',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${memoryPhotos.length}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: primaryPink,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Photos Grid
                                    if (memoryPhotos.isEmpty)
                                      Container(
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: darkBg,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: primaryPink.withOpacity(0.2),
                                            width: 2,
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons
                                                    .add_photo_alternate_outlined,
                                                color: primaryPink
                                                    .withOpacity(0.5),
                                                size: 40,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'No photos yet\nTap + to add memories',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    else
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                          childAspectRatio: 1,
                                        ),
                                        itemCount: memoryPhotos.length,
                                        itemBuilder: (context, photoIndex) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: primaryPink
                                                    .withOpacity(0.3),
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Image.network(
                                                    memoryPhotos[photoIndex],
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context,
                                                        child,
                                                        loadingProgress) {
                                                      if (loadingProgress ==
                                                          null) {
                                                        return child;
                                                      }
                                                      return Container(
                                                        color: darkBg,
                                                        child: Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                            color: primaryPink,
                                                            strokeWidth: 2,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Container(
                                                        color: darkBg,
                                                        child: Icon(
                                                          Icons.error_outline,
                                                          color: primaryPink,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  Positioned(
                                                    top: 4,
                                                    right: 4,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withOpacity(0.7),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                        onPressed: () =>
                                                            _deleteMemoryPhoto(
                                                                index,
                                                                photoIndex),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(4),
                                                        constraints:
                                                            const BoxConstraints(),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                    const SizedBox(height: 16),

                                    // Add Photo Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: isUploading
                                            ? null
                                            : () => _addMemoryPhoto(index),
                                        icon: Icon(
                                          isUploading
                                              ? Icons.hourglass_empty
                                              : Icons.add_a_photo,
                                          size: 18,
                                        ),
                                        label: Text(
                                          isUploading
                                              ? 'Uploading...'
                                              : 'Add Memory Photo',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryPink,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Complete Plan Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(
                    top: BorderSide(
                      color: primaryPink.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        isPlanCompleted = !isPlanCompleted;
                      });
                      _updateItinerary();
                    },
                    icon: Icon(
                      isPlanCompleted ? Icons.undo : Icons.check_circle,
                      color: Colors.white,
                      size: 22,
                    ),
                    label: Text(
                      isPlanCompleted
                          ? 'Mark as Incomplete'
                          : 'Complete This Plan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isPlanCompleted ? Colors.orange : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor:
                          (isPlanCompleted ? Colors.orange : Colors.green)
                              .withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
