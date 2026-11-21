import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/dev_pipeline_models.dart';

class DevPipelineProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  static const String _cacheKeyProjects = 'cached_dev_projects_json';
  static const String _cacheKeyTasks = 'cached_dev_tasks_json';

  List<DevProject> _projects = [];
  List<DevTask> _tasks = [];
  bool _isLoading = false;
  String? _error;
  String _selectedStream = 'Campaign Development';

  List<DevProject> get projects => _projects;
  List<DevTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedStream => _selectedStream;

  void setStream(String stream) {
    if (_selectedStream != stream) {
      _selectedStream = stream;
      notifyListeners();
    }
  }

  Future<void> fetchDevData({String? role, String? username, bool force = false}) async {
    // 1. Instant Cache Load (0ms)
    if (_projects.isEmpty && _tasks.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedProjectsStr = prefs.getString(_cacheKeyProjects);
        final cachedTasksStr = prefs.getString(_cacheKeyTasks);
        if (cachedProjectsStr != null && cachedTasksStr != null) {
          final List<dynamic> pList = json.decode(cachedProjectsStr);
          final List<dynamic> tList = json.decode(cachedTasksStr);
          _projects = pList.map((p) => DevProject.fromJson(Map<String, dynamic>.from(p))).toList();
          _tasks = tList.map((t) => DevTask.fromJson(Map<String, dynamic>.from(t))).toList();
          notifyListeners();
        }
      } catch (cacheErr) {
        debugPrint('Dev cache read error: $cacheErr');
      }
    }

    if (_projects.isEmpty && _tasks.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      // 2. Fast combined fetch in single round-trip
      Map<String, dynamic> combinedResp = {};
      try {
        combinedResp = await _apiService.postData({
          'action': 'getDevPipelineData',
          'role': role ?? 'Admin',
          'username': username ?? '',
        });
      } catch (_) {}

      if (combinedResp['success'] == true && combinedResp['projects'] is List && combinedResp['tasks'] is List) {
        _projects = (combinedResp['projects'] as List)
            .map((p) => DevProject.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        _tasks = (combinedResp['tasks'] as List)
            .map((t) => DevTask.fromJson(Map<String, dynamic>.from(t)))
            .toList();
      } else {
        // Fallback: parallel calls
        final results = await Future.wait([
          _apiService.postData({'action': 'getDevProjects', 'stream': ''}),
          _apiService.postData({'action': 'getDevTasks', 'role': role ?? 'Admin', 'username': username ?? ''}),
        ]);
        if (results[0]['success'] == true && results[0]['projects'] is List) {
          _projects = (results[0]['projects'] as List)
              .map((p) => DevProject.fromJson(Map<String, dynamic>.from(p)))
              .toList();
        }
        if (results[1]['success'] == true && results[1]['tasks'] is List) {
          _tasks = (results[1]['tasks'] as List)
              .map((t) => DevTask.fromJson(Map<String, dynamic>.from(t)))
              .toList();
        }
      }

      // 3. Save fresh data to local cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKeyProjects, json.encode(_projects.map((p) => p.toJson()).toList()));
        await prefs.setString(_cacheKeyTasks, json.encode(_tasks.map((t) => t.toJson()).toList()));
      } catch (cacheWriteErr) {
        debugPrint('Dev cache write error: $cacheWriteErr');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createProject({
    required String stream,
    required String campaignName,
    required String sessionName,
    required String duration,
    required String festivals,
    required String startDate,
    required String completionDate,
    required bool iecContent,
    required bool iecDesigning,
    required bool iecProofread,
    required bool iecFinalCheck,
    required Map<String, dynamic> assignees,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final resp = await _apiService.postData({
        'action': 'createDevProject',
        'stream': stream,
        'campaignName': campaignName,
        'sessionName': sessionName,
        'duration': duration,
        'festivals': festivals,
        'startDate': startDate,
        'completionDate': completionDate,
        'iecContent': iecContent,
        'iecDesigning': iecDesigning,
        'iecProofread': iecProofread,
        'iecFinalCheck': iecFinalCheck,
        'assignees': assignees,
      });

      await fetchDevData();
      return resp;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateTaskStatus(DevTask task, String newStatus) async {
    final oldStatus = task.status;
    task.status = newStatus;
    notifyListeners();

    try {
      final resp = await _apiService.postData({
        'action': 'updateDevTask',
        'taskId': task.taskId,
        'status': newStatus,
      });

      if (resp['success'] == true) {
        await fetchDevData();
        return true;
      } else {
        task.status = oldStatus;
        notifyListeners();
        return false;
      }
    } catch (e) {
      task.status = oldStatus;
      notifyListeners();
      return false;
    }
  }

  Future<bool> redoTask(DevTask task, String reason) async {
    try {
      final resp = await _apiService.postData({
        'action': 'redoDevTask',
        'taskId': task.taskId,
        'reason': reason,
      });

      if (resp['success'] == true) {
        await fetchDevData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> reassignDevTask({
    required DevTask task,
    required String newEmail,
    String? newName,
    String? role,
    String? category,
  }) async {
    try {
      final resp = await _apiService.postData({
        'action': 'reassignDevTask',
        'taskId': task.taskId,
        'newAssigneeEmail': newEmail,
        'newAssigneeName': newName ?? newEmail,
        'role': role ?? '',
        'category': category ?? task.stream,
      });

      if (resp['success'] == true) {
        // Refresh development pipeline tasks & data
        await fetchDevData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error reassigning dev task: $e');
      return false;
    }
  }

  Future<bool> deleteProject(String projectId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final resp = await _apiService.postData({
        'action': 'deleteDevProject',
        'projectId': projectId,
      });

      if (resp['success'] == true) {
        _projects.removeWhere((p) => p.projectId == projectId);
        _tasks.removeWhere((t) => t.projectId == projectId);
        notifyListeners();
        await fetchDevData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting dev project: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
