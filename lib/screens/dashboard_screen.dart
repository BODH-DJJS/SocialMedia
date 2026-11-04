import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../models/event.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _postFilter = 'All';
  String _postTab = 'Individual'; // 'Individual' or 'Combined'
  Timer? _refreshTimer;
  final Set<String> _selectedPosts = {};
  bool _isSelectionMode = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _workflowSearchController = TextEditingController();
  String _myQueueFilter = 'All Tasks';

  static const String _colWidthsPrefPrefix = 'dashboard_col_width_';
  static const Map<String, double> _defaultColWidths = {
    'postNo': 130.0,
    'activityType': 130.0,
    'branch': 150.0,
    'venue': 200.0,
    'theme': 220.0,
    'date': 115.0,
    'totalBen': 90.0,
    'actions': 120.0,
  };
  final Map<String, double> _colWidths = Map.from(_defaultColWidths);

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadColumnWidths();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final provider = context.read<EventProvider>();
      provider.fetchEvents(auth.role, auth.username);
      if (auth.role.toLowerCase() == 'admin') {
        provider.fetchUsers();
        provider.fetchBranchSPOCs();
      }
    });
  }

  Future<void> _loadColumnWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _defaultColWidths.keys) {
        final val = prefs.getDouble('$_colWidthsPrefPrefix$key');
        if (val != null && val >= 50.0) {
          _colWidths[key] = val;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveColumnWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _colWidths.entries) {
        await prefs.setDouble('$_colWidthsPrefPrefix${entry.key}', entry.value);
      }
    } catch (_) {}
  }

  void _resetColumnWidths() {
    setState(() {
      _colWidths.clear();
      _colWidths.addAll(_defaultColWidths);
    });
    _saveColumnWidths();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Column widths reset to default!'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _workflowSearchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.role.toLowerCase() == 'admin';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.dashboard_rounded, size: 20),
            ),
            const SizedBox(width: 10),
            Text(isAdmin ? 'BODH Admin' : 'My Queue'),
          ],
        ),
        bottom:
            eventProvider.isSyncing
                ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.transparent,
                  ),
                )
                : null,
        actions: [
          if (isAdmin && _currentIndex == 2) ...[
            Container(
              width: 220,
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _workflowSearchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search Post No or Branch...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _workflowSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Colors.white70),
                          onPressed: () => setState(() => _workflowSearchController.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (!isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                label: Text(
                  auth.role,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                backgroundColor: theme.colorScheme.secondary,
                side: BorderSide.none,
              ),
            ),
          eventProvider.isSyncing
              ? const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              )
              : IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                onPressed:
                    () => eventProvider.fetchEvents(auth.role, auth.username, force: true),
              ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () {
              auth.logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body:
          eventProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : isAdmin
              ? _buildAdminBody(eventProvider, auth)
              : _buildUserBody(eventProvider),
      bottomNavigationBar:
          isAdmin
              ? NavigationBarTheme(
                  data: NavigationBarThemeData(
                    labelTextStyle: MaterialStateProperty.all(
                      const TextStyle(color: Colors.white),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (i) => setState(() => _currentIndex = i),
                    backgroundColor: theme.colorScheme.primary,
                    indicatorColor: theme.colorScheme.secondary.withOpacity(0.3),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(
                          Icons.space_dashboard_outlined,
                          color: Colors.white60,
                        ),
                        selectedIcon: Icon(
                          Icons.space_dashboard,
                          color: Colors.white,
                        ),
                        label: 'Dashboard',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.list_alt_outlined, color: Colors.white60),
                        selectedIcon: Icon(Icons.list_alt, color: Colors.white),
                        label: 'All Posts',
                      ),
                      NavigationDestination(
                        icon: Icon(
                          Icons.view_kanban_outlined,
                          color: Colors.white60,
                        ),
                        selectedIcon: Icon(Icons.view_kanban, color: Colors.white),
                        label: 'Pipeline',
                      ),
                    ],
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  ),
                )
              : null,
    );
  }

  // ── ADMIN BODY ──
  Widget _buildAdminBody(EventProvider provider, AuthProvider auth) {
    switch (_currentIndex) {
      case 0:
        return _buildOverview(provider);
      case 1:
        return _buildAllPosts(provider, auth);
      case 2:
        return _buildKanbanBoard(provider);
      default:
        return _buildOverview(provider);
    }
  }

  // ── OVERVIEW / STATS ──
  Widget _buildOverview(EventProvider provider) {
    final total = provider.events.length;
    final done = provider.events.where((e) => e.status == 'Done').length;
    final pending = total - done;
    final writing =
        provider.events
            .where((e) => e.stage == 'Writing' && e.status != 'Done')
            .length;
    final editing =
        provider.events
            .where((e) => e.stage == 'Editing' && e.status != 'Done')
            .length;
    final proofing =
        provider.events
            .where((e) => e.stage == 'Proofreading' && e.status != 'Done')
            .length;

    final users = provider.users;
    final available = users.where((u) => u['status'] == 'Available').length;
    final engaged = users.where((u) => u['status'] == 'Engaged').length;

    final spocs = provider.spocs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards row
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Total Events',
                  '${provider.rawPosts.length}',
                  Icons.event_note,
                  const Color(0xFF1A237E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Active Tasks',
                  '$pending',
                  Icons.pending_actions,
                  const Color(0xFFFF6F00),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Completed',
                  '$done',
                  Icons.check_circle,
                  const Color(0xFF00897B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pipeline progress
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pipeline Progress',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _pipelineBar(
                    'Writing',
                    writing,
                    total,
                    const Color(0xFF42A5F5),
                  ),
                  const SizedBox(height: 12),
                  _pipelineBar(
                    'Editing',
                    editing,
                    total,
                    const Color(0xFFFF8A65),
                  ),
                  const SizedBox(height: 12),
                  _pipelineBar(
                    'Proofreading',
                    proofing,
                    total,
                    const Color(0xFFAB47BC),
                  ),
                  const SizedBox(height: 12),
                  _pipelineBar('Done', done, total, const Color(0xFF66BB6A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Team Availability
          if (users.isNotEmpty) ...[
            const Text(
              'Team Availability',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Available',
                    '$available',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Engaged',
                    '$engaged',
                    Icons.work_history,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Branch SPOCs
          const Text(
            'Branch SPOCs',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (spocs.isEmpty)
            const Text(
              'No SPOCs assigned yet.',
              style: TextStyle(color: Colors.grey),
            ),
          ...spocs.map(
            (s) => Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1A237E),
                  child: Icon(Icons.business, color: Colors.white, size: 20),
                ),
                title: Text(
                  s['branch'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${s['spocName']} (${s['spocEmail']})'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed:
                      () =>
                          _editSPOC(s['branch'], s['spocName'], s['spocEmail']),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editSPOC(String branch, String currentName, String currentEmail) {
    final nameCtrl = TextEditingController(text: currentName);
    final emailCtrl = TextEditingController(text: currentEmail);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Edit SPOC for $branch'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<EventProvider>().updateBranchSPOC(
                    branch,
                    nameCtrl.text,
                    emailCtrl.text,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pipelineBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 14,
              backgroundColor: Colors.grey.shade200,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  // ── KANBAN ──
  Widget _buildKanbanBoard(EventProvider provider) {
    final wQuery = _workflowSearchController.text.trim().toLowerCase();
    final filteredEvents = wQuery.isEmpty
          ? provider.events.where((e) => e.status != 'Done').toList()
          : provider.events.where((e) => (e.postNo.toLowerCase().contains(wQuery) || e.branch.toLowerCase().contains(wQuery)) && e.status != 'Done').toList();

    final contentStages = [
      (
        'Writing',
        filteredEvents.where((e) => e.stage == 'Writing').toList(),
        const Color(0xFF42A5F5),
        Icons.edit_note,
      ),
      (
        'Editing',
        filteredEvents.where((e) => e.stage == 'Editing').toList(),
        const Color(0xFFFF8A65),
        Icons.edit,
      ),
      (
        'Proofreading',
        filteredEvents.where((e) => e.stage == 'Proofreading').toList(),
        const Color(0xFFAB47BC),
        Icons.spellcheck,
      ),
      (
        'Text Crosscheck',
        filteredEvents
            .where((e) => e.stage == 'Text Crosscheck' || e.stage == 'Cross check' || e.stage == 'Crosscheck')
            .toList(),
        const Color(0xFF26A69A),
        Icons.fact_check,
      ),
      (
        'Ready to Post',
        filteredEvents.where((e) => e.stage == 'Ready to Post').toList(),
        Colors.purple.shade300,
        Icons.upload_file,
      ),
      (
        'Photos Clean',
        filteredEvents.where((e) => e.stage == 'Photos Clean').toList(),
        Colors.cyan,
        Icons.cleaning_services,
      ),
    ];

    final thumbnailStages = [
      (
        'Thumbnail Selection',
        filteredEvents.where((e) => e.stage == 'Thumbnail Selection').toList(),
        Colors.orange.shade300,
        Icons.image,
      ),
      (
        'Thumbnail Processing',
        filteredEvents
            .where((e) => e.stage == 'Thumbnail Processing')
            .toList(),
        Colors.orange,
        Icons.design_services,
      ),
      (
        'Thumbnail Cross checking',
        filteredEvents
            .where((e) => e.stage == 'Thumbnail Cross checking')
            .toList(),
        Colors.deepOrange,
        Icons.fact_check,
      ),
    ];

    final mediaStages = [
      (
        'Photo Editing',
        filteredEvents.where((e) => e.stage == 'Photo Editing').toList(),
        Colors.indigo,
        Icons.auto_fix_high,
      ),
      (
        'Video Editing',
        filteredEvents.where((e) => e.stage == 'Video Editing').toList(),
        Colors.redAccent,
        Icons.video_library,
      ),
      (
        'Media Cross Check',
        filteredEvents.where((e) => e.stage == 'Media Cross Check').toList(),
        Colors.blueGrey,
        Icons.fact_check,
      ),
      (
        'Media Final Cross check',
        filteredEvents.where((e) => e.stage == 'Media Final Cross check' || e.stage == 'Media Final Crosscheck').toList(),
        Colors.teal,
        Icons.verified,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
              'Content Workflow',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: 500,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  contentStages
                      .map(
                        (s) => _kanbanColumn(s.$1, s.$2, s.$3, s.$4, provider),
                      )
                      .toList(),
            ),
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'Thumbnail Workflow',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: 500,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  thumbnailStages
                      .map(
                        (s) => _kanbanColumn(s.$1, s.$2, s.$3, s.$4, provider),
                      )
                      .toList(),
            ),
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'Media Workflow',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: 500,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  mediaStages
                      .map(
                        (s) => _kanbanColumn(s.$1, s.$2, s.$3, s.$4, provider),
                      )
                      .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kanbanColumn(
    String title,
    List<Event> allTasks,
    Color color,
    IconData icon,
    EventProvider provider,
  ) {
    String columnFilter = 'All Tasks';

    return StatefulBuilder(
      builder: (context, setLocalState) {
        List<Event> tasks =
            allTasks.where((t) => t.status.trim().toLowerCase() != 'waiting').toList();
        if (columnFilter != 'All Tasks') {
          tasks = tasks.where((t) => t.status == columnFilter).toList();
        }
        List<Event> notStarted =
            tasks.where((t) => t.status != 'Done').toList();
        final doneList = tasks.where((t) => t.status == 'Done').toList();

        // Sort so that "Ready" tasks appear first
        notStarted.sort((a, b) {
          if (a.status == 'Ready' && b.status != 'Ready') return -1;
          if (a.status != 'Ready' && b.status == 'Ready') return 1;
          return 0;
        });

        return Container(
          width: 300,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color.withOpacity(0.9),
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${notStarted.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.filter_list, size: 18),
                      tooltip: 'Filter $title',
                      initialValue: columnFilter,
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        setLocalState(() {
                          columnFilter = val;
                        });
                      },
                      itemBuilder:
                          (context) => [
                            const PopupMenuItem(
                              value: 'All Tasks',
                              child: Text('All Tasks'),
                            ),
                            const PopupMenuItem(
                              value: 'Ready',
                              child: Text('Allotted Only'),
                            ),
                            const PopupMenuItem(
                              value: 'In Progress',
                              child: Text('In Progress Only'),
                            ),
                          ],
                    ),
                  ],
                ),
              ),
              // Cards
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    ...notStarted.map(
                      (t) => _buildKanbanTaskCard(t, color, provider),
                    ),

                    if (doneList.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                'Done (${doneList.length})',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                      ),
                    ...doneList.map((t) => _buildTaskCard(t, Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanTaskCard(
    Event task,
    Color accentColor,
    EventProvider provider,
  ) {
    return _buildTaskCard(task, accentColor);
  }

  Widget _buildTaskCard(Event task, Color accentColor) {
    final isDone = task.status == 'Done';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDone ? 0 : 2,
      color: isDone ? Colors.grey.shade100 : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/event', extra: task),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: accentColor, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Post ${task.postNo}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDone ? Colors.grey : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDone
                              ? Colors.green
                              : (task.status == 'In Progress'
                                  ? Colors.blue
                                  : (task.status == 'Ready'
                                      ? Colors.deepOrange
                                      : Colors.grey.shade400)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.status.isEmpty ? 'Pending' : (task.status == 'Ready' ? 'Allotted' : task.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (task.theme.isNotEmpty)
                Text(
                  task.theme,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              if (task.date.isNotEmpty)
                Text(
                  task.date,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              const SizedBox(height: 6),
              if (task.publishPlatform.isNotEmpty ||
                  task.mediaMode.isNotEmpty) ...[
                Row(
                  children: [
                    if (task.publishPlatform.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          task.publishPlatform,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (task.publishPlatform.isNotEmpty &&
                        task.mediaMode.isNotEmpty)
                      const SizedBox(width: 6),
                    if (task.mediaMode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              task.mediaMode == 'Video'
                                  ? Icons.videocam
                                  : Icons.photo,
                              size: 10,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              task.mediaMode,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.teal.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  if (task.assigneeName.isNotEmpty) ...[
                    Icon(Icons.person, size: 14, color: accentColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.assigneeName,
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (task.dueDate.isNotEmpty && !isDone) ...[
                    const Spacer(),
                    Icon(Icons.timer, size: 12, color: Colors.red.shade400),
                    const SizedBox(width: 2),
                    Text(
                      'Due ' + task.dueDate.split('T')[0],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ALL POSTS ──
  Widget _buildAllPosts(EventProvider provider, AuthProvider auth) {
    final filters = ['All', 'Active', 'Inactive', 'Posted', 'Clean', 'Completed'];

    List<Map<String, dynamic>> rawFiltered =
        provider.rawPosts.where((post) {
          final postNo = post['PostNo']?.toString().toLowerCase() ?? '';
          final branch = post['Branch']?.toString().toLowerCase() ?? '';

          // Search text filter by Post No OR Branch
          final searchQuery = _searchController.text.trim().toLowerCase();
          if (searchQuery.isNotEmpty && !postNo.contains(searchQuery) && !branch.contains(searchQuery)) {
            return false;
          }

          if (_postFilter == 'All') return true;
          // For combined, we might check tasks for the GroupID, but for now we check tasks for PostNo or GroupID
          final groupId = post['GroupID']?.toString() ?? '';
          final postTasks =
              provider.events
                  .where(
                    (t) =>
                        t.postNo == post['PostNo']?.toString() ||
                        (groupId.isNotEmpty && t.postNo == groupId),
                  )
                  .toList();

          final postStatus = _getPostWorkflowStatus(postTasks);

          if (_postFilter == 'Inactive') {
            return postStatus == 'Inactive';
          }
          if (_postFilter == 'Active') {
            return postStatus == 'Active';
          }
          if (_postFilter == 'Posted') {
            return postStatus == 'Posted' || postStatus == 'Clean' || postStatus == 'Completed';
          }
          if (_postFilter == 'Clean') {
            return postStatus == 'Clean';
          }
          if (_postFilter == 'Completed') {
            return postStatus == 'Completed';
          }
          return true;
        }).toList();

    List<Map<String, dynamic>> tabFiltered = [];
    List<Map<String, dynamic>> combinedGroups = [];

    if (_postTab == 'Individual') {
      tabFiltered =
          rawFiltered
              .where((p) => (p['GroupID']?.toString() ?? '').isEmpty)
              .toList();
    } else {
      final groups = <String, List<Map<String, dynamic>>>{};
      for (var p in rawFiltered) {
        final g = p['GroupID']?.toString() ?? '';
        if (g.isNotEmpty) {
          if (!groups.containsKey(g)) groups[g] = [];
          groups[g]!.add(p);
        }
      }
      for (var entry in groups.entries) {
        combinedGroups.add({'GroupID': entry.key, 'Posts': entry.value});
      }
    }

    return Scaffold(
      floatingActionButton:
          _postTab == 'Individual' &&
                  _isSelectionMode &&
                  _selectedPosts.isNotEmpty
              ? FloatingActionButton.extended(
                onPressed: _groupSelectedPosts,
                icon: const Icon(Icons.link),
                label: Text('Group ${_selectedPosts.length} Posts'),
              )
              : null,
      body: Column(
        children: [
          // Tab Toggle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Individual', label: Text('Individual')),
                ButtonSegment(value: 'Combined', label: Text('Combined')),
              ],
              selected: {_postTab},
              onSelectionChanged: (val) {
                setState(() {
                  _postTab = val.first;
                  _isSelectionMode = false;
                  _selectedPosts.clear();
                });
              },
            ),
          ),
          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Post No or Branch...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed:
                              () => setState(() => _searchController.clear()),
                        )
                        : null,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...filters.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: _postFilter == f,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.secondary.withOpacity(0.2),
                        onSelected:
                            (_) => setState(() {
                              _postFilter = f;
                              _isSelectionMode = false;
                              _selectedPosts.clear();
                            }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_postTab == 'Individual')
                    FilterChip(
                      label: const Text('Select Mode'),
                      selected: _isSelectionMode,
                      onSelected:
                          (val) => setState(() {
                            _isSelectionMode = val;
                            if (!val) _selectedPosts.clear();
                          }),
                      avatar: Icon(
                        _isSelectionMode
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  _postTab == 'Individual'
                      ? '${tabFiltered.length} posts'
                      : '${combinedGroups.length} combined groups',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                if (_postTab == 'Individual') ...[
                  Tooltip(
                    message: 'Reset column widths to default',
                    child: InkWell(
                      onTap: _resetColumnWidths,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune, size: 13, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text('Reset Columns', style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  'Drag column border to resize',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child:
                _postTab == 'Individual'
                    ? (tabFiltered.isEmpty
                        ? const Center(
                          child: Text('No individual posts found.'),
                        )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 800) {
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: tabFiltered.length,
                                  itemBuilder: (context, index) => _buildPostCard(tabFiltered[index], provider, auth),
                                );
                              }
                              return _buildPostsTable(tabFiltered, provider);
                            },
                          ))
                    : (combinedGroups.isEmpty
                        ? const Center(child: Text('No combined posts found.'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 800) {
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: combinedGroups.length,
                                  itemBuilder:
                                      (context, index) => _buildCombinedCard(
                                        combinedGroups[index],
                                        provider,
                                        auth,
                                      ),
                                );
                              }
                              return _buildCombinedPostsTable(combinedGroups, provider);
                            },
                          )),
          ),
        ],
      ),
    );
  }

  void _groupSelectedPosts() {
    final provider = context.read<EventProvider>();
    final selectedList = _selectedPosts.toList();
    // Sort selected post numbers
    selectedList.sort((a, b) {
      final intA = int.tryParse(a) ?? 0;
      final intB = int.tryParse(b) ?? 0;
      return intA.compareTo(intB);
    });

    // Detect branch from selected posts
    String branch = '';
    for (final pNo in selectedList) {
      final p = provider.rawPosts.firstWhere(
        (rp) => rp['PostNo']?.toString() == pNo,
        orElse: () => <String, dynamic>{},
      );
      if (p['Branch'] != null && p['Branch'].toString().trim().isNotEmpty) {
        branch = p['Branch'].toString().trim();
        break;
      }
    }
    if (branch.isEmpty) branch = 'Group';

    // Auto-generate default name: e.g. "Darbhanga Events (234, 256, 278)"
    final defaultGroupName = '$branch Events (${selectedList.join(', ')})';
    final ctrl = TextEditingController(text: defaultGroupName);

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Group Posts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Name this combined group. The name is auto-generated based on the branch and post numbers, and you can edit it anytime.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Group Name / ID',
                    hintText: 'e.g., Darbhanga Events (234, 256)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (ctrl.text.trim().isEmpty) return;
                  final groupId = ctrl.text.trim();
                  final success = await context
                      .read<EventProvider>()
                      .groupPosts(selectedList, groupId);
                  if (success && mounted) {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedPosts.clear();
                    });
                    context.read<EventProvider>().fetchEvents(
                      context.read<AuthProvider>().role,
                      context.read<AuthProvider>().username,
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Create Group'),
              ),
            ],
          ),
    );
  }

  String _getPostWorkflowStatus(List<Event> postTasks) {
    if (postTasks.isEmpty) return 'Inactive';

    final readyTask = postTasks.where((t) {
      final s = t.stage.trim().toLowerCase();
      return s == 'ready to post' || s == 'ready topost' || s == 'ready';
    }).firstOrNull;
    final isReadyDone = readyTask != null && readyTask.status.trim().toLowerCase() == 'done';

    final cleanTask = postTasks.where((t) {
      final s = t.stage.trim().toLowerCase();
      return s.contains('photos clean') || s.contains('photo clean') || s.contains('photosclean');
    }).firstOrNull;
    final isCleanDone = cleanTask != null && cleanTask.status.trim().toLowerCase() == 'done';

    if (isReadyDone && isCleanDone) {
      return 'Completed';
    }
    if (isReadyDone && !isCleanDone) {
      return 'Clean';
    }
    if (isReadyDone) {
      return 'Posted';
    }
    return 'Active';
  }

  Widget _buildWorkflowStatusBadge(String status) {
    Color bg;
    Color border;
    Color text;

    switch (status) {
      case 'Completed':
        bg = Colors.green.shade50;
        border = Colors.green.shade400;
        text = Colors.green.shade800;
        break;
      case 'Clean':
        bg = Colors.amber.shade50;
        border = Colors.amber.shade500;
        text = Colors.amber.shade900;
        break;
      case 'Posted':
        bg = Colors.teal.shade50;
        border = Colors.teal.shade400;
        text = Colors.teal.shade800;
        break;
      case 'Active':
        bg = Colors.blue.shade50;
        border = Colors.blue.shade400;
        text = Colors.blue.shade700;
        break;
      case 'Inactive':
      default:
        bg = Colors.orange.shade50;
        border = Colors.orange.shade300;
        text = Colors.orange.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  int? _combinedSortColumnIndex;
  bool _combinedSortAscending = true;

  void _combinedSort<T>(Comparable<T> Function(Map<String, dynamic> g) getField, int columnIndex, bool ascending) {
    setState(() {
      _combinedSortColumnIndex = columnIndex;
      _combinedSortAscending = ascending;
    });
  }

  int? _sortColumnIndex;
  bool _sortAscending = true;

  void _sort<T>(Comparable<T> Function(Map<String, dynamic> p) getField, int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  void _showPostLifecycle(Map<String, dynamic> post, EventProvider provider) {
    final postNo = post['PostNo']?.toString() ?? '';
    final postTasks = provider.events.where((t) => t.postNo == postNo).toList();
    final isInitialized = postTasks.isNotEmpty;
    final folderLink = post['FolderLink']?.toString() ?? '';
    final eventDate = post['Date']?.toString() ?? '';
    final theme = post['Theme']?.toString() ?? '';
    final branch = post['Branch']?.toString() ?? '';
    final guestType = post['GuestType']?.toString() ?? '';
    final guestName = post['GuestName']?.toString() ?? '';
    final guestDesignation = post['GuestDesignation']?.toString() ?? '';
    final guestOrg = post['GuestOrg']?.toString() ?? '';
    final hasGuest = guestName.isNotEmpty || guestOrg.isNotEmpty || guestType.isNotEmpty || guestDesignation.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Text('Post #${postNo}'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isInitialized ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isInitialized ? Colors.blue : Colors.orange),
                ),
                child: Text(
                  isInitialized ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isInitialized ? Colors.blue.shade800 : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (theme.isNotEmpty) ...[
                    Text('Theme: $theme', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                  ],
                  if (branch.isNotEmpty) ...[
                    Text('Branch: $branch', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                  ],
                  if (eventDate.isNotEmpty) ...[
                    Text('Event Date: $eventDate', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                  ],
                  if (hasGuest) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'अतिथि / वक्ता / प्रतिभागी सूची | List of Guest(s) / Speaker(s) / Participant(s)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                          ),
                          const SizedBox(height: 6),
                          if (guestType.isNotEmpty)
                            Text('• Type: $guestType', style: const TextStyle(fontSize: 12)),
                          if (guestName.isNotEmpty)
                            Text('• Name: $guestName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          if (guestDesignation.isNotEmpty)
                            Text('• Designation: $guestDesignation', style: const TextStyle(fontSize: 12)),
                          if (guestOrg.isNotEmpty)
                            Text('• Organization: $guestOrg', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 8),
                  if (folderLink.isNotEmpty) ...[
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder, color: Colors.blue),
                      title: const Text('Open Date Folder', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                      onTap: () {
                        html.window.open(folderLink, '_blank');
                      },
                    ),
                    const Divider(),
                  ],
                  if (!isInitialized) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Workflow has not been assigned yet. Click "Assign Workflow" below to assign users and setup deadlines.',
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text('Pipeline Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...postTasks.map((t) {
                      final isDone = t.status.trim().toLowerCase() == 'done';
                      final displayStatus = t.status == 'Ready' ? 'Allotted' : (t.status.isEmpty ? 'Pending' : t.status);
                      final assigneeInfo = t.assigneeName.isNotEmpty ? ' - ' + t.assigneeName : '';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isDone ? Icons.check_circle : Icons.pending_actions,
                          color: isDone ? Colors.green : Colors.orange,
                        ),
                        title: Text(t.stage),
                        subtitle: Text(displayStatus + assigneeInfo),
                        trailing: t.docLink.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.description, color: Colors.blue),
                                tooltip: 'Open ${t.stage} Doc',
                                onPressed: () {
                                  html.window.open(t.docLink, '_blank');
                                },
                              )
                            : null,
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (isInitialized)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                label: const Text('Delete Workflow', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDeletePostWorkflow(post, provider, context.read<AuthProvider>());
                },
              ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open in new tab'),
              onPressed: () {
                Navigator.pop(ctx);
                _openInNewTab('/admin-assign?postNo=$postNo');
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: Icon(isInitialized ? Icons.tune : Icons.add_task),
              label: Text(isInitialized ? 'Update Setup / Assignees' : 'Assign Workflow'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isInitialized ? Colors.blue : Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/admin-assign', extra: {
                  ...post,
                  'isInitialized': isInitialized,
                  'existingTasks': postTasks,
                });
              },
            ),
          ],
        );
      }
    );
  }

  void _confirmDeletePostWorkflow(Map<String, dynamic> post, EventProvider provider, AuthProvider auth) {
    final postNo = post['PostNo']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Workflow?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all workflow tasks for Post #$postNo?\n\nThis will remove all assigned tasks and convert the post back to Inactive.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.deleteWorkflow(
                postNo: postNo,
                isCombined: false,
                username: auth.username,
                role: auth.role,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Post #$postNo workflow deleted and marked Inactive.' : 'Failed to delete workflow.'),
                    backgroundColor: ok ? Colors.orange.shade800 : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete & Make Inactive'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCombinedWorkflow(Map<String, dynamic> group, EventProvider provider, AuthProvider auth) {
    final groupId = group['GroupID']?.toString() ?? '';
    final List<Map<String, dynamic>> posts = (group['Posts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Delete Combined Post?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete combined post "$groupId"?\n\nThis will delete all workflow tasks, ungroup the ${posts.length} events, and convert all of them back to Inactive.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.deleteWorkflow(
                postNo: groupId,
                isCombined: true,
                username: auth.username,
                role: auth.role,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Combined post $groupId deleted. Events are now Inactive.' : 'Failed to delete combined post.'),
                    backgroundColor: ok ? Colors.orange.shade800 : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete & Make Inactive'),
          ),
        ],
      ),
    );
  }

  void _showEditCombinedGroupDialog(Map<String, dynamic> group, EventProvider provider, AuthProvider auth) {
    final oldGroupId = group['GroupID']?.toString() ?? '';
    final List<Map<String, dynamic>> currentPosts = (group['Posts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final currentPostNos = currentPosts.map((p) => p['PostNo']?.toString() ?? '').where((n) => n.isNotEmpty).toSet();

    // Available unassigned posts or other posts that can be added to this group
    final availableIndividualPosts = provider.rawPosts.where((p) {
      final gId = p['GroupID']?.toString() ?? '';
      final pNo = p['PostNo']?.toString() ?? '';
      return gId.isEmpty && !currentPostNos.contains(pNo);
    }).toList();

    final nameController = TextEditingController(text: oldGroupId);
    final selectedToAdd = <String>{};
    final selectedToRemove = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final effectiveCount = currentPosts.length - selectedToRemove.length + selectedToAdd.length;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.tune, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text('Edit Combined Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Group Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name / ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                        helperText: 'You can change this name anytime',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Current Posts (Option to remove)
                    Row(
                      children: [
                        const Text('Current Posts in Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        Text(
                          '$effectiveCount post${effectiveCount == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: Colors.purple.shade700, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: currentPosts.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('No posts in this group.')))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: currentPosts.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final p = currentPosts[idx];
                                final pNo = p['PostNo']?.toString() ?? '';
                                final pTheme = p['Theme']?.toString() ?? '';
                                final pBranch = p['Branch']?.toString() ?? '';
                                final isMarkedForRemoval = selectedToRemove.contains(pNo);

                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    '#$pNo - $pTheme ($pBranch)',
                                    style: TextStyle(
                                      decoration: isMarkedForRemoval ? TextDecoration.lineThrough : null,
                                      color: isMarkedForRemoval ? Colors.red : null,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      isMarkedForRemoval ? Icons.undo : Icons.remove_circle_outline,
                                      color: isMarkedForRemoval ? Colors.green : Colors.red,
                                      size: 20,
                                    ),
                                    tooltip: isMarkedForRemoval ? 'Keep in group' : 'Remove from group',
                                    onPressed: () {
                                      setDialogState(() {
                                        if (isMarkedForRemoval) {
                                          selectedToRemove.remove(pNo);
                                        } else {
                                          selectedToRemove.add(pNo);
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Add More Individual Posts
                    const Text('Add More Posts to this Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: availableIndividualPosts.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('No available individual posts to add.', style: TextStyle(fontSize: 12, color: Colors.grey))))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: availableIndividualPosts.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final p = availableIndividualPosts[idx];
                                final pNo = p['PostNo']?.toString() ?? '';
                                final pTheme = p['Theme']?.toString() ?? '';
                                final pBranch = p['Branch']?.toString() ?? '';
                                final isSelected = selectedToAdd.contains(pNo);

                                return CheckboxListTile(
                                  dense: true,
                                  value: isSelected,
                                  title: Text('#$pNo - $pTheme ($pBranch)', style: const TextStyle(fontSize: 13)),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedToAdd.add(pNo);
                                      } else {
                                        selectedToAdd.remove(pNo);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) return;

                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);

                  // 1. Process removal of posts
                  for (final pNo in selectedToRemove) {
                    await provider.ungroupPost(pNo);
                  }

                  // 2. Process adding of new posts
                  if (selectedToAdd.isNotEmpty) {
                    await provider.groupPosts(selectedToAdd.toList(), oldGroupId);
                  }

                  // 3. Process renaming of group if changed
                  if (newName != oldGroupId) {
                    await provider.renameGroup(oldGroupId, newName);
                  }

                  // Refresh data
                  await provider.fetchEvents(auth.role, auth.username);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Combined group updated successfully!'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openInNewTab(String path) {
    try {
      final currentUri = Uri.parse(html.window.location.href);
      final newUrl = currentUri.replace(
        fragment: path,
        queryParameters: {},
      ).toString();
      html.window.open(newUrl, '_blank');
    } catch (_) {
      html.window.open('#$path', '_blank');
    }
  }

  void _showPostContextMenu(
    BuildContext context, 
    TapDownDetails details, 
    String postNo, {
    bool isCombined = false,
    Map<String, dynamic>? post,
    Map<String, dynamic>? group,
  }) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(40, 40),
      Offset.zero & overlay.size,
    );

    final provider = context.read<EventProvider>();
    final auth = context.read<AuthProvider>();
    final isInitialized = provider.events.any((t) => t.postNo == postNo);

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'open_new_tab',
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 18, color: Colors.blue),
              SizedBox(width: 10),
              Text('Open in new tab', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'edit_workflow',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
              SizedBox(width: 10),
              Text('Edit Workflow', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (isCombined)
          const PopupMenuItem<String>(
            value: 'edit_group',
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: Colors.purple),
                SizedBox(width: 10),
                Text('Edit Group (Add/Remove Posts)', style: TextStyle(fontSize: 13, color: Colors.purple)),
              ],
            ),
          ),
        if (isInitialized)
          const PopupMenuItem<String>(
            value: 'delete_workflow',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                SizedBox(width: 10),
                Text('Delete Workflow (Make Inactive)', style: TextStyle(fontSize: 13, color: Colors.red)),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == 'open_new_tab') {
        final combinedQuery = isCombined ? '&isCombined=true' : '';
        _openInNewTab('/admin-assign?postNo=$postNo$combinedQuery');
      } else if (value == 'edit_workflow') {
        if (isCombined && group != null) {
          final List<Map<String, dynamic>> posts = (group['Posts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          context.push('/admin-assign', extra: {
            'postNo': postNo,
            'isCombined': true,
            'isInitialized': isInitialized,
            'existingTasks': provider.events.where((t) => t.postNo == postNo).toList(),
            'combinedPosts': posts,
            if (posts.isNotEmpty) ...posts.first,
          });
        } else if (post != null) {
          context.push('/admin-assign', extra: {
            ...post,
            'isInitialized': isInitialized,
            'existingTasks': provider.events.where((t) => t.postNo == postNo).toList(),
          });
        } else {
          _openInNewTab('/admin-assign?postNo=$postNo');
        }
      } else if (value == 'edit_group') {
        if (isCombined && group != null) {
          _showEditCombinedGroupDialog(group, provider, auth);
        }
      } else if (value == 'delete_workflow') {
        if (isCombined && group != null) {
          _confirmDeleteCombinedWorkflow(group, provider, auth);
        } else if (post != null) {
          _confirmDeletePostWorkflow(post, provider, auth);
        } else {
          final foundPost = provider.rawPosts.firstWhere(
            (p) => p['PostNo']?.toString() == postNo,
            orElse: () => {'PostNo': postNo},
          );
          _confirmDeletePostWorkflow(foundPost, provider, auth);
        }
      }
    });
  }

  void _showCombinedLifecycle(Map<String, dynamic> group, EventProvider provider) {
    final groupId = group['GroupID']?.toString() ?? '';
    final List<Map<String, dynamic>> posts = (group['Posts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final postTasks = provider.events.where((t) => t.postNo == groupId).toList();
    final isInitialized = postTasks.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Text('Group: $groupId'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isInitialized ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isInitialized ? Colors.blue : Colors.orange),
                ),
                child: Text(
                  isInitialized ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isInitialized ? Colors.blue.shade800 : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Combined Events (${posts.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...posts.map((p) {
                    final pNo = p['PostNo']?.toString() ?? '';
                    final pTheme = p['Theme']?.toString() ?? '';
                    final pBranch = p['Branch']?.toString() ?? '';
                    final pLink = p['FolderLink']?.toString() ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Text('#$pNo', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$pTheme ($pBranch)',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pLink.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.folder, size: 18, color: Colors.blue),
                              tooltip: 'Open Date Folder',
                              onPressed: () => html.window.open(pLink, '_blank'),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(height: 24),
                  if (!isInitialized) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Combined workflow has not been assigned yet. Click "Assign Workflow" below to assign users.',
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text('Pipeline Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...postTasks.map((t) {
                      final isDone = t.status.trim().toLowerCase() == 'done';
                      final displayStatus = t.status == 'Ready' ? 'Allotted' : (t.status.isEmpty ? 'Pending' : t.status);
                      final assigneeInfo = t.assigneeName.isNotEmpty ? ' - ' + t.assigneeName : '';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isDone ? Icons.check_circle : Icons.pending_actions,
                          color: isDone ? Colors.green : Colors.orange,
                        ),
                        title: Text(t.stage),
                        subtitle: Text(displayStatus + assigneeInfo),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (isInitialized)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                label: const Text('Delete Combined Post', style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmDeleteCombinedWorkflow(group, provider, context.read<AuthProvider>());
                },
              ),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 18, color: Colors.purple),
              label: const Text('Edit Group (Posts & Name)', style: TextStyle(color: Colors.purple)),
              onPressed: () {
                Navigator.pop(ctx);
                _showEditCombinedGroupDialog(group, provider, context.read<AuthProvider>());
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open in new tab'),
              onPressed: () {
                Navigator.pop(ctx);
                _openInNewTab('/admin-assign?postNo=$groupId&isCombined=true');
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: Icon(isInitialized ? Icons.tune : Icons.add_task),
              label: Text(isInitialized ? 'Update Setup / Assignees' : 'Assign Workflow'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isInitialized ? Colors.blue : Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/admin-assign', extra: {
                  'postNo': groupId,
                  'isCombined': true,
                  'isInitialized': isInitialized,
                  'existingTasks': postTasks,
                  'combinedPosts': posts,
                  if (posts.isNotEmpty) ...posts.first,
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildResizableHeader(
    String title,
    String key,
    int colIndex,
    Comparable Function(Map<String, dynamic> p) getSortField,
  ) {
    final width = _colWidths[key] ?? _defaultColWidths[key] ?? 120.0;
    final isSorted = _sortColumnIndex == colIndex;

    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                final newAsc = _sortColumnIndex == colIndex ? !_sortAscending : true;
                _sort(getSortField, colIndex, newAsc);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSorted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: Colors.blue.shade700,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Draggable column resize handle
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  final cur = _colWidths[key] ?? _defaultColWidths[key] ?? 120.0;
                  _colWidths[key] = (cur + details.delta.dx).clamp(60.0, 700.0);
                });
              },
              onHorizontalDragEnd: (_) => _saveColumnWidths(),
              onDoubleTap: () {
                setState(() {
                  _colWidths[key] = _defaultColWidths[key] ?? 120.0;
                });
                _saveColumnWidths();
              },
              child: Tooltip(
                message: 'Drag to resize, double-click to reset',
                child: Container(
                  width: 14,
                  height: 32,
                  alignment: Alignment.center,
                  child: Container(
                    width: 2,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTable(List<Map<String, dynamic>> posts, EventProvider provider) {
    if (_sortColumnIndex != null) {
      posts.sort((a, b) {
        dynamic valA;
        dynamic valB;
        switch (_sortColumnIndex) {
          case 0: valA = a['PostNo']; valB = b['PostNo']; break;
          case 1: valA = a['ActivityType']; valB = b['ActivityType']; break;
          case 2: valA = a['Branch']; valB = b['Branch']; break;
          case 3: valA = a['Venue']; valB = b['Venue']; break;
          case 4: valA = a['Theme']; valB = b['Theme']; break;
          case 5: valA = a['Date']; valB = b['Date']; break;
          case 6: valA = a['TotalBeneficiary']; valB = b['TotalBeneficiary']; break;
        }
        if (_sortColumnIndex == 0) {
          final intA = int.tryParse(valA?.toString() ?? '') ?? 0;
          final intB = int.tryParse(valB?.toString() ?? '') ?? 0;
          return _sortAscending ? intA.compareTo(intB) : intB.compareTo(intA);
        }

        valA = valA?.toString() ?? '';
        valB = valB?.toString() ?? '';
        
        if (_sortColumnIndex == 6) {
          final intA = int.tryParse(valA) ?? 0;
          final intB = int.tryParse(valB) ?? 0;
          return _sortAscending ? intA.compareTo(intB) : intB.compareTo(intA);
        }
        return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _verticalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 10,
              radius: const Radius.circular(5),
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DataTable(
                    columnSpacing: 10,
                    horizontalMargin: 12,
                    headingRowHeight: 40,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 56,
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columns: [
                      DataColumn(
                        label: _buildResizableHeader(
                          'Post No',
                          'postNo',
                          0,
                          (p) => int.tryParse(p['PostNo']?.toString() ?? '') ?? 0,
                        ),
                      ),
                      DataColumn(
                        label: _buildResizableHeader(
                          'Activity Type',
                          'activityType',
                          1,
                          (p) => p['ActivityType'] ?? '',
                        ),
                      ),
                      DataColumn(
                        label: _buildResizableHeader(
                          'Branch',
                          'branch',
                          2,
                          (p) => p['Branch'] ?? '',
                        ),
                      ),
                      DataColumn(
                        label: _buildResizableHeader(
                          'Venue',
                          'venue',
                          3,
                          (p) => p['Venue'] ?? '',
                        ),
                      ),
                      DataColumn(
                        label: _buildResizableHeader(
                          'Theme',
                          'theme',
                          4,
                          (p) => p['Theme'] ?? '',
                        ),
                      ),
                      DataColumn(
                        label: _buildResizableHeader(
                          'Date',
                          'date',
                          5,
                          (p) => p['Date'] ?? '',
                        ),
                      ),
                      DataColumn(
                        label: _buildResizableHeader(
                          'Total Ben.',
                          'totalBen',
                          6,
                          (p) => int.tryParse(p['TotalBeneficiary']?.toString() ?? '0') ?? 0,
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: _colWidths['actions'] ?? _defaultColWidths['actions']!,
                          child: const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                    rows: posts.map((post) {
                      final postNo = post['PostNo']?.toString() ?? '';
                      final activityType = post['ActivityType']?.toString() ?? '';
                      final branch = post['Branch']?.toString() ?? '';
                      final venue = post['Venue']?.toString() ?? '';
                      final theme = post['Theme']?.toString() ?? '';
                      final date = post['Date']?.toString() ?? '';
                      final totalBen = post['TotalBeneficiary']?.toString() ?? '0';

                      final isSelected = _isSelectionMode && _selectedPosts.contains(postNo);
                      final postTasks = provider.events.where((t) => t.postNo == postNo).toList();
                      final isInitialized = postTasks.isNotEmpty;

                      return DataRow(
                        selected: isSelected,
                        onSelectChanged: _isSelectionMode
                            ? (selected) {
                                setState(() {
                                  if (selected == true) _selectedPosts.add(postNo);
                                  else _selectedPosts.remove(postNo);
                                });
                              }
                            : null,
                        cells: [
                          DataCell(
                            SizedBox(
                              width: _colWidths['postNo'] ?? _defaultColWidths['postNo']!,
                              child: InkWell(
                                onTap: () => _showPostLifecycle(post, provider),
                                onSecondaryTapDown: (details) => _showPostContextMenu(
                                  context, 
                                  details, 
                                  postNo, 
                                  post: post,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('#$postNo', style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Open in new tab',
                                      child: InkWell(
                                        onTap: () => _openInNewTab('/admin-assign?postNo=$postNo'),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(Icons.open_in_new, size: 13, color: Colors.blue.shade700),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildWorkflowStatusBadge(_getPostWorkflowStatus(postTasks)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: _colWidths['activityType'] ?? _defaultColWidths['activityType']!,
                              child: InkWell(
                                onTap: () => _showPostLifecycle(post, provider),
                                onSecondaryTapDown: (details) => _showPostContextMenu(context, details, postNo, post: post),
                                child: Text(activityType.isEmpty ? '—' : activityType, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: _colWidths['branch'] ?? _defaultColWidths['branch']!,
                              child: InkWell(
                                onTap: () => _showPostLifecycle(post, provider),
                                onSecondaryTapDown: (details) => _showPostContextMenu(context, details, postNo, post: post),
                                child: Text(branch, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: _colWidths['venue'] ?? _defaultColWidths['venue']!,
                              child: InkWell(
                                onTap: () => _showPostLifecycle(post, provider),
                                onSecondaryTapDown: (details) => _showPostContextMenu(context, details, postNo, post: post),
                                child: Text(venue, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: _colWidths['theme'] ?? _defaultColWidths['theme']!,
                              child: InkWell(
                                onTap: () => _showPostLifecycle(post, provider),
                                onSecondaryTapDown: (details) => _showPostContextMenu(context, details, postNo, post: post),
                                child: Text(theme, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: _colWidths['date'] ?? _defaultColWidths['date']!,
                              child: InkWell(
                                onTap: () => _showPostLifecycle(post, provider),
                                onSecondaryTapDown: (details) => _showPostContextMenu(context, details, postNo, post: post),
                                child: Text(date, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: _colWidths['totalBen'] ?? _defaultColWidths['totalBen']!,
                              child: InkWell(
                                onTap: () => _showPostLifecycle(post, provider),
                                onSecondaryTapDown: (details) => _showPostContextMenu(context, details, postNo, post: post),
                                child: Text(totalBen, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: _colWidths['actions'] ?? _defaultColWidths['actions']!,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.open_in_new, size: 16, color: Colors.blue.shade700),
                                    tooltip: 'Open in new tab',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () => _openInNewTab('/admin-assign?postNo=$postNo'),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, size: 18, color: Colors.blue.shade700),
                                    tooltip: 'Edit Workflow',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () {
                                      context.push('/admin-assign', extra: {
                                        ...post,
                                        'isInitialized': isInitialized,
                                        'existingTasks': postTasks,
                                      });
                                    },
                                  ),
                                  if (isInitialized) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                                      tooltip: 'Delete Workflow (Make Inactive)',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      onPressed: () => _confirmDeletePostWorkflow(post, provider, context.read<AuthProvider>()),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildCombinedPostsTable(List<Map<String, dynamic>> groups, EventProvider provider) {
    if (_combinedSortColumnIndex != null) {
      groups.sort((a, b) {
        dynamic valA;
        dynamic valB;
        final postsA = (a['Posts'] as List).cast<Map<String, dynamic>>();
        final postsB = (b['Posts'] as List).cast<Map<String, dynamic>>();
        final firstA = postsA.isNotEmpty ? postsA.first : <String, dynamic>{};
        final firstB = postsB.isNotEmpty ? postsB.first : <String, dynamic>{};

        switch (_combinedSortColumnIndex) {
          case 0: valA = a['GroupID']; valB = b['GroupID']; break;
          case 1: valA = postsA.length; valB = postsB.length; break;
          case 2: valA = firstA['Branch']; valB = firstB['Branch']; break;
          case 3: valA = firstA['Venue']; valB = firstB['Venue']; break;
          case 4: valA = firstA['Theme']; valB = firstB['Theme']; break;
          case 5: valA = firstA['Date']; valB = firstB['Date']; break;
          case 6:
            valA = postsA.fold<int>(0, (sum, p) => sum + (int.tryParse(p['TotalBeneficiary']?.toString() ?? '0') ?? 0));
            valB = postsB.fold<int>(0, (sum, p) => sum + (int.tryParse(p['TotalBeneficiary']?.toString() ?? '0') ?? 0));
            break;
        }
        valA = valA ?? '';
        valB = valB ?? '';

        if (_combinedSortColumnIndex == 1 || _combinedSortColumnIndex == 6) {
          final intA = valA is int ? valA : (int.tryParse(valA.toString()) ?? 0);
          final intB = valB is int ? valB : (int.tryParse(valB.toString()) ?? 0);
          return _combinedSortAscending ? intA.compareTo(intB) : intB.compareTo(intA);
        }
        return _combinedSortAscending ? valA.toString().compareTo(valB.toString()) : valB.toString().compareTo(valA.toString());
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 16,
                sortColumnIndex: _combinedSortColumnIndex,
                sortAscending: _combinedSortAscending,
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: [
                  DataColumn(
                    label: const Text('Group ID'),
                    onSort: (col, asc) => _combinedSort((g) => g['GroupID'] ?? '', col, asc),
                  ),
                  DataColumn(
                    label: const Text('Events'),
                    numeric: true,
                    onSort: (col, asc) => _combinedSort((g) => (g['Posts'] as List).length, col, asc),
                  ),
                  DataColumn(
                    label: const Text('Branch'),
                    onSort: (col, asc) => _combinedSort((g) => (g['Posts'] as List).first['Branch'] ?? '', col, asc),
                  ),
                  DataColumn(
                    label: const Text('Venue'),
                    onSort: (col, asc) => _combinedSort((g) => (g['Posts'] as List).first['Venue'] ?? '', col, asc),
                  ),
                  DataColumn(
                    label: const Text('Theme'),
                    onSort: (col, asc) => _combinedSort((g) => (g['Posts'] as List).first['Theme'] ?? '', col, asc),
                  ),
                  DataColumn(
                    label: const Text('Date'),
                    onSort: (col, asc) => _combinedSort((g) => (g['Posts'] as List).first['Date'] ?? '', col, asc),
                  ),
                  DataColumn(
                    label: const Text('Total Ben.', style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                    onSort: (col, asc) => _combinedSort((g) => 0, col, asc),
                  ),
                  const DataColumn(
                    label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
                rows: groups.map((group) {
                  final groupId = group['GroupID']?.toString() ?? '';
                  final List<Map<String, dynamic>> posts = (group['Posts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                  final firstPost = posts.isNotEmpty ? posts.first : <String, dynamic>{};
                  final branch = posts.map((p) => p['Branch']).where((b) => b != null && b.toString().isNotEmpty).toSet().join(', ');
                  final venue = posts.map((p) => p['Venue']).where((v) => v != null && v.toString().isNotEmpty).toSet().join(', ');
                  final theme = firstPost['Theme']?.toString() ?? '';
                  final date = firstPost['Date']?.toString() ?? '';
                  final totalBen = posts.fold<int>(0, (sum, p) => sum + (int.tryParse(p['TotalBeneficiary']?.toString() ?? '0') ?? 0));
                  final groupTasks = provider.events.where((t) => t.postNo == groupId).toList();
                  final isInitialized = groupTasks.isNotEmpty;
                  final groupStatus = _getPostWorkflowStatus(groupTasks);

                  return DataRow(
                    cells: [
                      DataCell(
                        InkWell(
                          onTap: () => _showCombinedLifecycle(group, provider),
                          onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(groupId, style: const TextStyle(color: Colors.purple, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Open in new tab',
                                child: InkWell(
                                  onTap: () => _openInNewTab('/admin-assign?postNo=$groupId&isCombined=true'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(Icons.open_in_new, size: 13, color: Colors.purple.shade700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildWorkflowStatusBadge(groupStatus),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Tooltip(
                          message: posts.map((p) => '#${p['PostNo']}').join(', '),
                          child: InkWell(
                            onTap: () => _showCombinedLifecycle(group, provider),
                            onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
                            child: Text('${posts.length} events (${posts.map((p) => '#${p['PostNo']}').take(2).join(', ')}${posts.length > 2 ? '...' : ''})'),
                          ),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => _showCombinedLifecycle(group, provider),
                          onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
                          child: Text(branch),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => _showCombinedLifecycle(group, provider),
                          onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(venue, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => _showCombinedLifecycle(group, provider),
                          onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(theme, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => _showCombinedLifecycle(group, provider),
                          onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
                          child: Text(date),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => _showCombinedLifecycle(group, provider),
                          onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
                          child: Text(totalBen.toString()),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.open_in_new, size: 16, color: Colors.purple.shade700),
                              tooltip: 'Open in new tab',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              onPressed: () => _openInNewTab('/admin-assign?postNo=$groupId&isCombined=true'),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 18, color: Colors.purple.shade700),
                              tooltip: 'Edit Combined Group',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              onPressed: () => _showEditCombinedGroupDialog(group, provider, context.read<AuthProvider>()),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(isInitialized ? Icons.tune : Icons.add_task, size: 18, color: Colors.blue.shade700),
                              tooltip: isInitialized ? 'Edit Workflow' : 'Assign Workflow',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              onPressed: () {
                                context.push(
                                  '/admin-assign',
                                  extra: {
                                    'postNo': groupId,
                                    'isCombined': true,
                                    'isInitialized': isInitialized,
                                    'existingTasks': groupTasks,
                                    'combinedPosts': posts,
                                    if (posts.isNotEmpty) ...posts.first,
                                  },
                                );
                              },
                            ),
                            if (isInitialized) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                                tooltip: 'Delete Combined Workflow (Make Inactive)',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                onPressed: () => _confirmDeleteCombinedWorkflow(group, provider, context.read<AuthProvider>()),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostCard(
    Map<String, dynamic> post,
    EventProvider provider,
    AuthProvider auth,
  ) {
    final postNo = post['PostNo']?.toString() ?? '';
    final theme = post['Theme']?.toString() ?? '';
    final date = post['Date']?.toString() ?? '';
    final branch = post['Branch']?.toString() ?? '';
    final state = post['State']?.toString() ?? '';
    final venue = post['Venue']?.toString() ?? '';
    final activityType = post['ActivityType']?.toString() ?? '';
    final male = post['Male'] ?? 0;
    final female = post['Female'] ?? 0;
    final children = post['Children'] ?? 0;
    final totalBen = post['TotalBeneficiary'] ?? 0;

    final postTasks = provider.events.where((t) => t.postNo == postNo).toList();
    final isInitialized = postTasks.isNotEmpty;

    // Workflow status indicators
    final dataUploaded = post['DataUploaded']?.toString() ?? '';
    final writingDone =
        postTasks.any((t) => t.stage == 'Writing' && t.status == 'Done')
            ? 'Yes'
            : (post['WritingDone']?.toString() ?? '');
    final editingDone =
        postTasks.any((t) => t.stage == 'Editing' && t.status == 'Done')
            ? 'Yes'
            : (post['EditingDone']?.toString() ?? '');
    final proofDone =
        postTasks.any((t) => t.stage == 'Proofreading' && t.status == 'Done')
            ? 'Yes'
            : (post['ProofReadingDone']?.toString() ?? '');
    final designDone =
        postTasks.any(
              (t) => t.stage.contains('Thumbnail') && t.status == 'Done',
            )
            ? 'Yes'
            : (post['DesignDone']?.toString() ?? '');
    final readyToPost =
        postTasks.any((t) => t.stage == 'Ready to Post' && t.status == 'Done')
            ? 'Yes'
            : (post['ReadyToBePosted']?.toString() ?? '');
    final posted = post['PostUploaded']?.toString() ?? '';

    final publishPlatform = post['PublishPlatform']?.toString() ?? '';
    final groupId = post['GroupID']?.toString() ?? '';
    final description = post['Description']?.toString() ?? '';

    // Find SPOC for branch
    final spocObj =
        provider.spocs.where((s) => s['branch'] == branch).firstOrNull;
    final spocName = spocObj?['spocName'] ?? 'No SPOC';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            _isSelectionMode && _selectedPosts.contains(postNo)
                ? BorderSide(
                  color: Theme.of(context).colorScheme.secondary,
                  width: 2,
                )
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (_selectedPosts.contains(postNo))
                _selectedPosts.remove(postNo);
              else
                _selectedPosts.add(postNo);
            });
          } else {
            _showPostLifecycle(post, provider);
          }
        },
        onSecondaryTapDown: (details) => _showPostContextMenu(context, details, postNo, post: post),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$postNo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildWorkflowStatusBadge(_getPostWorkflowStatus(postTasks)),
                  const SizedBox(width: 8),
                  if (publishPlatform.isNotEmpty)
                    Icon(
                      publishPlatform.toLowerCase() == 'instagram'
                          ? Icons.camera_alt
                          : Icons.chat,
                      size: 16,
                      color: Colors.pink,
                    ),
                  if (groupId.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Text(
                        groupId,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      theme,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.open_in_new, size: 18, color: Colors.blue.shade700),
                    tooltip: 'Open in new tab',
                    onPressed: () => _openInNewTab('/admin-assign?postNo=$postNo'),
                  ),
                  // Edit Workflow button
                  IconButton(
                    icon: Icon(
                      isInitialized ? Icons.edit_outlined : Icons.add_task_rounded,
                      color: isInitialized
                          ? Colors.blue.shade700
                          : Theme.of(context).colorScheme.secondary,
                    ),
                    tooltip: isInitialized
                        ? 'Edit Workflow & Assignees'
                        : 'Assign & Setup Workflow',
                    onPressed: () => context.push('/admin-assign', extra: {
                      ...post,
                      'isInitialized': isInitialized,
                      'existingTasks': postTasks,
                    }),
                  ),
                  if (isInitialized)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                      tooltip: 'Delete Workflow (Make Inactive)',
                      onPressed: () => _confirmDeletePostWorkflow(post, provider, auth),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (description.isNotEmpty) ...[
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _postDetail(Icons.calendar_today, date),
                  _postDetail(Icons.location_city, '$branch, $state'),
                  _postDetail(Icons.person_pin, spocName),
                  if (activityType.isNotEmpty)
                    _postDetail(Icons.category, activityType),
                ],
              ),
              if (venue.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        venue,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if ((post['GuestName']?.toString().isNotEmpty ?? false) ||
                  (post['GuestOrg']?.toString().isNotEmpty ?? false) ||
                  (post['GuestType']?.toString().isNotEmpty ?? false) ||
                  (post['GuestDesignation']?.toString().isNotEmpty ?? false)) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people_alt, size: 14, color: Colors.brown.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'अतिथि / वक्ता / प्रतिभागी: ' +
                              [
                                if (post['GuestType']?.toString().isNotEmpty ?? false) '${post['GuestType']}:',
                                if (post['GuestName']?.toString().isNotEmpty ?? false) post['GuestName'].toString(),
                                if (post['GuestDesignation']?.toString().isNotEmpty ?? false) '(${post['GuestDesignation']})',
                                if (post['GuestOrg']?.toString().isNotEmpty ?? false) '- ${post['GuestOrg']}',
                              ].join(' '),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.brown.shade800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Beneficiary row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _benStat('👨', 'Male', '$male'),
                    _benDivider(),
                    _benStat('👩', 'Female', '$female'),
                    _benDivider(),
                    _benStat('🧒', 'Children', '$children'),
                    _benDivider(),
                    _benStat('👥', 'Total', '$totalBen', bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Workflow status chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _statusChip('Data', dataUploaded),
                  _statusChip('Writing', writingDone),
                  _statusChip('Editing', editingDone),
                  _statusChip('Proof', proofDone),
                  _statusChip('Design', designDone),
                  _statusChip('Ready', readyToPost),
                  _statusChip('Posted', posted),
                ],
              ),

              if (post['FolderLink'] != null &&
                  post['FolderLink'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder, size: 14),
                  label: const Text(
                    'Open Raw Media Folder',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _launchUrl(post['FolderLink'].toString()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedCard(
    Map<String, dynamic> group,
    EventProvider provider,
    AuthProvider auth,
  ) {
    final groupId = group['GroupID'] as String;
    final List<Map<String, dynamic>> posts = group['Posts'];

    final postTasks =
        provider.events.where((t) => t.postNo == groupId).toList();
    final isInitialized = postTasks.isNotEmpty;

    // For media handling later, we will use the posts array.

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCombinedLifecycle(group, provider),
        onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade500,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      groupId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildWorkflowStatusBadge(_getPostWorkflowStatus(postTasks)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Combined Post (${posts.length} events)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.open_in_new, size: 18, color: Colors.purple.shade700),
                    tooltip: 'Open in new tab',
                    onPressed: () => _openInNewTab('/admin-assign?postNo=$groupId&isCombined=true'),
                  ),
                  IconButton(
                    icon: Icon(Icons.tune, size: 18, color: Colors.purple.shade700),
                    tooltip: 'Edit Group (Add/Remove Posts & Name)',
                    onPressed: () => _showEditCombinedGroupDialog(group, provider, auth),
                  ),
                  // Edit Combined Workflow button
                  IconButton(
                    icon: Icon(
                      isInitialized ? Icons.edit_outlined : Icons.add_task_rounded,
                      color: isInitialized
                          ? Colors.purple.shade700
                          : Theme.of(context).colorScheme.secondary,
                    ),
                    tooltip: isInitialized
                        ? 'Edit Combined Workflow'
                        : 'Assign & Setup Workflow',
                    onPressed: () {
                      context.push(
                        '/admin-assign',
                        extra: {
                          'postNo': groupId,
                          'isCombined': true,
                          'isInitialized': isInitialized,
                          'existingTasks': postTasks,
                          'combinedPosts': posts,
                          if (posts.isNotEmpty) ...posts.first,
                        },
                      );
                    },
                  ),
                  if (isInitialized)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                      tooltip: 'Delete Combined Post (Make Inactive)',
                      onPressed: () => _confirmDeleteCombinedWorkflow(group, provider, auth),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Show quick list of included posts
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    posts
                        .map(
                          (p) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '#${p['PostNo']} - ${p['Theme']}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              if (isInitialized) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _statusChip(
                      'Writing',
                      postTasks.any(
                            (t) => t.stage == 'Writing' && t.status == 'Done',
                          )
                          ? 'Yes'
                          : '',
                    ),
                    _statusChip(
                      'Editing',
                      postTasks.any(
                            (t) => t.stage == 'Editing' && t.status == 'Done',
                          )
                          ? 'Yes'
                          : '',
                    ),
                    _statusChip(
                      'Proof',
                      postTasks.any(
                            (t) =>
                                t.stage == 'Proofreading' && t.status == 'Done',
                          )
                          ? 'Yes'
                          : '',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Media Folders:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        posts.map((p) {
                          final folderUrl = p['FolderLink']?.toString() ?? '';
                          if (folderUrl.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.folder, size: 14),
                              label: Text(
                                '#${p['PostNo']} Raw',
                                style: const TextStyle(fontSize: 11),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                minimumSize: const Size(0, 30),
                              ),
                              onPressed: () => _launchUrl(folderUrl),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Widget _postDetail(IconData icon, String text) {
    if (text.isEmpty || text == ', ') return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _benStat(
    String emoji,
    String label,
    String value, {
    bool bold = false,
  }) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
            color: bold ? const Color(0xFF1A237E) : Colors.black87,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _benDivider() {
    return Container(width: 1, height: 30, color: Colors.grey.shade300);
  }

  Widget _statusChip(String label, String val) {
    final isDone =
        val.isNotEmpty &&
        val.toLowerCase() != 'false' &&
        val != '0' &&
        val != '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDone ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: isDone ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDone ? Colors.green.shade700 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ── USER BODY (My Queue) ──
  Widget _buildUserBody(EventProvider provider) {
    List<Event> visibleEvents =
        provider.events.where((e) => e.status.trim().toLowerCase() != 'waiting').toList();
    if (_myQueueFilter != 'All Tasks') {
      visibleEvents =
          visibleEvents.where((e) => e.status == _myQueueFilter).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Queue',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _myQueueFilter,
                items: const [
                  DropdownMenuItem(
                    value: 'All Tasks',
                    child: Text('All Tasks'),
                  ),
                  DropdownMenuItem(value: 'Ready', child: Text('Allotted Only')),
                  DropdownMenuItem(
                    value: 'In Progress',
                    child: Text('In Progress Only'),
                  ),
                  DropdownMenuItem(value: 'Done', child: Text('Done Only')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _myQueueFilter = val);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child:
              visibleEvents.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tasks found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    itemCount: visibleEvents.length,
                    itemBuilder: (context, index) {
                      final task = visibleEvents[index];
                      final stageColor =
                          task.stage == 'Writing'
                              ? const Color(0xFF42A5F5)
                              : task.stage == 'Editing'
                              ? const Color(0xFFFF8A65)
                              : task.stage == 'Proofreading'
                              ? const Color(0xFFAB47BC)
                              : const Color(0xFF26A69A);
                      return _buildTaskCard(task, stageColor);
                    },
                  ),
        ),
      ],
    );
  }
}
