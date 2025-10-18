class Task {
  final String id;
  final String title;
  final String description;
  final String date; // yyyy-MM-dd format
  final bool isCompleted;
  final String userId; // Logged-in user's UID

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.isCompleted = false,
    required this.userId,
  });

  // copyWith() → For updating specific fields
  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? date,
    bool? isCompleted,
    String? userId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
    );
  }

  // Convert Task → Map (for Firestore & SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'isCompleted': isCompleted, // ✅ keep boolean (true/false)
      'userId': userId,
    };
  }

  // Convert Map → Task (for Firestore & SQLite)
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] ?? '',

      // ✅ handle both int(1/0) or bool(true/false)
      isCompleted: map['isCompleted'] == true || map['isCompleted'] == 1,
      userId: map['userId'] ?? '',
    );
  }
}
