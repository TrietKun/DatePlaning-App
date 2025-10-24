import 'package:flutter/material.dart';

class ItemSuggestion extends StatefulWidget {
  const ItemSuggestion({
    super.key,
    required this.title,
    required this.type,
  });
  final String title;
  final String type;

  @override
  State<ItemSuggestion> createState() => _ItemSuggestionState();
}

class _ItemSuggestionState extends State<ItemSuggestion> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xfff1e3f3),
        borderRadius: BorderRadius.all(Radius.circular(10)),
        shape: BoxShape.rectangle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            child: Image.asset(
              getImageUrl(widget.type),
              width: MediaQuery.of(context).size.width * 0.2,
              height: MediaQuery.of(context).size.height * 0.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: const TextStyle(
              color: Color(0xff5a189a),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

//hàm lấy url ảnh từ loại
String getImageUrl(String type) {
  switch (type) {
    case 'cafe':
      return 'assets/images/cafe.png';
    case 'restaurant':
      return 'assets/images/cutlery.png';
    case 'cinema':
      return 'assets/images/cinema.png';
    case 'park':
      return 'assets/images/park.png';
    case 'museum':
      return 'assets/images/museum.png';
    default:
      return 'assets/images/3d-map.png';
  }
}
