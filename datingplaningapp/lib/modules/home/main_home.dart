import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datingplaningapp/modules/chat/chat_screen.dart';
import 'package:datingplaningapp/modules/couple/couple_screen.dart';
import 'package:datingplaningapp/modules/home/home_screen.dart';
import 'package:datingplaningapp/modules/plan/plan_screen.dart';
import 'package:datingplaningapp/modules/profile/profile_screen.dart';
import 'package:flutter/material.dart';

import '../entities/app_user.dart'; // chỗ bạn định nghĩa AppUser

class MainHome extends StatefulWidget {
  const MainHome({super.key});

  @override
  State<MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = const [
    HomeScreen(),
    ChatScreen(),
    PlanScreen(),
    CoupleScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  // 🟢 Lắng nghe lời mời kết bạn
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

  // 🟢 Lắng nghe lời mời mình đã gửi đi
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
          // SỬA: Người gửi request sẽ có partnerId là người nhận (data["to"])
          currentUser = AppUser(
            uid: currentUser!.uid,
            email: currentUser!.email,
            name: currentUser!.name,
            partnerId: data["to"], // Đây là đúng rồi - người nhận request
          );

          // THÊM: Xóa request đã được accept để tránh trigger nhiều lần
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
        title: const Text("Thành công 🎉"),
        content: const Text("Người kia đã chấp nhận kết bạn với bạn!"),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
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
        title: const Text("Lời mời kết bạn"),
        content: Text("Người dùng $fromUserId muốn kết bạn với bạn"),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("friend_requests")
                  .doc(requestId)
                  .update({"status": "rejected"});
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Từ chối"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("friend_requests")
                  .doc(requestId)
                  .update({"status": "accepted"});

              // update partnerId của cả 2 user
              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(currentUser!.uid)
                  .update({"partnerId": fromUserId});
              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(fromUserId)
                  .update({"partnerId": currentUser!.uid});

              // update current user
              currentUser = AppUser(
                uid: currentUser!.uid,
                email: currentUser!.email,
                name: currentUser!.name,
                partnerId: fromUserId,
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Chấp nhận"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: _tabs[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today), label: 'Plan'),
            BottomNavigationBarItem(
                icon: Icon(Icons.favorite), label: 'Couple'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
