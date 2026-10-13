import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../services/api_service.dart';

class EventProvider with ChangeNotifier {
  List<Event> _events = [];
  List<Map<String, dynamic>> _rawPosts = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _spocs = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  // ── In-memory caches ──
  final Map<String, Map<String, String>> _folderCache = {};
  DateTime? _lastPostsFetch;

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
  List<Map<String, dynamic>> get spocs => _spocs;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

  final ApiService _apiService = ApiService();

  // ── Load events from localStorage and show immediately, then refresh in bg ──
  Future<void> fetchEvents(String role, String username, {bool silent = false, bool force = false}) async {
    final isAdmin = role.toLowerCase() == 'admin';
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    // --- STEP 1: Serve from localStorage cache instantly ---
    bool loadedFromCache = false;
    final cachedEventsJson = prefs.getString(_cacheKeyEvents);
    final cachedTs = prefs.getInt(_cacheKeyTsEvents) ?? 0;
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
    // Skip refresh only if NOT forced, cache is fresh, and not silent
    final cacheAge = now - cachedTs;
    if (!force && loadedFromCache && cacheAge < _cacheTtlMs && !silent) {
      debugPrint('✅ Cache is fresh (${ (cacheAge/1000).round()}s old), skipping network call');
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
      return;
    }

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
    await prefs.remove(_cacheKeyTsEvents);
    await prefs.remove(_cacheKeyTsPosts);
    debugPrint('🗑️ Cache invalidated — next fetch will go to network');
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

  Future<String?> updateEvent(Event event, Map<String, dynamic> updates) async {
    // Optimistic UI update
    final originalStatus = event.status;
    if (updates.containsKey('Status')) {
      event.status = updates['Status'];
      notifyListeners();
    }

    try {
      final response = await _apiService.postData({
        'action': 'updateTask',
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
        notifyListeners();
      }
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
    
    // Optimistic UI update
    event.assignee = newEmail;
    if (newName != null) {
      event.assigneeName = newName;
    } else {
      // Find name from users list if possible
      final u = users.firstWhere((u) => u['username'] == newEmail, orElse: () => {});
      if (u.isNotEmpty) {
        event.assigneeName = u['name'] ?? newEmail;
      }
    }
    notifyListeners();

    try {
      final response = await _apiService.postData({
        'action': 'reassignTasks',
        'postNo': event.postNo,
        'isCombined': event.isCombined,
        'stage': event.stage,
        'newAssigneeEmail': newEmail,
        'newAssigneeName': newName,
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
    } catch (e) {
      debugPrint('Error fetching users: $e');
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
    try {
      final response = await _apiService.postData({
        'action': 'groupPosts',
        'postNos': postNos,
        'groupId': groupId,
      });
      if (response['success'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint('Error grouping posts: $e');
    }
    return false;
  }

  Future<bool> updatePostMeta(String postNo, Map<String, dynamic> updates) async {
    try {
      final Map<String, dynamic> payload = {'action': 'updatePostMeta', 'postNo': postNo};
      payload.addAll(updates);
      final response = await _apiService.postData(payload);
      if (response['success'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint('Error updating post meta: $e');
    }
    return false;
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
}
