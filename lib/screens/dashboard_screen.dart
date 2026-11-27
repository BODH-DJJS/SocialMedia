import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../models/event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dev_pipeline_screen.dart';
import '../utils/due_date_utils.dart';

class DashboardScreen extends StatefulWidget {
  final String? initialTab;
  final String? initialPipeline;
  const DashboardScreen({super.key, this.initialTab, this.initialPipeline});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _activePipelineIndex = 0; // 0: Social Media, 1: Development
  int _currentIndex = 0;
  String _postFilter = 'All';
  String _postTab = 'Overall'; // 'Overall', 'Individual' or 'Combined'
  Timer? _refreshTimer;
  Timer? _searchDebounce;
  int _postsPage = 0;
  int _postsPerPage = 50;
  final Set<String> _selectedPosts = {};
  bool _isSelectionMode = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _workflowSearchController = TextEditingController();
  String _myQueueFilter = 'All Tasks';

  static const String _colWidthsPrefPrefix = 'dashboard_col_width_';
  static const Map<String, double> _defaultColWidths = {
    'postNo': 160.0,
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

  String _getTabName(int index) {
    switch (index) {
      case 1: return 'posts';
      case 2: return 'pipeline';
      case 0:
      default: return 'tasks';
    }
  }

  void _switchPipeline(int index) async {
    setState(() => _activePipelineIndex = index);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_pipeline', index == 1 ? 'dev' : 'social');
    } catch (_) {}
    try {
      final tabName = _getTabName(_currentIndex);
      final pipelineName = index == 1 ? 'dev' : 'social';
      html.window.history.replaceState(null, '', '#/dashboard?pipeline=$pipelineName&tab=$tabName');
    } catch (_) {}
  }

  void _switchTab(int index) async {
    setState(() => _currentIndex = index);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_dashboard_tab', index);
    } catch (_) {}
    try {
      final tabName = _getTabName(index);
      final pipelineName = _activePipelineIndex == 1 ? 'dev' : 'social';
      html.window.history.replaceState(null, '', '#/dashboard?pipeline=$pipelineName&tab=$tabName');
    } catch (_) {}
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (widget.initialPipeline == null || widget.initialPipeline!.isEmpty) {
        final savedPipeline = prefs.getString('last_pipeline');
        if (savedPipeline == 'dev' && mounted) {
          setState(() => _activePipelineIndex = 1);
        }
      }
      if (widget.initialTab == null || widget.initialTab!.isEmpty) {
        final savedTab = prefs.getInt('last_dashboard_tab');
        if (savedTab != null && savedTab >= 0 && savedTab <= 2 && mounted) {
          setState(() => _currentIndex = savedTab);
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPipeline == 'dev') {
      _activePipelineIndex = 1;
    }
    if (widget.initialTab == 'pipeline' || widget.initialTab == 'kanban') {
      _currentIndex = 2;
    } else if (widget.initialTab == 'posts' || widget.initialTab == 'all') {
      _currentIndex = 1;
    } else if (widget.initialTab == 'tasks') {
      _currentIndex = 0;
    }
    _loadSavedState();
    _loadColumnWidths();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final provider = context.read<EventProvider>();
      // Silent refresh if data already present, otherwise normal fetch
      provider.fetchEvents(auth.role, auth.username, silent: provider.events.isNotEmpty);
      if (auth.role.toLowerCase() == 'admin') {
        if (provider.users.isEmpty) provider.fetchUsers();
        if (provider.spocs.isEmpty) provider.fetchBranchSPOCs();
      }
    });
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab != null) {
      if (widget.initialTab == 'pipeline' || widget.initialTab == 'kanban') {
        setState(() => _currentIndex = 2);
      } else if (widget.initialTab == 'posts' || widget.initialTab == 'all') {
        setState(() => _currentIndex = 1);
      } else if (widget.initialTab == 'tasks') {
        setState(() => _currentIndex = 0);
      }
    }
    if (widget.initialPipeline != oldWidget.initialPipeline && widget.initialPipeline != null) {
      setState(() => _activePipelineIndex = widget.initialPipeline == 'dev' ? 1 : 0);
    }
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
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _workflowSearchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activePipelineIndex == 1) {
      return DevPipelineScreen(
        onSwitchToSocialMedia: () => _switchPipeline(0),
      );
    }

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
            const SizedBox(width: 16),
            // Pipeline Switcher Pill
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _switchPipeline(0),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _activePipelineIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Social Media',
                        style: TextStyle(
                          color: _activePipelineIndex == 0 ? const Color(0xFF1E88E5) : Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: _activePipelineIndex == 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _switchPipeline(1),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _activePipelineIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Development',
                        style: TextStyle(
                          color: _activePipelineIndex == 1 ? const Color(0xFF1E88E5) : Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: _activePipelineIndex == 1 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
              child: SelectionContainer.disabled(
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
                onPressed: () async {
                  await eventProvider.invalidateCache();
                  await Future.wait([
                    eventProvider.fetchEvents(auth.role, auth.username, force: true),
                    eventProvider.fetchUsers(),
                  ]);
                },
              ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.assignment_outlined),
              tooltip: 'Daily WhatsApp Task Summary',
              onPressed: () => _showPendingTasksSummaryDialog(context, eventProvider),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () {
              context.read<EventProvider>().clear();
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
              : _buildUserBody(eventProvider, auth),
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
                    onDestinationSelected: (i) => _switchTab(i),
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

  Set<String> _getUnavailablePostNos(EventProvider provider) {
    final set = <String>{};
    for (final p in provider.rawPosts) {
      final st = (p['PostStatus'] ?? p['post_status'])?.toString().trim().toLowerCase();
      if (st == 'data unavailable' || st == 'dataunavailable' || st == 'inactive' || st == 'skip') {
        final pNo = (p['PostNo'] ?? p['post_no'])?.toString().trim();
        if (pNo != null && pNo.isNotEmpty) set.add(pNo);
        final gId = (p['GroupID'] ?? p['group_id'])?.toString().trim();
        if (gId != null && gId.isNotEmpty) set.add(gId);
      }
    }
    return set;
  }

  bool _isTaskUnavailable(Event e, Set<String> unavailablePostNos) {
    final cleanPNo = e.postNo.trim();
    if (unavailablePostNos.contains(cleanPNo)) return true;
    if (e.isCombined) {
      final extracted = RegExp(r'\b\d+\b').allMatches(cleanPNo).map((m) => m.group(0)!).toSet();
      if (extracted.isNotEmpty && extracted.every((no) => unavailablePostNos.contains(no))) {
        return true;
      }
    }
    return false;
  }

  // ── OVERVIEW / STATS ──
  Widget _buildOverview(EventProvider provider) {
    final unavail = _getUnavailablePostNos(provider);
    final activeEvents = provider.events.where((e) => !_isTaskUnavailable(e, unavail)).toList();
    final total = activeEvents.length;
    final done = activeEvents.where((e) => e.status == 'Done').length;
    final pending = total - done;
    final writing =
        activeEvents
            .where((e) => e.stage == 'Writing' && e.status != 'Done')
            .length;
    final editing =
        activeEvents
            .where((e) => e.stage == 'Editing' && e.status != 'Done')
            .length;
    final proofing =
        activeEvents
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
          const SizedBox(height: 16),

          // Daily WhatsApp Pending Tasks Summary Banner Card
          Card(
            color: const Color(0xFFE8F5E9),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.green.shade300, width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily WhatsApp Pending Tasks Summary',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B5E20)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'View section-wise pending tasks by user & copy instant formatted report for WhatsApp groups.',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showPendingTasksSummaryDialog(context, provider),
                    icon: const Icon(Icons.content_copy_rounded, size: 16),
                    label: const Text('Open & Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
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

  Map<String, Map<String, List<Event>>> _buildPendingSectionMap(List<Event> events) {
    final activePending = events.where((e) {
      final s = e.status.trim().toLowerCase();
      return s != 'done' && s != 'waiting';
    }).toList();

    final sections = <String, Map<String, List<Event>>>{
      '✍️ Writing': {},
      '📝 Editing': {},
      '🔍 Proofreading': {},
      '🔎 Text Crosscheck': {},
      '🖼️ Thumbnail Stages': {},
      '🎬 Media & Video Stages': {},
      '🚀 Ready to Post': {},
      '📌 Other Pending Stages': {},
    };

    for (final e in activePending) {
      final stage = e.stage.trim().toLowerCase();
      String sectionKey;
      if (stage == 'writing') {
        sectionKey = '✍️ Writing';
      } else if (stage == 'editing') {
        sectionKey = '📝 Editing';
      } else if (stage == 'proofreading') {
        sectionKey = '🔍 Proofreading';
      } else if (stage.contains('crosscheck') || stage.contains('cross check')) {
        if (stage.contains('media')) {
          sectionKey = '🎬 Media & Video Stages';
        } else if (stage.contains('thumb')) {
          sectionKey = '🖼️ Thumbnail Stages';
        } else {
          sectionKey = '🔎 Text Crosscheck';
        }
      } else if (stage.contains('thumb')) {
        sectionKey = '🖼️ Thumbnail Stages';
      } else if (stage.contains('photo') || stage.contains('video') || stage.contains('clean') || stage.contains('media')) {
        sectionKey = '🎬 Media & Video Stages';
      } else if (stage.contains('ready')) {
        sectionKey = '🚀 Ready to Post';
      } else {
        sectionKey = '📌 Other Pending Stages';
      }

      final userName = e.assigneeName.isNotEmpty ? e.assigneeName : (e.assignee.isNotEmpty ? e.assignee : 'Unassigned');
      sections[sectionKey]!.putIfAbsent(userName, () => []).add(e);
    }

    sections.removeWhere((key, val) => val.isEmpty);
    return sections;
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  String _generateWhatsAppReport(Map<String, Map<String, List<Event>>> sectionMap, int totalPending) {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    final buffer = StringBuffer();
    buffer.writeln('Jmjk🙏\n');
    buffer.writeln('📊 *BODH Social Media - Daily Pending Tasks Report*');
    buffer.writeln('📅 _Date: ${dateStr}_\n');

    sectionMap.forEach((sectionTitle, userMap) {
      if (userMap.isEmpty) return;
      int sectionTotal = userMap.values.fold(0, (sum, list) => sum + list.length);
      buffer.writeln('*$sectionTitle* (Total: $sectionTotal)');
      userMap.forEach((userName, events) {
        final postNos = events.map((e) => '#${e.postNo}').toSet().join(', ');
        buffer.writeln('• *$userName* (${events.length} task${events.length > 1 ? 's' : ''}): $postNos');
      });
      buffer.writeln('');
    });

    buffer.writeln('────────────────────');
    buffer.writeln('📌 *Total Active Tasks Pending:* $totalPending');
    buffer.writeln('🙏 _Please update your respective tasks at the earliest._');
    return buffer.toString();
  }

  String _generateSectionWhatsApp(String sectionTitle, Map<String, List<Event>> userMap) {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    final buffer = StringBuffer();
    int sectionTotal = userMap.values.fold(0, (sum, list) => sum + list.length);
    buffer.writeln('Jmjk🙏\n');
    buffer.writeln('*$sectionTitle* (Total: $sectionTotal) - $dateStr\n');
    userMap.forEach((userName, events) {
      final postNos = events.map((e) => '#${e.postNo}').toSet().join(', ');
      buffer.writeln('• *$userName* (${events.length} task${events.length > 1 ? 's' : ''}): $postNos');
    });
    buffer.writeln('\n🙏 _Please complete your respective tasks at the earliest._');
    return buffer.toString();
  }

  String _generateMultiSectionWhatsApp(
    Map<String, Map<String, List<Event>>> sectionMap,
    Set<String> selectedSections,
  ) {
    final now = DateTime.now();
    final dateStr = '${now.day} ${_monthName(now.month)} ${now.year}';
    final buffer = StringBuffer();
    buffer.writeln('Jmjk🙏\n');

    sectionMap.forEach((sectionTitle, userMap) {
      if (!selectedSections.contains(sectionTitle) || userMap.isEmpty) return;
      int sectionTotal = userMap.values.fold(0, (sum, list) => sum + list.length);
      buffer.writeln('*$sectionTitle* (Total: $sectionTotal) - $dateStr\n');
      userMap.forEach((userName, events) {
        final postNos = events.map((e) => '#${e.postNo}').toSet().join(', ');
        buffer.writeln('• *$userName* (${events.length} task${events.length > 1 ? 's' : ''}): $postNos');
      });
      buffer.writeln('');
    });

    buffer.writeln('🙏 _Please complete your respective tasks at the earliest._');
    return buffer.toString();
  }

  void _showPendingTasksSummaryDialog(BuildContext context, EventProvider provider) {
    final sectionMap = _buildPendingSectionMap(provider.events);
    int totalPending = 0;
    sectionMap.forEach((_, userMap) {
      userMap.forEach((_, list) => totalPending += list.length);
    });

    final selectedSections = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment_outlined, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Daily Pending Tasks Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: totalPending > 0 ? Colors.orange.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalPending Pending',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: totalPending > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: sectionMap.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      '🎉 All active tasks are completed!\nNo pending tasks at the moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Select one or more sections to copy together, or copy an individual section.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                if (selectedSections.length == sectionMap.length) {
                                  selectedSections.clear();
                                } else {
                                  selectedSections.addAll(sectionMap.keys);
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: Text(
                              selectedSections.length == sectionMap.length ? 'Clear All' : 'Select All',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...sectionMap.entries.map((entry) {
                        final sectionTitle = entry.key;
                        final userMap = entry.value;
                        final secCount = userMap.values.fold(0, (sum, list) => sum + list.length);
                        final isSelected = selectedSections.contains(sectionTitle);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          elevation: 0.5,
                          color: isSelected ? Colors.green.shade50.withOpacity(0.5) : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: const Color(0xFF2E7D32),
                                      visualDensity: VisualDensity.compact,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            selectedSections.add(sectionTitle);
                                          } else {
                                            selectedSections.remove(sectionTitle);
                                          }
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            if (isSelected) {
                                              selectedSections.remove(sectionTitle);
                                            } else {
                                              selectedSections.add(sectionTitle);
                                            }
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            Text(
                                              sectionTitle,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.blue.shade200),
                                              ),
                                              child: Text(
                                                '$secCount',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        final secText = _generateSectionWhatsApp(sectionTitle, userMap);
                                        Clipboard.setData(ClipboardData(text: secText));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('📋 Copied $sectionTitle to clipboard!'),
                                            duration: const Duration(seconds: 2),
                                            backgroundColor: const Color(0xFF2E7D32),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy, size: 14),
                                      label: const Text('Copy Section', style: TextStyle(fontSize: 11)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF2E7D32),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                ...userMap.entries.map((uEntry) {
                                  final uName = uEntry.key;
                                  final uEvents = uEntry.value;
                                  final postNos = uEvents.map((e) => '#${e.postNo}').toSet().toList();

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.indigo.shade50,
                                          child: Text(
                                            uName.isNotEmpty ? uName[0].toUpperCase() : '?',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    uName,
                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '${uEvents.length} pending',
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 4,
                                                children: postNos.map((p) => Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                  ),
                                                  child: Text(
                                                    p,
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                                                  ),
                                                )).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (selectedSections.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                final text = _generateMultiSectionWhatsApp(sectionMap, selectedSections);
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📋 Copied ${selectedSections.length} selected section(s) to clipboard!'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                );
              },
              icon: const Icon(Icons.checklist_rounded, size: 16),
              label: Text('Copy Selected (${selectedSections.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          if (sectionMap.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                final fullReport = _generateWhatsAppReport(sectionMap, totalPending);
                Clipboard.setData(ClipboardData(text: fullReport));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📋 Entire report copied to clipboard! Ready to paste into WhatsApp.'),
                    duration: Duration(seconds: 3),
                    backgroundColor: Color(0xFF2E7D32),
                  ),
                );
              },
              icon: const Icon(Icons.share, size: 16),
              label: const Text('📋 Copy Full Report for WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
        ),
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
    final unavail = _getUnavailablePostNos(provider);
    final wQuery = _workflowSearchController.text.trim().toLowerCase();
    final filteredEvents = provider.events.where((e) {
      if (e.status == 'Done') return false;
      if (_isTaskUnavailable(e, unavail)) return false;
      if (wQuery.isEmpty) return true;
      return e.postNo.toLowerCase().contains(wQuery) || e.branch.toLowerCase().contains(wQuery);
    }).toList();

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

        // Sort in ascending order of due date (earliest & expired first, undated last)
        notStarted.sort((a, b) => compareDueDates(
          a.dueDate,
          b.dueDate,
          secondaryCompare: () {
            if (a.status == 'Ready' && b.status != 'Ready') return -1;
            if (a.status != 'Ready' && b.status == 'Ready') return 1;
            final numA = int.tryParse(a.postNo.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final numB = int.tryParse(b.postNo.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return numA.compareTo(numB);
          },
        ));

        doneList.sort((a, b) => compareDueDates(
          a.dueDate,
          b.dueDate,
          secondaryCompare: () {
            final numA = int.tryParse(a.postNo.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final numB = int.tryParse(b.postNo.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return numA.compareTo(numB);
          },
        ));

        final expiredCount = notStarted.where((t) => isDueDateExpired(t.dueDate, isDone: false)).length;

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
                    if (expiredCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$expiredCount Expired',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
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
    final isExpired = isDueDateExpired(task.dueDate, isDone: isDone);
    final hasRevision = task.hasRevisionRemarks && !isDone;
    final combinedQuery = task.isCombined ? '&isCombined=true' : '';
    final taskUrl = '/event?postNo=${Uri.encodeComponent(task.postNo)}&stage=${Uri.encodeComponent(task.stage)}&taskId=${Uri.encodeComponent(task.taskId)}$combinedQuery';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDone ? 0 : (isExpired ? 3 : (hasRevision ? 3 : 2)),
      color: isDone
          ? Colors.grey.shade100
          : (isExpired ? const Color(0xFFFFEBEE) : (hasRevision ? const Color(0xFFFFFDF5) : Colors.white)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isExpired
              ? Colors.red.shade400
              : (hasRevision ? Colors.orange.shade300 : Colors.grey.shade200),
          width: isExpired ? 1.5 : (hasRevision ? 1.2 : 1),
        ),
      ),
      child: Listener(
        onPointerDown: (event) {
          // Middle mouse button (wheel click)
          if (event.buttons == 4) {
            _openInNewTab(taskUrl);
          }
        },
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Guard: If the open_in_new button was clicked within the last 600ms, do not navigate!
            if (DateTime.now().difference(_lastNewTabClick).inMilliseconds < 600) {
              return;
            }
            // Check for Ctrl (Windows/Linux) or Meta/Cmd (Mac)
            final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed;
            if (isCtrlOrMeta) {
              _openInNewTab(taskUrl);
            } else {
              context.push(taskUrl, extra: task);
            }
          },
          onSecondaryTapDown: (details) => _showPipelineTaskContextMenu(context, details, task),
          child: Container(
            decoration: BoxDecoration(
              color: isDone
                  ? Colors.grey.shade100
                  : (isExpired ? const Color(0xFFFFEBEE) : (hasRevision ? const Color(0xFFFFFDF5) : Colors.white)),
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(
                  color: isExpired
                      ? Colors.red.shade700
                      : (hasRevision ? Colors.deepOrange.shade700 : accentColor),
                  width: isExpired ? 6 : (hasRevision ? 5 : 4),
                ),
                top: isExpired
                    ? BorderSide(color: Colors.red.shade300, width: 1.5)
                    : (hasRevision ? BorderSide(color: Colors.orange.shade200, width: 1) : BorderSide.none),
                right: isExpired
                    ? BorderSide(color: Colors.red.shade300, width: 1.5)
                    : (hasRevision ? BorderSide(color: Colors.orange.shade200, width: 1) : BorderSide.none),
                bottom: isExpired
                    ? BorderSide(color: Colors.red.shade300, width: 1.5)
                    : (hasRevision ? BorderSide(color: Colors.orange.shade200, width: 1) : BorderSide.none),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              (task.isCombined || task.postNo.toLowerCase().startsWith('combined'))
                                  ? task.postNo
                                  : 'Post ${task.postNo}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDone ? Colors.grey : const Color(0xFF1A1A2E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Tooltip(
                            message: 'Open in background tab (Ctrl+Click)',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () {
                                _lastNewTabClick = DateTime.now();
                                _openInNewTab(taskUrl);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✓ ${(task.isCombined || task.postNo.toLowerCase().startsWith('combined')) ? task.postNo : 'Post #${task.postNo}'} opened in background tab'),
                                      duration: const Duration(milliseconds: 1500),
                                      behavior: SnackBarBehavior.floating,
                                      width: 280,
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.open_in_new, size: 14, color: Colors.blue.shade700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isExpired) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 10, color: Colors.white),
                          SizedBox(width: 2),
                          Text(
                            'EXPIRED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (hasRevision) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.replay_rounded, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'REVISION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                                      ? const Color(0xFFFBC02D)
                                      : Colors.grey.shade400)),
                      borderRadius: BorderRadius.circular(8),
                      border: task.status == 'Ready' ? Border.all(color: const Color(0xFFF57F17), width: 1) : null,
                    ),
                    child: Text(
                      task.status.isEmpty ? 'Pending' : (task.status == 'Ready' ? 'Allotted' : task.status),
                      style: TextStyle(
                        color: task.status == 'Ready' ? const Color(0xFF3E2723) : Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (task.theme.isNotEmpty && task.theme.trim() != task.postNo.trim())
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
              if (task.notes.trim().isNotEmpty && !isDone) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasRevision ? Colors.orange.shade400 : Colors.amber.shade300,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasRevision ? Icons.assignment_return_rounded : Icons.comment_rounded,
                            size: 12,
                            color: Colors.deepOrange.shade800,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hasRevision
                                  ? 'Sent Back by ${task.latestRevisionSender.isNotEmpty ? task.latestRevisionSender : "Reviewer"}:'
                                  : 'Notes / Remarks:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        task.latestRevisionCleanRemark,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3E2723),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isExpired ? Colors.red.shade600 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isExpired ? Colors.red.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isExpired ? Icons.alarm_off : Icons.timer,
                            size: 11,
                            color: isExpired ? Colors.white : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            (isExpired ? 'Expired: ' : 'Due ') + formatDueDateDisplay(task.dueDate),
                            style: TextStyle(
                              fontSize: 10,
                              color: isExpired ? Colors.white : Colors.grey.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ── ALL POSTS ──
  Widget _buildAllPosts(EventProvider provider, AuthProvider auth) {
    final filters = ['All', 'Active', 'Inactive', 'Posted', 'Clean', 'Completed', 'Later', 'Skip', 'Data Unavailable'];

    // Pre-index tasks by postNo / groupId for O(1) instant lookup
    final Map<String, List<Event>> tasksByPostNo = {};
    for (final t in provider.events) {
      if (t.postNo.isNotEmpty) {
        tasksByPostNo.putIfAbsent(t.postNo, () => []).add(t);
      }
    }

    final searchQuery = _searchController.text.trim().toLowerCase();

    List<Map<String, dynamic>> rawFiltered =
        provider.rawPosts.where((post) {
          final postNo = post['PostNo']?.toString().toLowerCase() ?? '';
          final branch = post['Branch']?.toString().toLowerCase() ?? '';
          final groupId = post['GroupID']?.toString().toLowerCase() ?? '';
          final theme = post['Theme']?.toString().toLowerCase() ?? '';
          final venue = post['Venue']?.toString().toLowerCase() ?? '';

          // Search text filter by Post No, Branch, GroupID, Theme, or Venue
          if (searchQuery.isNotEmpty && 
              !postNo.contains(searchQuery) && 
              !branch.contains(searchQuery) &&
              !groupId.contains(searchQuery) &&
              !theme.contains(searchQuery) &&
              !venue.contains(searchQuery)) {
            return false;
          }

          final rawPostNo = post['PostNo']?.toString() ?? '';
          final rawGroupId = post['GroupID']?.toString() ?? '';

          List<Event> postTasks = tasksByPostNo[rawPostNo] ?? [];
          if (postTasks.isEmpty && rawGroupId.isNotEmpty) {
            postTasks = tasksByPostNo[rawGroupId] ?? [];
          }

          final customPostStatus = post['PostStatus']?.toString().trim() ?? '';
          final postStatus = _getPostWorkflowStatus(postTasks, postStatus: customPostStatus);

          if (_postFilter == 'All') return true;

          if (_postFilter == 'Later') {
            return postStatus == 'Later';
          }
          if (_postFilter == 'Skip') {
            return postStatus == 'Skip';
          }
          if (_postFilter == 'Data Unavailable') {
            return postStatus == 'Data Unavailable';
          }
          if (_postFilter == 'Inactive') {
            return postStatus == 'Inactive' || 
                   postStatus == 'Data Unavailable' || 
                   postStatus == 'Later' || 
                   postStatus == 'Skip';
          }
          if (_postFilter == 'Active') {
            return postStatus == 'Active';
          }
          if (_postFilter == 'Posted') {
            return postStatus == 'Posted' || postStatus == 'Completed';
          }
          if (_postFilter == 'Clean') {
            // Clean mns Photos Clean pending: Ready is done, but Photos Clean is not done yet
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
            return isReadyDone && !isCleanDone;
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
    } else if (_postTab == 'Combined') {
      final groups = <String, List<Map<String, dynamic>>>{};
      for (var p in rawFiltered) {
        final g = p['GroupID']?.toString() ?? '';
        if (g.isNotEmpty) {
          groups.putIfAbsent(g, () => []).add(p);
        }
      }
      for (var entry in groups.entries) {
        entry.value.sort(comparePostNumbers);
        combinedGroups.add({'GroupID': entry.key, 'Posts': entry.value});
      }
    } else {
      // 'Overall' shows all individual posts AND all posts belonging to combined groups
      tabFiltered = rawFiltered;
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
                ButtonSegment(value: 'Overall', label: Text('Overall')),
                ButtonSegment(value: 'Individual', label: Text('Individual')),
                ButtonSegment(value: 'Combined', label: Text('Combined')),
              ],
              selected: {_postTab},
              onSelectionChanged: (val) {
                setState(() {
                  _postTab = val.first;
                  _postsPage = 0;
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
            child: SelectionContainer.disabled(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search by Post No, Branch, Group ID, or Theme...',
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
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _postsPage = 0;
                            });
                          },
                        )
                        : null,
              ),
              onChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 200), () {
                  if (mounted) {
                    setState(() {
                      _postsPage = 0;
                    });
                  }
                });
              },
              ),
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
                              _postsPage = 0;
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
                  _postTab == 'Combined'
                      ? '${combinedGroups.length} combined groups'
                      : '${tabFiltered.length} posts',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                if (_postTab == 'Individual' || _postTab == 'Overall') ...[
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
                _postTab == 'Combined'
                    ? (combinedGroups.isEmpty
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
                                        tasksByPostNo: tasksByPostNo,
                                      ),
                                );
                              }
                              return _buildCombinedPostsTable(combinedGroups, provider, tasksByPostNo: tasksByPostNo);
                            },
                          ))
                    : (tabFiltered.isEmpty
                        ? Center(
                          child: Text(_postTab == 'Overall' ? 'No posts found.' : 'No individual posts found.'),
                        )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 800) {
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: tabFiltered.length,
                                  itemBuilder: (context, index) => _buildPostCard(tabFiltered[index], provider, auth, tasksByPostNo: tasksByPostNo),
                                );
                              }
                              return _buildPostsTable(tabFiltered, provider, tasksByPostNo: tasksByPostNo);
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

    for (final pNo in selectedList) {
      final lockedStage = _getModificationLockStage(pNo, provider);
      if (lockedStage != null) {
        _showModificationLockedPopup('Post #$pNo', lockedStage);
        return;
      }
      final hasIndivTasks = provider.events.any((t) => t.postNo.trim() == pNo);
      if (hasIndivTasks) {
        _showDuplicateAssignmentPopup(
          'Duplicate Assignment Blocked',
          'Post #$pNo already has an active Individual workflow.\n\nPlease delete its Individual workflow first before combining it into a group.',
        );
        return;
      }
      final existingGroup = provider.rawPosts
          .where((p) => (p['PostNo'] ?? p['post_no'])?.toString().trim() == pNo)
          .map((p) => (p['GroupID'] ?? p['group_id'])?.toString().trim() ?? '')
          .firstWhere((g) => g.isNotEmpty, orElse: () => '');
      if (existingGroup.isNotEmpty) {
        _showDuplicateAssignmentPopup(
          'Already in Combined Group',
          'Post #$pNo is already part of "$existingGroup".\n\nRemove it from that group first before creating a new group.',
        );
        return;
      }
    }

    // Auto-generate default name: format Combined_Post(373, 374) or Combined Post(45, 56, 78) - branch name not required
    final defaultGroupName = 'Combined_Post(${selectedList.join(', ')})';
    final ctrl = TextEditingController(text: defaultGroupName);

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Group / Combine Posts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Name this combined post. Format should be Combined_Post(...) or Combined Post(...). Branch name is not required.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Combined Post Name / ID',
                    hintText: 'e.g., Combined_Post(373, 374) or Combined Post(45, 56, 78)',
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

  String _getPostWorkflowStatus(List<Event> postTasks, {String postStatus = ''}) {
    final trimmedStatus = postStatus.trim().toLowerCase();
    if (trimmedStatus == 'inactive') return 'Inactive';
    if (trimmedStatus == 'posted') return 'Posted';
    if (trimmedStatus == 'later') return 'Later';
    if (trimmedStatus == 'skip') return 'Skip';
    if (trimmedStatus == 'data unavailable' || trimmedStatus == 'dataunavailable') return 'Data Unavailable';

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
      case 'Later':
        bg = Colors.purple.shade50;
        border = Colors.purple.shade300;
        text = Colors.purple.shade700;
        break;
      case 'Skip':
        bg = Colors.grey.shade100;
        border = Colors.grey.shade400;
        text = Colors.grey.shade700;
        break;
      case 'Data Unavailable':
        bg = Colors.red.shade50;
        border = Colors.red.shade300;
        text = Colors.red.shade800;
        break;
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

  void _showEditPostBeneficiariesDialog(Map<String, dynamic> post, EventProvider provider) {
    final auth = context.read<AuthProvider>();
    if (auth.role.toLowerCase() != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only administrators are authorized to edit beneficiaries.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final postNo = post['PostNo']?.toString() ?? '';
    final venue = post['Venue']?.toString() ?? '';
    final date = post['Date']?.toString() ?? '';
    final state = post['State']?.toString() ?? '';
    final branch = post['Branch']?.toString() ?? '';

    final initialMale = int.tryParse(post['Male']?.toString() ?? '0') ?? 0;
    final initialFemale = int.tryParse(post['Female']?.toString() ?? '0') ?? 0;
    final initialChildren = int.tryParse(post['Children']?.toString() ?? '0') ?? 0;

    final maleController = TextEditingController(text: initialMale.toString());
    final femaleController = TextEditingController(text: initialFemale.toString());
    final childrenController = TextEditingController(text: initialChildren.toString());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSaving = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            int m = int.tryParse(maleController.text.trim()) ?? 0;
            int f = int.tryParse(femaleController.text.trim()) ?? 0;
            int c = int.tryParse(childrenController.text.trim()) ?? 0;
            int total = m + f + c;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Beneficiaries', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text(
                          'Post #$postNo ${venue.isNotEmpty ? '• $venue' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This update will be permanently written to the source Google Sheet (BODH Responses tab).',
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            errorMessage!,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: maleController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'पुरुष / Male',
                          prefixIcon: const Icon(Icons.man, color: Color(0xFF42A5F5)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: femaleController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'महिलाएं / Female',
                          prefixIcon: const Icon(Icons.woman, color: Color(0xFFE91E63)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: childrenController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'बच्चे / Children',
                          prefixIcon: const Icon(Icons.child_care, color: Color(0xFFFF9800)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'कुल लाभार्थी / Total Beneficiaries:',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              '$total',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          final result = await provider.updateBeneficiaries(
                            postNo: postNo,
                            state: state,
                            branch: branch,
                            venue: venue,
                            date: date,
                            prevMale: initialMale,
                            prevFemale: initialFemale,
                            prevChildren: initialChildren,
                            male: m,
                            female: f,
                            children: c,
                            subPost: post,
                          );

                          if (result['success'] == true) {
                            if (mounted) {
                              setState(() {});
                            }
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ?? 'Beneficiaries updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = result['message'] ?? 'Failed to update beneficiaries.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCombinedBeneficiariesDialog(Map<String, dynamic> group, EventProvider provider) {
    final auth = context.read<AuthProvider>();
    if (auth.role.toLowerCase() != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only administrators are authorized to edit beneficiaries.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final List<Map<String, dynamic>> posts = (group['Posts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    if (posts.isEmpty) return;
    if (posts.length == 1) {
      _showEditPostBeneficiariesDialog(posts.first, provider);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people, color: Colors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Event to Edit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      'Combined Group #${group['GroupID'] ?? ''} (${posts.length} events)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: posts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final p = posts[idx];
                final pNo = p['PostNo']?.toString() ?? '';
                final theme = p['Theme']?.toString() ?? p['Program']?.toString() ?? '';
                final venue = p['Venue']?.toString() ?? '';
                final date = p['Date']?.toString() ?? '';
                final male = p['Male'] ?? 0;
                final female = p['Female'] ?? 0;
                final children = p['Children'] ?? 0;
                final total = p['TotalBeneficiary'] ?? 0;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  title: Text('#$pNo - $theme', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (venue.isNotEmpty) Text('📍 $venue', style: const TextStyle(fontSize: 11)),
                      if (date.isNotEmpty) Text('📅 $date', style: const TextStyle(fontSize: 11)),
                      Text('👨 $male  👩 $female  🧒 $children  👥 Total: $total', style: TextStyle(fontSize: 11, color: Colors.indigo.shade700, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showEditPostBeneficiariesDialog(p, provider);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPostLifecycle(Map<String, dynamic> post, EventProvider provider) {
    final postNo = post['PostNo']?.toString() ?? '';
    final groupId = post['GroupID']?.toString() ?? '';
    var postTasks = provider.events.where((t) => t.postNo == postNo).toList();
    if (postTasks.isEmpty && groupId.isNotEmpty) {
      postTasks = provider.events.where((t) => t.postNo == groupId).toList();
    }
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
              Expanded(
                child: Text(
                  groupId.isNotEmpty ? 'Post #$postNo ($groupId)' : 'Post #$postNo',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
                        title: Row(
                          children: [
                            Text(t.stage),
                            if (t.hasRevisionRemarks && !isDone) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'REVISION',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayStatus + assigneeInfo),
                            if (t.notes.trim().isNotEmpty && !isDone) ...[
                              const SizedBox(height: 3),
                              Text(
                                '💬 Remarks: ${t.latestRevisionCleanRemark}',
                                style: TextStyle(
                                  color: Colors.deepOrange.shade900,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
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
                final adminUrl = '/admin-assign?postNo=${Uri.encodeComponent(postNo)}';
                context.push(adminUrl, extra: {
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
    final postNo = (post['PostNo'] ?? post['post_no'])?.toString() ?? '';
    final groupId = (post['GroupID'] ?? post['group_id'])?.toString().trim() ?? '';

    if (groupId.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.call_split_rounded, color: Colors.purple.shade700, size: 26),
              const SizedBox(width: 8),
              Text('Post #$postNo is in Group'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Post #$postNo is part of combined group:\n"$groupId"',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.link_off, size: 16),
                  label: Text('Remove #$postNo from Group'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple.shade700,
                    side: BorderSide(color: Colors.purple.shade300),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await provider.ungroupPost(postNo);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Post #$postNo removed from "$groupId". It is now an individual post.'
                              : 'Failed to remove post from group.'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: const Text('Delete Group Workflow'),
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
                          content: Text(ok
                              ? 'Combined post "$groupId" deleted and all posts unlinked.'
                              : 'Failed to delete combined workflow.'),
                          backgroundColor: ok ? Colors.orange.shade800 : Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 26),
            const SizedBox(width: 8),
            Text('Manage Post #$postNo Workflow'),
          ],
        ),
        content: Text(
          'Post #$postNo currently has active workflow tasks.\n\n'
          'If media is not available or you want to remove its tasks, select an option:',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.block, size: 16),
                label: const Text('Mark Data Unavailable & Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade900,
                  side: BorderSide(color: Colors.orange.shade400),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await provider.deleteWorkflow(
                    postNo: postNo,
                    isCombined: false,
                    newPostStatus: 'Data Unavailable',
                    username: auth.username,
                    role: auth.role,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Post #$postNo workflow deleted and marked Data Unavailable.'
                            : 'Failed to delete workflow.'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('Delete & Make Inactive'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await provider.deleteWorkflow(
                    postNo: postNo,
                    isCombined: false,
                    newPostStatus: 'Inactive',
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
              ),
            ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 26),
            const SizedBox(width: 8),
            const Text('Manage Combined Workflow'),
          ],
        ),
        content: Text(
          'Combined post "$groupId" contains ${posts.length} grouped events.\n\n'
          'If media is not available or you want to remove this workflow, select an option:\n\n'
          '• Data Unavailable: Deletes all workflow tasks, ungroups posts, and marks all posts as "Data Unavailable".\n'
          '• Make Inactive: Deletes all workflow tasks, ungroups posts, and marks all posts as "Inactive".',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.block, size: 16),
                label: const Text('Mark Data Unavailable & Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade900,
                  side: BorderSide(color: Colors.orange.shade400),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await provider.deleteWorkflow(
                    postNo: groupId,
                    isCombined: true,
                    newPostStatus: 'Data Unavailable',
                    username: auth.username,
                    role: auth.role,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? 'Combined post "$groupId" workflow deleted and marked Data Unavailable.'
                            : 'Failed to delete combined workflow.'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('Delete & Make Inactive'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await provider.deleteWorkflow(
                    postNo: groupId,
                    isCombined: true,
                    newPostStatus: 'Inactive',
                    username: auth.username,
                    role: auth.role,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Combined post "$groupId" deleted. Events are now Inactive.' : 'Failed to delete combined post.'),
                        backgroundColor: ok ? Colors.orange.shade800 : Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Checks if a post or combined group has already reached Proofreading, Media Cross Check, or any later stage.
  /// Returns the reached stage name if locked, or null if still modifiable.
  String? _getModificationLockStage(String postOrGroupId, EventProvider provider) {
    final tasks = provider.events.where((t) => t.postNo.trim() == postOrGroupId.trim()).toList();
    if (tasks.isEmpty) return null;

    const lockedStages = {
      'proofreading',
      'mediacrosscheck',
      'textcrosscheck',
      'crosscheck',
      'mediafinalcrosscheck',
      'mediafinalcrosschecking',
      'readytopost',
      'photosclean',
    };

    for (final t in tasks) {
      final stgNorm = t.stage.trim().toLowerCase().replaceAll(' ', '');
      final statusNorm = t.status.trim().toLowerCase();
      if (lockedStages.contains(stgNorm) && statusNorm.isNotEmpty && statusNorm != 'waiting') {
        return t.stage;
      }
    }
    return null;
  }

  void _showModificationLockedPopup(String postOrGroupId, String reachedStage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.orange.shade800, size: 26),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Cannot Modify Post',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          '"$postOrGroupId" has already reached the "$reachedStage" stage.\n\n'
          'Once a post reaches Proofreading or Media Cross Check, it cannot be modified or have new posts added to it.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateAssignmentPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.content_copy_rounded, color: Colors.red.shade700, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditCombinedGroupDialog(Map<String, dynamic> group, EventProvider provider, AuthProvider auth) {
    final oldGroupId = group['GroupID']?.toString() ?? '';
    final lockedStage = _getModificationLockStage(oldGroupId, provider);
    if (lockedStage != null) {
      _showModificationLockedPopup(oldGroupId, lockedStage);
      return;
    }

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
                    Row(
                      children: [
                        const Text('Combined Post Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        TextButton.icon(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                          icon: const Icon(Icons.auto_fix_high, size: 14),
                          label: const Text('Auto-format: Combined_Post(...)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            final activeNos = currentPosts
                                .map((p) => p['PostNo']?.toString() ?? '')
                                .where((n) => n.isNotEmpty && !selectedToRemove.contains(n))
                                .toSet()
                              ..addAll(selectedToAdd);
                            final sortedNos = activeNos.toList()
                              ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
                            nameController.text = 'Combined_Post(${sortedNos.join(', ')})';
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Combined Post Name / ID',
                        hintText: 'e.g., Combined_Post(373, 374) or Combined Post(45, 56, 78)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                        helperText: 'Format: Combined_Post(373, 374) or Combined Post(45, 56, 78). Branch name not required.',
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

                  for (final pNo in selectedToAdd) {
                    final addLock = _getModificationLockStage(pNo, provider);
                    if (addLock != null) {
                      Navigator.pop(ctx);
                      _showModificationLockedPopup('Post #$pNo', addLock);
                      return;
                    }
                    final hasIndivTasks = provider.events.any((t) => t.postNo.trim() == pNo);
                    if (hasIndivTasks) {
                      Navigator.pop(ctx);
                      _showDuplicateAssignmentPopup(
                        'Duplicate Assignment Blocked',
                        'Post #$pNo already has an active Individual workflow.\n\nPlease delete its Individual workflow first before adding it to this combined group.',
                      );
                      return;
                    }
                  }

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

  DateTime _lastNewTabClick = DateTime.fromMillisecondsSinceEpoch(0);

  void _openInNewTab(String path) {
    _lastNewTabClick = DateTime.now();
    try {
      final currentUri = Uri.parse(html.window.location.href);
      final newUrl = currentUri.replace(
        fragment: path,
        queryParameters: {},
      ).toString();

      final isMac = html.window.navigator.platform?.toUpperCase().contains('MAC') ?? false;

      // 1. Create a native anchor element attached to DOM
      final anchor = html.AnchorElement(href: newUrl)
        ..target = '_blank'
        ..rel = 'noopener noreferrer'
        ..style.display = 'none';
      html.document.body?.append(anchor);

      // 2. Dispatch simulated Ctrl+Click (or Cmd+Click on Mac) so the browser opens it in a background tab
      final mouseEvent = html.MouseEvent(
        'click',
        canBubble: true,
        cancelable: true,
        view: html.window,
        ctrlKey: !isMac,
        metaKey: isMac,
      );

      final dispatched = anchor.dispatchEvent(mouseEvent);
      anchor.remove();

      // Fallback if browser blocked the synthetic event
      if (!dispatched) {
        html.window.open(newUrl, '_blank');
      }
    } catch (_) {
      html.window.open('#$path', '_blank');
    }
  }

  void _showPipelineTaskContextMenu(
    BuildContext context,
    TapDownDetails details,
    Event task,
  ) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(40, 40),
      Offset.zero & overlay.size,
    );

    final combinedQuery = task.isCombined ? '&isCombined=true' : '';
    final taskUrl = '/event?postNo=${Uri.encodeComponent(task.postNo)}&stage=${Uri.encodeComponent(task.stage)}&taskId=${Uri.encodeComponent(task.taskId)}$combinedQuery';
    final workflowUrl = '/admin-assign?postNo=${Uri.encodeComponent(task.postNo)}$combinedQuery';

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'open_task_new_tab',
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 18, color: Colors.blue),
              SizedBox(width: 10),
              Text('Open Task in new tab', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'open_workflow_new_tab',
          child: Row(
            children: [
              Icon(Icons.assignment_outlined, size: 18, color: Colors.purple),
              SizedBox(width: 10),
              Text('Open Workflow in new tab', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'open_current_tab',
          child: Row(
            children: [
              Icon(Icons.touch_app_outlined, size: 18, color: Colors.black87),
              SizedBox(width: 10),
              Text('Open in current screen', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete_workflow',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('Delete Workflow / Data Unavailable', style: TextStyle(fontSize: 13, color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'open_task_new_tab') {
        _openInNewTab(taskUrl);
      } else if (value == 'open_workflow_new_tab') {
        _openInNewTab(workflowUrl);
      } else if (value == 'open_current_tab') {
        context.push(taskUrl, extra: task);
      } else if (value == 'delete_workflow') {
        final provider = context.read<EventProvider>();
        final auth = context.read<AuthProvider>();
        if (task.isCombined) {
          final group = {
            'GroupID': task.postNo,
            'Posts': provider.rawPosts.where((p) => (p['GroupID'] ?? p['group_id'])?.toString() == task.postNo).toList(),
          };
          _confirmDeleteCombinedWorkflow(group, provider, auth);
        } else {
          final post = provider.rawPosts.firstWhere(
            (p) => (p['PostNo'] ?? p['post_no'])?.toString() == task.postNo,
            orElse: () => {'PostNo': task.postNo},
          );
          _confirmDeletePostWorkflow(post, provider, auth);
        }
      }
    });
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
        if (auth.role.toLowerCase() == 'admin')
          const PopupMenuItem<String>(
            value: 'edit_beneficiaries',
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined, size: 18, color: Colors.indigo),
                SizedBox(width: 10),
                Text('Edit Beneficiaries', style: TextStyle(fontSize: 13, color: Colors.indigo)),
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
      } else if (value == 'edit_beneficiaries') {
        if (isCombined && group != null) {
          _showEditCombinedBeneficiariesDialog(group, provider);
        } else if (post != null) {
          _showEditPostBeneficiariesDialog(post, provider);
        } else {
          final foundPost = provider.rawPosts.firstWhere(
            (p) => p['PostNo']?.toString() == postNo,
            orElse: () => {'PostNo': postNo},
          );
          _showEditPostBeneficiariesDialog(foundPost, provider);
        }
      } else if (value == 'edit_workflow') {
        if (isCombined && group != null) {
          final List<Map<String, dynamic>> posts = (group['Posts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          final adminUrl = '/admin-assign?postNo=${Uri.encodeComponent(postNo)}&isCombined=true';
          context.push(adminUrl, extra: {
            'postNo': postNo,
            'isCombined': true,
            'isInitialized': isInitialized,
            'existingTasks': provider.events.where((t) => t.postNo == postNo).toList(),
            'combinedPosts': posts,
            if (posts.isNotEmpty) ...posts.first,
          });
        } else if (post != null) {
          final adminUrl = '/admin-assign?postNo=${Uri.encodeComponent(postNo)}';
          context.push(adminUrl, extra: {
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
                        title: Row(
                          children: [
                            Text(t.stage),
                            if (t.hasRevisionRemarks && !isDone) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'REVISION',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayStatus + assigneeInfo),
                            if (t.notes.trim().isNotEmpty && !isDone) ...[
                              const SizedBox(height: 3),
                              Text(
                                '💬 Remarks: ${t.latestRevisionCleanRemark}',
                                style: TextStyle(
                                  color: Colors.deepOrange.shade900,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
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
                final adminUrl = '/admin-assign?postNo=${Uri.encodeComponent(groupId)}&isCombined=true';
                context.push(adminUrl, extra: {
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

  Widget _buildPostsTable(List<Map<String, dynamic>> posts, EventProvider provider, {Map<String, List<Event>>? tasksByPostNo}) {
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

    final totalPosts = posts.length;
    final maxPage = totalPosts == 0 ? 0 : (totalPosts - 1) ~/ _postsPerPage;
    if (_postsPage > maxPage) {
      _postsPage = maxPage;
    }
    final startIndex = _postsPage * _postsPerPage;
    final endIndex = (startIndex + _postsPerPage < totalPosts) ? startIndex + _postsPerPage : totalPosts;
    final pagedPosts = totalPosts == 0 ? <Map<String, dynamic>>[] : posts.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
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
                    rows: pagedPosts.map((post) {
                      final auth = context.read<AuthProvider>();
                      final isAdmin = auth.role.toLowerCase() == 'admin';
                      final postNo = post['PostNo']?.toString() ?? '';
                      final groupId = post['GroupID']?.toString().trim() ?? '';
                      final activityType = post['ActivityType']?.toString() ?? '';
                      final branch = post['Branch']?.toString() ?? '';
                      final venue = post['Venue']?.toString() ?? '';
                      final theme = post['Theme']?.toString() ?? '';
                      final date = post['Date']?.toString() ?? '';
                      final totalBen = post['TotalBeneficiary']?.toString() ?? '0';

                      final isSelected = _isSelectionMode && _selectedPosts.contains(postNo);
                      List<Event> postTasks = tasksByPostNo?[postNo] ?? [];
                      if (postTasks.isEmpty && groupId.isNotEmpty) {
                        postTasks = tasksByPostNo?[groupId] ?? [];
                      }
                      if (postTasks.isEmpty) {
                        postTasks = provider.events.where((t) => t.postNo == postNo || (groupId.isNotEmpty && t.postNo == groupId)).toList();
                      }
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _showPostLifecycle(post, provider),
                                        onSecondaryTapDown: (details) => _showPostContextMenu(
                                          context, 
                                          details, 
                                          postNo, 
                                          post: post,
                                        ),
                                        child: Text(
                                          '#$postNo', 
                                          style: const TextStyle(
                                            color: Colors.blue, 
                                            decoration: TextDecoration.underline, 
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message: 'Open in new tab',
                                        child: InkWell(
                                          onTap: () => _openInNewTab('/admin-assign?postNo=${groupId.isNotEmpty ? groupId : postNo}'),
                                          child: Padding(
                                            padding: const EdgeInsets.all(2),
                                            child: Icon(Icons.open_in_new, size: 13, color: Colors.blue.shade700),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => _showPostLifecycle(post, provider),
                                        child: _buildWorkflowStatusBadge(_getPostWorkflowStatus(postTasks, postStatus: post['PostStatus']?.toString() ?? '')),
                                      ),
                                    ],
                                  ),
                                  if (groupId.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Tooltip(
                                      message: 'Group: $groupId',
                                      child: InkWell(
                                        onTap: () => _openInNewTab('/admin-assign?postNo=$groupId'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.indigo.shade200, width: 0.8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.link, size: 10, color: Colors.indigo.shade700),
                                              const SizedBox(width: 3),
                                              ConstrainedBox(
                                                constraints: BoxConstraints(maxWidth: (_colWidths['postNo'] ?? 160.0) - 25),
                                                child: Text(
                                                  groupId,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.indigo.shade800,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
                                onTap: () {
                                  if (isAdmin) {
                                    _showEditPostBeneficiariesDialog(post, provider);
                                  } else {
                                    _showPostLifecycle(post, provider);
                                  }
                                },
                                onSecondaryTapDown: (details) => _showPostContextMenu(context, details, postNo, post: post),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(child: Text(totalBen, overflow: TextOverflow.ellipsis)),
                                    if (isAdmin) ...[
                                      const SizedBox(width: 2),
                                      Icon(Icons.edit, size: 12, color: Colors.indigo.shade400),
                                    ],
                                  ],
                                ),
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
                                    onPressed: () => _openInNewTab('/admin-assign?postNo=${groupId.isNotEmpty ? groupId : postNo}'),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, size: 18, color: Colors.blue.shade700),
                                    tooltip: 'Edit Workflow',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    onPressed: () {
                                      final targetPostNo = groupId.isNotEmpty ? groupId : postNo;
                                      final adminUrl = '/admin-assign?postNo=${Uri.encodeComponent(targetPostNo)}';
                                      context.push(adminUrl, extra: {
                                        ...post,
                                        'isInitialized': isInitialized,
                                        'existingTasks': postTasks,
                                      });
                                    },
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.people_alt_outlined, size: 18, color: Colors.indigo.shade700),
                                      tooltip: 'Edit Beneficiaries',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      onPressed: () => _showEditPostBeneficiariesDialog(post, provider),
                                    ),
                                  ],
                                  if (isInitialized || groupId.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                                      tooltip: groupId.isNotEmpty ? 'Manage Group / Delete' : 'Delete Workflow (Make Inactive)',
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
    ),
  ),
  _buildPaginationControls(totalPosts, startIndex, endIndex, maxPage),
],
);
  }

  Widget _buildPaginationControls(int totalPosts, int startIndex, int endIndex, int maxPage) {
    if (totalPosts == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Showing ${startIndex + 1}–$endIndex of $totalPosts posts',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              Text('Rows per page:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: _postsPerPage,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                  DropdownMenuItem(value: 200, child: Text('200')),
                ],
                onChanged: (val) {
                  if (val != null && val != _postsPerPage) {
                    setState(() {
                      _postsPerPage = val;
                      _postsPage = 0;
                    });
                  }
                },
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                tooltip: 'First Page',
                onPressed: _postsPage > 0
                    ? () => setState(() => _postsPage = 0)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Previous Page',
                onPressed: _postsPage > 0
                    ? () => setState(() => _postsPage--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Page ${_postsPage + 1} of ${maxPage + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Next Page',
                onPressed: _postsPage < maxPage
                    ? () => setState(() => _postsPage++)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                tooltip: 'Last Page',
                onPressed: _postsPage < maxPage
                    ? () => setState(() => _postsPage = maxPage)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildCombinedPostsTable(List<Map<String, dynamic>> groups, EventProvider provider, {Map<String, List<Event>>? tasksByPostNo}) {
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
                  final auth = context.read<AuthProvider>();
                  final isAdmin = auth.role.toLowerCase() == 'admin';
                  final groupId = group['GroupID']?.toString() ?? '';
                  final List<Map<String, dynamic>> posts = (group['Posts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
                  final firstPost = posts.isNotEmpty ? posts.first : <String, dynamic>{};
                  final branch = posts.map((p) => p['Branch']).where((b) => b != null && b.toString().isNotEmpty).toSet().join(', ');
                  final venue = posts.map((p) => p['Venue']).where((v) => v != null && v.toString().isNotEmpty).toSet().join(', ');
                  final theme = firstPost['Theme']?.toString() ?? '';
                  final date = firstPost['Date']?.toString() ?? '';
                  final totalBen = posts.fold<int>(0, (sum, p) => sum + (int.tryParse(p['TotalBeneficiary']?.toString() ?? '0') ?? 0));
                  final groupTasks = tasksByPostNo?[groupId] ?? provider.events.where((t) => t.postNo == groupId).toList();
                  final isInitialized = groupTasks.isNotEmpty;
                  final groupStatus = _getPostWorkflowStatus(groupTasks, postStatus: firstPost['PostStatus']?.toString() ?? '');

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _showCombinedLifecycle(group, provider),
                              onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
                              child: Text(groupId, style: const TextStyle(color: Colors.purple, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                            ),
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
                            InkWell(
                              onTap: () => _showCombinedLifecycle(group, provider),
                              child: _buildWorkflowStatusBadge(groupStatus),
                            ),
                          ],
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
                          onTap: () {
                            if (isAdmin) {
                              _showEditCombinedBeneficiariesDialog(group, provider);
                            } else {
                              _showCombinedLifecycle(group, provider);
                            }
                          },
                          onSecondaryTapDown: (details) => _showPostContextMenu(context, details, groupId, isCombined: true, group: group),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(totalBen.toString()),
                              if (isAdmin) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.edit, size: 12, color: Colors.purple.shade400),
                              ],
                            ],
                          ),
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
                                final adminUrl = '/admin-assign?postNo=${Uri.encodeComponent(groupId)}&isCombined=true';
                                context.push(
                                  adminUrl,
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
                            if (isAdmin) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.people_alt_outlined, size: 18, color: Colors.purple.shade700),
                                tooltip: 'Edit Beneficiaries',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                onPressed: () => _showEditCombinedBeneficiariesDialog(group, provider),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                                tooltip: 'Delete Combined Group / Workflow',
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
    AuthProvider auth, {
    Map<String, List<Event>>? tasksByPostNo,
  }) {
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

    final postTasks = tasksByPostNo?[postNo] ?? provider.events.where((t) => t.postNo == postNo).toList();
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
                  _buildWorkflowStatusBadge(_getPostWorkflowStatus(postTasks, postStatus: post['PostStatus']?.toString() ?? '')),
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
                    onPressed: () {
                      final adminUrl = '/admin-assign?postNo=${Uri.encodeComponent(postNo)}';
                      context.push(adminUrl, extra: {
                        ...post,
                        'isInitialized': isInitialized,
                        'existingTasks': postTasks,
                      });
                    },
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
                child: Column(
                  children: [
                    Row(
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
                    if (auth.role.toLowerCase() == 'admin') ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () {
                            _showEditPostBeneficiariesDialog(post, provider);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 12, color: Colors.indigo),
                                SizedBox(width: 4),
                                Text('Edit Beneficiaries', style: TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
    AuthProvider auth, {
    Map<String, List<Event>>? tasksByPostNo,
  }) {
    final groupId = group['GroupID'] as String;
    final List<Map<String, dynamic>> posts = group['Posts'];

    final postTasks =
        tasksByPostNo?[groupId] ?? provider.events.where((t) => t.postNo == groupId).toList();
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
                  _buildWorkflowStatusBadge(_getPostWorkflowStatus(postTasks, postStatus: posts.isNotEmpty ? (posts.first['PostStatus']?.toString() ?? '') : '')),
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
                      final adminUrl = '/admin-assign?postNo=${Uri.encodeComponent(groupId)}&isCombined=true';
                      context.push(
                        adminUrl,
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
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                    tooltip: 'Delete Combined Post (Ungroup / Make Inactive)',
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
  Widget _buildUserBody(EventProvider provider, AuthProvider auth) {
    final myEmail = auth.username.trim().toLowerCase();

    // Match any display name associated with this user in user directories
    String myDisplayName = '';
    for (final u in provider.users) {
      final uEmail = (u['email'] ?? u['Email'] ?? u['username'])?.toString().trim().toLowerCase();
      if (uEmail == myEmail) {
        myDisplayName = (u['name'] ?? u['Name'])?.toString().trim().toLowerCase() ?? '';
        break;
      }
    }
    if (myDisplayName.isEmpty) {
      for (final u in provider.devUsers) {
        final uEmail = (u['email'] ?? u['Email'] ?? u['username'])?.toString().trim().toLowerCase();
        if (uEmail == myEmail) {
          myDisplayName = (u['name'] ?? u['Name'])?.toString().trim().toLowerCase() ?? '';
          break;
        }
      }
    }

    final unavail = _getUnavailablePostNos(provider);
    List<Event> visibleEvents = provider.events.where((e) {
      if (e.status.trim().toLowerCase() == 'waiting') return false;
      if (_isTaskUnavailable(e, unavail)) return false;
      final ass = e.assignee.trim().toLowerCase();
      final assName = e.assigneeName.trim().toLowerCase();

      final matchesEmail = myEmail.isNotEmpty && (ass == myEmail || assName == myEmail || ass.contains(myEmail));
      final matchesName = myDisplayName.isNotEmpty && (ass == myDisplayName || assName == myDisplayName);
      return matchesEmail || matchesName;
    }).toList();

    if (_myQueueFilter != 'All Tasks') {
      visibleEvents =
          visibleEvents.where((e) => e.status == _myQueueFilter).toList();
    }

    // Sort in ascending order of due date (earliest & expired first, undated last)
    visibleEvents.sort((a, b) => compareDueDates(
      a.dueDate,
      b.dueDate,
      secondaryCompare: () {
        if (a.status == 'Ready' && b.status != 'Ready') return -1;
        if (a.status != 'Ready' && b.status == 'Ready') return 1;
        final numA = int.tryParse(a.postNo.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final numB = int.tryParse(b.postNo.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return numA.compareTo(numB);
      },
    ));

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
