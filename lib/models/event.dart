class Event {
  final String taskId;
  final String postNo;
  final String stage;
  final String assignee;
  final String assigneeName;
  final String status;
  final String docLink;
  final String allottedDate;
  final String dueDate;
  final String notes;
  
  // Post metadata
  final String program;
  final String branch;
  final String state;
  final String venue;
  final String date;
  final String theme;
  final String timings;
  final int male;
  final int female;
  final int children;
  final int totalBeneficiary;
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
      taskId: json['TaskID']?.toString() ?? '',
      postNo: json['PostNo']?.toString() ?? '',
      stage: json['Stage']?.toString() ?? '',
      assignee: json['Assignee']?.toString() ?? '',
      assigneeName: (json['AssigneeName'] ?? json['Assignee'])?.toString() ?? '',
      status: json['Status']?.toString() ?? '',
      docLink: json['DocLink']?.toString() ?? '',
      allottedDate: json['AllottedDate']?.toString() ?? '',
      dueDate: json['DueDate']?.toString() ?? '',
      notes: json['Notes']?.toString() ?? '',
      program: json['Program']?.toString() ?? '',
      branch: json['Branch']?.toString() ?? '',
      state: json['State']?.toString() ?? '',
      venue: json['Venue']?.toString() ?? '',
      date: json['Date']?.toString() ?? '',
      theme: json['Theme']?.toString() ?? '',
      timings: json['Timings']?.toString() ?? '',
      male: _parseInt(json['Male']),
      female: _parseInt(json['Female']),
      children: _parseInt(json['Children']),
      totalBeneficiary: _parseInt(json['TotalBeneficiary']),
      organizers: json['Organizers']?.toString() ?? '',
      partners: json['Partners']?.toString() ?? '',
      importantInfo: json['ImportantInfo']?.toString() ?? '',
      folderLink: json['FolderLink']?.toString() ?? '',
      activityType: json['ActivityType']?.toString() ?? '',
      publishPlatform: json['PublishPlatform']?.toString() ?? '',
      postType: json['PostType']?.toString() ?? '',
      groupId: json['GroupID']?.toString() ?? '',
      mediaMode: json['MediaMode']?.toString() ?? '',
      description: json['Description']?.toString() ?? '',
      guestType: json['GuestType']?.toString() ?? '',
      guestName: json['GuestName']?.toString() ?? '',
      guestDesignation: json['GuestDesignation']?.toString() ?? '',
      guestOrg: json['GuestOrg']?.toString() ?? '',
      activitiesConducted: json['ActivitiesConducted']?.toString() ?? '',
      anyInformation: json['AnyInformation']?.toString() ?? '',
      mop: json['MOP']?.toString() ?? '',
      dataUploaded: json['DataUploaded']?.toString() ?? '',
      inProcess: json['InProcess']?.toString() ?? '',
      designDone: json['DesignDone']?.toString() ?? '',
      writingDone: json['WritingDone']?.toString() ?? '',
      editingDone: json['EditingDone']?.toString() ?? '',
      proofReadingDone: json['ProofReadingDone']?.toString() ?? '',
      thumbnailDone: json['ThumbnailDone']?.toString() ?? '',
      readyToBePosted: json['ReadyToBePosted']?.toString() ?? '',
      postUploaded: json['PostUploaded']?.toString() ?? '',
      rowIndex: json['rowIndex'] != null ? int.tryParse(json['rowIndex'].toString()) ?? 0 : 0,
      isCombined: json['isCombined'] == true,
      combinedPosts: json['CombinedPosts'] != null 
          ? List<Map<String, dynamic>>.from(json['CombinedPosts']) 
          : [],
    );
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }
}
