import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/event_provider.dart';
import '../models/event.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _postFilter = 'All';
  String _postTab = 'Individual'; // 'Individual' or 'Combined'
  Timer? _refreshTimer;
  final Set<String> _selectedPosts = {};
  bool _isSelectionMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _globalTaskFilter = 'All Tasks';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final provider = context.read<EventProvider>();
      provider.fetchEvents(auth.role, auth.username);
      if (auth.role.toLowerCase() == 'admin') {
        provider.fetchUsers();
        provider.fetchBranchSPOCs();
      }
      
      // Auto-refresh every 30 seconds silently
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          provider.fetchEvents(auth.role, auth.username, silent: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
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
        bottom: eventProvider.isSyncing
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
          if (!isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                label: Text(auth.role, style: const TextStyle(color: Colors.white, fontSize: 11)),
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
                  onPressed: () => eventProvider.fetchEvents(auth.role, auth.username),
                ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Filter Tasks: $_globalTaskFilter',
            onSelected: (val) => setState(() => _globalTaskFilter = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All Tasks', child: Text('All Tasks')),
              const PopupMenuItem(value: 'Ready', child: Text('Ready Only')),
              const PopupMenuItem(value: 'Waiting', child: Text('Waiting Only')),
              const PopupMenuItem(value: 'In Progress', child: Text('In Progress Only')),
            ],
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
      body: eventProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : isAdmin
              ? _buildAdminBody(eventProvider, auth)
              : _buildUserBody(eventProvider),
      bottomNavigationBar: isAdmin
          ? NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              backgroundColor: theme.colorScheme.primary,
              indicatorColor: theme.colorScheme.secondary.withOpacity(0.3),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined, color: Colors.white60),
                  selectedIcon: Icon(Icons.space_dashboard, color: Colors.white),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.view_kanban_outlined, color: Colors.white60),
                  selectedIcon: Icon(Icons.view_kanban, color: Colors.white),
                  label: 'Pipeline',
                ),
                NavigationDestination(
                  icon: Icon(Icons.list_alt_outlined, color: Colors.white60),
                  selectedIcon: Icon(Icons.list_alt, color: Colors.white),
                  label: 'All Posts',
                ),
              ],
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
        return _buildKanbanBoard(provider);
      case 2:
        return _buildAllPosts(provider, auth);
      default:
        return _buildOverview(provider);
    }
  }

  // ── OVERVIEW / STATS ──
  Widget _buildOverview(EventProvider provider) {
    final total = provider.events.length;
    final done = provider.events.where((e) => e.status == 'Done').length;
    final pending = total - done;
    final writing = provider.events.where((e) => e.stage == 'Writing' && e.status != 'Done').length;
    final editing = provider.events.where((e) => e.stage == 'Editing' && e.status != 'Done').length;
    final proofing = provider.events.where((e) => e.stage == 'Proofreading' && e.status != 'Done').length;

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
              Expanded(child: _statCard('Total Events', '${provider.rawPosts.length}', Icons.event_note, const Color(0xFF1A237E))),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Active Tasks', '$pending', Icons.pending_actions, const Color(0xFFFF6F00))),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Completed', '$done', Icons.check_circle, const Color(0xFF00897B))),
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
                  const Text('Pipeline Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  _pipelineBar('Writing', writing, total, const Color(0xFF42A5F5)),
                  const SizedBox(height: 12),
                  _pipelineBar('Editing', editing, total, const Color(0xFFFF8A65)),
                  const SizedBox(height: 12),
                  _pipelineBar('Proofreading', proofing, total, const Color(0xFFAB47BC)),
                  const SizedBox(height: 12),
                  _pipelineBar('Done', done, total, const Color(0xFF66BB6A)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Team Availability
          if (users.isNotEmpty) ...[
            const Text('Team Availability', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('Available', '$available', Icons.check_circle_outline, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Engaged', '$engaged', Icons.work_history, Colors.orange)),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Branch SPOCs
          const Text('Branch SPOCs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (spocs.isEmpty) const Text('No SPOCs assigned yet.', style: TextStyle(color: Colors.grey)),
          ...spocs.map((s) => Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF1A237E), child: Icon(Icons.business, color: Colors.white, size: 20)),
              title: Text(s['branch'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${s['spocName']} (${s['spocEmail']})'),
              trailing: IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editSPOC(s['branch'], s['spocName'], s['spocEmail'])),
            ),
          )),
        ],
      ),
    );
  }

  void _editSPOC(String branch, String currentName, String currentEmail) {
    final nameCtrl = TextEditingController(text: currentName);
    final emailCtrl = TextEditingController(text: currentEmail);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit SPOC for $branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<EventProvider>().updateBranchSPOC(branch, nameCtrl.text, emailCtrl.text);
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
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _pipelineBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: pct, minHeight: 14, backgroundColor: Colors.grey.shade200, color: color),
          ),
        ),
        const SizedBox(width: 12),
        Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ── KANBAN ──
  Widget _buildKanbanBoard(EventProvider provider) {
    final contentStages = [
      ('Writing', provider.events.where((e) => e.stage == 'Writing').toList(), const Color(0xFF42A5F5), Icons.edit_note),
      ('Editing', provider.events.where((e) => e.stage == 'Editing').toList(), const Color(0xFFFF8A65), Icons.edit),
      ('Proofreading', provider.events.where((e) => e.stage == 'Proofreading').toList(), const Color(0xFFAB47BC), Icons.spellcheck),
      ('Cross check', provider.events.where((e) => e.stage == 'Cross check').toList(), const Color(0xFF26A69A), Icons.fact_check),
      ('Ready to Post', provider.events.where((e) => e.stage == 'Ready to Post').toList(), Colors.purple.shade300, Icons.upload_file),
    ];
    
    final mediaStages = [
      ('Thumbnail Selection', provider.events.where((e) => e.stage == 'Thumbnail Selection').toList(), Colors.orange.shade300, Icons.image),
      ('Thumbnail Processing', provider.events.where((e) => e.stage == 'Thumbnail Processing').toList(), Colors.orange, Icons.design_services),
      ('Thumbnail Cross checking', provider.events.where((e) => e.stage == 'Thumbnail Cross checking').toList(), Colors.deepOrange, Icons.fact_check),
      ('Photos Selection', provider.events.where((e) => e.stage == 'Photos Selection').toList(), Colors.teal, Icons.photo_album),
      ('Photos Clean', provider.events.where((e) => e.stage == 'Photos Clean').toList(), Colors.cyan, Icons.cleaning_services),
      ('Photo Editing', provider.events.where((e) => e.stage == 'Photo Editing').toList(), Colors.indigo, Icons.auto_fix_high),
      ('Video Editing', provider.events.where((e) => e.stage == 'Video Editing').toList(), Colors.redAccent, Icons.video_library),
      ('Media Cross Check', provider.events.where((e) => e.stage == 'Media Cross Check').toList(), Colors.blueGrey, Icons.fact_check),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Content Workflow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: 500,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: contentStages.map((s) => _kanbanColumn(s.$1, s.$2, s.$3, s.$4, provider)).toList(),
            ),
          ),
        ),
        const SizedBox(height: 40),
        const Text('Media Workflow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: 500,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: mediaStages.map((s) => _kanbanColumn(s.$1, s.$2, s.$3, s.$4, provider)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kanbanColumn(String title, List<Event> tasks, Color color, IconData icon, EventProvider provider) {
    if (_globalTaskFilter != 'All Tasks') {
      tasks = tasks.where((t) => t.status == _globalTaskFilter).toList();
    }
    List<Event> notStarted = tasks.where((t) => t.status != 'Done').toList();
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color.withOpacity(0.9), fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: Text('${notStarted.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          // Cards
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                ...notStarted.map((t) => _buildKanbanTaskCard(t, color, provider)),

                if (doneList.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('Done (${doneList.length})', style: TextStyle(color: Colors.grey.shade500, fontSize: 11))),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ]),
                  ),
                ...doneList.map((t) => _buildTaskCard(t, Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanTaskCard(Event task, Color accentColor, EventProvider provider) {
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDone ? Colors.grey : const Color(0xFF1A1A2E)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDone ? Colors.green : (task.status == 'In Progress' ? Colors.blue : (task.status == 'Ready' ? Colors.deepOrange : Colors.grey.shade400)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.status.isEmpty ? 'Pending' : task.status,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (task.theme.isNotEmpty)
                Text(task.theme, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              if (task.date.isNotEmpty)
                Text(task.date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 6),
              if (task.publishPlatform.isNotEmpty || task.mediaMode.isNotEmpty) ...[
                Row(
                  children: [
                    if (task.publishPlatform.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.purple.shade200)),
                        child: Text(task.publishPlatform, style: TextStyle(fontSize: 9, color: Colors.purple.shade700, fontWeight: FontWeight.bold)),
                      ),
                    if (task.publishPlatform.isNotEmpty && task.mediaMode.isNotEmpty) const SizedBox(width: 6),
                    if (task.mediaMode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.teal.shade200)),
                        child: Row(
                          children: [
                            Icon(task.mediaMode == 'Video' ? Icons.videocam : Icons.photo, size: 10, color: Colors.teal.shade700),
                            const SizedBox(width: 2),
                            Text(task.mediaMode, style: TextStyle(fontSize: 9, color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
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
                    Expanded(child: Text(task.assigneeName, style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  ],
                  if (task.dueDate.isNotEmpty && !isDone) ...[
                    const Spacer(),
                    Icon(Icons.timer, size: 12, color: Colors.red.shade400),
                    const SizedBox(width: 2),
                    Text('Due ' + task.dueDate.split('T')[0], style: TextStyle(fontSize: 10, color: Colors.red.shade600, fontWeight: FontWeight.bold)),
                  ]
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
    final filters = ['All', 'Not Started', 'In Pipeline', 'Done'];

    List<Map<String, dynamic>> rawFiltered = provider.rawPosts.where((post) {
      final postNo = post['PostNo']?.toString() ?? '';
      
      // Search text filter
      final searchQuery = _searchController.text.trim();
      if (searchQuery.isNotEmpty && !postNo.contains(searchQuery)) {
        return false;
      }

      if (_postFilter == 'All') return true;
      // For combined, we might check tasks for the GroupID, but for now we check tasks for PostNo or GroupID
      final groupId = post['GroupID']?.toString() ?? '';
      final postTasks = provider.events.where((t) => t.postNo == postNo || (groupId.isNotEmpty && t.postNo == groupId)).toList();
      
      if (_postFilter == 'Not Started') return postTasks.isEmpty;
      if (_postFilter == 'In Pipeline') return postTasks.isNotEmpty && postTasks.any((t) => t.status != 'Done');
      if (_postFilter == 'Done') return postTasks.isNotEmpty && postTasks.every((t) => t.status == 'Done');
      return true;
    }).toList();

    List<Map<String, dynamic>> tabFiltered = [];
    List<Map<String, dynamic>> combinedGroups = [];

    if (_postTab == 'Individual') {
      tabFiltered = rawFiltered.where((p) => (p['GroupID']?.toString() ?? '').isEmpty).toList();
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
        combinedGroups.add({
          'GroupID': entry.key,
          'Posts': entry.value,
        });
      }
    }

    return Scaffold(
      floatingActionButton: _postTab == 'Individual' && _isSelectionMode && _selectedPosts.isNotEmpty
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
                hintText: 'Search by Post No...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear), 
                      onPressed: () => setState(() => _searchController.clear()),
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
                  ...filters.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _postFilter == f,
                      selectedColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                      onSelected: (_) => setState(() {
                        _postFilter = f;
                        _isSelectionMode = false;
                        _selectedPosts.clear();
                      }),
                    ),
                  )),
                  const SizedBox(width: 16),
                  if (_postTab == 'Individual')
                    FilterChip(
                      label: const Text('Select Mode'),
                      selected: _isSelectionMode,
                      onSelected: (val) => setState(() {
                        _isSelectionMode = val;
                        if (!val) _selectedPosts.clear();
                      }),
                      avatar: Icon(_isSelectionMode ? Icons.check_box : Icons.check_box_outline_blank),
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
                Text(_postTab == 'Individual' ? '${tabFiltered.length} posts' : '${combinedGroups.length} combined groups', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const Spacer(),
                Text('Tap card for details', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          // List
          Expanded(
            child: _postTab == 'Individual'
              ? (tabFiltered.isEmpty
                  ? const Center(child: Text('No individual posts found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: tabFiltered.length,
                      itemBuilder: (context, index) => _buildPostCard(tabFiltered[index], provider, auth),
                    ))
              : (combinedGroups.isEmpty
                  ? const Center(child: Text('No combined posts found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: combinedGroups.length,
                      itemBuilder: (context, index) => _buildCombinedCard(combinedGroups[index], provider, auth),
                    )),
          ),
        ],
      ),
    );
  }

  void _groupSelectedPosts() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group Posts'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Group ID (e.g., GRP-XYZ)', hintText: 'Enter a unique name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.isEmpty) return;
              final groupId = ctrl.text;
              final success = await context.read<EventProvider>().groupPosts(_selectedPosts.toList(), groupId);
              if (success && mounted) {
                setState(() {
                  _isSelectionMode = false;
                  _selectedPosts.clear();
                });
                context.read<EventProvider>().fetchEvents(context.read<AuthProvider>().role, context.read<AuthProvider>().username);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Group'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, EventProvider provider, AuthProvider auth) {
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

    // Workflow status indicators
    final dataUploaded = post['DataUploaded']?.toString() ?? '';
    final writingDone = post['WritingDone']?.toString() ?? '';
    final editingDone = post['EditingDone']?.toString() ?? '';
    final proofDone = post['ProofReadingDone']?.toString() ?? '';
    final designDone = post['DesignDone']?.toString() ?? '';
    final readyToPost = post['ReadyToBePosted']?.toString() ?? '';
    final posted = post['PostUploaded']?.toString() ?? '';

    final postTasks = provider.events.where((t) => t.postNo == postNo).toList();
    final isInitialized = postTasks.isNotEmpty;

    final publishPlatform = post['PublishPlatform']?.toString() ?? '';
    final groupId = post['GroupID']?.toString() ?? '';
    final description = post['Description']?.toString() ?? '';
    
    // Find SPOC for branch
    final spocObj = provider.spocs.where((s) => s['branch'] == branch).firstOrNull;
    final spocName = spocObj?['spocName'] ?? 'No SPOC';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: _isSelectionMode && _selectedPosts.contains(postNo) 
            ? BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2) 
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (_selectedPosts.contains(postNo)) _selectedPosts.remove(postNo);
              else _selectedPosts.add(postNo);
            });
          }
        },
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('#$postNo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  if (publishPlatform.isNotEmpty)
                    Icon(publishPlatform.toLowerCase() == 'instagram' ? Icons.camera_alt : Icons.chat, size: 16, color: Colors.pink),
                  if (groupId.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.purple.shade200)),
                      child: Text(groupId, style: TextStyle(fontSize: 10, color: Colors.purple.shade700, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(theme, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  // Assign Setup button
                  IconButton(
                    icon: Icon(isInitialized ? Icons.settings : Icons.add_task_rounded, color: isInitialized ? Colors.grey : Theme.of(context).colorScheme.secondary),
                    tooltip: isInitialized ? 'Workflow Initialized' : 'Assign & Setup Workflow',
                    onPressed: () => context.push('/admin-assign', extra: post),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              if (description.isNotEmpty) ...[
                Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                const SizedBox(height: 10),
              ],

              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _postDetail(Icons.calendar_today, date),
                  _postDetail(Icons.location_city, '$branch, $state'),
                  _postDetail(Icons.person_pin, spocName),
                  if (activityType.isNotEmpty) _postDetail(Icons.category, activityType),
                ],
              ),
              if (venue.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(child: Text(venue, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
              const SizedBox(height: 10),

            // Beneficiary row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            
            if (post['FolderLink'] != null && post['FolderLink'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder, size: 14),
                label: const Text('Open Raw Media Folder', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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

  Widget _buildCombinedCard(Map<String, dynamic> group, EventProvider provider, AuthProvider auth) {
    final groupId = group['GroupID'] as String;
    final List<Map<String, dynamic>> posts = group['Posts'];
    
    final postTasks = provider.events.where((t) => t.postNo == groupId).toList();
    final isInitialized = postTasks.isNotEmpty;
    
    // For media handling later, we will use the posts array.
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade500,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(groupId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Combined Post (${posts.length} events)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  IconButton(
                    icon: Icon(isInitialized ? Icons.settings : Icons.add_task_rounded, color: isInitialized ? Colors.grey : Theme.of(context).colorScheme.secondary),
                    tooltip: isInitialized ? 'Workflow Initialized' : 'Assign & Setup Workflow',
                    onPressed: () {
                      context.push('/admin-assign', extra: {
                        'postNo': groupId,
                        'isCombined': true,
                        'combinedPosts': posts,
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Show quick list of included posts
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: posts.map((p) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: Text('#${p['PostNo']} - ${p['Theme']}', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                )).toList(),
              ),
              if (isInitialized) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _statusChip('Writing', postTasks.any((t) => t.stage == 'Writing' && t.status == 'Done') ? 'Yes' : ''),
                    _statusChip('Editing', postTasks.any((t) => t.stage == 'Editing' && t.status == 'Done') ? 'Yes' : ''),
                    _statusChip('Proof', postTasks.any((t) => t.stage == 'Proofreading' && t.status == 'Done') ? 'Yes' : ''),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Media Folders:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: posts.map((p) {
                      final folderUrl = p['FolderLink']?.toString() ?? '';
                      if (folderUrl.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.folder, size: 14),
                          label: Text('#${p['PostNo']} Raw', style: const TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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

  Widget _benStat(String emoji, String label, String value, {bool bold = false}) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: 14, color: bold ? const Color(0xFF1A237E) : Colors.black87)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _benDivider() {
    return Container(width: 1, height: 30, color: Colors.grey.shade300);
  }

  Widget _statusChip(String label, String val) {
    final isDone = val.isNotEmpty && val.toLowerCase() != 'false' && val != '0' && val != '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDone ? Colors.green.shade300 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 12, color: isDone ? Colors.green : Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDone ? Colors.green.shade700 : Colors.grey)),
        ],
      ),
    );
  }

  // ── USER BODY (My Queue) ──
  Widget _buildUserBody(EventProvider provider) {
    List<Event> visibleEvents = provider.events.where((e) => e.status != 'Waiting').toList();
    if (_globalTaskFilter != 'All Tasks') {
      visibleEvents = visibleEvents.where((e) => e.status == _globalTaskFilter).toList();
    }
    
    if (visibleEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No tasks assigned yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleEvents.length,
      itemBuilder: (context, index) {
        final task = visibleEvents[index];
        final stageColor = task.stage == 'Writing'
            ? const Color(0xFF42A5F5)
            : task.stage == 'Editing'
                ? const Color(0xFFFF8A65)
                : task.stage == 'Proofreading'
                    ? const Color(0xFFAB47BC)
                    : const Color(0xFF26A69A);
        return _buildTaskCard(task, stageColor);
      },
    );
  }
}
