import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/dev_pipeline_provider.dart';
import '../providers/event_provider.dart';
import '../models/dev_pipeline_models.dart';
import '../utils/due_date_utils.dart';

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
  String _campaignFilter = 'All'; // Campaign dropdown filter
  String _smPostFilter = 'All'; // SM Post dropdown filter
  String _webIdeaFilter = 'All'; // Website Reporting dropdown filter
  String _blogIdeaFilter = 'All'; // Blogs / Articles dropdown filter

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

  final List<Map<String, dynamic>> _smStageConfigs = [
    {
      'name': 'Writing',
      'icon': Icons.draw_outlined,
      'color': Color(0xFF8E44AD),
      'group': 'Content',
    },
    {
      'name': 'Editing',
      'icon': Icons.auto_fix_high_rounded,
      'color': Color(0xFF3F51B5),
      'group': 'Content',
    },
    {
      'name': 'Proofreading',
      'icon': Icons.spellcheck_rounded,
      'color': Color(0xFF00897B),
      'group': 'Content',
    },
    {
      'name': 'Text Crosscheck',
      'icon': Icons.verified_outlined,
      'color': Color(0xFF27AE60),
      'group': 'Content',
    },
    {
      'name': 'Thumbnail Selection',
      'icon': Icons.image_search_rounded,
      'color': Color(0xFFF39C12),
      'group': 'Thumbnail',
    },
    {
      'name': 'Thumbnail Processing',
      'icon': Icons.design_services_rounded,
      'color': Color(0xFFD35400),
      'group': 'Thumbnail',
    },
    {
      'name': 'Thumbnail Cross checking',
      'icon': Icons.check_circle_outline_rounded,
      'color': Color(0xFFE67E22),
      'group': 'Thumbnail',
    },
    {
      'name': 'Photo Editing',
      'icon': Icons.photo_filter_rounded,
      'color': Color(0xFF16A085),
      'group': 'Media',
    },
    {
      'name': 'Video Editing',
      'icon': Icons.video_camera_back_rounded,
      'color': Color(0xFF2980B9),
      'group': 'Media',
    },
    {
      'name': 'Media Cross Check',
      'icon': Icons.rule_rounded,
      'color': Color(0xFF1ABC9C),
      'group': 'Media',
    },
    {
      'name': 'Media Final Cross check',
      'icon': Icons.fact_check_rounded,
      'color': Color(0xFF2ECC71),
      'group': 'Media',
    },
    {
      'name': 'Ready to Post',
      'icon': Icons.send_rounded,
      'color': Color(0xFFE91E63),
      'group': 'Publish',
    },
    {
      'name': 'Photos Clean',
      'icon': Icons.cleaning_services_rounded,
      'color': Color(0xFF607D8B),
      'group': 'Publish',
    },
  ];

  final List<Map<String, dynamic>> _webStageConfigs = [
    {
      'name': 'Writing',
      'icon': Icons.draw_outlined,
      'color': Color(0xFF8E44AD),
      'group': 'Content',
    },
    {
      'name': 'Editing',
      'icon': Icons.auto_fix_high_rounded,
      'color': Color(0xFF3F51B5),
      'group': 'Content',
    },
    {
      'name': 'Proofreading',
      'icon': Icons.spellcheck_rounded,
      'color': Color(0xFF00897B),
      'group': 'Content',
    },
    {
      'name': 'Text Crosscheck',
      'icon': Icons.verified_outlined,
      'color': Color(0xFF27AE60),
      'group': 'Content',
    },
    {
      'name': 'Raw Photos',
      'icon': Icons.photo_camera_back_outlined,
      'color': Color(0xFFE65100),
      'group': 'Media',
    },
    {
      'name': 'Selected Photos',
      'icon': Icons.photo_library_rounded,
      'color': Color(0xFF16A085),
      'group': 'Media',
    },
    {
      'name': 'Thumbnail Selection',
      'icon': Icons.image_search_rounded,
      'color': Color(0xFFD35400),
      'group': 'Thumbnail',
    },
  ];

  final List<Map<String, dynamic>> _blogStageConfigs = [
    {
      'name': 'Writing',
      'icon': Icons.draw_outlined,
      'color': Color(0xFF8E44AD),
      'group': 'Content',
    },
    {
      'name': 'Editing',
      'icon': Icons.auto_fix_high_rounded,
      'color': Color(0xFF3F51B5),
      'group': 'Content',
    },
    {
      'name': 'Proofreading',
      'icon': Icons.spellcheck_rounded,
      'color': Color(0xFF00897B),
      'group': 'Content',
    },
    {
      'name': 'Text Crosscheck',
      'icon': Icons.verified_outlined,
      'color': Color(0xFF27AE60),
      'group': 'Content',
    },
    {
      'name': 'Thumbnail Selection',
      'icon': Icons.image_search_rounded,
      'color': Color(0xFFD35400),
      'group': 'Thumbnail',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _streams.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
      final provider = context.read<DevPipelineProvider>();
      provider.setStream(_streams[_tabController.index]);
      provider.fetchDevData();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<DevPipelineProvider>().fetchDevData(role: auth.role, username: auth.username);
      context.read<EventProvider>().fetchDevUsers();
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
                label: Text(
                  _tabController.index == 1
                      ? 'Create SM Post'
                      : (_tabController.index == 2
                          ? 'Create Website Report'
                          : (_tabController.index == 3
                              ? 'Create Blog / Article'
                              : 'Create Event / Topic')),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  if (_tabController.index == 1) {
                    _showCreateSmProjectDialog(context);
                  } else if (_tabController.index == 2) {
                    _showCreateWebProjectDialog(context);
                  } else if (_tabController.index == 3) {
                    _showCreateBlogProjectDialog(context);
                  } else {
                    _showCreateProjectDialog(context);
                  }
                },
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
              : _tabController.index == 1
                  ? _buildSmPipelineView(devProvider)
                  : _tabController.index == 2
                      ? _buildWebPipelineView(devProvider)
                      : _buildBlogPipelineView(devProvider),
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

      void _showReassignDevTaskDialog(DevTask task) {
    showDialog(
      context: context,
      builder: (ctx) => _ReassignDevTaskDialog(
        task: task,
        onSuccess: () {
          context.read<DevPipelineProvider>().fetchDevData();
          context.read<EventProvider>().fetchDevUsers();
        },
      ),
    );
  }

  void _promptAddNewAssignee(
    BuildContext dialogCtx,
    String defaultRole,
    String streamCategory,
    void Function(String name, String email) onAdded,
  ) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog(
      context: dialogCtx,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1A237E)),
            const SizedBox(width: 8),
            Text('Add Assignee ($defaultRole)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                hintText: 'e.g. Rahul Sharma',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'Gmail Address *',
                hintText: 'e.g. rahul@gmail.com',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            Text(
              'Will be automatically written to Dev_Users under $streamCategory.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
            onPressed: () {
              final n = nameCtrl.text.trim();
              final e = emailCtrl.text.trim();
              if (n.isEmpty || e.isEmpty) return;
              Navigator.pop(ctx);
              onAdded(n, e);
            },
            child: const Text('Add Assignee'),
          ),
        ],
      ),
    );
  }

  bool _isCampaignTask(DevTask t) {
    final s = t.stream.toLowerCase();
    final p = t.projectId.toUpperCase();
    return s == 'campaign development' ||
        p.startsWith('CAMP') ||
        p.startsWith('CAM') ||
        (s.isEmpty && !p.startsWith('SMD') && !p.startsWith('WEB') && !p.startsWith('BLOG'));
  }

  bool _isCampaignProject(DevProject p) {
    final s = p.stream.toLowerCase();
    final pid = p.projectId.toUpperCase();
    return s == 'campaign development' ||
        pid.startsWith('CAMP') ||
        pid.startsWith('CAM') ||
        (s.isEmpty && !pid.startsWith('SMD') && !pid.startsWith('WEB') && !pid.startsWith('BLOG'));
  }

  bool _isSmTask(DevTask t) {
    final s = t.stream.toLowerCase();
    final p = t.projectId.toUpperCase();
    return s == 'sm development' || s == 'social media development' || p.startsWith('SMD');
  }

  bool _isSmProject(DevProject p) {
    final s = p.stream.toLowerCase();
    final pid = p.projectId.toUpperCase();
    return s == 'sm development' || s == 'social media development' || pid.startsWith('SMD');
  }

  bool _isWebTask(DevTask t) {
    final s = t.stream.toLowerCase();
    final p = t.projectId.toUpperCase();
    return s == 'website reporting' || s.contains('website') || p.startsWith('WEB');
  }

  bool _isWebProject(DevProject p) {
    final s = p.stream.toLowerCase();
    final pid = p.projectId.toUpperCase();
    return s == 'website reporting' || s.contains('website') || pid.startsWith('WEB');
  }

  bool _isBlogTask(DevTask t) {
    final s = t.stream.toLowerCase();
    final p = t.projectId.toUpperCase();
    return s == 'blogs / articles' || s == 'blog / article' || s.contains('blog') || p.startsWith('BLOG');
  }

  bool _isBlogProject(DevProject p) {
    final s = p.stream.toLowerCase();
    final pid = p.projectId.toUpperCase();
    return s == 'blogs / articles' || s == 'blog / article' || s.contains('blog') || pid.startsWith('BLOG');
  }

  List<Map<String, dynamic>> _filterUsersForCategory(List<Map<String, dynamic>> allUsers, String streamCategory) {
    final target = streamCategory.toLowerCase();
    final filtered = allUsers.where((u) {
      final cat = (u['Category'] ?? u['category'] ?? '').toString().trim().toLowerCase();
      if (cat.isEmpty || cat == 'all') return true;
      if (target.contains('campaign') && (cat.contains('camp') || cat.contains('campaign'))) return true;
      if (target.contains('sm') && (cat.contains('sm') || cat.contains('social'))) return true;
      if (target.contains('web') && (cat.contains('web') || cat.contains('site'))) return true;
      if (target.contains('blog') && (cat.contains('blog') || cat.contains('article'))) return true;
      return cat.contains(target) || target.contains(cat);
    }).toList();
    return filtered.isNotEmpty ? filtered : allUsers;
  }

  static String _mapStageToRole(String stage, String stream) {
    final s = stage.trim().toLowerCase();
    final st = stream.trim().toLowerCase();

    if (s == 'ideation') return 'Campaign Ideator';
    if (s == 'research') return 'Campaign Researcher';
    if (s.contains('sequencing')) return 'Sequencer';
    if (s == 'ppt development') return 'PPT Designer';
    if (s == 'final check' || s.contains('final review')) return 'Final Reviewer';

    if (s.contains('thumb')) return 'Thumbnail Designer';
    if (s == 'raw photos' || s == 'photos clean' || s.contains('photo select')) return 'Raw Photos Selector';
    if (s == 'selected photos' || s == 'photo editing') return 'Photo Editor';
    if (s == 'video editing') return 'Video Editor';
    if (s.contains('media cross')) return 'Media CrossChecker';
    if (s.contains('uploader') || s == 'ready to post') return 'Uploader';
    if (s.contains('crosscheck') || s.contains('cross check')) return 'CrossChecker';
    if (s.contains('proof')) return st.contains('campaign') ? 'Campaign Proofreader' : 'Proofreader';
    if (s.contains('edit')) return st.contains('campaign') ? 'Campaign Editor' : 'Editor';
    if (s.contains('writ')) return st.contains('campaign') ? 'Campaign Writer' : 'Writer';

    return stage;
  }

  static bool _matchesRole(String userRole, String targetRole) {
    final u = userRole.trim().toLowerCase();
    final t = targetRole.trim().toLowerCase();
    if (u.isEmpty || u == 'all' || u == 'admin' || u == 'coordinator' || u == 'lead') {
      return true;
    }
    if (u == t) return true;

    if (t.contains('editor') && !t.contains('photo') && !t.contains('video')) {
      return u.contains('editor') && !u.contains('photo') && !u.contains('video');
    }
    if (t.contains('writer') || t.contains('writ')) {
      return u.contains('writer') || u.contains('writ');
    }
    if (t.contains('proof')) {
      return u.contains('proof');
    }
    if (t.contains('cross')) {
      return u.contains('cross');
    }
    if (t.contains('thumb')) {
      return u.contains('thumb') || u.contains('designer');
    }
    if (t.contains('photo edit') || t == 'selected photos') {
      return u.contains('photo edit') || u.contains('photo editor');
    }
    if (t.contains('photo select') || t.contains('raw photo') || t.contains('photos clean')) {
      return u.contains('photo select') || u.contains('raw photo') || u.contains('photos clean') || u.contains('selector');
    }
    if (t.contains('video')) {
      return u.contains('video');
    }
    if (t.contains('ppt')) {
      return u.contains('ppt');
    }

    return u.contains(t) || t.contains(u);
  }

  Widget _buildCampaignPipelineView(DevPipelineProvider provider) {
    final streamProjects = provider.projects.where(_isCampaignProject).toList();
    final streamTasks = provider.tasks.where(_isCampaignTask).toList();

    if (streamTasks.isEmpty && streamProjects.isEmpty) {
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
    var filteredTasks = streamTasks;
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

    final campaigns = <String>[
      'All',
      ...{
        ...streamProjects.where((p) => p.campaignName.trim().isNotEmpty).map((p) => p.campaignName.trim()),
        ...streamTasks.where((t) => t.campaignName.trim().isNotEmpty).map((t) => t.campaignName.trim()),
      }
    ];

    if (_campaignFilter != 'All') {
      filteredTasks = filteredTasks.where((t) => t.campaignName.toLowerCase() == _campaignFilter.toLowerCase()).toList();
    }

    // Counts for stats banner
    final totalProjects = streamProjects.length;
    final totalTasks = streamTasks.length;
    final readyTasks = streamTasks.where((t) => t.status.toLowerCase() == 'ready').length;
    final doneTasks = streamTasks.where((t) => t.status.toLowerCase() == 'done').length;

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
                width: 200,
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
              const SizedBox(width: 8),
              // Campaign Name Filter Dropdown (Campaign Wise Search)
              Container(
                height: 36,
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: campaigns.contains(_campaignFilter) ? _campaignFilter : 'All',
                    style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                    items: campaigns.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c == 'All' ? 'Campaign: All' : c,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _campaignFilter = v ?? 'All'),
                  ),
                ),
              ),
              if (_campaignFilter != 'All') ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Delete Selected Campaign',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      String targetProjId = '';
                      for (final p in streamProjects) {
                        if (p.campaignName.toLowerCase() == _campaignFilter.toLowerCase()) {
                          targetProjId = p.projectId;
                          break;
                        }
                      }
                      if (targetProjId.isEmpty) {
                        for (final t in streamTasks) {
                          if (t.campaignName.toLowerCase() == _campaignFilter.toLowerCase()) {
                            targetProjId = t.projectId;
                            break;
                          }
                        }
                      }
                      if (targetProjId.isNotEmpty) {
                        _confirmDeleteDevProject(targetProjId, _campaignFilter);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 8),
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

  Widget _buildSmPipelineView(DevPipelineProvider provider) {
    final streamProjects = provider.projects.where(_isSmProject).toList();
    final streamTasks = provider.tasks.where(_isSmTask).toList();

    if (streamTasks.isEmpty && streamProjects.isEmpty) {
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
                  child: const Icon(Icons.share_rounded, size: 52, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No SM Development Posts Yet',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click "Create SM Post" above to start a new social media post with Content, Thumbnail, Media, and Publishing sequential workflows.',
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
    var filteredTasks = streamTasks;
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

    final postNames = <String>[
      'All',
      ...{
        ...streamProjects.where((p) => p.campaignName.trim().isNotEmpty).map((p) => p.campaignName.trim()),
        ...streamTasks.where((t) => t.campaignName.trim().isNotEmpty).map((t) => t.campaignName.trim()),
      }
    ];

    if (_smPostFilter != 'All') {
      filteredTasks = filteredTasks.where((t) => t.campaignName.toLowerCase() == _smPostFilter.toLowerCase()).toList();
    }

    // Counts for stats banner
    final totalPosts = streamProjects.length;
    final totalTasks = streamTasks.length;
    final readyTasks = streamTasks.where((t) => t.status.toLowerCase() == 'ready').length;
    final doneTasks = streamTasks.where((t) => t.status.toLowerCase() == 'done').length;

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
              _buildKpiChip('SM Posts', '$totalPosts', const Color(0xFF1A237E)),
              const SizedBox(width: 8),
              _buildKpiChip('Ready for Action', '$readyTasks', const Color(0xFF00897B)),
              const SizedBox(width: 8),
              _buildKpiChip('Completed Steps', '$doneTasks', Colors.green.shade700),
              const SizedBox(width: 8),
              _buildKpiChip('Total Tasks', '$totalTasks', Colors.grey.shade700),
              const Spacer(),
              // Search Field
              SizedBox(
                width: 200,
                height: 36,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search post / topic...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Post Filter Dropdown
              Container(
                height: 36,
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: postNames.contains(_smPostFilter) ? _smPostFilter : 'All',
                    style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                    items: postNames.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c == 'All' ? 'Post: All' : c,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _smPostFilter = v ?? 'All'),
                  ),
                ),
              ),
              if (_smPostFilter != 'All') ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Delete Selected Post',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete Post', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      String targetProjId = '';
                      for (final p in streamProjects) {
                        if (p.campaignName.toLowerCase() == _smPostFilter.toLowerCase()) {
                          targetProjId = p.projectId;
                          break;
                        }
                      }
                      if (targetProjId.isEmpty) {
                        for (final t in streamTasks) {
                          if (t.campaignName.toLowerCase() == _smPostFilter.toLowerCase()) {
                            targetProjId = t.projectId;
                            break;
                          }
                        }
                      }
                      if (targetProjId.isNotEmpty) {
                        _confirmDeleteDevProject(targetProjId, _smPostFilter);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 8),
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

        // Horizontal Kanban Board for SM Development (13 steps)
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
                        children: _smStageConfigs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final cfg = entry.value;
                          final stageName = cfg['name'] as String;
                          final stageColor = cfg['color'] as Color;
                          final stageIcon = cfg['icon'] as IconData;
                          final group = cfg['group'] as String;

                          final stageTasks = filteredTasks
                              .where((t) => t.stage.toLowerCase() == stageName.toLowerCase())
                              .toList();

                          return _buildKanbanColumn(
                            stepNum: idx + 1,
                            stageName: stageName,
                            tasks: stageTasks,
                            offsetDays: 0,
                            stageColor: stageColor,
                            stageIcon: stageIcon,
                            groupLabel: group,
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

  Widget _buildWebPipelineView(DevPipelineProvider provider) {
    final streamProjects = provider.projects.where(_isWebProject).toList();
    final streamTasks = provider.tasks.where(_isWebTask).toList();

    if (streamTasks.isEmpty && streamProjects.isEmpty) {
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
                    color: const Color(0xFF1A237E).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.language_rounded, size: 52, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Website Reporting Projects Yet',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click "Create Website Report" above to start a new reporting topic with Researched Data sheet, content docs, and photo/thumbnail workflows.',
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
    var filteredTasks = streamTasks;
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

    final ideaNames = <String>[
      'All',
      ...{
        ...streamProjects.where((p) => p.campaignName.trim().isNotEmpty).map((p) => p.campaignName.trim()),
        ...streamTasks.where((t) => t.campaignName.trim().isNotEmpty).map((t) => t.campaignName.trim()),
      }
    ];

    if (_webIdeaFilter != 'All') {
      filteredTasks = filteredTasks.where((t) => t.campaignName.toLowerCase() == _webIdeaFilter.toLowerCase()).toList();
    }

    final totalIdeas = streamProjects.length;
    final totalTasks = streamTasks.length;
    final readyTasks = streamTasks.where((t) => t.status.toLowerCase() == 'ready').length;
    final doneTasks = streamTasks.where((t) => t.status.toLowerCase() == 'done').length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              _buildKpiChip('Ideas', '$totalIdeas', const Color(0xFF1A237E)),
              const SizedBox(width: 8),
              _buildKpiChip('Ready for Action', '$readyTasks', const Color(0xFF00897B)),
              const SizedBox(width: 8),
              _buildKpiChip('Completed Steps', '$doneTasks', Colors.green.shade700),
              const SizedBox(width: 8),
              _buildKpiChip('Total Tasks', '$totalTasks', Colors.grey.shade700),
              const Spacer(),
              SizedBox(
                width: 200,
                height: 36,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search idea / assignee...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 36,
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: ideaNames.contains(_webIdeaFilter) ? _webIdeaFilter : 'All',
                    style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                    items: ideaNames.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c == 'All' ? 'Idea: All' : c,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _webIdeaFilter = v ?? 'All'),
                  ),
                ),
              ),
              if (_webIdeaFilter != 'All') ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Delete Selected Idea',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete Idea', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      String targetProjId = '';
                      for (final p in streamProjects) {
                        if (p.campaignName.toLowerCase() == _webIdeaFilter.toLowerCase()) {
                          targetProjId = p.projectId;
                          break;
                        }
                      }
                      if (targetProjId.isEmpty) {
                        for (final t in streamTasks) {
                          if (t.campaignName.toLowerCase() == _webIdeaFilter.toLowerCase()) {
                            targetProjId = t.projectId;
                            break;
                          }
                        }
                      }
                      if (targetProjId.isNotEmpty) {
                        _confirmDeleteDevProject(targetProjId, _webIdeaFilter);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 8),
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
                        children: _webStageConfigs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final cfg = entry.value;
                          final stageName = cfg['name'] as String;
                          final stageColor = cfg['color'] as Color;
                          final stageIcon = cfg['icon'] as IconData;
                          final group = cfg['group'] as String;

                          final stageTasks = filteredTasks
                              .where((t) => t.stage.toLowerCase() == stageName.toLowerCase())
                              .toList();

                          return _buildKanbanColumn(
                            stepNum: idx + 1,
                            stageName: stageName,
                            tasks: stageTasks,
                            offsetDays: 0,
                            stageColor: stageColor,
                            stageIcon: stageIcon,
                            groupLabel: group,
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

  Widget _buildBlogPipelineView(DevPipelineProvider provider) {
    final streamProjects = provider.projects.where(_isBlogProject).toList();
    final streamTasks = provider.tasks.where(_isBlogTask).toList();

    if (streamTasks.isEmpty && streamProjects.isEmpty) {
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
                    color: const Color(0xFF1A237E).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.article_rounded, size: 52, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Blog / Article Projects Yet',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Click "Create Blog / Article" above to start a new article topic with Researched Doc, content docs, and thumbnail selection workflow.',
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
    var filteredTasks = streamTasks;
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

    final ideaNames = <String>[
      'All',
      ...{
        ...streamProjects.where((p) => p.campaignName.trim().isNotEmpty).map((p) => p.campaignName.trim()),
        ...streamTasks.where((t) => t.campaignName.trim().isNotEmpty).map((t) => t.campaignName.trim()),
      }
    ];

    if (_blogIdeaFilter != 'All') {
      filteredTasks = filteredTasks.where((t) => t.campaignName.toLowerCase() == _blogIdeaFilter.toLowerCase()).toList();
    }

    final totalArticles = streamProjects.length;
    final totalTasks = streamTasks.length;
    final readyTasks = streamTasks.where((t) => t.status.toLowerCase() == 'ready').length;
    final doneTasks = streamTasks.where((t) => t.status.toLowerCase() == 'done').length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              _buildKpiChip('Articles', '$totalArticles', const Color(0xFF1A237E)),
              const SizedBox(width: 8),
              _buildKpiChip('Ready for Action', '$readyTasks', const Color(0xFF00897B)),
              const SizedBox(width: 8),
              _buildKpiChip('Completed Steps', '$doneTasks', Colors.green.shade700),
              const SizedBox(width: 8),
              _buildKpiChip('Total Tasks', '$totalTasks', Colors.grey.shade700),
              const Spacer(),
              SizedBox(
                width: 200,
                height: 36,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search article / assignee...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 36,
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.grey.shade50,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: ideaNames.contains(_blogIdeaFilter) ? _blogIdeaFilter : 'All',
                    style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                    items: ideaNames.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c == 'All' ? 'Article: All' : c,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _blogIdeaFilter = v ?? 'All'),
                  ),
                ),
              ),
              if (_blogIdeaFilter != 'All') ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Delete Selected Article Idea',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete Article', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      String targetProjId = '';
                      for (final p in streamProjects) {
                        if (p.campaignName.toLowerCase() == _blogIdeaFilter.toLowerCase()) {
                          targetProjId = p.projectId;
                          break;
                        }
                      }
                      if (targetProjId.isEmpty) {
                        for (final t in streamTasks) {
                          if (t.campaignName.toLowerCase() == _blogIdeaFilter.toLowerCase()) {
                            targetProjId = t.projectId;
                            break;
                          }
                        }
                      }
                      if (targetProjId.isNotEmpty) {
                        _confirmDeleteDevProject(targetProjId, _blogIdeaFilter);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(width: 8),
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
                        children: _blogStageConfigs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final cfg = entry.value;
                          final stageName = cfg['name'] as String;
                          final stageColor = cfg['color'] as Color;
                          final stageIcon = cfg['icon'] as IconData;
                          final group = cfg['group'] as String;

                          final stageTasks = filteredTasks
                              .where((t) => t.stage.toLowerCase() == stageName.toLowerCase())
                              .toList();

                          return _buildKanbanColumn(
                            stepNum: idx + 1,
                            stageName: stageName,
                            tasks: stageTasks,
                            offsetDays: 0,
                            stageColor: stageColor,
                            stageIcon: stageIcon,
                            groupLabel: group,
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

  Widget _buildKanbanColumn({
    required int stepNum,
    required String stageName,
    required List<DevTask> tasks,
    required int offsetDays,
    required Color stageColor,
    required IconData stageIcon,
    String? groupLabel,
  }) {
    final sortedTasks = List<DevTask>.from(tasks);
    sortedTasks.sort((a, b) => compareDueDates(
      a.dueDate,
      b.dueDate,
      secondaryCompare: () {
        final aDone = a.status.toLowerCase() == 'done';
        final bDone = b.status.toLowerCase() == 'done';
        if (!aDone && bDone) return -1;
        if (aDone && !bDone) return 1;
        final aReady = a.status.toLowerCase() == 'ready';
        final bReady = b.status.toLowerCase() == 'ready';
        if (aReady && !bReady) return -1;
        if (!aReady && bReady) return 1;
        final numA = int.tryParse(a.projectId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final numB = int.tryParse(b.projectId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return numA.compareTo(numB);
      },
    ));

    final readyCount = sortedTasks.where((t) => t.status.toLowerCase() == 'ready').length;
    final expiredCount = sortedTasks.where((t) => isDueDateExpired(t.dueDate, isDone: t.status.toLowerCase() == 'done')).length;

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
                                (groupLabel != null && groupLabel.isNotEmpty)
                                    ? 'Workflow: $groupLabel'
                                    : 'Cadence: +$offsetDays days',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                              if (readyCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$readyCount Allotted',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ),
                              ],
                              if (expiredCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade600,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$expiredCount Expired',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
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
                        '${sortedTasks.length}',
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
            child: sortedTasks.isEmpty
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
                    itemCount: sortedTasks.length,
                    itemBuilder: (context, i) => _buildTaskCard(sortedTasks[i], stepNum, stageColor),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DevTask task, int stepNum, Color stageColor) {
    final isDone = task.status.toLowerCase() == 'done';
    final isReady = task.status.toLowerCase() == 'ready';
    final isExpired = isDueDateExpired(task.dueDate, isDone: isDone);
    final isSm = task.stream == 'SM Development' || task.projectId.startsWith('SMD');
    final isWeb = task.stream == 'Website Reporting' || task.projectId.startsWith('WEB');
    final isBlog = task.stream == 'Blogs / Articles' || task.projectId.startsWith('BLOG');
    final isPptStage = !isSm && !isWeb && !isBlog && task.stage.toLowerCase() == 'ppt development';
    final isPostPptStage = !isSm && !isWeb && !isBlog && stepNum >= 6;

    final devProvider = context.read<DevPipelineProvider>();
    String cardPptFolder = task.pptFolderLink.trim();
    if (!isSm && cardPptFolder.isEmpty) {
      try {
        final pptTask = devProvider.tasks.firstWhere(
          (t) => t.projectId == task.projectId && t.stage.toLowerCase() == 'ppt development',
        );
        cardPptFolder = pptTask.docLink.isNotEmpty ? pptTask.docLink : pptTask.folderLink;
      } catch (_) {}
    }

    String cardWritingDoc = task.prevDocLink.trim().isNotEmpty ? task.prevDocLink.trim() : task.writingDocLink.trim();
    if (!isSm && cardWritingDoc.isEmpty) {
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
      statusBadgeBg = const Color(0xFFFFF9C4);
      statusBadgeText = const Color(0xFFF57F17);
      statusDisplay = 'Allotted';
    } else {
      statusBadgeBg = Colors.grey.shade100;
      statusBadgeText = Colors.grey.shade700;
      statusDisplay = 'Waiting';
    }

    return Card(
      elevation: isExpired ? 3 : (isReady ? 3 : 1),
      margin: const EdgeInsets.only(bottom: 10),
      color: isDone
          ? Colors.grey.shade50
          : (isExpired ? const Color(0xFFFFEBEE) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpired
              ? Colors.red.shade400
              : (isReady
                  ? Colors.amber.shade600
                  : (isDone ? Colors.green.shade200 : Colors.grey.shade300)),
          width: isExpired ? 1.8 : (isReady ? 1.8 : 1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTaskDetailsDialog(task, stepNum, stageColor),
        child: Container(
          decoration: BoxDecoration(
            color: isDone
                ? Colors.transparent
                : (isExpired ? const Color(0xFFFFEBEE) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: isExpired
                    ? Colors.red.shade700
                    : (isDone ? Colors.green : (isReady ? Colors.amber.shade700 : stageColor)),
                width: isExpired ? 6 : 4,
              ),
              top: isExpired ? BorderSide(color: Colors.red.shade300, width: 1.5) : BorderSide.none,
              right: isExpired ? BorderSide(color: Colors.red.shade300, width: 1.5) : BorderSide.none,
              bottom: isExpired ? BorderSide(color: Colors.red.shade300, width: 1.5) : BorderSide.none,
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
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Delete Project / Post',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _confirmDeleteDevProject(task.projectId, task.campaignName),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.delete_outline, size: 14, color: Colors.red.shade400),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isExpired) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'EXPIRED',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
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

              // Campaign & Session Name / Post & Topic / Idea Name
              Text(
                task.campaignName.isNotEmpty
                    ? task.campaignName
                    : (isSm ? 'Post Name' : ((isWeb || isBlog) ? 'Idea' : 'Campaign Topic')),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (task.sessionName.isNotEmpty) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSm ? Colors.purple.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isSm ? 'Topic: ${task.sessionName}' : 'Session: ${task.sessionName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSm ? Colors.purple.shade900 : Colors.blue.shade900,
                      fontWeight: FontWeight.w500,
                    ),
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
                  Tooltip(
                    message: 'Reassign / Change Assignee',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _showReassignDevTaskDialog(task),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(Icons.edit_outlined, size: 14, color: Colors.indigo.shade600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isExpired ? Icons.alarm_off : Icons.calendar_today_outlined,
                    size: 12,
                    color: isExpired ? Colors.red.shade700 : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isExpired ? 'Expired' : 'Due'}: ${task.dueDate.isNotEmpty ? formatDueDateDisplay(task.dueDate) : 'TBD'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isExpired ? Colors.red.shade700 : Colors.grey.shade700,
                      fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                    ),
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
                  if (isWeb) ...[
                    // Website Reporting Card Actions
                    if (task.docLink.isNotEmpty && (task.docLink.contains('document/d') || !task.docLink.contains('folders')))
                      InkWell(
                        onTap: () => _openUrl(task.docLink),
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
                              Text('Doc', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      )
                    else if (task.docLink.isNotEmpty && task.docLink.contains('folders'))
                      InkWell(
                        onTap: () => _openUrl(task.docLink),
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
                              Icon(Icons.folder_open_rounded, size: 13, color: Colors.orange),
                              SizedBox(width: 4),
                              Text('Folder', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    if (task.researchedDataLink.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => _openUrl(task.researchedDataLink),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.table_chart_outlined, size: 13, color: Colors.green),
                              SizedBox(width: 4),
                              Text('Sheet', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (task.folderLink.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => _openUrl(task.folderLink),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.folder_shared_outlined, size: 13, color: Colors.amber),
                              SizedBox(width: 4),
                              Text('Drive', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ] else if (isBlog) ...[
                    // Blogs / Articles Card Actions
                    if (task.docLink.isNotEmpty && (task.docLink.contains('document/d') || !task.docLink.contains('folders')))
                      InkWell(
                        onTap: () => _openUrl(task.docLink),
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
                              Text('Doc', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    if (task.thumbnailFolderLink.isNotEmpty || (task.docLink.isNotEmpty && task.docLink.contains('folders'))) ...[
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => _openUrl(task.thumbnailFolderLink.isNotEmpty ? task.thumbnailFolderLink : task.docLink),
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
                              Icon(Icons.image_outlined, size: 13, color: Colors.deepOrange),
                              SizedBox(width: 4),
                              Text('Thumb', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (task.researchedDocLink.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => _openUrl(task.researchedDocLink),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.indigo.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.menu_book_rounded, size: 13, color: Colors.indigo),
                              SizedBox(width: 4),
                              Text('Researched', style: TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (task.folderLink.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => _openUrl(task.folderLink),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.folder_shared_outlined, size: 13, color: Colors.amber),
                              SizedBox(width: 4),
                              Text('Drive', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ] else if (isSm) ...[
                    // SM Development Card Actions
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
                    if (task.folderLink.isNotEmpty) ...[
                      if (task.docLink.isNotEmpty) const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _openUrl(task.folderLink),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.folder_open_rounded, size: 13, color: Colors.orange),
                              SizedBox(width: 4),
                              Text('Drive', style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ] else if (isPptStage) ...[
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
            final isSm = task.stream == 'SM Development' || task.projectId.startsWith('SMD');
            final isWeb = task.stream == 'Website Reporting' || task.projectId.startsWith('WEB');
            final isBlog = task.stream == 'Blogs / Articles' || task.projectId.startsWith('BLOG');
            final isDone = task.status.toLowerCase() == 'done';
            final hasPreviousStage = stepNum > 1;
            final isPptStage = !isSm && !isWeb && !isBlog && task.stage.toLowerCase() == 'ppt development';
            final isPostPptStage = !isSm && !isWeb && !isBlog && stepNum >= 6;

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

            String bestResearchedData = task.researchedDataLink.isNotEmpty ? task.researchedDataLink : (proj?.researchedDataLink ?? '');
            String bestResearchedDoc = task.researchedDocLink.isNotEmpty ? task.researchedDocLink : (proj?.researchedDocLink ?? '');
            String bestThumbnailFolder = task.thumbnailFolderLink.isNotEmpty ? task.thumbnailFolderLink : (proj?.thumbnailFolderLink ?? '');

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
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Delete Project / Post',
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDeleteDevProject(task.projectId, task.campaignName);
                      },
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
                            _infoRow(isSm ? 'Post Name' : ((isWeb || isBlog) ? 'Idea' : 'Campaign'), task.campaignName),
                            if (task.sessionName.isNotEmpty) _infoRow(isSm ? 'Post Topic' : 'Session', task.sessionName),
                            if (task.festivalsIncluded.isNotEmpty) _infoRow('Festivals / Days', task.festivalsIncluded),
                            Row(
                              children: [
                                Expanded(
                                  child: _infoRow('Assignee', '${task.assignee} ${task.assigneeEmail.isNotEmpty ? "(${task.assigneeEmail})" : ""}'),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.person_search_rounded, size: 15, color: Color(0xFF1A237E)),
                                  label: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showReassignDevTaskDialog(task);
                                  },
                                ),
                              ],
                            ),
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

                      // ── Workspace Section (Tailored for Web, Blog, SM, PPT Folder / Docs) ──
                      if (isWeb) ...[
                        // Website Reporting
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.web_rounded, color: stageColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Stage: ${task.stage}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF14532D)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Website Reporting workflow. Content is carried forward from stage to stage. Access the Researched Data sheet, stage Docs/Folders below.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 12),
                              if (task.docLink.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: task.docLink.contains('folders') ? Colors.orange.shade800 : const Color(0xFF1A237E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: Icon(task.docLink.contains('folders') ? Icons.folder_open_rounded : Icons.open_in_new, size: 18),
                                    label: Text(
                                      task.docLink.contains('folders') ? 'Open ${task.stage} Folder' : 'Open ${task.stage} Doc',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _openUrl(task.docLink),
                                  ),
                                ),
                              if (bestResearchedData.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF107C41),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.table_chart_rounded, size: 18),
                                    label: const Text('Open "Researched Data" Google Sheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    onPressed: () => _openUrl(bestResearchedData),
                                  ),
                                ),
                              ],
                              if (bestThumbnailFolder.isNotEmpty && task.stage.toLowerCase() != 'thumbnail selection') ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      side: BorderSide(color: Colors.orange.shade800),
                                    ),
                                    icon: Icon(Icons.image_outlined, size: 17, color: Colors.orange.shade800),
                                    label: Text('Open Thumbnail Folder', style: TextStyle(color: Colors.orange.shade800, fontSize: 13)),
                                    onPressed: () => _openUrl(bestThumbnailFolder),
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
                                      side: const BorderSide(color: Color(0xFF14532D)),
                                    ),
                                    icon: const Icon(Icons.folder_shared_outlined, size: 17, color: Color(0xFF14532D)),
                                    label: const Text('Open Idea Drive Folder', style: TextStyle(color: Color(0xFF14532D), fontSize: 13)),
                                    onPressed: () => _openUrl(task.folderLink),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (isBlog) ...[
                        // Blogs / Articles
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDDD6FE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.article_rounded, color: stageColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Stage: ${task.stage}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF5B21B6)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Blogs / Articles pipeline. Content forwards through Docs with dedicated Researched Doc and Thumbnail selection.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 12),
                              if (task.docLink.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: task.docLink.contains('folders') ? Colors.orange.shade800 : const Color(0xFF1A237E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: Icon(task.docLink.contains('folders') ? Icons.folder_open_rounded : Icons.open_in_new, size: 18),
                                    label: Text(
                                      task.docLink.contains('folders') ? 'Open ${task.stage} Folder' : 'Open ${task.stage} Doc',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _openUrl(task.docLink),
                                  ),
                                ),
                              if (bestResearchedDoc.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4338CA),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                                    label: const Text('Open "Researched Doc" Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    onPressed: () => _openUrl(bestResearchedDoc),
                                  ),
                                ),
                              ],
                              if (bestThumbnailFolder.isNotEmpty && task.stage.toLowerCase() != 'thumbnail selection') ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      side: BorderSide(color: Colors.orange.shade800),
                                    ),
                                    icon: Icon(Icons.image_outlined, size: 17, color: Colors.orange.shade800),
                                    label: Text('Open Thumbnail Folder', style: TextStyle(color: Colors.orange.shade800, fontSize: 13)),
                                    onPressed: () => _openUrl(bestThumbnailFolder),
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
                                      side: const BorderSide(color: Color(0xFF5B21B6)),
                                    ),
                                    icon: const Icon(Icons.folder_shared_outlined, size: 17, color: Color(0xFF5B21B6)),
                                    label: const Text('Open Idea Drive Folder', style: TextStyle(color: Color(0xFF5B21B6), fontSize: 13)),
                                    onPressed: () => _openUrl(task.folderLink),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (isSm) ...[
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
                                  Icon(Icons.workspace_premium_rounded, color: stageColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Stage: ${task.stage}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Stage assigned to ${task.assignee}. Content and assets are automatically carried forward upon marking Done & Handoff.',
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
                                ),
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
                                    label: const Text('Open Post Drive Folder', style: TextStyle(color: Color(0xFF1A237E), fontSize: 13)),
                                    onPressed: () => _openUrl(task.folderLink),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (isPptStage) ...[
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
                      if (!isSm && !isWeb && !isBlog && hasIecMaterial) ...[
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
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                  label: const Text('Delete Project', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeleteDevProject(task.projectId, task.campaignName);
                  },
                ),
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

  void _confirmDeleteDevProject(String projectId, String projectName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Project / Post?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$projectName" (#$projectId)?\n\n'
          'This will permanently delete this post/project and all its assigned workflow tasks from the Development pipeline.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              final devProvider = context.read<DevPipelineProvider>();
              final success = await devProvider.deleteProject(projectId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? '✓ Project #$projectId ("$projectName") deleted successfully.'
                        : 'Failed to delete project #$projectId.'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executeMarkDone(
    BuildContext dialogCtx,
    DevTask task,
    void Function(void Function()) setDialogState,
  ) async {
    // Thumbnail Processing check: "Edited Thumbnail" folder under "Selected (Edited)" must not be empty
    final stageLower = task.stage.toLowerCase();
    if (stageLower == 'thumbnail processing' || stageLower == 'thumbnailprocessing') {
      final eventProvider = context.read<EventProvider>();
      final res = await eventProvider.checkThumbnailFolderNotEmpty(
        task.projectId,
        folderLink: task.thumbnailFolderLink.isNotEmpty ? task.thumbnailFolderLink : task.folderLink,
      );
      if (res['notEmpty'] != true) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text('Thumbnail Required'),
                ],
              ),
              content: Text(res['error'] ?? 'The "Edited Thumbnail" folder under "Selected (Edited)" is empty! Please upload edited thumbnail files first.'),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

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

    // Read all users from eventProvider filtered by category
    final eventProvider = context.read<EventProvider>();
    final users = List<Map<String, dynamic>>.from(_filterUsersForCategory(eventProvider.devUsers, 'Campaign Development'));

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
                        final expectedRole = _mapStageToRole(st, 'Campaign Development');
                        final stageUsers = users.where((u) => _matchesRole(u['Role']?.toString() ?? u['role']?.toString() ?? '', expectedRole)).toList();
                        final displayUsers = stageUsers.isNotEmpty ? stageUsers : users;

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
                                  hint: Text('Select $expectedRole', style: const TextStyle(fontSize: 12)),
                                  value: assignees[st]?['email']?.isNotEmpty == true ? assignees[st]!['email'] : null,
                                  items: [
                                    ...displayUsers.map((u) {
                                      final uEmail = u['Email']?.toString() ?? u['email']?.toString() ?? '';
                                      final uName = u['Name']?.toString() ?? u['name']?.toString() ?? uEmail;
                                      final uRole = u['Role']?.toString() ?? u['role']?.toString() ?? '';
                                      return DropdownMenuItem<String>(
                                        value: uEmail,
                                        child: Text('$uName ($uRole)', style: const TextStyle(fontSize: 12)),
                                      );
                                    }),
                                    const DropdownMenuItem<String>(
                                      value: '__add_new__',
                                      child: Text('+ Add New Assignee...', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val == '__add_new__') {
                                      _promptAddNewAssignee(ctx, st, 'Campaign Development', (name, email) {
                                        final newUser = {
                                          'Email': email,
                                          'Name': name,
                                          'Role': st,
                                          'Category': 'Campaign Development'
                                        };
                                        setDialogState(() {
                                          users.add(newUser);
                                          assignees[st] = {
                                            'name': name,
                                            'email': email,
                                          };
                                        });
                                      });
                                    } else if (val != null) {
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
                    final scaffold = ScaffoldMessenger.of(context);
                    final devProv = context.read<DevPipelineProvider>();
                    Navigator.pop(ctx);
                    final res = await devProv.createProject(
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
                        scaffold.showSnackBar(
                          SnackBar(
                            content: Text('Created ${res["projectId"]} successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        scaffold.showSnackBar(
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

  void _showCreateSmProjectDialog(BuildContext context) {
    final postNameCtrl = TextEditingController();
    final postTopicCtrl = TextEditingController();
    final festivalsCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime completionDate = DateTime.now().add(const Duration(days: 10));

    // 10 Roles matching existing Social Media posts
    final smRoles = [
      {'role': 'Writer', 'stage': 'Writing', 'group': 'Content'},
      {'role': 'Editor', 'stage': 'Editing', 'group': 'Content'},
      {'role': 'Proofreader', 'stage': 'Proofreading', 'group': 'Content'},
      {'role': 'CrossChecker', 'stage': 'Text Crosscheck', 'group': 'Content'},
      {'role': 'Thumbnail Designer', 'stage': 'Thumbnail (Select/Process/Check)', 'group': 'Thumbnail'},
      {'role': 'Photo Editor', 'stage': 'Photo Editing', 'group': 'Media'},
      {'role': 'Video Editor', 'stage': 'Video Editing', 'group': 'Media'},
      {'role': 'Media CrossChecker', 'stage': 'Media Cross Check (1 & 2)', 'group': 'Media'},
      {'role': 'Uploader', 'stage': 'Ready to Post', 'group': 'Publishing'},
      {'role': 'Photo Selector', 'stage': 'Photos Clean', 'group': 'Clean-up'},
    ];

    final eventProvider = context.read<EventProvider>();
    final users = List<Map<String, dynamic>>.from(_filterUsersForCategory(eventProvider.devUsers, 'SM Development'));

    final smAssignees = <String, Map<String, String>>{};
    for (final r in smRoles) {
      smAssignees[r['role']!] = {'name': '', 'email': ''};
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
                  Icon(Icons.share_rounded, color: Color(0xFF1A237E)),
                  SizedBox(width: 10),
                  Text('Create SM Development Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                                'Creates Post folder under Delhi (IN) > Head Office > SM Development with Raw, Selected, Edited folders, and individual stage Docs with automated forwarding.',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('1. Post Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: postNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Post Name *',
                          hintText: 'e.g. World Environment Day Post 2026',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: postTopicCtrl,
                        decoration: InputDecoration(
                          labelText: 'Post Topic',
                          hintText: 'e.g. Tree Plantation Drive Highlights',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: festivalsCtrl,
                        decoration: InputDecoration(
                          labelText: 'Festivals & Days Included',
                          hintText: 'e.g. Environment Day / World Earth Week',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
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
                                        const Text('End Date (Completion)', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                      const Text('2. Role Assignments (Content, Thumbnail, Media, Publish)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      ...smRoles.map((r) {
                        final roleName = r['role']!;
                        final stageName = r['stage']!;
                        final groupName = r['group']!;
                        final stageUsers = users.where((u) => _matchesRole(u['Role']?.toString() ?? u['role']?.toString() ?? '', roleName)).toList();
                        final displayUsers = stageUsers.isNotEmpty ? stageUsers : users;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 220,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      roleName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$groupName • $stageName',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  ],
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
                                  hint: Text('Select $roleName', style: const TextStyle(fontSize: 12)),
                                  value: smAssignees[roleName]?['email']?.isNotEmpty == true ? smAssignees[roleName]!['email'] : null,
                                  items: [
                                    ...displayUsers.map((u) {
                                      final uEmail = u['Email']?.toString() ?? u['email']?.toString() ?? '';
                                      final uName = u['Name']?.toString() ?? u['name']?.toString() ?? uEmail;
                                      final uRole = u['Role']?.toString() ?? u['role']?.toString() ?? '';
                                      return DropdownMenuItem<String>(
                                        value: uEmail,
                                        child: Text('$uName ($uRole)', style: const TextStyle(fontSize: 12)),
                                      );
                                    }),
                                    const DropdownMenuItem<String>(
                                      value: '__add_new__',
                                      child: Text('+ Add New Assignee...', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val == '__add_new__') {
                                      _promptAddNewAssignee(ctx, roleName, 'SM Development', (name, email) {
                                        final newUser = {
                                          'Email': email,
                                          'Name': name,
                                          'Role': roleName,
                                          'Category': 'SM Development'
                                        };
                                        setDialogState(() {
                                          users.add(newUser);
                                          smAssignees[roleName] = {
                                            'name': name,
                                            'email': email,
                                          };
                                        });
                                      });
                                    } else if (val != null) {
                                      final matched = users.firstWhere(
                                        (u) => (u['Email']?.toString() ?? u['email']?.toString()) == val,
                                        orElse: () => users.first,
                                      );
                                      final mName = matched['Name']?.toString() ?? matched['name']?.toString() ?? val;
                                      final mEmail = matched['Email']?.toString() ?? matched['email']?.toString() ?? val;
                                      setDialogState(() {
                                        smAssignees[roleName] = {
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
                  label: const Text('Create Post & Setup Flow', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (postNameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter Post Name'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    final scaffold = ScaffoldMessenger.of(context);
                    final devProv = context.read<DevPipelineProvider>();
                    Navigator.pop(ctx);

                    // Build full stage assignment map
                    final assigneesPayload = <String, Map<String, String>>{
                      'Writing': smAssignees['Writer'] ?? {'name': '', 'email': ''},
                      'Editing': smAssignees['Editor'] ?? {'name': '', 'email': ''},
                      'Proofreading': smAssignees['Proofreader'] ?? {'name': '', 'email': ''},
                      'Text Crosscheck': smAssignees['CrossChecker'] ?? {'name': '', 'email': ''},
                      'Thumbnail Selection': smAssignees['Thumbnail Designer'] ?? {'name': '', 'email': ''},
                      'Thumbnail Processing': smAssignees['Thumbnail Designer'] ?? {'name': '', 'email': ''},
                      'Thumbnail Cross checking': smAssignees['Thumbnail Designer'] ?? {'name': '', 'email': ''},
                      'Photo Editing': smAssignees['Photo Editor'] ?? {'name': '', 'email': ''},
                      'Video Editing': smAssignees['Video Editor'] ?? {'name': '', 'email': ''},
                      'Media Cross Check': smAssignees['Media CrossChecker'] ?? {'name': '', 'email': ''},
                      'Media Final Cross check': smAssignees['Media CrossChecker'] ?? {'name': '', 'email': ''},
                      'Ready to Post': smAssignees['Uploader'] ?? {'name': '', 'email': ''},
                      'Photos Clean': smAssignees['Photo Selector'] ?? {'name': '', 'email': ''},
                      ...smAssignees,
                    };

                    final res = await devProv.createProject(
                          stream: 'SM Development',
                          campaignName: postNameCtrl.text.trim(),
                          sessionName: postTopicCtrl.text.trim(),
                          duration: '',
                          festivals: festivalsCtrl.text.trim(),
                          startDate: DateFormat('d-MMM-yyyy').format(startDate),
                          completionDate: DateFormat('d-MMM-yyyy').format(completionDate),
                          iecContent: false,
                          iecDesigning: false,
                          iecProofread: false,
                          iecFinalCheck: false,
                          assignees: assigneesPayload,
                        );

                    if (mounted) {
                      if (res['success'] == true) {
                        scaffold.showSnackBar(
                          SnackBar(
                            content: Text('Created ${res["projectId"]} successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        scaffold.showSnackBar(
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

  void _showCreateWebProjectDialog(BuildContext context) {
    final ideaCtrl = TextEditingController();
    final festivalsCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime completionDate = DateTime.now().add(const Duration(days: 10));

    final webRoles = [
      {'role': 'Writer', 'stage': 'Writing', 'group': 'Content'},
      {'role': 'Editor', 'stage': 'Editing', 'group': 'Content'},
      {'role': 'Proofreader', 'stage': 'Proofreading', 'group': 'Content'},
      {'role': 'CrossChecker', 'stage': 'Text Crosscheck', 'group': 'Content'},
      {'role': 'Raw Photos Selector', 'stage': 'Raw Photos', 'group': 'Media'},
      {'role': 'Photo Editor', 'stage': 'Selected Photos', 'group': 'Media'},
      {'role': 'Thumbnail Designer', 'stage': 'Thumbnail Selection', 'group': 'Thumbnail'},
    ];

    final eventProvider = context.read<EventProvider>();
    final users = List<Map<String, dynamic>>.from(_filterUsersForCategory(eventProvider.devUsers, 'Website Reporting'));

    final webAssignees = <String, Map<String, String>>{};
    for (final r in webRoles) {
      webAssignees[r['role']!] = {'name': '', 'email': ''};
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
                  Icon(Icons.language_rounded, color: Color(0xFF107C41)),
                  SizedBox(width: 10),
                  Text('Create Website Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.table_chart_rounded, color: Color(0xFF107C41), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Creates Idea folder with "Researched Data" Sheet, Raw Photos & Selected Photos folders (with Thumbnail folder inside), and Docs with content forwarding.',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('1. Website Report Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ideaCtrl,
                        decoration: InputDecoration(
                          labelText: 'Idea *',
                          hintText: 'e.g. Annual Youth Summit 2026 Key Takeaways',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: festivalsCtrl,
                        decoration: InputDecoration(
                          labelText: 'Festivals & Days Included',
                          hintText: 'e.g. National Youth Day / International Anti-Drug Day',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
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
                                        const Text('End Date (Completion)', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                      const Text('2. Stage Assignees (Content, Media, Thumbnail)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      ...webRoles.map((r) {
                        final roleName = r['role']!;
                        final stageName = r['stage']!;
                        final groupName = r['group']!;
                        final stageUsers = users.where((u) => _matchesRole(u['Role']?.toString() ?? u['role']?.toString() ?? '', roleName)).toList();
                        final displayUsers = stageUsers.isNotEmpty ? stageUsers : users;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 220,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      roleName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$groupName • $stageName',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  ],
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
                                  hint: Text('Select $roleName', style: const TextStyle(fontSize: 12)),
                                  value: webAssignees[roleName]?['email']?.isNotEmpty == true ? webAssignees[roleName]!['email'] : null,
                                  items: [
                                    ...displayUsers.map((u) {
                                      final uEmail = u['Email']?.toString() ?? u['email']?.toString() ?? '';
                                      final uName = u['Name']?.toString() ?? u['name']?.toString() ?? uEmail;
                                      final uRole = u['Role']?.toString() ?? u['role']?.toString() ?? '';
                                      return DropdownMenuItem<String>(
                                        value: uEmail,
                                        child: Text('$uName ($uRole)', style: const TextStyle(fontSize: 12)),
                                      );
                                    }),
                                    const DropdownMenuItem<String>(
                                      value: '__add_new__',
                                      child: Text('+ Add New Assignee...', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val == '__add_new__') {
                                      _promptAddNewAssignee(ctx, roleName, 'Website Reporting', (name, email) {
                                        final newUser = {
                                          'Email': email,
                                          'Name': name,
                                          'Role': roleName,
                                          'Category': 'Website Reporting'
                                        };
                                        setDialogState(() {
                                          users.add(newUser);
                                          webAssignees[roleName] = {
                                            'name': name,
                                            'email': email,
                                          };
                                        });
                                      });
                                    } else if (val != null) {
                                      final matched = users.firstWhere(
                                        (u) => (u['Email']?.toString() ?? u['email']?.toString()) == val,
                                        orElse: () => users.first,
                                      );
                                      final mName = matched['Name']?.toString() ?? matched['name']?.toString() ?? val;
                                      final mEmail = matched['Email']?.toString() ?? matched['email']?.toString() ?? val;
                                      setDialogState(() {
                                        webAssignees[roleName] = {
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
                    backgroundColor: const Color(0xFF107C41),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Create Report & Setup Flow', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (ideaCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter Idea'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    final scaffold = ScaffoldMessenger.of(context);
                    final devProv = context.read<DevPipelineProvider>();
                    Navigator.pop(ctx);

                    final assigneesPayload = <String, Map<String, String>>{
                      'Writing': webAssignees['Writer'] ?? {'name': '', 'email': ''},
                      'Editing': webAssignees['Editor'] ?? {'name': '', 'email': ''},
                      'Proofreading': webAssignees['Proofreader'] ?? {'name': '', 'email': ''},
                      'Text Crosscheck': webAssignees['CrossChecker'] ?? {'name': '', 'email': ''},
                      'Raw Photos': webAssignees['Raw Photos Selector'] ?? {'name': '', 'email': ''},
                      'Selected Photos': webAssignees['Photo Editor'] ?? {'name': '', 'email': ''},
                      'Thumbnail Selection': webAssignees['Thumbnail Designer'] ?? {'name': '', 'email': ''},
                      ...webAssignees,
                    };

                    final res = await devProv.createProject(
                      stream: 'Website Reporting',
                      campaignName: ideaCtrl.text.trim(),
                      sessionName: '',
                      duration: '',
                      festivals: festivalsCtrl.text.trim(),
                      startDate: DateFormat('d-MMM-yyyy').format(startDate),
                      completionDate: DateFormat('d-MMM-yyyy').format(completionDate),
                      iecContent: false,
                      iecDesigning: false,
                      iecProofread: false,
                      iecFinalCheck: false,
                      assignees: assigneesPayload,
                    );

                    if (mounted) {
                      if (res['success'] == true) {
                        scaffold.showSnackBar(
                          SnackBar(
                            content: Text('Created ${res["projectId"]} successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        scaffold.showSnackBar(
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

  void _showCreateBlogProjectDialog(BuildContext context) {
    final ideaCtrl = TextEditingController();
    final festivalsCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime completionDate = DateTime.now().add(const Duration(days: 10));

    final blogRoles = [
      {'role': 'Writer', 'stage': 'Writing', 'group': 'Content'},
      {'role': 'Editor', 'stage': 'Editing', 'group': 'Content'},
      {'role': 'Proofreader', 'stage': 'Proofreading', 'group': 'Content'},
      {'role': 'CrossChecker', 'stage': 'Text Crosscheck', 'group': 'Content'},
      {'role': 'Thumbnail Designer', 'stage': 'Thumbnail Selection', 'group': 'Thumbnail'},
    ];

    final eventProvider = context.read<EventProvider>();
    final users = List<Map<String, dynamic>>.from(_filterUsersForCategory(eventProvider.devUsers, 'Blogs / Articles'));

    final blogAssignees = <String, Map<String, String>>{};
    for (final r in blogRoles) {
      blogAssignees[r['role']!] = {'name': '', 'email': ''};
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
                  Icon(Icons.menu_book_rounded, color: Color(0xFF5B21B6)),
                  SizedBox(width: 10),
                  Text('Create Blog / Article', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description_rounded, color: Color(0xFF5B21B6), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Creates Idea folder with "Researched Doc", Thumbnail folder, and Docs with content forwarding. (No media section)',
                                style: TextStyle(fontSize: 12, color: Colors.purple.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('1. Blog / Article Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ideaCtrl,
                        decoration: InputDecoration(
                          labelText: 'Idea *',
                          hintText: 'e.g. Exploring Mindful Youth Habits in Digital Era',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: festivalsCtrl,
                        decoration: InputDecoration(
                          labelText: 'Festivals & Days Included',
                          hintText: 'e.g. World Mental Health Day / International Youth Week',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
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
                                        const Text('End Date (Completion)', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                      const Text('2. Stage Assignees (Content, Thumbnail)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      ...blogRoles.map((r) {
                        final roleName = r['role']!;
                        final stageName = r['stage']!;
                        final groupName = r['group']!;
                        final stageUsers = users.where((u) => _matchesRole(u['Role']?.toString() ?? u['role']?.toString() ?? '', roleName)).toList();
                        final displayUsers = stageUsers.isNotEmpty ? stageUsers : users;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 220,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      roleName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$groupName • $stageName',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  ],
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
                                  hint: Text('Select $roleName', style: const TextStyle(fontSize: 12)),
                                  value: blogAssignees[roleName]?['email']?.isNotEmpty == true ? blogAssignees[roleName]!['email'] : null,
                                  items: [
                                    ...displayUsers.map((u) {
                                      final uEmail = u['Email']?.toString() ?? u['email']?.toString() ?? '';
                                      final uName = u['Name']?.toString() ?? u['name']?.toString() ?? uEmail;
                                      final uRole = u['Role']?.toString() ?? u['role']?.toString() ?? '';
                                      return DropdownMenuItem<String>(
                                        value: uEmail,
                                        child: Text('$uName ($uRole)', style: const TextStyle(fontSize: 12)),
                                      );
                                    }),
                                    const DropdownMenuItem<String>(
                                      value: '__add_new__',
                                      child: Text('+ Add New Assignee...', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val == '__add_new__') {
                                      _promptAddNewAssignee(ctx, roleName, 'Blogs / Articles', (name, email) {
                                        final newUser = {
                                          'Email': email,
                                          'Name': name,
                                          'Role': roleName,
                                          'Category': 'Blogs / Articles'
                                        };
                                        setDialogState(() {
                                          users.add(newUser);
                                          blogAssignees[roleName] = {
                                            'name': name,
                                            'email': email,
                                          };
                                        });
                                      });
                                    } else if (val != null) {
                                      final matched = users.firstWhere(
                                        (u) => (u['Email']?.toString() ?? u['email']?.toString()) == val,
                                        orElse: () => users.first,
                                      );
                                      final mName = matched['Name']?.toString() ?? matched['name']?.toString() ?? val;
                                      final mEmail = matched['Email']?.toString() ?? matched['email']?.toString() ?? val;
                                      setDialogState(() {
                                        blogAssignees[roleName] = {
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
                    backgroundColor: const Color(0xFF5B21B6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Create Blog & Setup Flow', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (ideaCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter Idea'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    final scaffold = ScaffoldMessenger.of(context);
                    final devProv = context.read<DevPipelineProvider>();
                    Navigator.pop(ctx);

                    final assigneesPayload = <String, Map<String, String>>{
                      'Writing': blogAssignees['Writer'] ?? {'name': '', 'email': ''},
                      'Editing': blogAssignees['Editor'] ?? {'name': '', 'email': ''},
                      'Proofreading': blogAssignees['Proofreader'] ?? {'name': '', 'email': ''},
                      'Text Crosscheck': blogAssignees['CrossChecker'] ?? {'name': '', 'email': ''},
                      'Thumbnail Selection': blogAssignees['Thumbnail Designer'] ?? {'name': '', 'email': ''},
                      ...blogAssignees,
                    };

                    final res = await devProv.createProject(
                      stream: 'Blogs / Articles',
                      campaignName: ideaCtrl.text.trim(),
                      sessionName: '',
                      duration: '',
                      festivals: festivalsCtrl.text.trim(),
                      startDate: DateFormat('d-MMM-yyyy').format(startDate),
                      completionDate: DateFormat('d-MMM-yyyy').format(completionDate),
                      iecContent: false,
                      iecDesigning: false,
                      iecProofread: false,
                      iecFinalCheck: false,
                      assignees: assigneesPayload,
                    );

                    if (mounted) {
                      if (res['success'] == true) {
                        scaffold.showSnackBar(
                          SnackBar(
                            content: Text('Created ${res["projectId"]} successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        scaffold.showSnackBar(
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


class _ReassignDevTaskDialog extends StatefulWidget {
  final DevTask task;
  final VoidCallback onSuccess;

  const _ReassignDevTaskDialog({required this.task, required this.onSuccess});

  @override
  State<_ReassignDevTaskDialog> createState() => _ReassignDevTaskDialogState();
}

class _ReassignDevTaskDialogState extends State<_ReassignDevTaskDialog> {
  String? _selectedEmail;
  bool _isOther = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final allUsers = eventProvider.devUsers;

    final streamCategory = widget.task.stream.isNotEmpty
        ? widget.task.stream
        : (widget.task.projectId.startsWith('WEB')
            ? 'Website Reporting'
            : (widget.task.projectId.startsWith('SMD')
                ? 'SM Development'
                : (widget.task.projectId.startsWith('BLOG')
                    ? 'Blogs / Articles'
                    : 'Campaign Development')));

    final target = streamCategory.toLowerCase();
    final categoryUsers = allUsers.where((u) {
      final cat = (u['Category'] ?? u['category'] ?? '').toString().trim().toLowerCase();
      if (cat.isEmpty || cat == 'all') return true;
      if (target.contains('campaign') && (cat.contains('camp') || cat.contains('campaign'))) return true;
      if (target.contains('sm') && (cat.contains('sm') || cat.contains('social'))) return true;
      if (target.contains('web') && (cat.contains('web') || cat.contains('site'))) return true;
      if (target.contains('blog') && (cat.contains('blog') || cat.contains('article'))) return true;
      return cat.contains(target) || target.contains(cat);
    }).toList();

    final categoryPool = categoryUsers.isNotEmpty ? categoryUsers : allUsers;
    final expectedRole = _DevPipelineScreenState._mapStageToRole(widget.task.stage, streamCategory);

    final roleFiltered = categoryPool.where((u) {
      final uRole = (u['Role'] ?? u['role'] ?? '').toString();
      return _DevPipelineScreenState._matchesRole(uRole, expectedRole);
    }).toList();

    final displayUsers = roleFiltered.isNotEmpty ? roleFiltered : categoryPool;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.person_pin_rounded, color: Color(0xFF1A237E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Reassign ${widget.task.stage} ($expectedRole)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${widget.task.campaignName} (#${widget.task.projectId})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.normal),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF1A237E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Category: $streamCategory • Role: $expectedRole\nCurrent: ${widget.task.assignee.isNotEmpty ? widget.task.assignee : "Unassigned"}',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Select $expectedRole',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                value: _selectedEmail,
                items: [
                  ...displayUsers.map((u) {
                    final email = u['Email']?.toString() ?? u['email']?.toString() ?? '';
                    final name = u['Name']?.toString() ?? u['name']?.toString() ?? email;
                    final role = u['Role']?.toString() ?? u['role']?.toString() ?? '';
                    return DropdownMenuItem<String>(
                      value: email,
                      child: Text('$name ($role)', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }),
                  const DropdownMenuItem<String>(
                    value: '__other__',
                    child: Text('+ Other (Add New User)', style: TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedEmail = val;
                    _isOther = val == '__other__';
                  });
                },
              ),
              if (_isOther) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'New User Name *',
                    hintText: 'e.g. John Sharma',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'New User Gmail *',
                    hintText: 'e.g. john@gmail.com',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                Text(
                  'This user will be automatically added to the Dev_Users sheet under category "$streamCategory".',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check, size: 16),
          label: const Text('Save & Reassign'),
          onPressed: _isLoading ? null : () async {
            if (_selectedEmail == null) return;

            String targetEmail = _selectedEmail!;
            String? newName;

            if (_isOther) {
              targetEmail = _emailController.text.trim();
              newName = _nameController.text.trim();
              if (targetEmail.isEmpty || newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter both name and email.')),
                );
                return;
              }
            } else {
              final matched = displayUsers.firstWhere(
                (u) => (u['Email']?.toString() ?? u['email']?.toString()) == targetEmail,
                orElse: () => displayUsers.first,
              );
              newName = matched['Name']?.toString() ?? matched['name']?.toString() ?? targetEmail;
            }

            setState(() => _isLoading = true);
            final messenger = ScaffoldMessenger.of(context);
            final devProvider = context.read<DevPipelineProvider>();

            final success = await devProvider.reassignDevTask(
              task: widget.task,
              newEmail: targetEmail,
              newName: newName,
              role: widget.task.stage,
              category: streamCategory,
            );

            if (mounted) {
              Navigator.pop(context);
              if (success) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Task reassigned to $newName successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                widget.onSuccess();
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to reassign task. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }
}
