import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datingplaningapp/modules/entities/app_user.dart';
import 'package:datingplaningapp/modules/plan/create_plan.dart';
import 'package:datingplaningapp/widgets/create_plan_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
          .orderBy("date", descending: true)
          .get();
      return snapshot.docs.map((doc) => {"id": doc.id, ...doc.data()}).toList();
    }

    final futures = planIds.map((id) async {
      final doc = await _firestore.collection("plans").doc(id).get();
      if (doc.exists) {
        return {"id": doc.id, ...doc.data()!};
      }
      return null;
    }).toList();

    final results = await Future.wait(futures);
    return results.whereType<Map<String, dynamic>>().toList();
  }

  void _showPlanDetailDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (context) => PlanDetailDialog(
          plan: plan,
          onPlanUpdated: () {
            setState(() {}); // Refresh the list
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchUserPlans(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xffFFC8DD)),
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
                            return const SizedBox(height: 100); // Space for FAB
                          }
                          return _buildPlanCard(plans[index]);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePlan()),
          ).then((_) => setState(() {}));
        },
        backgroundColor: const Color(0xffFFC8DD),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Plan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xffFFC8DD),
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'My Date Plans',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffFFC8DD), Color(0xffCDB4DB)],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.favorite,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final date = (plan['date'] as Timestamp).toDate();
    final time = (plan['time'] as Timestamp).toDate();
    final isCompleted = plan['completed'] ?? false;
    final itinerary = List<Map<String, dynamic>>.from(plan['itinerary'] ?? []);
    final completedCount =
        itinerary.where((item) => item['completed'] == true).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isCompleted
                  ? [Colors.green[50]!, Colors.green[100]!]
                  : [Colors.white, const Color(0xffFFC8DD).withOpacity(0.1)],
            ),
          ),
          child: Column(
            children: [
              // Header with status badge
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green
                            : const Color(0xffFFC8DD),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCompleted ? 'Completed' : 'In Progress',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
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
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'complete',
                          child: Row(
                            children: [
                              Icon(
                                isCompleted ? Icons.undo : Icons.check_circle,
                                color:
                                    isCompleted ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(isCompleted
                                  ? 'Mark Incomplete'
                                  : 'Mark Complete'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Banner image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xffFFC8DD).withOpacity(0.3),
                        const Color(0xffCDB4DB).withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: plan['bannerImage'] != null
                      ? Image.network(
                          plan['bannerImage'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultBanner(),
                        )
                      : _buildDefaultBanner(),
                ),
              ),

              // Plan details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['title'] ?? 'Date Plan',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildInfoRow(Icons.calendar_today, 'Date',
                        DateFormat('EEEE, dd/MM/yyyy').format(date)),
                    _buildInfoRow(Icons.access_time, 'Time',
                        DateFormat('HH:mm').format(time)),
                    _buildInfoRow(Icons.location_on, 'Pickup',
                        plan['pickup'] ?? 'Not specified'),

                    const SizedBox(height: 16),

                    // Progress indicator
                    Row(
                      children: [
                        const Icon(Icons.route,
                            color: Color(0xffFFC8DD), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Progress: $completedCount/${itinerary.length} destinations',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    LinearProgressIndicator(
                      value: itinerary.isNotEmpty
                          ? completedCount / itinerary.length
                          : 0,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xffFFC8DD)),
                      minHeight: 6,
                    ),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showPlanDetailDialog(plan),
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffCDB4DB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isCompleted
                                ? null
                                : () => _showPlanDetailDialog(plan),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Plan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCompleted
                                  ? Colors.grey
                                  : const Color(0xffFFC8DD),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
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
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffFFC8DD), Color(0xffCDB4DB)],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 40),
            SizedBox(height: 8),
            Text(
              'Date Plan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xffFFC8DD), size: 18),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlan(String planId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Delete Plan'),
        content: const Text(
            'Are you sure you want to delete this plan? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xffFFC8DD).withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Icon(
              Icons.calendar_today,
              size: 80,
              color: Color(0xffFFC8DD),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Date Plans Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create your first romantic plan\nand make unforgettable memories',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CreatePlanButton()),
              ).then((_) => setState(() {}));
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Create First Plan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffFFC8DD),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 8,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _PlanDetailDialogState extends State<PlanDetailDialog> {
  late List<Map<String, dynamic>> itinerary;
  late bool isPlanCompleted;

  @override
  void initState() {
    super.initState();
    itinerary = List<Map<String, dynamic>>.from(widget.plan['itinerary'] ?? []);
    isPlanCompleted = widget.plan['completed'] ?? false;
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
    // Simulate adding photo (in real app, use image_picker)
    final photoUrl =
        'https://picsum.photos/300/200?random=${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      itinerary[index]['memoryPhotos'] = [
        ...(itinerary[index]['memoryPhotos'] ?? []),
        photoUrl,
      ];
    });

    await _updateItinerary();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xffFFC8DD), Color(0xffCDB4DB)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
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
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: itinerary.length,
              itemBuilder: (context, index) {
                final item = itinerary[index];
                final isCompleted = item['completed'] ?? false;
                final memoryPhotos =
                    List<String>.from(item['memoryPhotos'] ?? []);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color:
                          isCompleted ? Colors.green : const Color(0xffFFC8DD),
                      width: 2,
                    ),
                  ),
                  child: ExpansionTile(
                    leading: InkWell(
                      onTap: () {
                        setState(() {
                          itinerary[index]['completed'] = !isCompleted;
                        });
                        _updateItinerary();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCompleted ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : Icons.circle_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    title: Text(
                      item['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? Colors.grey : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      item['address'],
                      style: TextStyle(
                        color: isCompleted ? Colors.grey : Colors.black54,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item['description']?.isNotEmpty == true)
                              Text(
                                item['description'],
                                style: const TextStyle(fontSize: 14),
                              ),

                            const SizedBox(height: 12),

                            // Memory photos section
                            const Text(
                              'Memory Photos:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            if (memoryPhotos.isEmpty)
                              Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.grey[400]!,
                                      style: BorderStyle.none),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No photos yet\nTap + to add memories',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                                itemCount: memoryPhotos.length,
                                itemBuilder: (context, photoIndex) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      memoryPhotos[photoIndex],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.error),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 12),

                            // Add photo button
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () => _addMemoryPhoto(index),
                                icon: const Icon(Icons.add_a_photo, size: 18),
                                label: const Text('Add Memory Photo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xffFFC8DD),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Complete plan button
          Container(
            padding: const EdgeInsets.all(16),
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
                ),
                label: Text(
                  isPlanCompleted ? 'Mark as Incomplete' : 'Complete This Plan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPlanCompleted ? Colors.orange : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
