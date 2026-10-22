import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';
import '../providers/auth_provider.dart';

class GroupMediaLink {
  final String postNo;
  final String theme;
  final String rawFolder;
  final String selectedFolder;
  final String monthLink;
  GroupMediaLink(this.postNo, this.theme, this.rawFolder, this.selectedFolder, this.monthLink);
}

class EventDetailScreen extends StatefulWidget {
  final Event event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoadingMedia = true;
  bool _isSaving = false;
  String _rawFolderLink = '';
  String _selectedFolderLink = '';
  String _editedFolderLink = '';
  String _writingDocLink = '';
  List<Map<String, dynamic>> _photos = [];
  List<GroupMediaLink> _groupMediaLinks = [];

  @override
  void initState() {
    super.initState();
    _fetchMediaLinks();
  }

  Future<void> _fetchMediaLinks() async {
    final provider = context.read<EventProvider>();
    
    if (widget.event.isCombined) {
      List<GroupMediaLink> groupLinks = [];
      String firstEdited = '';
      String firstWriting = '';
      
      for (int i = 0; i < widget.event.combinedPosts.length; i++) {
        final p = widget.event.combinedPosts[i];
        final pDate = p['Date']?.toString() ?? '';
        final pVenue = p['Venue']?.toString() ?? '';
        final pMonth = p['FolderLink']?.toString() ?? '';
        final pTheme = p['Theme']?.toString() ?? '';
        final pNo = p['PostNo']?.toString() ?? '';
        
        if (pMonth.isNotEmpty) {
           final links = await provider.fetchMediaFolders(pMonth, pDate, widget.event.stage, venue: pVenue, postNo: pNo);
           groupLinks.add(GroupMediaLink(pNo, pTheme, links['raw'] ?? '', links['selected'] ?? '', pMonth));
           
           if (i == 0) {
             firstEdited = links['edited'] ?? '';
             firstWriting = links['writingDoc'] ?? '';
           }
        }
      }
      
      if (mounted) {
        setState(() {
          _groupMediaLinks = groupLinks;
          _editedFolderLink = firstEdited;
          _writingDocLink = firstWriting;
          _isLoadingMedia = false;
        });
      }
    } else {
      final links = await provider.fetchMediaFolders(widget.event.folderLink, widget.event.date, widget.event.stage, venue: widget.event.venue, postNo: widget.event.postNo.toString());
      
      List<Map<String, dynamic>> fetchedPhotos = [];
      if (links['raw'] != null && links['raw']!.isNotEmpty) {
        fetchedPhotos = await provider.fetchPhotos(links['raw']!);
      }
      
      if (mounted) {
        setState(() {
          _rawFolderLink = links['raw'] ?? '';
          _selectedFolderLink = links['selected'] ?? '';
          _editedFolderLink = links['edited'] ?? '';
          _writingDocLink = links['writingDoc'] ?? '';
          _photos = fetchedPhotos;
          _isLoadingMedia = false;
        });
      }
    }
  }

  /// Get the best available doc link (prefer backend-found over stored)
  String get _bestDocLink {
    if (_writingDocLink.isNotEmpty && _writingDocLink.startsWith('http')) return _writingDocLink;
    if (widget.event.docLink.isNotEmpty && widget.event.docLink.startsWith('http')) return widget.event.docLink;

    // Fallback: If Ready to Post (or if current docLink is empty), look for Crosscheck / Text Crosscheck doc from the same post
    try {
      final provider = context.read<EventProvider>();
      final postTasks = provider.events.where((t) => t.postNo == widget.event.postNo).toList();
      for (final targetStage in ['text crosscheck', 'cross check', 'crosscheck', 'proofreading', 'editing', 'writing']) {
        final match = postTasks.firstWhere(
          (t) => t.stage.trim().toLowerCase() == targetStage && t.docLink.isNotEmpty && t.docLink.startsWith('http'),
          orElse: () => Event.fromJson({}),
        );
        if (match.docLink.isNotEmpty && match.docLink.startsWith('http')) {
          return match.docLink;
        }
      }
    } catch (_) {}

    return '';
  }

  void _openLink(String url, {bool inApp = true}) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty || !trimmedUrl.startsWith('http')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid link available')));
      return;
    }
    try {
      final uri = Uri.parse(trimmedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: inApp ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open link')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid link: ${trimmedUrl.substring(0, trimmedUrl.length > 50 ? 50 : trimmedUrl.length)}...')));
    }
  }

  void _markDone() async {
    final stageLower = widget.event.stage.toLowerCase();
    
    if (stageLower.contains('editing') && (stageLower.contains('photo') || stageLower.contains('video'))) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Submit ${widget.event.stage}'),
          content: const Text('Which action are you completing?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'Selection Only'),
              child: const Text('Photo/Video selection As Mark Done'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'Selection & Editing'),
              child: const Text('Photo/Video Editing As Mark Done'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );
      
      if (choice == null) return;
      
      setState(() => _isSaving = true);
      final provider = context.read<EventProvider>();
      final notEmpty = await provider.checkFolderNotEmpty(widget.event.postNo);
      if (!notEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Selected folder is empty! Please upload files first.'), backgroundColor: Colors.red),
        );
        return;
      }
    }
    
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Task marked as Done successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      )
    );
    Navigator.pop(context); // Go back immediately

    final provider = context.read<EventProvider>();
    provider.invalidateCache(); 
    provider.updateEvent(widget.event, {'Status': 'Done'}).then((error) {
      if (error != null && error != 'timeout') {
         messenger.showSnackBar(
           const SnackBar(content: Text('Failed: Please resubmit task again.'), backgroundColor: Colors.red)
         );
      }
    });
  }

  void _showReassignDialog(BuildContext context, Event targetEvent) {
    showDialog(
      context: context,
      builder: (context) {
        return _ReassignDialog(event: targetEvent);
      },
    );
  }


  bool get _hasPreviousStage {
    final s = widget.event.stage.toLowerCase().replaceAll(' ', '');
    return s == 'editing' ||
        s == 'proofreading' ||
        s == 'crosscheck' ||
        s == 'textcrosscheck' ||
        s == 'thumbnailprocessing' ||
        s == 'thumbnailcrosschecking' ||
        s == 'thumbnailcrosscheck' ||
        s == 'mediacrosscheck' ||
        s == 'mediafinalcrosscheck' ||
        s == 'mediafinalcrosschecking' ||
        s == 'photosclean' ||
        s == 'readytopost';
  }

  List<String> get _possiblePreviousStages {
    final s = widget.event.stage.toLowerCase().replaceAll(' ', '');
    if (s == 'thumbnailcrosschecking' || s == 'thumbnailcrosscheck') return ['Thumbnail Processing'];
    if (s == 'thumbnailprocessing') return ['Thumbnail Selection'];
    if (s == 'mediacrosscheck') return ['Photo Editing', 'Video Editing'];
    if (s == 'mediafinalcrosscheck' || s == 'mediafinalcrosschecking') return ['Media Cross Check', 'Proofreading'];
    if (s == 'photosclean') return ['Ready to Post'];
    if (s == 'editing') return ['Writing'];
    if (s == 'proofreading') return ['Editing', 'Media Cross Check', 'Thumbnail Cross checking'];
    if (s == 'crosscheck' || s == 'textcrosscheck') return ['Proofreading'];
    if (s == 'readytopost') return ['Text Crosscheck', 'Media Final Cross check'];
    return [];
  }

  void _showReverseDialog() async {
    final stages = _possiblePreviousStages;
    if (stages.isEmpty) return;

    String selectedStage = stages.first;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.replay_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Send Back for Revision'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will revert the task back to the previous assignee so they can make changes and re-submit.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (stages.length > 1) ...[
                const Text('Revert to which stage:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedStage,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: stages.map((st) => DropdownMenuItem(value: st, child: Text(st))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedStage = val);
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Will be sent back to: $selectedStage',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text('Revision Notes / Reason (Optional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Please update thumbnail font color or change photo...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm & Send Back'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      final provider = context.read<EventProvider>();
      final messenger = ScaffoldMessenger.of(context);
      
      final success = await provider.reverseTask(
        postNo: widget.event.postNo,
        currentStage: widget.event.stage,
        targetStage: selectedStage,
        reason: reasonController.text.trim(),
      );
      
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Task sent back to $selectedStage for revision!'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to reverse task. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = _isSaving;
    final isDone = widget.event.status == 'Done';
    final theme = Theme.of(context);
    final e = widget.event;

    Color stageColor = e.stage == 'Writing'
        ? const Color(0xFF42A5F5)
        : e.stage == 'Editing'
            ? const Color(0xFFFF8A65)
            : const Color(0xFFAB47BC);

    return Scaffold(
      appBar: AppBar(
        title: Text('Post ${e.postNo} • ${e.stage}'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDone ? Colors.green : stageColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Text(isDone ? 'Done' : (e.status.isEmpty ? 'Pending' : (e.status == 'Ready' ? 'Alloted' : e.status)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stage header strip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [stageColor.withOpacity(0.15), stageColor.withOpacity(0.03)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.theme.isNotEmpty)
                    Text(e.theme, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (e.date.isNotEmpty) _headerChip(Icons.calendar_today, e.date),
                      if (e.activityType.isNotEmpty) _headerChip(Icons.category, e.activityType),
                      if (e.publishPlatform.isNotEmpty) _headerChip(Icons.campaign, e.publishPlatform),
                      if (e.mediaMode.isNotEmpty) _headerChip(e.mediaMode == 'Video' ? Icons.videocam : Icons.photo, e.mediaMode),
                    ],
                  ),
                  if (e.assigneeName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.person, size: 16, color: stageColor),
                      const SizedBox(width: 4),
                      Text('Assigned to: ${e.assigneeName}', style: TextStyle(fontWeight: FontWeight.w600, color: stageColor)),
                      if (context.watch<AuthProvider>().role.toLowerCase() == 'admin')
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () => _showReassignDialog(context, e),
                          padding: const EdgeInsets.only(left: 8),
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                          color: stageColor,
                        ),
                    ]),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Combined Events Section — show each event's details
                  if (e.isCombined && e.combinedPosts.isNotEmpty) ...[
                    Card(
                      color: Colors.purple.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.purple.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.merge_type, size: 18, color: Colors.purple.shade700),
                                const SizedBox(width: 6),
                                Text(
                                  'Combined Post — ${e.combinedPosts.length} Events',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...e.combinedPosts.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final p = entry.value;
                              final pNo = p['PostNo']?.toString() ?? '';
                              final pTheme = p['Theme']?.toString() ?? '';
                              final pProgram = p['Program']?.toString() ?? '';
                              final pDate = p['Date']?.toString() ?? '';
                              final pVenue = p['Venue']?.toString() ?? '';
                              final pBranch = p['Branch']?.toString() ?? '';
                              final pState = p['State']?.toString() ?? '';
                              final pMale = p['Male'] ?? 0;
                              final pFemale = p['Female'] ?? 0;
                              final pChildren = p['Children'] ?? 0;
                              final pTotal = p['TotalBeneficiary'] ??
                                  ((pMale is num ? pMale : 0) +
                                      (pFemale is num ? pFemale : 0) +
                                      (pChildren is num ? pChildren : 0));
                              final accentColor = idx == 0 ? Colors.purple : Colors.blue;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: accentColor.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // PostNo + Theme
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: accentColor.shade500,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '#$pNo',
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            pTheme.isNotEmpty ? pTheme : pProgram,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Date + Branch/State
                                    if (pDate.isNotEmpty)
                                      _infoRow(Icons.calendar_today, 'Date', pDate),
                                    if (pBranch.isNotEmpty)
                                      _infoRow(Icons.location_city, 'Branch', pState.isNotEmpty ? '$pBranch, $pState' : pBranch),
                                    if (pVenue.isNotEmpty)
                                      _infoRow(Icons.place, 'Venue', pVenue),
                                    // Beneficiaries
                                    if ((pTotal as num) > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.people, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              '👨 $pMale  👩 $pFemale  🧒 $pChildren  👥 Total: $pTotal',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                            ),
                                    // Guest / Speaker / Participant Info
                                    if ((p['GuestName']?.toString().isNotEmpty ?? false) ||
                                        (p['GuestOrg']?.toString().isNotEmpty ?? false) ||
                                        (p['GuestType']?.toString().isNotEmpty ?? false) ||
                                        (p['GuestDesignation']?.toString().isNotEmpty ?? false)) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'अतिथि / वक्ता / प्रतिभागी | Guest / Speaker / Participant:',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown),
                                            ),
                                            const SizedBox(height: 4),
                                            if (p['GuestType']?.toString().isNotEmpty ?? false)
                                              _infoRow(Icons.person_pin, 'Type', p['GuestType'].toString()),
                                            if (p['GuestName']?.toString().isNotEmpty ?? false)
                                              _infoRow(Icons.person, 'Name', p['GuestName'].toString()),
                                            if (p['GuestDesignation']?.toString().isNotEmpty ?? false)
                                              _infoRow(Icons.work, 'Designation', p['GuestDesignation'].toString()),
                                            if (p['GuestOrg']?.toString().isNotEmpty ?? false)
                                              _infoRow(Icons.business, 'Organization', p['GuestOrg'].toString()),
                                          ],
                                        ),
                                      ),
                                    ],
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Event Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Event Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          _infoRow(Icons.location_city, 'Branch', '${e.branch}, ${e.state}'),
                          _infoRow(Icons.place, 'Venue', e.venue),
                          _infoRow(Icons.people, 'Organizers', e.organizers),
                          _infoRow(Icons.handshake, 'Partners', e.partners),
                          if (e.mop.isNotEmpty)
                            _infoRow(Icons.campaign, 'Promotion (MOP)', e.mop),
                          if (e.importantInfo.isNotEmpty)
                            _infoRow(Icons.info_outline, 'Important', e.importantInfo),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Guest / Speaker / Participant Card
                  if (e.guestName.isNotEmpty || e.guestOrg.isNotEmpty || e.guestType.isNotEmpty || e.guestDesignation.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'अतिथि / वक्ता / प्रतिभागी सूची | List of Guest(s) / Speaker(s) / Participant(s)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A2E)),
                            ),
                            const SizedBox(height: 12),
                            if (e.guestType.isNotEmpty) _infoRow(Icons.person_pin, 'Type', e.guestType),
                            if (e.guestName.isNotEmpty) _infoRow(Icons.person, 'Name', e.guestName),
                            if (e.guestDesignation.isNotEmpty) _infoRow(Icons.work, 'Designation', e.guestDesignation),
                            if (e.guestOrg.isNotEmpty) _infoRow(Icons.business, 'Organization', e.guestOrg),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Additional Info Card
                  if (e.activitiesConducted.isNotEmpty || e.anyInformation.isNotEmpty || e.description.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Additional Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 12),
                            if (e.activitiesConducted.isNotEmpty)
                              _infoRow(Icons.local_activity, 'Activities Conducted', e.activitiesConducted),
                            if (e.anyInformation.isNotEmpty)
                              _infoRow(Icons.info, 'Other Information', e.anyInformation),
                            if (e.description.isNotEmpty)
                              _infoRow(Icons.description, 'Note from Admin', e.description, color: Colors.blue.shade700),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Beneficiary Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Beneficiaries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _benCircle('👨', 'Male', e.male, const Color(0xFF42A5F5)),
                              _benCircle('👩', 'Female', e.female, const Color(0xFFE91E63)),
                              _benCircle('🧒', 'Children', e.children, const Color(0xFFFF9800)),
                              _benCircle('👥', 'Total', e.totalBeneficiary, theme.colorScheme.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Media Folders Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Media Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          if (_isLoadingMedia)
                            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                          else if (e.isCombined) ...[
                            ..._groupMediaLinks.map((g) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Post #${g.postNo} - ${g.theme}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.indigo)),
                                  const SizedBox(height: 6),
                                  if (g.rawFolder.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(bottom: 6), child: _mediaButton(Icons.photo_library, 'Raw Folder', '', Colors.blueGrey, () => _openLink(g.rawFolder))),
                                  if (g.selectedFolder.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(bottom: 6), child: _mediaButton(Icons.checklist, 'Selected Folder', '', Colors.teal, () => _openLink(g.selectedFolder))),
                                  if (g.monthLink.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(bottom: 12), child: _mediaButton(Icons.folder_shared, 'Date Folder / Event Archive', '', const Color(0xFFF39C12), () => _openLink(g.monthLink))),
                                  const Divider(),
                                ],
                              );
                            }),
                            const SizedBox(height: 8),
                            if (_editedFolderLink.isNotEmpty)
                              _mediaButton(Icons.auto_fix_high, 'Selected (Edited) [Group Master]', 'Edited files for the whole group', Colors.purple, () => _openLink(_editedFolderLink)),
                          ] else ...[
                            if (_rawFolderLink.isNotEmpty)
                              _mediaButton(Icons.photo_library, 'View Photos / Videos (Raw)', 'Original unedited files', Colors.blueGrey, () => _openLink(_rawFolderLink)),
                            if (_selectedFolderLink.isNotEmpty)
                              _mediaButton(Icons.checklist, 'Selected Photos', 'Best picks from Raw', Colors.teal, () => _openLink(_selectedFolderLink)),
                            if (_editedFolderLink.isNotEmpty)
                              _mediaButton(Icons.auto_fix_high, 'Selected (Edited)', 'Edited and approved files', Colors.purple, () => _openLink(_editedFolderLink)),
                            _mediaButton(Icons.folder_shared, 'Date Folder', 'Master event archive', const Color(0xFFF39C12), () => _openLink(e.folderLink)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Content Document Card
                  if (['writing', 'editing', 'proofreading', 'crosscheck', 'textcrosscheck', 'cross check', 'text crosscheck', 'ready to post', 'readytopost'].contains(e.stage.trim().toLowerCase())) ...[
                    Card(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: stageColor.withOpacity(0.4), width: 2),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.description, color: stageColor),
                                const SizedBox(width: 8),
                                Text(
                                  e.stage.toLowerCase().replaceAll(' ', '') == 'readytopost'
                                      ? 'Final Content Document (Crosscheck)'
                                      : '${e.stage} Document',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: stageColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              e.stage.toLowerCase().replaceAll(' ', '') == 'readytopost'
                                  ? 'Open the approved crosscheck document for the final post content.'
                                  : 'Open this document to work on the content. Google Docs saves automatically.',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.open_in_new),
                                label: Text(
                                  e.stage.toLowerCase().replaceAll(' ', '') == 'readytopost'
                                      ? 'Open Crosscheck Doc'
                                      : 'Open ${e.stage} Doc',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: stageColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  final docUrl = _bestDocLink;
                                  if (docUrl.isNotEmpty) {
                                    _openLink(docUrl);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Google Doc link available.')));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (!isDone) ...[
                    if (_hasPreviousStage) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 54,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.replay_rounded, color: Colors.orange),
                                label: const Text('Send Back', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.orange, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isSaving ? null : _showReverseDialog,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                icon: isSaving
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_circle),
                                label: Text(isSaving ? 'Saving...' : 'Mark Done & Handoff', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00897B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isSaving ? null : _markDone,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          icon: isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle),
                          label: Text(isSaving ? 'Saving...' : 'Mark Done & Handoff', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00897B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isSaving ? null : _markDone,
                        ),
                      ),
                    ],
                  ],
                  if (isDone)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text('This task is completed', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: color ?? Colors.black87, fontSize: 13),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benCircle(String emoji, String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(child: Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color))),
        ),
        const SizedBox(height: 4),
        Text(emoji, style: const TextStyle(fontSize: 14)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _mediaButton(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.08),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 18, color: color.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReassignDialog extends StatefulWidget {
  final Event event;
  const _ReassignDialog({required this.event});

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  String? _selectedEmail;
  bool _isOther = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final users = context.watch<EventProvider>().users;
    // Map stage to role (basic mapping, can be refined)
    String expectedRole = 'User';
    final stage = widget.event.stage.toLowerCase();
    if (stage.contains('writ')) expectedRole = 'Writer';
    else if (stage.contains('edit') && !stage.contains('photo') && !stage.contains('video')) expectedRole = 'Editor';
    else if (stage.contains('proof')) expectedRole = 'Proofreader';
    else if (stage.contains('cross check')) expectedRole = 'CrossChecker';
    else if (stage.contains('thumb')) expectedRole = 'Thumbnail Designer';
    else if (stage.contains('photo select')) expectedRole = 'Photo Selector';
    else if (stage.contains('photo edit')) expectedRole = 'Photo Editor';
    else if (stage.contains('video edit')) expectedRole = 'Video Editor';
    else if (stage.contains('media cross')) expectedRole = 'Media CrossChecker';
    else if (stage.contains('ready')) expectedRole = 'Uploader';

    final roleUsers = users.where((u) => u['role'] == expectedRole || u['role'] == 'Admin').toList();

    return AlertDialog(
      title: const Text('Reassign Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select User'),
              value: _selectedEmail,
              items: [
                ...roleUsers.map((u) {
                  return DropdownMenuItem(
                    value: u['username'],
                    child: Text('${u['name']} (${u['username']})'),
                  );
                }),
                const DropdownMenuItem(
                  value: 'other',
                  child: Text('Other (Add New User)'),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedEmail = val;
                  _isOther = val == 'other';
                });
              },
            ),
            if (_isOther) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'New User Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'New User Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              Text('Role will be set to: $expectedRole', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedEmail == null) return;
            
            String targetEmail = _selectedEmail!;
            String? newName;
            
            if (_isOther) {
              targetEmail = _emailController.text.trim();
              newName = _nameController.text.trim();
              if (targetEmail.isEmpty || newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter name and email.')));
                return;
              }
            }
            
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Task reassigned successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              )
            );
            
            // Pop the dialog immediately
            Navigator.pop(context);
            // Optionally pop the detail screen as well to return to dashboard
            Navigator.pop(context);

            // Process in background
            final provider = context.read<EventProvider>();
            provider.invalidateCache(); // ensure next refresh pulls fresh data
            provider.reassignTask(
              widget.event, 
              targetEmail,
              newName: newName,
              role: expectedRole,
            ).then((success) {
              if (!success) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Failed: Please resubmit task again.'), backgroundColor: Colors.red)
                );
              }
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
