import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../services/api_service.dart';

class EventProvider with ChangeNotifier {
  List<Event> _events = [];
  List<Map<String, dynamic>> _rawPosts = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _devUsers = [];
  List<Map<String, dynamic>> _spocs = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  // ── In-memory caches ──
  final Map<String, Map<String, String>> _folderCache = {};

  // Cache keys for localStorage
  static const _cacheKeyEvents = 'cache_events';
  static const _cacheKeyPosts  = 'cache_posts';
  static const _cacheKeyTsEvents = 'cache_ts_events';
  static const _cacheKeyTsPosts  = 'cache_ts_posts';
  // Consider cache valid for 3 minutes
  static const _cacheTtlMs = 3 * 60 * 1000;

  List<Event> get events => _events;
  List<Map<String, dynamic>> get rawPosts => _rawPosts;
  List<Map<String, dynamic>> get users => _users;
  List<Map<String, dynamic>> get devUsers => _devUsers.isNotEmpty ? _devUsers : _users;
  List<Map<String, dynamic>> get spocs => _spocs;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  final ApiService _apiService = ApiService();

  // ── Load events from localStorage and show immediately, then refresh in bg ──
  Future<void> fetchEvents(String role, String username, {bool silent = false, bool force = false}) async {
    final isAdmin = role.toLowerCase() == 'admin';
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    // If force refresh is requested, wipe cached data so stale data is never shown
    if (force) {
      await invalidateCache();
    }

    // --- STEP 1: Serve from localStorage cache instantly (only if NOT force) ---
    bool loadedFromCache = false;
    if (!force) {
      final cachedEventsJson = prefs.getString(_cacheKeyEvents);
      if (cachedEventsJson != null && cachedEventsJson.isNotEmpty) {
        try {
          final List<dynamic> cachedList = json.decode(cachedEventsJson);
          _events = cachedList.map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();
          loadedFromCache = true;
          debugPrint('⚡ Events loaded from cache instantly (${_events.length} items)');
        } catch (e) {
          debugPrint('Cache parse error: $e');
        }
      }

      if (isAdmin) {
        final cachedPostsJson = prefs.getString(_cacheKeyPosts);
        if (cachedPostsJson != null && cachedPostsJson.isNotEmpty) {
          try {
            final List<dynamic> cachedList = json.decode(cachedPostsJson);
            _rawPosts = cachedList.map((e) => e as Map<String, dynamic>).toList();
            debugPrint('⚡ Posts loaded from cache instantly (${_rawPosts.length} items)');
          } catch (e) {
            debugPrint('Posts cache parse error: $e');
          }
        }
      }
    }

    // Show cached data immediately — no loading spinner if we have cache
    if (loadedFromCache) {
      _isLoading = false;
      _isSyncing = true;
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    // --- STEP 2: Fetch fresh data in background ---
    // Try fetching from Supabase first for lightning-fast loads (<100ms)
    try {
      final supaPosts = await _apiService.fetchPostsFromSupabase();
      final supaTasks = await _apiService.fetchTasksFromSupabase(role: role, username: username);

      if (supaTasks.isNotEmpty || supaPosts.isNotEmpty) {
        // Map tasks and join with posts metadata (supporting both individual PostNo and GroupID)
        final postsMap = <String, List<Map<String, dynamic>>>{};
        for (final p in supaPosts) {
          final pNo = p['PostNo']?.toString() ?? p['post_no']?.toString() ?? '';
          final gId = p['GroupID']?.toString() ?? p['group_id']?.toString() ?? '';
          if (pNo.isNotEmpty) {
            postsMap.putIfAbsent(pNo, () => []).add(p);
          }
          if (gId.isNotEmpty && gId != pNo) {
            postsMap.putIfAbsent(gId, () => []).add(p);
          }
        }

        final List<Event> supaEvents = [];
        for (final t in supaTasks) {
          final merged = Map<String, dynamic>.from(t);
          final tPostNo = t['post_no']?.toString() ?? '';
          final matched = postsMap[tPostNo] ?? [];

          if (matched.length == 1) {
            merged.addAll(matched.first);
            // Ensure original task post_no isn't overwritten by post's post_no if task is a combined group!
            merged['post_no'] = tPostNo;
            merged['PostNo'] = tPostNo;
          } else if (matched.length > 1) {
            int totalM = 0, totalF = 0, totalC = 0;
            for (final m in matched) {
              totalM += (m['Male'] ?? m['male'] ?? 0) as int;
              totalF += (m['Female'] ?? m['female'] ?? 0) as int;
              totalC += (m['Children'] ?? m['children'] ?? 0) as int;
            }
            final firstP = matched.first;
            merged.addAll(firstP);
            // Crucial: keep the combined task postNo / Title as the task's PostNo and Theme!
            merged['post_no'] = tPostNo;
            merged['PostNo'] = tPostNo;
            merged['theme'] = tPostNo;
            merged['Theme'] = tPostNo;
            merged['male'] = totalM;
            merged['female'] = totalF;
            merged['children'] = totalC;
            merged['total_beneficiary'] = totalM + totalF + totalC;
            merged['is_combined'] = true;
            merged['isCombined'] = true;
            merged['combined_posts'] = matched;
            merged['CombinedPosts'] = matched;
          } else {
            // No direct post matched, but check if task itself is marked combined
            if (tPostNo.toLowerCase().contains('combined')) {
              merged['is_combined'] = true;
              merged['isCombined'] = true;
              merged['theme'] = tPostNo;
              merged['Theme'] = tPostNo;
            }
          }

          supaEvents.add(Event.fromJson(merged));
        }

        _events = supaEvents;
        _rawPosts = supaPosts;

        _isLoading = false;
        _isSyncing = false;
        notifyListeners();

        // Save fresh data to local cache
        prefs.setString(_cacheKeyEvents, json.encode(_events.map((e) => e.toJson()).toList()));
        prefs.setInt(_cacheKeyTsEvents, now);
        if (_rawPosts.isNotEmpty) {
          prefs.setString(_cacheKeyPosts, json.encode(_rawPosts));
          prefs.setInt(_cacheKeyTsPosts, now);
        }
        debugPrint('🚀 [Supabase Fast-Path] Loaded ${_events.length} events and ${_rawPosts.length} posts seamlessly!');
        return;
      }
    } catch (supaErr) {
      debugPrint('⚠️ Supabase fetch fallback to GAS: $supaErr');
    }

    // --- STEP 3: Fallback to Google Apps Script if Supabase is offline ---
    try {
      final taskPayload = <String, dynamic>{'action': 'getTasks', 'role': role, 'username': username};
      final postPayload = <String, dynamic>{'action': 'getPosts'};
      if (force) {
        taskPayload['forceRefresh'] = true;
        postPayload['forceRefresh'] = true;
      }
      if (isAdmin) {
        final results = await Future.wait([
          _apiService.postData(taskPayload),
          _apiService.postData(postPayload),
        ]);

        final tasksResponse = results[0];
        final postsResponse = results[1];

        if (tasksResponse['success'] == true) {
          final List<dynamic> tasksData = tasksResponse['tasks'];
          _events = tasksData.map((json) => Event.fromJson(json)).toList();
          // Save to localStorage
          prefs.setString(_cacheKeyEvents, json.encode(tasksData));
          prefs.setInt(_cacheKeyTsEvents, now);
        }
        if (postsResponse['success'] == true) {
          final List<dynamic> postsData = postsResponse['posts'];
          _rawPosts = postsData.map((e) => e as Map<String, dynamic>).toList();
          // Save to localStorage
          prefs.setString(_cacheKeyPosts, json.encode(postsData));
          prefs.setInt(_cacheKeyTsPosts, now);
        }
      } else {
        final response = await _apiService.postData({
          'action': 'getTasks',
          'role': role,
          'username': username,
        });

        if (response['success'] == true) {
          final List<dynamic> tasksData = response['tasks'];
          _events = tasksData.map((json) => Event.fromJson(json)).toList();
          // Save to localStorage
          prefs.setString(_cacheKeyEvents, json.encode(tasksData));
          prefs.setInt(_cacheKeyTsEvents, now);
        }
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
    }

    _isLoading = false;
    _isSyncing = false;
    notifyListeners();
  }

  // ── Force clear localStorage cache (call after mark done/reassign) ──
  Future<void> invalidateCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKeyEvents);
    await prefs.remove(_cacheKeyPosts);
    await prefs.remove(_cacheKeyTsEvents);
    await prefs.remove(_cacheKeyTsPosts);
    debugPrint('🗑️ Cache completely invalidated — next fetch will go to network');
  }

  Future<void> fetchAllPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final response = await _apiService.postData({'action': 'getPosts'});
      if (response['success'] == true) {
        final List<dynamic> postsData = response['posts'];
        _rawPosts = postsData.map((e) => e as Map<String, dynamic>).toList();
        prefs.setString(_cacheKeyPosts, json.encode(postsData));
        prefs.setInt(_cacheKeyTsPosts, now);
      }
    } catch (e) {
      debugPrint('Error fetching raw posts: $e');
    }
  }


  Future<bool> checkFolderNotEmpty(String postNo) async {
    try {
      final response = await _apiService.postData({
        'action': 'checkFolderNotEmpty',
        'postNo': postNo,
      });
      return response['notEmpty'] == true;
    } catch (e) {
      return true; // Failsafe
    }
  }

  Future<Map<String, dynamic>> checkThumbnailFolderNotEmpty(String postNo, {String? folderLink}) async {
    try {
      final payload = <String, dynamic>{
        'action': 'checkFolderNotEmpty',
        'postNo': postNo,
        'checkType': 'thumbnail',
        'stage': 'Thumbnail Processing',
      };
      if (folderLink != null && folderLink.isNotEmpty) {
        payload['folderLink'] = folderLink;
      }
      final response = await _apiService.postData(payload);
      return {
        'notEmpty': response['notEmpty'] == true,
        'error': response['error']?.toString() ?? 'The "Edited Thumbnail" folder under "Selected (Edited)" is empty! Please upload the edited thumbnail files.',
      };
    } catch (e) {
      return {'notEmpty': true}; // Failsafe
    }
  }

  Future<String?> updateEvent(Event event, Map<String, dynamic> updates) async {
    // Optimistic UI update
    final originalStatus = event.status;
    final originalCanvaLink = event.canvaLink;
    if (updates.containsKey('Status')) {
      event.status = updates['Status'];
      notifyListeners();
    }
    if (updates.containsKey('CanvaLink')) {
      event.canvaLink = updates['CanvaLink']?.toString() ?? '';
      // Also update sibling tasks of the same post in local cache
      final postTasks = _events.where((t) => t.postNo == event.postNo);
      for (final t in postTasks) {
        t.canvaLink = event.canvaLink;
      }
      notifyListeners();
    }

    invalidateCache();

    // ── Instant Supabase Write (takes ~50ms) ──
    try {
      _apiService.updateTaskInSupabase(event.taskId, updates);
    } catch (_) {}

    try {
      final response = await _apiService.postData({
        'action': 'updateTask',
        'taskId': event.taskId,
        'rowIndex': event.rowIndex,
        'updates': updates,
      });

      if (response['success'] == true) {
        return null; // Success
      }
      
      if (response['success'] == false && response['message'] == 'Invalid server response') {
        return 'timeout'; // GAS background execution succeeded but load balancer timed out
      }
      
      // Revert optimistic update on error
      if (updates.containsKey('Status')) {
        event.status = originalStatus;
      }
      if (updates.containsKey('CanvaLink')) {
        event.canvaLink = originalCanvaLink;
      }
      notifyListeners();
      return response['message']?.toString() ?? 'Unknown backend error';
    } catch (e) {
      debugPrint('Error updating event: $e');
      // Treat network/timeout exceptions as success because GAS scripts usually succeed in the background.
      return 'timeout'; 
    }
  }

  Future<bool> reverseTask({
    required String postNo,
    required String currentStage,
    required String targetStage,
    String reason = '',
  }) async {
    invalidateCache();
    try {
      final response = await _apiService.postData({
        'action': 'reverseTask',
        'postNo': postNo,
        'currentStage': currentStage,
        'targetStage': targetStage,
        'reason': reason,
      });
      if (response['success'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint('Error reversing task: $e');
      return true;
    }
    return false;
  }

  Future<bool> reassignTask(Event event, String newEmail, {String? newName, String? role}) async {
    final originalAssignee = event.assignee;
    final originalAssigneeName = event.assigneeName;
    
    // Resolve name
    String resolvedName = newName ?? '';
    if (resolvedName.isEmpty) {
      final u = users.firstWhere(
        (u) => (u['username'] ?? u['email'] ?? '').toString().toLowerCase() == newEmail.toLowerCase(), 
        orElse: () => {}
      );
      if (u.isNotEmpty) {
        resolvedName = u['name'] ?? newEmail;
      } else {
        resolvedName = newEmail;
      }
    }

    // 1. Optimistic UI update on the event object
    event.assignee = newEmail;
    event.assigneeName = resolvedName;

    // 2. CRUCIAL: Also update all matching tasks in provider's _events list!
    final normTargetStage = event.stage.toLowerCase().replaceAll(' ', '');
    for (final ev in _events) {
      final evStage = ev.stage.toLowerCase().replaceAll(' ', '');
      if (ev.taskId == event.taskId || (ev.postNo == event.postNo && evStage == normTargetStage)) {
        ev.assignee = newEmail;
        ev.assigneeName = resolvedName;
      }
    }
    notifyListeners();

    // 3. Update local cache immediately so internal refresh or re-render has the new assignee
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyEvents, json.encode(_events.map((e) => e.toJson()).toList()));
    } catch (_) {}

    // 4. Instant write to Supabase (takes ~50ms so refresh sees new name immediately)
    try {
      _apiService.updateTaskInSupabase(event.taskId, {
        'Assignee': event.assignee,
        'AssigneeName': event.assigneeName,
      });
    } catch (_) {}

    try {
      final response = await _apiService.postData({
        'action': 'reassignTasks',
        'postNo': event.postNo,
        'taskId': event.taskId,
        'isCombined': event.isCombined,
        'stage': event.stage,
        'newAssigneeEmail': newEmail,
        'newAssigneeName': resolvedName,
        'role': role,
      });

      if (response['success'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint('Error reassigning task: $e');
      // Treat network/timeout exceptions as success because GAS scripts usually succeed in the background.
      return true;
    }
    
    // Revert only if we get a clean `{success: false}` from the backend
    event.assignee = originalAssignee;
    event.assigneeName = originalAssigneeName;
    for (final ev in _events) {
      final evStage = ev.stage.toLowerCase().replaceAll(' ', '');
      if (ev.taskId == event.taskId || (ev.postNo == event.postNo && evStage == normTargetStage)) {
        ev.assignee = originalAssignee;
        ev.assigneeName = originalAssigneeName;
      }
    }
    notifyListeners();
    return false;
  }

  Future<bool> createTasksForPost(String postNo) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postData({
        'action': 'createTasksForPost',
        'postNo': postNo,
      });

      if (response['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error creating tasks: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> fetchUsers() async {
    try {
      final response = await _apiService.postData({'action': 'getUsers'});
      if (response['success'] == true) {
        final List<dynamic> usersData = response['users'];
        _users = usersData.map((e) => e as Map<String, dynamic>).toList();
        notifyListeners();
      }
      await fetchDevUsers();
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }

  Future<void> fetchDevUsers() async {
    try {
      final response = await _apiService.postData({'action': 'getDevUsers'});
      if (response['success'] == true && response['users'] is List) {
        final List<dynamic> devUsersData = response['users'];
        _devUsers = devUsersData.map((e) => e as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching dev users: $e');
    }
  }

  Future<void> fetchBranchSPOCs() async {
    try {
      final response = await _apiService.postData({'action': 'getBranchSPOCs'});
      if (response['success'] == true) {
        final List<dynamic> spocsData = response['spocs'];
        _spocs = spocsData.map((e) => e as Map<String, dynamic>).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching SPOCs: $e');
    }
  }

  Future<bool> updateBranchSPOC(String branch, String spocName, String spocEmail) async {
    try {
      final response = await _apiService.postData({
        'action': 'updateBranchSPOC',
        'branch': branch,
        'spocName': spocName,
        'spocEmail': spocEmail,
      });
      if (response['success'] == true) {
        await fetchBranchSPOCs();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating SPOC: $e');
    }
    return false;
  }

  Future<bool> groupPosts(List<String> postNos, String groupId) async {
    invalidateCache();
    try {
      final response = await _apiService.postData({
        'action': 'groupPosts',
        'postNos': postNos,
        'groupId': groupId,
      });
      if (response['success'] == true) {
        for (var p in _rawPosts) {
          final pNo = p['PostNo']?.toString() ?? '';
          if (postNos.contains(pNo)) {
            p['GroupID'] = groupId;
            final curStatus = p['PostStatus']?.toString().trim().toLowerCase() ?? '';
            if (curStatus == 'data unavailable' || curStatus == 'dataunavailable') {
              p['PostStatus'] = '';
            }
          }
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error grouping posts: $e');
    }
    return false;
  }

  Future<bool> ungroupPost(String postNo) async {
    invalidateCache();
    try {
      final response = await _apiService.postData({
        'action': 'ungroupPost',
        'postNo': postNo,
      });
      if (response['success'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint('Error ungrouping post: $e');
    }
    return false;
  }

  Future<bool> renameGroup(String oldGroupId, String newGroupId) async {
    invalidateCache();
    try {
      final response = await _apiService.postData({
        'action': 'renameGroup',
        'oldGroupId': oldGroupId,
        'newGroupId': newGroupId,
      });
      if (response['success'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint('Error renaming group: $e');
    }
    return false;
  }

  Future<bool> updatePostMeta(String postNo, Map<String, dynamic> updates) async {
    try {
      final Map<String, dynamic> payload = {'action': 'updatePostMeta', 'postNo': postNo};
      payload.addAll(updates);
      final response = await _apiService.postData(payload);
      if (response['success'] == true) {
        // Update in-memory rawPosts if present
        for (var p in _rawPosts) {
          if (p['PostNo']?.toString() == postNo || (p['GroupID']?.toString().isNotEmpty == true && p['GroupID']?.toString() == postNo)) {
            if (updates.containsKey('activityType')) {
              p['ActivityType'] = updates['activityType'];
            }
            if (updates.containsKey('postStatus')) {
              p['PostStatus'] = updates['postStatus'];
            }
            if (updates.containsKey('publishPlatform')) {
              p['PublishPlatform'] = updates['publishPlatform'];
            }
            if (updates.containsKey('postType')) {
              p['PostType'] = updates['postType'];
            }
            if (updates.containsKey('mediaMode')) {
              p['MediaMode'] = updates['mediaMode'];
            }
            if (updates.containsKey('description')) {
              p['Description'] = updates['description'];
            }
          }
        }
        // Save to localStorage cache
        try {
          final prefs = await SharedPreferences.getInstance();
          prefs.setString(_cacheKeyPosts, json.encode(_rawPosts));
        } catch (_) {}
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error updating post meta: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>> updateBeneficiaries({
    required String postNo,
    required String state,
    required String branch,
    required String venue,
    required String date,
    required int prevMale,
    required int prevFemale,
    required int prevChildren,
    required int male,
    required int female,
    required int children,
    Event? event,
    Map<String, dynamic>? subPost,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'action': 'updateBeneficiaries',
        'postNo': postNo,
        'state': state,
        'branch': branch,
        'venue': venue,
        'date': date,
        'prevMale': prevMale,
        'prevFemale': prevFemale,
        'prevChildren': prevChildren,
        'male': male,
        'female': female,
        'children': children,
      };
      final response = await _apiService.postData(payload);
      if (response['success'] == true) {
        final total = male + female + children;
        // 1. Update the Event object if provided
        if (event != null) {
          event.male = male;
          event.female = female;
          event.children = children;
          event.totalBeneficiary = total;
        }
        // 2. Update subPost if provided
        if (subPost != null) {
          subPost['Male'] = male;
          subPost['Female'] = female;
          subPost['Children'] = children;
          subPost['TotalBeneficiary'] = total;
        }
        // If event is combined, recompute total across its subposts
        if (event != null && event.isCombined && event.combinedPosts.isNotEmpty) {
          int cMale = 0, cFemale = 0, cChildren = 0;
          for (var sp in event.combinedPosts) {
            cMale += int.tryParse(sp['Male']?.toString() ?? '0') ?? 0;
            cFemale += int.tryParse(sp['Female']?.toString() ?? '0') ?? 0;
            cChildren += int.tryParse(sp['Children']?.toString() ?? '0') ?? 0;
          }
          event.male = cMale;
          event.female = cFemale;
          event.children = cChildren;
          event.totalBeneficiary = cMale + cFemale + cChildren;
        }
        // 3. Update in _rawPosts
        for (var p in _rawPosts) {
          if (p['PostNo']?.toString() == postNo) {
            p['Male'] = male;
            p['Female'] = female;
            p['Children'] = children;
            p['TotalBeneficiary'] = total;
            break;
          }
        }
        // 4. Update in _events list
        for (var ev in _events) {
          if (ev.postNo == postNo) {
            ev.male = male;
            ev.female = female;
            ev.children = children;
            ev.totalBeneficiary = total;
          }
          if (ev.isCombined && ev.combinedPosts.isNotEmpty) {
            for (var sp in ev.combinedPosts) {
              if (sp['PostNo']?.toString() == postNo) {
                sp['Male'] = male;
                sp['Female'] = female;
                sp['Children'] = children;
                sp['TotalBeneficiary'] = total;
              }
            }
          }
        }
        // 5. Update local storage cache
        try {
          final prefs = await SharedPreferences.getInstance();
          prefs.setString(_cacheKeyPosts, json.encode(_rawPosts));
        } catch (_) {}
        notifyListeners();
        return {'success': true, 'message': response['message'] ?? 'Beneficiaries updated successfully!'};
      } else {
        return {'success': false, 'message': response['message'] ?? 'Failed to update beneficiaries.'};
      }
    } catch (e) {
      debugPrint('Error updating beneficiaries: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> createTasksForPostV2({
    required String postNo,
    required Map<String, String> assignees,
    required Map<String, String> dueDates,
    required String description,
    required String publishPlatform,
    required String postType,
    required String mediaMode,
  }) async {
    // ── Instant in-memory and Supabase update: Clear 'Skip' / 'Inactive' tag when assigned ──
    for (var p in _rawPosts) {
      if (p['PostNo']?.toString() == postNo || (p['GroupID']?.toString().isNotEmpty == true && p['GroupID']?.toString() == postNo)) {
        p['PostStatus'] = '';
        p['post_status'] = '';
        p['Description'] = description;
        p['PublishPlatform'] = publishPlatform;
        p['PostType'] = postType;
        p['MediaMode'] = mediaMode;
      }
    }
    notifyListeners();

    try {
      _apiService.updatePostInSupabase(postNo, {
        'postStatus': '',
        'description': description,
        'publishPlatform': publishPlatform,
        'postType': postType,
        'mediaMode': mediaMode,
      });
    } catch (_) {}

    try {
      final res = await _apiService.postData({
        'action': 'createTasksForPostV2',
        'postNo': postNo,
        'assignees': assignees,
        'dueDates': dueDates,
        'description': description,
        'publishPlatform': publishPlatform,
        'postType': postType,
        'mediaMode': mediaMode,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error creating tasks v2: $e');
      return false;
    }
  }

  Future<bool> deleteWorkflow({
    required String postNo,
    bool isCombined = false,
    String? username,
    String? role,
  }) async {
    try {
      final res = await _apiService.postData({
        'action': 'deleteWorkflow',
        'postNo': postNo,
        'isCombined': isCombined,
      });

      if (res['success'] == true) {
        // Optimistically remove tasks locally
        _events.removeWhere((t) => t.postNo == postNo);
        if (isCombined) {
          for (final p in _rawPosts) {
            if (p['GroupID']?.toString() == postNo) {
              p['GroupID'] = '';
            }
          }
        }
        notifyListeners();

        // Refresh events in background
        if (role != null && username != null) {
          fetchEvents(role, username);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting workflow: $e');
      return false;
    }
  }

  Future<Map<String, String>> fetchMediaFolders(String monthLink, String dateStr, String stage, {String venue = '', String postNo = ''}) async {
    // ── Layer 2: Flutter in-memory cache ──
    // Key combines postNo + dateStr to be unique per event
    final cacheKey = '${postNo.isNotEmpty ? postNo : monthLink}-$dateStr${venue.isNotEmpty ? '-$venue' : ''}';
    if (_folderCache.containsKey(cacheKey)) {
      debugPrint('📦 Folder cache HIT for $cacheKey');
      return _folderCache[cacheKey]!;
    }

    try {
      debugPrint('=== fetchMediaFolders (cache MISS: $cacheKey) ===');
      debugPrint('monthLink: $monthLink');
      debugPrint('dateStr sent to Apps Script: "$dateStr"');
      debugPrint('stage: "$stage"');
      
      final response = await _apiService.postData({
        'action': 'getMediaFolders',
        'monthLink': monthLink,
        'dateStr': dateStr,
        'stage': stage,
        'venue': venue,
        'postNo': postNo,
      });

      debugPrint('getMediaFolders response: $response');

      if (response['success'] == true) {
        final folders = response['folders'];
        debugPrint('raw: ${folders['raw']}');
        debugPrint('selected: ${folders['selected']}');
        debugPrint('edited: ${folders['edited']}');
        debugPrint('writingDoc: ${folders['writingDoc']}');
        debugPrint('BACKEND DEBUG: ${folders['debug']}');
        final result = {
          'raw': folders['raw']?.toString() ?? '',
          'selected': folders['selected']?.toString() ?? '',
          'edited': folders['edited']?.toString() ?? '',
          'writingDoc': folders['writingDoc']?.toString() ?? '',
        };
        // Store in cache for the rest of the session
        _folderCache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint('Error fetching media folders: $e');
    }
    return {'raw': '', 'selected': '', 'edited': '', 'writingDoc': ''};
  }

  Future<List<Map<String, dynamic>>> fetchPhotos(String folderUrl) async {
    if (folderUrl.isEmpty) return [];
    try {
      final response = await _apiService.postData({
        'action': 'getPhotos',
        'folderUrl': folderUrl,
      });

      if (response['success'] == true && response['photos'] != null) {
        return List<Map<String, dynamic>>.from(response['photos']);
      }
    } catch (e) {
      debugPrint('Error fetching photos: $e');
    }
    return [];
  }

  /// Fast targeted fetch for single post or combined group (completes in ~1-2 seconds)
  Future<Map<String, dynamic>?> fetchSinglePostDetails(String postNo, {bool isCombined = false}) async {
    try {
      final response = await _apiService.postData({
        'action': 'getPostDetails',
        'postNo': postNo,
        'isCombined': isCombined,
      });

      if (response['success'] == true) {
        final postData = response['postData'] as Map<String, dynamic>? ?? {};
        final combinedPosts = (response['combinedPosts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        final rawTasks = response['tasks'] as List<dynamic>? ?? [];
        final isCombinedVal = response['isCombined'] == true || combinedPosts.length > 1;

        final tasks = rawTasks.map((j) {
          final map = Map<String, dynamic>.from(j as Map<String, dynamic>);
          // Merge postData fields so theme, venue, folderLink, beneficiaries are available
          for (final key in postData.keys) {
            if (!map.containsKey(key) || map[key] == null || map[key].toString().isEmpty) {
              map[key] = postData[key];
            }
          }
          map['isCombined'] = isCombinedVal;
          map['CombinedPosts'] = combinedPosts;
          return Event.fromJson(map);
        }).toList();

        // Update in-memory tasks so other UI components can see them
        _events.removeWhere((t) => t.postNo == postNo);
        _events.addAll(tasks);

        return {
          'postData': postData,
          'combinedPosts': combinedPosts,
          'tasks': tasks,
          'isCombined': isCombinedVal,
        };
      }
    } catch (e) {
      debugPrint('Error fetching single post details: $e');
    }
    return null;
  }
}
