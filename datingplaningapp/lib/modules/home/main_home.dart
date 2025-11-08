import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datingplaningapp/modules/chat/chat_screen.dart';
import 'package:datingplaningapp/modules/couple/couple_screen.dart';
import 'package:datingplaningapp/modules/home/home_screen.dart';
import 'package:datingplaningapp/modules/plan/plan_screen.dart';
import 'package:datingplaningapp/modules/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import '../entities/app_user.dart';

class MainHome extends StatefulWidget {
  const MainHome({super.key});

  @override
  State<MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fabAnimationController;

  // Colors
  final Color darkBg = const Color(0xFF0D0D0D);
  final Color cardBg = const Color(0xFF1A1A1A);
  final Color primaryPink = const Color(0xFFFF6B9D);
  final Color lightPink = const Color(0xFFFFB6C1);
  final Color accentPurple = const Color(0xFF8B5CF6);

  final List<Widget> _tabs = const [
    HomeScreen(),
    ChatScreen(),
    PlanScreen(),
    CoupleScreen(),
    ProfileScreen(),
  ];

  final List<IconData> _icons = [
    Icons.home_rounded,
    Icons.chat_bubble_rounded,
    Icons.calendar_month_rounded,
    Icons.favorite_rounded,
    Icons.person_rounded,
  ];

  final List<String> _labels = [
    'Home',
    'Chat',
    'Plan',
    'Couple',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimationController.forward();

    Future.microtask(() {
      print("🔍 Checking currentUser: $currentUser");
      if (currentUser != null) {
        print("✅ Starting listeners for UID: ${currentUser!.uid}");
        listenIncomingRequests(currentUser!.uid);
        listenSentRequests(currentUser!.uid);
      } else {
        print("⚠️ currentUser is null, cannot start listeners");
      }
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _fabAnimationController.reset();
    _fabAnimationController.forward();
  }

  void listenIncomingRequests(String uid) {
    FirebaseFirestore.instance
        .collection("friend_requests")
        .where("to", isEqualTo: uid)
        .where("status", isEqualTo: "pending")
        .snapshots()
        .listen((snapshot) {
      print("Incoming requests count: ${snapshot.docs.length}");
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print("Incoming request data: $data");
        _showRequestDialog(doc.id, data["from"]);
      }
    });
  }

  void listenSentRequests(String uid) {
    FirebaseFirestore.instance
        .collection("friend_requests")
        .where("from", isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print("Sent request data: $data");
        if (data["status"] == "accepted") {
          _showAcceptedDialog();
          currentUser = AppUser(
            uid: currentUser!.uid,
            email: currentUser!.email,
            name: currentUser!.name,
            partnerId: data["to"],
          );

          FirebaseFirestore.instance
              .collection("friend_requests")
              .doc(doc.id)
              .delete();
        }
      }
    });
  }

  void _showAcceptedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryPink, lightPink]),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.celebration, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              "Thành công 🎉",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Người kia đã chấp nhận kết bạn với bạn!",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRequestDialog(String requestId, String fromUserId) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryPink, accentPurple]),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.person_add, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              "Lời mời kết bạn",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Người dùng $fromUserId muốn kết bạn với bạn",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("friend_requests")
                  .doc(requestId)
                  .update({"status": "rejected"});
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              "Từ chối",
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("friend_requests")
                  .doc(requestId)
                  .update({"status": "accepted"});

              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(currentUser!.uid)
                  .update({"partnerId": fromUserId});
              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(fromUserId)
                  .update({"partnerId": currentUser!.uid});

              currentUser = AppUser(
                uid: currentUser!.uid,
                email: currentUser!.email,
                name: currentUser!.name,
                partnerId: fromUserId,
              );
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                const Text("Chấp nhận", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: darkBg,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Container(
            key: ValueKey<int>(_selectedIndex),
            child: _tabs[_selectedIndex],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: cardBg,
            boxShadow: [
              BoxShadow(
                color: primaryPink.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (index) {
                  final isSelected = _selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onItemTapped(index),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glowing background for selected item
                                if (isSelected)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 40,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          primaryPink.withOpacity(0.3),
                                          accentPurple.withOpacity(0.3),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryPink.withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                // Icon
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: isSelected ? 0.8 : 1.0,
                                    end: isSelected ? 1.0 : 1.0,
                                  ),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.elasticOut,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: Icon(
                                        _icons[index],
                                        size: isSelected ? 28 : 24,
                                        color: isSelected
                                            ? primaryPink
                                            : Colors.white.withOpacity(0.5),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            // Label
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: TextStyle(
                                fontSize: isSelected ? 12 : 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? primaryPink
                                    : Colors.white.withOpacity(0.5),
                              ),
                              child: Text(_labels[index]),
                            ),
                            // Indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isSelected ? 30 : 0,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryPink, accentPurple],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
