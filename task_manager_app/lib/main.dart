import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

// --- CONFIGURATION ---
// REPLACE THIS WITH YOUR RENDER BACKEND URL LATER
const String BASE_URL = 'http://localhost:3000'; 
// Note: 10.0.2.2 is special alias to access localhost from Android Emulator.
// If testing on real device, use your computer's local IP (e.g., 192.168.1.X:3000)

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// --- MODELS ---

class Task {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String? assignedTo;
  final DateTime? dueDate;
  final List<String> suggestedActions;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.category,
    required this.priority,
    required this.status,
    this.assignedTo,
    this.dueDate,
    this.suggestedActions = const [],
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      priority: json['priority'] ?? 'low',
      status: json['status'] ?? 'pending',
      assignedTo: json['assigned_to'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      suggestedActions: json['suggested_actions'] != null 
          ? List<String>.from(json['suggested_actions']) 
          : [],
    );
  }
}

// --- STATE MANAGEMENT (PROVIDER) ---

class TaskProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: BASE_URL));
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Statistics getters
  int get pendingCount => _tasks.where((t) => t.status == 'pending').length;
  int get inProgressCount => _tasks.where((t) => t.status == 'in_progress').length;
  int get completedCount => _tasks.where((t) => t.status == 'completed').length;

  Future<void> fetchTasks({String? category, String? priority}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.get('/api/tasks', queryParameters: {
        if (category != null && category != 'All') 'category': category.toLowerCase(),
        if (priority != null && priority != 'All') 'priority': priority.toLowerCase(),
      });

      final List data = response.data;
      _tasks = data.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      _error = "Failed to load tasks. Check connection.";
      print(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTask(String title, String description, String? assignedTo, DateTime? dueDate) async {
    try {
      await _dio.post('/api/tasks', data: {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'due_date': dueDate?.toIso8601String(),
      });
      await fetchTasks(); // Refresh list
      return true;
    } catch (e) {
      _error = "Failed to create task";
      notifyListeners();
      return false;
    }
  }

  Future<void> updateStatus(String id, String newStatus) async {
    try {
      await _dio.patch('/api/tasks/$id', data: {'status': newStatus});
      await fetchTasks();
    } catch (e) {
      print("Error updating status: $e");
    }
  }
}

// --- UI WIDGETS ---

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartTask',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedCategory = 'All';
  String _selectedPriority = 'All';

  @override
  void initState() {
    super.initState();
    // Fetch tasks on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
    });
  }

  void _applyFilters() {
    context.read<TaskProvider>().fetchTasks(
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      priority: _selectedPriority == 'All' ? null : _selectedPriority,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchTasks(),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Summary Cards
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                SummaryCard(title: 'Pending', count: provider.pendingCount, color: Colors.orange.shade100, textColor: Colors.orange.shade900),
                const SizedBox(width: 8),
                SummaryCard(title: 'In Progress', count: provider.inProgressCount, color: Colors.blue.shade100, textColor: Colors.blue.shade900),
                const SizedBox(width: 8),
                SummaryCard(title: 'Done', count: provider.completedCount, color: Colors.green.shade100, textColor: Colors.green.shade900),
              ],
            ),
          ),

          // 2. Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  label: Text('Category: $_selectedCategory'),
                  onSelected: (_) => _showFilterDialog('Category', ['All', 'Scheduling', 'Finance', 'Technical', 'Safety'], (val) {
                    setState(() => _selectedCategory = val);
                    _applyFilters();
                  }),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Priority: $_selectedPriority'),
                  onSelected: (_) => _showFilterDialog('Priority', ['All', 'High', 'Medium', 'Low'], (val) {
                    setState(() => _selectedPriority = val);
                    _applyFilters();
                  }),
                ),
              ],
            ),
          ),

          // 3. Task List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)))
                    : ListView.builder(
                        itemCount: provider.tasks.length,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          return TaskCard(task: provider.tasks[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const CreateTaskSheet(),
        ),
        label: const Text('New Task'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showFilterDialog(String title, List<String> options, Function(String) onSelect) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Select $title'),
        children: options.map((o) => SimpleDialogOption(
          child: Text(o),
          onPressed: () {
            onSelect(o);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final Color textColor;

  const SummaryCard({super.key, required this.title, required this.count, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            Text(title, style: TextStyle(fontSize: 12, color: textColor)),
          ],
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high': return Colors.red.shade100;
      case 'medium': return Colors.orange.shade100;
      default: return Colors.grey.shade100;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'technical': return Colors.purple.shade50;
      case 'finance': return Colors.green.shade50;
      case 'scheduling': return Colors.blue.shade50;
      default: return Colors.grey.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: _getCategoryColor(task.category),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _getPriorityColor(task.priority), borderRadius: BorderRadius.circular(8)),
                  child: Text(task.priority.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            if (task.suggestedActions.isNotEmpty)
              Wrap(
                spacing: 8,
                children: task.suggestedActions.take(2).map((a) => Chip(
                  label: Text(a, style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white,
                )).toList(),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(task.category.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                DropdownButton<String>(
                  value: task.status,
                  isDense: true,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  ],
                  onChanged: (val) {
                    if (val != null) context.read<TaskProvider>().updateStatus(task.id, val);
                  },
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({super.key});

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _assignController = TextEditingController();
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('New Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task Title', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (AI Auto-Classify)', border: OutlineInputBorder(), alignLabelWithHint: true),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _assignController,
                    decoration: const InputDecoration(labelText: 'Assign To', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _selectedDate = date);
                  },
                  icon: const Icon(Icons.calendar_today),
                ),
              ],
            ),
            if (_selectedDate != null) 
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Due: ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}", style: const TextStyle(color: Colors.blue)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : () async {
                if (_formKey.currentState!.validate()) {
                  setState(() => _isSubmitting = true);
                  final success = await context.read<TaskProvider>().createTask(
                    _titleController.text,
                    _descController.text,
                    _assignController.text,
                    _selectedDate,
                  );
                  if (success && mounted) Navigator.pop(context);
                  else setState(() => _isSubmitting = false);
                }
              },
              child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Smart Create'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}