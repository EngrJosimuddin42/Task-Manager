import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import 'add_task_screen.dart';
import 'task_list_screen.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../services/custom_snackbar.dart';
import '../services/alert_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchQuery = "";
  Map<String, dynamic>? profileData;
  bool isProfileLoading = true;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // 🔹 first check mounted
      if (!mounted) return;

      setState(() {
        profileData = doc.data();
        isProfileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(context, "❌ Failed to load profile. Please try again later.",
        backgroundColor: Colors.red);
    }
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

// Determine Task Color Based on Status

  Color getTaskColor(Task task) {
    if (task.isCompleted) return Colors.green;
    final now = DateTime.now();
    final taskDate = DateFormat('yyyy-MM-dd').parse(task.date);
    if (taskDate.isBefore(DateTime(now.year, now.month, now.day))) {
      return Colors.redAccent;
    } else if (taskDate.year == now.year &&
        taskDate.month == now.month &&
        taskDate.day == now.day) {
      return Colors.blue;
    } else {
      return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    List<Task> tasks = provider.tasks;

    if (searchQuery.isNotEmpty) {
      tasks = tasks
          .where((t) => t.title.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: const Text('📋 Task Manager'),centerTitle: true,elevation: 4,
            leadingWidth: 100,
            leading: isProfileLoading
                ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Padding(padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null && profileData != null) {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()));
                      } else {

                        // ❌ user null or document deleted → logout
                        FirebaseAuth.instance.signOut();
                        if (mounted) {
                          Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()));
                        }
                      }
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.deepPurple,
                        child: Text( profileData != null
                              ? profileData!['name'][0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 16,fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Icon(
                      provider.isOnline ? Icons.wifi : Icons.wifi_off,
                      color:
                      provider.isOnline ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(provider.isOnline ? "Online" : "Offline",style: const TextStyle(fontSize: 14,fontWeight: FontWeight.w600,color: Colors.white)),
                  ],
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search tasks...',
                          prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.tune, color: Colors.white),
                      onPressed: () {
                        Navigator.push(context,
                          MaterialPageRoute(builder: (context) => const TaskListScreen()));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: tasks.isEmpty
              ? const Center(
            child: Text("কোনো টাস্ক নেই 😴\nনতুন টাস্ক যোগ করুন!",textAlign: TextAlign.center,style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final Task task = tasks[index];
              final dueColor = getTaskColor(task);

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Checkbox(activeColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                          value: task.isCompleted,
                          onChanged: isProcessing
                              ? null
                              : (val) async {
                            setState(() => isProcessing = true);
                            await provider.toggleComplete(task);
                            setState(() => isProcessing = false);
                          },
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task.title, style: TextStyle(fontSize: 18,fontWeight: FontWeight.w600,decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: task.isCompleted
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                            if (task.description.isNotEmpty)
                              Padding(padding: const EdgeInsets.only(top: 2),
                                child: Text(task.description,style: const TextStyle(fontSize: 14, color: Colors.black54))),
                            Padding(padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded,size: 16, color: dueColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text('Due Date: ${task.date}',style: TextStyle(fontSize: 13,fontWeight: FontWeight.w600, color: dueColor)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.edit,color: Colors.blueAccent),
                            onPressed: isProcessing
                                ? null
                                : () async {
                              setState(() => isProcessing = true);
                              final result = await Navigator.push(context,
                                MaterialPageRoute(builder: (_) => AddTaskScreen(task: task)));
                              if (result == true) {
                                await provider.loadTasks();
                              }
                              setState(() => isProcessing = false);
                            },
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline,color: Colors.redAccent),
                            onPressed: isProcessing
                                ? null
                                : () async {

                              // ✅ Reusable AlertDialogUtils
                              final confirm = await AlertDialogUtils.showConfirm(
                                context: context,
                                title: "Confirm Delete",
                                content: const Text("Are you sure you want to delete this task?"),
                                confirmText: "Delete",
                                cancelText: "Cancel",
                                confirmColor: Colors.redAccent);

                              if (confirm == true) {
                                setState(() =>isProcessing = true);
                                await provider.deleteTask(task.id);
                                setState(() =>isProcessing = false);
                                CustomSnackbar.show(context,"✅ Task deleted successfully!",
                                    backgroundColor:Colors.green);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: isProcessing
                ? null
                : () async {
              setState(() => isProcessing = true);
              final result = await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddTaskScreen()));
              if (result == true) { await provider.loadTasks();}
              setState(() => isProcessing = false);
            },
            backgroundColor: Colors.deepPurple,
            elevation: 6,
            child: const Icon(Icons.add, size: 30, color: Colors.white),
          ),
        ),
        if (isProcessing)
          Container(color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
