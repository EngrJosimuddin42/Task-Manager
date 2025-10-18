import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:async';


class DBHelper {
  static Database? _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔹 Database getter
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  // 🔹 Initialize local DB
  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'task_manager.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            date TEXT NOT NULL,
            isCompleted INTEGER NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            userId TEXT NOT NULL)''');},
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN synced INTEGER NOT NULL DEFAULT 0');
          await db.execute(
              'ALTER TABLE tasks ADD COLUMN userId TEXT NOT NULL DEFAULT ""');
        }
      },
    );
  }

  // 🔹 Check internet

  Future<bool> isOnline() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) return false;


      // 🔹 Instead of .timeout(), use Future.any (works everywhere)
      final lookup = await Future.any([
        InternetAddress.lookup('example.com'),
        Future.delayed(const Duration(seconds: 3), () => <InternetAddress>[]),
      ]);

      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (e) {
      print('⚠️ Internet check failed: $e');
      return false;
    }
  }

  // 🔹 Insert new task
  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap()..['synced'] = 0,
      conflictAlgorithm: ConflictAlgorithm.replace);

    if (await isOnline()) {
      try {
        await _firestore
            .collection('tasks')
            .doc(task.userId)
            .collection('userTasks')
            .doc(task.id)
            .set(task.toMap());
        await db.update('tasks', {'synced': 1}, where: 'id = ?',whereArgs: [task.id],);
      } catch (e) {
        print('⚠️ Firestore insert/update failed or timed out: $e');
      }
    }
  }

  // 🔹 Update task
  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap()..['synced'] = 0,
      where: 'id = ?',
      whereArgs: [task.id],
    );

    if (await isOnline()) {
      try {
        await _firestore
            .collection('tasks')
            .doc(task.userId)
            .collection('userTasks')
            .doc(task.id)
            .set(task.toMap());
        await db.update(
          'tasks',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [task.id],
        );
      } catch (e) {
        print('⚠️ Firestore update failed: $e');
      }
    }
  }

  // 🔹 Delete task
  Future<void> deleteTask(String id, String userId) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);

    if (await isOnline()) {
      try {
        await _firestore
            .collection('tasks')
            .doc(userId)
            .collection('userTasks')
            .doc(id)
            .delete();
      } catch (e) {
        print('⚠️ Firestore delete failed: $e');
      }
    }
  }

  // 🔹 Get all tasks for current user
  Future<List<Task>> getTasks(String userId) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  // 🔹 Sync Firestore → Local
  Future<void> syncFromFirestore(String userId) async {
    if (await isOnline()) {
      final db = await database;
      final snapshot = await _firestore
          .collection('tasks')
          .doc(userId)
          .collection('userTasks')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        await db.insert(
          'tasks',
          {
            'id': data['id'],
            'title': data['title'],
            'description': data['description'],
            'date': data['date'],
            'isCompleted': data['isCompleted'] ? 1 : 0,
            'synced': 1,
            'userId': data['userId'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      print('✅ Firestore → Local sync done for $userId');
    }
  }

  // 🔹 Sync Local → Firestore
  Future<void> syncToFirestore(String userId) async {
    if (await isOnline()) {
      final db = await database;
      final unsyncedTasks = await db.query(
        'tasks',
        where: 'synced = ? AND userId = ?',
        whereArgs: [0, userId],
      );

      for (var task in unsyncedTasks) {
        try {
          await _firestore
              .collection('tasks')
              .doc(userId)
              .collection('userTasks')
              .doc(task['id'] as String)
              .set({
            'id': task['id'],
            'title': task['title'],
            'description': task['description'],
            'date': task['date'],
            'isCompleted': task['isCompleted'] == 1,
            'userId': task['userId'],
          });

          await db.update(
            'tasks',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [task['id']],
          );
        } catch (e) {
          print('⚠️ Sync failed for ${task['id']}: $e');
        }
      }
      print('✅ Local → Firestore sync completed for $userId');
    }
  }

  // 🔹 Delete all tasks (for specific user only)
  Future<int> deleteAllTasks(String? userId) async {
    final db = await database;

    if (userId != null && userId.isNotEmpty) {

      // 🔸 Clear all tasks from a specific user account
      return await db.delete(
        'tasks',
        where: 'userId = ?',
        whereArgs: [userId],
      );
    } else {

      // ❌ Nothing will be deleted while logged out
      print("⚠️ No userId provided, skipping deleteAllTasks.");
      return 0;
    }
  }
}
