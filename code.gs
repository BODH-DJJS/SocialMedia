var POSTS_SHEET = 'Events';
var TASKS_SHEET = 'Tasks';
var USERS_SHEET = 'Users';
var PIPELINE_SHEET = 'Pipeline Config';
var BRANCH_SPOC_SHEET = 'Branch SPOC';

// ── Source Form Responses Sheet (BODH Responses) ──
var SOURCE_RESPONSES_SPREADSHEET_ID = '1OvVqqDI5JwTMJA4svMKXUb2JuOMQUaPgH7Un-UMum14';
var SOURCE_RESPONSES_TAB = 'BODH Responses';

// ── Development Pipeline Sheets ──
var DEV_PROJECTS_SHEET = 'Dev_Projects';
var DEV_TASKS_SHEET = 'Dev_Tasks';
var DEV_PIPELINE_SHEET = 'Dev_Pipeline_Config';
var DEV_USERS_SHEET = 'Dev_Users';

function ensureSheets() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  
  if (!ss.getSheetByName(USERS_SHEET)) {
    var users = ss.insertSheet(USERS_SHEET);
    users.appendRow(['Email', 'Name', 'Role']);
  }
  var usersSheet = ss.getSheetByName(USERS_SHEET);
  var usersData = usersSheet.getDataRange().getValues();
  var roleCounts = {};
  for (var u = 1; u < usersData.length; u++) {
    var role = usersData[u][2];
    if (role) {
      roleCounts[role] = (roleCounts[role] || 0) + 1;
    }
  }

  var roles = [
    {role: 'Writer', prefix: 'writer'},
    {role: 'Editor', prefix: 'editor'},
    {role: 'Proofreader', prefix: 'proofreader'},
    {role: 'CrossChecker', prefix: 'crosscheck'},
    {role: 'Thumbnail Designer', prefix: 'thumbnail'},
    {role: 'Photo Selector', prefix: 'photoselect'},
    {role: 'Photo Editor', prefix: 'photoedit'},
    {role: 'Video Editor', prefix: 'videoedit'},
    {role: 'Media CrossChecker', prefix: 'mediacheck'},
    {role: 'Uploader', prefix: 'uploader'},
    // Development Pipeline Roles
    {role: 'Campaign Ideator', prefix: 'ideator'},
    {role: 'Campaign Researcher', prefix: 'researcher'},
    {role: 'Sequencer', prefix: 'sequencer'},
    {role: 'Campaign Writer', prefix: 'camp_writer'},
    {role: 'PPT Designer', prefix: 'ppt_dev'},
    {role: 'Campaign Proofreader', prefix: 'camp_proof'},
    {role: 'Campaign Editor', prefix: 'camp_editor'},
    {role: 'Final Reviewer', prefix: 'final_rev'}
  ];

  for (var r = 0; r < roles.length; r++) {
    var count = roleCounts[roles[r].role] || 0;
    // Add users until we have at least 1 sample user for each role
    var suffix = count + 1;
    var targetCount = roles[r].role.indexOf('Campaign') !== -1 || roles[r].role === 'Sequencer' || roles[r].role === 'PPT Designer' || roles[r].role === 'Final Reviewer' ? 2 : 5;
    while (count < targetCount) {
      usersSheet.appendRow([roles[r].prefix + suffix + '@example.com', 'Sample ' + roles[r].role + ' ' + suffix, roles[r].role]);
      count++;
      suffix++;
    }
  }
  
  if (!roleCounts['Admin']) {
    usersSheet.appendRow(['admin', 'Admin User', 'Admin']);
  }
  
  var pipeSheet = ss.getSheetByName(PIPELINE_SHEET);
  if (!pipeSheet) {
    pipeSheet = ss.insertSheet(PIPELINE_SHEET);
    pipeSheet.appendRow(['Stage Name', 'Required Role', 'Depends On']);
  }
  
  // Ensure all stages exist in the config
  var requiredStages = [
    {stage: 'Writing', role: 'Writer', dep: ''},
    {stage: 'Editing', role: 'Editor', dep: 'Writing'},
    {stage: 'Proofreading', role: 'Proofreader', dep: 'Editing, Media Cross Check'},
    {stage: 'Text Crosscheck', role: 'CrossChecker', dep: 'Proofreading'},
    {stage: 'Thumbnail Selection', role: 'Thumbnail Designer', dep: ''},
    {stage: 'Thumbnail Processing', role: 'Thumbnail Designer', dep: 'Thumbnail Selection'},
    {stage: 'Thumbnail Cross checking', role: 'Thumbnail Designer', dep: 'Thumbnail Processing'},
    {stage: 'Photo Editing', role: 'Photo Editor', dep: ''},
    {stage: 'Video Editing', role: 'Video Editor', dep: ''},
    {stage: 'Media Cross Check', role: 'Media CrossChecker', dep: 'Photo Editing, Video Editing'},
    {stage: 'Media Final Cross check', role: 'Media CrossChecker', dep: 'Proofreading'},
    {stage: 'Ready to Post', role: 'Uploader', dep: 'Text Crosscheck, Media Final Cross check'},
    {stage: 'Photos Clean', role: 'Photo Selector', dep: 'Ready to Post'}
  ];
  
  // Remove obsolete stages from PIPELINE_SHEET
  var existingPipeData = pipeSheet.getDataRange().getValues();
  for (var i = existingPipeData.length - 1; i >= 1; i--) {
    var sNorm = normalizeStageName(existingPipeData[i][0]);
    if (sNorm === 'photosselection' || sNorm === 'photoselection') {
      pipeSheet.deleteRow(i + 1);
    }
  }
  existingPipeData = pipeSheet.getDataRange().getValues();
  
  for (var r = 0; r < requiredStages.length; r++) {
    var matchIdx = -1;
    for (var i = 1; i < existingPipeData.length; i++) {
      if (normalizeStageName(existingPipeData[i][0]) === normalizeStageName(requiredStages[r].stage)) {
        matchIdx = i + 1;
        pipeSheet.getRange(i + 1, 1).setValue(requiredStages[r].stage);
        pipeSheet.getRange(i + 1, 2).setValue(requiredStages[r].role);
        pipeSheet.getRange(i + 1, 3).setValue(requiredStages[r].dep);
        break;
      }
    }
    if (matchIdx === -1) {
      pipeSheet.appendRow([requiredStages[r].stage, requiredStages[r].role, requiredStages[r].dep]);
    }
  }
  
  if (!ss.getSheetByName(TASKS_SHEET)) {
    var tasks = ss.insertSheet(TASKS_SHEET);
    tasks.appendRow(['TaskID', 'PostNo', 'Stage', 'Assignee', 'Status', 'StartedAt', 'CompletedAt', 'DocLink']);
  }

  if (!ss.getSheetByName(BRANCH_SPOC_SHEET)) {
    var spoc = ss.insertSheet(BRANCH_SPOC_SHEET);
    spoc.appendRow(['Branch', 'SPOCName', 'SPOCEmail']);
  }
  
  // Ensure Tasks sheet has new columns
  var tasksSheet = ss.getSheetByName(TASKS_SHEET);
  var taskHeaders = tasksSheet.getRange(1, 1, 1, tasksSheet.getLastColumn()).getValues()[0];
  if (taskHeaders.indexOf('AllottedDate') === -1) tasksSheet.getRange(1, taskHeaders.length + 1).setValue('AllottedDate');
  if (taskHeaders.indexOf('DueDate') === -1) tasksSheet.getRange(1, taskHeaders.length + 2).setValue('DueDate');
  if (taskHeaders.indexOf('Notes') === -1) tasksSheet.getRange(1, taskHeaders.length + 3).setValue('Notes');
  if (taskHeaders.indexOf('CanvaLink') === -1) tasksSheet.getRange(1, taskHeaders.length + 4).setValue('CanvaLink');
}

function formatDate(dateVal) {
  if (!dateVal) return '';
  var d;
  if (dateVal instanceof Date) {
    d = dateVal;
  } else {
    d = new Date(dateVal);
    if (isNaN(d.getTime())) return String(dateVal);
  }
  return Utilities.formatDate(d, "Asia/Kolkata", "dd-MMM-yyyy");
}

function safeNum(val) {
  var n = Number(val);
  return isNaN(n) ? 0 : n;
}

function doPost(e) {
  try {
    ensureSheets();
    var payload = JSON.parse(e.postData.contents);
    var action = payload.action;

    if (action === 'login') {
      return respond(handleLogin(payload));
    } else if (action === 'getTasks') {
      return respond(handleGetTasks(payload));
    } else if (action === 'getPosts') {
      return respond(handleGetPosts(payload));
    } else if (action === 'getPostDetails') {
      return respond(handleGetPostDetails(payload));
    } else if (action === 'getMediaFolders') {
      return respond(handleGetMediaFolders(payload));
    } else if (action === 'getPhotos') {
      return respond(handleGetPhotos(payload));
    } else if (action === 'checkFolderNotEmpty') {
      return respond(handleCheckFolderNotEmpty(payload));
    } else if (action === 'updateTask') {
      var lock = LockService.getScriptLock();
      lock.waitLock(10000);
      try {
        var res = handleUpdateTask(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'reassignTasks') {
      var lock = LockService.getScriptLock();
      lock.waitLock(10000);
      try {
        var res = handleReassignTasks(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'createTasksForPost') {
      var lock = LockService.getScriptLock();
      lock.waitLock(15000);
      try {
        var res = createTasksForPost(payload.postNo);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'getDashboardStats') {
      return respond(handleGetDashboardStats());
    } else if (action === 'getUsers') {
      return respond(handleGetUsers());
    } else if (action === 'getBranchSPOCs') {
      return respond(handleGetBranchSPOCs());
    } else if (action === 'updateBranchSPOC') {
      return respond(handleUpdateBranchSPOC(payload));
    } else if (action === 'updatePostMeta') {
      return respond(handleUpdatePostMeta(payload));
    } else if (action === 'groupPosts') {
      return respond(handleGroupPosts(payload));
    } else if (action === 'ungroupPost') {
      return respond(handleUngroupPost(payload));
    } else if (action === 'renameGroup') {
      return respond(handleRenameGroup(payload));
    } else if (action === 'reverseTask') {
      var lock = LockService.getScriptLock();
      lock.waitLock(10000);
      try {
        var res = handleReverseTask(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'createTasksForPostV2') {
      var lock = LockService.getScriptLock();
      lock.waitLock(15000);
      try {
        var res = createTasksForPostV2(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'deleteWorkflow') {
      var lock = LockService.getScriptLock();
      lock.waitLock(15000);
      try {
        var res = handleDeleteWorkflow(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'revertMediaFinalToProofreading') {
      var lock = LockService.getScriptLock();
      lock.waitLock(15000);
      try {
        var res = revertActiveFinalMediaToProofreading();
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'getDevProjects') {
      return respond(handleGetDevProjects(payload));
    } else if (action === 'getDevTasks') {
      return respond(handleGetDevTasks(payload));
    } else if (action === 'createDevProject') {
      var lock = LockService.getScriptLock();
      lock.waitLock(20000);
      try {
        var res = handleCreateDevProject(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'updateDevTask') {
      var lock = LockService.getScriptLock();
      lock.waitLock(10000);
      try {
        var res = handleUpdateDevTask(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'redoDevTask') {
      var lock = LockService.getScriptLock();
      lock.waitLock(10000);
      try {
        var res = handleRedoDevTask(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'reassignDevTask') {
      var lock = LockService.getScriptLock();
      lock.waitLock(10000);
      try {
        var res = handleReassignDevTask(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'updateBeneficiaries') {
      var lock = LockService.getScriptLock();
      lock.waitLock(15000);
      try {
        var res = handleUpdateBeneficiaries(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else if (action === 'getDevUsers') {
      return respond(handleGetDevUsers());
    } else if (action === 'deleteDevProject') {
      var lock = LockService.getScriptLock();
      lock.waitLock(15000);
      try {
        var res = handleDeleteDevProject(payload);
        return respond(res);
      } finally {
        lock.releaseLock();
      }
    } else {
      return respond({success: false, message: 'Unknown action'});
    }
  } catch (error) {
    return respond({success: false, message: 'App Script Error: ' + error.toString()});
  }
}

function respond(data) {
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON);
}

function handleLogin(payload) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(USERS_SHEET);
  var data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    var userEmail = data[i][0].toString().toLowerCase();
    
    // Login via Google (uses email) or manual (uses username which is actually email)
    var inputIdentifier = payload.email || payload.username;
    
    if (inputIdentifier && userEmail === inputIdentifier.toLowerCase()) {
      if (payload.displayName && data[i][1] !== payload.displayName) {
        sheet.getRange(i + 1, 2).setValue(payload.displayName);
      }
      return { success: true, role: data[i][2], username: data[i][0] };
    }
  }
  return { success: false, message: 'Account not found or unauthorized. Ask admin to add your email.' };
}

function buildPostObj(pRow) {
  var male = safeNum(pRow[8]);
  var female = safeNum(pRow[9]);
  var children = safeNum(pRow[10]);
  return {
    'PostNo': pRow[0] || '',
    'Program': pRow[1] || '',
    'Branch': pRow[2] || '',
    'State': pRow[3] || '',
    'Venue': pRow[4] || '',
    'Theme': pRow[5] || '',
    'Date': formatDate(pRow[6]),
    'Timings': pRow[7] || '',
    'Male': male,
    'Female': female,
    'Children': children,
    'TotalBeneficiary': male + female + children,
    'Organizers': pRow[11] || '',
    'Partners': pRow[12] || '',
    'GuestType': pRow[14] || '',
    'GuestName': pRow[15] || '',
    'GuestDesignation': pRow[16] || '',
    'GuestOrg': pRow[17] || '',
    'ImportantInfo': pRow[19] || '',
    'FolderLink': pRow[21] || pRow[20] || '',
    'ActivityType': pRow[22] || '',
    'ActivitiesConducted': pRow[19] || '',
    'AnyInformation': pRow[20] || '',
    'MOP': pRow[23] || '',
    'DataUploaded': pRow[24] || '',
    'InProcess': pRow[25] || '',
    'DesignDone': pRow[26] || '',
    'WritingDone': pRow[27] || '',
    'EditingDone': pRow[28] || '',
    'ProofReadingDone': pRow[29] || '',
    'ThumbnailDone': pRow[30] || '',
    'ReadyToBePosted': pRow[31] || '',
    'PostUploaded': pRow[32] || '',
    'PublishPlatform': pRow[35] || '',
    'PostType': pRow[36] || '',
    'GroupID': pRow[37] || '',
    'MediaMode': pRow[38] || '',
    'Description': pRow[39] || '',
    'PostStatus': pRow[40] || ''
  };
}

function normalizeStageName(st) {
  if (!st) return '';
  var norm = st.toString().toLowerCase()
           .replace(/[^a-z0-9]/g, '')
           .replace(/photos/g, 'photo')
           .replace(/videos/g, 'video');
  if (norm === 'crosscheck' || norm === 'textcrosscheck' || norm === 'crosschecking' || norm === 'textcrosschecking') {
    return 'textcrosscheck';
  }
  return norm;
}

function backfillMissingTasks(ss) {
  var tasksSheet = ss.getSheetByName(TASKS_SHEET);
  var pipeSheet = ss.getSheetByName(PIPELINE_SHEET);
  if (!tasksSheet || !pipeSheet) return false;
  
  var tasksData = tasksSheet.getDataRange().getValues();
  if (tasksData.length < 2) return false;

  var postsSheet = ss.getSheetByName(POSTS_SHEET);
  var postsData = postsSheet ? postsSheet.getDataRange().getValues() : [];
  var postMetadata = {};
  for (var i = 1; i < postsData.length; i++) {
    var rPNo = postsData[i][0] ? postsData[i][0].toString().trim() : '';
    var rGId = postsData[i][37] ? postsData[i][37].toString().trim() : '';
    var pub = postsData[i][35] ? postsData[i][35].toString().toLowerCase() : '';
    var mod = postsData[i][38] ? postsData[i][38].toString().toLowerCase() : '';
    if (rPNo && !postMetadata[rPNo]) postMetadata[rPNo] = { pub: pub, mod: mod };
    if (rGId && !postMetadata[rGId]) postMetadata[rGId] = { pub: pub, mod: mod };
  }

  var pipeData = pipeSheet.getDataRange().getValues();
  
  var requiredStages = [];
  var normalizedRequired = [];
  for (var p = 1; p < pipeData.length; p++) {
    if (pipeData[p][0]) {
      var st = pipeData[p][0].toString().trim();
      requiredStages.push(st);
      normalizedRequired.push(normalizeStageName(st));
    }
  }
  
  var postTasks = {};
  var postStatuses = {}; 
  for (var i = 1; i < tasksData.length; i++) {
    var pNo = tasksData[i][1];
    var st = tasksData[i][2];
    var status = tasksData[i][4];
    if (pNo && st) {
      pNo = pNo.toString().trim();
      if (!postTasks[pNo]) {
        postTasks[pNo] = [];
        postStatuses[pNo] = { total: 0, done: 0 };
      }
      postTasks[pNo].push(normalizeStageName(st));
      postStatuses[pNo].total++;
      if (status === 'Done') postStatuses[pNo].done++;
    }
  }
  
  var newRows = [];
  var now = new Date().toLocaleString();
  var headers = tasksData[0];
  
  for (var pNo in postTasks) {
    if (postStatuses[pNo].total > 0 && postStatuses[pNo].total > postStatuses[pNo].done) {
      var existingSt = postTasks[pNo];
      var meta = postMetadata[pNo] || { pub: '', mod: '' };
      
      var skipStages = ['photosselection', 'photoselection'];
      if (meta.pub.indexOf('insta') === -1 || meta.mod.indexOf('video') === -1) {
        skipStages.push('thumbnailselection', 'thumbnailprocessing', 'thumbnailcrosschecking', 'thumbnailcrosscheck');
      }
      if (meta.mod.indexOf('video') === -1) {
        skipStages.push('videoediting');
      }
      if (meta.mod.indexOf('photo') === -1) {
        skipStages.push('photoediting');
      }

      for (var r = 0; r < requiredStages.length; r++) {
        var reqStage = requiredStages[r];
        var normReq = normalizedRequired[r];
        
        if (skipStages.indexOf(normReq) !== -1) continue;

        if (existingSt.indexOf(normReq) === -1) {
          var rowData = [];
          for (var h = 0; h < headers.length; h++) {
            var headerName = headers[h].toString();
            if (headerName === 'TaskID') rowData.push(pNo + '-' + reqStage);
            else if (headerName === 'PostNo') rowData.push(pNo);
            else if (headerName === 'Stage') rowData.push(reqStage);
            else if (headerName === 'Assignee') rowData.push('');
            else if (headerName === 'Status') rowData.push('Waiting');
            else if (headerName === 'StartedAt') rowData.push(now);
            else rowData.push('');
          }
          newRows.push(rowData);
          existingSt.push(normReq);
        }
      }
    }
  }
  
  if (newRows.length > 0) {
    tasksSheet.getRange(tasksData.length + 1, 1, newRows.length, headers.length).setValues(newRows);
    return true;
  }
  return false;
}

function cleanupAndSyncTasks(ss) {
  var taskSheet = ss.getSheetByName(TASKS_SHEET);
  if (!taskSheet) return;
  var data = taskSheet.getDataRange().getValues();
  if (data.length < 2) return;
  var headers = data[0];
  var taskIdCol = headers.indexOf('TaskID');
  var postNoCol = headers.indexOf('PostNo');
  var stageCol = headers.indexOf('Stage');
  var statusCol = headers.indexOf('Status');
  var assigneeCol = headers.indexOf('Assignee');
  var allottedCol = headers.indexOf('AllottedDate');
  var dueDateCol = headers.indexOf('DueDate');

  // 1. Delete obsolete Photos Selection tasks from TASKS_SHEET
  var deletedAny = false;
  for (var i = data.length - 1; i >= 1; i--) {
    var rawStage = (data[i][stageCol] || '').toString().trim();
    var sNorm = normalizeStageName(rawStage);
    if (sNorm === 'photosselection' || sNorm === 'photoselection') {
      taskSheet.deleteRow(i + 1);
      deletedAny = true;
    }
  }
  if (deletedAny) {
    data = taskSheet.getDataRange().getValues();
  }

  // 2. Auto-sync: If old stage is 'Cross check' or 'Crosscheck', rename cell to 'Text Crosscheck'
  var postTasksMap = {};
  for (var i = 1; i < data.length; i++) {
    var pNo = data[i][postNoCol];
    if (!pNo) continue;
    pNo = pNo.toString().trim();
    
    var rawStage = (data[i][stageCol] || '').toString().trim();
    if (rawStage === 'Cross check' || rawStage === 'Crosscheck') {
      taskSheet.getRange(i + 1, stageCol + 1).setValue('Text Crosscheck');
      rawStage = 'Text Crosscheck';
      if (taskIdCol !== -1) {
        var curTaskId = (data[i][taskIdCol] || '').toString();
        if (curTaskId.indexOf('-Cross check') !== -1 || curTaskId.indexOf('-Crosscheck') !== -1) {
          taskSheet.getRange(i + 1, taskIdCol + 1).setValue(pNo + '-Text Crosscheck');
        }
      }
    }
    
    if (!postTasksMap[pNo]) postTasksMap[pNo] = [];
    postTasksMap[pNo].push({
      stage: normalizeStageName(rawStage),
      status: data[i][statusCol],
      assignee: data[i][assigneeCol]
    });
  }

  // 3. Deduplicate and ensure Media Final Cross check exists for active posts
  // First, remove duplicate Media Final Cross check tasks if multiple exist for a post
  var finalCheckSeen = {};
  var duplicateRows = [];
  for (var i = data.length - 1; i >= 1; i--) {
    var pNo = (data[i][postNoCol] || '').toString().trim();
    var sNorm = normalizeStageName(data[i][stageCol]);
    if (sNorm === 'mediafinalcrosscheck' || sNorm === 'mediafinalcrosschecking') {
      if (finalCheckSeen[pNo]) {
        duplicateRows.push(i + 1);
      } else {
        finalCheckSeen[pNo] = true;
      }
    }
  }
  if (duplicateRows.length > 0) {
    for (var d = 0; d < duplicateRows.length; d++) {
      taskSheet.deleteRow(duplicateRows[d]);
    }
    data = taskSheet.getDataRange().getValues();
  }

  // 4. Run fixStuckTasks to fix any dependencies and unblock Ready to Post
  try {
    fixStuckTasks(ss);
  } catch(e) {}
}

function handleGetTasks(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  try {
    ensureSheets();
    cleanupAndSyncTasks(ss);
  } catch(e) {}
  
  var tasksData = ss.getSheetByName(TASKS_SHEET).getDataRange().getValues();
  var postsData = ss.getSheetByName(POSTS_SHEET).getDataRange().getValues();
  var usersData = ss.getSheetByName(USERS_SHEET).getDataRange().getValues();
  
  var userMap = {};
  for (var u = 1; u < usersData.length; u++) {
    if (usersData[u][0]) {
      userMap[usersData[u][0].toString().trim().toLowerCase()] = usersData[u][1] || usersData[u][0];
    }
  }
  
  if (tasksData.length < 2 || postsData.length < 2) return { success: true, tasks: [] };
  
  // Build Post Map for fast lookup (O(N) instead of O(N * M))
  var postsMap = {};
  for (var p = 1; p < postsData.length; p++) {
    var r = postsData[p];
    if (!r[0]) continue;
    var pNo = r[0].toString();
    var gId = r[37] ? r[37].toString() : '';
    
    if (!postsMap[pNo]) postsMap[pNo] = [];
    postsMap[pNo].push(r);
    
    if (gId && gId !== pNo) {
      if (!postsMap[gId]) postsMap[gId] = [];
      postsMap[gId].push(r);
    }
  }
  
  var taskHeaders = tasksData[0];
  var resultTasks = [];
  
  for (var i = 1; i < tasksData.length; i++) {
    var trow = tasksData[i];
    var tObj = {};
    for (var j = 0; j < taskHeaders.length; j++) {
      var val = trow[j];
      var headerName = taskHeaders[j].toString();
      
      if (val instanceof Date || (headerName === 'DueDate' && val) || (headerName === 'AllottedDate' && val) || 
(headerName === 'Date' && val)) {
        tObj[taskHeaders[j]] = formatDate(val);
      } else {
        tObj[taskHeaders[j]] = val;
      }
    }
    tObj['PostNo'] = trow[1]; // Fallback if header is messed up
    tObj['rowIndex'] = i + 1;
    tObj['AssigneeName'] = userMap[(tObj['Assignee'] || '').toString().trim().toLowerCase()] || tObj['Assignee'];
    
    if (payload.role === 'Admin' || tObj['Assignee'] === payload.username) {
      var matchedRows = postsMap[tObj['PostNo']] || [];

      if (matchedRows.length == 1) {
        var postObj = buildPostObj(matchedRows[0]);
        for (var key in postObj) tObj[key] = postObj[key];
      } else if (matchedRows.length > 1) {
        var totalMale = 0, totalFemale = 0, totalChildren = 0;
        var combinedPosts = [];
        for (var k = 0; k < matchedRows.length; k++) {
          var po = buildPostObj(matchedRows[k]);
          totalMale += po.Male;
          totalFemale += po.Female;
          totalChildren += po.Children;
          combinedPosts.push(po);
        }
        var firstPost = combinedPosts[0];
        
        // Populate standard fields for the task card using the first post as a base, but aggregate totals
        var postNosList = combinedPosts.map(function(cp) { return cp.PostNo; }).filter(function(x) { return x; }).join(', ');
        var combinedTitle = (tObj['PostNo'] && (tObj['PostNo'].indexOf('Combined') !== -1 || tObj['PostNo'].indexOf('Group') !== -1))
            ? tObj['PostNo']
            : ('Combined_Post(' + postNosList + ')');
        tObj['Theme'] = combinedTitle;
        tObj['Date'] = firstPost.Date;
        tObj['Branch'] = firstPost.Branch;
        tObj['State'] = firstPost.State;
        tObj['PublishPlatform'] = firstPost.PublishPlatform;
        tObj['PostType'] = firstPost.PostType;
        tObj['Male'] = totalMale;
        tObj['Female'] = totalFemale;
        tObj['Children'] = totalChildren;
        tObj['TotalBeneficiary'] = totalMale + totalFemale + totalChildren;
        tObj['CombinedPosts'] = combinedPosts; // Pass all combined posts down for the UI
        tObj['isCombined'] = true;
      }
      
      resultTasks.push(tObj);
    }
  }
  return { success: true, tasks: resultTasks.reverse() };
}

function handleGetPosts(payload) {
  var cache = CacheService.getScriptCache();
  var cacheKey = 'all_posts';

  // If forceRefresh requested, clear GAS cache
  if (payload && payload.forceRefresh) {
    cache.remove(cacheKey);
  } else {
    var cached = cache.get(cacheKey);
    if (cached) {
      return { success: true, posts: JSON.parse(cached), fromCache: true };
    }
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var postsData = ss.getSheetByName(POSTS_SHEET).getDataRange().getValues();
  if (postsData.length < 2) return { success: true, posts: [] };
  
  var posts = [];
  for (var i = 1; i < postsData.length; i++) {
    var pRow = postsData[i];
    if (!pRow[0]) continue;
    posts.push(buildPostObj(pRow));
  }
  var result = posts.reverse();

  // Cache for 5 minutes (300 sec). GAS cache max value size is 100KB.
  // If posts list is large, chunk it or skip caching gracefully.
  try {
    var serialized = JSON.stringify(result);
    if (serialized.length < 90000) { // stay under 100KB GAS limit
      cache.put(cacheKey, serialized, 300);
    }
  } catch(cErr) {}

  return { success: true, posts: result };
}

function handleGetPostDetails(payload) {
  var postNo = (payload.postNo || '').toString().trim();
  var isCombined = payload.isCombined === true || payload.isCombined === 'true';
  if (!postNo) return { success: false, message: 'Missing postNo' };

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var postsData = ss.getSheetByName(POSTS_SHEET).getDataRange().getValues();
  var tasksData = ss.getSheetByName(TASKS_SHEET).getDataRange().getValues();
  var usersData = ss.getSheetByName(USERS_SHEET).getDataRange().getValues();

  var userMap = {};
  for (var u = 1; u < usersData.length; u++) {
    if (usersData[u][0]) {
      userMap[usersData[u][0].toString().trim().toLowerCase()] = usersData[u][1] || usersData[u][0];
    }
  }

  var matchedPosts = [];
  var postNoCol = 0;
  var groupIdCol = 37; // GroupID column in Events sheet (0-indexed)

  for (var i = 1; i < postsData.length; i++) {
    var r = postsData[i];
    var rPNo = (r[postNoCol] || '').toString().trim();
    var rGId = (r[groupIdCol] || '').toString().trim();

    if (isCombined) {
      if (rGId === postNo || rPNo === postNo) {
        matchedPosts.push(buildPostObj(r));
      }
    } else {
      if (rPNo === postNo) {
        matchedPosts.push(buildPostObj(r));
        break;
      }
    }
  }

  // Also check if post was queried without isCombined but is a GroupID
  if (matchedPosts.length === 0 && !isCombined) {
    for (var i = 1; i < postsData.length; i++) {
      var r = postsData[i];
      var rGId = (r[groupIdCol] || '').toString().trim();
      if (rGId === postNo) {
        matchedPosts.push(buildPostObj(r));
        isCombined = true;
      }
    }
  }

  var postObj;
  var isCombinedGroup = isCombined || matchedPosts.length > 1;

  if (matchedPosts.length === 1) {
    postObj = matchedPosts[0];
  } else if (matchedPosts.length > 1) {
    var totalMale = 0, totalFemale = 0, totalChildren = 0;
    for (var k = 0; k < matchedPosts.length; k++) {
      totalMale += (Number(matchedPosts[k].Male) || 0);
      totalFemale += (Number(matchedPosts[k].Female) || 0);
      totalChildren += (Number(matchedPosts[k].Children) || 0);
    }
    var firstPost = matchedPosts[0];
    var postNosList = matchedPosts.map(function(cp) { return cp.PostNo; }).filter(function(x) { return x; }).join(', ');
    var combinedTitle = (postNo && (postNo.indexOf('Combined') !== -1 || postNo.indexOf('Group') !== -1))
        ? postNo
        : ('Combined_Post(' + postNosList + ')');
    
    postObj = {
      'PostNo': postNo,
      'Theme': combinedTitle,
      'Date': firstPost.Date,
      'Branch': firstPost.Branch,
      'State': firstPost.State,
      'Venue': firstPost.Venue,
      'FolderLink': firstPost.FolderLink,
      'PublishPlatform': firstPost.PublishPlatform,
      'PostType': firstPost.PostType,
      'Male': totalMale,
      'Female': totalFemale,
      'Children': totalChildren,
      'TotalBeneficiary': totalMale + totalFemale + totalChildren,
      'GroupID': postNo,
      'isCombined': true,
      'CombinedPosts': matchedPosts
    };
  } else {
    postObj = { 'PostNo': postNo };
  }

  // Fetch tasks for this postNo or GroupID
  var taskHeaders = tasksData[0];
  var resultTasks = [];
  for (var t = 1; t < tasksData.length; t++) {
    var trow = tasksData[t];
    var tPostNo = (trow[1] || '').toString().trim();
    if (tPostNo === postNo) {
      var tObj = {};
      for (var j = 0; j < taskHeaders.length; j++) {
        var val = trow[j];
        var headerName = taskHeaders[j].toString();
        if (val instanceof Date || (headerName === 'DueDate' && val) || (headerName === 'AllottedDate' && val) || (headerName === 'Date' && val)) {
          tObj[headerName] = formatDate(val);
        } else {
          tObj[headerName] = val;
        }
      }
      tObj['PostNo'] = trow[1];
      tObj['rowIndex'] = t + 1;
      tObj['AssigneeName'] = userMap[(tObj['Assignee'] || '').toString().trim().toLowerCase()] || tObj['Assignee'];

      // Enrich task with post metadata
      for (var key in postObj) {
        if (tObj[key] === undefined || tObj[key] === null || tObj[key] === '') {
          tObj[key] = postObj[key];
        }
      }
      tObj['isCombined'] = isCombinedGroup;
      tObj['CombinedPosts'] = matchedPosts;

      resultTasks.push(tObj);
    }
  }

  return {
    success: true,
    postData: postObj,
    combinedPosts: matchedPosts,
    tasks: resultTasks,
    isCombined: isCombinedGroup
  };
}

function handleGetDashboardStats() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var tasksData = ss.getSheetByName(TASKS_SHEET).getDataRange().getValues();
  var postsData = ss.getSheetByName(POSTS_SHEET).getDataRange().getValues();
  
  var totalPosts = 0;
  for (var i = 1; i < postsData.length; i++) {
    if (postsData[i][0]) totalPosts++;
  }
  
  var stageCounts = {};
  var assigneeCounts = {};
  var doneTasks = 0;
  var pendingTasks = 0;
  
  for (var i = 1; i < tasksData.length; i++) {
    var stage = tasksData[i][2] || 'Unknown';
    var assignee = tasksData[i][3] || 'Unassigned';
    var status = tasksData[i][4] || 'Not Started';
    
    stageCounts[stage] = (stageCounts[stage] || 0) + 1;
    assigneeCounts[assignee] = (assigneeCounts[assignee] || 0) + 1;
    
    if (status === 'Done') doneTasks++;
    else pendingTasks++;
  }
  
  return {
    success: true,
    stats: {
      totalPosts: totalPosts,
      totalTasks: tasksData.length - 1,
      doneTasks: doneTasks,
      pendingTasks: pendingTasks,
      stageCounts: stageCounts,
      assigneeCounts: assigneeCounts
    }
  };
}

function handleReassignTasks(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var usersSheet = ss.getSheetByName(USERS_SHEET);
  
  // 1. Ensure user exists
  if (payload.newAssigneeName) {
    var users = usersSheet.getDataRange().getValues();
    var found = false;
    for (var i = 1; i < users.length; i++) {
      if (users[i][0].toString().toLowerCase() === payload.newAssigneeEmail.toLowerCase()) {
        found = true;
        // Optional: Update name?
        if (users[i][1] !== payload.newAssigneeName) {
          usersSheet.getRange(i + 1, 2).setValue(payload.newAssigneeName);
        }
        break;
      }
    }
    if (!found) {
      usersSheet.appendRow([payload.newAssigneeEmail, payload.newAssigneeName, payload.role]);
    }
  }

  // 2. Update tasks
  var taskSheet = ss.getSheetByName(TASKS_SHEET);
  var tasks = taskSheet.getDataRange().getValues();
  var headers = tasks[0];
  var postNoCol = headers.indexOf('PostNo');
  var stageCol = headers.indexOf('Stage');
  var assigneeCol = headers.indexOf('Assignee');
  
  // Convert all postNos to strings for safe comparison (Sheets may return numbers)
  var postNosToUpdate = [String(payload.postNo)];
  if (payload.isCombined) {
    var postsSheet = ss.getSheetByName(POSTS_SHEET);
    var posts = postsSheet.getDataRange().getValues();
    var groupId = null;
    for(var p=1; p<posts.length; p++) {
      if (String(posts[p][0]) == String(payload.postNo) || String(posts[p][37]) == String(payload.postNo)) {
        groupId = posts[p][37] ? String(posts[p][37]) : String(payload.postNo);
        break;
      }
    }
    if (groupId) {
      for(var p=1; p<posts.length; p++) {
        if (String(posts[p][37]) == groupId || String(posts[p][0]) == groupId) {
          var pNo = String(posts[p][0]);
          if (postNosToUpdate.indexOf(pNo) === -1) {
            postNosToUpdate.push(pNo);
          }
        }
      }
    }
  }
  
  var updated = 0;
  var targetStage = normalizeStageName(payload.stage);
  for(var i=1; i<tasks.length; i++) {
    var tPostNo = String(tasks[i][postNoCol]);  // convert to string
    var tStage = normalizeStageName(tasks[i][stageCol]);
    if (postNosToUpdate.indexOf(tPostNo) !== -1 && tStage === targetStage) {
      taskSheet.getRange(i+1, assigneeCol+1).setValue(payload.newAssigneeEmail);
      updated++;
    }
  }
  if (updated === 0) {
    return {success: false, message: 'No matching task found for stage: ' + payload.stage + ' postNo: ' + payload.postNo};
  }
  return {success: true, message: 'Reassigned ' + updated + ' tasks'};
}

function handleUpdateTask(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(TASKS_SHEET);
  var headers = sheet.getDataRange().getValues()[0];
  var rowIndex = payload.rowIndex;
  var updates = payload.updates;
  
  if (updates['Status'] === 'Done') {
    updates['CompletedAt'] = new Date().toLocaleString();
    try {
      copyForwardDocument(rowIndex, headers, sheet);
    } catch(e) {
      // Drive logic failed, still save status
    }
    
    try {
      var data = sheet.getDataRange().getValues();
      var stage = data[rowIndex - 1][headers.indexOf('Stage')] || '';
      var postNo = data[rowIndex - 1][headers.indexOf('PostNo')];
      var currentStageLower = stage.toString().replace(/\s+/g, '').toLowerCase();
      if (currentStageLower === 'thumbnailcrosschecking' || currentStageLower === 'thumbnailcrosscheck' || currentStageLower === 'mediacrosscheck') {
        copyThumbnailFile(postNo);
      }
    } catch (e) {}
  }

  for (var key in updates) {
    var colIndex = headers.indexOf(key);
    if (colIndex === -1 && key === 'CanvaLink') {
      colIndex = headers.length;
      sheet.getRange(1, colIndex + 1).setValue('CanvaLink');
      headers.push('CanvaLink');
    }
    if (colIndex !== -1) {
      sheet.getRange(rowIndex, colIndex + 1).setValue(updates[key]);
    }
  }

  // If CanvaLink was updated or if task is marked Done with CanvaLink present, forward it to downstream media stages
  try {
    copyForwardCanvaLink(rowIndex, headers, sheet, updates);
  } catch (canvaErr) {}

  try {
    CacheService.getScriptCache().remove('all_posts');
  } catch(cErr) {}

  if (updates['Status'] === 'Done') {
    // Unlock any task that depends on this one
    try {
      unlockDependentTasks(rowIndex, headers, sheet);
    } catch (e) {
      // Fail silently if unlocking fails
    }
    
// Dynamic dependency unlocking handles Ready to Post and Photos Clean
    
    // Sync back to POSTS_SHEET to keep old columns updated
    try {
      var data = sheet.getDataRange().getValues();
      var row = data[rowIndex - 1];
      var stage = row[headers.indexOf('Stage')];
      var postNo = row[headers.indexOf('PostNo')];
      
      var postsSheet = ss.getSheetByName(POSTS_SHEET);
      var postsData = postsSheet.getDataRange().getValues();
      var postRowIdx = -1;
      for (var p = 1; p < postsData.length; p++) {
        if (postsData[p][0] == postNo) {
          postRowIdx = p + 1;
          break;
        }
      }
      
      if (postRowIdx !== -1) {
        if (stage === 'Writing') postsSheet.getRange(postRowIdx, 28).setValue('Yes'); // WritingDone
        else if (stage === 'Editing') postsSheet.getRange(postRowIdx, 29).setValue('Yes'); // EditingDone
        else if (stage === 'Proofreading') {
          postsSheet.getRange(postRowIdx, 30).setValue('Yes'); // ProofReadingDone
        }
        else if (stage === 'Thumbnail Cross checking' || stage === 'Media Cross Check') postsSheet.getRange(postRowIdx, 31).setValue('Yes'); // ThumbnailDone
        else if (stage === 'Ready to Post') {
          postsSheet.getRange(postRowIdx, 32).setValue('Ready'); // ReadyToBePosted
          postsSheet.getRange(postRowIdx, 33).setValue('Yes'); // PostUploaded
        }
      }
    } catch (e) {}
  }

  return { success: true, message: 'Task updated successfully' };
}

function fixStuckTasks(ss) {
  var taskSheet = ss.getSheetByName(TASKS_SHEET);
  var pipeSheet = ss.getSheetByName(PIPELINE_SHEET);
  if (!taskSheet || !pipeSheet) return;
  var pipe = pipeSheet.getDataRange().getValues();
  var data = taskSheet.getDataRange().getValues();
  if (data.length < 2) return;
  var headers = data[0];
  var statusCol = headers.indexOf('Status');
  var stageCol = headers.indexOf('Stage');
  var postNoCol = headers.indexOf('PostNo');
  var docLinkCol = headers.indexOf('DocLink');

  var reqMap = {};
  for (var i = 1; i < pipe.length; i++) {
    var stage = normalizeStageName(pipe[i][0]);
    if (stage === 'photosselection' || stage === 'photoselection') continue;
    var deps = (pipe[i][2] || '').toString().toLowerCase().split(',');
    var cleanDeps = [];
    for (var d = 0; d < deps.length; d++) {
      var c = normalizeStageName(deps[d]);
      if (c) cleanDeps.push(c);
    }
    reqMap[stage] = cleanDeps;
  }

  var posts = {};
  for (var i = 1; i < data.length; i++) {
    var pNo = data[i][postNoCol];
    if (!posts[pNo]) posts[pNo] = [];
    posts[pNo].push({
      rowIdx: i + 1,
      stage: normalizeStageName(data[i][stageCol]),
      status: data[i][statusCol],
      docLink: docLinkCol !== -1 ? data[i][docLinkCol] : ''
    });
  }

  for (var pNo in posts) {
    var pTasks = posts[pNo];
    
    // Fix missing doc links for Ready to Post
    var readyToPostTask = null;
    var crosscheckDocLink = '';
    for (var t = 0; t < pTasks.length; t++) {
      if (pTasks[t].stage === 'readytopost') readyToPostTask = pTasks[t];
      if (pTasks[t].stage === 'textcrosscheck') crosscheckDocLink = pTasks[t].docLink || '';
    }
    if (readyToPostTask && crosscheckDocLink && !readyToPostTask.docLink && docLinkCol !== -1) {
      taskSheet.getRange(readyToPostTask.rowIdx, docLinkCol + 1).setValue(crosscheckDocLink);
    }
    
    for (var t = 0; t < pTasks.length; t++) {
      var task = pTasks[t];
      if (task.stage === 'photosselection' || task.stage === 'photoselection') continue;

      var reqs = reqMap[task.stage] || [];
      if (reqs.length > 0) {
        var allDone = true;
        for (var r = 0; r < reqs.length; r++) {
          var reqTaskExists = false;
          var reqTaskDone = false;
          for (var pt = 0; pt < pTasks.length; pt++) {
            if (pTasks[pt].stage === reqs[r]) {
              reqTaskExists = true;
              if (pTasks[pt].status === 'Done') reqTaskDone = true;
              break;
            }
          }
          if (reqTaskExists && !reqTaskDone) {
            allDone = false;
            break;
          }
        }

        if (task.status === 'Waiting' || !task.status) {
          if (allDone) {
            taskSheet.getRange(task.rowIdx, statusCol + 1).setValue('Ready');
            task.status = 'Ready';
          }
        } else if (task.status === 'Ready') {
          // Revert premature Ready status back to Waiting if any prerequisite dependency is not yet Done
          // This applies to old posts and ensures Proofreading waits for Media Cross Check, and Ready to Post waits for both Text & Media Cross Check
          if (!allDone) {
            taskSheet.getRange(task.rowIdx, statusCol + 1).setValue('Waiting');
            task.status = 'Waiting';
          }
        }
      }
    }
  }
}

function revertActiveFinalMediaToProofreading() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var taskSheet = ss.getSheetByName(TASKS_SHEET);
  if (!taskSheet) return { success: false, message: 'Tasks sheet not found' };

  var data = taskSheet.getDataRange().getValues();
  if (data.length < 2) return { success: false, message: 'No tasks found' };

  var headers = data[0];
  var postNoCol = headers.indexOf('PostNo');
  var stageCol = headers.indexOf('Stage');
  var statusCol = headers.indexOf('Status');
  var completedAtCol = headers.indexOf('CompletedAt');

  // Find all posts that currently have Media Final Cross check in Ready / In Progress (not Done)
  var targetPosts = {};
  for (var i = 1; i < data.length; i++) {
    var sNorm = normalizeStageName(data[i][stageCol]);
    var status = data[i][statusCol];
    var pNo = (data[i][postNoCol] || '').toString().trim();
    if ((sNorm === 'mediafinalcrosscheck' || sNorm === 'mediafinalcrosschecking') && status !== 'Done' && status !== 'Waiting') {
      targetPosts[pNo] = true;
    }
  }

  var modifiedCount = 0;
  // For each target post:
  // 1. Set Proofreading to 'Ready' (clear CompletedAt if it was marked Done)
  // 2. Set Media Final Cross check to 'Waiting'
  // 3. Set Text Crosscheck to 'Waiting' if not Done
  for (var i = 1; i < data.length; i++) {
    var pNo = (data[i][postNoCol] || '').toString().trim();
    if (!targetPosts[pNo]) continue;

    var sNorm = normalizeStageName(data[i][stageCol]);
    if (sNorm === 'proofreading') {
      taskSheet.getRange(i + 1, statusCol + 1).setValue('Ready');
      if (completedAtCol !== -1) taskSheet.getRange(i + 1, completedAtCol + 1).setValue('');
      modifiedCount++;
    } else if (sNorm === 'mediafinalcrosscheck' || sNorm === 'mediafinalcrosschecking') {
      taskSheet.getRange(i + 1, statusCol + 1).setValue('Waiting');
    } else if (sNorm === 'textcrosscheck' || sNorm === 'crosscheck') {
      if (data[i][statusCol] !== 'Done') {
        taskSheet.getRange(i + 1, statusCol + 1).setValue('Waiting');
      }
    }
  }

  try {
    CacheService.getScriptCache().remove('all_posts');
  } catch(e) {}

  return { success: true, message: 'Successfully reverted ' + Object.keys(targetPosts).length + ' posts back to Proofreading.' };
}

function unlockDependentTasks(rowIndex, headers, taskSheet) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var pipe = ss.getSheetByName(PIPELINE_SHEET).getDataRange().getValues();
  var data = taskSheet.getDataRange().getValues();

  var currentStage = data[rowIndex - 1][headers.indexOf('Stage')];
  var postNo = data[rowIndex - 1][headers.indexOf('PostNo')];

  var dependentStages = [];
  var currentStageNorm = normalizeStageName(currentStage);

  // Find all stages that depend on currentStage
  for (var i = 1; i < pipe.length; i++) {
    var pStageNorm = normalizeStageName(pipe[i][0]);
    if (pStageNorm === 'photosselection' || pStageNorm === 'photoselection') continue;
    var deps = (pipe[i][2] || '').toString().toLowerCase().split(',');
    for (var d = 0; d < deps.length; d++) {
      if (normalizeStageName(deps[d]) === currentStageNorm) {
        dependentStages.push(pStageNorm);
      }
    }
  }

  if (dependentStages.length === 0) return;

  var stageCol = headers.indexOf('Stage');
  var postNoCol = headers.indexOf('PostNo');
  var statusCol = headers.indexOf('Status');

  // Find all tasks for this post
  var postTasks = [];
  for (var i = 1; i < data.length; i++) {
    if (data[i][postNoCol] == postNo) {
      postTasks.push({
        rowIdx: i + 1, 
        stage: normalizeStageName(data[i][stageCol]), 
        status: data[i][statusCol]
      });
    }
  }

  // For each dependent stage, check if ALL its dependencies are Done (only for tasks that exist)
  for (var d = 0; d < dependentStages.length; d++) {
    var depStageNorm = dependentStages[d];
    
    // Find the task for this dependent stage
    var targetTask = null;
    for (var p = 0; p < postTasks.length; p++) {
      if (postTasks[p].stage === depStageNorm) {
        targetTask = postTasks[p];
        break;
      }
    }
    
    if (targetTask && (targetTask.status === 'Waiting' || !targetTask.status)) {
      // Find its required dependencies from pipe
      var requiredDeps = [];
      for (var i = 1; i < pipe.length; i++) {
        if (normalizeStageName(pipe[i][0]) === depStageNorm) {
          var rawDeps = (pipe[i][2] || '').toString().toLowerCase().split(',');
          for (var r = 0; r < rawDeps.length; r++) {
            var n = normalizeStageName(rawDeps[r]);
            if (n) requiredDeps.push(n);
          }
          break;
        }
      }
      
      var allDone = true;
      for (var r = 0; r < requiredDeps.length; r++) {
        var reqDep = requiredDeps[r];
        if (!reqDep) continue;
        
        // Does this dependency exist in the post's tasks?
        var reqTaskExists = false;
        var reqTaskDone = false;
        for (var p = 0; p < postTasks.length; p++) {
          if (postTasks[p].stage === reqDep) {
            reqTaskExists = true;
            if (postTasks[p].status === 'Done') reqTaskDone = true;
            break;
          }
        }
        
        if (reqTaskExists && !reqTaskDone) {
          allDone = false;
          break;
        }
      }
      
      if (allDone) {
        taskSheet.getRange(targetTask.rowIdx, statusCol + 1).setValue('Ready');
      }
    }
  }
}

function copyForwardDocument(rowIndex, headers, taskSheet) {
  var data = taskSheet.getDataRange().getValues();
  var row = data[rowIndex - 1];
  var docLinkCol = headers.indexOf('DocLink');
  var postNoCol = headers.indexOf('PostNo');
  var stageCol = headers.indexOf('Stage');

  var currentDocUrl = row[docLinkCol];
  var postNo = row[postNoCol];
  var currentStage = row[stageCol];

  if (!currentDocUrl || currentDocUrl.indexOf('document/d/') === -1) return;
  var currentDocId = currentDocUrl.match(/[-\w]{25,}/);
  if (!currentDocId) return;

  var currentNorm = normalizeStageName(currentStage);

  // If we just finished Cross check, share its doc link with Ready to Post
  if (currentNorm === 'textcrosscheck') {
    for (var i = 1; i < data.length; i++) {
      if (data[i][postNoCol] == postNo && normalizeStageName(data[i][stageCol]) === 'readytopost') {
        taskSheet.getRange(i + 1, docLinkCol + 1).setValue(currentDocUrl);
        break;
      }
    }
    return; // Do not copy the document
  }

  var stageOrder = ['Writing', 'Editing', 'Proofreading', 'Text Crosscheck'];
  var stageOrderNorm = ['writing', 'editing', 'proofreading', 'textcrosscheck'];
  var currentIdx = stageOrderNorm.indexOf(currentNorm);
  if (currentIdx === -1 || currentIdx >= stageOrderNorm.length - 1) return;
  var nextStage = stageOrder[currentIdx + 1];
  var nextStageNorm = stageOrderNorm[currentIdx + 1];

  // Find the next stage row and get its document link
  var nextDocUrl = '';
  var nextRowIdx = -1;
  for (var i = 1; i < data.length; i++) {
    if (data[i][postNoCol] == postNo && normalizeStageName(data[i][stageCol]) === nextStageNorm) {
      nextDocUrl = data[i][docLinkCol] || '';
      nextRowIdx = i + 1;
      break;
    }
  }

  // Fallback: Create next doc if missing
  if ((!nextDocUrl || nextDocUrl.indexOf('document/d/') === -1) && nextRowIdx !== -1) {
    try {
      var currentFile = DriveApp.getFileById(currentDocId[0]);
      var parents = currentFile.getParents();
      if (parents.hasNext()) {
        var parentFolder = parents.next();
        var newDoc = DocumentApp.create(nextStage);
        var newDocFile = DriveApp.getFileById(newDoc.getId());
        newDocFile.moveTo(parentFolder);
        newDocFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT);
        newDoc.getBody().appendParagraph('Post: ' + postNo + ' | ' + nextStage + ' Document')
          .setHeading(DocumentApp.ParagraphHeading.HEADING1);
        newDoc.saveAndClose();

        nextDocUrl = newDocFile.getUrl();
        taskSheet.getRange(nextRowIdx, docLinkCol + 1).setValue(nextDocUrl);
      }
    } catch (e) {}
  }

  // If next doc exists, copy content over
  if (nextDocUrl && nextDocUrl.indexOf('document/d/') !== -1) {
    var nextDocIdMatch = nextDocUrl.match(/[-\w]{25,}/);
    if (nextDocIdMatch) {
      try {
        var nextDoc = DocumentApp.openById(nextDocIdMatch[0]);
        var nextBody = nextDoc.getBody();
        
        // Cleanly wipe the next doc to avoid any duplicate blocks if triggered multiple times
        try {
          nextBody.clear();
          nextBody.appendParagraph('Post: ' + postNo + ' | ' + nextStage + ' Document')
            .setHeading(DocumentApp.ParagraphHeading.HEADING1);
        } catch(clearErr) {}
        
        // Helper function to append a doc's content
        function appendDocContent(docIdToCopy, stageNameToLog) {
          try {
            var copyDoc = DocumentApp.openById(docIdToCopy);
            var copyBody = copyDoc.getBody();
            if (stageNameToLog) {
              nextBody.appendParagraph('\n--- Content inherited from ' + stageNameToLog + ' ---\n').setHeading(DocumentApp.ParagraphHeading.HEADING2);
            }
            var numChildren = copyBody.getNumChildren();
            for (var i = 0; i < numChildren; i++) {
              try {
                var child = copyBody.getChild(i);
                if (child.getType() === DocumentApp.ElementType.PARAGRAPH) {
                  nextBody.appendParagraph(child.copy());
                } else if (child.getType() === DocumentApp.ElementType.LIST_ITEM) {
                  nextBody.appendListItem(child.copy());
                } else if (child.getType() === DocumentApp.ElementType.TABLE) {
                  nextBody.appendTable(child.copy());
                }
              } catch(elemErr) {}
            }
          } catch(err) {}
        }
        
        // 1. Copy the current stage doc
        appendDocContent(currentDocId[0], null); // no inherited header for the immediate current stage
        
        // 2. Iterate backwards through all previous stages and copy their original docs
        for (var p = currentIdx - 1; p >= 0; p--) {
          var prevStageName = stageOrder[p];
          var prevStageNorm = stageOrderNorm[p];
          var prevDocUrl = '';
          
          for (var r = 1; r < data.length; r++) {
            if (data[r][postNoCol] == postNo && normalizeStageName(data[r][stageCol]) === prevStageNorm) {
              prevDocUrl = data[r][docLinkCol] || '';
              break;
            }
          }
          
          if (prevDocUrl && prevDocUrl.indexOf('document/d/') !== -1) {
            var prevDocIdMatch = prevDocUrl.match(/[-\w]{25,}/);
            if (prevDocIdMatch) {
              // Avoid duplicating if the previous stage's content was already embedded by the user
              var currentText = nextBody.getText();
              if (currentText.indexOf('--- Content inherited from ' + prevStageName) === -1) {
                appendDocContent(prevDocIdMatch[0], prevStageName);
              }
            }
          }
        }
        
        nextDoc.saveAndClose();
      } catch (e) {
        var notesCol = headers.indexOf('Notes');
        if (notesCol !== -1 && nextRowIdx !== -1) {
          taskSheet.getRange(nextRowIdx, notesCol + 1).setValue('Error copying history: ' + e.toString());
        }
      }
    }
  }

  // Automatically change next task status to Ready if it was Waiting
  if (nextRowIdx !== -1) {
    var statusCol = headers.indexOf('Status');
    var currentStatus = data[nextRowIdx - 1][statusCol];
    if (currentStatus === 'Waiting' || !currentStatus) {
      taskSheet.getRange(nextRowIdx, statusCol + 1).setValue('Ready');
    }
  }
}

function copyForwardCanvaLink(rowIndex, headers, taskSheet, updates) {
  var data = taskSheet.getDataRange().getValues();
  var row = data[rowIndex - 1];
  var canvaLinkCol = headers.indexOf('CanvaLink');
  var postNoCol = headers.indexOf('PostNo');
  var stageCol = headers.indexOf('Stage');
  
  if (canvaLinkCol === -1) return;

  var currentLink = (updates && updates['CanvaLink'] !== undefined) ? updates['CanvaLink'] : row[canvaLinkCol];
  if (!currentLink) return;

  var postNo = row[postNoCol];
  var stageNorm = normalizeStageName(row[stageCol]);

  // Forward Canva link to downstream stages (or all workflow stages of this post so everyone has access)
  for (var i = 1; i < data.length; i++) {
    if (data[i][postNoCol] == postNo) {
      taskSheet.getRange(i + 1, canvaLinkCol + 1).setValue(currentLink);
    }
  }
}

// ───── DRIVE AUTOMATION: Create folders + docs inside date folder ─────
function createTasksForPost(postNo) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var tasks = ss.getSheetByName(TASKS_SHEET);
  var pipe = ss.getSheetByName(PIPELINE_SHEET).getDataRange().getValues();
  var usersData = ss.getSheetByName(USERS_SHEET).getDataRange().getValues();
  var postsData = ss.getSheetByName(POSTS_SHEET).getDataRange().getValues();
  var existingTasks = tasks.getDataRange().getValues();

  // Check duplicates
  for (var t = 1; t < existingTasks.length; t++) {
    if (existingTasks[t][1] == postNo) {
      return {success: false, message: 'Tasks already exist for ' + postNo};
    }
  }

  // Find the post row to get FolderLink and Date
  var postRow = null;
  for (var p = 1; p < postsData.length; p++) {
    if (postsData[p][0] == postNo) { postRow = postsData[p]; break; }
  }

  var dateStr = '';
  var monthFolderLink = '';
  if (postRow) {
    dateStr = formatDate(postRow[6]);
    monthFolderLink = postRow[21] || postRow[20] || '';
  }

  // ── Drive: find/create date folder and subfolders ──
  var docLinks = {};
  var rawFolderUrl = '';

  if (monthFolderLink && monthFolderLink.indexOf('drive.google.com') !== -1) {
    var match = monthFolderLink.match(/[-\w]{25,}/);
    if (match) {
      try {
        var monthFolder = DriveApp.getFolderById(match[0]);

        // Use existing folder directly (no folder creation)
        var dateFolder = monthFolder;
        var dateFolders = monthFolder.searchFolders("title = '" + dateStr + "' and trashed = false");
        if (dateFolders.hasNext()) {
          dateFolder = dateFolders.next();
        }

        // Find Raw subfolder URL if exists
        var sfSearch = dateFolder.searchFolders("title = 'Raw' and trashed = false");
        if (sfSearch.hasNext()) {
          rawFolderUrl = sfSearch.next().getUrl();
        }

        // Create a single collaborative doc if not exist
        var docName = postNo + ' - Content Doc';
        var docSearch = dateFolder.searchFiles("title = '" + docName + "' and mimeType = 'application/vnd.google-apps.document'");
        if (docSearch.hasNext()) {
          var existingDoc = docSearch.next();
          existingDoc.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT);
          docLinks['Writing'] = existingDoc.getUrl();
        } else {
          var newDoc = DocumentApp.create(docName);
          var newDocFile = DriveApp.getFileById(newDoc.getId());
          newDocFile.moveTo(dateFolder);
          newDocFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT);
          newDoc.getBody().appendParagraph('Post: ' + postNo + ' | Content Document')
            .setHeading(DocumentApp.ParagraphHeading.HEADING1);
          newDoc.saveAndClose();
          docLinks['Writing'] = newDocFile.getUrl();
        }
      } catch (driveErr) {
        // Don't store error string as DocLink - leave empty so app uses backend search
        docLinks['Writing'] = '';
      }
    }
  }

  // ── Round-robin auto-assignment ──
  var userPools = {};
  for (var u = 1; u < usersData.length; u++) {
    var role = usersData[u][2];
    if (!userPools[role]) userPools[role] = [];
    userPools[role].push(usersData[u][0]);
  }

  var assignCounts = {};
  for (var t = 1; t < existingTasks.length; t++) {
    var a = existingTasks[t][3];
    if (a) assignCounts[a] = (assignCounts[a] || 0) + 1;
  }

  // ── Create task rows ──
  for (var i = 1; i < pipe.length; i++) {
    var stage = pipe[i][0];
    var requiredRole = pipe[i][1];
    var assignee = '';

    // ONLY assign the FIRST stage (Writing)
    if (i === 1) {
      var pool = userPools[requiredRole] || [];
      if (pool.length > 0) {
        var minCount = Infinity;
        var picked = pool[0];
        for (var p = 0; p < pool.length; p++) {
          var cnt = assignCounts[pool[p]] || 0;
          if (cnt < minCount) {
            minCount = cnt;
            picked = pool[p];
          }
        }
        assignee = picked;
        assignCounts[picked] = (assignCounts[picked] || 0) + 1;
      }
    }

    var docUrl = docLinks[stage] || '';
    var initialStatus = (i === 1) ? 'Ready' : 'Waiting'; // Only first stage is Ready

    tasks.appendRow([
      postNo + '-' + stage,
      postNo,
      stage,
      assignee,
      initialStatus,
      new Date().toLocaleString(),
      '',
      docUrl
    ]);
  }

  return {success: true, message: 'Tasks created for ' + postNo + ' with Drive folders, docs, and auto-assignment'};
}

// ───── Get photo thumbnails from a Drive folder ─────
function handleGetPhotos(payload) {
  var folderUrl = payload.folderUrl;
  if (!folderUrl) return { success: true, photos: [] };

  var match = folderUrl.match(/[-\w]{25,}/);
  if (!match) return { success: true, photos: [] };

  var photos = [];
  try {
    var folder = DriveApp.getFolderById(match[0]);
    var files = folder.getFiles();
    var count = 0;
    while (files.hasNext() && count < 50) {
      var file = files.next();
      var mime = file.getMimeType();
      if (mime.indexOf('image') !== -1 || mime.indexOf('video') !== -1) {
        var id = file.getId();
        photos.push({
          name: file.getName(),
          mimeType: mime,
          thumbnailUrl: 'https://drive.google.com/thumbnail?id=' + id + '&sz=w400',
          viewUrl: 'https://drive.google.com/file/d/' + id + '/view',
        downloadUrl: 'https://drive.google.com/uc?export=view&id=' + id
        });
        count++;
      }
    }
  } catch (e) {}
  return { success: true, photos: photos };
}

function handleGetMediaFolders(payload) {
  var monthLink = payload.monthLink;
  var dateStr = payload.dateStr;
  var venue = payload.venue || '';
  var postNo = payload.postNo || '';

  // ── Layer 1: GAS server cache (6 hours) ──
  var cache = CacheService.getScriptCache();
  var cacheKey = 'mf_' + (postNo || monthLink.slice(-20)) + '_' + dateStr.replace(/[^a-zA-Z0-9]/g, '') + (venue ? '_' + venue.replace(/[^a-zA-Z0-9]/g, '').slice(0, 10) : '');
  var cached = cache.get(cacheKey);
  if (cached) {
    try {
      var parsed = JSON.parse(cached);
      if (parsed.editedThumbnail) {
        return { success: true, folders: parsed, fromCache: true };
      }
    } catch(e) {}
  }

  var result = { raw: '', selected: '', edited: '', editedThumbnail: '', proofreadDoc: '', crosscheckDoc: '' };

  if (!monthLink || monthLink.indexOf('drive.google.com') === -1) {
    return { success: true, folders: result };
  }

  var match = monthLink.match(/[-\w]{25,}/);
  if (!match) return { success: true, folders: result };

  var monthFolderId = match[0];
  try {
    var dateFolder = DriveApp.getFolderById(monthFolderId);

    if (dateFolder) {
      var sfs = dateFolder.getFolders();
      while (sfs.hasNext()) {
        var sub = sfs.next();
        var subName = sub.getName().toLowerCase();
        if (subName === 'raw') {
          result.raw = sub.getUrl();
        } else if (subName === 'selected') {
          result.selected = sub.getUrl();
        } else if (subName.indexOf('edited') !== -1 || subName === 'selected (edited)') {
          result.edited = sub.getUrl();

          // Check if 'Edited (Thumbnail)' or 'Edited Thumbnail' exists inside Selected (Edited) without duplicate
          var thumbSearch = sub.getFolders();
          var foundThumb = null;
          while (thumbSearch.hasNext()) {
            var tf = thumbSearch.next();
            var tfNorm = tf.getName().toLowerCase().replace(/[\s\-_()]/g, '');
            if (tfNorm === 'editedthumbnail' || tfNorm === 'editedthumbnails' || (tfNorm.indexOf('edited') !== -1 && tfNorm.indexOf('thumb') !== -1)) {
              foundThumb = tf;
              break;
            }
          }
          if (!foundThumb) {
            var thumbSearch2 = sub.getFolders();
            while (thumbSearch2.hasNext()) {
              var tf2 = thumbSearch2.next();
              if (tf2.getName().toLowerCase().indexOf('thumb') !== -1) {
                foundThumb = tf2;
                break;
              }
            }
          }
          if (foundThumb) {
            result.editedThumbnail = foundThumb.getUrl();
          } else {
            // Not found in Selected (Edited): create it cleanly without duplicate
            try {
              var newThumb = sub.createFolder('Edited (Thumbnail)');
              newThumb.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT);
              result.editedThumbnail = newThumb.getUrl();
            } catch(crErr) {}
          }
        }
      }
    }

    // Look up proofreading and text crosscheck docs for this post
    if (postNo) {
      try {
        var ss = SpreadsheetApp.getActiveSpreadsheet();
        var tSheet = ss.getSheetByName(TASKS_SHEET);
        if (tSheet) {
          var tData = tSheet.getDataRange().getValues();
          var tHeaders = tData[0];
          var pNoCol = tHeaders.indexOf('PostNo');
          var stgCol = tHeaders.indexOf('Stage');
          var docCol = tHeaders.indexOf('DocLink');
          for (var i = 1; i < tData.length; i++) {
            if (tData[i][pNoCol] == postNo) {
              var stgNorm = normalizeStageName(tData[i][stgCol]);
              if (stgNorm === 'proofreading') {
                result.proofreadDoc = tData[i][docCol] || '';
              } else if (stgNorm === 'textcrosscheck' || stgNorm === 'crosscheck') {
                result.crosscheckDoc = tData[i][docCol] || '';
              }
            }
          }
        }
      } catch (docErr) {}
    }

    // Cache the result for 6 hours (21600 sec)
    if (result.raw || result.selected || result.edited) {
      try { cache.put(cacheKey, JSON.stringify(result), 21600); } catch(cErr) {}
    }
  } catch (e) {}

  return { success: true, folders: result };
}

function handleGetPhotos(payload) {
  var folderUrl = payload.folderUrl;
  if (!folderUrl) return { success: true, photos: [] };

  var match = folderUrl.match(/[-\w]{25,}/);
  if (!match) return { success: true, photos: [] };

  var photos = [];
  try {
    var folder = DriveApp.getFolderById(match[0]);
    var files = folder.getFiles();
    var count = 0;
    while (files.hasNext() && count < 50) {
      var file = files.next();
      var mime = file.getMimeType();
      if (mime.indexOf('image') !== -1 || mime.indexOf('video') !== -1) {
        var id = file.getId();
        photos.push({
          name: file.getName(),
          mimeType: mime,
          thumbnailUrl: 'https://drive.google.com/thumbnail?id=' + id + '&sz=w400',
          viewUrl: 'https://drive.google.com/file/d/' + id + '/view',
        downloadUrl: 'https://drive.google.com/uc?export=view&id=' + id
        });
        count++;
      }
    }
  } catch (e) {}
  return { success: true, photos: photos };
}

// ───── NEW API HANDLERS (Phase 2) ─────

function handleGetUsers() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var usersData = ss.getSheetByName(USERS_SHEET).getDataRange().getValues();
  var tasksData = ss.getSheetByName(TASKS_SHEET).getDataRange().getValues();

  // Count active tasks per user
  var activeCounts = {};
  for (var t = 1; t < tasksData.length; t++) {
    var assignee = tasksData[t][3];
    var status = tasksData[t][4];
    if (assignee && status !== 'Done') {
      activeCounts[assignee] = (activeCounts[assignee] || 0) + 1;
    }
  }

  var users = [];
  for (var i = 1; i < usersData.length; i++) {
    var email = usersData[i][0] || '';
    var name = usersData[i][1] || '';
    var role = usersData[i][2] || '';
    var activeTasks = activeCounts[email] || 0;

    if (email) {
      users.push({
        email: email,
        username: email,
        name: name || email,
        role: role,
        status: activeTasks > 0 ? 'Engaged' : 'Available',
        activeTasks: activeTasks
      });
    }
  }
  return { success: true, users: users };
}

function handleGetBranchSPOCs() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(BRANCH_SPOC_SHEET);
  if (!sheet || sheet.getLastRow() < 2) return { success: true, spocs: [] };

  var data = sheet.getDataRange().getValues();
  var spocs = [];
  for (var i = 1; i < data.length; i++) {
    spocs.push({
      branch: data[i][0] || '',
      spocName: data[i][1] || '',
      spocEmail: data[i][2] || ''
    });
  }
  return { success: true, spocs: spocs };
}

function handleUpdateBranchSPOC(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(BRANCH_SPOC_SHEET);
  var data = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    if (data[i][0] === payload.branch) {
      sheet.getRange(i + 1, 2).setValue(payload.spocName);
      sheet.getRange(i + 1, 3).setValue(payload.spocEmail);
      return { success: true, message: 'SPOC updated for ' + payload.branch };
    }
  }
  // New branch entry
  sheet.appendRow([payload.branch, payload.spocName, payload.spocEmail]);
  return { success: true, message: 'SPOC added for ' + payload.branch };
}

function handleUpdateBeneficiaries(payload) {
  var postNo = (payload.postNo || '').toString().trim();
  var state = (payload.state || '').toString().trim();
  var branch = (payload.branch || '').toString().trim();
  var venue = (payload.venue || '').toString().trim();
  var dateStr = (payload.date || '').toString().trim();
  var prevMale = safeNum(payload.prevMale);
  var prevFemale = safeNum(payload.prevFemale);
  var prevChildren = safeNum(payload.prevChildren);

  var newMale = safeNum(payload.male);
  var newFemale = safeNum(payload.female);
  var newChildren = safeNum(payload.children);

  try {
    var sourceSS = SpreadsheetApp.openById(SOURCE_RESPONSES_SPREADSHEET_ID);
    var sourceSheet = sourceSS.getSheetByName(SOURCE_RESPONSES_TAB);
    if (!sourceSheet) {
      return { success: false, message: 'Source sheet "' + SOURCE_RESPONSES_TAB + '" not found in spreadsheet.' };
    }

    var data = sourceSheet.getDataRange().getValues();
    if (data.length < 2) {
      return { success: false, message: 'Source sheet is empty.' };
    }

    var header = data[0];
    
    // Exact column indices (0-based) based on BODH Responses sheet:
    // C = State (index 2, Col 3)
    // D to W = Branches (indices 3 to 22, Cols 4 to 23)
    // X = Venue (index 23, Col 24)
    // Z = Date (index 25, Col 26)
    // AB = Male (index 27, Col 28)
    // AC = Female (index 28, Col 29)
    // AD = Children (index 29, Col 30)
    var stateCol = 2;
    var venueCol = 23;
    var dateCol = 25;
    var maleCol = 27;     // Column AB (1-based: 28)
    var femaleCol = 28;   // Column AC (1-based: 29)
    var childrenCol = 29; // Column AD (1-based: 30)

    // Verify and adjust column indices specifically around columns 20 to 35
    for (var c = 20; c < Math.min(header.length, 35); c++) {
      var hText = (header[c] || '').toString().toLowerCase();
      if (hText.indexOf('स्थान') !== -1 || hText.indexOf('venue') !== -1) {
        venueCol = c;
      } else if (hText.indexOf('दिनांक') !== -1 || hText.indexOf('date') !== -1) {
        dateCol = c;
      } else if (hText.indexOf('महिलाएं') !== -1 || hText.indexOf('female') !== -1) {
        femaleCol = c;
      } else if (hText.indexOf('पुरुष') !== -1 || (hText.indexOf('male') !== -1 && hText.indexOf('female') === -1)) {
        maleCol = c;
      } else if (hText.indexOf('बच्चे') !== -1 || hText.indexOf('children') !== -1) {
        childrenCol = c;
      }
    }

    function cleanString(s) {
      if (!s) return '';
      return s.toString().toLowerCase().replace(/[\s\r\n\t,.\-_/\\()|:;]/g, '');
    }

    function parseDateObj(val) {
      if (!val) return null;
      if (val instanceof Date) {
        if (isNaN(val.getTime())) return null;
        return { y: val.getFullYear(), m: val.getMonth() + 1, d: val.getDate() };
      }
      var str = val.toString().trim();
      var parts = str.match(/(\d{1,4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,4})/);
      if (parts) {
        var p1 = parseInt(parts[1], 10);
        var p2 = parseInt(parts[2], 10);
        var p3 = parseInt(parts[3], 10);
        if (p1 > 1000) {
          return { y: p1, m: p2, d: p3 };
        } else if (p3 > 1000) {
          if (p1 > 12) {
            return { y: p3, m: p2, d: p1 };
          } else {
            return { y: p3, m: p1, d: p2 };
          }
        }
      }
      var dt = new Date(str);
      if (!isNaN(dt.getTime()) && dt.getFullYear() > 1990) {
        return { y: dt.getFullYear(), m: dt.getMonth() + 1, d: dt.getDate() };
      }
      return null;
    }

    function dateEquals(v1, v2) {
      var d1 = parseDateObj(v1);
      var d2 = parseDateObj(v2);
      if (!d1 || !d2) return false;
      return d1.y === d2.y && ((d1.m === d2.m && d1.d === d2.d) || (d1.m === d2.d && d1.d === d2.m));
    }

    var cleanTargetVenue = cleanString(venue);
    var cleanTargetState = cleanString(state);
    var cleanTargetBranch = cleanString(branch);

    var bestRowIndex = -1;
    var bestScore = 0;

    for (var r = 1; r < data.length; r++) {
      var row = data[r];
      var score = 0;

      // 1. Date match (30 pts)
      if (dateStr && row[dateCol]) {
        if (dateEquals(row[dateCol], dateStr)) {
          score += 30;
        }
      }

      // 2. Venue match (30 pts)
      var rowVenue = cleanString(row[venueCol]);
      if (cleanTargetVenue && rowVenue) {
        if (rowVenue === cleanTargetVenue) {
          score += 30;
        } else if (rowVenue.indexOf(cleanTargetVenue) !== -1 || cleanTargetVenue.indexOf(rowVenue) !== -1) {
          score += 25;
        } else {
          var vSub = cleanTargetVenue.substring(0, Math.min(12, cleanTargetVenue.length));
          if (vSub.length >= 6 && rowVenue.indexOf(vSub) !== -1) {
            score += 15;
          }
        }
      }

      // 3. Beneficiaries match (up to 30 pts)
      var rowM = safeNum(row[maleCol]);
      var rowF = safeNum(row[femaleCol]);
      var rowC = safeNum(row[childrenCol]);

      var benMatches = 0;
      if (rowM === prevMale) benMatches += 10;
      if (rowF === prevFemale) benMatches += 10;
      if (rowC === prevChildren) benMatches += 10;
      score += benMatches;

      // 4. State match (10 pts)
      var rowState = cleanString(row[stateCol]);
      if (cleanTargetState && rowState && (rowState === cleanTargetState || rowState.indexOf(cleanTargetState) !== -1)) {
        score += 10;
      }

      // 5. Branch match (15 pts) - check across columns D to W (index 3 to 22)
      if (cleanTargetBranch) {
        for (var b = 3; b <= 22 && b < row.length; b++) {
          var bVal = cleanString(row[b]);
          if (bVal && (bVal === cleanTargetBranch || bVal.indexOf(cleanTargetBranch) !== -1 || cleanTargetBranch.indexOf(bVal) !== -1)) {
            score += 15;
            break;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestRowIndex = r;
      }
    }

    if (bestRowIndex !== -1 && bestScore >= 40) {
      // 1. Write new values to source sheet (Columns AB=28, AC=29, AD=30)
      sourceSheet.getRange(bestRowIndex + 1, maleCol + 1).setValue(newMale);
      sourceSheet.getRange(bestRowIndex + 1, femaleCol + 1).setValue(newFemale);
      sourceSheet.getRange(bestRowIndex + 1, childrenCol + 1).setValue(newChildren);
      SpreadsheetApp.flush();

      // Invalidate script cache
      try {
        CacheService.getScriptCache().remove('all_posts');
      } catch(ce) {}

      var colABLetter = 'AB (Col ' + (maleCol + 1) + ')';
      var colACLetter = 'AC (Col ' + (femaleCol + 1) + ')';
      var colADLetter = 'AD (Col ' + (childrenCol + 1) + ')';

      return {
        success: true,
        message: 'Beneficiaries successfully updated in BODH Responses sheet at row ' + (bestRowIndex + 1) + ' (Cols: ' + colABLetter + ', ' + colACLetter + ', ' + colADLetter + '). New counts: 👨 ' + newMale + ', 👩 ' + newFemale + ', 🧒 ' + newChildren + '.',
        matchedRow: bestRowIndex + 1,
        matchScore: bestScore,
        maleCol: maleCol + 1,
        femaleCol: femaleCol + 1,
        childrenCol: childrenCol + 1
      };
    } else {
      return {
        success: false,
        message: 'Could not find a confident matching row in BODH Responses (Best score: ' + bestScore + ', required >= 40).'
      };
    }
  } catch (err) {
    return {
      success: false,
      message: 'Error updating beneficiaries in source sheet: ' + err.toString()
    };
  }
}

function handleUpdatePostMeta(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(POSTS_SHEET);
  var data = sheet.getDataRange().getValues();
  var postNo = payload.postNo;

  for (var i = 1; i < data.length; i++) {
    if (data[i][0] == postNo) {
      var rowIdx = i + 1;
      if (payload.publishPlatform !== undefined) sheet.getRange(rowIdx, 36).setValue(payload.publishPlatform);
      if (payload.postType !== undefined) sheet.getRange(rowIdx, 37).setValue(payload.postType);
      if (payload.groupId !== undefined) sheet.getRange(rowIdx, 38).setValue(payload.groupId);
      if (payload.mediaMode !== undefined) sheet.getRange(rowIdx, 39).setValue(payload.mediaMode);
      if (payload.description !== undefined) sheet.getRange(rowIdx, 40).setValue(payload.description);
      if (payload.activityType !== undefined) sheet.getRange(rowIdx, 23).setValue(payload.activityType);
      if (payload.postStatus !== undefined) sheet.getRange(rowIdx, 41).setValue(payload.postStatus);
      try { CacheService.getScriptCache().remove('all_posts'); } catch(e) {}
      return { success: true, message: 'Post metadata updated' };
    }
  }
  return { success: false, message: 'Post not found' };
}

function handleGroupPosts(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(POSTS_SHEET);
  var data = sheet.getDataRange().getValues();
  var postNos = payload.postNos; // Array of post numbers
  var groupId = payload.groupId;

  var updated = 0;
  for (var i = 1; i < data.length; i++) {
    if (postNos.indexOf(data[i][0].toString()) !== -1 || postNos.indexOf(Number(data[i][0])) !== -1) {
      sheet.getRange(i + 1, 38).setValue(groupId); // Column AL (38)
      // If post was marked 'Data Unavailable', reset PostStatus so it becomes clean/active under group
      var curStatus = (data[i][40] || '').toString().trim().toLowerCase();
      if (curStatus === 'data unavailable' || curStatus === 'dataunavailable') {
        sheet.getRange(i + 1, 41).setValue(''); // Column AO (41) PostStatus
      }
      updated++;
    }
  }
  try { CacheService.getScriptCache().remove('all_posts'); } catch(e) {}
  return { success: true, message: updated + ' posts grouped under ' + groupId };
}

function handleUngroupPost(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(POSTS_SHEET);
  var data = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    if (data[i][0] == payload.postNo) {
      sheet.getRange(i + 1, 38).setValue(''); // Clear GroupID
      try { CacheService.getScriptCache().remove('all_posts'); } catch(e) {}
      return { success: true, message: 'Post ungrouped' };
    }
  }
  return { success: false, message: 'Post not found' };
}

function handleRenameGroup(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var postsSheet = ss.getSheetByName(POSTS_SHEET);
  var tasksSheet = ss.getSheetByName(TASKS_SHEET);
  
  var oldGroupId = (payload.oldGroupId || '').toString().trim();
  var newGroupId = (payload.newGroupId || '').toString().trim();
  
  if (!oldGroupId || !newGroupId) {
    return { success: false, message: 'Both oldGroupId and newGroupId are required' };
  }
  
  // 1. Update GroupID in POSTS_SHEET (col 38)
  var postsData = postsSheet.getDataRange().getValues();
  var postsUpdated = 0;
  for (var i = 1; i < postsData.length; i++) {
    var g = postsData[i][37] ? postsData[i][37].toString().trim() : '';
    if (g === oldGroupId) {
      postsSheet.getRange(i + 1, 38).setValue(newGroupId);
      postsUpdated++;
    }
  }
  
  // 2. Update PostNo in TASKS_SHEET if tasks were created under oldGroupId
  if (tasksSheet) {
    var tasksData = tasksSheet.getDataRange().getValues();
    for (var t = 1; t < tasksData.length; t++) {
      var tPostNo = tasksData[t][1] ? tasksData[t][1].toString().trim() : '';
      if (tPostNo === oldGroupId) {
        tasksSheet.getRange(t + 1, 2).setValue(newGroupId);
        // Also update TaskID prefix
        var curTaskId = tasksData[t][0] ? tasksData[t][0].toString() : '';
        if (curTaskId.indexOf(oldGroupId + '-') === 0) {
          var newTaskId = newGroupId + curTaskId.substring(oldGroupId.length);
          tasksSheet.getRange(t + 1, 1).setValue(newTaskId);
        }
      }
    }
  }
  
  try { CacheService.getScriptCache().remove('all_posts'); } catch(e) {}
  return { success: true, message: 'Group renamed from "' + oldGroupId + '" to "' + newGroupId + '"' };
}

function handleDeleteWorkflow(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var tasksSheet = ss.getSheetByName(TASKS_SHEET);
  var postsSheet = ss.getSheetByName(POSTS_SHEET);
  
  var postNo = (payload.postNo || '').toString().trim();
  var isCombined = payload.isCombined === true;
  
  if (!postNo) return { success: false, message: 'postNo required' };
  
  // 1. Delete all tasks for this postNo or groupId from TASKS_SHEET
  var deletedCount = 0;
  if (tasksSheet) {
    var tasksData = tasksSheet.getDataRange().getValues();
    for (var t = tasksData.length - 1; t >= 1; t--) {
      var taskPostNo = tasksData[t][1] ? tasksData[t][1].toString().trim() : '';
      if (taskPostNo === postNo) {
        tasksSheet.deleteRow(t + 1);
        deletedCount++;
      }
    }
  }
  
  // 2. If combined, clear GroupID (col 38 / AL) for all posts that had this groupId
  if (isCombined && postsSheet) {
    var postsData = postsSheet.getDataRange().getValues();
    for (var p = 1; p < postsData.length; p++) {
      var currentGroupId = postsData[p][37] ? postsData[p][37].toString().trim() : '';
      if (currentGroupId === postNo) {
        postsSheet.getRange(p + 1, 38).setValue('');
      }
    }
  }
  
  return { 
    success: true, 
    message: 'Workflow deleted (' + deletedCount + ' tasks removed). Post is now inactive.' 
  };
}

function createTasksForPostV2(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var tasks = ss.getSheetByName(TASKS_SHEET);
  var pipe = ss.getSheetByName(PIPELINE_SHEET).getDataRange().getValues();
  var postsData = ss.getSheetByName(POSTS_SHEET).getDataRange().getValues();
  var existingTasks = tasks.getDataRange().getValues();
  var taskHeaders = existingTasks[0];

  var postNo = payload.postNo;
  var assignees = payload.assignees || {};
  var dueDates = payload.dueDates || {};
  var description = payload.description || '';
  var publishPlatform = payload.publishPlatform || '';
  var postType = payload.postType || 'Individual';
  var mediaMode = payload.mediaMode || 'Photos';

  // Map existing tasks for upsert logic
  var isUpdate = false;
  var existingTaskRows = {};
  for (var t = 1; t < existingTasks.length; t++) {
    if (existingTasks[t][1] == postNo) {
      isUpdate = true;
      var st = normalizeStageName(existingTasks[t][2]);
      existingTaskRows[st] = t + 1;
    }
  }

  // Delete obsolete Photos Selection tasks from sheet for this post
  if (isUpdate) {
    for (var t = existingTasks.length - 1; t >= 1; t--) {
      if (existingTasks[t][1] == postNo) {
        var stNorm = normalizeStageName(existingTasks[t][2]);
        if (stNorm === 'photosselection' || stNorm === 'photoselection') {
          tasks.deleteRow(t + 1);
          delete existingTaskRows[stNorm];
        }
      }
    }
    existingTasks = tasks.getDataRange().getValues();
  }

  // If not Instagram Video, delete thumbnail tasks from sheet when updating
  var pubLower = (publishPlatform || '').toLowerCase();
  var modLower = (mediaMode || '').toLowerCase();
  var isInstaVideo = pubLower.indexOf('insta') !== -1 && modLower.indexOf('video') !== -1;
  if (!isInstaVideo && isUpdate) {
    var thumbStages = ['thumbnailselection', 'thumbnailprocessing', 'thumbnailcrosschecking', 'thumbnailcrosscheck'];
    for (var t = existingTasks.length - 1; t >= 1; t--) {
      if (existingTasks[t][1] == postNo) {
        var stNorm = normalizeStageName(existingTasks[t][2]);
        if (thumbStages.indexOf(stNorm) !== -1) {
          tasks.deleteRow(t + 1);
          delete existingTaskRows[stNorm];
        }
      }
    }
    // Re-fetch existing tasks after row deletions
    existingTasks = tasks.getDataRange().getValues();
  }

  // Delete Video Editing or Photo Editing if current Media Mode does not include it
  if (isUpdate) {
    for (var t = existingTasks.length - 1; t >= 1; t--) {
      if (existingTasks[t][1] == postNo) {
        var stNorm = normalizeStageName(existingTasks[t][2]);
        // If mediaMode is Video (does not contain 'photo'), delete Photo Editing
        if (modLower.indexOf('photo') === -1 && stNorm === 'photoediting') {
          tasks.deleteRow(t + 1);
          delete existingTaskRows[stNorm];
        }
        // If mediaMode is Photos (does not contain 'video'), delete Video Editing
        if (modLower.indexOf('video') === -1 && stNorm === 'videoediting') {
          tasks.deleteRow(t + 1);
          delete existingTaskRows[stNorm];
        }
      }
    }
    // Re-fetch and re-index existing tasks after row deletions
    existingTasks = tasks.getDataRange().getValues();
    existingTaskRows = {};
    for (var t = 1; t < existingTasks.length; t++) {
      if (existingTasks[t][1] == postNo) {
        var st = normalizeStageName(existingTasks[t][2]);
        existingTaskRows[st] = t + 1;
      }
    }
  }

  // Find all posts in the group (or just the single post)
  var groupPosts = [];
  var groupId = null;

  for (var p = 1; p < postsData.length; p++) {
    if (postsData[p][0] == postNo || postsData[p][37] == postNo) {
      if (postsData[p][37]) {
        groupId = postsData[p][37];
      }
      break;
    }
  }

  if (groupId) {
    for (var p = 1; p < postsData.length; p++) {
      if (postsData[p][37] == groupId || postsData[p][0] == groupId) {
        groupPosts.push(postsData[p]);
      }
    }
  } else {
    for (var p = 1; p < postsData.length; p++) {
      if (postsData[p][0] == postNo) {
        groupPosts.push(postsData[p]);
        break;
      }
    }
  }

  var postsSheet = ss.getSheetByName(POSTS_SHEET);
  postsSheet.getRange(2, 36).setValue('PublishPlatform');
  postsSheet.getRange(2, 37).setValue('PostType');
  postsSheet.getRange(2, 38).setValue('GroupID');
  postsSheet.getRange(2, 39).setValue('MediaMode');
  postsSheet.getRange(2, 40).setValue('Description');
  postsSheet.getRange(2, 41).setValue('PostStatus');

  // Update post metadata for all posts in group
  for (var gp = 0; gp < groupPosts.length; gp++) {
    var pNo = groupPosts[gp][0];
    for (var i = 1; i < postsData.length; i++) {
      if (postsData[i][0] == pNo) {
        var rIdx = i + 1;
        var postsSheet = ss.getSheetByName(POSTS_SHEET);
        if (publishPlatform) postsSheet.getRange(rIdx, 36).setValue(publishPlatform);
        if (postType) postsSheet.getRange(rIdx, 37).setValue(postType);
        if (mediaMode) postsSheet.getRange(rIdx, 39).setValue(mediaMode);
        if (description) postsSheet.getRange(rIdx, 40).setValue(description);
        break;
      }
    }
  }

  // ── Drive: create folders + docs for EACH post in the group ──
  var docLinks = {};

  if (groupPosts.length > 0) {
    // First, count occurrences of each date in the group
    var dateCounts = {};
    for (var i = 0; i < groupPosts.length; i++) {
      var dStr = formatDate(groupPosts[i][6]);
      dateCounts[dStr] = (dateCounts[dStr] || 0) + 1;
    }

    for (var gp = 0; gp < groupPosts.length; gp++) {
      var currPost = groupPosts[gp];
      var currMonthLink = currPost[21] || currPost[20] || '';

      if (currMonthLink && currMonthLink.indexOf('drive.google.com') !== -1) {
        var match = currMonthLink.match(/[-\w]{25,}/);
        if (match) {
          try {
            var dateFolder = DriveApp.getFolderById(match[0]);
            // No folder creation: reporting form already creates folders!

            // Create Google Docs for specific stages ONLY in the first post's folder
            if (gp === 0) {
              var docStages = ['Writing', 'Editing', 'Proofreading', 'Text Crosscheck'];
              for (var d = 0; d < docStages.length; d++) {
                var docStageName = docStages[d];
                var docName = currPost[0] + ' - ' + docStageName;
                var docFound = false;
                var existingFiles = dateFolder.getFiles();
                var foundDocUrl = '';
                var targetHeadingText = 'Post: ' + currPost[0] + ' | ' + docStageName + ' Document';

                while (existingFiles.hasNext()) {
                  var ef = existingFiles.next();
                  if (ef.getName().toLowerCase() === docName.toLowerCase() ||
                      ef.getName().toLowerCase() === (docName + '.docx').toLowerCase() ||
                      ef.getName().toLowerCase() === docStageName.toLowerCase() ||
                      (docStageName === 'Text Crosscheck' && (ef.getName().toLowerCase() === (currPost[0] + ' - crosscheck').toLowerCase() || ef.getName().toLowerCase() === 'crosscheck'))) {
                    foundDocUrl = ef.getUrl();
                    docFound = true;

                    // Inspect existing doc and ensure heading exists
                    try {
                      var efDoc = DocumentApp.openById(ef.getId());
                      var efBody = efDoc.getBody();
                      var firstPara = efBody.getNumChildren() > 0 ? efBody.getChild(0) : null;
                      var firstText = firstPara ? firstPara.asText().getText().trim() : '';

                      // If empty or doesn't have the post/stage heading, insert it at top
                      if (!firstText || firstText.indexOf('Post: ' + currPost[0]) === -1) {
                        var insertedHeader = efBody.insertParagraph(0, targetHeadingText);
                        insertedHeader.setHeading(DocumentApp.ParagraphHeading.HEADING1);
                        efDoc.saveAndClose();
                      }
                    } catch (inspectErr) {}

                    break;
                  }
                }

                if (!docFound) {
                  try {
                    var newDoc = DocumentApp.create(docName);
                    var newDocFile = DriveApp.getFileById(newDoc.getId());
                    newDocFile.moveTo(dateFolder);
                    newDocFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT);
                    var body = newDoc.getBody();

                    body.appendParagraph(targetHeadingText).setHeading(DocumentApp.ParagraphHeading.HEADING1);
                    newDoc.saveAndClose();
                    foundDocUrl = newDocFile.getUrl();
                  } catch (docErr) {
                    foundDocUrl = '';
                  }
                }
                
                docLinks[normalizeStageName(docStageName)] = foundDocUrl;
              }
            }
          } catch (driveErr) {
            // Drive failed for this specific post, continue to next
          }
        }
      }
    }
  }
  
  // Find column indexes for new headers
  var allottedDateCol = taskHeaders.indexOf('AllottedDate');
  var dueDateCol = taskHeaders.indexOf('DueDate');
  var notesCol = taskHeaders.indexOf('Notes');
  var canvaLinkCol = taskHeaders.indexOf('CanvaLink');
  
  // ── Create task rows with admin-specified assignees ──
  var skipStages = ['photosselection', 'photoselection'];
  var pubLower = (publishPlatform || '').toLowerCase();
  var modLower = (mediaMode || '').toLowerCase();
  
  if (pubLower.indexOf('insta') === -1 || modLower.indexOf('video') === -1) {
    skipStages.push('thumbnailselection', 'thumbnailprocessing', 'thumbnailcrosschecking', 'thumbnailcrosscheck');
  }
  if (modLower.indexOf('video') === -1) {
    skipStages.push('videoediting');
  }
  if (modLower.indexOf('photo') === -1) {
    skipStages.push('photoediting');
  }

  for (var i = 1; i < pipe.length; i++) {
    var stage = pipe[i][0];
    var depOn = pipe[i][2] || '';
    
    var normalizedStage = normalizeStageName(stage);
    if (skipStages.indexOf(normalizedStage) !== -1) continue;
    
    var assignee = '';
    for (var k in assignees) {
      if (normalizeStageName(k) === normalizedStage) { assignee = assignees[k]; break; }
    }
    
    var docUrl = '';
    for (var k in docLinks) {
      if (normalizeStageName(k) === normalizedStage) { docUrl = docLinks[k]; break; }
    }
    
    var initialStatus = 'Waiting';
    if (!depOn || depOn.toString().trim() === '') {
      initialStatus = assignee ? 'Ready' : 'Waiting';
    }
    
    var allottedDate = assignee ? new Date().toLocaleString() : '';
    
    var dueDate = '';
    for (var k in dueDates) {
      if (normalizeStageName(k) === normalizedStage) { dueDate = dueDates[k]; break; }
    }
    if (dueDate) {
      dueDate = formatDate(dueDate);
    } else {
      var defaultOffsetDays = {
        'writing': 3,
        'editing': 6,
        'proofreading': 8,
        'textcrosscheck': 9,
        'crosscheck': 9,
        'readytopost': 10,
        'photosclean': 15,
        'thumbnailselection': 2,
        'thumbnailprocessing': 4,
        'thumbnailcrosschecking': 6,
        'photoediting': 5,
        'videoediting': 5,
        'mediacrosscheck': 6,
        'mediafinalcrosscheck': 9,
        'mediafinalcrosschecking': 9
      };
      var offset = defaultOffsetDays[normalizedStage];
      if (offset !== undefined) {
        var d = new Date();
        d.setDate(d.getDate() + offset);
        dueDate = formatDate(d);
      }
    }
    
    var existingRowIdx = existingTaskRows[normalizedStage];

    if (existingRowIdx) {
      // Update existing task
      var assigneeCol = taskHeaders.indexOf('Assignee');
      var docLinkCol = taskHeaders.indexOf('DocLink');
      
      if (assignee && assigneeCol !== -1) {
        tasks.getRange(existingRowIdx, assigneeCol + 1).setValue(assignee);
        if (allottedDateCol !== -1) {
          tasks.getRange(existingRowIdx, allottedDateCol + 1).setValue(new Date().toLocaleString());
        }
      }
      if (dueDate && dueDateCol !== -1) {
        tasks.getRange(existingRowIdx, dueDateCol + 1).setValue(dueDate);
      }
      if (docUrl && docLinkCol !== -1) {
        var existingDocUrl = existingTasks[existingRowIdx - 1][docLinkCol];
        if (!existingDocUrl) {
          tasks.getRange(existingRowIdx, docLinkCol + 1).setValue(docUrl);
        }
      }
    } else {
      // Append new task
      var rowData = [
        postNo + '-' + stage,
        postNo,
        stage,
        assignee,
        initialStatus,
        new Date().toLocaleString(),
        '',
        docUrl
      ];
      
      // Extend row to include new columns
      if (allottedDateCol !== -1) {
        while (rowData.length <= allottedDateCol) rowData.push('');
        rowData[allottedDateCol] = allottedDate;
      }
      if (dueDateCol !== -1) {
        while (rowData.length <= dueDateCol) rowData.push('');
        rowData[dueDateCol] = dueDate;
      }
      if (notesCol !== -1) {
        while (rowData.length <= notesCol) rowData.push('');
        rowData[notesCol] = '';
      }
      if (canvaLinkCol !== -1) {
        while (rowData.length <= canvaLinkCol) rowData.push('');
        rowData[canvaLinkCol] = '';
      }
      
      tasks.appendRow(rowData);
    }
  }
  
  var msg = isUpdate ? 'Tasks updated for ' + postNo : 'Tasks created for ' + postNo + ' with assignees, folders, and docs';
  return {success: true, message: msg};
}

function copyThumbnailFile(postNo) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var postsSheet = ss.getSheetByName(POSTS_SHEET);
  var postsData = postsSheet.getDataRange().getValues();
  var postRow = null;
  
  for (var p = 1; p < postsData.length; p++) {
    if (postsData[p][0] == postNo) {
      postRow = postsData[p];
      break;
    }
  }
  if (!postRow) return;

  var dateStr = formatDate(postRow[6]);
  var photosLink = postRow[20] || '';
  var videosLink = postRow[21] || '';
  
  var linksToTry = [photosLink, videosLink];
  
  for (var i = 0; i < linksToTry.length; i++) {
    var link = linksToTry[i];
    if (!link || link.indexOf('drive.google.com') === -1) continue;
    
    var match = link.match(/[-\w]{25,}/);
    if (!match) continue;
    
    try {
      var dateFolder = DriveApp.getFolderById(match[0]);
      
      var rawFolder = null;
      var editedFolder = null;
      
      var sfs = dateFolder.getFolders();
      while (sfs.hasNext()) {
        var sub = sfs.next();
        var subName = sub.getName().toLowerCase();
        if (subName === 'raw') {
          rawFolder = sub;
        } else if (subName.indexOf('edited') !== -1 || subName === 'selected (edited)') {
          editedFolder = sub;
        }
      }
      
      if (rawFolder && editedFolder) {
        var targetThumbFolder = null;
        
        // 1. Look for 'Photos' inside 'Raw'
        var photosFolders = rawFolder.searchFolders("title = 'Photos' or title = 'photos'");
        if (photosFolders.hasNext()) {
          var photosFolder = photosFolders.next();
          // Look for 'Thumbnail' inside 'Photos'
          var thumbFolders = photosFolder.searchFolders("title contains 'Thumbnail' or title contains 'thumbnail'");
          if (thumbFolders.hasNext()) {
            targetThumbFolder = thumbFolders.next();
          }
        }
        
        // 2. Fallback: Look directly in 'Raw' just in case
        if (!targetThumbFolder) {
          var directThumb = rawFolder.searchFolders("title contains 'Thumbnail' or title contains 'thumbnail'");
          if (directThumb.hasNext()) targetThumbFolder = directThumb.next();
        }
        
        if (targetThumbFolder) {
          var files = targetThumbFolder.getFiles();
          while (files.hasNext()) {
            var file = files.next();
            var existingIter = editedFolder.getFilesByName(file.getName());
            if (!existingIter.hasNext()) {
              file.makeCopy(file.getName(), editedFolder);
            }
          }
        }
      }
    } catch(e) {
      // Ignore Drive errors
    }
  }
}

function handleReverseTask(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var taskSheet = ss.getSheetByName(TASKS_SHEET);
  var pipeSheet = ss.getSheetByName(PIPELINE_SHEET);
  var pipe = pipeSheet.getDataRange().getValues();
  var data = taskSheet.getDataRange().getValues();
  var headers = data[0];
  
  var postNo = payload.postNo;
  var currentStage = payload.currentStage;
  var reason = payload.reason || '';
  var targetStage = payload.targetStage;
  
  var stageCol = headers.indexOf('Stage');
  var postNoCol = headers.indexOf('PostNo');
  var statusCol = headers.indexOf('Status');
  var notesCol = headers.indexOf('Notes');
  var completedAtCol = headers.indexOf('CompletedAt');
  
  var currentNorm = normalizeStageName(currentStage);
  
  if (!targetStage) {
    if (currentNorm === 'thumbnailcrosschecking' || currentNorm === 'thumbnailcrosscheck') {
      targetStage = 'Thumbnail Processing';
    } else if (currentNorm === 'thumbnailprocessing') {
      targetStage = 'Thumbnail Selection';
    } else if (currentNorm === 'mediacrosscheck') {
      var hasVideoEdit = false;
      for (var r = 1; r < data.length; r++) {
        if (data[r][postNoCol] == postNo && normalizeStageName(data[r][stageCol]) === 'videoediting') {
          hasVideoEdit = true;
          break;
        }
      }
      targetStage = hasVideoEdit ? 'Video Editing' : 'Photo Editing';
    } else if (currentNorm === 'mediafinalcrosscheck' || currentNorm === 'mediafinalcrosschecking') {
      targetStage = 'Proofreading';
    } else if (currentNorm === 'photosclean') {
      targetStage = 'Ready to Post';
    } else if (currentNorm === 'editing') {
      targetStage = 'Writing';
    } else if (currentNorm === 'proofreading') {
      targetStage = 'Editing';
    } else if (currentNorm === 'crosscheck' || currentNorm === 'textcrosscheck') {
      targetStage = 'Proofreading';
    } else if (currentNorm === 'readytopost') {
      targetStage = 'Text Crosscheck';
    }
  }
  
  if (!targetStage) {
    return { success: false, message: 'Could not determine previous stage to reverse to.' };
  }
  
  var targetNorm = normalizeStageName(targetStage);
  var reversed = false;
  
  for (var r = 1; r < data.length; r++) {
    if (data[r][postNoCol] == postNo) {
      var rStage = normalizeStageName(data[r][stageCol]);
      
      // Revert previous stage task to In Progress
      if (rStage === targetNorm) {
        taskSheet.getRange(r + 1, statusCol + 1).setValue('Ready');
        if (completedAtCol !== -1) {
          taskSheet.getRange(r + 1, completedAtCol + 1).setValue('');
        }
        if (notesCol !== -1 && reason) {
          var existingNote = data[r][notesCol] || '';
          var newNote = (existingNote ? existingNote + '\n' : '') + '[Revision: ' + new Date().toLocaleDateString() + ']: ' + reason;
          taskSheet.getRange(r + 1, notesCol + 1).setValue(newNote);
        }
        reversed = true;
      }
      
      // Reset current stage task back to Waiting
      if (rStage === currentNorm) {
        taskSheet.getRange(r + 1, statusCol + 1).setValue('Waiting');
      }

      // If reverting to Proofreading, also pause Text Crosscheck if it was Ready until Proofreading is re-approved
      if (targetNorm === 'proofreading' && (rStage === 'textcrosscheck' || rStage === 'crosscheck') && data[r][statusCol] !== 'Done') {
        taskSheet.getRange(r + 1, statusCol + 1).setValue('Waiting');
      }
    }
  }
  
  try {
    CacheService.getScriptCache().remove('all_posts');
  } catch(cErr) {}
  
  if (reversed) {
    return { success: true, message: 'Task reversed back to ' + targetStage, targetStage: targetStage };
  } else {
    return { success: false, message: 'Previous stage task (' + targetStage + ') not found for Post ' + postNo };
  }
}

function doGet(e) {
  return ContentService.createTextOutput('GET requests not supported, use POST.').setMimeType(ContentService.MimeType.TEXT);
}

// Keep-Alive: set a time-based trigger on this function every 5 minutes
// GAS Editor > Triggers > Add Trigger > keepAlive > Time-driven > Every 5 minutes
function keepAlive() {
  Logger.log('keep-alive ping: ' + new Date());
}

function handleCheckFolderNotEmpty(payload) {
  var postNo = payload.postNo;
  var stage = (payload.stage || '').toLowerCase();
  var checkType = (payload.checkType || '').toLowerCase();
  var isThumbnailCheck = checkType === 'thumbnail' || stage.indexOf('thumbnail') !== -1;

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var postsSheet = ss.getSheetByName(POSTS_SHEET);
  var postsData = postsSheet ? postsSheet.getDataRange().getValues() : [];
  var postRow = null;
  for (var p = 1; p < postsData.length; p++) {
    if (postsData[p][0] == postNo || postsData[p][1] == postNo) { postRow = postsData[p]; break; }
  }
  
  var linksToTry = [];
  if (postRow) {
    if (postRow[20]) linksToTry.push(postRow[20]);
    if (postRow[21]) linksToTry.push(postRow[21]);
  }
  if (payload.folderLink) {
    linksToTry.push(payload.folderLink);
  }

  // Also check Dev_Projects sheet if not found in POSTS_SHEET
  if (linksToTry.length === 0) {
    try {
      var devProjSheet = ss.getSheetByName(DEV_PROJECTS_SHEET);
      if (devProjSheet) {
        var dpData = devProjSheet.getDataRange().getValues();
        for (var dp = 1; dp < dpData.length; dp++) {
          if (dpData[dp][0] == postNo) {
            var fUrl = dpData[dp][7] || dpData[dp][8] || '';
            if (fUrl) linksToTry.push(fUrl);
            break;
          }
        }
      }
    } catch(devErr) {}
  }
  
  if (linksToTry.length === 0) return {success: true, notEmpty: true}; // failsafe
  
  for (var i = 0; i < linksToTry.length; i++) {
    var link = linksToTry[i];
    if (!link || link.indexOf('drive.google.com') === -1) continue;
    var match = link.match(/[-\w]{25,}/);
    if (!match) continue;
    
    try {
      var dateFolder = DriveApp.getFolderById(match[0]);
      
      if (isThumbnailCheck) {
        // Specific requirement: Under "Selected (Edited)" folder, check/create "Edited (Thumbnail)" folder
        var selectedEditedFolder = null;
        var sfs = dateFolder.getFolders();
        while (sfs.hasNext()) {
          var sub = sfs.next();
          var subName = sub.getName().toLowerCase().replace(/[\s\-_()]/g, '');
          if (subName === 'selectededited' || subName === 'selected(edited)' || subName === 'edited') {
            selectedEditedFolder = sub;
            break;
          }
        }
        if (!selectedEditedFolder) {
          var sfs2 = dateFolder.getFolders();
          while (sfs2.hasNext()) {
            var sub2 = sfs2.next();
            if (sub2.getName().toLowerCase().indexOf('edited') !== -1) {
              selectedEditedFolder = sub2;
              break;
            }
          }
        }
        if (!selectedEditedFolder && dateFolder.getName().toLowerCase().indexOf('edited') !== -1) {
          selectedEditedFolder = dateFolder;
        }

        if (selectedEditedFolder) {
          var editedThumbFolder = null;
          var tSearch = selectedEditedFolder.getFolders();
          while (tSearch.hasNext()) {
            var tf = tSearch.next();
            var tfNorm = tf.getName().toLowerCase().replace(/[\s\-_()]/g, '');
            if (tfNorm === 'editedthumbnail' || tfNorm === 'editedthumbnails' || (tfNorm.indexOf('edited') !== -1 && tfNorm.indexOf('thumb') !== -1)) {
              editedThumbFolder = tf;
              break;
            }
          }
          if (!editedThumbFolder) {
            var tSearch2 = selectedEditedFolder.getFolders();
            while (tSearch2.hasNext()) {
              var tf2 = tSearch2.next();
              if (tf2.getName().toLowerCase().indexOf('thumb') !== -1) {
                editedThumbFolder = tf2;
                break;
              }
            }
          }

          // If Edited (Thumbnail) folder is not there in Selected (Edited), create it without duplicate!
          if (!editedThumbFolder) {
            try {
              editedThumbFolder = selectedEditedFolder.createFolder('Edited (Thumbnail)');
              editedThumbFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT);
            } catch(crErr) {}
          }

          if (editedThumbFolder) {
            if (editedThumbFolder.getFiles().hasNext() || editedThumbFolder.getFolders().hasNext()) {
              return {success: true, notEmpty: true, folderUrl: editedThumbFolder.getUrl()};
            } else {
              return {
                success: true,
                notEmpty: false,
                folderUrl: editedThumbFolder.getUrl(),
                error: 'The "Edited (Thumbnail)" folder under "Selected (Edited)" is empty! Please upload the edited thumbnail files before marking done.'
              };
            }
          }
        } else {
          // If Selected (Edited) folder wasn't found, check if dateFolder itself has Edited Thumbnail
          var directThumb = null;
          var dSearch = dateFolder.getFolders();
          while (dSearch.hasNext()) {
            var df = dSearch.next();
            var dfNorm = df.getName().toLowerCase().replace(/[\s\-_()]/g, '');
            if (dfNorm === 'editedthumbnail' || (dfNorm.indexOf('edited') !== -1 && dfNorm.indexOf('thumb') !== -1)) {
              directThumb = df;
              break;
            }
          }
          if (directThumb && (directThumb.getFiles().hasNext() || directThumb.getFolders().hasNext())) {
            return {success: true, notEmpty: true, folderUrl: directThumb.getUrl()};
          }
          return {
            success: true,
            notEmpty: false,
            error: '"Selected (Edited)" folder was not found! Please ensure files are placed in "Selected (Edited) > Edited (Thumbnail)".'
          };
        }
      } else {
        // Standard Photo / Video editing check
        var sfs = dateFolder.getFolders();
        while(sfs.hasNext()) {
          var sub = sfs.next();
          var subName = sub.getName().toLowerCase();
          if (subName.indexOf('edited') !== -1 || subName === 'selected') {
            if (sub.getFiles().hasNext() || sub.getFolders().hasNext()) {
               return {success: true, notEmpty: true};
            }
          }
        }
      }
    } catch(e) {}
  }
  
  if (isThumbnailCheck) {
    return {
      success: true,
      notEmpty: false,
      error: 'The "Edited (Thumbnail)" folder under "Selected (Edited)" is empty! Please upload the edited thumbnail files.'
    };
  }
  return {success: true, notEmpty: false};
}

// =========================================================================
// ── DEVELOPMENT PIPELINE HANDLERS & HELPERS (CAMPAIGN / SM / WEB / BLOGS) ──
// =========================================================================

function ensureDevSheets(ss) {
  var iecAndPptCols = [
    'PptFolderLink', 'IecFolderLink', 'IecWritingDocLink',
    'IecDesigningFolderLink', 'IecProofreadDocLink', 'IecFinalCheckDocLink',
    'ResearchedDataLink', 'ResearchedDocLink', 'ThumbnailFolderLink'
  ];

  var pSheet = ss.getSheetByName(DEV_PROJECTS_SHEET);
  if (!pSheet) {
    pSheet = ss.insertSheet(DEV_PROJECTS_SHEET);
    pSheet.appendRow([
      'ProjectID', 'Stream', 'CampaignName', 'SessionName', 'Duration',
      'FestivalsIncluded', 'StartDate', 'CompletionDate', 'IECContent',
      'IECDesigning', 'IECProofread', 'IECFinalCheck', 'FolderLink',
      'DocLink', 'Status', 'CreatedAt'
    ].concat(iecAndPptCols));
  } else {
    var pHeaders = pSheet.getRange(1, 1, 1, Math.max(pSheet.getLastColumn(), 1)).getValues()[0];
    for (var c = 0; c < iecAndPptCols.length; c++) {
      if (pHeaders.indexOf(iecAndPptCols[c]) === -1) {
        pSheet.getRange(1, pHeaders.length + 1).setValue(iecAndPptCols[c]);
        pHeaders.push(iecAndPptCols[c]);
      }
    }
  }

  var tSheet = ss.getSheetByName(DEV_TASKS_SHEET);
  if (!tSheet) {
    tSheet = ss.insertSheet(DEV_TASKS_SHEET);
    tSheet.appendRow([
      'TaskID', 'ProjectID', 'Stage', 'Assignee', 'AssigneeEmail',
      'Status', 'DueDate', 'AllottedDate', 'CompletedAt', 'DocLink', 'Notes'
    ].concat(iecAndPptCols));
  } else {
    var tHeaders = tSheet.getRange(1, 1, 1, Math.max(tSheet.getLastColumn(), 1)).getValues()[0];
    for (var c = 0; c < iecAndPptCols.length; c++) {
      if (tHeaders.indexOf(iecAndPptCols[c]) === -1) {
        tSheet.getRange(1, tHeaders.length + 1).setValue(iecAndPptCols[c]);
        tHeaders.push(iecAndPptCols[c]);
      }
    }
  }

  var devPipeSheet = ss.getSheetByName(DEV_PIPELINE_SHEET);
  if (!devPipeSheet) {
    devPipeSheet = ss.insertSheet(DEV_PIPELINE_SHEET);
    devPipeSheet.appendRow(['Stream', 'Stage Name', 'Required Role', 'Cadence Days', 'Depends On']);
  }

  var devStages = [
    // ── Campaign Development ──
    ['Campaign Development', 'Ideation', 'Campaign Ideator', 4, ''],
    ['Campaign Development', 'Research', 'Campaign Researcher', 8, 'Ideation'],
    ['Campaign Development', 'Selection and sequencing', 'Sequencer', 12, 'Research'],
    ['Campaign Development', 'Writing', 'Campaign Writer', 16, 'Selection and sequencing'],
    ['Campaign Development', 'PPT Development', 'PPT Designer', 20, 'Writing'],
    ['Campaign Development', 'Proofreading', 'Campaign Proofreader', 24, 'PPT Development'],
    ['Campaign Development', 'Editing', 'Campaign Editor', 28, 'Proofreading'],
    ['Campaign Development', 'Final Check', 'Final Reviewer', 32, 'Editing'],

    // ── SM Development ──
    ['SM Development', 'Writing', 'Writer', 2, ''],
    ['SM Development', 'Editing', 'Editor', 4, 'Writing'],
    ['SM Development', 'Proofreading', 'Proofreader', 6, 'Editing'],
    ['SM Development', 'Text Crosscheck', 'CrossChecker', 8, 'Proofreading'],
    ['SM Development', 'Thumbnail Selection', 'Thumbnail Designer', 2, ''],
    ['SM Development', 'Thumbnail Processing', 'Thumbnail Designer', 4, 'Thumbnail Selection'],
    ['SM Development', 'Thumbnail Cross checking', 'Thumbnail Designer', 6, 'Thumbnail Processing'],
    ['SM Development', 'Photo Editing', 'Photo Editor', 4, ''],
    ['SM Development', 'Video Editing', 'Video Editor', 4, ''],
    ['SM Development', 'Media Cross Check', 'Media CrossChecker', 6, 'Photo Editing, Video Editing'],
    ['SM Development', 'Ready to Post', 'Uploader', 10, 'Text Crosscheck, Thumbnail Cross checking, Media Cross Check'],
    ['SM Development', 'Photos Clean', 'Photo Selector', 12, 'Ready to Post'],

    // ── Website Reporting ──
    ['Website Reporting', 'Writing', 'Writer', 3, ''],
    ['Website Reporting', 'Editing', 'Editor', 6, 'Writing'],
    ['Website Reporting', 'Proofreading', 'Proofreader', 9, 'Editing'],
    ['Website Reporting', 'Text Crosscheck', 'CrossChecker', 12, 'Proofreading'],
    ['Website Reporting', 'Raw Photos', 'Raw Photos Selector', 3, ''],
    ['Website Reporting', 'Selected Photos', 'Photo Editor', 6, 'Raw Photos'],
    ['Website Reporting', 'Thumbnail Selection', 'Thumbnail Designer', 6, ''],

    // ── Blogs / Articles ──
    ['Blogs / Articles', 'Writing', 'Writer', 4, ''],
    ['Blogs / Articles', 'Editing', 'Editor', 7, 'Writing'],
    ['Blogs / Articles', 'Proofreading', 'Proofreader', 10, 'Editing'],
    ['Blogs / Articles', 'Text Crosscheck', 'CrossChecker', 12, 'Proofreading'],
    ['Blogs / Articles', 'Thumbnail Selection', 'Thumbnail Designer', 7, '']
  ];

  var existingPipeData = devPipeSheet.getDataRange().getValues();
  var existingPipeKeys = {};
  for (var p = 1; p < existingPipeData.length; p++) {
    var pStream = (existingPipeData[p][0] || '').toString().trim().toLowerCase();
    var pStage = (existingPipeData[p][1] || '').toString().trim().toLowerCase();
    existingPipeKeys[pStream + '||' + pStage] = true;
  }

  for (var s = 0; s < devStages.length; s++) {
    var key = devStages[s][0].toLowerCase() + '||' + devStages[s][1].toLowerCase();
    if (!existingPipeKeys[key]) {
      devPipeSheet.appendRow(devStages[s]);
      existingPipeKeys[key] = true;
    }
  }

  var devUsersSheet = ss.getSheetByName(DEV_USERS_SHEET);
  if (!devUsersSheet) {
    devUsersSheet = ss.insertSheet(DEV_USERS_SHEET);
    devUsersSheet.appendRow(['Email', 'Name', 'Role', 'Category']);
  } else if (devUsersSheet.getLastColumn() < 4) {
    devUsersSheet.getRange(1, 4).setValue('Category');
  }

  var sampleDevUsers = [
    // ── Campaign Development ──
    ['camp.writer@djjs.org', 'Sample Campaign Writer (Replace Me)', 'Campaign Writer', 'Campaign Development'],
    ['camp.editor@djjs.org', 'Sample Campaign Editor (Replace Me)', 'Campaign Editor', 'Campaign Development'],
    ['camp.proof@djjs.org', 'Sample Campaign Proofreader (Replace Me)', 'Campaign Proofreader', 'Campaign Development'],
    ['camp.ppt@djjs.org', 'Sample PPT Designer (Replace Me)', 'PPT Designer', 'Campaign Development'],
    ['camp.review@djjs.org', 'Sample Final Reviewer (Replace Me)', 'Final Reviewer', 'Campaign Development'],
    
    // ── SM Development ──
    ['sm.writer@djjs.org', 'Sample SM Writer (Replace Me)', 'Writer', 'SM Development'],
    ['sm.editor@djjs.org', 'Sample SM Editor (Replace Me)', 'Editor', 'SM Development'],
    ['sm.proof@djjs.org', 'Sample SM Proofreader (Replace Me)', 'Proofreader', 'SM Development'],
    ['sm.crosscheck@djjs.org', 'Sample SM CrossChecker (Replace Me)', 'CrossChecker', 'SM Development'],
    ['sm.thumbnail@djjs.org', 'Sample SM Thumbnail Designer (Replace Me)', 'Thumbnail Designer', 'SM Development'],
    ['sm.photoedit@djjs.org', 'Sample SM Photo Editor (Replace Me)', 'Photo Editor', 'SM Development'],
    ['sm.videoedit@djjs.org', 'Sample SM Video Editor (Replace Me)', 'Video Editor', 'SM Development'],
    ['sm.uploader@djjs.org', 'Sample SM Uploader (Replace Me)', 'Uploader', 'SM Development'],

    // ── Website Reporting ──
    ['web.writer@djjs.org', 'Sample Web Writer (Replace Me)', 'Writer', 'Website Reporting'],
    ['web.editor@djjs.org', 'Sample Web Editor (Replace Me)', 'Editor', 'Website Reporting'],
    ['web.proof@djjs.org', 'Sample Web Proofreader (Replace Me)', 'Proofreader', 'Website Reporting'],
    ['web.photos@djjs.org', 'Sample Web Photo Selector (Replace Me)', 'Raw Photos Selector', 'Website Reporting'],
    ['web.photoedit@djjs.org', 'Sample Web Photo Editor (Replace Me)', 'Photo Editor', 'Website Reporting'],
    ['web.thumbnail@djjs.org', 'Sample Web Thumbnail Designer (Replace Me)', 'Thumbnail Designer', 'Website Reporting'],

    // ── Blogs / Articles ──
    ['blog.writer@djjs.org', 'Sample Blog Writer (Replace Me)', 'Writer', 'Blogs / Articles'],
    ['blog.editor@djjs.org', 'Sample Blog Editor (Replace Me)', 'Editor', 'Blogs / Articles'],
    ['blog.proof@djjs.org', 'Sample Blog Proofreader (Replace Me)', 'Proofreader', 'Blogs / Articles'],
    ['blog.crosscheck@djjs.org', 'Sample Blog CrossChecker (Replace Me)', 'CrossChecker', 'Blogs / Articles'],
    ['blog.thumbnail@djjs.org', 'Sample Blog Thumbnail Designer (Replace Me)', 'Thumbnail Designer', 'Blogs / Articles'],

    // ── Cross-Stream / All ──
    ['lead.admin@djjs.org', 'Sample Lead Coordinator (Replace Me)', 'Coordinator', 'All']
  ];

  // Only seed sample users when devUsersSheet is brand new or completely empty (< 2 rows)
  if (devUsersSheet.getLastRow() < 2) {
    for (var u = 0; u < sampleDevUsers.length; u++) {
      devUsersSheet.appendRow(sampleDevUsers[u]);
    }
  }
}

function getOrCreateDevStreamFolder(streamName) {
  // Exact Shared Drive Hierarchy:
  // BODH Drive -> 2 - Bodh Data - All Years (ID: 1Z6PKvQbNXo2RJ7DGZsCaWgoO1nzZiPgw)
  //   -> 2 - Events Reports - Year Wise
  //     -> Delhi (IN)
  //       -> Head Office
  //         -> [streamName] (Campaign Development, SM Development, Website Reporting, Blogs / Articles)

  var BODH_DATA_ALL_YEARS_ID = '1Z6PKvQbNXo2RJ7DGZsCaWgoO1nzZiPgw';
  var baseAllYearsFolder = null;
  try {
    baseAllYearsFolder = DriveApp.getFolderById(BODH_DATA_ALL_YEARS_ID);
  } catch(e) {}

  // 1. Locate "2 - Events Reports - Year Wise"
  var eventReportsFolder = null;
  if (baseAllYearsFolder) {
    var erSearch = baseAllYearsFolder.searchFolders("title = '2 - Events Reports - Year Wise' and trashed = false");
    if (erSearch.hasNext()) {
      eventReportsFolder = erSearch.next();
    } else {
      // Fallback check by partial name
      var allSub = baseAllYearsFolder.getFolders();
      while (allSub.hasNext()) {
        var sub = allSub.next();
        if (sub.getName().indexOf('Events Reports') !== -1) {
          eventReportsFolder = sub;
          break;
        }
      }
    }
  }

  // 2. Locate "Delhi (IN)"
  var delhiFolder = null;
  var parentForDelhi = eventReportsFolder || baseAllYearsFolder;

  if (parentForDelhi) {
    var dSearch = parentForDelhi.searchFolders("title = 'Delhi (IN)' and trashed = false");
    if (dSearch.hasNext()) {
      delhiFolder = dSearch.next();
    } else {
      // Check for 'Delhi' without (IN) or partial match
      var subs = parentForDelhi.getFolders();
      while (subs.hasNext()) {
        var sFolder = subs.next();
        var sName = sFolder.getName().toLowerCase();
        if (sName === 'delhi (in)' || sName === 'delhi' || sName.indexOf('delhi') !== -1) {
          delhiFolder = sFolder;
          break;
        }
      }
      if (!delhiFolder) {
        delhiFolder = parentForDelhi.createFolder('Delhi (IN)');
      }
    }
  }

  // Fallback if base ID was unreachable
  if (!delhiFolder) {
    var globalDSearch = DriveApp.searchFolders("title = 'Delhi (IN)' and trashed = false");
    if (globalDSearch.hasNext()) {
      delhiFolder = globalDSearch.next();
    } else {
      delhiFolder = DriveApp.getRootFolder().createFolder('Delhi (IN)');
    }
  }

  // 3. Inside 'Delhi (IN)', find or create 'Head Office'
  var hoFolder = null;
  var hoSearch = delhiFolder.searchFolders("title = 'Head Office' and trashed = false");
  if (hoSearch.hasNext()) {
    hoFolder = hoSearch.next();
  } else {
    hoFolder = delhiFolder.createFolder('Head Office');
  }

  // 4. Inside 'Head Office', ensure all 4 stream folders exist
  var streams = ['Campaign Development', 'SM Development', 'Website Reporting', 'Blogs / Articles'];
  var targetFolder = null;
  for (var s = 0; s < streams.length; s++) {
    var sName = streams[s];
    var sSearch = hoFolder.searchFolders("title = '" + sName + "' and trashed = false");
    var folder;
    if (sSearch.hasNext()) {
      folder = sSearch.next();
    } else {
      folder = hoFolder.createFolder(sName);
    }
    if (sName === streamName) {
      targetFolder = folder;
    }
  }

  return targetFolder || hoFolder;
}

function handleGetDevProjects(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  ensureDevSheets(ss);
  var sheet = ss.getSheetByName(DEV_PROJECTS_SHEET);
  var data = sheet.getDataRange().getValues();
  if (data.length < 2) return { success: true, projects: [] };

  var headers = data[0];
  var projects = [];
  var filterStream = payload && payload.stream ? payload.stream.toString().trim() : '';

  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    if (!row[0]) continue;
    var p = {};
    for (var h = 0; h < headers.length; h++) {
      var val = row[h];
      if (val instanceof Date) {
        p[headers[h]] = formatDate(val);
      } else {
        p[headers[h]] = val !== undefined && val !== null ? val.toString() : '';
      }
    }
    if (!filterStream || p.Stream === filterStream) {
      projects.push(p);
    }
  }

  return { success: true, projects: projects.reverse() };
}

function handleGetDevTasks(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  ensureDevSheets(ss);
  var sheet = ss.getSheetByName(DEV_TASKS_SHEET);
  var data = sheet.getDataRange().getValues();
  if (data.length < 2) return { success: true, tasks: [] };

  var headers = data[0];
  var tasks = [];
  var role = payload ? payload.role : '';
  var username = payload && payload.username ? payload.username.toString().trim().toLowerCase() : '';
  var projectId = payload && payload.projectId ? payload.projectId.toString().trim() : '';

  // Get project map for enriching task details
  var pSheet = ss.getSheetByName(DEV_PROJECTS_SHEET);
  var pData = pSheet.getDataRange().getValues();
  var pMap = {};
  if (pData.length >= 2) {
    var pHeaders = pData[0];
    for (var p = 1; p < pData.length; p++) {
      if (pData[p][0]) {
        var pObj = {};
        for (var ph = 0; ph < pHeaders.length; ph++) {
          var pVal = pData[p][ph];
          pObj[pHeaders[ph]] = pVal instanceof Date ? formatDate(pVal) : (pVal !== null ? pVal.toString() : '');
        }
        pMap[pData[p][0].toString()] = pObj;
      }
    }
  }

  // Pre-scan data to build project maps for Writing doc, Editing doc, Proofreading doc, Crosscheck doc, and PPT folder
  var projectWritingDocMap = {};
  var projectEditingDocMap = {};
  var projectProofDocMap = {};
  var projectCrosscheckDocMap = {};
  var projectPptFolderMap = {};
  var stageColIdx = headers.indexOf('Stage');
  var projIdColIdx = headers.indexOf('ProjectID');
  var docLinkColIdx = headers.indexOf('DocLink');
  var pptLinkColIdx = headers.indexOf('PptFolderLink');

  for (var i = 1; i < data.length; i++) {
    var pId = data[i][projIdColIdx] ? data[i][projIdColIdx].toString() : '';
    var st = data[i][stageColIdx] ? data[i][stageColIdx].toString().toLowerCase() : '';
    var dLink = docLinkColIdx !== -1 && data[i][docLinkColIdx] ? data[i][docLinkColIdx].toString() : '';
    var pLink = pptLinkColIdx !== -1 && data[i][pptLinkColIdx] ? data[i][pptLinkColIdx].toString() : '';

    if (st === 'writing' && dLink) {
      projectWritingDocMap[pId] = dLink;
    }
    if (st === 'editing' && dLink) {
      projectEditingDocMap[pId] = dLink;
    }
    if (st === 'proofreading' && dLink) {
      projectProofDocMap[pId] = dLink;
    }
    if ((st === 'text crosscheck' || st === 'cross check') && dLink) {
      projectCrosscheckDocMap[pId] = dLink;
    }
    if (st === 'ppt development') {
      projectPptFolderMap[pId] = pLink || dLink;
    }
  }

  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    if (!row[0]) continue;
    var t = {};
    for (var h = 0; h < headers.length; h++) {
      var val = row[h];
      if (val instanceof Date) {
        t[headers[h]] = formatDate(val);
      } else {
        t[headers[h]] = val !== undefined && val !== null ? val.toString() : '';
      }
    }
    t.rowIndex = i + 1;

    // Attach project info
    var proj = pMap[t.ProjectID] || {};
    t.CampaignName = proj.CampaignName || '';
    t.SessionName = proj.SessionName || '';
    t.Stream = proj.Stream || '';
    t.StartDate = proj.StartDate || '';
    t.CompletionDate = proj.CompletionDate || '';
    t.FolderLink = proj.FolderLink || '';
    t.PptFolderLink = proj.PptFolderLink || projectPptFolderMap[t.ProjectID] || t.PptFolderLink || '';
    t.WritingDocLink = projectWritingDocMap[t.ProjectID] || '';
    t.EditingDocLink = projectEditingDocMap[t.ProjectID] || '';
    t.ProofreadingDocLink = projectProofDocMap[t.ProjectID] || '';
    t.CrosscheckDocLink = projectCrosscheckDocMap[t.ProjectID] || '';
    if (t.Stage && t.Stage.toLowerCase() === 'ppt development') {
      t.PrevDocLink = projectWritingDocMap[t.ProjectID] || '';
    }
    t.ResearchedDataLink = proj.ResearchedDataLink || t.ResearchedDataLink || '';
    t.ResearchedDocLink = proj.ResearchedDocLink || t.ResearchedDocLink || '';
    t.ThumbnailFolderLink = proj.ThumbnailFolderLink || t.ThumbnailFolderLink || '';

    if (projectId && t.ProjectID !== projectId) continue;

    var assigneeLower = (t.Assignee || '').toLowerCase();
    var emailLower = (t.AssigneeEmail || '').toLowerCase();

    if (role === 'Admin' || assigneeLower === username || emailLower === username) {
      tasks.push(t);
    }
  }

  return { success: true, tasks: tasks.reverse() };
}

function handleCreateDevProject(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  ensureDevSheets(ss);
  var pSheet = ss.getSheetByName(DEV_PROJECTS_SHEET);
  var tSheet = ss.getSheetByName(DEV_TASKS_SHEET);

  var stream = payload.stream || 'Campaign Development';
  var isSmDev = (stream.indexOf('SM') !== -1 || stream.indexOf('Social Media') !== -1);
  var isWebRep = (stream.indexOf('Website') !== -1 || stream.indexOf('Web') !== -1);
  var isBlogArt = (stream.indexOf('Blog') !== -1 || stream.indexOf('Article') !== -1);
  var campaignName = (payload.campaignName || payload.postName || payload.idea || '').toString().trim();
  var sessionName = (payload.sessionName || payload.postTopic || '').toString().trim();
  var duration = payload.duration || '';
  var festivals = payload.festivals || '';
  var startDate = payload.startDate ? formatDate(payload.startDate) : formatDate(new Date());
  var completionDate = payload.completionDate ? formatDate(payload.completionDate) : '';
  var iecContent = (!isSmDev && !isWebRep && !isBlogArt) && payload.iecContent === true ? 'Yes' : 'No';
  var iecDesigning = (!isSmDev && !isWebRep && !isBlogArt) && payload.iecDesigning === true ? 'Yes' : 'No';
  var iecProofread = (!isSmDev && !isWebRep && !isBlogArt) && payload.iecProofread === true ? 'Yes' : 'No';
  var iecFinalCheck = (!isSmDev && !isWebRep && !isBlogArt) && payload.iecFinalCheck === true ? 'Yes' : 'No';
  var assignees = payload.assignees || {};

  if (!campaignName) {
    return { success: false, message: (isWebRep || isBlogArt ? 'Idea' : (isSmDev ? 'Post Name' : 'Campaign Name')) + ' is required.' };
  }

  // Generate unique ProjectID e.g. CAMP-001, SMD-001, WEB-001, BLOG-001
  var lastRow = pSheet.getLastRow();
  var prefix = isSmDev ? 'SMD' : (stream.indexOf('Campaign') !== -1 ? 'CAMP' : (isWebRep ? 'WEB' : (isBlogArt ? 'BLOG' : 'DEV')));
  var projectNo = (lastRow >= 2 ? lastRow : 1);
  var projectId = prefix + '-' + String(projectNo).padStart(3, '0');

  // Create folder: Delhi -> Head Office -> [Stream] -> [Campaign / Post Name / Idea]
  var streamFolder = getOrCreateDevStreamFolder(stream);
  var campFolder;
  var cSearch = streamFolder.searchFolders("title = '" + campaignName + "' and trashed = false");
  if (cSearch.hasNext()) {
    campFolder = cSearch.next();
  } else {
    campFolder = streamFolder.createFolder(campaignName);
  }

  var sessionFolder = campFolder;
  if (!isSmDev && !isWebRep && !isBlogArt && sessionName) {
    var sessSearch = campFolder.searchFolders("title = '" + sessionName + "' and trashed = false");
    if (sessSearch.hasNext()) {
      sessionFolder = sessSearch.next();
    } else {
      sessionFolder = campFolder.createFolder(sessionName);
    }
  }

  // Subfolders for SM Development (Raw, Selected, Edited)
  var rawFolder, selFolder, editFolder;
  if (isSmDev) {
    var rSearch = campFolder.searchFolders("title = 'Raw' and trashed = false");
    rawFolder = rSearch.hasNext() ? rSearch.next() : campFolder.createFolder('Raw');
    try { rawFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}

    var sSearch = campFolder.searchFolders("title = 'Selected' and trashed = false");
    selFolder = sSearch.hasNext() ? sSearch.next() : campFolder.createFolder('Selected');
    try { selFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}

    var eSearch = campFolder.searchFolders("title = 'Edited' and trashed = false");
    editFolder = eSearch.hasNext() ? eSearch.next() : campFolder.createFolder('Edited');
    try { editFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
  }

  // Subfolders and Researched Data Sheet for Website Reporting
  var researchedDataUrl = '';
  var rawPhotosFolder, selPhotosFolder, thumbFolder;
  if (isWebRep) {
    try {
      var resSheet = SpreadsheetApp.create('Researched Data');
      var resSheetFile = DriveApp.getFileById(resSheet.getId());
      resSheetFile.moveTo(campFolder);
      try { resSheetFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
      researchedDataUrl = resSheetFile.getUrl();
    } catch(rsErr) {
      researchedDataUrl = '';
    }

    var rSearch = campFolder.searchFolders("title = 'Raw Photos' and trashed = false");
    rawPhotosFolder = rSearch.hasNext() ? rSearch.next() : campFolder.createFolder('Raw Photos');
    try { rawPhotosFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}

    var sSearch = campFolder.searchFolders("title = 'Selected Photos' and trashed = false");
    selPhotosFolder = sSearch.hasNext() ? sSearch.next() : campFolder.createFolder('Selected Photos');
    try { selPhotosFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}

    var tSearch = selPhotosFolder.searchFolders("title = 'Thumbnail' and trashed = false");
    thumbFolder = tSearch.hasNext() ? tSearch.next() : selPhotosFolder.createFolder('Thumbnail');
    try { thumbFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
  }

  // Researched Doc and Thumbnail Folder for Blogs / Articles
  var researchedDocUrl = '';
  var blogThumbFolder;
  if (isBlogArt) {
    try {
      var rDoc = DocumentApp.create('Researched Doc');
      var rDocFile = DriveApp.getFileById(rDoc.getId());
      rDocFile.moveTo(campFolder);
      try { rDocFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
      var rBody = rDoc.getBody();
      rBody.appendParagraph(campaignName + ' - Researched Doc').setHeading(DocumentApp.ParagraphHeading.HEADING1);
      rBody.appendParagraph('Idea: ' + campaignName);
      rBody.appendParagraph('Festivals / Days: ' + festivals);
      rBody.appendParagraph('Compile research, ideas, reference links, and article drafts here.');
      rBody.appendParagraph('--------------------------------------------------\n');
      rDoc.saveAndClose();
      researchedDocUrl = rDocFile.getUrl();
    } catch(rdErr) {
      researchedDocUrl = '';
    }

    var btSearch = campFolder.searchFolders("title = 'Thumbnail' and trashed = false");
    blogThumbFolder = btSearch.hasNext() ? btSearch.next() : campFolder.createFolder('Thumbnail');
    try { blogThumbFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
  }

  // Stages configuration based on Stream
  var stages;
  if (isSmDev) {
    stages = [
      { name: 'Writing', offset: 4, isDoc: true, initialStatus: 'Ready' },
      { name: 'Editing', offset: 8, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Proofreading', offset: 12, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Text Crosscheck', offset: 16, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Thumbnail Selection', offset: 8, isDoc: false, initialStatus: 'Ready' },
      { name: 'Thumbnail Processing', offset: 12, isDoc: false, initialStatus: 'Waiting' },
      { name: 'Thumbnail Cross checking', offset: 16, isDoc: false, initialStatus: 'Waiting' },
      { name: 'Photo Editing', offset: 8, isDoc: false, initialStatus: 'Ready' },
      { name: 'Video Editing', offset: 8, isDoc: false, initialStatus: 'Ready' },
      { name: 'Media Cross Check', offset: 12, isDoc: false, initialStatus: 'Waiting' },
      { name: 'Media Final Cross check', offset: 16, isDoc: false, initialStatus: 'Waiting' },
      { name: 'Ready to Post', offset: 20, isDoc: false, initialStatus: 'Waiting' },
      { name: 'Photos Clean', offset: 24, isDoc: false, initialStatus: 'Waiting' }
    ];
  } else if (isWebRep) {
    stages = [
      { name: 'Writing', offset: 4, isDoc: true, initialStatus: 'Ready' },
      { name: 'Editing', offset: 8, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Proofreading', offset: 12, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Text Crosscheck', offset: 16, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Raw Photos', offset: 8, isDoc: false, initialStatus: 'Ready' },
      { name: 'Selected Photos', offset: 12, isDoc: false, initialStatus: 'Waiting' },
      { name: 'Thumbnail Selection', offset: 16, isDoc: false, initialStatus: 'Waiting' }
    ];
  } else if (isBlogArt) {
    stages = [
      { name: 'Writing', offset: 4, isDoc: true, initialStatus: 'Ready' },
      { name: 'Editing', offset: 8, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Proofreading', offset: 12, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Text Crosscheck', offset: 16, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Thumbnail Selection', offset: 20, isDoc: false, initialStatus: 'Waiting' }
    ];
  } else {
    stages = [
      { name: 'Ideation', offset: 4, isDoc: true, initialStatus: 'Ready' },
      { name: 'Research', offset: 8, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Selection and sequencing', offset: 12, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Writing', offset: 16, isDoc: true, initialStatus: 'Waiting' },
      { name: 'PPT Development', offset: 20, isDoc: false, initialStatus: 'Waiting' },
      { name: 'Proofreading', offset: 24, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Editing', offset: 28, isDoc: true, initialStatus: 'Waiting' },
      { name: 'Final Check', offset: 32, isDoc: true, initialStatus: 'Waiting' }
    ];
  }

  var stageDocUrls = {};
  var pptFolderUrl = '';

  for (var s = 0; s < stages.length; s++) {
    var stName = stages[s].name;
    var assignedObj = assignees[stName] || {};
    if (!assignedObj.name) {
      if (stName === 'Writing') assignedObj = assignees['Writer'] || {};
      else if (stName === 'Editing') assignedObj = assignees['Editor'] || {};
      else if (stName === 'Proofreading') assignedObj = assignees['Proofreader'] || {};
      else if (stName === 'Text Crosscheck') assignedObj = assignees['CrossChecker'] || {};
      else if (stName === 'Raw Photos') assignedObj = assignees['Photo Selector'] || assignees['Photographer'] || {};
      else if (stName === 'Selected Photos') assignedObj = assignees['Photo Editor'] || {};
      else if (stName === 'Thumbnail Selection') assignedObj = assignees['Thumbnail Designer'] || {};
    }
    var sEmail = (typeof assignedObj === 'object' && assignedObj ? assignedObj.email : '') || '';

    if (!isSmDev && !isWebRep && !isBlogArt && stName === 'PPT Development') {
      // Step 5 of Campaign: PPT Upload folder
      var pptFolderName = '5 - PPT Development';
      var pptFolder;
      var fSearch = sessionFolder.searchFolders("title = '" + pptFolderName + "' and trashed = false");
      if (fSearch.hasNext()) {
        pptFolder = fSearch.next();
      } else {
        pptFolder = sessionFolder.createFolder(pptFolderName);
      }
      try { pptFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
      if (sEmail && sEmail.indexOf('@') !== -1) {
        try { pptFolder.addEditor(sEmail); } catch(pErr) {}
      }
      pptFolderUrl = pptFolder.getUrl();
      stageDocUrls[stName] = pptFolderUrl;
    } else if (stages[s].isDoc) {
      // Create Google Doc for content writing stages
      var stepDocTitle = campaignName + (sessionName ? ' - ' + sessionName : '') + ' - Step ' + (s + 1) + ' (' + stName + ')';
      var stepDocUrl = '';
      try {
        var sDoc = DocumentApp.create(stepDocTitle);
        var sDocFile = DriveApp.getFileById(sDoc.getId());
        sDocFile.moveTo((isSmDev || isWebRep || isBlogArt) ? campFolder : sessionFolder);
        try { sDocFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
        
        var sBody = sDoc.getBody();
        sBody.appendParagraph(stepDocTitle).setHeading(DocumentApp.ParagraphHeading.HEADING1);
        sBody.appendParagraph((isWebRep || isBlogArt ? 'Idea: ' : (isSmDev ? 'Post: ' : 'Campaign: ')) + campaignName + (sessionName ? ' | Topic: ' + sessionName : ''));
        sBody.appendParagraph('Stage: ' + stName + ' (Step ' + (s + 1) + ' of ' + stages.length + ')');
        sBody.appendParagraph('Festivals / Days: ' + festivals + (duration ? ' | Duration: ' + duration : ''));
        if (isWebRep && researchedDataUrl) {
          sBody.appendParagraph('Researched Data Sheet: ' + researchedDataUrl);
        }
        if (isBlogArt && researchedDocUrl) {
          sBody.appendParagraph('Researched Doc: ' + researchedDocUrl);
        }
        if (isBlogArt && blogThumbFolder) {
          sBody.appendParagraph('Thumbnail Folder: ' + blogThumbFolder.getUrl());
        }
        sBody.appendParagraph('Idea Drive Folder: ' + campFolder.getUrl());
        sBody.appendParagraph('--------------------------------------------------\n');
        
        if (sEmail && sEmail.indexOf('@') !== -1) {
          try { sDocFile.addEditor(sEmail); } catch(mErr) {}
        }
        
        sDoc.saveAndClose();
        stepDocUrl = sDocFile.getUrl();
      } catch(err) {
        stepDocUrl = '';
      }
      stageDocUrls[stName] = stepDocUrl;
    } else if (isWebRep) {
      if (stName === 'Raw Photos') {
        stageDocUrls[stName] = rawPhotosFolder ? rawPhotosFolder.getUrl() : campFolder.getUrl();
      } else if (stName === 'Selected Photos') {
        stageDocUrls[stName] = selPhotosFolder ? selPhotosFolder.getUrl() : campFolder.getUrl();
      } else if (stName === 'Thumbnail Selection') {
        stageDocUrls[stName] = thumbFolder ? thumbFolder.getUrl() : (selPhotosFolder ? selPhotosFolder.getUrl() : campFolder.getUrl());
      } else {
        stageDocUrls[stName] = campFolder.getUrl();
      }
    } else if (isBlogArt) {
      if (stName === 'Thumbnail Selection') {
        stageDocUrls[stName] = blogThumbFolder ? blogThumbFolder.getUrl() : campFolder.getUrl();
      } else {
        stageDocUrls[stName] = campFolder.getUrl();
      }
    } else {
      // Non-doc stages in SM Development
      if (stName.indexOf('Photo') !== -1 || stName.indexOf('Video') !== -1) {
        stageDocUrls[stName] = rawFolder ? rawFolder.getUrl() : campFolder.getUrl();
      } else if (stName.indexOf('Thumbnail') !== -1) {
        stageDocUrls[stName] = selFolder ? selFolder.getUrl() : campFolder.getUrl();
      } else if (stName.indexOf('Media') !== -1) {
        stageDocUrls[stName] = editFolder ? editFolder.getUrl() : campFolder.getUrl();
      } else {
        stageDocUrls[stName] = campFolder.getUrl();
      }
    }
  }

  // Master docUrl for project row
  var masterDocUrl = stageDocUrls['Writing'] || stageDocUrls['Ideation'] || campFolder.getUrl();

  // -------------------------------------------------------------
  // IEC Material (Common to Campaign, NOT per session)
  // Under campFolder: create 'IEC Material' folder if not present
  // -------------------------------------------------------------
  var iecFolderUrl = '';
  var iecWritingDocUrl = '';
  var iecDesigningFolderUrl = '';
  var iecProofreadDocUrl = '';
  var iecFinalCheckDocUrl = '';

  var hasIec = (iecContent === 'Yes' || iecDesigning === 'Yes' || iecProofread === 'Yes' || iecFinalCheck === 'Yes');
  if (hasIec) {
    var iecFolder;
    var iecSearch = campFolder.searchFolders("title = 'IEC Material' and trashed = false");
    if (iecSearch.hasNext()) {
      iecFolder = iecSearch.next();
    } else {
      iecFolder = campFolder.createFolder('IEC Material');
    }
    try { iecFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
    iecFolderUrl = iecFolder.getUrl();

    // 1. IEC Content Writing Doc
    if (iecContent === 'Yes') {
      var wDocTitle = campaignName + ' - IEC Content Writing';
      var wDocSearch = iecFolder.searchFiles("title = '" + wDocTitle + "' and trashed = false");
      if (wDocSearch.hasNext()) {
        iecWritingDocUrl = wDocSearch.next().getUrl();
      } else {
        try {
          var wDoc = DocumentApp.create(wDocTitle);
          var wDocFile = DriveApp.getFileById(wDoc.getId());
          wDocFile.moveTo(iecFolder);
          try { wDocFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
          var wBody = wDoc.getBody();
          wBody.appendParagraph(wDocTitle).setHeading(DocumentApp.ParagraphHeading.HEADING1);
          wBody.appendParagraph('Campaign: ' + campaignName);
          wBody.appendParagraph('Type: IEC Material - Content Writing');
          wBody.appendParagraph('--------------------------------------------------\n');
          wDoc.saveAndClose();
          iecWritingDocUrl = wDocFile.getUrl();
        } catch(err) {}
      }
    }

    // 2. IEC Designing Folder
    if (iecDesigning === 'Yes') {
      var dFolderName = 'IEC Designing';
      var dSearch = iecFolder.searchFolders("title = '" + dFolderName + "' and trashed = false");
      var dFolder;
      if (dSearch.hasNext()) {
        dFolder = dSearch.next();
      } else {
        dFolder = iecFolder.createFolder(dFolderName);
      }
      try { dFolder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
      iecDesigningFolderUrl = dFolder.getUrl();
    }

    // 3. IEC Proofread Doc (with forwarded content from Writing Doc)
    if (iecProofread === 'Yes') {
      var pDocTitle = campaignName + ' - IEC Proofreading';
      var pDocSearch = iecFolder.searchFiles("title = '" + pDocTitle + "' and trashed = false");
      if (pDocSearch.hasNext()) {
        iecProofreadDocUrl = pDocSearch.next().getUrl();
      } else {
        try {
          var pDoc = DocumentApp.create(pDocTitle);
          var pDocFile = DriveApp.getFileById(pDoc.getId());
          pDocFile.moveTo(iecFolder);
          try { pDocFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
          var pBody = pDoc.getBody();
          pBody.appendParagraph(pDocTitle).setHeading(DocumentApp.ParagraphHeading.HEADING1);
          pBody.appendParagraph('Campaign: ' + campaignName);
          pBody.appendParagraph('Type: IEC Material - Proofreading');
          pBody.appendParagraph('--------------------------------------------------\n');
          pDoc.saveAndClose();
          iecProofreadDocUrl = pDocFile.getUrl();

          // Auto copy content from IEC Writing Doc into IEC Proofreading Doc if writing doc exists
          if (iecWritingDocUrl) {
            try { copyDevDocContentForward(iecWritingDocUrl, iecProofreadDocUrl, 'IEC Content Writing', 'IEC Proofreading'); } catch(ce) {}
          }
        } catch(err) {}
      }
    }

    // 4. IEC Final Cross check Doc (with forwarded content from Proofread Doc)
    if (iecFinalCheck === 'Yes') {
      var fDocTitle = campaignName + ' - IEC Final Cross check';
      var fDocSearch = iecFolder.searchFiles("title = '" + fDocTitle + "' and trashed = false");
      if (fDocSearch.hasNext()) {
        iecFinalCheckDocUrl = fDocSearch.next().getUrl();
      } else {
        try {
          var fDoc = DocumentApp.create(fDocTitle);
          var fDocFile = DriveApp.getFileById(fDoc.getId());
          fDocFile.moveTo(iecFolder);
          try { fDocFile.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT); } catch(pe) {}
          var fBody = fDoc.getBody();
          fBody.appendParagraph(fDocTitle).setHeading(DocumentApp.ParagraphHeading.HEADING1);
          fBody.appendParagraph('Campaign: ' + campaignName);
          fBody.appendParagraph('Type: IEC Material - Final Cross check');
          fBody.appendParagraph('--------------------------------------------------\n');
          fDoc.saveAndClose();
          iecFinalCheckDocUrl = fDocFile.getUrl();

          // Auto copy content from IEC Proofread Doc into IEC Final Cross check Doc
          var srcUrl = iecProofreadDocUrl || iecWritingDocUrl;
          if (srcUrl) {
            try { copyDevDocContentForward(srcUrl, iecFinalCheckDocUrl, 'IEC Proofreading', 'IEC Final Cross check'); } catch(ce) {}
          }
        } catch(err) {}
      }
    }
  }

  var finalThumbUrl = isWebRep ? (thumbFolder ? thumbFolder.getUrl() : '') : (isBlogArt ? (blogThumbFolder ? blogThumbFolder.getUrl() : '') : '');

  // Append project row
  pSheet.appendRow([
    projectId,
    stream,
    campaignName,
    sessionName,
    duration,
    festivals,
    startDate,
    completionDate,
    iecContent,
    iecDesigning,
    iecProofread,
    iecFinalCheck,
    sessionFolder.getUrl(),
    masterDocUrl,
    'Active',
    new Date().toLocaleString(),
    pptFolderUrl,
    iecFolderUrl,
    iecWritingDocUrl,
    iecDesigningFolderUrl,
    iecProofreadDocUrl,
    iecFinalCheckDocUrl,
    researchedDataUrl,
    researchedDocUrl,
    finalThumbUrl
  ]);

  var baseDate = new Date();
  var taskRows = [];
  for (var s = 0; s < stages.length; s++) {
    var stageObj = stages[s];
    var stName = stageObj.name;
    var assignedObj = assignees[stName] || {};
    var assigneeName = typeof assignedObj === 'object' ? (assignedObj.name || '') : assignedObj.toString();
    var assigneeEmail = typeof assignedObj === 'object' ? (assignedObj.email || '') : '';

    var d = new Date(baseDate.getTime());
    d.setDate(d.getDate() + stageObj.offset);
    var dueDateStr = formatDate(d);

    var initialStatus = stageObj.initialStatus || ((s === 0) ? 'Ready' : 'Waiting');
    var allottedDate = (initialStatus === 'Ready' && assigneeName) ? new Date().toLocaleString() : '';
    var specificDocUrl = stageDocUrls[stName] || '';

    taskRows.push([
      projectId + '-' + stName,
      projectId,
      stName,
      assigneeName,
      assigneeEmail,
      initialStatus,
      dueDateStr,
      allottedDate,
      '',
      specificDocUrl,
      '',
      pptFolderUrl,
      iecFolderUrl,
      iecWritingDocUrl,
      iecDesigningFolderUrl,
      iecProofreadDocUrl,
      iecFinalCheckDocUrl,
      researchedDataUrl,
      researchedDocUrl,
      finalThumbUrl
    ]);
  }

  // Append task rows
  if (taskRows.length > 0) {
    var tLastRow = tSheet.getLastRow();
    tSheet.getRange(tLastRow + 1, 1, taskRows.length, taskRows[0].length).setValues(taskRows);
  }

  // Ensure any newly specified assignees are recorded in Dev_Users sheet
  try {
    var devUsersSheet = ss.getSheetByName(DEV_USERS_SHEET);
    if (devUsersSheet) {
      var existingDevUserData = devUsersSheet.getDataRange().getValues();
      var existingDevEmails = {};
      for (var u = 1; u < existingDevUserData.length; u++) {
        var em = (existingDevUserData[u][0] || '').toString().trim().toLowerCase();
        if (em) existingDevEmails[em] = true;
      }
      for (var k in assignees) {
        var aObj = assignees[k];
        if (aObj && typeof aObj === 'object') {
          var aEmail = (aObj.email || '').toString().trim();
          var aName = (aObj.name || '').toString().trim();
          if (aEmail && aEmail.indexOf('@') !== -1 && !existingDevEmails[aEmail.toLowerCase()]) {
            devUsersSheet.appendRow([aEmail, aName || aEmail, k, stream]);
            existingDevEmails[aEmail.toLowerCase()] = true;
          }
        }
      }
    }
  } catch(ue) {}

  return {
    success: true,
    message: 'Campaign Development project and 8 sequential tasks created successfully.',
    projectId: projectId,
    docUrl: masterDocUrl,
    pptFolderUrl: pptFolderUrl,
    folderUrl: sessionFolder.getUrl(),
    iecFolderUrl: iecFolderUrl,
    iecWritingDocUrl: iecWritingDocUrl,
    iecDesigningFolderUrl: iecDesigningFolderUrl,
    iecProofreadDocUrl: iecProofreadDocUrl,
    iecFinalCheckDocUrl: iecFinalCheckDocUrl
  };
}

function handleReassignDevTask(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  ensureDevSheets(ss);
  
  var taskId = payload.taskId;
  var newAssigneeName = payload.newAssigneeName || '';
  var newAssigneeEmail = payload.newAssigneeEmail || '';
  var role = payload.role || '';
  var category = payload.category || '';

  if (!taskId) {
    return { success: false, message: 'TaskId is required.' };
  }

  // 1. Ensure user exists in Dev_Users sheet, or append if new
  var devUsersSheet = ss.getSheetByName(DEV_USERS_SHEET);
  if (devUsersSheet && newAssigneeEmail) {
    var usersData = devUsersSheet.getDataRange().getValues();
    var found = false;
    for (var i = 1; i < usersData.length; i++) {
      if ((usersData[i][0] || '').toString().toLowerCase() === newAssigneeEmail.toLowerCase()) {
        found = true;
        // Update name if changed
        if (newAssigneeName && usersData[i][1] !== newAssigneeName) {
          devUsersSheet.getRange(i + 1, 2).setValue(newAssigneeName);
        }
        break;
      }
    }
    if (!found) {
      devUsersSheet.appendRow([newAssigneeEmail, newAssigneeName || newAssigneeEmail, role, category || 'All']);
    }
  }

  // 2. Update task in Dev_Tasks sheet
  var tSheet = ss.getSheetByName(DEV_TASKS_SHEET);
  if (!tSheet) return { success: false, message: 'Dev_Tasks sheet not found.' };

  var tData = tSheet.getDataRange().getValues();
  var headers = tData[0];
  var taskIdCol = headers.indexOf('TaskID');
  var assigneeCol = headers.indexOf('Assignee');
  var assigneeEmailCol = headers.indexOf('AssigneeEmail');
  var allottedDateCol = headers.indexOf('AllottedDate');
  var statusCol = headers.indexOf('Status');
  var docLinkCol = headers.indexOf('DocLink');

  if (taskIdCol === -1 || assigneeCol === -1) {
    return { success: false, message: 'Invalid Dev_Tasks headers.' };
  }

  var updated = false;
  var targetDocUrl = '';
  for (var i = 1; i < tData.length; i++) {
    if (tData[i][taskIdCol] && tData[i][taskIdCol].toString() === taskId) {
      tSheet.getRange(i + 1, assigneeCol + 1).setValue(newAssigneeName || newAssigneeEmail);
      if (assigneeEmailCol !== -1) {
        tSheet.getRange(i + 1, assigneeEmailCol + 1).setValue(newAssigneeEmail);
      }
      if (allottedDateCol !== -1 && (!tData[i][allottedDateCol] || tData[i][statusCol] === 'Ready')) {
        tSheet.getRange(i + 1, allottedDateCol + 1).setValue(new Date().toLocaleString());
      }
      if (docLinkCol !== -1) {
        targetDocUrl = tData[i][docLinkCol];
      }
      updated = true;
      break;
    }
  }

  // 3. Grant edit access to new assignee if Google Doc / Folder exists
  if (targetDocUrl && newAssigneeEmail && newAssigneeEmail.indexOf('@') !== -1) {
    try {
      if (targetDocUrl.indexOf('/document/d/') !== -1) {
        var docId = targetDocUrl.split('/document/d/')[1].split('/')[0];
        DriveApp.getFileById(docId).addEditor(newAssigneeEmail);
      } else if (targetDocUrl.indexOf('/folders/') !== -1) {
        var folderId = targetDocUrl.split('/folders/')[1].split('?')[0].split('/')[0];
        DriveApp.getFolderById(folderId).addEditor(newAssigneeEmail);
      }
    } catch(e) {}
  }

  if (updated) {
    return { success: true, message: 'Task reassigned successfully!' };
  } else {
    return { success: false, message: 'Task not found: ' + taskId };
  }
}

function handleUpdateDevTask(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  ensureDevSheets(ss);
  var tSheet = ss.getSheetByName(DEV_TASKS_SHEET);
  var data = tSheet.getDataRange().getValues();
  if (data.length < 2) return { success: false, message: 'No tasks found' };

  var headers = data[0];
  var taskIdCol = headers.indexOf('TaskID');
  var projIdCol = headers.indexOf('ProjectID');
  var stageCol = headers.indexOf('Stage');
  var statusCol = headers.indexOf('Status');
  var completedAtCol = headers.indexOf('CompletedAt');
  var allottedCol = headers.indexOf('AllottedDate');
  var docLinkCol = headers.indexOf('DocLink');

  var taskId = payload.taskId;
  var targetRowIdx = -1;
  var currentTask = null;

  for (var i = 1; i < data.length; i++) {
    if (data[i][taskIdCol] == taskId) {
      targetRowIdx = i + 1;
      currentTask = {
        rowIdx: i + 1,
        taskId: data[i][taskIdCol],
        projectId: data[i][projIdCol],
        stage: data[i][stageCol],
        status: data[i][statusCol],
        docLink: docLinkCol !== -1 ? data[i][docLinkCol] : ''
      };
      break;
    }
  }

  if (targetRowIdx === -1 || !currentTask) {
    return { success: false, message: 'Task not found: ' + taskId };
  }

  var newStatus = payload.status || 'Done';
  tSheet.getRange(targetRowIdx, statusCol + 1).setValue(newStatus);
  if (newStatus === 'Done' && completedAtCol !== -1) {
    tSheet.getRange(targetRowIdx, completedAtCol + 1).setValue(new Date().toLocaleString());
  }

  // If marked Done, unlock the next sequential step for this project AND copy forward content
  if (newStatus === 'Done') {
    var projectTasks = [];
    for (var i = 1; i < data.length; i++) {
      if (data[i][projIdCol] == currentTask.projectId) {
        projectTasks.push({
          rowIdx: i + 1,
          stage: data[i][stageCol],
          status: (i + 1 === targetRowIdx) ? 'Done' : data[i][statusCol],
          docLink: docLinkCol !== -1 ? data[i][docLinkCol] : ''
        });
      }
    }

    var isSmDev = currentTask.projectId.indexOf('SMD') === 0;
    var isWebRep = currentTask.projectId.indexOf('WEB') === 0;
    var isBlogArt = currentTask.projectId.indexOf('BLOG') === 0;

    if (isSmDev || isWebRep || isBlogArt) {
      function findProjTask(stName) {
        for (var pt = 0; pt < projectTasks.length; pt++) {
          if (projectTasks[pt].stage.toLowerCase() === stName.toLowerCase()) return projectTasks[pt];
        }
        return null;
      }
      function setReady(taskObj) {
        if (!taskObj) return;
        tSheet.getRange(taskObj.rowIdx, statusCol + 1).setValue('Ready');
        if (allottedCol !== -1) {
          tSheet.getRange(taskObj.rowIdx, allottedCol + 1).setValue(new Date().toLocaleString());
        }
      }

      var cStageLower = currentTask.stage.toLowerCase();
      // 1. Content Workflow (Same for SM, Website Reporting, and Blogs/Articles!)
      if (cStageLower === 'writing') {
        var nextT = findProjTask('Editing');
        setReady(nextT);
        if (currentTask.docLink && nextT && nextT.docLink) {
          try { copyDevDocContentForward(currentTask.docLink, nextT.docLink, 'Writing', 'Editing'); } catch(e) {}
        }
      } else if (cStageLower === 'editing') {
        var nextT = findProjTask('Proofreading');
        setReady(nextT);
        if (currentTask.docLink && nextT && nextT.docLink) {
          try { copyDevDocContentForward(currentTask.docLink, nextT.docLink, 'Editing', 'Proofreading'); } catch(e) {}
        }
      } else if (cStageLower === 'proofreading') {
        var nextT = findProjTask('Text Crosscheck');
        setReady(nextT);
        if (currentTask.docLink && nextT && nextT.docLink) {
          try { copyDevDocContentForward(currentTask.docLink, nextT.docLink, 'Proofreading', 'Text Crosscheck'); } catch(e) {}
        }
        if (isSmDev) {
          var mcc = findProjTask('Media Cross Check');
          if (mcc && mcc.status === 'Done') {
            setReady(findProjTask('Media Final Cross check'));
          }
        }
      } else if (cStageLower === 'text crosscheck' || cStageLower === 'cross check') {
        if (isWebRep || isBlogArt) {
          setReady(findProjTask('Thumbnail Selection'));
        } else {
          var mfc = findProjTask('Media Final Cross check');
          if (mfc && mfc.status === 'Done') {
            setReady(findProjTask('Ready to Post'));
          }
        }
      }
      // 2. Website Reporting Media Workflow
      else if (isWebRep && cStageLower === 'raw photos') {
        setReady(findProjTask('Selected Photos'));
      } else if (isWebRep && cStageLower === 'selected photos') {
        setReady(findProjTask('Thumbnail Selection'));
      }
      // 3. SM Development Thumbnail & Media Workflow
      else if (isSmDev && cStageLower === 'thumbnail selection') {
        setReady(findProjTask('Thumbnail Processing'));
      } else if (isSmDev && cStageLower === 'thumbnail processing') {
        setReady(findProjTask('Thumbnail Cross checking'));
      } else if (isSmDev && (cStageLower === 'photo editing' || cStageLower === 'video editing')) {
        var pe = findProjTask('Photo Editing');
        var ve = findProjTask('Video Editing');
        var peDone = !pe || pe.status === 'Done';
        var veDone = !ve || ve.status === 'Done';
        if (peDone && veDone) {
          setReady(findProjTask('Media Cross Check'));
        }
      } else if (isSmDev && cStageLower === 'media cross check') {
        var pr = findProjTask('Proofreading');
        if (pr && pr.status === 'Done') {
          setReady(findProjTask('Media Final Cross check'));
        }
      } else if (isSmDev && cStageLower === 'media final cross check') {
        var tc = findProjTask('Text Crosscheck');
        if (tc && tc.status === 'Done') {
          setReady(findProjTask('Ready to Post'));
        }
      } else if (isSmDev && cStageLower === 'ready to post') {
        setReady(findProjTask('Photos Clean'));
      }
    } else {
      // Campaign Development 8-step sequential workflow
      var stagesOrder = [
        'Ideation', 'Research', 'Selection and sequencing', 'Writing',
        'PPT Development', 'Proofreading', 'Editing', 'Final Check'
      ];

      var currentIdx = -1;
      for (var s = 0; s < stagesOrder.length; s++) {
        if (stagesOrder[s].toLowerCase() === currentTask.stage.toLowerCase()) {
          currentIdx = s;
          break;
        }
      }

      if (currentIdx !== -1 && currentIdx + 1 < stagesOrder.length) {
        var nextStageName = stagesOrder[currentIdx + 1];
        var nextTask = null;
        for (var pt = 0; pt < projectTasks.length; pt++) {
          if (projectTasks[pt].stage.toLowerCase() === nextStageName.toLowerCase()) {
            nextTask = projectTasks[pt];
            tSheet.getRange(projectTasks[pt].rowIdx, statusCol + 1).setValue('Ready');
            if (allottedCol !== -1) {
              tSheet.getRange(projectTasks[pt].rowIdx, allottedCol + 1).setValue(new Date().toLocaleString());
            }
            break;
          }
        }

        // Copy completed content into the next stage doc
        var sourceDocUrl = currentTask.docLink;
        if (currentTask.stage.toLowerCase() === 'ppt development') {
          // When PPT Development completes, source text comes from Step 4 (Writing) doc
          for (var pt = 0; pt < projectTasks.length; pt++) {
            if (projectTasks[pt].stage.toLowerCase() === 'writing') {
              sourceDocUrl = projectTasks[pt].docLink;
              break;
            }
          }
        }

        // Only attempt to copy if both source and target are valid Google Docs
        if (sourceDocUrl && nextTask && nextTask.docLink &&
            sourceDocUrl.indexOf('docs.google.com/document') !== -1 &&
            nextTask.docLink.indexOf('docs.google.com/document') !== -1) {
          try {
            copyDevDocContentForward(
              sourceDocUrl,
              nextTask.docLink,
              currentTask.stage.toLowerCase() === 'ppt development' ? 'Writing' : currentTask.stage,
              nextStageName
            );
          } catch(cErr) {}
        }
      }
    }
  }

  return { success: true, message: 'Development task updated successfully.' };
}

function handleRedoDevTask(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  ensureDevSheets(ss);
  var tSheet = ss.getSheetByName(DEV_TASKS_SHEET);
  var data = tSheet.getDataRange().getValues();
  if (data.length < 2) return { success: false, message: 'No tasks found' };

  var headers = data[0];
  var taskIdCol = headers.indexOf('TaskID');
  var projIdCol = headers.indexOf('ProjectID');
  var stageCol = headers.indexOf('Stage');
  var statusCol = headers.indexOf('Status');
  var notesCol = headers.indexOf('Notes');
  var completedAtCol = headers.indexOf('CompletedAt');

  var taskId = payload.taskId;
  var reason = payload.reason || 'Needs revision';
  var targetRowIdx = -1;
  var currentTask = null;

  for (var i = 1; i < data.length; i++) {
    if (data[i][taskIdCol] == taskId) {
      targetRowIdx = i + 1;
      currentTask = {
        rowIdx: i + 1,
        taskId: data[i][taskIdCol],
        projectId: data[i][projIdCol],
        stage: data[i][stageCol]
      };
      break;
    }
  }

  if (targetRowIdx === -1 || !currentTask) {
    return { success: false, message: 'Task not found: ' + taskId };
  }

  var isSmDev = currentTask.projectId.indexOf('SMD') === 0;
  var isWebRep = currentTask.projectId.indexOf('WEB') === 0;
  var isBlogArt = currentTask.projectId.indexOf('BLOG') === 0;
  var prevStageName = '';
  if (isSmDev) {
    var cStageLower = currentTask.stage.toLowerCase();
    if (cStageLower === 'editing') prevStageName = 'Writing';
    else if (cStageLower === 'proofreading') prevStageName = 'Editing';
    else if (cStageLower === 'text crosscheck' || cStageLower === 'cross check') prevStageName = 'Proofreading';
    else if (cStageLower === 'thumbnail processing') prevStageName = 'Thumbnail Selection';
    else if (cStageLower === 'thumbnail cross checking') prevStageName = 'Thumbnail Processing';
    else if (cStageLower === 'media cross check') prevStageName = 'Photo Editing';
    else if (cStageLower === 'media final cross check') prevStageName = 'Media Cross Check';
    else if (cStageLower === 'ready to post') prevStageName = 'Media Final Cross check';
    else if (cStageLower === 'photos clean') prevStageName = 'Ready to Post';
  } else if (isWebRep) {
    var cStageLower = currentTask.stage.toLowerCase();
    if (cStageLower === 'editing') prevStageName = 'Writing';
    else if (cStageLower === 'proofreading') prevStageName = 'Editing';
    else if (cStageLower === 'text crosscheck' || cStageLower === 'cross check') prevStageName = 'Proofreading';
    else if (cStageLower === 'selected photos') prevStageName = 'Raw Photos';
    else if (cStageLower === 'thumbnail selection') prevStageName = 'Selected Photos';
  } else if (isBlogArt) {
    var cStageLower = currentTask.stage.toLowerCase();
    if (cStageLower === 'editing') prevStageName = 'Writing';
    else if (cStageLower === 'proofreading') prevStageName = 'Editing';
    else if (cStageLower === 'text crosscheck' || cStageLower === 'cross check') prevStageName = 'Proofreading';
    else if (cStageLower === 'thumbnail selection') prevStageName = 'Text Crosscheck';
  } else {
    var stagesOrder = [
      'Ideation', 'Research', 'Selection and sequencing', 'Writing',
      'PPT Development', 'Proofreading', 'Editing', 'Final Check'
    ];

    var currentIdx = -1;
    for (var s = 0; s < stagesOrder.length; s++) {
      if (stagesOrder[s].toLowerCase() === currentTask.stage.toLowerCase()) {
        currentIdx = s;
        break;
      }
    }

    if (currentIdx > 0) {
      prevStageName = stagesOrder[currentIdx - 1];
    }
  }

  if (!prevStageName) {
    return { success: false, message: 'Cannot redo or previous stage not found for: ' + currentTask.stage };
  }
  var prevTaskRowIdx = -1;
  for (var i = 1; i < data.length; i++) {
    if (data[i][projIdCol] == currentTask.projectId && data[i][stageCol].toLowerCase() === prevStageName.toLowerCase()) {
      prevTaskRowIdx = i + 1;
      break;
    }
  }

  if (prevTaskRowIdx === -1) {
    return { success: false, message: 'Previous stage task not found: ' + prevStageName };
  }

  // Revert previous task to Ready and append redo note
  tSheet.getRange(prevTaskRowIdx, statusCol + 1).setValue('Ready');
  if (completedAtCol !== -1) {
    tSheet.getRange(prevTaskRowIdx, completedAtCol + 1).setValue('');
  }
  if (notesCol !== -1) {
    var existingNote = data[prevTaskRowIdx - 1][notesCol] || '';
    var newNote = (existingNote ? existingNote + '\n' : '') + '[Redo: ' + new Date().toLocaleDateString() + ']: ' + reason;
    tSheet.getRange(prevTaskRowIdx, notesCol + 1).setValue(newNote);
  }

  // Set current task back to Waiting
  tSheet.getRange(targetRowIdx, statusCol + 1).setValue('Waiting');

  return {
    success: true,
    message: 'Task successfully sent back to ' + prevStageName + ' for redo.'
  };
}

function copyDevDocContentForward(sourceDocUrl, targetDocUrl, sourceStageName, targetStageName) {
  if (!sourceDocUrl || !targetDocUrl || sourceDocUrl === targetDocUrl) return;
  var sMatch = sourceDocUrl.match(/[-\w]{25,}/);
  var tMatch = targetDocUrl.match(/[-\w]{25,}/);
  if (!sMatch || !tMatch) return;

  try {
    var sourceDoc = DocumentApp.openById(sMatch[0]);
    var targetDoc = DocumentApp.openById(tMatch[0]);
    var sBody = sourceDoc.getBody();
    var tBody = targetDoc.getBody();

    // Prevent duplicate handover if already copied
    if (tBody.getText().indexOf('Handover from Previous Stage: ' + sourceStageName) !== -1) {
      return;
    }

    // Append a distinct sub-heading in the next document with predecessor's work
    tBody.appendParagraph('\n==================================================');
    tBody.appendParagraph('Handover from Previous Stage: ' + sourceStageName).setHeading(DocumentApp.ParagraphHeading.HEADING2);
    tBody.appendParagraph('Submitted on: ' + new Date().toLocaleString());
    tBody.appendParagraph('--------------------------------------------------\n');

    var numChildren = sBody.getNumChildren();
    for (var i = 0; i < numChildren; i++) {
      var elem = sBody.getChild(i).copy();
      var type = elem.getType();
      if (type == DocumentApp.ElementType.PARAGRAPH) {
        tBody.appendParagraph(elem.asParagraph());
      } else if (type == DocumentApp.ElementType.TABLE) {
        tBody.appendTable(elem.asTable());
      } else if (type == DocumentApp.ElementType.LIST_ITEM) {
        tBody.appendListItem(elem.asListItem());
      }
    }

    targetDoc.saveAndClose();
  } catch(e) {}
}

function handleGetDevUsers() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  ensureDevSheets(ss);
  var devUsersSheet = ss.getSheetByName(DEV_USERS_SHEET);
  
  if (!devUsersSheet || devUsersSheet.getLastRow() < 2) {
    // If Dev_Users sheet is empty, fall back to social media users so UI remains functional
    return handleGetUsers();
  }

  var usersData = devUsersSheet.getDataRange().getValues();
  var tasksData = [];
  var tSheet = ss.getSheetByName(DEV_TASKS_SHEET);
  if (tSheet && tSheet.getLastRow() >= 2) {
    tasksData = tSheet.getDataRange().getValues();
  }

  // Count active tasks per user in Development
  var activeCounts = {};
  for (var t = 1; t < tasksData.length; t++) {
    var assigneeEmail = tasksData[t][4]; // AssigneeEmail
    var status = tasksData[t][5]; // Status
    if (assigneeEmail && status !== 'Done') {
      var eKey = assigneeEmail.toString().trim().toLowerCase();
      activeCounts[eKey] = (activeCounts[eKey] || 0) + 1;
    }
  }

  var users = [];
  var devEmailSet = {};
  for (var i = 1; i < usersData.length; i++) {
    var raw0 = (usersData[i][0] || '').toString().trim();
    var raw1 = (usersData[i][1] || '').toString().trim();
    var email = raw0.indexOf('@') !== -1 ? raw0 : (raw1.indexOf('@') !== -1 ? raw1 : raw0);
    var name = raw0.indexOf('@') !== -1 ? raw1 : raw0;
    if (!name) name = email;
    var role = usersData[i][2] ? usersData[i][2].toString().trim() : '';
    var category = usersData[i][3] ? usersData[i][3].toString().trim() : '';
    var activeTasks = activeCounts[email.toLowerCase()] || 0;

    if (email) {
      users.push({
        email: email,
        username: email,
        name: name || email,
        role: role,
        category: category,
        status: activeTasks > 0 ? 'Engaged' : 'Available',
        activeTasks: activeTasks
      });
      devEmailSet[email.toLowerCase()] = true;
    }
  }

  // Also include any users from main Users sheet that aren't already in Dev_Users
  var smUsersSheet = ss.getSheetByName(USERS_SHEET);
  if (smUsersSheet && smUsersSheet.getLastRow() >= 2) {
    var smData = smUsersSheet.getDataRange().getValues();
    for (var j = 1; j < smData.length; j++) {
      var sEmail = (smData[j][0] || '').toString().trim();
      var sName = (smData[j][1] || '').toString().trim();
      var sRole = (smData[j][2] || '').toString().trim();
      if (sEmail && !devEmailSet[sEmail.toLowerCase()]) {
        var aCount = activeCounts[sEmail.toLowerCase()] || 0;
        users.push({
          email: sEmail,
          username: sEmail,
          name: sName || sEmail,
          role: sRole,
          category: 'All',
          status: aCount > 0 ? 'Engaged' : 'Available',
          activeTasks: aCount
        });
        devEmailSet[sEmail.toLowerCase()] = true;
      }
    }
  }

  return { success: true, users: users };
}

function handleDeleteDevProject(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  ensureDevSheets(ss);
  var pSheet = ss.getSheetByName(DEV_PROJECTS_SHEET);
  var tSheet = ss.getSheetByName(DEV_TASKS_SHEET);
  
  var projectId = (payload.projectId || '').toString().trim();
  if (!projectId) return { success: false, message: 'projectId required' };
  
  // 1. Delete all tasks for this projectId from DEV_TASKS_SHEET
  var deletedTasks = 0;
  if (tSheet && tSheet.getLastRow() >= 2) {
    var tData = tSheet.getDataRange().getValues();
    var pIdCol = tData[0].indexOf('ProjectID');
    if (pIdCol !== -1) {
      for (var t = tData.length - 1; t >= 1; t--) {
        if ((tData[t][pIdCol] || '').toString().trim() === projectId) {
          tSheet.deleteRow(t + 1);
          deletedTasks++;
        }
      }
    }
  }
  
  // 2. Delete the project row from DEV_PROJECTS_SHEET
  var deletedProject = false;
  if (pSheet && pSheet.getLastRow() >= 2) {
    var pData = pSheet.getDataRange().getValues();
    var projIdCol = pData[0].indexOf('ProjectID');
    if (projIdCol !== -1) {
      for (var p = pData.length - 1; p >= 1; p--) {
        if ((pData[p][projIdCol] || '').toString().trim() === projectId) {
          pSheet.deleteRow(p + 1);
          deletedProject = true;
          break;
        }
      }
    }
  }
  
  return {
    success: true,
    message: 'Project ' + projectId + ' and ' + deletedTasks + ' tasks deleted successfully.'
  };
}

