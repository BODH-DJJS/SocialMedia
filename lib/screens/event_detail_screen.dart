import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/searchable_user_picker.dart';

class GroupMediaLink {
  final String postNo;
  final String theme;
  final String rawFolder;
  final String selectedFolder;
  final String monthLink;
  GroupMediaLink(this.postNo, this.theme, this.rawFolder, this.selectedFolder, this.monthLink);
}

class EventDetailScreen extends StatefulWidget {
  final Event? event;
  final String? postNo;
  final String? stage;
  final String? taskId;
  final bool isCombined;

  const EventDetailScreen({
    super.key,
    this.event,
    this.postNo,
    this.stage,
    this.taskId,
    this.isCombined = false,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Event? _event;
  bool _isLoadingEvent = false;
  String? _errorMessage;

  Event get event => _event ?? (widget.event ?? (throw StateError('Event is not loaded')));

  bool _isLoadingMedia = true;
  bool _isSaving = false;
  String _rawFolderLink = '';
  String _selectedFolderLink = '';
  String _editedFolderLink = '';
  String _editedThumbnailFolderLink = '';
  String _writingDocLink = '';
  String _proofreadDocLink = '';
  String _crosscheckDocLink = '';
  String _canvaLink = '';
  bool _isSavingCanva = false;
  List<Map<String, dynamic>> _photos = [];
  List<GroupMediaLink> _groupMediaLinks = [];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _event = widget.event;
      _canvaLink = _event!.canvaLink;
      _fetchMediaLinks();
    } else {
      _loadEventFromQuery();
    }
  }

  Future<void> _loadEventFromQuery() async {
    setState(() {
      _isLoadingEvent = true;
      _errorMessage = null;
    });

    final pNo = widget.postNo?.trim() ?? '';
    final stg = widget.stage?.trim() ?? '';
    final tId = widget.taskId?.trim() ?? '';

    if (pNo.isEmpty && tId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingEvent = false;
          _errorMessage = 'No post number or task ID provided.';
        });
      }
      return;
    }

    final provider = context.read<EventProvider>();
    final auth = context.read<AuthProvider>();

    // 1. Check in-memory events
    Event? found = _findMatchingEvent(provider.events, pNo, stg, tId);

    // 2. Instant localStorage cache check (0ms)
    if (found == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final key in prefs.getKeys()) {
          if (key.startsWith('cache_events')) {
            final jsonStr = prefs.getString(key);
            if (jsonStr != null && jsonStr.isNotEmpty) {
              final List<dynamic> list = json.decode(jsonStr);
              final cachedEvents = list.map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();
              final cachedFound = _findMatchingEvent(cachedEvents, pNo, stg, tId);
              if (cachedFound != null) {
                found = cachedFound;
                provider.setEvents(cachedEvents);
                if (mounted) {
                  setState(() {
                    _event = found;
                    _canvaLink = found!.canvaLink;
                    _isLoadingEvent = false;
                  });
                  _fetchMediaLinks();
                }
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Cache check error in _loadEventFromQuery: $e');
      }
    }

    // 3. Fast Supabase targeted fetch (< 100ms) with fallback to Google Apps Script
    if (found == null && (pNo.isNotEmpty || tId.isNotEmpty)) {
      try {
        final details = await provider.fetchSinglePostDetails(
          pNo,
          taskId: tId,
          stage: stg,
          isCombined: widget.isCombined,
        );
        if (details != null && details['tasks'] != null) {
          final tasks = (details['tasks'] as List<dynamic>).cast<Event>();
          found = _findMatchingEvent(tasks, pNo, stg, tId);
        }
      } catch (e) {
        debugPrint('Error in fetchSinglePostDetails: $e');
      }
    }

    // 4. Fallback: fetch all events
    if (found == null && auth.isLoggedIn) {
      try {
        await provider.fetchEvents(auth.role, auth.username);
        found = _findMatchingEvent(provider.events, pNo, stg, tId);
      } catch (e) {
        debugPrint('Error in fetchEvents: $e');
      }
    }

    if (mounted && _isLoadingEvent) {
      if (found != null) {
        setState(() {
          _event = found;
          _canvaLink = found!.canvaLink;
          _isLoadingEvent = false;
        });
        _fetchMediaLinks();
      } else {
        setState(() {
          _isLoadingEvent = false;
          _errorMessage = 'Task for ${(widget.isCombined || pNo.toLowerCase().startsWith('combined')) ? pNo : 'Post #$pNo'} (${stg.isNotEmpty ? stg : "Active Stage"}) not found.';
        });
      }
    }
  }

  Event? _findMatchingEvent(List<Event> list, String pNo, String stg, String tId) {
    if (list.isEmpty) return null;
    final cleanPNo = pNo.trim().toLowerCase();
    final cleanStg = stg.trim().toLowerCase();
    final cleanTId = tId.trim().toLowerCase();

    if (cleanTId.isNotEmpty) {
      try {
        return list.firstWhere((e) => e.taskId.trim().toLowerCase() == cleanTId);
      } catch (_) {}
    }
    if (cleanPNo.isNotEmpty && cleanStg.isNotEmpty) {
      try {
        return list.firstWhere(
          (e) => e.postNo.trim().toLowerCase() == cleanPNo && e.stage.trim().toLowerCase() == cleanStg,
        );
      } catch (_) {}
    }
    if (cleanPNo.isNotEmpty) {
      try {
        final active = list.where((e) => e.postNo.trim().toLowerCase() == cleanPNo && e.status != 'Done').toList();
        if (active.isNotEmpty) return active.first;
        return list.firstWhere((e) => e.postNo.trim().toLowerCase() == cleanPNo);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _fetchMediaLinks() async {
    final provider = context.read<EventProvider>();
    
    if (event.isCombined) {
      List<GroupMediaLink> groupLinks = [];
      String firstEdited = '';
      String firstEditedThumb = '';
      String firstWriting = '';
      String firstProofread = '';
      String firstCrosscheck = '';
      
      for (int i = 0; i < event.combinedPosts.length; i++) {
        final p = event.combinedPosts[i];
        final pDate = p['Date']?.toString() ?? '';
        final pVenue = p['Venue']?.toString() ?? '';
        final pMonth = p['FolderLink']?.toString() ?? '';
        final pTheme = p['Theme']?.toString() ?? '';
        final pNo = p['PostNo']?.toString() ?? '';
        
        if (pMonth.isNotEmpty) {
           final links = await provider.fetchMediaFolders(pMonth, pDate, event.stage, venue: pVenue, postNo: pNo);
           groupLinks.add(GroupMediaLink(pNo, pTheme, links['raw'] ?? '', links['selected'] ?? '', pMonth));
           
           if (i == 0) {
             firstEdited = links['edited'] ?? '';
             firstEditedThumb = links['editedThumbnail'] ?? '';
             firstWriting = links['writingDoc'] ?? '';
             firstProofread = links['proofreadDoc'] ?? '';
             firstCrosscheck = links['crosscheckDoc'] ?? '';
           }
        }
      }
      
      if (mounted) {
        setState(() {
          _groupMediaLinks = groupLinks;
          _editedFolderLink = firstEdited;
          _editedThumbnailFolderLink = firstEditedThumb;
          _writingDocLink = firstWriting;
          _proofreadDocLink = firstProofread;
          _crosscheckDocLink = firstCrosscheck;
          _isLoadingMedia = false;
        });
      }
    } else {
      final links = await provider.fetchMediaFolders(event.folderLink, event.date, event.stage, venue: event.venue, postNo: event.postNo.toString());
      
      List<Map<String, dynamic>> fetchedPhotos = [];
      if (links['raw'] != null && links['raw']!.isNotEmpty) {
        fetchedPhotos = await provider.fetchPhotos(links['raw']!);
      }
      
      if (mounted) {
        setState(() {
          _rawFolderLink = links['raw'] ?? '';
          _selectedFolderLink = links['selected'] ?? '';
          _editedFolderLink = links['edited'] ?? '';
          _editedThumbnailFolderLink = links['editedThumbnail'] ?? '';
          _writingDocLink = links['writingDoc'] ?? '';
          _proofreadDocLink = links['proofreadDoc'] ?? '';
          _crosscheckDocLink = links['crosscheckDoc'] ?? '';
          _photos = fetchedPhotos;
          _isLoadingMedia = false;
        });
      }
    }

    // Silently enrich sibling tasks cache for this post
    try {
      provider.fetchSinglePostDetails(event.postNo, isCombined: event.isCombined);
    } catch (_) {}
  }

  String _toViewModeUrl(String url) {
    if (url.isEmpty) return url;
    var u = url.trim();
    if (u.contains('docs.google.com')) {
      if (u.contains('/edit')) {
        u = u.replaceAll(RegExp(r'/edit.*'), '/preview');
      } else if (!u.contains('/preview')) {
        u = u.endsWith('/') ? '${u}preview' : '$u/preview';
      }
    }
    return u;
  }

  String get _proofreadingDocLink {
    if (_proofreadDocLink.isNotEmpty && _proofreadDocLink.startsWith('http')) return _proofreadDocLink;
    try {
      final provider = context.read<EventProvider>();
      final postTasks = provider.events.where((t) => t.postNo == event.postNo).toList();
      final match = postTasks.firstWhere(
        (t) => t.stage.trim().toLowerCase().replaceAll(' ', '') == 'proofreading' && t.docLink.isNotEmpty && t.docLink.startsWith('http'),
        orElse: () => Event.fromJson({}),
      );
      if (match.docLink.isNotEmpty && match.docLink.startsWith('http')) return match.docLink;
    } catch (_) {}
    return '';
  }

  String get _textCrosscheckDocLink {
    if (_crosscheckDocLink.isNotEmpty && _crosscheckDocLink.startsWith('http')) return _crosscheckDocLink;
    try {
      final provider = context.read<EventProvider>();
      final postTasks = provider.events.where((t) => t.postNo == event.postNo).toList();
      for (final targetStage in ['textcrosscheck', 'crosscheck', 'text crosscheck', 'cross check']) {
        final match = postTasks.firstWhere(
          (t) => t.stage.trim().toLowerCase().replaceAll(' ', '') == targetStage.replaceAll(' ', '') && t.docLink.isNotEmpty && t.docLink.startsWith('http'),
          orElse: () => Event.fromJson({}),
        );
        if (match.docLink.isNotEmpty && match.docLink.startsWith('http')) return match.docLink;
      }
    } catch (_) {}
    return '';
  }

  /// Get the best available doc link (prefer backend-found over stored)
  String get _bestDocLink {
    if (_writingDocLink.isNotEmpty && _writingDocLink.startsWith('http')) return _writingDocLink;
    if (event.docLink.isNotEmpty && event.docLink.startsWith('http')) return event.docLink;

    // Fallback: If Ready to Post (or if current docLink is empty), look for Crosscheck / Text Crosscheck doc from the same post
    try {
      final provider = context.read<EventProvider>();
      final postTasks = provider.events.where((t) => t.postNo == event.postNo).toList();
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

  /// Get the best available Canva link (from current task or sibling tasks)
  String get _bestCanvaLink {
    if (_canvaLink.trim().isNotEmpty && _canvaLink.trim().startsWith('http')) return _canvaLink.trim();
    if (event.canvaLink.trim().isNotEmpty && event.canvaLink.trim().startsWith('http')) {
      return event.canvaLink.trim();
    }
    try {
      final provider = context.read<EventProvider>();
      final postTasks = provider.events.where((t) => t.postNo == event.postNo).toList();
      for (final t in postTasks) {
        if (t.canvaLink.trim().isNotEmpty && t.canvaLink.trim().startsWith('http')) {
          return t.canvaLink.trim();
        }
      }
    } catch (_) {}
    return '';
  }

  void _showEditCanvaDialog() {
    final controller = TextEditingController(text: _bestCanvaLink);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.palette_outlined, color: Color(0xFF00C4CC)),
            SizedBox(width: 8),
            Text('Canva Project Link'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the Canva project or design link here. This link will be shared with the Media Cross-Checkers.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'https://www.canva.com/design/...',
                labelText: 'Canva URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C4CC),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newLink = controller.text.trim();
              Navigator.pop(ctx);
              setState(() {
                _canvaLink = newLink;
                _isSavingCanva = true;
              });
              final provider = context.read<EventProvider>();
              final err = await provider.updateEvent(event, {'CanvaLink': newLink});
              if (mounted) {
                setState(() => _isSavingCanva = false);
                if (err == null || err == 'timeout') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Canva link saved successfully!'), backgroundColor: Colors.teal),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save Canva link: $err'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Link'),
          ),
        ],
      ),
    );
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
    final stageLower = event.stage.toLowerCase();
    
    // Thumbnail Processing check: "Edited Thumbnail" folder under "Selected (Edited)" must not be empty
    if (stageLower == 'thumbnail processing' || stageLower == 'thumbnailprocessing') {
      setState(() => _isSaving = true);
      final provider = context.read<EventProvider>();
      final res = await provider.checkThumbnailFolderNotEmpty(event.postNo, folderLink: event.folderLink);
      if (res['notEmpty'] != true) {
        setState(() => _isSaving = false);
        if (mounted) {
          final fUrl = res['folderUrl']?.toString() ?? _editedThumbnailFolderLink;
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
              content: Text(res['error'] ?? 'The "Edited (Thumbnail)" folder under "Selected (Edited)" is empty! Please upload edited thumbnail files first.'),
              actions: [
                if (fUrl.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open Edited (Thumbnail) Folder'),
                    onPressed: () {
                      _openLink(fUrl);
                    },
                  ),
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
    
    if (stageLower.contains('editing') && (stageLower.contains('photo') || stageLower.contains('video'))) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF1A237E), size: 24),
              const SizedBox(width: 8),
              Text('Submit ${event.stage}'),
            ],
          ),
          content: Text(
            'Are you sure you want to mark ${event.stage} as Done and proceed with handoff?\n\n'
            'Please ensure the selected photos and edited media have been uploaded to the Selected Folder.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm & Mark Done'),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
      
      setState(() => _isSaving = true);
      final provider = context.read<EventProvider>();
      final notEmpty = await provider.checkFolderNotEmpty(event.postNo);
      if (!notEmpty) {
        setState(() => _isSaving = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text('Selected Folder Empty'),
                ],
              ),
              content: const Text('The Selected folder is empty! Please upload the selected photos/videos into the Selected folder before marking this task as Done.'),
              actions: [
                if (_selectedFolderLink.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open Selected Folder'),
                    onPressed: () => _openLink(_selectedFolderLink),
                  ),
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
    provider.updateEvent(event, {'Status': 'Done'}).then((error) {
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

  void _confirmDeletePostWorkflow(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Workflow?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all workflow tasks for ${(event.isCombined || event.postNo.toLowerCase().startsWith('combined')) ? event.postNo : 'Post #${event.postNo}'}?\n\n'
          'This will remove all assigned tasks and convert the post back to Inactive.',
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
            label: const Text('Delete & Make Inactive', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<EventProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final ok = await provider.deleteWorkflow(
                postNo: event.postNo,
                isCombined: event.isCombined,
              );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '${(event.isCombined || event.postNo.toLowerCase().startsWith('combined')) ? event.postNo : 'Post #${event.postNo}'} workflow deleted and marked Inactive.'
                        : 'Failed to delete workflow.'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
                if (ok) {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/dashboard');
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }


  bool get _hasPreviousStage {
    final s = event.stage.toLowerCase().replaceAll(' ', '');
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
    final s = event.stage.toLowerCase().replaceAll(' ', '');
    if (s == 'thumbnailcrosschecking' || s == 'thumbnailcrosscheck') return ['Thumbnail Processing'];
    if (s == 'thumbnailprocessing') return ['Thumbnail Selection'];
    if (s == 'mediacrosscheck') return ['Proofreading', 'Photo Editing', 'Video Editing'];
    if (s == 'mediafinalcrosscheck' || s == 'mediafinalcrosschecking') return ['Proofreading', 'Media Cross Check', 'Photo Editing', 'Video Editing'];
    if (s == 'photosclean') return ['Ready to Post'];
    if (s == 'editing') return ['Writing'];
    if (s == 'proofreading') return ['Editing', 'Media Cross Check', 'Thumbnail Cross checking'];
    if (s == 'crosscheck' || s == 'textcrosscheck') return ['Proofreading'];
    if (s == 'readytopost') return ['Text Crosscheck', 'Media Final Cross check', 'Proofreading'];
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
        postNo: event.postNo,
        currentStage: event.stage,
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
    if (_isLoadingEvent) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.postNo != null && widget.postNo!.isNotEmpty
              ? ((widget.isCombined || widget.postNo!.toLowerCase().startsWith('combined'))
                  ? widget.postNo!
                  : 'Post #${widget.postNo}')
              : 'Loading Post...'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading task details...', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Post Not Found'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 54, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Unable to find task for this post.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Go to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isSaving = _isSaving;
    final isDone = event.status == 'Done';
    final theme = Theme.of(context);
    final e = event;

    Color stageColor = e.stage == 'Writing'
        ? const Color(0xFF42A5F5)
        : e.stage == 'Editing'
            ? const Color(0xFFFF8A65)
            : const Color(0xFFAB47BC);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Text('${(e.isCombined || e.postNo.toLowerCase().startsWith('combined')) ? e.postNo : 'Post ${e.postNo}'} • ${e.stage}'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.role.toLowerCase() == 'admin') {
                return IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete Workflow (Make Inactive)',
                  onPressed: () => _confirmDeletePostWorkflow(context),
                );
              }
              return const SizedBox.shrink();
            },
          ),
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
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.people, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '👨 $pMale  👩 $pFemale  🧒 $pChildren  👥 Total: $pTotal',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => _showEditBeneficiariesDialog(context, e, subPost: p),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.blue.shade200),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.edit, size: 11, color: Colors.blue),
                                                  SizedBox(width: 2),
                                                  Text('Edit', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Beneficiaries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              if (!e.isCombined)
                                TextButton.icon(
                                  onPressed: () => _showEditBeneficiariesDialog(context, e),
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Edit Beneficiaries', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                )
                              else
                                Text(
                                  'Edit per sub-post above',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
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
                            if (_editedThumbnailFolderLink.isNotEmpty)
                              _mediaButton(Icons.image, 'Edited (Thumbnail)', 'Thumbnail files under Selected (Edited)', Colors.amber.shade900, () => _openLink(_editedThumbnailFolderLink)),
                          ] else ...[
                            if (_rawFolderLink.isNotEmpty)
                              _mediaButton(Icons.photo_library, 'View Photos / Videos (Raw)', 'Original unedited files', Colors.blueGrey, () => _openLink(_rawFolderLink)),
                            if (_selectedFolderLink.isNotEmpty)
                              _mediaButton(Icons.checklist, 'Selected Photos', 'Best picks from Raw', Colors.teal, () => _openLink(_selectedFolderLink)),
                            if (_editedFolderLink.isNotEmpty)
                              _mediaButton(Icons.auto_fix_high, 'Selected (Edited)', 'Edited and approved files', Colors.purple, () => _openLink(_editedFolderLink)),
                            if (_editedThumbnailFolderLink.isNotEmpty)
                              _mediaButton(Icons.image, 'Edited (Thumbnail)', 'Thumbnail files under Selected (Edited)', Colors.amber.shade900, () => _openLink(_editedThumbnailFolderLink)),
                            _mediaButton(Icons.folder_shared, 'Date Folder', 'Master event archive', const Color(0xFFF39C12), () => _openLink(e.folderLink)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Canva Link Section (Available for Content, Thumbnail, and Media stages)
                  Builder(
                    builder: (context) {
                      final canvaUrl = _bestCanvaLink;
                      const canvaColor = Color(0xFF00C4CC);

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: canvaColor.withOpacity(0.4), width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: canvaColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.palette_outlined, color: canvaColor, size: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Canva Design / Project',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: canvaColor),
                                    ),
                                  ),
                                  if (_isSavingCanva)
                                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: canvaColor))
                                  else
                                    TextButton.icon(
                                      icon: Icon(canvaUrl.isEmpty ? Icons.add_link : Icons.edit, size: 16),
                                      label: Text(canvaUrl.isEmpty ? 'Add Link' : 'Edit Link'),
                                      style: TextButton.styleFrom(foregroundColor: canvaColor),
                                      onPressed: _showEditCanvaDialog,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'View or add the Canva project link for this post so all collaborators across content, thumbnail, and media can access it.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              if (canvaUrl.isNotEmpty) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open Canva Project'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: canvaColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _openLink(canvaUrl),
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: Colors.grey, size: 18),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'No Canva link added yet. Tap "Add Link" to attach your design.',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
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

                  // Approved Text Content Review for Media Final Cross check
                  if (['mediafinalcrosscheck', 'mediafinalcrosschecking'].contains(e.stage.trim().toLowerCase().replaceAll(' ', ''))) ...[
                    Card(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.withOpacity(0.4), width: 2),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.rate_review_outlined, color: Colors.teal),
                                SizedBox(width: 8),
                                Text(
                                  'Approved Text Content Review',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Review the approved text documents in view mode to ensure finalized media matches the post details before approval.',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.visibility_outlined, size: 18),
                                    label: const Text('Proofreading Doc', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00897B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      final docUrl = _proofreadingDocLink;
                                      if (docUrl.isNotEmpty) {
                                        _openLink(_toViewModeUrl(docUrl));
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Proofreading document available.')));
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.visibility_outlined, size: 18),
                                    label: const Text('Crosscheck Doc', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF27AE60),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      final docUrl = _textCrosscheckDocLink;
                                      if (docUrl.isNotEmpty) {
                                        _openLink(_toViewModeUrl(docUrl));
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Text Crosscheck document available.')));
                                      }
                                    },
                                  ),
                                ),
                              ],
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

  void _showEditBeneficiariesDialog(BuildContext context, Event event, {Map<String, dynamic>? subPost}) {
    final postNo = subPost != null ? (subPost['PostNo']?.toString() ?? '') : event.postNo;
    final venue = subPost != null ? (subPost['Venue']?.toString() ?? '') : event.venue;
    final date = subPost != null ? (subPost['Date']?.toString() ?? '') : event.date;
    final state = subPost != null ? (subPost['State']?.toString() ?? '') : event.state;
    final branch = subPost != null ? (subPost['Branch']?.toString() ?? '') : event.branch;

    final initialMale = subPost != null ? (int.tryParse(subPost['Male']?.toString() ?? '0') ?? 0) : event.male;
    final initialFemale = subPost != null ? (int.tryParse(subPost['Female']?.toString() ?? '0') ?? 0) : event.female;
    final initialChildren = subPost != null ? (int.tryParse(subPost['Children']?.toString() ?? '0') ?? 0) : event.children;

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
                      // Male Input
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
                      // Female Input
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
                      // Children Input
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
                      // Calculated Total Card
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

                          final provider = Provider.of<EventProvider>(context, listen: false);
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
                            event: event,
                            subPost: subPost,
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
    else if (stage.contains('cross check') && !stage.contains('thumb') && !stage.contains('media')) expectedRole = 'CrossChecker';
    else if (stage.contains('thumbnail selection') || stage == 'thumbnail selection') expectedRole = 'Thumbnail Selector';
    else if (stage.contains('thumbnail processing') || stage == 'thumbnail processing') expectedRole = 'Thumbnail Processor';
    else if (stage.contains('thumbnail cross') || stage.contains('thumbnail cross checking')) expectedRole = 'Thumbnail CrossChecker';
    else if (stage.contains('thumb')) expectedRole = 'Thumbnail Designer';
    else if (stage.contains('photo select')) expectedRole = 'Photo Selector';
    else if (stage.contains('photo edit')) expectedRole = 'Photo Editor';
    else if (stage.contains('video edit')) expectedRole = 'Video Editor';
    else if (stage.contains('media cross')) expectedRole = 'Media CrossChecker';
    else if (stage.contains('ready')) expectedRole = 'Uploader';

    final roleUsers = users.where((u) {
      final r = u['role']?.toString() ?? '';
      // Support specific thumbnail roles as well as generic 'Thumbnail Designer'
      if (expectedRole.startsWith('Thumbnail')) {
        return r == expectedRole || r == 'Thumbnail Designer' || r == 'Admin';
      }
      return r == expectedRole || r == 'Admin';
    }).toList();

    // Sort: Users of that role first, then fallbacks, then Admin strictly at the END!
    roleUsers.sort((a, b) {
      final roleA = (a['role'] ?? '').toString().toLowerCase();
      final roleB = (b['role'] ?? '').toString().toLowerCase();
      final isAdminA = roleA == 'admin';
      final isAdminB = roleB == 'admin';
      if (isAdminA && !isAdminB) return 1;
      if (!isAdminA && isAdminB) return -1;

      final targetLower = expectedRole.toLowerCase();
      final isExactA = roleA == targetLower;
      final isExactB = roleB == targetLower;
      if (isExactA && !isExactB) return -1;
      if (!isExactA && isExactB) return 1;

      final nameA = (a['name'] ?? a['email'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? b['email'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    return AlertDialog(
      title: const Text('Reassign Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchableUserPicker(
              title: expectedRole,
              value: _selectedEmail,
              users: roleUsers,
              valueField: 'username',
              allowOther: true,
              otherLabel: '+ Other (Add New User)',
              onOtherSelected: () {
                setState(() {
                  _selectedEmail = 'other';
                  _isOther = true;
                });
              },
              onChanged: (val) {
                setState(() {
                  _selectedEmail = val;
                  _isOther = (val == 'other' || val == '__other__');
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
