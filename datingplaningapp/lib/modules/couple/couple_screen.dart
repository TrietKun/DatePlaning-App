import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datingplaningapp/modules/entities/app_user.dart';
import 'package:datingplaningapp/widgets/create_plan_button.dart';
import 'package:datingplaningapp/widgets/find_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CoupleScreen extends StatefulWidget {
  const CoupleScreen({super.key});

  @override
  State<CoupleScreen> createState() => _CoupleScreenState();
}

class _CoupleScreenState extends State<CoupleScreen> {
  AppUser? partnerData;
  Map<String, dynamic>? coupleData;
  List<String> albumPhotos = [];
  List<Map<String, dynamic>> upcomingDates = [];

  @override
  void initState() {
    super.initState();
    if (currentUser?.partnerId != null) {
      _loadCoupleData();
    }
  }

  Future<void> _loadCoupleData() async {
    try {
      // Load partner data
      final partnerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.partnerId)
          .get();

      if (partnerDoc.exists) {
        setState(() {
          partnerData = AppUser.fromMap(partnerDoc.id, partnerDoc.data()!);
        });
      }

      // Load couple data
      final coupleId = _getCoupleId();
      final coupleDoc = await FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .get();

      if (coupleDoc.exists) {
        setState(() {
          coupleData = coupleDoc.data();
          albumPhotos = List<String>.from(coupleData!['albumPhotos'] ?? []);
        });
      } else {
        // Tạo couple document mới
        await _createCoupleDocument(coupleId);
      }

      // Load upcoming dates
      _loadUpcomingDates();
    } catch (e) {
      print('Error loading couple data: $e');
    }
  }

  String _getCoupleId() {
    final ids = [currentUser!.uid, currentUser!.partnerId!];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _createCoupleDocument(String coupleId) async {
    final defaultData = {
      'startDate': FieldValue.serverTimestamp(),
      'status': 'Together forever ❤️',
      'albumPhotos': [],
      'user1': currentUser!.uid,
      'user2': currentUser!.partnerId,
    };

    await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .set(defaultData);

    setState(() {
      coupleData = {
        ...defaultData,
        'startDate': Timestamp.now(),
      };
    });
  }

  Future<void> _loadUpcomingDates() async {
    // Lấy user document
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    final plans = userDoc.data()?['plans'] as List<dynamic>? ?? [];

    if (plans.isEmpty) {
      setState(() {
        upcomingDates = [];
      });
      return;
    }

    // Lấy id mới nhất (cuối mảng)
    final latestPlanId = plans.last;

    // Lấy dữ liệu plan từ collection plans
    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(latestPlanId)
        .get();

    if (!planDoc.exists) {
      setState(() {
        upcomingDates = [];
      });
      return;
    }

    setState(() {
      upcomingDates = [
        {
          ...planDoc.data()!,
          'id': planDoc.id,
        }
      ];
    });
  }

  int _getDaysCount() {
    if (coupleData?['startDate'] == null) return 0;
    final startDate = (coupleData!['startDate'] as Timestamp).toDate();
    final now = DateTime.now();
    return now.difference(startDate).inDays;
  }

  Future<void> _updateStatus() async {
    final controller = TextEditingController(text: coupleData?['status'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your couple status...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('couples')
                  .doc(_getCoupleId())
                  .update({'status': controller.text});

              setState(() {
                coupleData!['status'] = controller.text;
              });

              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    // Giả lập thêm ảnh (trong thực tế sẽ dùng image_picker)
    final photoUrl =
        'https://picsum.photos/200/200?random=${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      albumPhotos.add(photoUrl);
    });

    await FirebaseFirestore.instance
        .collection('couples')
        .doc(_getCoupleId())
        .update({'albumPhotos': albumPhotos});
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser?.partnerId == null) {
      return const SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(100)),
              child: Image(
                image: AssetImage('assets/images/alone.jpg'),
                width: 200,
                height: 200,
              ),
            ),
            SizedBox(height: 20),
            FindButton(),
            SizedBox(height: 50),
            Center(
              child: Text(
                'Please find a partner to start your love journey!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (partnerData == null || coupleData == null) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar + Names Section
            _buildAvatarSection(),

            const SizedBox(height: 20),

            // Days Count Section
            _buildDaysCountSection(),

            const SizedBox(height: 20),

            // Status Section
            _buildStatusSection(),

            const SizedBox(height: 30),

            // Album Section
            _buildAlbumSection(),

            const SizedBox(height: 30),

            // Upcoming Dates Section
            _buildUpcomingDatesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffFFC8DD), Color(0xffCDB4DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // User 1
          Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: currentUser?.profileImage != null
                    ? NetworkImage(currentUser!.profileImage!)
                    : const AssetImage('assets/images/hearts.png')
                        as ImageProvider,
              ),
              const SizedBox(height: 8),
              Text(
                currentUser?.name ?? 'You',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          // Heart Icon
          const Column(
            children: [
              Icon(
                Icons.favorite,
                color: Colors.red,
                size: 40,
              ),
              SizedBox(height: 4),
              Text(
                '❤️',
                style: TextStyle(fontSize: 24),
              ),
            ],
          ),

          // User 2 (Partner)
          Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: partnerData?.profileImage != null
                    ? NetworkImage(partnerData!.profileImage!)
                    : const AssetImage('assets/images/hearts.png')
                        as ImageProvider,
              ),
              const SizedBox(height: 8),
              Text(
                partnerData?.name ?? 'Partner',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaysCountSection() {
    final daysCount = _getDaysCount();
    final startDate = coupleData!['startDate'] as Timestamp;
    final formattedDate = DateFormat('dd/MM/yyyy').format(startDate.toDate());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.pink[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.pink[100]!),
      ),
      child: Column(
        children: [
          const Text(
            '💕 Together for',
            style: TextStyle(fontSize: 18, color: Colors.pink),
          ),
          const SizedBox(height: 8),
          Text(
            '$daysCount',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.pink,
            ),
          ),
          Text(
            daysCount == 1 ? 'day' : 'days',
            style: const TextStyle(fontSize: 18, color: Colors.pink),
          ),
          const SizedBox(height: 8),
          Text(
            'Since $formattedDate',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Our Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              IconButton(
                onPressed: _updateStatus,
                icon: const Icon(Icons.edit, color: Colors.purple),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            coupleData!['status'] ?? 'Together forever ❤️',
            style: const TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📸 Our Album',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            IconButton(
              onPressed: _addPhoto,
              icon: const Icon(Icons.add_photo_alternate, color: Colors.pink),
            ),
          ],
        ),
        const SizedBox(height: 12),
        albumPhotos.isEmpty
            ? Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, size: 50, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No photos yet\nTap + to add memories',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: albumPhotos.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      albumPhotos[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error, color: Colors.grey),
                        );
                      },
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildUpcomingDatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💝 Upcoming Dates',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        upcomingDates.isEmpty
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange[100]!),
                ),
                child: const Center(
                  child: Text(
                    'No upcoming dates planned\nCreate some romantic plans! 💕',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: upcomingDates.length,
                itemBuilder: (context, index) {
                  final date = upcomingDates[index];
                  final Timestamp? timestamp = date['dateTime'] as Timestamp?;
                  final dateTime = timestamp?.toDate();

                  final formattedDate = dateTime != null
                      ? DateFormat('EEE, MMM d, y').format(dateTime)
                      : 'No date';
                  final formattedTime = dateTime != null
                      ? DateFormat('h:mm a').format(dateTime)
                      : '--:--';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink[100]!, Colors.purple[100]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date['title'] ?? 'Date Night',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 16, color: Colors.purple),
                            const SizedBox(width: 8),
                            Text(
                              formattedDate,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 16, color: Colors.purple),
                            const SizedBox(width: 8),
                            Text(
                              formattedTime,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        if (date['location'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 16, color: Colors.purple),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  date['location'],
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
        const SizedBox(height: 20),
        const CreatePlanButton(),
      ],
    );
  }
}
