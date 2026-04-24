import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'models/task_model.dart';
import 'services/task_storage.dart';

void main() {
  runApp(const TaskPlannerApp());
}

class TaskPlannerApp extends StatelessWidget {
  const TaskPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '时间规划',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CE7),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CE7),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TaskStorage _storage = TaskStorage();
  List<TaskModel> _allTasks = [];
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 语音识别
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _speechText = '';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _initSpeech();
  }

  Future<void> _loadTasks() async {
    final tasks = await _storage.loadTasks();
    setState(() {
      _allTasks = tasks;
      _isLoading = false;
    });
  }

  void _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    setState(() {});
  }

  List<TaskModel> get _selectedDayTasks {
    return _allTasks
        .where((t) =>
            t.date.year == _selectedDay.year &&
            t.date.month == _selectedDay.month &&
            t.date.day == _selectedDay.day)
        .toList()
      ..sort((a, b) {
        if (a.time == null && b.time == null) return 0;
        if (a.time == null) return 1;
        if (b.time == null) return -1;
        return a.time!.compareTo(b.time!);
      });
  }

  int get _taskCountForDay(DateTime day) {
    return _allTasks
        .where((t) =>
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day &&
            !t.isCompleted)
        .length;
  }

  // ---- 语音识别 ----
  void _startListening() async {
    if (!_speechAvailable) {
      _showMessage('语音识别不可用');
      return;
    }
    setState(() {
      _speechText = '';
      _isListening = true;
    });
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _speechText = result.recognizedWords;
        });
      },
      localeId: 'zh_CN',
      listenMode: stt.ListenMode.dictation,
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _parseVoiceAndAddTask() {
    final text = _speechText.trim();
    if (text.isEmpty) {
      _showMessage('没有识别到内容');
      return;
    }

    // 智能解析语音文本：尝试提取时间和任务标题
    String? parsedTime;
    String parsedTitle = text;

    // 常见时间模式
    final timePatterns = [
      RegExp(r'(\d{1,2})[点时:：](\d{0,2})'),
      RegExp(r'(上午|下午|晚上|早上|中午|凌晨)(\d{1,2})[点时]?'),
      RegExp(r'(\d{1,2})[点时](半|一刻)'),
    ];

    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        parsedTitle = text.replaceAll(match.group(0)!, '').trim();
        parsedTitle = parsedTitle.replaceAll(RegExp(r'[，,。.、]'), ' ').trim();

        // 格式化时间
        if (pattern == timePatterns[0]) {
          int hour = int.parse(match.group(1)!);
          String? minute = match.group(2);
          if (hour < 0 || hour > 23) hour = 9;
          parsedTime =
              '${hour.toString().padLeft(2, '0')}:${(minute?.isNotEmpty == true ? int.parse(minute!) : 0).toString().padLeft(2, '0')}';
        } else if (pattern == timePatterns[1]) {
          String period = match.group(1)!;
          int hour = int.parse(match.group(2)!);
          if (period == '下午' || period == '晚上') hour += 12;
          if (hour >= 24) hour -= 12;
          parsedTime = '${hour.toString().padLeft(2, '0')}:00';
        } else if (pattern == timePatterns[2]) {
          int hour = int.parse(match.group(1)!);
          String sub = match.group(2)!;
          int minute = sub == '半' ? 30 : 15;
          parsedTime =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
        break;
      }
    }

    if (parsedTitle.isEmpty) parsedTitle = text;

    _showAddTaskDialog(
      initialTitle: parsedTitle,
      initialTime: parsedTime,
    );
  }

  // ---- 弹窗 ----
  void _showAddTaskDialog({
    String initialTitle = '',
    String? initialTime,
  }) {
    final titleController = TextEditingController(text: initialTitle);
    String? selectedTime = initialTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '添加任务',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                autofocus: initialTitle.isEmpty,
                decoration: InputDecoration(
                  labelText: '任务内容',
                  hintText: '输入任务内容...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.task_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // 日期选择
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('yyyy年M月d日 EEEE', 'zh_CN')
                    .format(_selectedDay)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDay,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                    locale: const Locale('zh', 'CN'),
                  );
                  if (date != null) {
                    setModalState(() {
                      // will use this date when saving
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              // 时间选择
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime != null
                        ? _parseTimeOfDay(selectedTime)
                        : TimeOfDay.now(),
                    helpText: '选择时间',
                  );
                  if (time != null) {
                    setModalState(() {
                      selectedTime = time.format(context);
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Text(
                        selectedTime ?? '不设置时间',
                        style: TextStyle(
                          color: selectedTime != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      if (selectedTime != null)
                        GestureDetector(
                          onTap: () => setModalState(() => selectedTime = null),
                          child: Icon(Icons.clear,
                              size: 20, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入任务内容')),
                    );
                    return;
                  }
                  final task = TaskModel(
                    id: const Uuid().v4(),
                    title: title,
                    date: _selectedDay,
                    time: selectedTime,
                  );
                  await _storage.addTask(task);
                  await _loadTasks();
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('添加任务'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  void _showDeleteConfirm(TaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除「${task.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await _storage.deleteTask(task.id);
              await _loadTasks();
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ---- 构建界面 ----
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // 顶部栏
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '时间规划',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('yyyy年M月d日', 'zh_CN')
                                    .format(DateTime.now()),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // 统计
                          _buildStatChip(
                            icon: Icons.check_circle_outline,
                            label:
                                '${_allTasks.where((t) => t.isCompleted).length}',
                            color: Colors.green,
                            bgColor: Colors.green.withOpacity(0.1),
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            icon: Icons.pending_outlined,
                            label:
                                '${_allTasks.where((t) => !t.isCompleted).length}',
                            color: colorScheme.primary,
                            bgColor:
                                colorScheme.primary.withOpacity(0.1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 日历
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime(2024),
                          lastDay: DateTime(2030),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          calendarFormat: _calendarFormat,
                          onFormatChanged: (format) {
                            setState(() => _calendarFormat = format);
                          },
                          onDaySelected: (selected, focused) {
                            setState(() {
                              _selectedDay = selected;
                              _focusedDay = focused;
                            });
                          },
                          locale: 'zh_CN',
                          headerVisible: false,
                          daysOfWeekHeight: 36,
                          rowHeight: 44,
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              final count = _taskCountForDay(date);
                              if (count == 0) return null;
                              return Positioned(
                                bottom: 2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            },
                            selectedBuilder: (context, date, focused) {
                              return Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${date.day}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                            todayBuilder: (context, date, focused) {
                              return Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            defaultTextStyle: TextStyle(
                              color: Colors.grey[700],
                            ),
                            weekendTextStyle: TextStyle(
                              color: Colors.red[400],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 日期标题
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text(
                            DateFormat('M月d日 周E', 'zh_CN')
                                .format(_selectedDay),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedDayTasks.length} 个任务',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 任务列表
                  if (_selectedDayTasks.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final task = _selectedDayTasks[index];
                          return _buildTaskCard(task);
                        },
                        childCount: _selectedDayTasks.length,
                      ),
                    ),

                  // 底部间距（给 FAB 让位）
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
      ),
      // 浮动按钮
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 语音按钮
          if (_speechAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                heroTag: 'voice',
                onPressed: _isListening ? _stopListening : _startListening,
                backgroundColor: _isListening
                    ? Colors.redAccent
                    : colorScheme.primary,
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                ),
              ),
            ),
          // 添加任务按钮
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () => _showAddTaskDialog(),
            backgroundColor: colorScheme.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // 语音识别结果底部面板
      bottomSheet: _isListening
          ? _buildListeningPanel()
          : (_speechText.isNotEmpty && !_isListening)
              ? _buildVoiceResultPanel()
              : null,
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red[400]),
      ),
      confirmDismiss: (direction) async {
        _showDeleteConfirm(task);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: task.isCompleted
                ? Colors.green.withOpacity(0.3)
                : Colors.grey[200]!,
          ),
        ),
        color: task.isCompleted
            ? Colors.green.withOpacity(0.03)
            : colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 完成勾选
              GestureDetector(
                onTap: () async {
                  await _storage.toggleTask(task.id);
                  await _loadTasks();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isCompleted
                        ? Colors.green
                        : Colors.transparent,
                    border: Border.all(
                      color: task.isCompleted
                          ? Colors.green
                          : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // 任务内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? Colors.grey
                            : colorScheme.onSurface,
                      ),
                    ),
                    if (task.time != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            task.time!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // 删除按钮
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                onPressed: () => _showDeleteConfirm(task),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '今天没有任务',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击 + 添加新任务\n或点击 🎤 语音添加',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[400]!, Colors.pink[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '正在聆听...',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _stopListening,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '停止',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            if (_speechText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '"$_speechText"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceResultPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '识别结果',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _speechText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _speechText = '');
                      _startListening();
                    },
                    child: const Text('重新识别'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() => _speechText = '');
                      _parseVoiceAndAddTask();
                    },
                    child: const Text('添加为任务'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
