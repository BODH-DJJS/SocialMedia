function generateStateWiseTables() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const inputSheet = ss.getSheetByName("Events");

  // SAFE output sheet
  let outputSheet = ss.getSheetByName("State wise combine Report");
  if (!outputSheet) {
    outputSheet = ss.insertSheet("State wise combine Report");
  }

  // Clear output
  outputSheet.clear();

  // Read headers (row 1) and data (from row 3)
  const lastRow = inputSheet.getLastRow();
  const lastCol = inputSheet.getLastColumn();
  const headersRaw = inputSheet.getRange(2, 1, 1, lastCol).getValues()[0];
  const dataRaw = lastRow >= 4 ? inputSheet.getRange(4, 1, lastRow - 3, lastCol).getValues() : [];

  // Helpers
  const norm = s => String(s || "")
    .replace(/\u00A0/g, " ")
    .toLowerCase()
    .replace(/\s*\|\s*/g, " | ")
    .replace(/\s+/g, " ")
    .trim();

  const headers = headersRaw.map(norm);

  const findCol = (candidates) => {
    const cand = candidates.map(norm);
    for (let i = 0; i < headers.length; i++) {
      for (let j = 0; j < cand.length; j++) {
        if (headers[i] === cand[j]) return i;
      }
    }
    for (let i = 0; i < headers.length; i++) {
      for (let j = 0; j < cand.length; j++) {
        if (headers[i].includes(cand[j])) return i;
      }
    }
    return -1;
  };

  // Candidate names
  const stateCol = findCol(["राज्य | state", "state | राज्य", "राज्य", "state"]);
  const branchCol = findCol(["शाखा | branch", "branch | शाखा", "शाखा", "branch"]);
  const activityCol = findCol(["activity type", "program type", "activity", "type"]);
  let beneficiaryCol = findCol([
    "total beneficiary", "total beneficiaries", "beneficiary total",
    "total (beneficiary)", "total (male+female+children)", "total ben"
  ]);

  const maleCol = findCol(["पुरुष male", "male", "पुरुष"]);
  const femaleCol = findCol(["महिलाएं female", "female", "महिलाएं", "महिला"]);
  const childrenCol = findCol(["बच्चे children", "children", "बच्चे", "child", "kids"]);

  // 🔥 DATE COLUMN (ONLY ADDITION)
  const dateCol = findCol(["date", "event date", "program date"]);

  if (stateCol === -1 || branchCol === -1 || activityCol === -1) {
    throw new Error("Required columns not found. Make sure State, Branch, and Activity Type headers exist.");
  }

  const computeBeneficiaryFromMFC =
    beneficiaryCol === -1 && (maleCol !== -1 || femaleCol !== -1 || childrenCol !== -1);

  // ================= DATE FILTER =================
  const START_DATE = new Date("2026-04-01"); // change if required
  const END_DATE = new Date("2026-08-31");

  const data = dataRaw.filter(r => {
    if (dateCol === -1) return true; // if date col missing, don't filter

    const d = new Date(r[dateCol]);
    if (isNaN(d)) return false;

    return d >= START_DATE && d <= END_DATE;
  });
  // ===============================================

  const states = [...new Set(data.map(r => r[stateCol]).filter(v => v !== ""))].sort();

  let outRow = 1;

  // --- Fixed Activities ---
  const fixedActivities = [
    "Community Awareness Program",
    "Mass Sensitization Program",
    "Youth Awareness Workshop",
    "Counseling & Treatment",
    "Workplace Awareness Program",
    "Training Workshops",
    "Projects in Collaboration"
  ];

  // ========== PER STATE REPORT ==========
  const grandTotals = {}; // for combined table

  states.forEach(state => {

    // --- Heading ---
    outputSheet.getRange(outRow, 1).setValue("Sankalp - State/Branch Review Sheet")
      .setFontWeight("bold").setFontSize(14)
      .setHorizontalAlignment("center").setVerticalAlignment("middle");
    outputSheet.getRange(outRow, 1, 1, fixedActivities.length + 3).merge();
    outRow++;

    outputSheet.getRange(outRow, 1).setValue("Duration: 1-Apr-2026 - 31-Aug-2026")
      .setFontWeight("bold").setFontSize(11)
      .setHorizontalAlignment("center").setVerticalAlignment("middle");
    outputSheet.getRange(outRow, 1, 1, fixedActivities.length + 3).merge();
    outRow++;

    outputSheet.getRange(outRow, 1).setValue("State - " + state)
      .setFontWeight("bold").setFontSize(12)
      .setBackground("#cfe2f3")
      .setHorizontalAlignment("center").setVerticalAlignment("middle");
    outputSheet.getRange(outRow, 1, 1, fixedActivities.length + 3).merge();
    outRow++;

    // --- Headers ---
    const mainHeader = ["Branch", "Activity Type",
      ...Array(fixedActivities.length - 1).fill(""),
      "Total Events", "Total Beneficiary"];

    outputSheet.getRange(outRow, 1, 1, mainHeader.length)
      .setValues([mainHeader]).setFontWeight("bold")
      .setBackground("#ead1dc")
      .setHorizontalAlignment("center").setVerticalAlignment("middle");

    outputSheet.getRange(outRow, 2, 1, fixedActivities.length).merge();
    outputSheet.getRange(outRow, 1, 2, 1).merge();
    outputSheet.getRange(outRow, fixedActivities.length + 2, 2, 1).merge();
    outputSheet.getRange(outRow, fixedActivities.length + 3, 2, 1).merge();
    outRow++;

    const subHeader = ["", ...fixedActivities, "", ""];
    outputSheet.getRange(outRow, 1, 1, subHeader.length)
      .setValues([subHeader]).setFontWeight("bold")
      .setBackground("#ead1dc")
      .setHorizontalAlignment("center")
      .setVerticalAlignment("middle")
      .setWrap(true);
    outRow++;

    // --- Group Data ---
    const stateRows = data.filter(r => r[stateCol] === state);
    const branchMap = {};

    stateRows.forEach(r => {
      const branch = r[branchCol] || "";
      if (!branch) return;

      const act = r[activityCol] ? String(r[activityCol]).trim() : "";

      const ben = beneficiaryCol !== -1
        ? Number(r[beneficiaryCol]) || 0
        : (computeBeneficiaryFromMFC
          ? (Number(r[maleCol] || 0)
            + Number(r[femaleCol] || 0)
            + Number(r[childrenCol] || 0))
          : 0);

      if (!branchMap[branch]) {
        branchMap[branch] = { totalBen: 0, events: 0 };
        fixedActivities.forEach(a => branchMap[branch][a] = 0);
      }

      if (fixedActivities.includes(act)) {
        branchMap[branch][act] += 1;
      }

      branchMap[branch].events += 1;
      branchMap[branch].totalBen += ben;
    });

    const branches = Object.keys(branchMap).sort();
    const totals = { events: 0, totalBen: 0 };
    fixedActivities.forEach(a => totals[a] = 0);

    branches.forEach(br => {
      const rowData = [br];
      fixedActivities.forEach(a => {
        rowData.push(branchMap[br][a] || 0);
        totals[a] += branchMap[br][a] || 0;
      });

      rowData.push(branchMap[br].events);
      rowData.push(branchMap[br].totalBen);

      totals.events += branchMap[br].events;
      totals.totalBen += branchMap[br].totalBen;

      outputSheet.getRange(outRow, 1, 1, rowData.length)
        .setValues([rowData])
        .setHorizontalAlignment("center")
        .setVerticalAlignment("middle");
      outRow++;
    });

    // Totals Row
    const totalRow = ["TOTAL"];
    fixedActivities.forEach(a => totalRow.push(totals[a]));
    totalRow.push(totals.events);
    totalRow.push(totals.totalBen);

    outputSheet.getRange(outRow, 1, 1, totalRow.length)
      .setValues([totalRow])
      .setFontWeight("bold")
      .setBackground("#d9ead3")
      .setHorizontalAlignment("center")
      .setVerticalAlignment("middle");

    grandTotals[state] = { branches: branchMap, totals: totals };

    const startRow = outRow - branches.length - 2;
    const endRow = outRow;
    outputSheet.getRange(startRow, 1,
      endRow - startRow + 1,
      fixedActivities.length + 3)
      .setBorder(true, true, true, true, true, true);

    outRow += 3;
  });

  // ========== COMBINED REPORT ==========
  outputSheet.getRange(outRow, 1)
    .setValue("Sankalp - Combined State/Branch Review Sheet")
    .setFontWeight("bold")
    .setFontSize(14)
    .setHorizontalAlignment("center");
  outputSheet.getRange(outRow, 1, 1, fixedActivities.length + 3).merge();
  outRow++;

  outputSheet.getRange(outRow, 1)
    .setValue("Duration: 1-Apr-2026 - 31-Aug-2026")
    .setFontWeight("bold")
    .setFontSize(11)
    .setHorizontalAlignment("center");
  outputSheet.getRange(outRow, 1, 1, fixedActivities.length + 3).merge();
  outRow++;

  const mainHeader2 = ["State/Branch", "Activity Type",
    ...Array(fixedActivities.length - 1).fill(""),
    "Total Events", "Total Beneficiary"];

  outputSheet.getRange(outRow, 1, 1, mainHeader2.length)
    .setValues([mainHeader2])
    .setFontWeight("bold")
    .setBackground("#ead1dc")
    .setHorizontalAlignment("center");

  outputSheet.getRange(outRow, 2, 1, fixedActivities.length).merge();
  outputSheet.getRange(outRow, 1, 2, 1).merge();
  outputSheet.getRange(outRow, fixedActivities.length + 2, 2, 1).merge();
  outputSheet.getRange(outRow, fixedActivities.length + 3, 2, 1).merge();
  outRow++;

  const subHeader2 = ["", ...fixedActivities, "", ""];
  outputSheet.getRange(outRow, 1, 1, subHeader2.length)
    .setValues([subHeader2])
    .setFontWeight("bold")
    .setBackground("#ead1dc")
    .setHorizontalAlignment("center")
    .setWrap(true);
  outRow++;

  let combinedTotals = { events: 0, totalBen: 0 };
  fixedActivities.forEach(a => combinedTotals[a] = 0);

  Object.keys(grandTotals).forEach(state => {
    const stateData = grandTotals[state];

    Object.keys(stateData.branches).sort().forEach(br => {
      const b = stateData.branches[br];
      const rowData = [br];
      fixedActivities.forEach(a => rowData.push(b[a] || 0));
      rowData.push(b.events);
      rowData.push(b.totalBen);

      outputSheet.getRange(outRow, 1, 1, rowData.length)
        .setValues([rowData])
        .setHorizontalAlignment("center");
      outRow++;
    });

    const st = stateData.totals;
    const totalRow = [state + " TOTAL"];

    fixedActivities.forEach(a => {
      totalRow.push(st[a]);
      combinedTotals[a] += st[a];
    });

    totalRow.push(st.events);
    totalRow.push(st.totalBen);
    combinedTotals.events += st.events;
    combinedTotals.totalBen += st.totalBen;

    outputSheet.getRange(outRow, 1, 1, totalRow.length)
      .setValues([totalRow])
      .setFontWeight("bold")
      .setBackground("#d9ead3")
      .setHorizontalAlignment("center");
    outRow++;

    outRow++;
  });

  const grandRow = ["GRAND TOTAL"];
  fixedActivities.forEach(a => grandRow.push(combinedTotals[a]));
  grandRow.push(combinedTotals.events);
  grandRow.push(combinedTotals.totalBen);

  outputSheet.getRange(outRow, 1, 1, grandRow.length)
    .setValues([grandRow])
    .setFontWeight("bold")
    .setBackground("#ffe599")
    .setHorizontalAlignment("center");

  outputSheet.autoResizeColumns(1, outputSheet.getLastColumn());
}
