import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';
import '../db/db_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper();
  final _uuid = const Uuid();

  List<Task> _tasks = [];
  bool _isOnline = false;

  // ⚡ Updated type (List<ConnectivityResult>)
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  List<Task> get tasks => _tasks;

  bool get isOnline => _isOnline;

  TaskProvider() {
    _init();
  }

  // 🔹 Initialize provider
  Future<void> _init() async {
    await _checkConnectivity();
    await loadTasks();
    _listenConnectivity();

    // ✅ Listen for login/logout changes
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {

        // user logged in → reload that user's tasks
        await loadTasks();
      } else {

        // user logged out → clear all tasks
        clearTasks();
      }
    });
  }

  // 🔹 Check internet connectivity
  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;
    if (kDebugMode) {
      print('🌐 Initial Connectivity: ${_isOnline ? 'Online' : 'Offline'}');
    }
    notifyListeners();
  }

  // 🔹 Listen to connectivity changes
  void _listenConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((
            List<ConnectivityResult> results) {
          final result = results.isNotEmpty ? results.first : ConnectivityResult
              .none;
          final nowOnline = result != ConnectivityResult.none;

          if (_isOnline != nowOnline) {
            _isOnline = nowOnline;
            notifyListeners();
            Future.delayed(const Duration(milliseconds: 800), () async {
              if (_isOnline) await _syncOnConnectivityChange();
            });
          }
        });
  }

  // 🔹 Sync tasks on connectivity change
  Future<void> _syncOnConnectivityChange() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_isOnline) {
      await _dbHelper.syncToFirestore(user.uid);
      await _dbHelper.syncFromFirestore(user.uid);
      await loadTasks();
      if (kDebugMode) print('🔁 Synced tasks on connectivity change');
    }
  }

  // 🔹 Load tasks for current user
  Future<void> loadTasks() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Local DB fetch
      final localTasks = await _dbHelper.getTasks(user.uid);

      // 🔸 If the local DB is empty and the internet is available, it will fetch data from Firestore.
      if (localTasks.isEmpty) {
        if (await _dbHelper.isOnline()) {
          await _dbHelper.syncFromFirestore(user.uid);
          print('📥 Restored tasks from Firestore after reinstall');
        }
      }

      // 🔹from Local DB Provider list update
      _tasks = await _dbHelper.getTasks(user.uid);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Load tasks error: $e');
    }
  }


  // 🔹 Add new task
  Future<void> addTask(String title, String description, String date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newTask = Task(
      id: _uuid.v4(),
      title: title,
      description: description,
      date: date,
      isCompleted: false,
      userId: user.uid,
    );

    await _dbHelper.insertTask(newTask);
    _tasks.add(newTask);
    notifyListeners();

    if (_isOnline) {
      await _dbHelper.syncToFirestore(user.uid);
    }
  }

  // 🔹 Update existing task
  Future<void> updateTask(String id, String title, String description,
      String date) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final updatedTask = Task(
      id: id,
      title: title,
      description: description,
      date: date,
      isCompleted: _tasks[index].isCompleted,
      userId: _tasks[index].userId,
    );

    await _dbHelper.updateTask(updatedTask);
    _tasks[index] = updatedTask;
    notifyListeners();

    if (_isOnline) {
      await _dbHelper.syncToFirestore(updatedTask.userId);
    }
  }

  // 🔹 Toggle complete / incomplete
  Future<void> toggleComplete(Task task) async {
    final updated = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      date: task.date,
      isCompleted: !task.isCompleted,
      userId: task.userId,
    );

    await _dbHelper.updateTask(updated);
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) _tasks[index] = updated;
    notifyListeners();

    if (_isOnline) {
      await _dbHelper.syncToFirestore(updated.userId);
    }
  }

  // 🔹 Delete a single task
  Future<void> deleteTask(String id) async {
    final task = _tasks.firstWhere(
          (t) => t.id == id,
      orElse: () =>
          Task(
            id: '',
            title: '',
            description: '',
            date: '',
            isCompleted: false,
            userId: '',
          ),
    );

    if (task.id.isEmpty) return;

    await _dbHelper.deleteTask(task.id, task.userId);
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();

    if (_isOnline) {
      await _dbHelper.syncToFirestore(task.userId);
    }
  }

  // 🔹 Delete all tasks (Firestore + Local DB)
  Future<void> clearTasks() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // 🔸 Firestore (user subcollection) থেকে সব task ডিলিট
        final userTasksRef = FirebaseFirestore.instance
            .collection('tasks')
            .doc(user.uid)
            .collection('userTasks');

        final snapshot = await userTasksRef.get();

        // batch delete (for large sets)
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        if (snapshot.docs.isNotEmpty) {
          await batch.commit();
        }

        // 🔸from Local DB current user task delete
        await _dbHelper.deleteAllTasks(user.uid);
      }

      // 🔸 Provider list clear
      _tasks.clear();
      notifyListeners();

      if (kDebugMode) print("✅ All tasks cleared from Firestore & Local DB for current user");
    } catch (e) {
      if (kDebugMode) print("❌ Error clearing tasks: $e");
    }
  }

  // 🔹 only local provider list clear (for logout)
  void clearLocalOnly() {
    _tasks.clear();
    notifyListeners();
  }
}
