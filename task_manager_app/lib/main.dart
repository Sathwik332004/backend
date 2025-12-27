import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:google_fonts/google_fonts.dart';

// --- CONFIGURATION ---
// ANDROID EMULATOR uses 10.0.2.2 to access localhost.
// If running on a real device, change this to your PC's IP (e.g., http://192.168.1.X:3000)
// If deployed to Render, change this to your Render URL (e.g., https://my-app.onrender.com)
const String BASE_URL = 'http://localhost:3000'; 

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const SmartTaskApp(),
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

  // Convert to List for CSV
  List<dynamic> toCsvRow() {
    return [
      id, title, description, category, priority, status, assignedTo, dueDate?.toIso8601String()
    ];
  }
}

// --- STATE MANAGEMENT ---

class AppState with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: BASE_URL, connectTimeout: const Duration(seconds: 5)));
  
  // Data
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false; // New: Offline State
  
  // Theme State (Bonus Feature)
  ThemeMode _themeMode = ThemeMode.light;

  // Search State (Bonus Feature)
  String _searchQuery = '';

  List<Task> get tasks {
    if (_searchQuery.isEmpty) return _tasks;
    return _tasks.where((t) => 
      t.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      t.description.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;
  ThemeMode get themeMode => _themeMode;
  String get searchQuery => _searchQuery;

  // Stats
  int get pendingCount => _tasks.where((t) => t.status == 'pending').length;
  int get inProgressCount => _tasks.where((t) => t.status == 'in_progress').length;
  int get completedCount => _tasks.where((t) => t.status == 'completed').length;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void _checkOffline(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout || 
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        _isOffline = true;
      }
    }
  }

  // Updated fetchTasks to include status
  Future<void> fetchTasks({String? category, String? priority, String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.get('/api/tasks', queryParameters: {
        if (category != null && category != 'All') 'category': category.toLowerCase(),
        if (priority != null && priority != 'All') 'priority': priority.toLowerCase(),
        // Handle "In Progress" -> "in_progress" conversion
        if (status != null && status != 'All') 'status': status.toLowerCase().replaceAll(' ', '_'),
      });
      final List data = response.data;
      _tasks = data.map((json) => Task.fromJson(json)).toList();
      _isOffline = false; // Reset offline status on success
    } catch (e) {
      _checkOffline(e);
      _error = "Could not connect to server.\nMake sure Node.js is running on Port 3000.";
      print("Error fetching tasks: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // New: Pre-classify task without saving (Bonus: "Show classification before saving")
  Future<Map<String, dynamic>> classifyTaskPreview(String title, String description) async {
    try {
      final response = await _dio.post('/api/classify', data: {
        'title': title,
        'description': description,
      });
      _isOffline = false;
      return response.data;
    } catch (e) {
      _checkOffline(e);
      // Fallback if offline or endpoint not implemented yet
      print("Preview Error: $e");
      return {'category': 'general', 'priority': 'low'};
    }
  }

  Future<bool> createTask(Map<String, dynamic> taskData) async {
    try {
      await _dio.post('/api/tasks', data: taskData);
      await fetchTasks();
      _isOffline = false;
      return true;
    } catch (e) {
      _checkOffline(e);
      _error = "Failed to create task";
      notifyListeners();
      return false;
    }
  }

  Future<void> updateStatus(String id, String newStatus) async {
    try {
      await _dio.patch('/api/tasks/$id', data: {'status': newStatus});
      await fetchTasks();
      _isOffline = false;
    } catch (e) {
      _checkOffline(e);
      print("Error updating status: $e");
    }
  }

  // Delete Task Implementation
  Future<void> deleteTask(String id) async {
    try {
      await _dio.delete('/api/tasks/$id');
      await fetchTasks();
      _isOffline = false;
    } catch (e) {
      _checkOffline(e);
      print("Error deleting task: $e");
    }
  }

  // Bonus: CSV Export
  Future<void> exportToCsv() async {
    List<List<dynamic>> rows = [
      ["ID", "Title", "Description", "Category", "Priority", "Status", "Assigned To", "Due Date"]
    ];
    for (var t in _tasks) {
      rows.add(t.toCsvRow());
    }
    String csvData = const ListToCsvConverter().convert(rows);
    // On Android/iOS this opens the system share sheet
    await Share.share(csvData, subject: 'Task Export.csv');
  }
}

// --- UI COMPONENTS ---

class SmartTaskApp extends StatelessWidget {
  const SmartTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select((AppState s) => s.themeMode);
    
    return MaterialApp(
      title: 'SmartTask',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      // Dark Theme (Bonus Feature)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
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
  String _filterCat = 'All';
  String _filterPrio = 'All';
  String _filterStatus = 'All'; // New Status Filter State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchTasks();
    });
  }

  void _runFilter() {
    context.read<AppState>().fetchTasks(
      category: _filterCat,
      priority: _filterPrio,
      status: _filterStatus, // Pass status to fetchTasks
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search tasks...', border: InputBorder.none),
              onChanged: (val) => context.read<AppState>().setSearchQuery(val),
            )
          : const Text("SmartTask Manager", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  context.read<AppState>().setSearchQuery('');
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'csv') state.exportToCsv();
              if (val == 'theme') state.toggleTheme();
            },
            itemBuilder: (ctx) => [
               const PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.download), SizedBox(width: 8), Text('Export CSV')])),
               PopupMenuItem(value: 'theme', child: Row(children: [Icon(state.themeMode == ThemeMode.light ? Icons.dark_mode : Icons.light_mode), const SizedBox(width: 8), Text(state.themeMode == ThemeMode.light ? 'Dark Mode' : 'Light Mode')])),
            ],
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await state.fetchTasks(category: _filterCat, priority: _filterPrio, status: _filterStatus),
        child: Column(
          children: [
             // Offline Indicator
            if (state.isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.redAccent,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text("Offline Mode: Server unreachable", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
            // Summary Cards
            if (!_isSearching)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  SummaryCard(label: 'Pending', count: state.pendingCount, color: Colors.orange.shade200, icon: Icons.timer),
                  const SizedBox(width: 10),
                  SummaryCard(label: 'Active', count: state.inProgressCount, color: Colors.blue.shade200, icon: Icons.run_circle),
                  const SizedBox(width: 10),
                  SummaryCard(label: 'Done', count: state.completedCount, color: Colors.green.shade200, icon: Icons.check_circle),
                ],
              ),
            ),
            
            // Quick Filters
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                   FilterChip(label: Text("Cat: $_filterCat"), onSelected: (_) => _showFilterDialog("Category", ["All", "Scheduling", "Finance", "Technical", "Safety"], (v) { setState(() => _filterCat = v); _runFilter(); })),
                   const SizedBox(width: 8),
                   FilterChip(label: Text("Prio: $_filterPrio"), onSelected: (_) => _showFilterDialog("Priority", ["All", "High", "Medium", "Low"], (v) { setState(() => _filterPrio = v); _runFilter(); })),
                   const SizedBox(width: 8),
                   // NEW: Status Filter Chip
                   FilterChip(label: Text("Status: $_filterStatus"), onSelected: (_) => _showFilterDialog("Status", ["All", "Pending", "In Progress", "Completed"], (v) { setState(() => _filterStatus = v); _runFilter(); })),
                ],
              ),
            ),

            // Task List
            Expanded(
              child: state.isLoading 
                ? const Center(child: CircularProgressIndicator())
                : state.tasks.isEmpty 
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.task_alt, size: 64, color: Colors.grey), Text("No tasks found")]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.tasks.length,
                      itemBuilder: (ctx, i) => TaskTile(task: state.tasks[i], searchQuery: state.searchQuery),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context, 
          isScrollControlled: true, 
          useSafeArea: true,
          builder: (_) => const CreateTaskWizard()
        ),
        label: const Text("New Task"),
        icon: const Icon(Icons.add_task),
      ),
    );
  }

  void _showFilterDialog(String title, List<String> opts, Function(String) onSel) {
    showDialog(context: context, builder: (_) => SimpleDialog(
      title: Text("Select $title"),
      children: opts.map((o) => SimpleDialogOption(child: Text(o), onPressed: () { onSel(o); Navigator.pop(context); })).toList(),
    ));
  }
}

// --- WIDGETS ---

class SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const SummaryCard({super.key, required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.2) : color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isDark ? Colors.white : Colors.black87),
            const SizedBox(height: 8),
            Text(count.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  final Task task;
  final String searchQuery;
  const TaskTile({super.key, required this.task, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    // Wrapped in Dismissible for delete functionality
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm Delete"),
              content: const Text("Are you sure you want to delete this task?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        context.read<AppState>().deleteTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task deleted")),
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: HighlightText(text: task.title, highlight: searchQuery, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  _buildPriorityBadge(task.priority),
                ],
              ),
              const SizedBox(height: 8),
              HighlightText(text: task.description, highlight: searchQuery, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(label: Text(task.category.toUpperCase(), style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                  const Spacer(),
                  if (task.dueDate != null) 
                    Text("Due: ${DateFormat('MM/dd').format(task.dueDate!)}", style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (task.assignedTo != null) 
                    Row(children: [const Icon(Icons.person, size: 16), const SizedBox(width: 4), Text(task.assignedTo!, style: const TextStyle(fontSize: 12))]),
                  DropdownButton<String>(
                    value: task.status,
                    underline: const SizedBox(),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyLarge?.color),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    ],
                    onChanged: (v) => context.read<AppState>().updateStatus(task.id, v!),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'high': color = Colors.red; break;
      case 'medium': color = Colors.orange; break;
      default: color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)),
      child: Text(priority.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// Bonus: Highlighting Search Text
class HighlightText extends StatelessWidget {
  final String text;
  final String highlight;
  final TextStyle style;

  const HighlightText({super.key, required this.text, required this.highlight, required this.style});

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty) return Text(text, style: style);

    final lowerText = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    final idx = lowerText.indexOf(lowerHighlight);

    if (idx < 0) return Text(text, style: style);

    return RichText(
      text: TextSpan(
        style: style.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + highlight.length),
            style: style.copyWith(backgroundColor: Colors.yellow, color: Colors.black),
          ),
          TextSpan(text: text.substring(idx + highlight.length)),
        ],
      ),
    );
  }
}

// --- CREATE TASK WIZARD (Analyze -> Edit -> Save) ---

class CreateTaskWizard extends StatefulWidget {
  const CreateTaskWizard({super.key});
  @override
  State<CreateTaskWizard> createState() => _CreateTaskWizardState();
}

class _CreateTaskWizardState extends State<CreateTaskWizard> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _assignCtrl = TextEditingController();
  DateTime? _dueDate;
  
  // Step 2 Data
  bool _isAnalyzing = false;
  bool _showPreview = false;
  String _predictedCategory = 'general';
  String _predictedPriority = 'low';

  void _analyzeAndPreview() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isAnalyzing = true);

    // Call Backend "Preview" Endpoint
    final result = await context.read<AppState>().classifyTaskPreview(_titleCtrl.text, _descCtrl.text);

    setState(() {
      _isAnalyzing = false;
      _showPreview = true;
      _predictedCategory = result['category'] ?? 'general';
      _predictedPriority = result['priority'] ?? 'low';
      
      // Auto-fill extracted entities if any
      if (result['extracted_entities']?['person'] != null && _assignCtrl.text.isEmpty) {
        _assignCtrl.text = result['extracted_entities']['person'];
      }
    });
  }

  void _submitFinal() async {
    final success = await context.read<AppState>().createTask({
      'title': _titleCtrl.text,
      'description': _descCtrl.text,
      'assigned_to': _assignCtrl.text,
      'due_date': _dueDate?.toIso8601String(),
      'category': _predictedCategory, // User might have overridden this
      'priority': _predictedPriority, // User might have overridden this
    });
    if (success && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 16, left: 16, right: 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_showPreview ? "Confirm Details" : "New Task", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              
              if (!_showPreview) ...[
                // --- STEP 1: INPUT ---
                TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Required" : null),
                const SizedBox(height: 12),
                TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()), maxLines: 3),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzeAndPreview, 
                  icon: _isAnalyzing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome),
                  label: const Text("Analyze & Next"),
                ),
              ] else ...[
                // --- STEP 2: PREVIEW & EDIT ---
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue)),
                  child: const Row(children: [Icon(Icons.info_outline, color: Colors.blue), SizedBox(width: 8), Expanded(child: Text("AI analyzed your task. You can override these values before saving."))]),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _predictedCategory,
                  decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                  items: ['scheduling', 'finance', 'technical', 'safety', 'general'].map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _predictedCategory = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _predictedPriority,
                  decoration: const InputDecoration(labelText: "Priority", border: OutlineInputBorder()),
                  items: ['high', 'medium', 'low'].map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => _predictedPriority = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _assignCtrl, decoration: const InputDecoration(labelText: "Assign To", border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                        if (d != null) setState(() => _dueDate = d);
                      },
                    ),
                  ],
                ),
                if (_dueDate != null) Text("Due: ${DateFormat.yMMMd().format(_dueDate!)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(onPressed: () => setState(() => _showPreview = false), child: const Text("Back")),
                    const Spacer(),
                    FilledButton(onPressed: _submitFinal, child: const Text("Save Task")),
                  ],
                )
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}