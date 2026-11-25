import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class ApiService {
  static const String scriptUrl = 'https://script.google.com/macros/s/AKfycbwPc0XQIMPI4Lms59IGtyVcSRLlEcPOJWbt7VhN3jfmkukgqkSgxHd6HNxbtPGCODskGw/exec';

  Future<Map<String, dynamic>> postData(Map<String, dynamic> payload) async {
    final uri = Uri.parse(scriptUrl);

    if (kIsWeb) {
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'text/plain;charset=utf-8',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );
      return _parseResponse(resp.body);
    } else {
      return await _postWithBackoff(uri, payload);
    }
  }

  Future<Map<String, dynamic>> _postWithBackoff(Uri uri, Map<String, dynamic> payload) async {
    final client = http.Client();
    try {
      int attempt = 0;
      while (true) {
        final req = http.Request('POST', uri)
          ..followRedirects = false
          ..headers.addAll({
            'Content-Type': 'text/plain;charset=utf-8',
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
          })
          ..body = json.encode(payload);
          
        final streamed = await client.send(req);
        final resp = await http.Response.fromStream(streamed);
        
        // Backoff on 429
        if (resp.statusCode == 429 && attempt < 3) {
          final waitMs = 400 * (1 << attempt);
          await Future.delayed(Duration(milliseconds: waitMs));
          attempt++;
          continue;
        }
        
        // Follow redirect for Apps Script
        if ((resp.statusCode == 302 || resp.statusCode == 301) && attempt < 2) {
          final loc = resp.headers['location'];
          if (loc != null && loc.isNotEmpty) {
            final redirectUri = Uri.parse(loc);
            final getReq = http.Request('GET', redirectUri)
              ..followRedirects = false
              ..headers.addAll({
                'Accept': 'application/json',
                'X-Requested-With': 'XMLHttpRequest',
              });
            final getStreamed = await client.send(getReq);
            final getResp = await http.Response.fromStream(getStreamed);
            if (getResp.statusCode == 200) return _parseResponse(getResp.body);
            attempt++;
            continue;
          }
        }
        
        return _parseResponse(resp.body);
      }
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _parseResponse(String rawBody) {
    try {
      final raw = rawBody.trim();
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      final start = rawBody.indexOf('{');
      final end = rawBody.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final candidate = rawBody.substring(start, end + 1);
        try { return json.decode(candidate) as Map<String, dynamic>; } catch (_) {}
      }
      return {'success': false, 'message': 'Invalid server response'};
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // ── SUPABASE FAST READ / WRITE (Direct PostgreSQL Database Access)
  // ═════════════════════════════════════════════════════════════════════
  static const String supabaseUrl = 'https://tbyltpojvcxvqupaimhc.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_SIhd8itf5N1Dlg0D1YYf7A_g0bTkp0T';

  /// Fetches tasks from Supabase in ~100ms with optional user filtering (fetches all pages if > 1000)
  Future<List<Map<String, dynamic>>> fetchTasksFromSupabase({String? role, String? username}) async {
    final stopwatch = Stopwatch()..start();
    var baseQuery = '$supabaseUrl/rest/v1/tasks?select=*&order=row_index.desc';
    
    // Non-admin can only see their assigned tasks
    if (role != null && role.toLowerCase() != 'admin' && username != null && username.isNotEmpty) {
      final cleanUser = username.trim().toLowerCase();
      baseQuery += '&or=(assignee.ilike.${Uri.encodeComponent(cleanUser)},assignee_name.ilike.${Uri.encodeComponent(cleanUser)})';
    }

    try {
      final List<Map<String, dynamic>> allTasks = [];
      int offset = 0;
      const int pageSize = 1000;

      while (true) {
        final uri = Uri.parse('$baseQuery&limit=$pageSize&offset=$offset');
        final response = await http.get(
          uri,
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final List<dynamic> list = json.decode(response.body);
          allTasks.addAll(list.map((e) => e as Map<String, dynamic>));
          if (list.length < pageSize) break; // Reached the end
          offset += pageSize;
        } else {
          debugPrint('⚠️ [Supabase Tasks Error]: ${response.statusCode} - ${response.body}');
          break;
        }
      }

      stopwatch.stop();
      debugPrint('⚡ [Supabase] Loaded ${allTasks.length} tasks in ${stopwatch.elapsedMilliseconds} ms!');
      return allTasks;
    } catch (e) {
      debugPrint('⚠️ [Supabase Tasks Exception]: $e');
      return [];
    }
  }

  /// Fetches posts metadata from Supabase in ~100ms
  Future<List<Map<String, dynamic>>> fetchPostsFromSupabase() async {
    final stopwatch = Stopwatch()..start();
    // Exclude header row if post_no is 'Post No.'
    final uri = Uri.parse('$supabaseUrl/rest/v1/posts?select=*&post_no=neq.Post%20No.&order=row_index.desc');

    try {
      final response = await http.get(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Accept': 'application/json',
        },
      );
      stopwatch.stop();

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        debugPrint('⚡ [Supabase] Loaded ${list.length} posts in ${stopwatch.elapsedMilliseconds} ms!');
        
        // Map snake_case to PascalCase so dashboard_screen filters work identically!
        return list.map((e) {
          final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
          m['PostNo'] = m['post_no'];
          m['Program'] = m['program'];
          m['Branch'] = m['branch'];
          m['State'] = m['state'];
          m['Venue'] = m['venue'];
          m['Theme'] = m['theme'];
          m['Date'] = m['date'];
          m['Timings'] = m['timings'];
          m['Male'] = m['male'];
          m['Female'] = m['female'];
          m['Children'] = m['children'];
          m['TotalBeneficiary'] = m['total_beneficiary'];
          m['Organizers'] = m['organizers'];
          m['Partners'] = m['partners'];
          m['GuestType'] = m['guest_type'];
          m['GuestName'] = m['guest_name'];
          m['GuestDesignation'] = m['guest_designation'];
          m['GuestOrg'] = m['guest_org'];
          m['ImportantInfo'] = m['important_info'];
          m['FolderLink'] = m['folder_link'];
          m['ActivityType'] = m['activity_type'];
          m['ActivitiesConducted'] = m['activities_conducted'];
          m['AnyInformation'] = m['any_information'];
          m['MOP'] = m['mop'];
          m['DataUploaded'] = m['data_uploaded'];
          m['InProcess'] = m['in_process'];
          m['DesignDone'] = m['design_done'];
          m['WritingDone'] = m['writing_done'];
          m['EditingDone'] = m['editing_done'];
          m['ProofReadingDone'] = m['proof_reading_done'];
          m['ThumbnailDone'] = m['thumbnail_done'];
          m['ReadyToBePosted'] = m['ready_to_be_posted'];
          m['PostUploaded'] = m['post_uploaded'];
          m['PublishPlatform'] = m['publish_platform'];
          m['PostType'] = m['post_type'];
          m['GroupID'] = m['group_id'];
          m['MediaMode'] = m['media_mode'];
          m['Description'] = m['description'];
          m['PostStatus'] = m['post_status'];
          m['rowIndex'] = m['row_index'];
          return m;
        }).toList();
      } else {
        debugPrint('⚠️ [Supabase Posts Error]: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('⚠️ [Supabase Posts Exception]: $e');
      return [];
    }
  }

  /// Fetches users from Supabase in ~50ms (returns empty list if table doesn't exist yet)
  Future<List<Map<String, dynamic>>> fetchUsersFromSupabase() async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/users?select=*&order=row_index.asc');
    try {
      final response = await http.get(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        return list.map((raw) {
          final m = Map<String, dynamic>.from(raw as Map);
          m['username'] = m['email'];
          return m;
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('⚠️ [Supabase Users Exception]: $e');
      return [];
    }
  }

  /// Fetches a single post and its associated tasks from Supabase in ~50-80ms
  Future<Map<String, dynamic>?> fetchSinglePostFromSupabase(
    String postNo, {
    String? taskId,
    String? stage,
    bool isCombined = false,
  }) async {
    final cleanPNo = postNo.trim();
    final cleanTId = taskId?.trim() ?? '';
    if (cleanPNo.isEmpty && cleanTId.isEmpty) return null;

    final stopwatch = Stopwatch()..start();

    try {
      final taskQuery = cleanTId.isNotEmpty
          ? '$supabaseUrl/rest/v1/tasks?task_id=eq.${Uri.encodeComponent(cleanTId)}'
          : '$supabaseUrl/rest/v1/tasks?post_no=eq.${Uri.encodeComponent(cleanPNo)}';

      final quotedPNo = '"' + cleanPNo.replaceAll('"', '') + '"';
      final isGroupLike = cleanPNo.contains('(') || cleanPNo.toLowerCase().contains('combined') || cleanPNo.toLowerCase().contains('group');

      final postQuery = isGroupLike
          ? '$supabaseUrl/rest/v1/posts?select=*&group_id=eq.${Uri.encodeComponent(cleanPNo)}'
          : '$supabaseUrl/rest/v1/posts?select=*&or=(post_no.eq.${Uri.encodeComponent(quotedPNo)},group_id.eq.${Uri.encodeComponent(quotedPNo)})';

      final responses = await Future.wait([
        http.get(
          Uri.parse(taskQuery),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
            'Accept': 'application/json',
          },
        ),
        http.get(
          Uri.parse(postQuery),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
            'Accept': 'application/json',
          },
        ),
      ]);

      stopwatch.stop();
      debugPrint('⚡ [Supabase Single Post] Queried in ${stopwatch.elapsedMilliseconds} ms!');

      final taskResp = responses[0];
      final postResp = responses[1];

      List<dynamic> rawTasks = [];
      if (taskResp.statusCode == 200) {
        rawTasks = json.decode(taskResp.body) as List<dynamic>;
      }

      if (rawTasks.isEmpty && cleanTId.isNotEmpty && cleanPNo.isNotEmpty) {
        final fallbackTasksResp = await http.get(
          Uri.parse('$supabaseUrl/rest/v1/tasks?post_no=eq.${Uri.encodeComponent(cleanPNo)}'),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
            'Accept': 'application/json',
          },
        );
        if (fallbackTasksResp.statusCode == 200) {
          rawTasks = json.decode(fallbackTasksResp.body) as List<dynamic>;
        }
      }

      List<dynamic> rawPosts = postResp.statusCode == 200 ? json.decode(postResp.body) : [];

      // If post wasn't found by group query, retry with or=(...)
      if (rawPosts.isEmpty && cleanPNo.isNotEmpty) {
        final retryPostResp = await http.get(
          Uri.parse('$supabaseUrl/rest/v1/posts?select=*&or=(post_no.eq.${Uri.encodeComponent(quotedPNo)},group_id.eq.${Uri.encodeComponent(quotedPNo)})'),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
            'Accept': 'application/json',
          },
        );
        if (retryPostResp.statusCode == 200) {
          rawPosts = json.decode(retryPostResp.body);
        }
      }

      // If single post found and it has a group_id, fetch all sibling posts so combined post is complete!
      if (rawPosts.length == 1 && (isCombined || cleanPNo.toLowerCase().contains('combined'))) {
        final gId = rawPosts.first['group_id']?.toString() ?? '';
        if (gId.isNotEmpty && gId != cleanPNo) {
          final groupPostsResp = await http.get(
            Uri.parse('$supabaseUrl/rest/v1/posts?select=*&group_id=eq.${Uri.encodeComponent(gId)}'),
            headers: {
              'apikey': supabaseAnonKey,
              'Authorization': 'Bearer $supabaseAnonKey',
              'Accept': 'application/json',
            },
          );
          if (groupPostsResp.statusCode == 200) {
            final List<dynamic> groupList = json.decode(groupPostsResp.body);
            if (groupList.isNotEmpty) {
              rawPosts = groupList;
            }
          }
        }
      }

      if (rawTasks.isEmpty && rawPosts.isEmpty) return null;

      // Normalize all post maps to have both PascalCase and snake_case fields
      final List<Map<String, dynamic>> normalizedPosts = rawPosts.map((e) {
        final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
        m['PostNo'] = m['post_no']?.toString() ?? m['PostNo']?.toString() ?? '';
        m['Program'] = m['program']?.toString() ?? m['Program']?.toString() ?? '';
        m['Branch'] = m['branch']?.toString() ?? m['Branch']?.toString() ?? '';
        m['State'] = m['state']?.toString() ?? m['State']?.toString() ?? '';
        m['Venue'] = m['venue']?.toString() ?? m['Venue']?.toString() ?? '';
        m['Theme'] = m['theme']?.toString() ?? m['Theme']?.toString() ?? '';
        m['Date'] = m['date']?.toString() ?? m['Date']?.toString() ?? '';
        m['Timings'] = m['timings']?.toString() ?? m['Timings']?.toString() ?? '';
        m['Male'] = m['male'] ?? m['Male'] ?? 0;
        m['Female'] = m['female'] ?? m['Female'] ?? 0;
        m['Children'] = m['children'] ?? m['Children'] ?? 0;
        m['TotalBeneficiary'] = m['total_beneficiary'] ?? m['TotalBeneficiary'] ?? 0;
        m['Organizers'] = m['organizers']?.toString() ?? m['Organizers']?.toString() ?? '';
        m['Partners'] = m['partners']?.toString() ?? m['Partners']?.toString() ?? '';
        m['GuestType'] = m['guest_type']?.toString() ?? m['GuestType']?.toString() ?? '';
        m['GuestName'] = m['guest_name']?.toString() ?? m['GuestName']?.toString() ?? '';
        m['GuestDesignation'] = m['guest_designation']?.toString() ?? m['GuestDesignation']?.toString() ?? '';
        m['GuestOrg'] = m['guest_org']?.toString() ?? m['GuestOrg']?.toString() ?? '';
        m['ImportantInfo'] = m['important_info']?.toString() ?? m['ImportantInfo']?.toString() ?? '';
        m['FolderLink'] = m['folder_link']?.toString() ?? m['FolderLink']?.toString() ?? '';
        m['ActivityType'] = m['activity_type']?.toString() ?? m['ActivityType']?.toString() ?? '';
        m['ActivitiesConducted'] = m['activities_conducted']?.toString() ?? m['ActivitiesConducted']?.toString() ?? '';
        m['AnyInformation'] = m['any_information']?.toString() ?? m['AnyInformation']?.toString() ?? '';
        m['MOP'] = m['mop']?.toString() ?? m['MOP']?.toString() ?? '';
        m['DataUploaded'] = m['data_uploaded']?.toString() ?? m['DataUploaded']?.toString() ?? '';
        m['InProcess'] = m['in_process']?.toString() ?? m['InProcess']?.toString() ?? '';
        m['DesignDone'] = m['design_done']?.toString() ?? m['DesignDone']?.toString() ?? '';
        m['GroupID'] = m['group_id']?.toString() ?? m['GroupID']?.toString() ?? '';
        return m;
      }).toList()..sort((a, b) {
        final pA = (a['PostNo'] ?? '').toString().trim();
        final pB = (b['PostNo'] ?? '').toString().trim();
        final nA = int.tryParse(pA.replaceAll(RegExp(r'[^0-9]'), ''));
        final nB = int.tryParse(pB.replaceAll(RegExp(r'[^0-9]'), ''));
        if (nA != null && nB != null && nA != nB) return nA.compareTo(nB);
        return pA.compareTo(pB);
      });

      final isCombinedVal = isCombined || normalizedPosts.length > 1 || cleanPNo.toLowerCase().contains('combined') || cleanPNo.contains('(');

      Map<String, dynamic> postData = {};
      if (normalizedPosts.isNotEmpty) {
        if (isCombinedVal && normalizedPosts.length > 1) {
          int totalM = 0, totalF = 0, totalC = 0;
          for (final m in normalizedPosts) {
            totalM += (m['Male'] is num ? m['Male'] as num : int.tryParse(m['Male'].toString()) ?? 0).toInt();
            totalF += (m['Female'] is num ? m['Female'] as num : int.tryParse(m['Female'].toString()) ?? 0).toInt();
            totalC += (m['Children'] is num ? m['Children'] as num : int.tryParse(m['Children'].toString()) ?? 0).toInt();
          }
          final firstPost = normalizedPosts.first;
          postData = Map<String, dynamic>.from(firstPost);
          postData['PostNo'] = cleanPNo;
          postData['post_no'] = cleanPNo;
          postData['Theme'] = cleanPNo;
          postData['theme'] = cleanPNo;
          postData['GroupID'] = cleanPNo;
          postData['group_id'] = cleanPNo;
          postData['Male'] = totalM;
          postData['male'] = totalM;
          postData['Female'] = totalF;
          postData['female'] = totalF;
          postData['Children'] = totalC;
          postData['children'] = totalC;
          postData['TotalBeneficiary'] = totalM + totalF + totalC;
          postData['total_beneficiary'] = totalM + totalF + totalC;
          postData['isCombined'] = true;
          postData['is_combined'] = true;
          postData['CombinedPosts'] = normalizedPosts;
          postData['combined_posts'] = normalizedPosts;
        } else {
          postData = Map<String, dynamic>.from(normalizedPosts.first);
        }
      }

      final tasks = rawTasks.map((t) {
        final map = Map<String, dynamic>.from(t as Map<String, dynamic>);
        final originalTaskPostNo = map['post_no']?.toString() ?? map['PostNo']?.toString() ?? '';
        for (final k in postData.keys) {
          if (!map.containsKey(k) || map[k] == null || map[k].toString().isEmpty) {
            map[k] = postData[k];
          }
        }
        if (originalTaskPostNo.isNotEmpty) {
          map['post_no'] = originalTaskPostNo;
          map['PostNo'] = originalTaskPostNo;
        }
        map['isCombined'] = isCombinedVal;
        map['is_combined'] = isCombinedVal;
        map['CombinedPosts'] = normalizedPosts;
        map['combined_posts'] = normalizedPosts;
        return map;
      }).toList();

      return {
        'success': true,
        'postData': postData,
        'combinedPosts': normalizedPosts,
        'tasks': tasks,
        'isCombined': isCombinedVal,
      };
    } catch (e) {
      debugPrint('⚠️ [Supabase Single Post Exception]: $e');
      return null;
    }
  }

  /// Updates task instantly in Supabase (takes ~50ms)
  Future<bool> updateTaskInSupabase(String taskId, Map<String, dynamic> updates) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/tasks?task_id=eq.${Uri.encodeComponent(taskId)}');
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (updates.containsKey('Status')) payload['status'] = updates['Status'];
    if (updates.containsKey('CanvaLink')) payload['canva_link'] = updates['CanvaLink'];
    if (updates.containsKey('DocLink')) payload['doc_link'] = updates['DocLink'];
    if (updates.containsKey('DueDate')) payload['due_date'] = updates['DueDate'];
    if (updates.containsKey('Notes')) payload['notes'] = updates['Notes'];
    if (updates.containsKey('Assignee')) payload['assignee'] = updates['Assignee'];
    if (updates.containsKey('AssigneeName')) payload['assignee_name'] = updates['AssigneeName'];

    try {
      final response = await http.patch(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode(payload),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('⚠️ [Supabase Task Update Error]: $e');
      return false;
    }
  }

  /// Updates post metadata (e.g. clearing 'Skip' or 'Inactive' post_status) in Supabase instantly
  Future<bool> updatePostInSupabase(String postNo, Map<String, dynamic> updates) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/posts?post_no=eq.${Uri.encodeComponent(postNo)}');
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (updates.containsKey('postStatus')) payload['post_status'] = updates['postStatus'];
    if (updates.containsKey('activityType')) payload['activity_type'] = updates['activityType'];
    if (updates.containsKey('publishPlatform')) payload['publish_platform'] = updates['publishPlatform'];
    if (updates.containsKey('postType')) payload['post_type'] = updates['postType'];
    if (updates.containsKey('mediaMode')) payload['media_mode'] = updates['mediaMode'];
    if (updates.containsKey('description')) payload['description'] = updates['description'];
    if (updates.containsKey('groupId')) payload['group_id'] = updates['groupId'];

    try {
      final response = await http.patch(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode(payload),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('⚠️ [Supabase Post Update Error]: $e');
      return false;
    }
  }

  /// Deletes all tasks for a post or combined group from Supabase instantly (~50ms)
  Future<bool> deleteTasksFromSupabase(String postNo) async {
    final cleanPNo = postNo.trim();
    if (cleanPNo.isEmpty) return false;
    final uri = Uri.parse('$supabaseUrl/rest/v1/tasks?post_no=eq.${Uri.encodeComponent(cleanPNo)}');
    try {
      final response = await http.delete(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Prefer': 'return=minimal',
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('⚠️ [Supabase Task Delete Error]: $e');
      return false;
    }
  }

  /// Ungroups a post in Supabase instantly (~50ms)
  Future<bool> ungroupPostInSupabase(String postNo, {String? newStatus}) async {
    final cleanPNo = postNo.trim();
    if (cleanPNo.isEmpty) return false;
    final uri = Uri.parse('$supabaseUrl/rest/v1/posts?post_no=eq.${Uri.encodeComponent(cleanPNo)}');
    try {
      final body = <String, dynamic>{
        'group_id': '',
        'post_type': 'Individual',
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (newStatus != null && newStatus.isNotEmpty) {
        body['post_status'] = newStatus;
      }
      final response = await http.patch(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode(body),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('⚠️ [Supabase Ungroup Error]: $e');
      return false;
    }
  }

  /// Groups posts under a combined group in Supabase instantly (~50ms)
  Future<bool> groupPostsInSupabase(List<String> postNos, String groupId) async {
    if (postNos.isEmpty || groupId.trim().isEmpty) return false;
    try {
      for (final pNo in postNos) {
        final uri = Uri.parse('$supabaseUrl/rest/v1/posts?post_no=eq.${Uri.encodeComponent(pNo.trim())}');
        await http.patch(
          uri,
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: json.encode({
            'group_id': groupId.trim(),
            'post_type': 'Combined',
            'updated_at': DateTime.now().toIso8601String(),
          }),
        );
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ [Supabase Group Error]: $e');
      return false;
    }
  }

  /// Renames a combined group in Supabase instantly (~50ms)
  Future<bool> renameGroupInSupabase(String oldGroupId, String newGroupId) async {
    final cleanOld = oldGroupId.trim();
    final cleanNew = newGroupId.trim();
    if (cleanOld.isEmpty || cleanNew.isEmpty) return false;
    try {
      // 1. Update posts table
      final postsUri = Uri.parse('$supabaseUrl/rest/v1/posts?group_id=eq.${Uri.encodeComponent(cleanOld)}');
      await http.patch(
        postsUri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode({
          'group_id': cleanNew,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
      // 2. Update tasks table
      final tasksUri = Uri.parse('$supabaseUrl/rest/v1/tasks?post_no=eq.${Uri.encodeComponent(cleanOld)}');
      await http.patch(
        tasksUri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode({
          'post_no': cleanNew,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ [Supabase Rename Group Error]: $e');
      return false;
    }
  }

  /// Clears group_id from all posts in a combined group in Supabase (~50ms)
  Future<bool> clearGroupPostsInSupabase(String groupId, {String? newStatus}) async {
    final cleanGId = groupId.trim();
    if (cleanGId.isEmpty) return false;
    final uri = Uri.parse('$supabaseUrl/rest/v1/posts?group_id=eq.${Uri.encodeComponent(cleanGId)}');
    try {
      final body = <String, dynamic>{
        'group_id': '',
        'post_type': 'Individual',
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (newStatus != null && newStatus.isNotEmpty) {
        body['post_status'] = newStatus;
      }
      final response = await http.patch(
        uri,
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode(body),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('⚠️ [Supabase Clear Group Error]: $e');
      return false;
    }
  }

  /// Test method: Fetches test_events directly from Supabase in milliseconds
  Future<List<Map<String, dynamic>>> fetchTestEventsFromSupabase() async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/test_events?select=*');
    final stopwatch = Stopwatch()..start();

    final response = await http.get(
      uri,
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Accept': 'application/json',
      },
    );

    stopwatch.stop();

    if (response.statusCode == 200) {
      final List<dynamic> list = json.decode(response.body);
      debugPrint('⚡ [Supabase] Loaded ${list.length} records in ${stopwatch.elapsedMilliseconds} ms!');
      return list.map((e) => e as Map<String, dynamic>).toList();
    } else {
      debugPrint('❌ [Supabase] Error: ${response.statusCode} - ${response.body}');
      return [];
    }
  }
}
