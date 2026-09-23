import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.isRead = false,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? date,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'date': date.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      date: DateTime.parse(json['date'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

class NotificationController extends ChangeNotifier {
  static const _storageKey = 'optcare_notifications';
  List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((item) => !item.isRead).length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final parsed = jsonDecode(raw) as List<dynamic>;
      _notifications = parsed
          .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    notifyListeners();
  }

  Future<void> addNotification(NotificationItem item) async {
    _notifications.insert(0, item);
    await _save();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    _notifications = _notifications.map((item) {
      if (item.id == id) {
        return item.copyWith(isRead: true);
      }
      return item;
    }).toList();
    await _save();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((item) => item.copyWith(isRead: true)).toList();
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _notifications = [];
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_notifications.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}

final notificationsController = NotificationController();
