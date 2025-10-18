import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import 'package:intl/intl.dart';
import '../services/custom_snackbar.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;
  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  String? selectedDate;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      titleController.text = widget.task!.title;
      descriptionController.text = widget.task!.description;
      selectedDate = widget.task!.date;
    }
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate != null
          ? DateFormat('yyyy-MM-dd').parse(selectedDate!)
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> saveTask() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      CustomSnackbar.show(context,"⚠️ Please enter a task title",
          backgroundColor:Colors.red);
      return;
    }

    if (selectedDate == null) {
      CustomSnackbar.show(context,"⚠️ Please select a due date",
          backgroundColor:Colors.red);
      return;
    }

    final taskProvider = context.read<TaskProvider>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      CustomSnackbar.show(context,"❌ User not logged in",
          backgroundColor:Colors.red);
      return;
    }

    // 🔍 Duplicate check
    final isDuplicate = taskProvider.tasks.any((task) =>
    task.title.toLowerCase() == title.toLowerCase() &&
        task.date == selectedDate &&
        task.id != widget.task?.id);

    if (isDuplicate) {
      CustomSnackbar.show(context,"⚠️ Task with this title and date already exists!",
          backgroundColor:Colors.red);
      return;
    }

    setState(() => isSaving = true);

    try {
      bool isOnline = taskProvider.isOnline;

      if (widget.task == null) {

        // ➕ Add new task
        await taskProvider.addTask(title, description, selectedDate!);
        CustomSnackbar.show(context, isOnline ? "✅ Task added successfully!" : "📴 Offline: Task saved locally!",
         backgroundColor:  isOnline ? Colors.green : Colors.green);
      } else {

        // ✏️ Update existing task
        await taskProvider.updateTask(widget.task!.id, title, description, selectedDate!);
        CustomSnackbar.show(context, isOnline? "✅ Task updated successfully!" : "📴 Offline: Task updated locally!",
         backgroundColor:isOnline ? Colors.green : Colors.green,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      CustomSnackbar.show(context,"❌ Error saving task: $e",
          backgroundColor:Colors.red);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  InputDecoration buildInputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.deepPurple),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
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
        title: Text(widget.task == null ? '➕ Add New Task' : '✏️ Edit Task',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 4,
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(taskProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: taskProvider.isOnline ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 4),
                Text(
                  taskProvider.isOnline ? "Online" : "Offline",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: buildInputDecoration(
                    label: 'Task Title',
                    hint: 'Enter your task title',
                    icon: Icons.note_alt,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: buildInputDecoration(
                    label: 'Description',
                    hint: 'Enter task details...',
                    icon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: 18),
                InkWell(
                  onTap: () => _pickDueDate(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1.3)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.deepPurple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(selectedDate ?? 'Select Due Date',style: TextStyle(fontSize: 16,color: selectedDate == null ? Colors.grey[600] : Colors.black87,fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 26, color: Colors.white),
                    label: Text(widget.task == null ? 'Save Task' : 'Update Task',style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A11CB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: isSaving ? null : saveTask,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (isSaving)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
