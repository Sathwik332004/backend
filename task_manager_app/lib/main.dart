import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Basics App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const DashboardScreen(),
    );
  }
}

/// ---------------------------
/// DASHBOARD SCREEN
/// ---------------------------
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          TaskCard(
            title: 'Fix Login Bug',
            description: 'Resolve authentication issue on Android',
            priority: 'High',
          ),
          TaskCard(
            title: 'Prepare Report',
            description: 'Monthly finance summary',
            priority: 'Medium',
          ),
          TaskCard(
            title: 'Team Meeting',
            description: 'Discuss Q4 roadmap',
            priority: 'Low',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ---------------------------
/// TASK CARD WIDGET
/// ---------------------------
class TaskCard extends StatelessWidget {
  final String title;
  final String description;
  final String priority;

  const TaskCard({
    super.key,
    required this.title,
    required this.description,
    required this.priority,
  });

  Color _priorityColor() {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade100;
      case 'medium':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: _priorityColor(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                label: Text(priority.toUpperCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
