import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/dev_pipeline_models.dart';

class DevPipelineProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

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

  Future<void> fetchDevData({String? role, String? username}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final projResp = await _apiService.postData({
        'action': 'getDevProjects',
        'stream': '',
      });

      if (projResp['success'] == true && projResp['projects'] is List) {
        _projects = (projResp['projects'] as List)
            .map((p) => DevProject.fromJson(Map<String, dynamic>.from(p)))
            .toList();
      }

      final taskResp = await _apiService.postData({
        'action': 'getDevTasks',
        'role': role ?? 'Admin',
        'username': username ?? '',
      });

      if (taskResp['success'] == true && taskResp['tasks'] is List) {
        _tasks = (taskResp['tasks'] as List)
            .map((t) => DevTask.fromJson(Map<String, dynamic>.from(t)))
            .toList();
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
