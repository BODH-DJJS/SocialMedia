import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/event_provider.dart';
import '../providers/auth_provider.dart';
import '../models/event.dart';
import 'package:intl/intl.dart';

class GroupMediaLink {
  final String postNo;
  final String theme;
  final String rawFolder;
  final String selectedFolder;
  final String monthLink;
  GroupMediaLink(this.postNo, this.theme, this.rawFolder, this.selectedFolder, this.monthLink);
}

class AdminAssignScreen extends StatefulWidget {
  final Map<String, dynamic> postData;

  const AdminAssignScreen({super.key, required this.postData});

  @override
  State<AdminAssignScreen> createState() => _AdminAssignScreenState();
}

class _AdminAssignScreenState extends State<AdminAssignScreen> {
  late Map<String, dynamic> _postData;
  bool _isLoading = false;
  bool _isLoadingMedia = true;
  String _rawFolderLink = '';
  String _selectedFolderLink = '';
  String _editedFolderLink = '';
  List<GroupMediaLink> _groupMediaLinks = [];

  String? _selectedWriter;
  String? _selectedEditor;
  String? _selectedProofreader;
  String? _selectedCrosscheck;
  String? _selectedUploader;
  
  String? _selectedThumbnailSelect;
  String? _selectedThumbnailProcess;
  String? _selectedThumbnailCrosscheck;
  String? _selectedPhotosClean;
  String? _selectedPhotoEdit;
  String? _selectedVideoEdit;
  String? _selectedMediaCheck;
  String? _selectedMediaFinalCheck;

  DateTime? _writingDue;
  DateTime? _editingDue;
  DateTime? _proofreadingDue;
  DateTime? _crosscheckDue;
  DateTime? _uploaderDue;
  
  DateTime? _thumbnailSelectDue;
  DateTime? _thumbnailProcessDue;
  DateTime? _thumbnailCrosscheckDue;
  DateTime? _photosCleanDue;
  DateTime? _photoEditDue;
  DateTime? _videoEditDue;
  DateTime? _mediaCheckDue;
  DateTime? _mediaFinalCheckDue;

  String _publishPlatform = 'WhatsApp';
  String _postType = 'Individual';
  String _mediaMode = 'Photos';
  String _postStatus = 'Active';
  String _activityType = '';

  static const List<String> _activityTypeOptions = [
    'Mass Sensitization Program',
    'Youth Awareness Workshop',
    'Community Awareness Program',
    'Counseling & Treatment',
    'Workplace Awareness Program',
    'Projects in Collaboration',
    'Training Workshops',
  ];

  static const List<String> _postStatusOptions = [
    'Active',
    'Later',
    'Skip',
    'Data Unavailable',
  ];

  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _postData = Map<String, dynamic>.from(widget.postData);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<EventProvider>();
      final auth = context.read<AuthProvider>();

      provider.fetchUsers();

      // Check if opened in a fresh tab without post details
      final postNo = (_postData['postNo'] ?? _postData['PostNo'])?.toString() ?? '';
      final isCombined = _postData['isCombined'] == true;
      final isDataMissing = _postData['Theme'] == null ||
          _postData['Theme'].toString().isEmpty ||
          (isCombined && (_postData['combinedPosts'] as List<dynamic>? ?? []).isEmpty);

      if (isDataMissing && postNo.isNotEmpty) {
        // STEP 1: Instant check from local browser cache (localStorage)
        final prefs = await SharedPreferences.getInstance();
        final cachedPostsJson = prefs.getString('cached_raw_posts');
        final cachedEventsJson = prefs.getString('cached_events');
        bool foundInLocalCache = false;

        if (cachedPostsJson != null && cachedPostsJson.isNotEmpty) {
          try {
            final List<dynamic> allCachedPosts = json.decode(cachedPostsJson);
            final List<dynamic> allCachedEvents = cachedEventsJson != null ? json.decode(cachedEventsJson) : [];
            final cachedEvents = allCachedEvents.map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();

            if (isCombined) {
              final combinedPosts = allCachedPosts
                  .where((p) => p['GroupID']?.toString() == postNo)
                  .cast<Map<String, dynamic>>()
                  .toList();
              if (combinedPosts.isNotEmpty) {
                final postTasks = cachedEvents.where((t) => t.postNo == postNo).toList();
                _postData = {
                  'postNo': postNo,
                  'GroupID': postNo,
                  'isCombined': true,
                  'isInitialized': postTasks.isNotEmpty,
                  'existingTasks': postTasks,
                  'combinedPosts': combinedPosts,
                  ...combinedPosts.first,
                };
                foundInLocalCache = true;
              }
            } else {
              final found = allCachedPosts.firstWhere(
                (p) => p['PostNo']?.toString() == postNo,
                orElse: () => null,
              );
              if (found != null) {
                final postTasks = cachedEvents.where((t) => t.postNo == postNo).toList();
                _postData = {
                  ...found as Map<String, dynamic>,
                  'isInitialized': postTasks.isNotEmpty,
                  'existingTasks': postTasks,
                };
                foundInLocalCache = true;
              }
            }
          } catch (e) {
            debugPrint('Local cache extraction error: $e');
          }
        }

        // STEP 2: If found in local cache, render immediately! Otherwise fetch ONLY this post in 1-2s
        if (foundInLocalCache) {
          _populateExistingTasksAndDueDates();
          // Silently refresh in background
          provider.fetchSinglePostDetails(postNo, isCombined: isCombined).then((freshDetails) {
            if (freshDetails != null && mounted) {
              final pObj = freshDetails['postData'] as Map<String, dynamic>? ?? {};
              final cPosts = freshDetails['combinedPosts'] as List<Map<String, dynamic>>? ?? [];
              final tasks = freshDetails['tasks'] as List<Event>? ?? [];
              setState(() {
                _postData = {
                  ...pObj,
                  'isInitialized': tasks.isNotEmpty,
                  'existingTasks': tasks,
                  'combinedPosts': cPosts,
                  'isCombined': freshDetails['isCombined'] == true,
                };
                _populateExistingTasksAndDueDates();
              });
            }
          });
        } else {
          // Fast single-post fetch (only row 698, ~1-2 seconds)
          setState(() => _isLoading = true);
          final singleDetails = await provider.fetchSinglePostDetails(postNo, isCombined: isCombined);
          if (singleDetails != null) {
            final pObj = singleDetails['postData'] as Map<String, dynamic>? ?? {};
            final cPosts = singleDetails['combinedPosts'] as List<Map<String, dynamic>>? ?? [];
            final tasks = singleDetails['tasks'] as List<Event>? ?? [];
            _postData = {
              ...pObj,
              'postNo': postNo,
              'isInitialized': tasks.isNotEmpty,
              'existingTasks': tasks,
              'combinedPosts': cPosts,
              'isCombined': singleDetails['isCombined'] == true,
            };
          } else {
            // Ultimate fallback: fetch full events if single-post API failed
            await provider.fetchEvents(auth.role, auth.username);
            final foundPost = provider.rawPosts.firstWhere(
              (p) => p['PostNo']?.toString() == postNo,
              orElse: () => {'PostNo': postNo},
            );
            final postTasks = provider.events.where((t) => t.postNo == postNo).toList();
            _postData = {
              ...foundPost,
              'isInitialized': postTasks.isNotEmpty,
              'existingTasks': postTasks,
            };
          }
          setState(() => _isLoading = false);
          _populateExistingTasksAndDueDates();
        }
      } else {
        _populateExistingTasksAndDueDates();
      }

      _fetchMediaLinks();
    });
  }

  void _populateExistingTasksAndDueDates() {
    if (!mounted) return;
    final existingTasks = _postData['existingTasks'] as List<Event>? ?? [];
    debugPrint('=== AdminAssignScreen existingTasks ===');
    debugPrint('Total existingTasks: ${existingTasks.length}');

    setState(() {
      _publishPlatform = _postData['PublishPlatform']?.toString().isNotEmpty == true 
          ? _postData['PublishPlatform'] 
          : 'WhatsApp';
      _postType = _postData['PostType']?.toString().isNotEmpty == true 
          ? _postData['PostType'] 
          : 'Individual';
      _mediaMode = _postData['MediaMode']?.toString().isNotEmpty == true 
          ? _postData['MediaMode'] 
          : 'Photos';
      final rawStatus = _postData['PostStatus']?.toString().trim() ?? '';
      _postStatus = rawStatus.isNotEmpty ? rawStatus : 'Active';
      _activityType = _postData['ActivityType']?.toString().trim() ?? '';
      _descController.text = _postData['Description']?.toString() ?? '';
      
      for (final task in existingTasks) {
        final stage = task.stage.toLowerCase().replaceAll(' ', '');
        final assignee = task.assignee.isEmpty ? null : task.assignee.trim();
        debugPrint('Task: stage="${task.stage}" -> norm="$stage", assignee="$assignee"');
        DateTime? dueDate;
        if (task.dueDate.isNotEmpty) {
          try {
            final format = DateFormat('d-MMM-yyyy');
            dueDate = format.parse(task.dueDate);
          } catch (e) {
            // Ignore parse errors
          }
        }
        
        if (stage == 'writing') {
          _selectedWriter = assignee;
          _writingDue = dueDate;
        } else if (stage == 'editing') {
          _selectedEditor = assignee;
          _editingDue = dueDate;
        } else if (stage == 'proofreading') {
          _selectedProofreader = assignee;
          _proofreadingDue = dueDate;
        } else if (stage == 'crosscheck' || stage == 'textcrosscheck') {
          _selectedCrosscheck = assignee;
          _crosscheckDue = dueDate;
        } else if (stage == 'readytopost') {
          _selectedUploader = assignee;
          _uploaderDue = dueDate;
        } else if (stage == 'thumbnailselection') {
          _selectedThumbnailSelect = assignee;
          _thumbnailSelectDue = dueDate;
        } else if (stage == 'thumbnailprocessing') {
          _selectedThumbnailProcess = assignee;
          _thumbnailProcessDue = dueDate;
        } else if (stage == 'thumbnailcrosschecking') {
          _selectedThumbnailCrosscheck = assignee;
          _thumbnailCrosscheckDue = dueDate;
        } else if (stage == 'photosclean') {
          _selectedPhotosClean = assignee;
          _photosCleanDue = dueDate;
        } else if (stage == 'photoediting') {
          _selectedPhotoEdit = assignee;
          _photoEditDue = dueDate;
        } else if (stage == 'videoediting') {
          _selectedVideoEdit = assignee;
          _videoEditDue = dueDate;
        } else if (stage == 'mediacrosscheck') {
          _selectedMediaCheck = assignee;
          _mediaCheckDue = dueDate;
        } else if (stage == 'mediafinalcrosscheck' || stage == 'mediafinalcrosschecking') {
          _selectedMediaFinalCheck = assignee;
          _mediaFinalCheckDue = dueDate;
        }
      }

      // Auto-populate default due dates for any unassigned due dates
      _applyDefaultDueDates(force: false);
    });
  }

  void _applyDefaultDueDates({DateTime? baseDate, bool force = false}) {
    final now = baseDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      // Content Timeline: Writing (+3d) -> Editing (+3d) -> Proofreading (+2d) -> Text Crosscheck (+1d) -> Ready to Post (+1d) -> Photos Clean (+5d)
      if (force || _writingDue == null) {
        _writingDue = today.add(const Duration(days: 3));
      }
      if (force || _editingDue == null) {
        _editingDue = (_writingDue ?? today).add(const Duration(days: 3));
      }
      if (force || _proofreadingDue == null) {
        _proofreadingDue = (_editingDue ?? today).add(const Duration(days: 2));
      }
      if (force || _crosscheckDue == null) {
        _crosscheckDue = (_proofreadingDue ?? today).add(const Duration(days: 1));
      }
      if (force || _uploaderDue == null) {
        _uploaderDue = (_crosscheckDue ?? today).add(const Duration(days: 1));
      }
      if (force || _photosCleanDue == null) {
        _photosCleanDue = (_uploaderDue ?? today).add(const Duration(days: 5));
      }

      // Thumbnail Timeline: Selection (+2d) -> Processing (+2d) -> Cross checking (+2d)
      if (force || _thumbnailSelectDue == null) {
        _thumbnailSelectDue = today.add(const Duration(days: 2));
      }
      if (force || _thumbnailProcessDue == null) {
        _thumbnailProcessDue = (_thumbnailSelectDue ?? today).add(const Duration(days: 2));
      }
      if (force || _thumbnailCrosscheckDue == null) {
        _thumbnailCrosscheckDue = (_thumbnailProcessDue ?? today).add(const Duration(days: 2));
      }

      // Media Timeline: Video / Photo Editing (+5d) -> Media Cross Check (+1d) -> Media Final Cross check (+1d aligned with Text Crosscheck)
      if (force || _photoEditDue == null) {
        _photoEditDue = today.add(const Duration(days: 5));
      }
      if (force || _videoEditDue == null) {
        _videoEditDue = today.add(const Duration(days: 5));
      }
      final mediaBase = (_mediaMode.toLowerCase().contains('video') ? _videoEditDue : _photoEditDue) ?? today;
      if (force || _mediaCheckDue == null) {
        _mediaCheckDue = mediaBase.add(const Duration(days: 1));
      }
      if (force || _mediaFinalCheckDue == null) {
        _mediaFinalCheckDue = (_proofreadingDue ?? today).add(const Duration(days: 1));
      }
    });
  }

  Future<void> _fetchMediaLinks() async {
    final provider = context.read<EventProvider>();
    final isCombined = _postData['isCombined'] == true;
    final combinedPosts = _postData['combinedPosts'] as List<dynamic>? ?? [];

    if (isCombined && combinedPosts.isNotEmpty) {
      List<GroupMediaLink> groupLinks = [];
      String firstEdited = '';

      for (int i = 0; i < combinedPosts.length; i++) {
        final p = combinedPosts[i] as Map<String, dynamic>;
        final pDate = p['Date']?.toString() ?? '';
        final pVenue = p['Venue']?.toString() ?? '';
        final pMonth = p['FolderLink']?.toString() ?? '';
        final pTheme = p['Theme']?.toString() ?? '';
        final pNo = p['PostNo']?.toString() ?? '';

        if (pMonth.isNotEmpty) {
          final links = await provider.fetchMediaFolders(pMonth, pDate, 'AdminAssign', venue: pVenue, postNo: pNo);
          groupLinks.add(GroupMediaLink(pNo, pTheme, links['raw'] ?? '', links['selected'] ?? '', pMonth));

          if (i == 0) {
            firstEdited = links['edited'] ?? '';
          }
        }
      }

      if (mounted) {
        setState(() {
          _groupMediaLinks = groupLinks;
          _editedFolderLink = firstEdited;
          _isLoadingMedia = false;
        });
      }
    } else {
      final folderLink = _postData['FolderLink']?.toString() ?? '';
      final eventDate = _postData['Date']?.toString() ?? '';
      final venue = _postData['Venue']?.toString() ?? '';
      final postNo = _postData['PostNo']?.toString() ?? '';

      if (folderLink.isNotEmpty) {
        final links = await provider.fetchMediaFolders(folderLink, eventDate, 'AdminAssign', venue: venue, postNo: postNo);
        if (mounted) {
          setState(() {
            _rawFolderLink = links['raw'] ?? '';
            _selectedFolderLink = links['selected'] ?? '';
            _editedFolderLink = links['edited'] ?? '';
            _isLoadingMedia = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMedia = false;
          });
        }
      }
    }
  }

  void _openLink(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty || !trimmedUrl.startsWith('http')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid link available')));
      return;
    }
    try {
      final uri = Uri.parse(trimmedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open link')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
    }
  }

  Future<void> _pickDate(BuildContext context, Function(DateTime) onSelect) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) onSelect(date);
  }

  Widget _buildUserDropdown(String title, String role, String? value, Function(String?) onChanged) {
    final allUsers = context.watch<EventProvider>().users;
    final users = allUsers.where((u) => u['role'] == role).toList();
    final uniqueUsers = <String, Map<String, dynamic>>{};
    for (var u in users) {
      final email = u['email']?.toString() ?? '';
      if (email.isNotEmpty) {
        uniqueUsers[email] = u;
      }
    }
    
    if (value != null && value.isNotEmpty && !uniqueUsers.containsKey(value)) {
      final fallbackUser = allUsers.firstWhere(
        (u) => u['email'] == value, 
        orElse: () => {'email': value, 'name': value, 'role': 'Unknown'}
      );
      uniqueUsers[value] = fallbackUser;
    }
    
    // Ensure the current value is in the unique list, otherwise reset it
    final safeValue = (value == null || value.isEmpty || uniqueUsers.containsKey(value)) ? value : null;
    
    final isInitialized = widget.postData['isInitialized'] == true;
    
    // Auto-select first user if value is null AND it is a new assignment
    if (!isInitialized && (safeValue == null || safeValue.isEmpty) && uniqueUsers.isNotEmpty) {
      final firstEmail = uniqueUsers.keys.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onChanged(firstEmail);
      });
    }
    
    final effectiveValue = safeValue ?? (!isInitialized && uniqueUsers.isNotEmpty ? uniqueUsers.keys.first : null);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Auto-assign (least loaded)'),
              value: effectiveValue,
              items: [
                const DropdownMenuItem(value: null, child: Text('Auto-assign (least loaded)')),
                ...uniqueUsers.values.map((u) {
                  final email = u['email']?.toString() ?? '';
                  final name = u['name']?.toString() ?? '';
                  final status = u['status'];
                  final active = u['activeTasks'];
                  
                  final displayName = name.isNotEmpty && name.toLowerCase() != email.toLowerCase() ? name : email;
                  
                  return DropdownMenuItem<String>(
                    value: email,
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: status == 'Available' ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('($active active)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String title, DateTime? date, Function(DateTime) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickDate(context, onSelect),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(date == null ? 'No due date' : DateFormat('dd MMM yyyy').format(date)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioGroup(String title, List<String> options, String selected, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: options.map((opt) => InkWell(
            onTap: () => onChanged(opt),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(
                  value: opt,
                  groupValue: selected,
                  onChanged: (v) => onChanged(v!),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(opt),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final provider = context.read<EventProvider>();
    final isCombined = _postData['isCombined'] == true;
    final postNo = isCombined ? _postData['postNo']?.toString() : _postData['PostNo']?.toString();
    final isInitialized = _postData['isInitialized'] == true;
    if (postNo == null) return;
    
    setState(() => _isLoading = true);

    final assignees = <String, String>{};
    if (_selectedWriter != null) assignees['Writing'] = _selectedWriter!;
    if (_selectedEditor != null) assignees['Editing'] = _selectedEditor!;
    if (_selectedProofreader != null) assignees['Proofreading'] = _selectedProofreader!;
    if (_selectedCrosscheck != null) {
      assignees['Text Crosscheck'] = _selectedCrosscheck!;
      assignees['Cross check'] = _selectedCrosscheck!;
    }
    if (_selectedMediaFinalCheck != null) assignees['Media Final Cross check'] = _selectedMediaFinalCheck!;
    if (_selectedUploader != null) assignees['Ready to Post'] = _selectedUploader!;
    
    if (_publishPlatform.toLowerCase().contains('insta') && _mediaMode.toLowerCase().contains('video')) {
      if (_selectedThumbnailSelect != null) assignees['Thumbnail Selection'] = _selectedThumbnailSelect!;
      if (_selectedThumbnailProcess != null) assignees['Thumbnail Processing'] = _selectedThumbnailProcess!;
      if (_selectedThumbnailCrosscheck != null) assignees['Thumbnail Cross checking'] = _selectedThumbnailCrosscheck!;
    }

    if (_selectedPhotosClean != null) assignees['Photos Clean'] = _selectedPhotosClean!;
    
    if (_mediaMode.toLowerCase().contains('photo')) {
      if (_selectedPhotoEdit != null) assignees['Photo Editing'] = _selectedPhotoEdit!;
    }
    if (_mediaMode.toLowerCase().contains('video')) {
      if (_selectedVideoEdit != null) assignees['Video Editing'] = _selectedVideoEdit!;
    }
    if (_selectedMediaCheck != null) assignees['Media Cross Check'] = _selectedMediaCheck!;

    final dueDates = <String, String>{};
    if (_writingDue != null) dueDates['Writing'] = _writingDue!.toIso8601String();
    if (_editingDue != null) dueDates['Editing'] = _editingDue!.toIso8601String();
    if (_proofreadingDue != null) dueDates['Proofreading'] = _proofreadingDue!.toIso8601String();
    if (_crosscheckDue != null) {
      dueDates['Text Crosscheck'] = _crosscheckDue!.toIso8601String();
      dueDates['Cross check'] = _crosscheckDue!.toIso8601String();
    }
    if (_mediaFinalCheckDue != null) dueDates['Media Final Cross check'] = _mediaFinalCheckDue!.toIso8601String();
    if (_uploaderDue != null) dueDates['Ready to Post'] = _uploaderDue!.toIso8601String();
    
    if (_publishPlatform.toLowerCase().contains('insta') && _mediaMode.toLowerCase().contains('video')) {
      if (_thumbnailSelectDue != null) dueDates['Thumbnail Selection'] = _thumbnailSelectDue!.toIso8601String();
      if (_thumbnailProcessDue != null) dueDates['Thumbnail Processing'] = _thumbnailProcessDue!.toIso8601String();
      if (_thumbnailCrosscheckDue != null) dueDates['Thumbnail Cross checking'] = _thumbnailCrosscheckDue!.toIso8601String();
    }
    
    if (_photosCleanDue != null) dueDates['Photos Clean'] = _photosCleanDue!.toIso8601String();
    
    if (_mediaMode.toLowerCase().contains('photo')) {
      if (_photoEditDue != null) dueDates['Photo Editing'] = _photoEditDue!.toIso8601String();
    }
    if (_mediaMode.toLowerCase().contains('video')) {
      if (_videoEditDue != null) dueDates['Video Editing'] = _videoEditDue!.toIso8601String();
    }
    if (_mediaCheckDue != null) dueDates['Media Cross Check'] = _mediaCheckDue!.toIso8601String();

    final success = await provider.createTasksForPostV2(
      postNo: postNo,
      assignees: assignees,
      dueDates: dueDates,
      description: _descController.text,
      publishPlatform: _publishPlatform,
      postType: _postType,
      mediaMode: _mediaMode,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isInitialized ? 'Workflow updated successfully!' : 'Workflow setup successfully!'), backgroundColor: Colors.green));
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to setup workflow or tasks already exist.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCombined = _postData['isCombined'] == true;
    final isInitialized = _postData['isInitialized'] == true;
    final postNo = isCombined ? _postData['postNo'] : _postData['PostNo'];
    final themeName = isCombined ? 'Combined Group' : (_postData['Theme'] ?? 'No Theme');
    final provider = context.watch<EventProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Workflow'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Post Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Post #$postNo', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(themeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  if (_postData['Program']?.toString().isNotEmpty == true) ...[
                                    const SizedBox(height: 2),
                                    Text(_postData['Program'].toString(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                  ],
                                ],
                              ),
                            ),
                            // Status selector: Active, Later, Skip, Data Unavailable
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusBadgeBg(_postStatus),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getStatusBadgeBorder(_postStatus)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _postStatusOptions.contains(_postStatus) ? _postStatus : 'Active',
                                  icon: Icon(Icons.arrow_drop_down, color: _getStatusBadgeText(_postStatus), size: 20),
                                  isDense: true,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _getStatusBadgeText(_postStatus),
                                  ),
                                  items: _postStatusOptions.map((opt) {
                                    return DropdownMenuItem<String>(
                                      value: opt,
                                      child: Text(
                                        opt,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusBadgeText(opt),
                                          fontSize: 13,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newVal) async {
                                    if (newVal == null || newVal == _postStatus) return;
                                    setState(() {
                                      _postStatus = newVal;
                                      _postData['PostStatus'] = newVal;
                                    });
                                    final ok = await provider.updatePostMeta(postNo.toString(), {'postStatus': newVal});
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok ? 'Status updated to "$newVal"' : 'Failed to update status'),
                                          backgroundColor: ok ? Colors.green : Colors.red,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        // Activity Type Dropdown (Editable & persists to sheet)
                        Row(
                          children: [
                            Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            const Text(
                              'Activity Type:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _activityTypeOptions.contains(_activityType)
                                        ? _activityType
                                        : null,
                                    hint: Text(
                                      _activityType.isNotEmpty ? _activityType : 'Select Activity Type',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _activityType.isNotEmpty ? Colors.black87 : Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    isExpanded: true,
                                    isDense: true,
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    items: _activityTypeOptions.map((opt) {
                                      return DropdownMenuItem<String>(
                                        value: opt,
                                        child: Text(opt, style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (newVal) async {
                                      if (newVal == null || newVal == _activityType) return;
                                      setState(() {
                                        _activityType = newVal;
                                        _postData['ActivityType'] = newVal;
                                      });
                                      final ok = await provider.updatePostMeta(postNo.toString(), {'activityType': newVal});
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(ok ? 'Activity Type updated to "$newVal"' : 'Failed to update Activity Type'),
                                            backgroundColor: ok ? Colors.green : Colors.red,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Combined Events Breakdown (if combined)
                  if (isCombined && (_postData['combinedPosts'] as List<dynamic>? ?? []).isNotEmpty) ...[
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
                                  'Combined Events (${(_postData['combinedPosts'] as List).length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...( _postData['combinedPosts'] as List).asMap().entries.map((entry) {
                              final idx = entry.key;
                              final p = entry.value as Map<String, dynamic>;
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
                                    if (pDate.isNotEmpty) _infoRow(Icons.calendar_today, 'Date', pDate),
                                    if (pBranch.isNotEmpty) _infoRow(Icons.location_city, 'Branch', pState.isNotEmpty ? '$pBranch, $pState' : pBranch),
                                    if (pVenue.isNotEmpty) _infoRow(Icons.place, 'Venue', pVenue),
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
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Event Details Card (Individual post)
                  if (!isCombined) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Event Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 12),
                            if (_postData['Date']?.toString().isNotEmpty == true)
                              _infoRow(Icons.calendar_today, 'Date', _postData['Date'].toString()),
                            if (_postData['Branch']?.toString().isNotEmpty == true)
                              _infoRow(Icons.location_city, 'Branch', '${_postData['Branch'] ?? ''}${_postData['State']?.toString().isNotEmpty == true ? ', ${_postData['State']}' : ''}'),
                            if (_postData['Venue']?.toString().isNotEmpty == true)
                              _infoRow(Icons.place, 'Venue', _postData['Venue'].toString()),
                            if (_postData['Organizers']?.toString().isNotEmpty == true)
                              _infoRow(Icons.people, 'Organizers', _postData['Organizers'].toString()),
                            if (_postData['Partners']?.toString().isNotEmpty == true)
                              _infoRow(Icons.handshake, 'Partners', _postData['Partners'].toString()),
                            if (_postData['Timings']?.toString().isNotEmpty == true)
                              _infoRow(Icons.access_time, 'Timings', _postData['Timings'].toString()),
                            if (_postData['ActivityType']?.toString().isNotEmpty == true)
                              _infoRow(Icons.category, 'Activity Type', _postData['ActivityType'].toString()),
                            if (_postData['MOP']?.toString().isNotEmpty == true)
                              _infoRow(Icons.campaign, 'Promotion (MOP)', _postData['MOP'].toString()),
                            if (_postData['ImportantInfo']?.toString().isNotEmpty == true)
                              _infoRow(Icons.info_outline, 'Important', _postData['ImportantInfo'].toString()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Guest / Speaker / Participant Card (if any)
                    if (_postData['GuestName']?.toString().isNotEmpty == true ||
                        _postData['GuestOrg']?.toString().isNotEmpty == true ||
                        _postData['GuestType']?.toString().isNotEmpty == true ||
                        _postData['GuestDesignation']?.toString().isNotEmpty == true) ...[
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
                              if (_postData['GuestType']?.toString().isNotEmpty == true)
                                _infoRow(Icons.person_pin, 'Type', _postData['GuestType'].toString()),
                              if (_postData['GuestName']?.toString().isNotEmpty == true)
                                _infoRow(Icons.person, 'Name', _postData['GuestName'].toString()),
                              if (_postData['GuestDesignation']?.toString().isNotEmpty == true)
                                _infoRow(Icons.work, 'Designation', _postData['GuestDesignation'].toString()),
                              if (_postData['GuestOrg']?.toString().isNotEmpty == true)
                                _infoRow(Icons.business, 'Organization', _postData['GuestOrg'].toString()),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Beneficiaries Card
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
                                _benCircle('👨', 'Male', int.tryParse(_postData['Male']?.toString() ?? '') ?? 0, const Color(0xFF42A5F5)),
                                _benCircle('👩', 'Female', int.tryParse(_postData['Female']?.toString() ?? '') ?? 0, const Color(0xFFE91E63)),
                                _benCircle('🧒', 'Children', int.tryParse(_postData['Children']?.toString() ?? '') ?? 0, const Color(0xFFFF9800)),
                                _benCircle('👥', 'Total', int.tryParse(_postData['TotalBeneficiary']?.toString() ?? '') ?? 0, theme.colorScheme.primary),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Media Folders Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.folder_shared, color: Color(0xFF1565C0)),
                              const SizedBox(width: 8),
                              const Text('Media & Raw Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isLoadingMedia)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                    SizedBox(width: 12),
                                    Text('Checking Drive folders...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              ),
                            )
                          else if (isCombined && _groupMediaLinks.isNotEmpty) ...[
                            ..._groupMediaLinks.map((g) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Post #${g.postNo} - ${g.theme}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.indigo)),
                                  const SizedBox(height: 6),
                                  if (g.rawFolder.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(bottom: 6), child: _mediaButton(Icons.photo_library, 'View Photos / Videos (Raw)', 'Original files from event', Colors.blueGrey, () => _openLink(g.rawFolder))),
                                  if (g.selectedFolder.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(bottom: 6), child: _mediaButton(Icons.checklist, 'Selected Folder', 'Selected picks', Colors.teal, () => _openLink(g.selectedFolder))),
                                  if (g.monthLink.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(bottom: 12), child: _mediaButton(Icons.folder_shared, 'Date Folder Archive', '', const Color(0xFFF39C12), () => _openLink(g.monthLink))),
                                  const Divider(),
                                ],
                              );
                            }),
                            if (_editedFolderLink.isNotEmpty)
                              _mediaButton(Icons.auto_fix_high, 'Selected (Edited) [Group Master]', 'Edited files for the whole group', Colors.purple, () => _openLink(_editedFolderLink)),
                          ] else ...[
                            if (_rawFolderLink.isNotEmpty)
                              _mediaButton(Icons.photo_library, 'View Photos / Videos (Raw)', 'Original unedited files', Colors.blueGrey, () => _openLink(_rawFolderLink))
                            else if (widget.postData['FolderLink']?.toString().isNotEmpty == true)
                              _mediaButton(Icons.photo_library, 'View Photos / Videos (Raw / Event Folder)', 'Date drive link', Colors.blueGrey, () => _openLink(widget.postData['FolderLink'].toString())),
                            if (_selectedFolderLink.isNotEmpty)
                              _mediaButton(Icons.checklist, 'Selected Photos', 'Best picks from Raw', Colors.teal, () => _openLink(_selectedFolderLink)),
                            if (_editedFolderLink.isNotEmpty)
                              _mediaButton(Icons.auto_fix_high, 'Selected (Edited)', 'Edited and approved files', Colors.purple, () => _openLink(_editedFolderLink)),
                            if (widget.postData['FolderLink']?.toString().isNotEmpty == true && widget.postData['FolderLink'].toString() != _rawFolderLink)
                              _mediaButton(Icons.folder_shared, 'Date Folder', 'Media drive archive', const Color(0xFFF39C12), () => _openLink(widget.postData['FolderLink'].toString())),
                            if (_rawFolderLink.isEmpty && (widget.postData['FolderLink']?.toString().isEmpty ?? true))
                              Text('No media folder links registered for this post yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Post Meta
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Post Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildRadioGroup('Publishing Platform', ['WhatsApp', 'Instagram'], _publishPlatform, (v) => setState(() => _publishPlatform = v)),
                          const Divider(height: 24),
                          _buildRadioGroup('Post Type', ['Individual', 'Combined'], _postType, (v) => setState(() => _postType = v)),
                          const Divider(height: 24),
                          _buildRadioGroup('Media Mode', ['Photos', 'Video'], _mediaMode, (v) => setState(() => _mediaMode = v)),
                          const Divider(height: 24),
                          const Text('Content Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descController,
                            maxLines: 3,
                            decoration: const InputDecoration(hintText: 'Enter guidelines for writers...'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Assignments
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Content Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              TextButton.icon(
                                icon: const Icon(Icons.auto_awesome, size: 16),
                                label: const Text('Auto-calculate Due Dates', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  _applyDefaultDueDates(force: true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Default due dates calculated from today!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('1. Writer', 'Writer', _selectedWriter, (v) => setState(() => _selectedWriter = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _writingDue, (d) => setState(() => _writingDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('2. Editor', 'Editor', _selectedEditor, (v) => setState(() => _selectedEditor = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _editingDue, (d) => setState(() => _editingDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('3. Proofreader', 'Proofreader', _selectedProofreader, (v) => setState(() => _selectedProofreader = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _proofreadingDue, (d) => setState(() => _proofreadingDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('4. Text Crosscheck', 'CrossChecker', _selectedCrosscheck, (v) => setState(() => _selectedCrosscheck = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _crosscheckDue, (d) => setState(() => _crosscheckDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('5. Ready to Post', 'Uploader', _selectedUploader, (v) => setState(() => _selectedUploader = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _uploaderDue, (d) => setState(() => _uploaderDue = d))),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text('Media Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          
                          if (_publishPlatform.toLowerCase().contains('insta') && _mediaMode.toLowerCase().contains('video')) ...[
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('1. Thumbnail Selection', 'Thumbnail Designer', _selectedThumbnailSelect, (v) => setState(() => _selectedThumbnailSelect = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _thumbnailSelectDue, (d) => setState(() => _thumbnailSelectDue = d))),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('2. Thumbnail Processing', 'Thumbnail Designer', _selectedThumbnailProcess, (v) => setState(() => _selectedThumbnailProcess = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _thumbnailProcessDue, (d) => setState(() => _thumbnailProcessDue = d))),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('3. Thumbnail Cross checking', 'Thumbnail Designer', _selectedThumbnailCrosscheck, (v) => setState(() => _selectedThumbnailCrosscheck = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _thumbnailCrosscheckDue, (d) => setState(() => _thumbnailCrosscheckDue = d))),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Divider(),
                            ),
                          ],
                          
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('Photos Clean (Post-Publishing)', 'Photo Selector', _selectedPhotosClean, (v) => setState(() => _selectedPhotosClean = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _photosCleanDue, (d) => setState(() => _photosCleanDue = d))),
                            ],
                          ),
                          
                          if (_mediaMode.toLowerCase().contains('photo')) ...[
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('Photo Editing', 'Photo Editor', _selectedPhotoEdit, (v) => setState(() => _selectedPhotoEdit = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _photoEditDue, (d) => setState(() => _photoEditDue = d))),
                              ],
                            ),
                          ],
                          
                          if (_mediaMode.toLowerCase().contains('video')) ...[
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildUserDropdown('Video Editing', 'Video Editor', _selectedVideoEdit, (v) => setState(() => _selectedVideoEdit = v))),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: _buildDateField('Due Date', _videoEditDue, (d) => setState(() => _videoEditDue = d))),
                              ],
                            ),
                          ],
                          
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('Media Cross Check', 'Media CrossChecker', _selectedMediaCheck, (v) => setState(() => _selectedMediaCheck = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _mediaCheckDue, (d) => setState(() => _mediaCheckDue = d))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildUserDropdown('Media Final Cross check', 'Media CrossChecker', _selectedMediaFinalCheck, (v) => setState(() => _selectedMediaFinalCheck = v))),
                              const SizedBox(width: 12),
                              Expanded(flex: 1, child: _buildDateField('Due Date', _mediaFinalCheckDue, (d) => setState(() => _mediaFinalCheckDue = d))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    icon: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(isInitialized ? Icons.update : Icons.rocket_launch),
                    label: Text(
                      _isLoading ? 'Processing...' : (isInitialized ? 'Update Tasks & Folders' : 'Create Tasks & Folders'), 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _submit,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
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
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
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
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.2)),
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
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 18, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusBadgeBg(String status) {
    switch (status) {
      case 'Later':
        return Colors.purple.shade50;
      case 'Skip':
        return Colors.grey.shade100;
      case 'Data Unavailable':
        return Colors.red.shade50;
      case 'Active':
      default:
        return Colors.blue.shade50;
    }
  }

  Color _getStatusBadgeBorder(String status) {
    switch (status) {
      case 'Later':
        return Colors.purple.shade300;
      case 'Skip':
        return Colors.grey.shade400;
      case 'Data Unavailable':
        return Colors.red.shade300;
      case 'Active':
      default:
        return Colors.blue.shade300;
    }
  }

  Color _getStatusBadgeText(String status) {
    switch (status) {
      case 'Later':
        return Colors.purple.shade800;
      case 'Skip':
        return Colors.grey.shade800;
      case 'Data Unavailable':
        return Colors.red.shade800;
      case 'Active':
      default:
        return Colors.blue.shade800;
    }
  }
}

