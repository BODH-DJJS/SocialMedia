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

  /// Fetches tasks from Supabase in ~100ms with optional user filtering
  Future<List<Map<String, dynamic>>> fetchTasksFromSupabase({String? role, String? username}) async {
    final stopwatch = Stopwatch()..start();
    var query = '$supabaseUrl/rest/v1/tasks?select=*&order=row_index.desc';
    
    // Non-admin can only see their assigned tasks
    if (role != null && role.toLowerCase() != 'admin' && username != null && username.isNotEmpty) {
      query += '&assignee=eq.${Uri.encodeComponent(username)}';
    }

    try {
      final response = await http.get(
        Uri.parse(query),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $supabaseAnonKey',
          'Accept': 'application/json',
        },
      );
      stopwatch.stop();

      if (response.statusCode == 200) {
        final List<dynamic> list = json.decode(response.body);
        debugPrint('⚡ [Supabase] Loaded ${list.length} tasks in ${stopwatch.elapsedMilliseconds} ms!');
        return list.map((e) => e as Map<String, dynamic>).toList();
      } else {
        debugPrint('⚠️ [Supabase Tasks Error]: ${response.statusCode} - ${response.body}');
        return [];
      }
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
