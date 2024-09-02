import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class RankItem {
  final String id;
  String content; // This is the name
  String? imagePath;
  String? tier;

  RankItem({
    required this.content,
    this.imagePath,
    this.tier,
    String? id,
  }) : id = id ?? const Uuid().v4();

  // Factory constructor to create a RankItem from JSON
  factory RankItem.fromJson(Map<String, dynamic> json) {
    return RankItem(
      content: json['content'],
      imagePath: json['imagePath'],
      tier: json['tier'],
      id: json['id'],
    );
  }

  // Convert a RankItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'imagePath': imagePath,
      'tier': tier,
    };
  }

  // Method to handle image importing and processing
  Future<void> importImage(String path) async {
    // TODO: Implement image importing, cropping, and downscaling
    imagePath = path;
  }

  // Widget to display the item
  Widget buildWidget(double size) {
    if (imagePath != null) {
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(imagePath!),
            fit: BoxFit.contain,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    } else {
      return Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            content,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }
}
