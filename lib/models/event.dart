import '../utils/due_date_utils.dart';

int comparePostNumbers(dynamic a, dynamic b) {
  final strA = (a is Map ? (a['PostNo'] ?? a['post_no'] ?? '') : a).toString().trim();
  final strB = (b is Map ? (b['PostNo'] ?? b['post_no'] ?? '') : b).toString().trim();
  final numA = int.tryParse(strA.replaceAll(RegExp(r'[^0-9]'), ''));
  final numB = int.tryParse(strB.replaceAll(RegExp(r'[^0-9]'), ''));
  if (numA != null && numB != null && numA != numB) {
    return numA.compareTo(numB);
  }
  return strA.compareTo(strB);
}

class Event {
  final String taskId;
  final String postNo;
  String stage;
  String assignee;
  String assigneeName;
  String status;
  final String docLink;
  String canvaLink;
  final String allottedDate;
  final String dueDate;
  String notes;
  
  // Post metadata
  final String program;
  final String branch;
  final String state;
  final String venue;
  final String date;
  final String theme;
  final String timings;
  int male;
  int female;
  int children;
  int totalBeneficiary;
  final String organizers;
  final String partners;
  final String importantInfo;
  final String folderLink;
  final String activityType;
  final String publishPlatform;
  final String postType;
  final String groupId;
  final String mediaMode;
  final String description;
  
  // New Guest and Info Fields
  final String guestType;
  final String guestName;
  final String guestDesignation;
  final String guestOrg;
  final String activitiesConducted;
  final String anyInformation;
  
  // Workflow status from Posts sheet
  final String mop;
  final String dataUploaded;
  final String inProcess;
  final String designDone;
  final String writingDone;
  final String editingDone;
  final String proofReadingDone;
  final String thumbnailDone;
  final String readyToBePosted;
  final String postUploaded;

  final int rowIndex;

  final bool isCombined;
  final List<Map<String, dynamic>> combinedPosts;

  Event({
    required this.taskId,
    required this.postNo,
    required this.stage,
    required this.assignee,
    required this.assigneeName,
    required this.status,
    required this.docLink,
    this.canvaLink = '',
    required this.allottedDate,
    required this.dueDate,
    required this.notes,
    required this.program,
    required this.branch,
    required this.state,
    required this.venue,
    required this.date,
    required this.theme,
    required this.timings,
    required this.male,
    required this.female,
    required this.children,
    required this.totalBeneficiary,
    required this.organizers,
    required this.partners,
    required this.importantInfo,
    required this.folderLink,
    required this.activityType,
    required this.publishPlatform,
    required this.postType,
    required this.groupId,
    required this.mediaMode,
    required this.description,
    required this.guestType,
    required this.guestName,
    required this.guestDesignation,
    required this.guestOrg,
    required this.activitiesConducted,
    required this.anyInformation,
    required this.mop,
    required this.dataUploaded,
    required this.inProcess,
    required this.designDone,
    required this.writingDone,
    required this.editingDone,
    required this.proofReadingDone,
    required this.thumbnailDone,
    required this.readyToBePosted,
    required this.postUploaded,
    required this.rowIndex,
    this.isCombined = false,
    this.combinedPosts = const [],
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      taskId: (json['TaskID'] ?? json['task_id'])?.toString() ?? '',
      postNo: (json['PostNo'] ?? json['post_no'])?.toString() ?? '',
      stage: (json['Stage'] ?? json['stage'])?.toString() ?? '',
      assignee: (json['Assignee'] ?? json['assignee'])?.toString().trim() ?? '',
      assigneeName: (json['AssigneeName'] ?? json['assignee_name'] ?? json['Assignee'] ?? json['assignee'])?.toString().trim() ?? '',
      status: (json['Status'] ?? json['status'])?.toString() ?? '',
      docLink: (json['DocLink'] ?? json['doc_link'])?.toString() ?? '',
      canvaLink: (json['CanvaLink'] ?? json['canva_link'])?.toString() ?? '',
      allottedDate: formatDueDateDisplay((json['AllottedDate'] ?? json['allotted_date'])?.toString()),
      dueDate: formatDueDateDisplay((json['DueDate'] ?? json['due_date'])?.toString()),
      notes: (json['Notes'] ?? json['notes'])?.toString() ?? '',
      program: (json['Program'] ?? json['program'])?.toString() ?? '',
      branch: (json['Branch'] ?? json['branch'])?.toString() ?? '',
      state: (json['State'] ?? json['state'])?.toString() ?? '',
      venue: (json['Venue'] ?? json['venue'])?.toString() ?? '',
      date: (json['Date'] ?? json['date'])?.toString() ?? '',
      theme: (json['Theme'] ?? json['theme'])?.toString() ?? '',
      timings: (json['Timings'] ?? json['timings'])?.toString() ?? '',
      male: _parseInt(json['Male'] ?? json['male']),
      female: _parseInt(json['Female'] ?? json['female']),
      children: _parseInt(json['Children'] ?? json['children']),
      totalBeneficiary: _parseInt(json['TotalBeneficiary'] ?? json['total_beneficiary']),
      organizers: (json['Organizers'] ?? json['organizers'])?.toString() ?? '',
      partners: (json['Partners'] ?? json['partners'])?.toString() ?? '',
      importantInfo: (json['ImportantInfo'] ?? json['important_info'])?.toString() ?? '',
      folderLink: (json['FolderLink'] ?? json['folder_link'])?.toString() ?? '',
      activityType: (json['ActivityType'] ?? json['activity_type'])?.toString() ?? '',
      publishPlatform: (json['PublishPlatform'] ?? json['publish_platform'])?.toString() ?? '',
      postType: (json['PostType'] ?? json['post_type'])?.toString() ?? '',
      groupId: (json['GroupID'] ?? json['group_id'])?.toString() ?? '',
      mediaMode: (json['MediaMode'] ?? json['media_mode'])?.toString() ?? '',
      description: (json['Description'] ?? json['description'])?.toString() ?? '',
      guestType: (json['GuestType'] ?? json['guest_type'])?.toString() ?? '',
      guestName: (json['GuestName'] ?? json['guest_name'])?.toString() ?? '',
      guestDesignation: (json['GuestDesignation'] ?? json['guest_designation'])?.toString() ?? '',
      guestOrg: (json['GuestOrg'] ?? json['guest_org'])?.toString() ?? '',
      activitiesConducted: (json['ActivitiesConducted'] ?? json['activities_conducted'])?.toString() ?? '',
      anyInformation: (json['AnyInformation'] ?? json['any_information'])?.toString() ?? '',
      mop: (json['MOP'] ?? json['mop'])?.toString() ?? '',
      dataUploaded: (json['DataUploaded'] ?? json['data_uploaded'])?.toString() ?? '',
      inProcess: (json['InProcess'] ?? json['in_process'])?.toString() ?? '',
      designDone: (json['DesignDone'] ?? json['design_done'])?.toString() ?? '',
      writingDone: (json['WritingDone'] ?? json['writing_done'])?.toString() ?? '',
      editingDone: (json['EditingDone'] ?? json['editing_done'])?.toString() ?? '',
      proofReadingDone: (json['ProofReadingDone'] ?? json['proof_reading_done'])?.toString() ?? '',
      thumbnailDone: (json['ThumbnailDone'] ?? json['thumbnail_done'])?.toString() ?? '',
      readyToBePosted: (json['ReadyToBePosted'] ?? json['ready_to_be_posted'])?.toString() ?? '',
      postUploaded: (json['PostUploaded'] ?? json['post_uploaded'])?.toString() ?? '',
      rowIndex: json['rowIndex'] != null 
          ? (int.tryParse(json['rowIndex'].toString()) ?? 0) 
          : (json['row_index'] != null ? int.tryParse(json['row_index'].toString()) ?? 0 : 0),
      isCombined: json['isCombined'] == true || json['is_combined'] == true,
      combinedPosts: (json['CombinedPosts'] != null 
          ? List<Map<String, dynamic>>.from(json['CombinedPosts']) 
          : (json['combined_posts'] != null ? List<Map<String, dynamic>>.from(json['combined_posts']) : []))
        ..sort(comparePostNumbers),
    );
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'TaskID': taskId,
      'PostNo': postNo,
      'Stage': stage,
      'Assignee': assignee,
      'AssigneeName': assigneeName,
      'Status': status,
      'DocLink': docLink,
      'CanvaLink': canvaLink,
      'AllottedDate': allottedDate,
      'DueDate': dueDate,
      'Notes': notes,
      'Program': program,
      'Branch': branch,
      'State': state,
      'Venue': venue,
      'Date': date,
      'Theme': theme,
      'Timings': timings,
      'Male': male,
      'Female': female,
      'Children': children,
      'TotalBeneficiary': totalBeneficiary,
      'Organizers': organizers,
      'Partners': partners,
      'ImportantInfo': importantInfo,
      'FolderLink': folderLink,
      'ActivityType': activityType,
      'PublishPlatform': publishPlatform,
      'PostType': postType,
      'GroupID': groupId,
      'MediaMode': mediaMode,
      'Description': description,
      'GuestType': guestType,
      'GuestName': guestName,
      'GuestDesignation': guestDesignation,
      'GuestOrg': guestOrg,
      'ActivitiesConducted': activitiesConducted,
      'AnyInformation': anyInformation,
      'MOP': mop,
      'DataUploaded': dataUploaded,
      'InProcess': inProcess,
      'DesignDone': designDone,
      'WritingDone': writingDone,
      'EditingDone': editingDone,
      'ProofReadingDone': proofReadingDone,
      'ThumbnailDone': thumbnailDone,
      'ReadyToBePosted': readyToBePosted,
      'PostUploaded': postUploaded,
      'rowIndex': rowIndex,
      'isCombined': isCombined,
      'CombinedPosts': combinedPosts,
    };
  }

  /// Whether this task has any revision notes / remarks
  bool get hasRevisionRemarks {
    final n = notes.toLowerCase();
    return n.contains('[revision') || n.contains('revision:') || n.contains('sent back') || n.contains('send back');
  }

  /// Extracts the list of individual revision entries
  List<String> get revisionEntries {
    if (notes.trim().isEmpty) return [];
    return notes
        .split(RegExp(r'\n+(?=\[(?:Revision|Sent Back))', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Extracts the clean comment text from the latest revision remark
  String get latestRevisionCleanRemark {
    if (notes.trim().isEmpty) return '';
    final entries = revisionEntries;
    final last = entries.isNotEmpty ? entries.last : notes.trim();
    final match = RegExp(r'^\[(?:Revision|Sent Back)[^\]]*\]:\s*(.*)$', dotAll: true, caseSensitive: false).firstMatch(last);
    if (match != null && match.group(1) != null && match.group(1)!.trim().isNotEmpty) {
      return match.group(1)!.trim();
    }
    return last;
  }

  /// Extracts sender / reviewer info
  String get latestRevisionSender {
    if (notes.trim().isEmpty) return '';
    final entries = revisionEntries;
    final last = entries.isNotEmpty ? entries.last : notes.trim();
    final matchFrom = RegExp(r'\[Revision from ([^\]]+?) on ', caseSensitive: false).firstMatch(last);
    if (matchFrom != null) {
      return matchFrom.group(1)?.trim() ?? '';
    }
    final matchSentBack = RegExp(r'\[Sent Back by ([^\]]+?)\]', caseSensitive: false).firstMatch(last);
    if (matchSentBack != null) {
      return matchSentBack.group(1)?.trim() ?? '';
    }
    if (last.toLowerCase().contains('[revision')) {
      return 'Reviewer / Proofreader';
    }
    return '';
  }

  /// Extracts timestamp or date
  String get latestRevisionDate {
    if (notes.trim().isEmpty) return '';
    final entries = revisionEntries;
    final last = entries.isNotEmpty ? entries.last : notes.trim();
    final matchFrom = RegExp(r' on ([^\]]+)\]', caseSensitive: false).firstMatch(last);
    if (matchFrom != null) {
      return matchFrom.group(1)?.trim() ?? '';
    }
    final matchOld = RegExp(r'\[Revision:\s*([^\]]+)\]', caseSensitive: false).firstMatch(last);
    if (matchOld != null) {
      return matchOld.group(1)?.trim() ?? '';
    }
    return '';
  }
}
