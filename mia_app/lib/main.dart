import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:idb_shim/idb_browser.dart' as idb;
import 'package:shared_preferences/shared_preferences.dart';

const _primaryBlue = Color(0xFF123B67);
const _schoolSubjects = [
  _SchoolSubject('Matematica', Icons.functions),
  _SchoolSubject('Italiano', Icons.menu_book),
  _SchoolSubject('Latino', Icons.account_balance),
  _SchoolSubject('Geostoria', Icons.public),
  _SchoolSubject('Fisica', Icons.bolt),
  _SchoolSubject('Disegno', Icons.brush),
  _SchoolSubject('Scienze', Icons.science),
  _SchoolSubject('Inglese', Icons.language),
  _SchoolSubject('Religione', Icons.church),
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ok computer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _primaryBlue),
        scaffoldBackgroundColor: const Color(0xFFEAF1F8),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Il mio calendario'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const _storageKey = 'homework_calendar_tasks';
  static const _weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  static const _months = [
    'Gennaio',
    'Febbraio',
    'Marzo',
    'Aprile',
    'Maggio',
    'Giugno',
    'Luglio',
    'Agosto',
    'Settembre',
    'Ottobre',
    'Novembre',
    'Dicembre',
  ];

  final Map<String, List<_HomeworkTask>> _tasksByDate = {};
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  int _selectedPage = 0;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    _visibleMonth = DateTime(today.year, today.month);
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final preferences = await SharedPreferences.getInstance();
      final storedTasks = preferences.getString(_storageKey);
      final decodedTasks = <String, List<_HomeworkTask>>{};

      if (storedTasks != null) {
        final data = jsonDecode(storedTasks) as Map<String, dynamic>;
        for (final entry in data.entries) {
          final tasks = entry.value as List<dynamic>;
          decodedTasks[entry.key] = tasks
              .map(
                (task) => _HomeworkTask.fromJson(
                  Map<String, dynamic>.from(task as Map),
                ),
              )
              .toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _tasksByDate
          ..clear()
          ..addAll(decodedTasks);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Non riesco a caricare i compiti salvati.';
        _isLoading = false;
      });
    }
  }

  String get _selectedDateKey => _dateKey(_selectedDate);

  List<_HomeworkTask> get _selectedTasks =>
      _tasksByDate[_selectedDateKey] ?? const [];

  Future<void> _saveTasks(Map<String, List<_HomeworkTask>> updatedTasks) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        updatedTasks.map(
          (date, tasks) =>
              MapEntry(date, tasks.map((task) => task.toJson()).toList()),
        ),
      );
      final saved = await preferences.setString(_storageKey, encoded);
      if (!saved) {
        throw StateError('Impossibile salvare i compiti.');
      }

      if (!mounted) return;
      setState(() {
        _tasksByDate
          ..clear()
          ..addAll(updatedTasks);
      });
    } catch (_) {
      _showMessage('Non riesco a salvare la modifica. Riprova.');
    }
  }

  Future<void> _addTask() async {
    final draft = await showDialog<_HomeworkDraft>(
      context: context,
      builder: (_) => const _AddTaskDialog(),
    );

    if (draft == null || !mounted) return;
    final updatedTasks = _copyTasks();
    updatedTasks
        .putIfAbsent(_selectedDateKey, () => [])
        .add(
          _HomeworkTask(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: draft.title,
            subject: draft.subject,
          ),
        );
    await _saveTasks(updatedTasks);
  }

  Future<void> _toggleTask(_HomeworkTask task) async {
    final updatedTasks = _copyTasks();
    final tasks = updatedTasks[_selectedDateKey]!;
    final index = tasks.indexWhere((item) => item.id == task.id);
    tasks[index] = task.copyWith(isDone: !task.isDone);
    await _saveTasks(updatedTasks);
  }

  Future<void> _deleteTask(_HomeworkTask task) async {
    final updatedTasks = _copyTasks();
    updatedTasks[_selectedDateKey]!.removeWhere((item) => item.id == task.id);
    if (updatedTasks[_selectedDateKey]!.isEmpty) {
      updatedTasks.remove(_selectedDateKey);
    }
    await _saveTasks(updatedTasks);
  }

  Map<String, List<_HomeworkTask>> _copyTasks() => _tasksByDate.map(
    (date, tasks) => MapEntry(date, List<_HomeworkTask>.of(tasks)),
  );

  void _changeMonth(int amount) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + amount,
      );
      _selectedDate = _visibleMonth;
    });
  }

  void _selectToday() {
    final today = DateTime.now();
    setState(() {
      _selectedDate = DateTime(today.year, today.month, today.day);
      _visibleMonth = DateTime(today.year, today.month);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_selectedPage) {
          0 => 'ok computer',
          1 => widget.title,
          _ => 'School',
        }),
        backgroundColor: const Color(0xFFD8E5F2),
        actions: _selectedPage == 1
            ? [
                TextButton.icon(
                  onPressed: _selectToday,
                  icon: const Icon(Icons.today),
                  label: const Text('Oggi'),
                ),
              ]
            : null,
      ),
      body: switch (_selectedPage) {
        0 => _buildHomePage(),
        1 =>
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _buildLoadError()
              : _buildCalendar(),
        _ => _buildSchoolPage(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedPage,
        onDestinationSelected: (index) {
          setState(() => _selectedPage = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ok computer',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'School',
          ),
        ],
      ),
      floatingActionButton:
          _selectedPage != 1 || _isLoading || _loadError != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addTask,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi compito'),
            ),
    );
  }

  Widget _buildHomePage() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 12),
        Text(
          'Cosa vuoi aprire?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold, color: _primaryBlue),
        ),
        const SizedBox(height: 24),
        _buildHomeTile(
          title: 'Il mio calendario',
          subtitle: 'Visualizza e organizza i tuoi compiti',
          icon: Icons.calendar_month,
          page: 1,
        ),
        const SizedBox(height: 16),
        _buildHomeTile(
          title: 'School',
          subtitle: 'Apri le tue materie scolastiche',
          icon: Icons.school,
          page: 2,
        ),
      ],
    );
  }

  Widget _buildHomeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required int page,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedPage = page),
        child: SizedBox(
          height: 150,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(icon, size: 48, color: _primaryBlue),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: _primaryBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolPage() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _schoolSubjects.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final subject = _schoolSubjects[index];
        return Card(
          color: Colors.white.withValues(alpha: 0.85),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _SubjectFilesPage(subject: subject),
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(subject.icon, size: 38, color: _primaryBlue),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    subject.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadTasks, child: const Text('Riprova')),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final tasks = _selectedTasks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _buildMonthHeader(),
        const SizedBox(height: 16),
        _buildCalendarGrid(),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Compiti per ${_formatDate(_selectedDate)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              '${tasks.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          Card(
            color: Colors.white.withValues(alpha: 0.75),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nessun compito per questo giorno. '
                'Tocca “Aggiungi compito” per scriverne uno.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...tasks.map(_buildTaskTile),
      ],
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          tooltip: 'Mese precedente',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '${_months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          tooltip: 'Mese successivo',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final offset = firstDay.weekday - 1;
    final numberOfWeeks = ((offset + daysInMonth) / 7).ceil();
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: _weekdays
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        day,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        for (var week = 0; week < numberOfWeeks; week++)
          Row(
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                Expanded(
                  child: _buildDayCell(
                    week * 7 + weekday - offset + 1,
                    daysInMonth,
                    today,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildDayCell(int day, int daysInMonth, DateTime today) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: 52);
    }

    final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
    final key = _dateKey(date);
    final isSelected = key == _selectedDateKey;
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final hasTasks = _tasksByDate[key]?.isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: isSelected ? _primaryBlue : Colors.white.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isToday && !isSelected
              ? const BorderSide(color: _primaryBlue, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedDate = date),
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasTasks
                        ? (isSelected ? Colors.white : _primaryBlue)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTile(_HomeworkTask task) {
    return Card(
      color: Colors.white.withValues(alpha: 0.85),
      child: ListTile(
        leading: Checkbox(
          value: task.isDone,
          onChanged: (_) => _toggleTask(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isDone ? TextDecoration.lineThrough : null,
            color: task.isDone ? Colors.black54 : null,
          ),
        ),
        subtitle: task.subject == null ? null : Text(task.subject!),
        trailing: IconButton(
          onPressed: () => _deleteTask(task),
          tooltip: 'Elimina compito',
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1].toLowerCase()} ${date.year}';

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _SchoolSubject {
  const _SchoolSubject(this.name, this.icon);

  final String name;
  final IconData icon;
}

class _SubjectFile {
  const _SubjectFile({
    required this.id,
    required this.subject,
    required this.name,
    required this.bytes,
  });

  final String id;
  final String subject;
  final String name;
  final List<int> bytes;

  factory _SubjectFile.fromJson(Map<String, dynamic> json) => _SubjectFile(
    id: json['id'] as String,
    subject: json['subject'] as String,
    name: json['name'] as String,
    bytes: List<int>.from(json['bytes'] as List),
  );

  Map<String, Object> toJson() => {
    'id': id,
    'subject': subject,
    'name': name,
    'bytes': bytes,
  };
}

class _SubjectFileStorage {
  static const _storeName = 'subject_files';
  static final Future<idb.Database> _database = _openDatabase();

  static Future<idb.Database> _openDatabase() async {
    final factory = idb.getIdbFactory();
    if (factory == null) {
      throw StateError('Il salvataggio dei file non è disponibile.');
    }
    return factory.open(
      'school_subject_files',
      version: 1,
      onUpgradeNeeded: (event) {
        if (!event.database.objectStoreNames.contains(_storeName)) {
          event.database.createObjectStore(_storeName, keyPath: 'id');
        }
      },
    );
  }

  static Future<List<_SubjectFile>> filesFor(String subject) async {
    final database = await _database;
    final transaction = database.transaction(_storeName, idb.idbModeReadOnly);
    final records = await transaction.objectStore(_storeName).getAll();
    await transaction.completed;
    return records
        .map(
          (record) =>
              _SubjectFile.fromJson(Map<String, dynamic>.from(record as Map)),
        )
        .where((file) => file.subject == subject)
        .toList();
  }

  static Future<void> save(_SubjectFile file) async {
    final database = await _database;
    final transaction = database.transaction(_storeName, idb.idbModeReadWrite);
    await transaction.objectStore(_storeName).put(file.toJson());
    await transaction.completed;
  }

  static Future<void> delete(String id) async {
    final database = await _database;
    final transaction = database.transaction(_storeName, idb.idbModeReadWrite);
    await transaction.objectStore(_storeName).delete(id);
    await transaction.completed;
  }
}

class _SubjectFilesPage extends StatefulWidget {
  const _SubjectFilesPage({required this.subject});

  final _SchoolSubject subject;

  @override
  State<_SubjectFilesPage> createState() => _SubjectFilesPageState();
}

class _SubjectFilesPageState extends State<_SubjectFilesPage> {
  List<_SubjectFile> _files = [];
  bool _isLoading = true;
  bool _isAdding = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final files = await _SubjectFileStorage.filesFor(widget.subject.name);
      if (!mounted) return;
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Non riesco a caricare i file salvati.';
        _isLoading = false;
      });
    }
  }

  Future<void> _addFiles() async {
    setState(() => _isAdding = true);
    try {
      final pickedFiles = await FilePicker.pickFiles(
        dialogTitle: 'Scegli i file per ${widget.subject.name}',
        type: FileType.any,
      );
      for (final pickedFile in pickedFiles) {
        final bytes = await pickedFile.readAsBytes();
        final now = DateTime.now().microsecondsSinceEpoch;
        await _SubjectFileStorage.save(
          _SubjectFile(
            id: '${widget.subject.name}-$now-${pickedFile.name}',
            subject: widget.subject.name,
            name: pickedFile.name,
            bytes: bytes,
          ),
        );
      }
      await _loadFiles();
    } catch (_) {
      if (mounted) {
        await _loadFiles();
        _showMessage(
          'Non riesco a salvare i file. Potrebbe mancare spazio nel browser.',
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _downloadFile(_SubjectFile file) async {
    final dot = file.name.lastIndexOf('.');
    final extension = dot > 0 ? file.name.substring(dot + 1) : '';
    final name = dot > 0 ? file.name.substring(0, dot) : file.name;
    try {
      await FileSaver.instance.saveAs(
        name: name,
        bytes: Uint8List.fromList(file.bytes),
        fileExtension: extension,
        mimeType: MimeType.other,
        dialogTitle: 'Scarica ${file.name}',
      );
    } catch (_) {
      _showMessage('Non riesco a scaricare ${file.name}.');
    }
  }

  Future<void> _deleteFile(_SubjectFile file) async {
    try {
      await _SubjectFileStorage.delete(file.id);
      await _loadFiles();
    } catch (_) {
      _showMessage('Non riesco a eliminare ${file.name}.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        backgroundColor: const Color(0xFFD8E5F2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadFiles,
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            )
          : _files.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Non ci sono ancora file per questa materia. '
                  'Tocca “Aggiungi file” per sceglierne uno. I file restano '
                  'salvati in questo browser; lo spazio disponibile dipende '
                  'dal dispositivo.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'I file sono salvati in questo browser. Lo spazio '
                    'disponibile dipende dal dispositivo.',
                    textAlign: TextAlign.center,
                  ),
                ),
                ..._files.map(
                  (file) => Card(
                    color: Colors.white.withValues(alpha: 0.85),
                    child: ListTile(
                      leading: const Icon(
                        Icons.insert_drive_file_outlined,
                        color: _primaryBlue,
                      ),
                      title: Text(file.name),
                      subtitle: Text(
                        '${(file.bytes.length / 1024).toStringAsFixed(1)} KB',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Scarica file',
                            onPressed: () => _downloadFile(file),
                            icon: const Icon(Icons.download),
                          ),
                          IconButton(
                            tooltip: 'Elimina file',
                            onPressed: () => _deleteFile(file),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAdding ? null : _addFiles,
        icon: _isAdding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isAdding ? 'Salvataggio...' : 'Aggiungi file'),
      ),
    );
  }
}

class _HomeworkTask {
  const _HomeworkTask({
    required this.id,
    required this.title,
    this.subject,
    this.isDone = false,
  });

  final String id;
  final String title;
  final String? subject;
  final bool isDone;

  _HomeworkTask copyWith({bool? isDone}) => _HomeworkTask(
    id: id,
    title: title,
    subject: subject,
    isDone: isDone ?? this.isDone,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (subject != null) 'subject': subject,
    'isDone': isDone,
  };

  factory _HomeworkTask.fromJson(Map<String, dynamic> json) => _HomeworkTask(
    id: json['id'] as String,
    title: json['title'] as String,
    subject: json['subject'] as String?,
    isDone: json['isDone'] as bool? ?? false,
  );
}

class _HomeworkDraft {
  const _HomeworkDraft({required this.subject, required this.title});

  final String subject;
  final String title;
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _controller = TextEditingController();
  String? _selectedSubject;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final subject = _selectedSubject;
    if (text.isNotEmpty && subject != null) {
      Navigator.pop(context, _HomeworkDraft(subject: subject, title: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _selectedSubject == null
            ? 'Scegli la materia'
            : 'Compito di $_selectedSubject',
      ),
      content: SizedBox(
        width: 360,
        height: 360,
        child: _selectedSubject == null
            ? ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final subject in _schoolSubjects)
                    ListTile(
                      leading: Icon(subject.icon, color: _primaryBlue),
                      title: Text(subject.name),
                      onTap: () =>
                          setState(() => _selectedSubject = subject.name),
                    ),
                ],
              )
            : TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Es. Esercizi del capitolo 3',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _selectedSubject == null
              ? () => Navigator.pop(context)
              : () => setState(() => _selectedSubject = null),
          child: Text(_selectedSubject == null ? 'Annulla' : 'Indietro'),
        ),
        if (_selectedSubject != null)
          FilledButton(onPressed: _submit, child: const Text('Aggiungi')),
      ],
    );
  }
}
