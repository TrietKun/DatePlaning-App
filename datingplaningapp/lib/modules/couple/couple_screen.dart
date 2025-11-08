import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datingplaningapp/modules/entities/app_user.dart';
import 'package:datingplaningapp/modules/services/cloudinaryService.dart';
import 'package:datingplaningapp/widgets/create_plan_button.dart';
import 'package:datingplaningapp/widgets/find_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CoupleScreen extends StatefulWidget {
  const CoupleScreen({super.key});

  @override
  State<CoupleScreen> createState() => _CoupleScreenState();
}

class _CoupleScreenState extends State<CoupleScreen>
    with SingleTickerProviderStateMixin {
  AppUser? partnerData;
  Map<String, dynamic>? coupleData;
  List<String> albumPhotos = [];
  List<Map<String, dynamic>> upcomingDates = [];
  bool isUploading = false;

  late AnimationController _heartBeatController;
  late Animation<double> _heartBeatAnimation;

  // Color Theme
  static const Color darkBg = Color(0xFF0D0D0D);
  static const Color cardBg = Color(0xFF1A1A1A);
  static const Color primaryPink = Color(0xFFFF6B9D);
  static const Color lightPink = Color(0xFFFFB6C1);
  static const Color accentPurple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    if (currentUser?.partnerId != null) {
      _loadCoupleData();
    }
  }

  void _initAnimations() {
    _heartBeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _heartBeatAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _heartBeatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heartBeatController.dispose();
    super.dispose();
  }

  // ==================== DATA LOADING ====================

  Future<void> _loadCoupleData() async {
    try {
      await Future.wait([
        _loadPartnerData(),
        _loadCoupleDocument(),
      ]);
      await _loadUpcomingDates();
    } catch (e) {
      _showError('Failed to load couple data');
    }
  }

  Future<void> _loadPartnerData() async {
    final partnerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.partnerId)
        .get();

    if (partnerDoc.exists) {
      setState(() {
        partnerData = AppUser.fromMap(partnerDoc.id, partnerDoc.data()!);
      });
    }
  }

  Future<void> _loadCoupleDocument() async {
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
      await _createCoupleDocument(coupleId);
    }
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
      coupleData = {...defaultData, 'startDate': Timestamp.now()};
    });
  }

  Future<void> _loadUpcomingDates() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    final plans = userDoc.data()?['plans'] as List<dynamic>? ?? [];
    if (plans.isEmpty) {
      setState(() => upcomingDates = []);
      return;
    }

    final planDoc = await FirebaseFirestore.instance
        .collection('plans')
        .doc(plans.last)
        .get();

    setState(() {
      upcomingDates = planDoc.exists
          ? [
              {'id': planDoc.id, ...planDoc.data()!}
            ]
          : [];
    });
  }

  // ==================== HELPER METHODS ====================

  String _getCoupleId() {
    final ids = [currentUser!.uid, currentUser!.partnerId!];
    ids.sort();
    return ids.join('_');
  }

  int _getDaysCount() {
    if (coupleData?['startDate'] == null) return 0;
    final startDate = (coupleData!['startDate'] as Timestamp).toDate();
    return DateTime.now().difference(startDate).inDays;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryPink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ==================== STATUS UPDATE ====================

  Future<void> _updateStatus() async {
    final controller = TextEditingController(text: coupleData?['status'] ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _StatusUpdateDialog(
        controller: controller,
        onSave: () => Navigator.pop(context, controller.text),
      ),
    );

    if (result != null) {
      await FirebaseFirestore.instance
          .collection('couples')
          .doc(_getCoupleId())
          .update({'status': result});

      setState(() => coupleData!['status'] = result);
      _showSuccess('Status updated! 💕');
    }
  }

  // ==================== PHOTO MANAGEMENT ====================

  Future<void> _pickAndUploadImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => isUploading = true);

      // Upload lên Cloudinary
      final imageFile = File(image.path);
      final folderName = 'couple_photos/${_getCoupleId()}';

      final downloadUrl = await CloudinaryService.uploadImage(
        imageFile,
        folderName,
      );

      // Cập nhật vào Firestore
      setState(() => albumPhotos.add(downloadUrl));

      await FirebaseFirestore.instance
          .collection('couples')
          .doc(_getCoupleId())
          .update({'albumPhotos': albumPhotos});

      _showSuccess('Photo added successfully! 💕');
    } catch (e) {
      _showError('Failed to upload photo: ${e.toString()}');
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _deletePhoto(int index) async {
    try {
      final photoUrl = albumPhotos[index];

      try {
        await FirebaseStorage.instance.refFromURL(photoUrl).delete();
      } catch (e) {
        // Storage deletion might fail if photo doesn't exist
      }

      setState(() => albumPhotos.removeAt(index));

      await FirebaseFirestore.instance
          .collection('couples')
          .doc(_getCoupleId())
          .update({'albumPhotos': albumPhotos});

      _showSuccess('Photo deleted');
    } catch (e) {
      _showError('Failed to delete photo');
    }
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => _DeletePhotoDialog(
        onDelete: () {
          Navigator.pop(context);
          _deletePhoto(index);
        },
      ),
    );
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    if (currentUser?.partnerId == null) {
      return _buildEmptyState();
    }

    if (partnerData == null || coupleData == null) {
      return _buildLoadingState();
    }

    return Container(
      color: darkBg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 24),
              _buildDaysCountSection(),
              const SizedBox(height: 24),
              _buildStatusSection(),
              const SizedBox(height: 24),
              _buildAlbumSection(),
              const SizedBox(height: 24),
              _buildUpcomingDatesSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: darkBg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryPink.withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 15,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: const Image(
                          image: AssetImage('assets/images/alone.jpg'),
                          width: 200,
                          height: 200,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              const FindButton(),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: child,
                    );
                  },
                  child: Text(
                    'Find your soulmate and start\nyour love journey together! 💕',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: darkBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryPink),
            const SizedBox(height: 20),
            Text(
              'Loading your love story...',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryPink.withOpacity(0.3),
              accentPurple.withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryPink.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: primaryPink.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAvatarCard(
              currentUser?.profileImage,
              currentUser?.name ?? 'You',
              primaryPink,
            ),
            ScaleTransition(
              scale: _heartBeatAnimation,
              child: _buildHeartIcon(),
            ),
            _buildAvatarCard(
              partnerData?.profileImage,
              partnerData?.name ?? 'Partner',
              accentPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCard(String? imageUrl, String name, Color borderColor) {
    return Column(
      children: [
        Hero(
          tag: 'avatar_$name',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: borderColor.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 45,
              backgroundImage: imageUrl != null
                  ? NetworkImage(imageUrl)
                  : const AssetImage('assets/images/hearts.png')
                      as ImageProvider,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHeartIcon() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [primaryPink, lightPink]),
            boxShadow: [
              BoxShadow(
                color: primaryPink.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.favorite, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 8),
        const Text(
          '∞',
          style: TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDaysCountSection() {
    final daysCount = _getDaysCount();
    final startDate = coupleData!['startDate'] as Timestamp;
    final formattedDate = DateFormat('dd/MM/yyyy').format(startDate.toDate());

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryPink.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: primaryPink.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '💕 Together for',
              style: TextStyle(
                fontSize: 18,
                color: primaryPink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: daysCount),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [primaryPink, accentPurple]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryPink.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              daysCount == 1 ? 'day' : 'days',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Since $formattedDate',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentPurple.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: accentPurple.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '✨ Our Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentPurple,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _updateStatus,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryPink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit, color: primaryPink, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            coupleData!['status'] ?? 'Together forever ❤️',
            style: const TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1.5,
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
              '📸 Our Memories',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton.icon(
                onPressed: isUploading ? null : _pickAndUploadImage,
                icon: Icon(
                  isUploading
                      ? Icons.hourglass_empty
                      : Icons.add_photo_alternate,
                  size: 20,
                ),
                label: Text(isUploading ? 'Uploading...' : 'Add Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        albumPhotos.isEmpty ? _buildEmptyAlbum() : _buildPhotoGrid(),
      ],
    );
  }

  Widget _buildEmptyAlbum() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryPink.withOpacity(0.3), width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: primaryPink.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No memories yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Photo" to capture your moments',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: albumPhotos.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildPhotoCard(index),
        );
      },
    );
  }

  Widget _buildPhotoCard(int index) {
    return GestureDetector(
      onLongPress: () => _showDeleteConfirmation(index),
      child: Hero(
        tag: 'photo_$index',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryPink.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: primaryPink.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Image.network(
                  albumPhotos[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: cardBg,
                      child: Center(
                        child: CircularProgressIndicator(color: primaryPink),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: cardBg,
                      child: Icon(Icons.error_outline,
                          color: primaryPink, size: 40),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showDeleteConfirmation(index),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingDatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💝 Upcoming Date',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        upcomingDates.isEmpty ? _buildEmptyDates() : _buildDatesList(),
        const SizedBox(height: 20),
        const CreatePlanButton(),
      ],
    );
  }

  Widget _buildEmptyDates() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryPink.withOpacity(0.3), width: 2),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 48,
              color: primaryPink.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No upcoming dates',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create romantic plans together! 💕',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: upcomingDates.length,
      itemBuilder: (context, index) => _buildDateCard(upcomingDates[index]),
    );
  }

  Widget _buildDateCard(Map<String, dynamic> date) {
    final Timestamp? timestamp = date['dateTime'] as Timestamp?;
    final dateTime = timestamp?.toDate();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryPink.withOpacity(0.2),
            accentPurple.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryPink.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryPink.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryPink, accentPurple]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.favorite, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date['title'] ?? 'Romantic Date',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date['location'] ?? 'No location',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryPink.withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: primaryPink, size: 18),
                const SizedBox(width: 8),
                Text(
                  dateTime != null
                      ? DateFormat('dd MMM yyyy, HH:mm').format(dateTime)
                      : 'Date not set',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (date['description'] != null &&
              date['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              date['description'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== DIALOG WIDGETS ====================

class _StatusUpdateDialog extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;

  const _StatusUpdateDialog({
    required this.controller,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFFFF6B9D).withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '✨ Update Status',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              maxLength: 100,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'How\'s your relationship? 💕',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: const Color(0xFFFF6B9D).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: const Color(0xFFFF6B9D).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF6B9D), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B9D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletePhotoDialog extends StatelessWidget {
  final VoidCallback onDelete;

  const _DeletePhotoDialog({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delete Photo?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This precious memory will be permanently deleted.\nThis action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Keep Photo',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
