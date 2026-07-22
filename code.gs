var POSTS_SHEET = 'Events';
var TASKS_SHEET = 'Tasks';
var USERS_SHEET = 'Users';
var PIPELINE_SHEET = 'Pipeline Config';
var BRANCH_SPOC_SHEET = 'Branch SPOC';

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
    {role: 'Uploader', prefix: 'uploader'}
  ];

  for (var r = 0; r < roles.length; r++) {
    var count = roleCounts[roles[r].role] || 0;
    // Add users until we have at least 5 for this role
    var suffix = count + 1;
    while (count < 5) {
      usersSheet.appendRow([roles[r].prefix + suffix, 'Sample ' + roles[r].role + ' ' + suffix, roles[r].role]);
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
    {stage: 'Cross check', role: 'CrossChecker', dep: 'Proofreading'},
    {stage: 'Thumbnail Selection', role: 'Thumbnail Designer', dep: ''},
    {stage: 'Thumbnail Processing', role: 'Thumbnail Designer', dep: 'Thumbnail Selection'},
    {stage: 'Thumbnail Cross checking', role: 'Thumbnail Designer', dep: 'Thumbnail Processing'},
    {stage: 'Photos Selection', role: 'Photo Selector', dep: ''},
    {stage: 'Photos Clean', role: 'Photo Selector', dep: 'Photos Selection'},
    {stage: 'Photo Editing', role: 'Photo Editor', dep: 'Photos Selection'},
    {stage: 'Video Editing', role: 'Video Editor', dep: 'Photos Selection'},
    {stage: 'Media Cross Check', role: 'Media CrossChecker', dep: 'Photo Editing, Video Editing'},
    {stage: 'Ready to Post', role: 'Uploader', dep: 'Cross check'}
  ];
  
  var existingPipeData = pipeSheet.getDataRange().getValues();
  var existingStages = [];
  for (var i = 1; i < existingPipeData.length; i++) {
    existingStages.push((existingPipeData[i][0] || '').toString().toLowerCase());
  }
  
  for (var r = 0; r < requiredStages.length; r++) {
    if (existingStages.indexOf(requiredStages[r].stage.toLowerCase()) === -1) {
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
    } else if (action === 'getMediaFolders') {
      return respond(handleGetMediaFolders(payload));
    } else if (action === 'getPhotos') {
      return respond(handleGetPhotos(payload));
    } else if (action === 'updateTask') {
      var lock = LockService.getScriptLock();
      lock.waitLock(10000);
      try {
        var res = handleUpdateTask(payload);
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
    } else if (action === 'createTasksForPostV2') {
      var lock = LockService.getScriptLock();
      lock.waitLock(15000);
      try {
        var res = createTasksForPostV2(payload);
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
    'Description': pRow[39] || ''
  };
}

function backfillMissingTasks(ss) {
  var tasksSheet = ss.getSheetByName(TASKS_SHEET);
  var pipeSheet = ss.getSheetByName(PIPELINE_SHEET);
  if (!tasksSheet || !pipeSheet) return false;
  
  var tasksData = tasksSheet.getDataRange().getValues();
  if (tasksData.length < 2) return false;

  var pipeData = pipeSheet.getDataRange().getValues();
  
  var requiredStages = [];
  var normalizedRequired = [];
  for (var p = 1; p < pipeData.length; p++) {
    if (pipeData[p][0]) {
      var st = pipeData[p][0].toString().trim();
      requiredStages.push(st);
      normalizedRequired.push(st.toLowerCase().replace(/[^a-z0-9]/g, ''));
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
      postTasks[pNo].push(st.toString().toLowerCase().replace(/[^a-z0-9]/g, ''));
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
      for (var r = 0; r < requiredStages.length; r++) {
        var reqStage = requiredStages[r];
        var normReq = normalizedRequired[r];
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

function handleGetTasks(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  
  // Auto-backfill missing tasks for active posts before returning data
  var didBackfill = backfillMissingTasks(ss);
  
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
  
  var taskHeaders = tasksData[0];
  var resultTasks = [];
  
  for (var i = 1; i < tasksData.length; i++) {
    var trow = tasksData[i];
    var tObj = {};
    for (var j = 0; j < taskHeaders.length; j++) {
      var val = trow[j];
      var headerName = taskHeaders[j].toString();
      
      if (val instanceof Date || (headerName === 'DueDate' && val) || (headerName === 'AllottedDate' && val) || (headerName === 'Date' && val)) {
        tObj[taskHeaders[j]] = formatDate(val);
      } else {
        tObj[taskHeaders[j]] = val;
      }
    }
    tObj['rowIndex'] = i + 1;
    tObj['AssigneeName'] = userMap[(tObj['Assignee'] || '').toString().trim().toLowerCase()] || tObj['Assignee'];
    
    if (payload.role === 'Admin' || tObj['Assignee'] === payload.username) {
      var matchedRows = postsData.filter(function(r, idx) { 
        return idx > 0 && (r[0] == tObj['PostNo'] || r[37] == tObj['PostNo']); 
      });

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
        tObj['Theme'] = 'Combined Group (' + matchedRows.length + ' posts)';
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
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var postsData = ss.getSheetByName(POSTS_SHEET).getDataRange().getValues();
  if (postsData.length < 2) return { success: true, posts: [] };
  
  var posts = [];
  for (var i = 1; i < postsData.length; i++) {
    var pRow = postsData[i];
    if (!pRow[0]) continue;
    posts.push(buildPostObj(pRow));
  }
  return { success: true, posts: posts.reverse() };
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

function handleUpdateTask(payload) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(TASKS_SHEET);
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

    // Unlock any task that depends on this one
    try {
      unlockDependentTasks(rowIndex, headers, sheet);
    } catch (e) {
      // Fail silently if unlocking fails
    }
  }

  for (var key in updates) {
    var colIndex = headers.indexOf(key);
    if (colIndex !== -1) {
      sheet.getRange(rowIndex, colIndex + 1).setValue(updates[key]);
    }
  }
  return { success: true, message: 'Task updated successfully' };
}

function unlockDependentTasks(rowIndex, headers, taskSheet) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var pipe = ss.getSheetByName(PIPELINE_SHEET).getDataRange().getValues();
  var data = taskSheet.getDataRange().getValues();

  var currentStage = data[rowIndex - 1][headers.indexOf('Stage')];
  var postNo = data[rowIndex - 1][headers.indexOf('PostNo')];

  var dependentStages = [];
  var currentStageLower = (currentStage || '').replace(/\s+/g, '').toLowerCase();

  // Find all stages that depend on currentStage
  for (var i = 1; i < pipe.length; i++) {
    var deps = (pipe[i][2] || '').toString().toLowerCase().split(',');
    for (var d = 0; d < deps.length; d++) {
      if (deps[d].replace(/\s+/g, '') === currentStageLower) {
        dependentStages.push((pipe[i][0] || '').replace(/\s+/g, '').toLowerCase());
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
        stage: (data[i][stageCol] || '').replace(/\s+/g, '').toLowerCase(), 
        status: data[i][statusCol]
      });
    }
  }

  // For each dependent stage, check if ALL its dependencies are Done (only for tasks that exist)
  for (var d = 0; d < dependentStages.length; d++) {
    var depStageLower = dependentStages[d];
    
    // Find the task for this dependent stage
    var targetTask = null;
    for (var p = 0; p < postTasks.length; p++) {
      if (postTasks[p].stage === depStageLower) {
        targetTask = postTasks[p];
        break;
      }
    }
    
    if (targetTask && (targetTask.status === 'Waiting' || !targetTask.status)) {
      // Find its required dependencies from pipe
      var requiredDeps = [];
      for (var i = 1; i < pipe.length; i++) {
        if ((pipe[i][0] || '').replace(/\s+/g, '').toLowerCase() === depStageLower) {
          requiredDeps = (pipe[i][2] || '').toString().toLowerCase().split(',');
          for (var r = 0; r < requiredDeps.length; r++) {
            requiredDeps[r] = requiredDeps[r].replace(/\s+/g, '');
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

  var stageOrder = ['Writing', 'Editing', 'Proofreading', 'Crosscheck'];
  var stageOrderLower = ['writing', 'editing', 'proofreading', 'crosscheck'];
  var currentStageLower = (currentStage || '').replace(/\s+/g, '').toLowerCase();
  var currentIdx = stageOrderLower.indexOf(currentStageLower);
  if (currentIdx === -1 || currentIdx >= stageOrderLower.length - 1) return;
  var nextStage = stageOrder[currentIdx + 1];

  // Find the next stage row and get its document link
  var nextDocUrl = '';
  var nextRowIdx = -1;
  var nextStageLower = nextStage.replace(/\s+/g, '').toLowerCase(); // Normalize
  for (var i = 1; i < data.length; i++) {
    var iterStageLower = (data[i][stageCol] || '').replace(/\s+/g, '').toLowerCase();
    if (data[i][postNoCol] == postNo && iterStageLower === nextStageLower) {
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
        
        // Clear out the next doc except for the very first paragraph
        try {
          var numNextChildren = nextBody.getNumChildren();
          while (numNextChildren > 1) {
            nextBody.removeChild(nextBody.getChild(numNextChildren - 1));
            numNextChildren--;
          }
        } catch(e) {}
        
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
          var prevStageLower = prevStageName.toLowerCase();
          var prevDocUrl = '';
          
          for (var r = 1; r < data.length; r++) {
            var iterStageLower = (data[r][stageCol] || '').replace(/\s+/g, '').toLowerCase();
            if (data[r][postNoCol] == postNo && iterStageLower === prevStageLower) {
              prevDocUrl = data[r][docLinkCol] || '';
              break;
            }
          }
          
          if (prevDocUrl && prevDocUrl.indexOf('document/d/') !== -1) {
            var prevDocIdMatch = prevDocUrl.match(/[-\w]{25,}/);
            if (prevDocIdMatch) {
              appendDocContent(prevDocIdMatch[0], prevStageName);
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

        // Find or create date folder
        var dateFolder = null;
        var dateFolders = monthFolder.searchFolders("title = '" + dateStr + "'");
        if (dateFolders.hasNext()) {
          dateFolder = dateFolders.next();
        } else {
          dateFolder = monthFolder.createFolder(dateStr);
        }

        // Create subfolders if not exist
        var subfolderNames = ['Raw', 'Selected', 'Selected (Edited)'];
        for (var s = 0; s < subfolderNames.length; s++) {
          var sfName = subfolderNames[s];
          var sfSearch = dateFolder.searchFolders("title = '" + sfName + "'");
          if (!sfSearch.hasNext()) {
            var newSf = dateFolder.createFolder(sfName);
            newSf.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT);
            if (sfName === 'Raw') rawFolderUrl = newSf.getUrl();
          } else {
            if (sfName === 'Raw') rawFolderUrl = sfSearch.next().getUrl();
          }
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
  var result = { raw: '', edited: '' };

  if (!monthLink || monthLink.indexOf('drive.google.com') === -1) {
    return { success: true, folders: result };
  }

  var match = monthLink.match(/[-\w]{25,}/);
  if (!match) return { success: true, folders: result };

  var monthFolderId = match[0];
  try {
    var monthFolder = DriveApp.getFolderById(monthFolderId);

    var targetFolderName = dateStr;
    if (payload.venue) {
       targetFolderName = dateStr + ' - ' + payload.venue;
    }

    var dateFolder = null;
    var folders = monthFolder.getFolders();
    
    // First try exact match with venue, if not found try just date
    while (folders.hasNext()) {
      var f = folders.next();
      var fn = f.getName().toLowerCase();
      if (fn === targetFolderName.toLowerCase()) {
        dateFolder = f;
        break;
      }
    }
    
    // Fallback to just date match if specific venue folder not found
    if (!dateFolder) {
      var folders2 = monthFolder.getFolders();
      while (folders2.hasNext()) {
        var f2 = folders2.next();
        var fn2 = f2.getName().toLowerCase();
        if (fn2 === dateStr.toLowerCase()) {
          dateFolder = f2;
          break;
        }
      }
    }

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
        }
      }
    }
  } catch (e) {}

  return { success: true, folders: result };
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
      updated++;
    }
  }
  return { success: true, message: updated + ' posts grouped under ' + groupId };
}

function handleUngroupPost(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(POSTS_SHEET);
  var data = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    if (data[i][0] == payload.postNo) {
      sheet.getRange(i + 1, 38).setValue(''); // Clear GroupID
      return { success: true, message: 'Post ungrouped' };
    }
  }
  return { success: false, message: 'Post not found' };
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

  // Check duplicates
  for (var t = 1; t < existingTasks.length; t++) {
    if (existingTasks[t][1] == postNo) {
      return {success: false, message: 'Tasks already exist for ' + postNo};
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
    var leaderPost = groupPosts[0];
    var monthFolderLink = leaderPost[21] || leaderPost[20] || '';

    if (monthFolderLink && monthFolderLink.indexOf('drive.google.com') !== -1) {
      var match = monthFolderLink.match(/[-\w]{25,}/);
      if (match) {
        try {
          var monthFolder = DriveApp.getFolderById(match[0]);

          // First, count occurrences of each date in the group
          var dateCounts = {};
          for (var i = 0; i < groupPosts.length; i++) {
            var dStr = formatDate(groupPosts[i][6]);
            dateCounts[dStr] = (dateCounts[dStr] || 0) + 1;
          }

          for (var gp = 0; gp < groupPosts.length; gp++) {
            var currPost = groupPosts[gp];
            var cDateStr = formatDate(currPost[6]);
            var cVenue = currPost[4] || '';
            // Only append venue if this date appears more than once in the group
            var cDateFolderTitle = (dateCounts[cDateStr] > 1 && cVenue) ? (cDateStr + ' - ' + cVenue) : cDateStr;

            // Find or create date folder for this specific venue/post
            var dateFolder = null;
            var dateFolders = monthFolder.getFolders();
            var searchStr = cDateFolderTitle.toLowerCase();
            while (dateFolders.hasNext()) {
              var df = dateFolders.next();
              var fn = df.getName().toLowerCase();
              if (fn === searchStr) {
                dateFolder = df;
                break;
              }
            }
            if (!dateFolder) dateFolder = monthFolder.createFolder(cDateFolderTitle);

            // Create subfolders inside this post's folder
            var subfolderNames = (gp === 0) ? ['Raw', 'Selected', 'Selected (Edited)'] : ['Raw', 'Selected'];
            for (var s = 0; s < subfolderNames.length; s++) {
              var sfName = subfolderNames[s];
              var exists = false;
              var sfs = dateFolder.getFolders();
              while (sfs.hasNext()) {
                if (sfs.next().getName().toLowerCase() === sfName.toLowerCase()) { exists = true; break; }
              }
              if (!exists) {
                var newSf = dateFolder.createFolder(sfName);
                newSf.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT);
              }
            }

            // Create Google Docs for specific stages ONLY in the first post's folder
            if (gp === 0) {
              var docStages = ['Writing', 'Editing', 'Proofreading', 'Crosscheck'];
              for (var d = 0; d < docStages.length; d++) {
                var docStageName = docStages[d];
                var docName = currPost[0] + ' - ' + docStageName;
                var docFound = false;
                var existingFiles = dateFolder.getFiles();
                var foundDocUrl = '';
                while (existingFiles.hasNext()) {
                  var ef = existingFiles.next();
                  if (ef.getName().toLowerCase() === docName.toLowerCase() ||
                      ef.getName().toLowerCase() === (docName + '.docx').toLowerCase() ||
                      ef.getName().toLowerCase() === docStageName.toLowerCase()) {
                    foundDocUrl = ef.getUrl();
                    docFound = true;
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

                    body.appendParagraph('Post: ' + currPost[0] + ' | ' + docStageName + ' Document').setHeading(DocumentApp.ParagraphHeading.HEADING1);
                    newDoc.saveAndClose();
                    foundDocUrl = newDocFile.getUrl();
                  } catch (docErr) {
                    foundDocUrl = '';
                  }
                }
                
                docLinks[docStageName.toLowerCase()] = foundDocUrl;
              }
            }
          }
        } catch (driveErr) {
          // Drive failed, continue without docs
        }
      }
    }
  }
  
  // Find column indexes for new headers
  var allottedDateCol = taskHeaders.indexOf('AllottedDate');
  var dueDateCol = taskHeaders.indexOf('DueDate');
  var notesCol = taskHeaders.indexOf('Notes');
  
  // ── Create task rows with admin-specified assignees ──
  var skipStages = [];
  var pubLower = (publishPlatform || '').toLowerCase();
  var modLower = (mediaMode || '').toLowerCase();
  
  if (pubLower.indexOf('insta') === -1) {
    skipStages.push('thumbnailselection', 'thumbnailprocessing', 'thumbnailcrosschecking');
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
    
    var normalizedStage = stage.toString().replace(/\s+/g, '').toLowerCase();
    if (skipStages.indexOf(normalizedStage) !== -1) continue;
    
    var assignee = '';
    for (var k in assignees) {
      if (k.replace(/\s+/g, '').toLowerCase() === normalizedStage) { assignee = assignees[k]; break; }
    }
    
    var docUrl = '';
    for (var k in docLinks) {
      if (k.replace(/\s+/g, '').toLowerCase() === normalizedStage) { docUrl = docLinks[k]; break; }
    }
    
    var initialStatus = 'Waiting';
    if (!depOn || depOn.toString().trim() === '') {
      initialStatus = assignee ? 'Ready' : 'Waiting';
    }
    
    var allottedDate = assignee ? new Date().toLocaleString() : '';
    
    var dueDate = '';
    for (var k in dueDates) {
      if (k.replace(/\s+/g, '').toLowerCase() === normalizedStage) { dueDate = dueDates[k]; break; }
    }
    
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
    
    tasks.appendRow(rowData);
  }
  
  return {success: true, message: 'Tasks created for ' + postNo + ' with assignees, folders, and docs'};
}

function doGet(e) {
  return ContentService.createTextOutput('GET requests not supported, use POST.').setMimeType(ContentService.MimeType.TEXT);
}
