import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/api_service.dart';

class EventProvider with ChangeNotifier {
  List<Event> _events = [];
  List<Map<String, dynamic>> _rawPosts = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _spocs = [];
  bool _isLoading = false;

  List<Event> get events => _events;
  List<Map<String, dynamic>> get rawPosts => _rawPosts;
  List<Map<String, dynamic>> get users => _users;
  List<Map<String, dynamic>> get spocs => _spocs;
  bool get isLoading => _isLoading;

  final ApiService _apiService = ApiService();

  Future<void> fetchEvents(String role, String username, {bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final response = await _apiService.postData({
        'action': 'getTasks',
        'role': role,
        'username': username,
      });

      if (response['success'] == true) {
        final List<dynamic> tasksData = response['tasks'];
        _events = tasksData.map((json) => Event.fromJson(json)).toList();
        
        // If admin, also fetch all raw posts for visibility
        if (role.toLowerCase() == 'admin') {
          await fetchAllPosts();
        }
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
    }

    if (!silent) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllPosts() async {
    try {
      final response = await _apiService.postData({'action': 'getPosts'});
      if (response['success'] == true) {
        final List<dynamic> postsData = response['posts'];
        _rawPosts = postsData.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('Error fetching raw posts: $e');
    }
  }

  Future<bool> updateEvent(Event event, Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.postData({
        'action': 'updateTask',
        'rowIndex': event.rowIndex,
        'updates': updates,
      });

      if (response['success'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint('Error updating event: $e');
    }

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
    // Fire-and-forget the API call. Google Drive API takes 15-30 seconds to create folders and docs.
    // By not awaiting this, the UI stays fully responsive and pops immediately.
    _apiService.postData({
      'action': 'createTasksForPostV2',
      'postNo': postNo,
      'assignees': assignees,
      'dueDates': dueDates,
      'description': description,
      'publishPlatform': publishPlatform,
      'postType': postType,
      'mediaMode': mediaMode,
    }).catchError((e) {
      debugPrint('Error creating tasks v2 (background): $e');
    });

    // Optimistically assume success and return instantly
    return true;
  }

  Future<Map<String, String>> fetchMediaFolders(String monthLink, String dateStr, String stage) async {
    try {
      debugPrint('=== fetchMediaFolders ===');
      debugPrint('monthLink: $monthLink');
      debugPrint('dateStr sent to Apps Script: "$dateStr"');
      debugPrint('stage: "$stage"');
      
      final response = await _apiService.postData({
        'action': 'getMediaFolders',
        'monthLink': monthLink,
        'dateStr': dateStr,
        'stage': stage,
      });

      debugPrint('getMediaFolders response: $response');

      if (response['success'] == true) {
        final folders = response['folders'];
        debugPrint('raw: ${folders['raw']}');
        debugPrint('selected: ${folders['selected']}');
        debugPrint('edited: ${folders['edited']}');
        debugPrint('writingDoc: ${folders['writingDoc']}');
        debugPrint('BACKEND DEBUG: ${folders['debug']}');
        return {
          'raw': folders['raw']?.toString() ?? '',
          'selected': folders['selected']?.toString() ?? '',
          'edited': folders['edited']?.toString() ?? '',
          'writingDoc': folders['writingDoc']?.toString() ?? '',
        };
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
