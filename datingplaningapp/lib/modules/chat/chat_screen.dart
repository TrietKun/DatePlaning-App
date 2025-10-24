import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datingplaningapp/modules/entities/app_user.dart';
import 'package:datingplaningapp/widgets/find_button.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  // Animation controllers
  late AnimationController _sendButtonController;
  late AnimationController _messageAnimationController;
  late AnimationController _typingAnimationController;
  late Animation<double> _sendButtonAnimation;
  late Animation<double> _typingDotAnimation;

  // Pagination variables
  static const int _messagesLimit = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;
  List<DocumentSnapshot> _allMessages = [];

  // Typing indicator
  bool _isTyping = false;
  bool _partnerIsTyping = false;

  // UI State
  String _selectedBackground = 'gradient1';
  bool _showEmojiPicker = false;

  // Background options với gradients đẹp
  final Map<String, List<Color>> _backgroundOptions = {
    'gradient1': [Color(0xFFFF9A9E), Color(0xFFFECFEF), Color(0xFFFECFEF)],
    'gradient2': [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
    'gradient3': [Color(0xFFFFD3E1), Color(0xFFFFA8DC), Color(0xFFE0BBE4)],
    'gradient4': [Color(0xFFB2FEFA), Color(0xFF0ED2F7)],
    'gradient5': [Color(0xFFFBD3E9), Color(0xFFBB377D)],
    'gradient6': [Color(0xFFFFECD2), Color(0xFFFCB69F)],
  };

  // Emoji list mở rộng
  final List<String> _emojis = [
    '😀',
    '😂',
    '😍',
    '🥰',
    '😊',
    '😎',
    '🤔',
    '😮',
    '😢',
    '😡',
    '👍',
    '👎',
    '❤️',
    '💔',
    '🔥',
    '⭐',
    '🎉',
    '🎊',
    '💕',
    '💖',
    '😘',
    '😜',
    '🤗',
    '🤭',
    '😇',
    '🥺',
    '😋',
    '🤤',
    '😴',
    '🤯',
    '🙌',
    '👏',
    '💪',
    '🤝',
    '🙏',
    '✨',
    '🌟',
    '💫',
    '🎈',
    '🎁'
  ];

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _setupScrollListener();
    _setupAnimations();
    _setupTypingListener();
  }

  void _initializeChat() {
    _controller.addListener(() {
      final isTyping = _controller.text.isNotEmpty;
      if (_isTyping != isTyping) {
        _updateTypingStatus(isTyping);
      }
    });
  }

  void _setupAnimations() {
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _sendButtonAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(
            parent: _sendButtonController, curve: Curves.elasticOut));

    _typingDotAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(
            parent: _typingAnimationController, curve: Curves.easeInOut));

    _typingAnimationController.repeat(reverse: true);
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == 0 &&
          _hasMoreMessages &&
          !_isLoadingMore) {
        _loadMoreMessages();
      }
    });
  }

  void _setupTypingListener() {
    final chatId = getChatId();
    if (chatId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final partnerTyping = data['${getPartnerId()}_typing'] ?? false;
          if (mounted && _partnerIsTyping != partnerTyping) {
            setState(() => _partnerIsTyping = partnerTyping);
          }
        }
      });
    }
  }

  String getChatId() {
    if (currentUser == null || currentUser!.partnerId == null) return "";
    final ids = [currentUser!.uid, currentUser!.partnerId!];
    ids.sort();
    return ids.join("_");
  }

  String getPartnerId() {
    return currentUser?.partnerId ?? "";
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    _isTyping = isTyping;
    final chatId = getChatId();
    if (chatId.isNotEmpty) {
      await FirebaseFirestore.instance.collection("chats").doc(chatId).set({
        '${currentUser!.uid}_typing': isTyping,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() => _isLoadingMore = true);

    try {
      final chatId = getChatId();
      Query query = FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .orderBy("time", descending: true)
          .limit(_messagesLimit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final newMessages = snapshot.docs.reversed.toList();

        setState(() {
          _allMessages.insertAll(0, newMessages);
        });
      }

      if (snapshot.docs.length < _messagesLimit) {
        _hasMoreMessages = false;
      }
    } catch (e) {
      print('Error loading more messages: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    if ((_controller.text.trim().isEmpty && imageUrl == null) ||
        currentUser == null) return;

    final chatId = getChatId();
    final msg = _controller.text.trim();

    // Animation khi gửi tin nhắn
    _sendButtonController.forward().then((_) {
      _sendButtonController.reverse();
    });

    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .add({
      "senderId": currentUser!.uid,
      "message": msg,
      "imageUrl": imageUrl,
      "type": imageUrl != null ? "image" : "text",
      "time": FieldValue.serverTimestamp(),
    });

    _controller.clear();
    await _updateTypingStatus(false);
    _scrollToBottom();

    // Trigger animation cho tin nhắn mới
    _messageAnimationController.forward().then((_) {
      _messageAnimationController.reset();
    });
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        _showLoadingDialog();
        final imageUrl = await _uploadImage(File(image.path));
        Navigator.pop(context);
        await _sendMessage(imageUrl: imageUrl);
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog('Lỗi khi gửi ảnh: $e');
    }
  }

  Future<void> _takeAndSendPhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        _showLoadingDialog();
        final imageUrl = await _uploadImage(File(photo.path));
        Navigator.pop(context);
        await _sendMessage(imageUrl: imageUrl);
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog('Lỗi khi chụp ảnh: $e');
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance
        .ref()
        .child('chat_images')
        .child('$fileName.jpg');

    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              _backgroundOptions[_selectedBackground]![0],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Lỗi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
            style: TextButton.styleFrom(
              foregroundColor: _backgroundOptions[_selectedBackground]![0],
            ),
          ),
        ],
      ),
    );
  }

  void _showBackgroundPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Chọn nền chat',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.2,
              ),
              itemCount: _backgroundOptions.length,
              itemBuilder: (context, index) {
                final entry = _backgroundOptions.entries.toList()[index];
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedBackground = entry.key);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: entry.value,
                      ),
                      border: _selectedBackground == entry.key
                          ? Border.all(color: Colors.white, width: 4)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: entry.value[0].withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _selectedBackground == entry.key
                        ? Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 30,
                          )
                        : null,
                  ),
                );
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEmojiPickerCustom() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
  }

  Widget _buildEmojiPicker() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: _showEmojiPicker ? 280 : 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chọn emoji',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showEmojiPicker = false),
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _emojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _controller.text += _emojis[index];
                      _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: _controller.text.length),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Text(
                          _emojis[index],
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe, String time) {
    print(
        "Message: ${msg['message']}, isMe: $isMe, senderId: ${msg['senderId']}, currentUserId: ${currentUser?.uid}");

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.pink[300],
              child: Text(
                'P',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe
                  ? _backgroundOptions[_selectedBackground]![0]
                  : Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: isMe ? Radius.circular(18) : Radius.circular(4),
                bottomRight: isMe ? Radius.circular(4) : Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg["type"] == "image" && msg["imageUrl"] != null)
                  Container(
                    constraints: BoxConstraints(maxWidth: 250, maxHeight: 300),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        msg["imageUrl"],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _backgroundOptions[_selectedBackground]![0],
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            child: Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (msg["message"]?.isNotEmpty == true)
                  Text(
                    msg["message"] ?? "",
                    style: TextStyle(
                      fontSize: 16,
                      color: isMe ? Colors.white : Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                SizedBox(height: 6),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isMe ? Colors.white.withOpacity(0.8) : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[300],
              child: Text(
                'M',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return _partnerIsTyping
        ? Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _backgroundOptions[_selectedBackground]![1],
                  child: Text(
                    'P',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _typingDotAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _typingDotAnimation.value,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    _backgroundOptions[_selectedBackground]![0],
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 4),
                      AnimatedBuilder(
                        animation: _typingDotAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale:
                                1.0 - (_typingDotAnimation.value - 0.5).abs(),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    _backgroundOptions[_selectedBackground]![1],
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 4),
                      AnimatedBuilder(
                        animation: _typingDotAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 - _typingDotAnimation.value + 0.5,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    _backgroundOptions[_selectedBackground]![0],
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 8),
                      Text(
                        "đang nhập...",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser?.partnerId == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _backgroundOptions[_selectedBackground]!
                .map(
                  (color) => color.withOpacity(0.1),
                )
                .toList(),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _backgroundOptions[_selectedBackground]![0]
                        .withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.asset(
                  'assets/images/alone.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 30),
            FindButton(),
            SizedBox(height: 20),
            Text(
              'Tìm một người bạn để bắt đầu trò chuyện!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final chatId = getChatId();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _backgroundOptions[_selectedBackground]!
                .map(
                  (color) => color.withOpacity(0.05),
                )
                .toList(),
          ),
        ),
        child: Column(
          children: [
            // Custom AppBar
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                bottom: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _backgroundOptions[_selectedBackground]!,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _backgroundOptions[_selectedBackground]![0]
                        .withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.chat_bubble_rounded,
                      color: _backgroundOptions[_selectedBackground]![0],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Đang kết nối...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showBackgroundPicker,
                    icon: Icon(Icons.palette, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Messages
            // Thay thế phần Expanded StreamBuilder trong build() bằng code này:

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("chats")
                    .doc(chatId)
                    .collection("messages")
                    .orderBy("time", descending: true)
                    .limit(_messagesLimit)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _backgroundOptions[_selectedBackground]![0],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Chưa có tin nhắn nào. Hãy chào nhau! 👋",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Lấy messages từ snapshot và đảo ngược để hiển thị đúng thứ tự
                  final messages = snapshot.data!.docs.reversed.toList();

                  // Tự động scroll xuống khi có tin nhắn mới
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients && messages.isNotEmpty) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return Column(
                    children: [
                      if (_isLoadingMore)
                        Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _backgroundOptions[_selectedBackground]![0],
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          itemCount:
                              messages.length + 1, // +1 cho typing indicator
                          itemBuilder: (context, index) {
                            // Hiển thị typing indicator ở cuối
                            if (index == messages.length) {
                              return _buildTypingIndicator();
                            }

                            final msg =
                                messages[index].data() as Map<String, dynamic>;
                            final isMe = msg["senderId"] == currentUser!.uid;
                            final time = msg["time"] != null
                                ? (msg["time"] as Timestamp)
                                    .toDate()
                                    .toLocal()
                                    .toString()
                                    .substring(11, 16)
                                : "";

                            return _buildMessageBubble(msg, isMe, time);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Emoji picker
            _buildEmojiPicker(),

            // Input area
            Container(
              margin: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Attachment button
                  PopupMenuButton<String>(
                    icon: Container(
                      margin: EdgeInsets.all(8),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _backgroundOptions[_selectedBackground]!,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'gallery':
                          _pickAndSendImage();
                          break;
                        case 'camera':
                          _takeAndSendPhoto();
                          break;
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'gallery',
                        child: Row(
                          children: [
                            Icon(Icons.photo_library,
                                color: _backgroundOptions[_selectedBackground]![
                                    0]),
                            SizedBox(width: 12),
                            Text('Thư viện'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'camera',
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt,
                                color: _backgroundOptions[_selectedBackground]![
                                    0]),
                            SizedBox(width: 12),
                            Text('Camera'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _showEmojiPickerCustom,
                              icon: Icon(
                                Icons.emoji_emotions_outlined,
                                color: _showEmojiPicker
                                    ? _backgroundOptions[_selectedBackground]![
                                        0]
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      style: TextStyle(fontSize: 16),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),

                  // Send button
                  AnimatedBuilder(
                    animation: _sendButtonAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _sendButtonAnimation.value,
                        child: Container(
                          margin: EdgeInsets.all(8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(25),
                              onTap: () {
                                print(
                                    "Send button tapped! Text: '${_controller.text}'");
                                if (_controller.text.trim().isNotEmpty) {
                                  _sendMessage();
                                } else {
                                  print("Text is empty, can't send");
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _backgroundOptions[
                                        _selectedBackground]!,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _backgroundOptions[
                                              _selectedBackground]![0]
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _sendButtonController.dispose();
    _messageAnimationController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }
}
