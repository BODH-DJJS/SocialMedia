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
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_outlined, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Development Pipeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(width: 16),
            // Pipeline switcher pill
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: widget.onSwitchToSocialMedia,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Text(
                        'Social Media',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Development',
                      style: TextStyle(
                        color: Color(0xFF6C5CE7),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
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
            icon: const Icon(Icons.refresh),
            onPressed: () => devProvider.fetchDevData(role: auth.role, username: auth.username),
          ),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6C5CE7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create New Event / Topic', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showCreateProjectDialog(context),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _streams.map((s) => Tab(text: s)).toList(),
        ),
      ),
      body: devProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tabController.index == 0
              ? _buildCampaignPipelineView(devProvider)
              : _buildComingSoonStreamView(_streams[_tabController.index]),
    );
  }

  Widget _buildComingSoonStreamView(String streamName) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            streamName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            'The folder structure and backend support are configured.\nStream-specific sequential workflows will be enabled here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignPipelineView(DevPipelineProvider provider) {
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

    if (provider.tasks.isEmpty && provider.projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Campaign Development Projects Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click "Create New Event / Topic" above to start a campaign session and its 8-step workflow.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: stages.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final stageName = entry.value;
                  final stageTasks = provider.tasks
                      .where((t) => t.stage.toLowerCase() == stageName.toLowerCase())
                      .toList();

                  return _buildKanbanColumn(
                    stepNum: idx + 1,
                    stageName: stageName,
                    tasks: stageTasks,
                    offsetDays: (idx + 1) * 4,
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumn({
    required int stepNum,
    required String stageName,
    required List<DevTask> tasks,
    required int offsetDays,
  }) {
    return Container(
      width: 290,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.15),
                  child: Text(
                    '$stepNum',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stageName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '+$offsetDays days cadence',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: tasks.length,
              itemBuilder: (context, i) => _buildTaskCard(tasks[i], stepNum),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DevTask task, int stepNum) {
    Color statusColor;
    switch (task.status.toLowerCase()) {
      case 'done':
        statusColor = Colors.green;
        break;
      case 'ready':
        statusColor = const Color(0xFF0984E3);
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: task.status.toLowerCase() == 'ready' ? const Color(0xFF0984E3).withOpacity(0.4) : Colors.grey.shade200,
          width: task.status.toLowerCase() == 'ready' ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showTaskDetailsDialog(task, stepNum),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.projectId,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      task.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.campaignName.isNotEmpty ? task.campaignName : 'Campaign Topic',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (task.sessionName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Session: ${task.sessionName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.assignee.isNotEmpty ? task.assignee : 'Unassigned',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${task.dueDate.isNotEmpty ? task.dueDate : 'TBD'}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              if (task.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.replay, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          task.notes.split('\n').last,
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetailsDialog(DevTask task, int stepNum) {
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
                  color: const Color(0xFF6C5CE7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.task_alt, color: Color(0xFF6C5CE7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Step $stepNum: ${task.stage}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${task.projectId} | ${task.campaignName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _infoRow('Session', task.sessionName.isNotEmpty ? task.sessionName : 'General'),
                  _infoRow('Assignee', '${task.assignee} ${task.assigneeEmail.isNotEmpty ? "(${task.assigneeEmail})" : ""}'),
                  _infoRow('Status', task.status),
                  _infoRow('Due Date', task.dueDate),
                  if (task.allottedDate.isNotEmpty) _infoRow('Allotted', task.allottedDate),
                  if (task.completedAt.isNotEmpty) _infoRow('Completed At', task.completedAt),
                  const SizedBox(height: 12),
                  if (task.notes.isNotEmpty) ...[
                    const Text('Revision / Redo History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(task.notes, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Shared Work Document:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'All 8 steps share this collaborative document with full editing history.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  if (task.docLink.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0984E3),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text('Open Google Document'),
                      onPressed: () => _openUrl(task.docLink),
                    )
                  else
                    const Text('No document URL attached yet', style: TextStyle(color: Colors.grey)),
                  if (task.folderLink.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Open Session Drive Folder'),
                      onPressed: () => _openUrl(task.folderLink),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (stepNum > 1 && task.status.toLowerCase() != 'waiting')
              TextButton.icon(
                icon: const Icon(Icons.replay, color: Colors.redAccent),
                label: const Text('Redo (Send Back)', style: TextStyle(color: Colors.redAccent)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRedoDialog(task, stepNum);
                },
              ),
            if (task.status.toLowerCase() == 'ready')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Mark Done & Unlock Next Step'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await context.read<DevPipelineProvider>().updateTaskStatus(task, 'Done');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Step marked Done! Next step unlocked.'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showRedoDialog(DevTask task, int stepNum) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Back for Redo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will set this step to Waiting and return the previous step to Ready so the predecessor can revise the work.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Revision / Redo Reason',
                hintText: 'Enter notes explaining what needs to be changed...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
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
              title: const Text('Create Campaign Development Event / Session', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'This will create the Delhi -> Head Office -> Campaign Development folder, document, and 8 sequential tasks with 4-day due date cadence.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: campNameCtrl,
                        decoration: const InputDecoration(
                          labelText: '1. Campaign Name *',
                          hintText: 'e.g. Anti-Drug Youth Campaign 2026',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sessNameCtrl,
                        decoration: const InputDecoration(
                          labelText: '2. Session Name (Sub-section)',
                          hintText: 'e.g. Session 1 - Understanding Addiction',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: durationCtrl,
                              decoration: const InputDecoration(
                                labelText: '3. Duration',
                                hintText: 'e.g. 2 Hours / 3 Days',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: festivalsCtrl,
                              decoration: const InputDecoration(
                                labelText: '4. Festivals & Days Included',
                                hintText: 'e.g. World Health Day',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('5. Start Date', style: TextStyle(fontSize: 13)),
                              subtitle: Text(DateFormat('d-MMM-yyyy').format(startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.calendar_today, size: 18),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setDialogState(() => startDate = picked);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('6. Completion Date', style: TextStyle(fontSize: 13)),
                              subtitle: Text(DateFormat('d-MMM-yyyy').format(completionDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                              trailing: const Icon(Icons.calendar_today, size: 18),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: completionDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setDialogState(() => completionDate = picked);
                              },
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('7. IEC Material Sub-divisions:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Content Writing'),
                            selected: iecContent,
                            onSelected: (v) => setDialogState(() => iecContent = v),
                          ),
                          FilterChip(
                            label: const Text('Designing'),
                            selected: iecDesigning,
                            onSelected: (v) => setDialogState(() => iecDesigning = v),
                          ),
                          FilterChip(
                            label: const Text('Proofread'),
                            selected: iecProofread,
                            onSelected: (v) => setDialogState(() => iecProofread = v),
                          ),
                          FilterChip(
                            label: const Text('Final Cross check'),
                            selected: iecFinalCheck,
                            onSelected: (v) => setDialogState(() => iecFinalCheck = v),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('8. Assign Stage Owners (4-day cadence):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...stages.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final st = entry.value;
                        final offset = (idx + 1) * 4;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 190,
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                  ),
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
                  child: const Text('Create Project & Setup Flow'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
