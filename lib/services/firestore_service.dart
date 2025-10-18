import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'tasks';

  // Add task
  Future<void> addTask(Task task) async {
    await _firestore.collection(_collection).doc(task.id).set(task.toMap());
  }

  // Update task
  Future<void> updateTask(Task task) async {
    await _firestore.collection(_collection).doc(task.id).update(task.toMap());
  }

  // Delete task
  Future<void> deleteTask(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // Get all tasks
  Future<List<Task>> getTasks() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) => Task.fromMap(doc.data())).toList();
  }
}
