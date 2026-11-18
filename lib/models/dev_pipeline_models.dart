class DevProject {
  final String projectId;
  final String stream;
  final String campaignName;
  final String sessionName;
  final String duration;
  final String festivalsIncluded;
  final String startDate;
  final String completionDate;
  final bool iecContent;
  final bool iecDesigning;
  final bool iecProofread;
  final bool iecFinalCheck;
  final String folderLink;
  final String docLink;
  final String status;
  final String createdAt;
  final String pptFolderLink;
  final String iecFolderLink;
  final String iecWritingDocLink;
  final String iecDesigningFolderLink;
  final String iecProofreadDocLink;
  final String iecFinalCheckDocLink;
  final String researchedDataLink;
  final String researchedDocLink;
  final String thumbnailFolderLink;

  DevProject({
    required this.projectId,
    required this.stream,
    required this.campaignName,
    required this.sessionName,
    required this.duration,
    required this.festivalsIncluded,
    required this.startDate,
    required this.completionDate,
    required this.iecContent,
    required this.iecDesigning,
    required this.iecProofread,
    required this.iecFinalCheck,
    required this.folderLink,
    required this.docLink,
    required this.status,
    required this.createdAt,
    this.pptFolderLink = '',
    this.iecFolderLink = '',
    this.iecWritingDocLink = '',
    this.iecDesigningFolderLink = '',
    this.iecProofreadDocLink = '',
    this.iecFinalCheckDocLink = '',
    this.researchedDataLink = '',
    this.researchedDocLink = '',
    this.thumbnailFolderLink = '',
  });

  factory DevProject.fromJson(Map<String, dynamic> json) {
    return DevProject(
      projectId: json['ProjectID']?.toString() ?? '',
      stream: json['Stream']?.toString() ?? 'Campaign Development',
      campaignName: json['CampaignName']?.toString() ?? '',
      sessionName: json['SessionName']?.toString() ?? '',
      duration: json['Duration']?.toString() ?? '',
      festivalsIncluded: json['FestivalsIncluded']?.toString() ?? '',
      startDate: json['StartDate']?.toString() ?? '',
      completionDate: json['CompletionDate']?.toString() ?? '',
      iecContent: json['IECContent']?.toString().toLowerCase() == 'yes',
      iecDesigning: json['IECDesigning']?.toString().toLowerCase() == 'yes',
      iecProofread: json['IECProofread']?.toString().toLowerCase() == 'yes',
      iecFinalCheck: json['IECFinalCheck']?.toString().toLowerCase() == 'yes',
      folderLink: json['FolderLink']?.toString() ?? '',
      docLink: json['DocLink']?.toString() ?? '',
      status: json['Status']?.toString() ?? 'Active',
      createdAt: json['CreatedAt']?.toString() ?? '',
      pptFolderLink: json['PptFolderLink']?.toString() ?? '',
      iecFolderLink: json['IecFolderLink']?.toString() ?? '',
      iecWritingDocLink: json['IecWritingDocLink']?.toString() ?? '',
      iecDesigningFolderLink: json['IecDesigningFolderLink']?.toString() ?? '',
      iecProofreadDocLink: json['IecProofreadDocLink']?.toString() ?? '',
      iecFinalCheckDocLink: json['IecFinalCheckDocLink']?.toString() ?? '',
      researchedDataLink: json['ResearchedDataLink']?.toString() ?? '',
      researchedDocLink: json['ResearchedDocLink']?.toString() ?? '',
      thumbnailFolderLink: json['ThumbnailFolderLink']?.toString() ?? '',
    );
  }
}

class DevTask {
  final String taskId;
  final String projectId;
  final String stage;
  final String assignee;
  final String assigneeEmail;
  String status;
  final String dueDate;
  final String allottedDate;
  final String completedAt;
  final String docLink;
  String notes;
  final int rowIndex;

  // Enriched project fields
  final String campaignName;
  final String sessionName;
  final String stream;
  final String folderLink;
  final String pptFolderLink;
  final String prevDocLink;
  final String writingDocLink;
  final String editingDocLink;
  final String proofreadingDocLink;
  final String crosscheckDocLink;
  final String iecFolderLink;
  final String iecWritingDocLink;
  final String iecDesigningFolderLink;
  final String iecProofreadDocLink;
  final String iecFinalCheckDocLink;
  final String festivalsIncluded;
  final String researchedDataLink;
  final String researchedDocLink;
  final String thumbnailFolderLink;

  DevTask({
    required this.taskId,
    required this.projectId,
    required this.stage,
    required this.assignee,
    required this.assigneeEmail,
    required this.status,
    required this.dueDate,
    required this.allottedDate,
    required this.completedAt,
    required this.docLink,
    required this.notes,
    required this.rowIndex,
    this.campaignName = '',
    this.sessionName = '',
    this.stream = '',
    this.folderLink = '',
    this.pptFolderLink = '',
    this.prevDocLink = '',
    this.writingDocLink = '',
    this.editingDocLink = '',
    this.proofreadingDocLink = '',
    this.crosscheckDocLink = '',
    this.iecFolderLink = '',
    this.iecWritingDocLink = '',
    this.iecDesigningFolderLink = '',
    this.iecProofreadDocLink = '',
    this.iecFinalCheckDocLink = '',
    this.festivalsIncluded = '',
    this.researchedDataLink = '',
    this.researchedDocLink = '',
    this.thumbnailFolderLink = '',
  });

  factory DevTask.fromJson(Map<String, dynamic> json) {
    return DevTask(
      taskId: json['TaskID']?.toString() ?? '',
      projectId: json['ProjectID']?.toString() ?? '',
      stage: json['Stage']?.toString() ?? '',
      assignee: json['Assignee']?.toString() ?? '',
      assigneeEmail: json['AssigneeEmail']?.toString() ?? '',
      status: json['Status']?.toString() ?? 'Waiting',
      dueDate: json['DueDate']?.toString() ?? '',
      allottedDate: json['AllottedDate']?.toString() ?? '',
      completedAt: json['CompletedAt']?.toString() ?? '',
      docLink: json['DocLink']?.toString() ?? '',
      notes: json['Notes']?.toString() ?? '',
      rowIndex: json['rowIndex'] is int ? json['rowIndex'] : int.tryParse(json['rowIndex']?.toString() ?? '0') ?? 0,
      campaignName: json['CampaignName']?.toString() ?? '',
      sessionName: json['SessionName']?.toString() ?? '',
      stream: json['Stream']?.toString() ?? '',
      folderLink: json['FolderLink']?.toString() ?? '',
      pptFolderLink: json['PptFolderLink']?.toString() ?? '',
      prevDocLink: json['PrevDocLink']?.toString() ?? '',
      writingDocLink: json['WritingDocLink']?.toString() ?? '',
      editingDocLink: json['EditingDocLink']?.toString() ?? '',
      proofreadingDocLink: json['ProofreadingDocLink']?.toString() ?? '',
      crosscheckDocLink: json['CrosscheckDocLink']?.toString() ?? '',
      iecFolderLink: json['IecFolderLink']?.toString() ?? '',
      iecWritingDocLink: json['IecWritingDocLink']?.toString() ?? '',
      iecDesigningFolderLink: json['IecDesigningFolderLink']?.toString() ?? '',
      iecProofreadDocLink: json['IecProofreadDocLink']?.toString() ?? '',
      iecFinalCheckDocLink: json['IecFinalCheckDocLink']?.toString() ?? '',
      festivalsIncluded: json['FestivalsIncluded']?.toString() ?? '',
      researchedDataLink: json['ResearchedDataLink']?.toString() ?? '',
      researchedDocLink: json['ResearchedDocLink']?.toString() ?? '',
      thumbnailFolderLink: json['ThumbnailFolderLink']?.toString() ?? '',
    );
  }
}
