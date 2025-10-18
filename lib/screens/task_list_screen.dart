import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../db/db_helper.dart';
import '../models/task_model.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> tasks = [];
  String filter = "All";

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final allTasks = await DBHelper().getTasks(user.uid); // ✅ add userId
    setState(() {
      if (filter == "Pending") {tasks =allTasks.where((t) => !t.isCompleted && !isOutdated(t)).toList();}
      else if (filter == "Completed") {tasks = allTasks.where((t) => t.isCompleted).toList();}
      else if (filter == "Outdated") {tasks = allTasks.where((t) => !t.isCompleted && isOutdated(t)).toList();}
      else {tasks = allTasks;}
    });
  }

  bool isOutdated(Task t) {
    if (t.date.isEmpty) return false;
    try {
      final now = DateTime.now();
      final taskDate = DateFormat('yyyy-MM-dd').parse(t.date);
      return taskDate.isBefore(DateTime(now.year, now.month, now.day));
    } catch (e) {
      return false;
    }
  }

  Color getTaskColor(Task t) {
    if (t.isCompleted) return Colors.green;
    if (isOutdated(t)) return Colors.redAccent;

    final now = DateTime.now();
    final taskDate = DateFormat('yyyy-MM-dd').parse(t.date);
    if (taskDate.year == now.year &&
        taskDate.month == now.month &&
        taskDate.day == now.day) {
      return Colors.blue;
    }

    return Colors.black87;
  }

  Future<void> generatePdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                '📋 Task List',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            ...tasks.map((t) {PdfColor color;
              if (t.isCompleted) {color = PdfColors.green;}
              else if (isOutdated(t)) {color = PdfColors.red;}
              else {
                final now = DateTime.now();
                final taskDate = DateFormat('yyyy-MM-dd').parse(t.date);
                if (taskDate.year == now.year &&
                    taskDate.month == now.month &&
                    taskDate.day == now.day) {
                  color = PdfColors.blue;
                } else {
                  color = PdfColors.black;
                }
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    t.title,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (t.description.isNotEmpty)
                    pw.Text(t.description,
                        style: pw.TextStyle(fontSize: 14, color: color)),
                  pw.Text(
                    'Due Date: ${DateFormat('yyyy-MM-dd').format(DateFormat('yyyy-MM-dd').parse(t.date))}',
                    style: pw.TextStyle(fontSize: 14, color: color),
                  ),
                  pw.Divider(),
                ],
              );
            }).toList(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        centerTitle: true,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Task List',style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold,color: Colors.white)),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: filter,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(value: "All", child: Text("All")),
                DropdownMenuItem(value: "Pending", child: Text("Pending")),
                DropdownMenuItem(value: "Completed", child: Text("Completed")),
                DropdownMenuItem(value: "Outdated", child: Text("Outdated")),
              ],
              onChanged: (value) {
                setState(() => filter = value!);
                loadTasks();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: generatePdf),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadTasks,
        child: tasks.isEmpty
            ? const Center(
          child: Text('No tasks found 😶',style: TextStyle(fontSize: 16, color: Colors.grey)))
            : ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final color = getTaskColor(task);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(task.title,textAlign: TextAlign.center,style: TextStyle(fontSize: 18,fontWeight: FontWeight.w600,color: color,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(task.description,textAlign: TextAlign.center,style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Due Date: ${DateFormat('yyyy-MM-dd').format(DateFormat('yyyy-MM-dd').parse(task.date))}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13,fontWeight: FontWeight.w600,color: color)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
