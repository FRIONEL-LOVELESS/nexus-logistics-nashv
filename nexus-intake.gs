// ============================================================================
// NEXUS INTAKE // DRIVE FILE RELAY (Google Apps Script: nexus-intake.gs)
// Live project: "Drive File Relay" -> web app "Nexus Intake Console" (v2)
// doGet  : serves Index.html (RELAY CONSOLE)
// doPost : telemetry webhook
// ============================================================================

var INTAKE_ID = '15D10kUiVSabgNS1kx6vwQ_afLUsIvw61';
var DEST_ID = '1rTIfH5QIcHgWEGrN7gcHlvCPaWVau_S-';
// Satellite addresses are redacted in this public copy; the live Apps Script holds the real ones.
var SATELLITE_1 = 'SATELLITE_EMAIL_1';
var SATELLITE_2 = 'SATELLITE_EMAIL_2';
var SATELLITE_3 = 'SATELLITE_EMAIL_3';
var SATELLITE_4 = 'SATELLITE_EMAIL_4';

function doGet(){return HtmlService.createHtmlOutputFromFile('Index').setTitle('NEXUS INTAKE // COMMAND CONSOLE').setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL).addMetaTag('viewport','width=device-width, initial-scale=1');}
function getRelayStats(){try{var intake=DriveApp.getFolderById(INTAKE_ID);var files=intake.getFiles();var count=0;while(files.hasNext()){files.next();count=count+1;}return{pendingCount:count};}catch(e){return{pendingCount:0,error:e.message};}}
function executeManualBatch(){var intake=DriveApp.getFolderById(INTAKE_ID);var dest=DriveApp.getFolderById(DEST_ID);var files=intake.getFiles();var count=0;var details=[];while(files.hasNext()){var file=files.next();var name=file.getName();try{file.addEditor(SATELLITE_1);file.addEditor(SATELLITE_2);file.addEditor(SATELLITE_3);file.addEditor(SATELLITE_4);file.moveTo(dest);count=count+1;details.push('Moved: '+name);}catch(err){details.push('Err: '+name);}}try{intake.addEditor(SATELLITE_1);intake.addEditor(SATELLITE_2);intake.addEditor(SATELLITE_3);intake.addEditor(SATELLITE_4);}catch(e){}return{summary:'Routed '+count+' file(s) to HQ.',details:details};}
function runDriveRelayPipeline(){executeManualBatch();}

// ============================================================================
// NEXUS INTAKE ROUTING // TELEMETRY WEBHOOK (doPost)
// Architecture: Music City, U.S.A. Fidelity SPU
// ============================================================================
function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);

    // Orlando Sheriff & Donelson Monetization Telemetry Log
    console.log("TELEMETRY LOG INITIATED");
    console.log("Source Node:", payload.telemetryNode || "Unknown");
    console.log("Tracking Ledger:", payload.trackingLedger || "Unknown");
    console.log("Asset ID:", "1ndrz2aXePS6XWnwN5_cidfkurWXIOPzG");

    return ContentService.createTextOutput(JSON.stringify({
      status: "success",
      grade: "Music City SPU",
      message: "Intake routing complete. Telemetry logged."
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: "Payload rejected by Nexus Intake."
    })).setMimeType(ContentService.MimeType.JSON);
  }
}
