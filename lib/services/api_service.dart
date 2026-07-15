import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

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
}
