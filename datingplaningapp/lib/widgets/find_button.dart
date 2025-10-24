import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datingplaningapp/modules/entities/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FindButton extends StatefulWidget {
  const FindButton({super.key});

  @override
  State<FindButton> createState() => _FindButtonState();
}

class _FindButtonState extends State<FindButton> {
  //khởi tạo 1 user tạm thời rỗng
  AppUser? foundPartner;

  //hàm tìm kiếm partner theo email
  Future<void> findPartnerByEmail(String email) async {
    //tìm kiếm user có email tương ứng
    final query = await FirebaseFirestore.instance
        .collection("users")
        .where('email', isEqualTo: email)
        .get();
    //cập nhật partnerId cho currentUser
    if (query.docs.isEmpty) {
      //không tìm thấy user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user found with that email')),
      );
      return;
    }
    final foundPartnerId = query.docs.first.id;
    setState(() {
      foundPartner = AppUser.fromMap(foundPartnerId, query.docs.first.data());
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Found partner ID: $foundPartnerId')),
    );
  }

  Future<void> acceptFriendRequest(String requestId, String partnerId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final usersRef = FirebaseFirestore.instance.collection('users');
    final requestsRef =
        FirebaseFirestore.instance.collection('friend_requests');

    final batch = FirebaseFirestore.instance.batch();

    // Update partnerId cho cả 2
    batch.update(usersRef.doc(currentUser.uid), {
      'partnerId': partnerId,
    });
    batch.update(usersRef.doc(partnerId), {
      'partnerId': currentUser.uid,
    });

    // Update status request
    batch.update(requestsRef.doc(requestId), {
      'status': 'accepted',
    });

    await batch.commit();
  }

  Future<void> sendFriendRequest(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final requestsRef =
        FirebaseFirestore.instance.collection('friend_requests');

    // Kiểm tra có request ngược lại chưa - SỬA FIELD NAMES
    final reverse = await requestsRef
        .where('from', isEqualTo: toUserId) // SỬA: từ 'fromUserId' thành 'from'
        .where('to',
            isEqualTo: currentUser.uid) // SỬA: từ 'toUserId' thành 'to'
        .where('status', isEqualTo: 'pending')
        .get();

    if (reverse.docs.isNotEmpty) {
      // Cả hai đã gửi cho nhau -> auto accept
      await acceptFriendRequest(reverse.docs.first.id, toUserId);
      return;
    }

    // Nếu chưa thì tạo request mới - SỬA FIELD NAMES
    await requestsRef.add({
      'from': currentUser.uid, // SỬA: từ 'fromUserId' thành 'from'
      'to': toUserId, // SỬA: từ 'toUserId' thành 'to'
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            final _emailController = TextEditingController();
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    '🔎 Tìm bạn',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  content: SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ô nhập email
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: Color(0xffffc8dd),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey,
                                blurRadius: 8,
                                offset: const Offset(4, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: "Nhập email người cần tìm",
                              prefixIcon:
                                  const Icon(Icons.email, color: Colors.pink),
                              filled: true,
                              fillColor: Color(0xffffc8dd),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 20),
                            ),
                          ),
                        ),
                        // Nếu đã tìm thấy user
                        if (foundPartner != null)
                          Column(
                            children: [
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.pink[50],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundImage: AssetImage(
                                        'assets/images/hearts.png',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        foundPartner!.name ?? 'No name',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        sendFriendRequest(foundPartner!.uid);
                                        Navigator.of(context).pop();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xffcdb4db),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text("Kết bạn"),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => {
                        Navigator.of(context).pop(),
                        setState(() {
                          foundPartner = null;
                        }),
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        String email = _emailController.text.trim();
                        final query = await FirebaseFirestore.instance
                            .collection("users")
                            .where('email', isEqualTo: email)
                            .get();
                        if (query.docs.isEmpty) {
                          setDialogState(() {
                            foundPartner = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Không tìm thấy user'),
                            ),
                          );
                          return;
                        }
                        final foundPartnerId = query.docs.first.id;
                        setState(() {
                          foundPartner = AppUser.fromMap(
                            foundPartnerId,
                            query.docs.first.data(),
                          );
                        });
                        setDialogState(() {}); // refresh UI dialog
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xffcdb4db),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Tìm'),
                    ),
                  ],
                );
              },
            );
          },
        ).then((_) {
          // Reset foundPartner khi đóng dialog
          setState(() {
            foundPartner = null;
          });
        });
      },
      child: const Text('Find Partner'),
    );
  }
}
