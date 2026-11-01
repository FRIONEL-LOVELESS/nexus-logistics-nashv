// NEXUS INTAKE // TELEMETRY WEBHOOK (public, doPost only)
// Don't press Run in the editor: e only exists on a real web request.

function doGet() {
  return ContentService.createTextOutput(JSON.stringify({
    status: "online",
    message: "Nexus Intake webhook is up. Send a POST with a JSON body."
  })).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      throw new Error("No POST body received.");
    }
    const payload = JSON.parse(e.postData.contents);
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
    console.error("Nexus Intake rejected payload:", error.message);
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: "Payload rejected by Nexus Intake.",
      detail: error.message
    })).setMimeType(ContentService.MimeType.JSON);
  }
}
