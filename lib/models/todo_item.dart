import 'package:cloud_firestore/cloud_firestore.dart';

class TodoItem {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  final String ownerId;
  final List<String> sharedWith;
  final Map<String, dynamic> lastModifiedBy;
  final String ownerEmail;
  final bool isOwned;

  TodoItem({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.createdAt,
    required this.ownerId,
    required this.sharedWith,
    required this.lastModifiedBy,
    required this.ownerEmail,
    this.isOwned = true,
  });

  factory TodoItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TodoItem(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      ownerId: data['ownerId'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      sharedWith: List<String>.from(data['sharedWith'] ?? []),
      lastModifiedBy: Map<String, dynamic>.from(data['lastModifiedBy'] ?? {}),
      isOwned: true, // Default to true for Firestore documents
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'sharedWith': sharedWith,
      'lastModifiedBy': lastModifiedBy,
    };
  }

  TodoItem copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    List<String>? sharedWith,
    Map<String, dynamic>? lastModifiedBy,
    bool? isOwned,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: this.createdAt,
      ownerId: this.ownerId,
      ownerEmail: this.ownerEmail,
      sharedWith: sharedWith ?? this.sharedWith,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isOwned: isOwned ?? this.isOwned,
    );
  }
}
