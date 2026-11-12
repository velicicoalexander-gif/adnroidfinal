import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LucrurileMeleApp());
}

class TaskItem {
  String id;
  String title;
  String note;
  DateTime date;
  bool hasTime;
  String? startTime;
  String? endTime;
  String recurrence;
  bool endRecurrence;
  DateTime? recurrenceEndDate;
  bool autoTransfer;
  bool isCompleted;

  TaskItem({
    required this.id,
    required this.title,
    this.note = '',
    required this.date,
    this.hasTime = false,
    this.startTime,
    this.endTime,
    this.recurrence = 'none',
    this.endRecurrence = false,
    this.recurrenceEndDate,
    this.autoTransfer = true,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'date': DateUtils.dateOnly(date).toIso8601String(),
        'hasTime': hasTime,
        'startTime': startTime,
        'endTime': endTime,
        'recurrence': recurrence,
        'endRecurrence': endRecurrence,
        'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
        'autoTransfer': autoTransfer,
        'isCompleted': isCompleted,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'],
        title: json['title'],
        note: json['note'] ?? '',
        date: DateUtils.dateOnly(DateTime.parse(json['date'])),
        hasTime: json['hasTime'] ?? false,
        startTime: json['startTime'],
        endTime: json['endTime'],
        recurrence: json['recurrence'] ?? 'none',
        endRecurrence: json['endRecurrence'] ?? false,
        recurrenceEndDate: json['recurrenceEndDate'] != null
            ? DateTime.parse(json['recurrenceEndDate'])
            : null,
        autoTransfer: json['autoTransfer'] ?? true,
        isCompleted: json['isCompleted'] ?? false,
      );

  TaskItem copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? date,
    bool? hasTime,
    String? startTime,
    String? endTime,
    String? recurrence,
    bool? endRecurrence,
    DateTime? recurrenceEndDate,
    bool? autoTransfer,
    bool? isCompleted,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      date: date ?? this.date,
      hasTime: hasTime ?? this.hasTime,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      recurrence: recurrence ?? this.recurrence,
      endRecurrence: endRecurrence ?? this.endRecurrence,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      autoTransfer: autoTransfer ?? this.autoTransfer,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class LucrurileMeleApp extends StatefulWidget {
  const LucrurileMeleApp({super.key});

  @override
  State<LucrurileMeleApp> createState() => _LucrurileMeleAppState();
}

class _LucrurileMeleAppState extends State<LucrurileMeleApp> {
  bool darkMode = false;
  Color primaryTeal = const Color(0xFF009688);
  bool fadeOnComplete = true;
  bool showScaleAndFraction = true;
  bool globalAutoRollover = true;
  List<TaskItem> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool('darkMode') ?? false;
      fadeOnComplete = prefs.getBool('fadeOnComplete') ?? true;
      showScaleAndFraction = prefs.getBool('showScaleAndFraction') ?? true;
      globalAutoRollover = prefs.getBool('globalAutoRollover') ?? true;
    });

    final rawTasks = prefs.getString('tasks_db');
    if (rawTasks != null) {
      final List decoded = jsonDecode(rawTasks);
      tasks = decoded.map((e) => TaskItem.fromJson(e)).toList();
    } else {
      final today = DateUtils.dateOnly(DateTime.now());
      tasks = [
        TaskItem(id: 't1', title: 'Obicei', date: today, hasTime: true, startTime: '17:47', recurrence: 'daily'),
        TaskItem(id: 't2', title: 'Nuci', date: today, recurrence: 'daily'),
        TaskItem(id: 't3', title: 'Fac comandă sticuri și căști Gavrilova viaimpex', date: today),
        TaskItem(id: 't4', title: 'Rezolv ci contabilitatea la ZAICANI', date: today),
        TaskItem(id: 't5', title: 'Fac contract ZAICANI', date: today),
        TaskItem(id: 't6', title: 'Telefon frate orb repar', date: today),
        TaskItem(id: 't7', title: 'Cu lucrarea la Chilat văd', date: today),
      ];
    }
    _processDailyRecurrenceAndRollover();
    await _saveTasks();
  }

  void _processDailyRecurrenceAndRollover() {
    final today = DateUtils.dateOnly(DateTime.now());
    bool changed = false;
    for (int i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      if (!t.isCompleted && t.date.isBefore(today) && t.autoTransfer && globalAutoRollover && t.recurrence == 'none') {
        tasks[i] = t.copyWith(date: today);
        changed = true;
      }
    }
    final dailyTemplates = tasks.where((t) => t.recurrence == 'daily').toList();
    for (final tmpl in dailyTemplates) {
      final existsToday = tasks.any((x) => x.title == tmpl.title && DateUtils.isSameDay(x.date, today));
      if (!existsToday) {
        tasks.add(tmpl.copyWith(
          id: 'rec_${DateTime.now().microsecondsSinceEpoch}_${tmpl.title}',
          date: today,
          isCompleted: false,
        ));
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasks_db', jsonEncode(tasks.map((e) => e.toJson()).toList()));
  }

  void _upsertTask(TaskItem item) {
    setState(() {
      final idx = tasks.indexWhere((t) => t.id == item.id);
      if (idx >= 0) {
        tasks[idx] = item;
      } else {
        tasks.add(item);
      }
    });
    _saveTasks();
  }

  void _deleteTask(String id) {
    setState(() => tasks.removeWhere((t) => t.id == id));
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lucrurile mele',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: darkMode ? Brightness.dark : Brightness.light,
        primaryColor: primaryTeal,
        scaffoldBackgroundColor: darkMode ? const Color(0xFF121212) : const Color(0xFFEAEAEA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          brightness: darkMode ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: MainShell(
        tasks: tasks,
        primaryTeal: primaryTeal,
        darkMode: darkMode,
        fadeOnComplete: fadeOnComplete,
        showScaleAndFraction: showScaleAndFraction,
        onUpsertTask: _upsertTask,
        onDeleteTask: _deleteTask,
        onToggleDark: () async {
          setState(() => darkMode = !darkMode);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('darkMode', darkMode);
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final List<TaskItem> tasks;
  final Color primaryTeal;
  final bool darkMode;
  final bool fadeOnComplete;
  final bool showScaleAndFraction;
  final Function(TaskItem) onUpsertTask;
  final Function(String) onDeleteTask;
  final VoidCallback onToggleDark;

  const MainShell({
    super.key,
    required this.tasks,
    required this.primaryTeal,
    required this.darkMode,
    required this.fadeOnComplete,
    required this.showScaleAndFraction,
    required this.onUpsertTask,
    required this.onDeleteTask,
    required this.onToggleDark,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentTab = 0;
  DateTime selectedWeekBase = DateUtils.dateOnly(DateTime.now());
  DateTime? expandedDate = DateUtils.dateOnly(DateTime.now());
  String? selectedTaskId;
  String searchQuery = '';

  List<DateTime> _getCurrentWeekDays() {
    final weekday = selectedWeekBase.weekday;
    final monday = selectedWeekBase.subtract(Duration(days: weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  void _openQuickDialog({TaskItem? existing, required DateTime date}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    String startTime = existing?.startTime ?? '17:47';
    bool hasTime = existing?.hasTime ?? false;
    String recurrence = existing?.recurrence ?? 'none';
    bool autoTransfer = existing?.autoTransfer ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text('${date.day}.${date.month}.${date.year}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Scrie lucrul...'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Indicați ora ($startTime)'),
                  value: hasTime,
                  onChanged: (v) async {
                    setDState(() => hasTime = v);
                    if (v) {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 17, minute: 47),
                      );
                      if (picked != null) {
                        setDState(() {
                          startTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repetare în fiecare zi'),
                  value: recurrence == 'daily',
                  onChanged: (v) => setDState(() => recurrence = v ? 'daily' : 'none'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Transfer automat pe mâine'),
                  value: autoTransfer,
                  onChanged: (v) => setDState(() => autoTransfer = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ANULEAZĂ')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                widget.onUpsertTask(TaskItem(
                  id: existing?.id ?? 't_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtrl.text.trim(),
                  date: date,
                  hasTime: hasTime,
                  startTime: hasTime ? startTime : null,
                  recurrence: recurrence,
                  autoTransfer: autoTransfer,
                  isCompleted: existing?.isCompleted ?? false,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('SALVEAZĂ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getCurrentWeekDays();
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedTask = widget.tasks.where((t) => t.id == selectedTaskId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.primaryTeal,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.format_list_bulleted), onPressed: () => setState(() => currentTab = 0)),
            IconButton(icon: const Icon(Icons.calendar_month), onPressed: () => setState(() => currentTab = 1)),
            IconButton(icon: const Icon(Icons.settings), onPressed: () => setState(() => currentTab = 2)),
          ],
        ),
      ),
      body: currentTab == 0
          ? ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: weekDays.length,
              itemBuilder: (ctx, i) {
                final day = weekDays[i];
                final dayTasks = widget.tasks.where((t) => DateUtils.isSameDay(t.date, day)).toList();
                final done = dayTasks.where((t) => t.isCompleted).length;
                final total = dayTasks.length;
                final isExpanded = expandedDate != null && DateUtils.isSameDay(expandedDate, day);
                final isToday = DateUtils.isSameDay(day, today);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () => setState(() => expandedDate = isExpanded ? null : day),
                        leading: CircleAvatar(
                          backgroundColor: isToday ? widget.primaryTeal : Colors.grey[300],
                          foregroundColor: isToday ? Colors.white : Colors.black87,
                          child: Text('${day.day}'),
                        ),
                        title: Text(isToday && (total - done) > 0 ? '${total - done}e lucruri restante' : '$total Lucruri'),
                        subtitle: LinearProgressIndicator(
                          value: total == 0 ? 0 : done / total,
                          backgroundColor: const Color(0xFFE57373),
                          valueColor: AlwaysStoppedAnimation<Color>(widget.primaryTeal),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _openQuickDialog(date: day),
                        ),
                      ),
                      if (isExpanded)
                        ...dayTasks.map((t) => ListTile(
                              selected: selectedTaskId == t.id,
                              onTap: () => setState(() => selectedTaskId = selectedTaskId == t.id ? null : t.id),
                              leading: Checkbox(
                                value: t.isCompleted,
                                onChanged: (v) => widget.onUpsertTask(t.copyWith(isCompleted: v ?? false)),
                              ),
                              title: Text(
                                t.title,
                                style: TextStyle(decoration: t.isCompleted ? TextDecoration.lineThrough : null),
                              ),
                              subtitle: t.hasTime && t.startTime != null ? Text(t.startTime!) : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.redo),
                                onPressed: () => widget.onUpsertTask(t.copyWith(date: t.date.add(const Duration(days: 1)))),
                              ),
                            )),
                    ],
                  ),
                );
              },
            )
          : currentTab == 1
              ? ListView(
                  padding: const EdgeInsets.all(12),
                  children: widget.tasks
                      .map((t) => Card(
                            child: ListTile(
                              leading: Checkbox(
                                value: t.isCompleted,
                                onChanged: (v) => widget.onUpsertTask(t.copyWith(isCompleted: v ?? false)),
                              ),
                              title: Text(t.title),
                              subtitle: Text('${t.date.day}.${t.date.month}.${t.date.year}'),
                            ),
                          ))
                      .toList(),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          decoration: const InputDecoration(icon: Icon(Icons.search), hintText: 'Căutare...', border: InputBorder.none),
                          onChanged: (v) => setState(() => searchQuery = v),
                        ),
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      ...widget.tasks
                          .where((t) => t.title.toLowerCase().contains(searchQuery.toLowerCase()))
                          .map((t) => ListTile(title: Text(t.title), subtitle: Text('${t.date.day}.${t.date.month}.${t.date.year}'))),
                    SwitchListTile(
                      title: const Text('Setări de proiectare: Design întunecat'),
                      value: widget.darkMode,
                      onChanged: (_) => widget.onToggleDark(),
                    ),
                  ],
                ),
      bottomNavigationBar: selectedTask != null
          ? BottomAppBar(
              color: widget.primaryTeal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () => _openQuickDialog(existing: selectedTask, date: selectedTask.date),
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo, color: Colors.white),
                    onPressed: () {
                      widget.onUpsertTask(selectedTask.copyWith(date: selectedTask.date.add(const Duration(days: 1))));
                      setState(() => selectedTaskId = null);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white),
                    onPressed: () {
                      widget.onUpsertTask(selectedTask.copyWith(id: 'c_${DateTime.now().millisecondsSinceEpoch}'));
                      setState(() => selectedTaskId = null);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => Share.share(selectedTask.title),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () {
                      widget.onDeleteTask(selectedTask.id);
                      setState(() => selectedTaskId = null);
                    },
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
