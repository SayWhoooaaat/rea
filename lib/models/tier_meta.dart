import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TierMeta {
  int id; // 1‑based, recalculated when we save
  String label;
  Color color;

  TierMeta({required this.id, required this.label, required this.color});

  // ---- (de)serialisation ----------------------------------------------
  factory TierMeta.fromJson(Map<String, dynamic> j) => TierMeta(
        id: (j['id'] ?? 0) as int, // older data = 0
        label: j['label'] as String,
        color: _hexToColor(j['color'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'color':
            '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      };

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
