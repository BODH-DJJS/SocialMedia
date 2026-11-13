import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/dev_pipeline_provider.dart';
import '../providers/event_provider.dart';
import '../models/dev_pipeline_models.dart';

class DevPipelineScreen extends StatefulWidget {
  final VoidCallback onSwitchToSocialMedia;

  const DevPipelineScreen({super.key, required this.onSwitchToSocialMedia});

  @override
  State<DevPipelineScreen> createState() => _DevPipelineScreenState();
}

class _DevPipelineScreenState extends State<DevPipelineScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _streams = [
    'Campaign Development',
    'SM Development',
    'Website Reporting',
    'Blogs / Articles'
  ];

  String _searchQuery = '';
  String _statusFilter = 'All'; // All, Ready, Waiting, Done

  final List<Map<String, dynamic>> _stageConfigs = [
    {
      'name': 'Ideation',
      'icon': Icons.lightbulb_outline_rounded,
      'color': Color(0xFFF39C12),
      'cadence': 4,
    },
    {
      'name': 'Research',
      'icon': Icons.travel_explore_rounded,
      'color': Color(0xFF2980B9),
      'cadence': 8,
    },
    {
      'name': 'Selection and sequencing',
      'icon': Icons.checklist_rtl_rounded,
      'color': Color(0xFF16A085),
      'cadence': 12,
    },
    {
      'name': 'Writing',
      'icon': Icons.draw_outlined,
      'color': Color(0xFF8E44AD),
      'cadence': 16,
    },
    {
      'name': 'PPT Development',
      'icon': Icons.co_present_rounded,
      'color': Color(0xFFD35400),
      'cadence': 20,
    },
    {
      'name': 'Proofreading',
      'icon': Icons.spellcheck_rounded,
      'color': Color(0xFF00897B),
      'cadence': 24,
    },
    {
      'name': 'Editing',
      'icon': Icons.auto_fix_high_rounded,
      'color': Color(0xFF3F51B5),
      'cadence': 28,
    },
    {
      'name': 'Final Check',
      'icon': Icons.verified_outlined,
      'color': Color(0xFF27AE60),
      'cadence': 32,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _streams.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final provider = context.read<DevPipelineProvider>();
      provider.setStream(_streams[_tabController.index]);
      provider.fetchDevData();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<DevPipelineProvider>().fetchDevData(role: auth.role, username: auth.username);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.parse(url.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devProvider = context.watch<DevPipelineProvider>();
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.role.toLowerCase() == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 2,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hub_rounded, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Development Pipeline',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                Text(
                  'Delhi (IN) • Head Office • BODH Drive',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
            const SizedBox(width: 20),
            // Pipeline Switcher Pill
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: widget.onSwitchToSocialMedia,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.photo_library_outlined, size: 15, color: Colors.white.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Text(
                            'Social Media',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.layers_rounded, size: 15, color: Color(0xFF1A237E)),
                        SizedBox(width: 6),
                        Text(
                          'Development',
                          style: TextStyle(
                            color: Color(0xFF1A237E),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => devProvider.fetchDevData(role: auth.role, username: auth.username),
          ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F00),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Create Event / Topic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showCreateProjectDialog(context),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF151C65),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFFF6F00),
              indicatorWeight: 3.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                _buildTab('Campaign Development', Icons.campaign_rounded),
                _buildTab('SM Development', Icons.share_rounded),
                _buildTab('Website Reporting', Icons.language_rounded),
                _buildTab('Blogs / Articles', Icons.article_rounded),
              ],
            ),
          ),
        ),
      ),
      body: devProvider.isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1A237E)),
                  SizedBox(height: 16),
                  Text('Loading Development Pipeline...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _tabController.index == 0
              ? _buildCampaignPipelineView(devProvider)
              : _buildComingSoonStreamView(_streams[_tabController.index]),
    );
  }

  Tab _buildTab(String title, IconData icon) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
    );
  }

  Widget _buildComingSoonStreamView(String streamName) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 3,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.architecture_rounded, size: 54, color: Color(0xFF1A237E)),
              ),
              const SizedBox(height: 20),
              Text(
                streamName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 10),
              Text(
                'The Shared Drive folder structure under Delhi (IN) > Head Office is mapped and ready.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Text(
                      'Sequential workflow steps will be enabled for this stream soon.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignPipelineView(DevPipelineProvider provider) {
    if (provider.tasks.isEmpty && provider.projects.isEmpty) {
      return Center(
        child: Card(
          elevation: 2,
          margin: const EdgeInsets.all(32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.post_add_rounded, size: 52, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Campaign Development Projects Yet',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click "Create Event / Topic" above to start a new campaign topic with its 8-step sequential workflow and 4-day cadence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Filter tasks
    var filteredTasks = provider.tasks;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filteredTasks = filteredTasks.where((t) =>
        t.campaignName.toLowerCase().contains(q) ||
        t.sessionName.toLowerCase().contains(q) ||
        t.assignee.toLowerCase().contains(q) ||
        t.projectId.toLowerCase().contains(q)
      ).toList();
    }
    if (_statusFilter != 'All') {
      filteredTasks = filteredTasks.where((t) => t.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
    }

    // Counts for stats banner
    final totalProjects = provider.projects.length;
    final totalTasks = provider.tasks.length;
    final readyTasks = provider.tasks.where((t) => t.status.toLowerCase() == 'ready').length;
    final doneTasks = provider.tasks.where((t) => t.status.toLowerCase() == 'done').length;

    return Column(
      children: [
        // Summary & Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              // KPI Badges
              _buildKpiChip('Campaigns', '$totalProjects', const Color(0xFF1A237E)),
              const SizedBox(width: 8),
              _buildKpiChip('Ready for Action', '$readyTasks', const Color(0xFF00897B)),
              const SizedBox(width: 8),
              _buildKpiChip('Completed Steps', '$doneTasks', Colors.green.shade700),
              const SizedBox(width: 8),
              _buildKpiChip('Total Tasks', '$totalTasks', Colors.grey.shade700),
              const Spacer(),
              // Search Field
              SizedBox(
                width: 220,
                height: 36,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search campaign / session...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Status Filter Dropdown
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('Filter: All')),
                      DropdownMenuItem(value: 'Ready', child: Text('Filter: Ready')),
                      DropdownMenuItem(value: 'Waiting', child: Text('Filter: Waiting')),
                      DropdownMenuItem(value: 'Done', child: Text('Filter: Done')),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Kanban Board
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _stageConfigs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final cfg = entry.value;
                          final stageName = cfg['name'] as String;
                          final stageColor = cfg['color'] as Color;
                          final stageIcon = cfg['icon'] as IconData;
                          final cadence = cfg['cadence'] as int;

                          final stageTasks = filteredTasks
                              .where((t) => t.stage.toLowerCase() == stageName.toLowerCase())
                              .toList();

                          return _buildKanbanColumn(
                            stepNum: idx + 1,
                            stageName: stageName,
                            tasks: stageTasks,
                            offsetDays: cadence,
                            stageColor: stageColor,
                            stageIcon: stageIcon,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKpiChip(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              count,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn({
    required int stepNum,
    required String stageName,
    required List<DevTask> tasks,
    required int offsetDays,
    required Color stageColor,
    required IconData stageIcon,
  }) {
    final readyCount = tasks.where((t) => t.status.toLowerCase() == 'ready').length;

    return Container(
      width: 310,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: stageColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(stageIcon, size: 16, color: stageColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Step $stepNum: $stageName',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                'Cadence: +$offsetDays days',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                              if (readyCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00897B).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$readyCount Ready',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stageColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stageColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Task List
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade300),
                          const SizedBox(height: 6),
                          Text(
                            'No tasks in this step',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: tasks.length,
                    itemBuilder: (context, i) => _buildTaskCard(tasks[i], stepNum, stageColor),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DevTask task, int stepNum, Color stageColor) {
    final isDone = task.status.toLowerCase() == 'done';
    final isReady = task.status.toLowerCase() == 'ready';
    final isPptStage = task.stage.toLowerCase() == 'ppt development';
    final isPostPptStage = stepNum >= 6;

    final devProvider = context.read<DevPipelineProvider>();
    String cardPptFolder = task.pptFolderLink.trim();
    if (cardPptFolder.isEmpty) {
      try {
        final pptTask = devProvider.tasks.firstWhere(
          (t) => t.projectId == task.projectId && t.stage.toLowerCase() == 'ppt development',
        );
        cardPptFolder = pptTask.docLink.isNotEmpty ? pptTask.docLink : pptTask.folderLink;
      } catch (_) {}
    }

    String cardWritingDoc = task.prevDocLink.trim().isNotEmpty ? task.prevDocLink.trim() : task.writingDocLink.trim();
    if (cardWritingDoc.isEmpty) {
      try {
        final writingTask = devProvider.tasks.firstWhere(
          (t) => t.projectId == task.projectId && t.stage.toLowerCase() == 'writing',
        );
        cardWritingDoc = writingTask.docLink.trim();
      } catch (_) {}
    }

    Color statusBadgeBg;
    Color statusBadgeText;
    String statusDisplay;

    if (isDone) {
      statusBadgeBg = Colors.green.shade50;
      statusBadgeText = Colors.green.shade700;
      statusDisplay = 'Done';
    } else if (isReady) {
      statusBadgeBg = const Color(0xFFE0F2F1);
      statusBadgeText = const Color(0xFF00897B);
      statusDisplay = 'Ready / Active';
    } else {
      statusBadgeBg = Colors.grey.shade100;
      statusBadgeText = Colors.grey.shade700;
      statusDisplay = 'Waiting';
    }

    return Card(
      elevation: isReady ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isReady
              ? const Color(0xFF00897B).withOpacity(0.6)
              : (isDone ? Colors.green.shade200 : Colors.grey.shade300),
          width: isReady ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTaskDetailsDialog(task, stepNum, stageColor),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: isDone ? Colors.green : (isReady ? const Color(0xFF00897B) : stageColor),
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Project ID & Status Pill
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '#${task.projectId}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBadgeBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusBadgeText.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isReady) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00897B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (isDone) ...[
                          const Icon(Icons.check, size: 10, color: Colors.green),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          statusDisplay,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusBadgeText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Campaign & Session Name
              Text(
                task.campaignName.isNotEmpty ? task.campaignName : 'Campaign Topic',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (task.sessionName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Session: ${task.sessionName}',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Assignee & Due Date
              Row(
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.grey.shade300,
                    child: Text(
                      task.assignee.isNotEmpty ? task.assignee[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.assignee.isNotEmpty ? task.assignee : 'Unassigned',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${task.dueDate.isNotEmpty ? task.dueDate : 'TBD'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),

              // Revision / Redo Alert Banner
              if (task.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.replay_rounded, size: 12, color: Colors.amber.shade900),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          task.notes.split('\n').last,
                          style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 16),

              // Quick Actions on Card
              Row(
                children: [
                  if (isPptStage) ...[
                    // Step 5: PPT Folder & Writing Doc
                    if (task.docLink.isNotEmpty || cardPptFolder.isNotEmpty)
                      InkWell(
                        onTap: () => _openUrl(task.docLink.isNotEmpty ? task.docLink : cardPptFolder),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.drive_folder_upload_rounded, size: 13, color: Colors.deepOrange),
                              SizedBox(width: 4),
                              Text('PPT Folder', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    if (cardWritingDoc.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _openUrl(cardWritingDoc),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.description_outlined, size: 13, color: Colors.blue),
                              SizedBox(width: 4),
                              Text('Writing Doc', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Standard Doc
                    if (task.docLink.isNotEmpty)
                      InkWell(
                        onTap: () => _openUrl(task.docLink),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.description_outlined, size: 13, color: Colors.blue),
                              SizedBox(width: 4),
                              Text('Doc', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    // For Steps 6, 7, 8: Also show PPT Folder link on card
                    if (isPostPptStage && cardPptFolder.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _openUrl(cardPptFolder),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.co_present_rounded, size: 13, color: Colors.deepOrange),
                              SizedBox(width: 4),
                              Text('PPT', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  const Spacer(),
                  // Prominent Details / Handoff trigger
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isReady ? const Color(0xFF00897B) : const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isDone ? Icons.visibility_rounded : Icons.touch_app_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          isDone ? 'View' : 'Open & Action',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full Task Details & Action Dialog (Mirrors Social Media Flow)
  void _showTaskDetailsDialog(DevTask task, int stepNum, Color stageColor) {
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDone = task.status.toLowerCase() == 'done';
            final hasPreviousStage = stepNum > 1;
            final isPptStage = task.stage.toLowerCase() == 'ppt development';
            final isPostPptStage = stepNum >= 6;

            final devProvider = context.read<DevPipelineProvider>();
            String bestPptFolder = task.pptFolderLink.trim();
            if (bestPptFolder.isEmpty) {
              try {
                final pptTask = devProvider.tasks.firstWhere(
                  (t) => t.projectId == task.projectId && t.stage.toLowerCase() == 'ppt development',
                );
                bestPptFolder = pptTask.docLink.isNotEmpty ? pptTask.docLink : pptTask.folderLink;
              } catch (_) {}
            }

            String bestWritingDoc = task.prevDocLink.trim().isNotEmpty ? task.prevDocLink.trim() : task.writingDocLink.trim();
            if (bestWritingDoc.isEmpty) {
              try {
                final writingTask = devProvider.tasks.firstWhere(
                  (t) => t.projectId == task.projectId && t.stage.toLowerCase() == 'writing',
                );
                bestWritingDoc = writingTask.docLink.trim();
              } catch (_) {}
            }

            // Campaign-level IEC Material links
            DevProject? proj;
            try {
              proj = devProvider.projects.firstWhere((p) => p.projectId == task.projectId);
            } catch (_) {}

            String bestIecFolder = task.iecFolderLink.isNotEmpty ? task.iecFolderLink : (proj?.iecFolderLink ?? '');
            String bestIecWritingDoc = task.iecWritingDocLink.isNotEmpty ? task.iecWritingDocLink : (proj?.iecWritingDocLink ?? '');
            String bestIecDesigningFolder = task.iecDesigningFolderLink.isNotEmpty ? task.iecDesigningFolderLink : (proj?.iecDesigningFolderLink ?? '');
            String bestIecProofreadDoc = task.iecProofreadDocLink.isNotEmpty ? task.iecProofreadDocLink : (proj?.iecProofreadDocLink ?? '');
            String bestIecFinalCheckDoc = task.iecFinalCheckDocLink.isNotEmpty ? task.iecFinalCheckDocLink : (proj?.iecFinalCheckDocLink ?? '');
            final hasIecMaterial = bestIecFolder.isNotEmpty || bestIecWritingDoc.isNotEmpty || bestIecDesigningFolder.isNotEmpty || bestIecProofreadDoc.isNotEmpty || bestIecFinalCheckDoc.isNotEmpty;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: stageColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.task_alt_rounded, color: stageColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step $stepNum: ${task.stage}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '#${task.projectId} • ${task.campaignName}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDone ? Colors.green.shade50 : (task.status == 'Ready' ? const Color(0xFFE0F2F1) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDone ? Colors.green : (task.status == 'Ready' ? const Color(0xFF00897B) : Colors.grey)),
                    ),
                    child: Text(
                      isDone ? 'Done' : (task.status == 'Ready' ? 'Ready / Active' : 'Waiting'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDone ? Colors.green.shade800 : (task.status == 'Ready' ? const Color(0xFF00897B) : Colors.grey.shade800),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Project Details Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _infoRow('Campaign', task.campaignName),
                            if (task.sessionName.isNotEmpty) _infoRow('Session', task.sessionName),
                            _infoRow('Assignee', '${task.assignee} ${task.assigneeEmail.isNotEmpty ? "(${task.assigneeEmail})" : ""}'),
                            _infoRow('Due Date', task.dueDate.isNotEmpty ? task.dueDate : 'TBD'),
                            if (task.allottedDate.isNotEmpty) _infoRow('Allotted On', task.allottedDate),
                            if (task.completedAt.isNotEmpty) _infoRow('Completed At', task.completedAt),
                          ],
                        ),
                      ),

                      // Revision / Redo Notes
                      if (task.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.replay_rounded, size: 16, color: Colors.amber.shade900),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Revision / Redo History',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(task.notes, style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // ── Workspace Section (Tailored for PPT Folder / Docs) ──
                      if (isPptStage) ...[
                        // Step 5: PPT Development Upload Folder & Writing Script Reference
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.co_present_rounded, color: Colors.deepOrange.shade800, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Step 5: PPT Development Folder & Script',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange.shade900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Upload your presentation files (PPT/PDF) to this dedicated folder. You can reference the finalized script & content from Step 4 (Writing) below.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 12),
                              // Primary Button: Open PPT Upload Folder
                              if (task.docLink.isNotEmpty || bestPptFolder.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepOrange.shade800,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.drive_folder_upload_rounded, size: 20),
                                    label: const Text('Open PPT Upload Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    onPressed: () => _openUrl(task.docLink.isNotEmpty ? task.docLink : bestPptFolder),
                                  ),
                                )
                              else
                                const Text('No PPT folder attached yet', style: TextStyle(color: Colors.grey, fontSize: 12)),

                              // Reference Step 4 Writing Doc
                              if (bestWritingDoc.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A237E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.description, size: 17),
                                    label: const Text('Open Step 4 (Writing) Doc for Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    onPressed: () => _openUrl(bestWritingDoc),
                                  ),
                                ),
                              ],

                              if (task.folderLink.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      side: BorderSide(color: Colors.deepOrange.shade800),
                                    ),
                                    icon: Icon(Icons.folder_open, size: 17, color: Colors.deepOrange.shade800),
                                    label: Text('Open Session Drive Folder', style: TextStyle(color: Colors.deepOrange.shade800, fontSize: 13)),
                                    onPressed: () => _openUrl(task.folderLink),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (isPostPptStage) ...[
                        // Steps 6, 7, 8: Show Stage Doc AND PPT Folder Link
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD0DCFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.description, color: Color(0xFF1A237E), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Step $stepNum: ${task.stage} Doc & PPT Folder',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Review both the stage document (copied forward) and the uploaded presentation slides from Step 5 (PPT Development).',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 12),
                              // Primary Stage Doc Button
                              if (task.docLink.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A237E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.open_in_new, size: 18),
                                    label: Text('Open ${task.stage} Doc', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => _openUrl(task.docLink),
                                  ),
                                ),

                              // Secondary Button: Open PPT Upload Folder from Step 5
                              if (bestPptFolder.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepOrange.shade800,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.co_present_rounded, size: 18),
                                    label: const Text('Open PPT Presentation Folder (Step 5)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    onPressed: () => _openUrl(bestPptFolder),
                                  ),
                                ),
                              ],

                              if (task.folderLink.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      side: const BorderSide(color: Color(0xFF1A237E)),
                                    ),
                                    icon: const Icon(Icons.folder_open, size: 17, color: Color(0xFF1A237E)),
                                    label: const Text('Open Session Drive Folder', style: TextStyle(color: Color(0xFF1A237E), fontSize: 13)),
                                    onPressed: () => _openUrl(task.folderLink),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        // Steps 1 to 4: Standard Stage Doc
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD0DCFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.description, color: Color(0xFF1A237E), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Step $stepNum Document: ${task.stage}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Each stage has its own document with edit access for the assigned owner. When marked Done, content is automatically carried over to the next stage.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 12),
                              if (task.docLink.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A237E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.open_in_new, size: 18),
                                    label: Text('Open ${task.stage} Doc', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => _openUrl(task.docLink),
                                  ),
                                )
                              else
                                const Text('No document URL attached yet', style: TextStyle(color: Colors.grey, fontSize: 12)),

                              if (task.folderLink.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      side: const BorderSide(color: Color(0xFF1A237E)),
                                    ),
                                    icon: const Icon(Icons.folder_open, size: 17, color: Color(0xFF1A237E)),
                                    label: const Text('Open Session Drive Folder', style: TextStyle(color: Color(0xFF1A237E), fontSize: 13)),
                                    onPressed: () => _openUrl(task.folderLink),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // ── Campaign IEC Material Section (Common to Campaign) ──
                      if (hasIecMaterial) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCE93D8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_stories_rounded, color: Color(0xFF6A1B9A), size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Campaign IEC Material (Common)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4A148C)),
                                  ),
                                  const Spacer(),
                                  if (bestIecFolder.isNotEmpty)
                                    InkWell(
                                      onTap: () => _openUrl(bestIecFolder),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFBA68C8)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.folder_open, size: 14, color: Color(0xFF6A1B9A)),
                                            SizedBox(width: 4),
                                            Text('Open IEC Folder', style: TextStyle(fontSize: 11, color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'IEC Material is created once per campaign under the Campaign folder. Sub-divisions share content forwarding and designing assets.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (bestIecWritingDoc.isNotEmpty)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF7B1FA2)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        backgroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.description, size: 15, color: Color(0xFF7B1FA2)),
                                      label: const Text('1. IEC Writing Doc', style: TextStyle(color: Color(0xFF7B1FA2), fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _openUrl(bestIecWritingDoc),
                                    ),
                                  if (bestIecDesigningFolder.isNotEmpty)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFE65100)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        backgroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.drive_folder_upload, size: 15, color: Color(0xFFE65100)),
                                      label: const Text('2. IEC Designing Folder', style: TextStyle(color: Color(0xFFE65100), fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _openUrl(bestIecDesigningFolder),
                                    ),
                                  if (bestIecProofreadDoc.isNotEmpty)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF00695C)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        backgroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.spellcheck, size: 15, color: Color(0xFF00695C)),
                                      label: const Text('3. IEC Proofread Doc', style: TextStyle(color: Color(0xFF00695C), fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _openUrl(bestIecProofreadDoc),
                                    ),
                                  if (bestIecFinalCheckDoc.isNotEmpty)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF2E7D32)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        backgroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.verified, size: 15, color: Color(0xFF2E7D32)),
                                      label: const Text('4. IEC Final Cross check', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _openUrl(bestIecFinalCheckDoc),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Action Buttons: Exactly matching Social Media Flow ──
                      if (!isDone) ...[
                        if (hasPreviousStage) ...[
                          Row(
                            children: [
                              // Send Back (Redo) Button
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 54,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.replay_rounded, color: Colors.orange),
                                    label: const Text(
                                      'Send Back',
                                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.orange, width: 1.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: isSaving
                                        ? null
                                        : () {
                                            Navigator.pop(ctx);
                                            _showRedoDialog(task, stepNum);
                                          },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Mark Done & Handoff Button
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    icon: isSaving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Icon(Icons.check_circle, size: 20),
                                    label: Text(
                                      isSaving ? 'Saving...' : 'Mark Done & Handoff',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00897B),
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: isSaving
                                        ? null
                                        : () {
                                            setDialogState(() => isSaving = true);
                                            _executeMarkDone(ctx, task, setDialogState);
                                          },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Step 1: Full-width Mark Done & Handoff
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_circle, size: 20),
                              label: Text(
                                isSaving ? 'Saving...' : 'Mark Done & Handoff',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00897B),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      setDialogState(() => isSaving = true);
                                      _executeMarkDone(ctx, task, setDialogState);
                                    },
                            ),
                          ),
                        ],
                      ] else ...[
                        // Already Completed Badge
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Step Completed ${task.completedAt.isNotEmpty ? "(${task.completedAt})" : ""}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeMarkDone(
    BuildContext dialogCtx,
    DevTask task,
    void Function(void Function()) setDialogState,
  ) async {
    // If task is waiting, show a friendly confirmation
    if (task.status.toLowerCase() == 'waiting') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Advance Step Early?'),
          content: const Text(
            'This step is currently in "Waiting" status because previous steps may not have finished.\n\nDo you want to proceed and Mark Done & Handoff to unlock the next step?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Yes, Mark Done & Handoff'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (!mounted) return;
    setDialogState(() {});
    Navigator.pop(dialogCtx);

    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Marking done and handing off to next stage...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    final success = await context.read<DevPipelineProvider>().updateTaskStatus(task, 'Done');
    if (mounted) {
      scaffold.hideCurrentSnackBar();
      if (success) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('✓ Step "${task.stage}" marked Done & Handed off to next stage!'),
            backgroundColor: const Color(0xFF00897B),
          ),
        );
      } else {
        scaffold.showSnackBar(
          const SnackBar(content: Text('Failed to update task. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRedoDialog(DevTask task, int stepNum) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.replay_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Send Back for Redo', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will set this step to Waiting and return the previous step to Ready so the predecessor can revise the work.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Revision / Redo Reason *',
                hintText: 'Enter specific feedback explaining what needs to be revised...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await context.read<DevPipelineProvider>().redoTask(task, reasonController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task sent back for Redo.'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Confirm Redo'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final campNameCtrl = TextEditingController();
    final sessNameCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final festivalsCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime completionDate = DateTime.now().add(const Duration(days: 32));

    bool iecContent = false;
    bool iecDesigning = false;
    bool iecProofread = false;
    bool iecFinalCheck = false;

    final stages = [
      'Ideation',
      'Research',
      'Selection and sequencing',
      'Writing',
      'PPT Development',
      'Proofreading',
      'Editing',
      'Final Check'
    ];

    // Read all users from eventProvider
    final eventProvider = context.read<EventProvider>();
    final users = eventProvider.users;

    final assignees = <String, Map<String, String>>{};
    for (final st in stages) {
      assignees[st] = {'name': '', 'email': ''};
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.add_task_rounded, color: Color(0xFF1A237E)),
                  SizedBox(width: 10),
                  Text('Create Campaign Event / Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_shared_rounded, color: Color(0xFF1A237E), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Creates Session folder with 7 Docs + Step 5 PPT Upload Folder, and common IEC Material folder under Campaign with Writing Doc, Designing Folder, and Proofreading/Final Check docs.',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('1. Campaign & Session Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: campNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Campaign Name *',
                          hintText: 'e.g. Anti-Drug Youth Campaign 2026',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: sessNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Session Name (Sub-section)',
                          hintText: 'e.g. Session 1 - Understanding Addiction',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: durationCtrl,
                              decoration: InputDecoration(
                                labelText: 'Duration',
                                hintText: 'e.g. 2 Hours / 3 Days',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: festivalsCtrl,
                              decoration: InputDecoration(
                                labelText: 'Festivals & Days Included',
                                hintText: 'e.g. World Health Day',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setDialogState(() => startDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Start Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(DateFormat('d-MMM-yyyy').format(startDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: completionDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setDialogState(() => completionDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event_available, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Completion Date', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(DateFormat('d-MMM-yyyy').format(completionDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 28),
                      const Text('2. IEC Material Sub-divisions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          FilterChip(
                            label: const Text('Content Writing'),
                            selected: iecContent,
                            selectedColor: const Color(0xFF1A237E).withOpacity(0.15),
                            checkmarkColor: const Color(0xFF1A237E),
                            onSelected: (v) => setDialogState(() => iecContent = v),
                          ),
                          FilterChip(
                            label: const Text('Designing'),
                            selected: iecDesigning,
                            selectedColor: const Color(0xFF1A237E).withOpacity(0.15),
                            checkmarkColor: const Color(0xFF1A237E),
                            onSelected: (v) => setDialogState(() => iecDesigning = v),
                          ),
                          FilterChip(
                            label: const Text('Proofread'),
                            selected: iecProofread,
                            selectedColor: const Color(0xFF1A237E).withOpacity(0.15),
                            checkmarkColor: const Color(0xFF1A237E),
                            onSelected: (v) => setDialogState(() => iecProofread = v),
                          ),
                          FilterChip(
                            label: const Text('Final Cross check'),
                            selected: iecFinalCheck,
                            selectedColor: const Color(0xFF1A237E).withOpacity(0.15),
                            checkmarkColor: const Color(0xFF1A237E),
                            onSelected: (v) => setDialogState(() => iecFinalCheck = v),
                          ),
                        ],
                      ),

                      const Divider(height: 28),
                      const Text('3. Assign Stage Owners (4-day cadence)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      ...stages.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final st = entry.value;
                        final offset = (idx + 1) * 4;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 210,
                                child: Text(
                                  '${idx + 1}. $st (+$offset d):',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    isDense: true,
                                  ),
                                  hint: const Text('Select Assignee', style: TextStyle(fontSize: 12)),
                                  value: assignees[st]?['email']?.isNotEmpty == true ? assignees[st]!['email'] : null,
                                  items: users.map((u) {
                                    final uEmail = u['Email']?.toString() ?? u['email']?.toString() ?? '';
                                    final uName = u['Name']?.toString() ?? u['name']?.toString() ?? uEmail;
                                    final uRole = u['Role']?.toString() ?? u['role']?.toString() ?? '';
                                    return DropdownMenuItem<String>(
                                      value: uEmail,
                                      child: Text('$uName ($uRole)', style: const TextStyle(fontSize: 12)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final matched = users.firstWhere(
                                        (u) => (u['Email']?.toString() ?? u['email']?.toString()) == val,
                                        orElse: () => users.first,
                                      );
                                      final mName = matched['Name']?.toString() ?? matched['name']?.toString() ?? val;
                                      final mEmail = matched['Email']?.toString() ?? matched['email']?.toString() ?? val;
                                      setDialogState(() {
                                        assignees[st] = {
                                          'name': mName,
                                          'email': mEmail,
                                        };
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Create Project & Setup Flow', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (campNameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter Campaign Name'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final res = await context.read<DevPipelineProvider>().createProject(
                          stream: 'Campaign Development',
                          campaignName: campNameCtrl.text.trim(),
                          sessionName: sessNameCtrl.text.trim(),
                          duration: durationCtrl.text.trim(),
                          festivals: festivalsCtrl.text.trim(),
                          startDate: DateFormat('d-MMM-yyyy').format(startDate),
                          completionDate: DateFormat('d-MMM-yyyy').format(completionDate),
                          iecContent: iecContent,
                          iecDesigning: iecDesigning,
                          iecProofread: iecProofread,
                          iecFinalCheck: iecFinalCheck,
                          assignees: assignees,
                        );

                    if (mounted) {
                      if (res['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Created ${res["projectId"]} successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed: ${res["message"]}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
