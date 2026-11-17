import 'package:intl/intl.dart';

DateTime? parseDueDate(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;

  // Remove trailing time after comma, e.g. "22/07/2026, 18:08:01"
  if (s.contains(',')) {
    s = s.split(',')[0].trim();
  }
  // Try ISO-8601 directly
  if (s.contains('T')) {
    final parsedIso = DateTime.tryParse(s);
    if (parsedIso != null) return parsedIso;
    s = s.split('T')[0].trim();
  }

  // Try standard parse (YYYY-MM-DD)
  final dt = DateTime.tryParse(s);
  if (dt != null) return dt;

  final months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
    'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
  };

  final parts = s.split(RegExp(r'[\s\-/]+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 3) {
    // Check Day-MonthName-Year (e.g. 27-Jul-2026)
    final d1 = int.tryParse(parts[0]);
    final mStr1 = parts[1].toLowerCase();
    final y1 = int.tryParse(parts[2]);
    if (d1 != null && months.containsKey(mStr1) && y1 != null) {
      final y = y1 < 100 ? 2000 + y1 : y1;
      return DateTime(y, months[mStr1]!, d1);
    }

    // Check MonthName-Day-Year (e.g. Jul-27-2026)
    final d2 = int.tryParse(parts[1]);
    final mStr2 = parts[0].toLowerCase();
    final y2 = int.tryParse(parts[2]);
    if (d2 != null && months.containsKey(mStr2) && y2 != null) {
      final y = y2 < 100 ? 2000 + y2 : y2;
      return DateTime(y, months[mStr2]!, d2);
    }

    // Check numeric parts (e.g. 27/07/2026 or 2026/07/27)
    final p0 = int.tryParse(parts[0]);
    final p1 = int.tryParse(parts[1]);
    final p2 = int.tryParse(parts[2]);
    if (p0 != null && p1 != null && p2 != null) {
      if (p2 > 1000) {
        if (p0 > 12) {
          return DateTime(p2, p1, p0);
        } else if (p1 > 12) {
          return DateTime(p2, p0, p1);
        } else {
          // Default DD/MM/YYYY
          return DateTime(p2, p1, p0);
        }
      } else if (p0 > 1000) {
        return DateTime(p0, p1, p2);
      }
    }
  }

  // Fallback to DateFormat patterns
  final patterns = [
    'd-MMM-yyyy',
    'dd-MMM-yyyy',
    'd MMM yyyy',
    'dd MMM yyyy',
    'd/M/yyyy',
    'dd/MM/yyyy',
    'yyyy-MM-dd',
    'MM/dd/yyyy',
  ];
  for (final pat in patterns) {
    try {
      return DateFormat(pat).parse(s);
    } catch (_) {}
  }

  return null;
}

bool isDueDateExpired(String? raw, {bool isDone = false}) {
  if (isDone) return false;
  final dt = parseDueDate(raw);
  if (dt == null) return false;
  final now = DateTime.now();
  final endOfDay = DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
  return now.isAfter(endOfDay);
}

int compareDueDates(String? dateA, String? dateB, {int Function()? secondaryCompare}) {
  final dtA = parseDueDate(dateA);
  final dtB = parseDueDate(dateB);

  if (dtA != null && dtB != null) {
    final cmp = dtA.compareTo(dtB);
    if (cmp != 0) return cmp;
    return secondaryCompare?.call() ?? 0;
  }
  // Tasks with a valid due date come first
  if (dtA != null && dtB == null) return -1;
  if (dtA == null && dtB != null) return 1;

  // Both have no due date
  return secondaryCompare?.call() ?? 0;
}

String formatDueDateDisplay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  var s = raw.trim();
  if (s.contains('T')) {
    s = s.split('T')[0].trim();
  }
  if (s.contains(',')) {
    s = s.split(',')[0].trim();
  }
  return s;
}
