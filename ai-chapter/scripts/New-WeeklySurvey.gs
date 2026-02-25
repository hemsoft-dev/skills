// ============================================================
// SESSION FEEDBACK SURVEY — Google Apps Script
// ai-chapter/scripts/New-WeeklySurvey.gs
//
// SETUP:
//   1. Go to https://script.google.com → New project
//   2. Paste this entire file
//   3. Update the CONFIG section below
//   4. Run createWeeklySurvey() once to authorize and create first form
//   5. Set a weekly trigger: Triggers (clock icon) → Add Trigger
//      → createWeeklySurvey → Time-driven → Week timer → Monday 7–8am
//
// BULK CREATION:
//   To scaffold surveys for multiple weeks ahead, run:
//     createSurveysForNextNWeeks(4)   ← creates next 4 weeks of forms
//   Each form gets its own dated title; all email you the batch summary.
// ============================================================

// ============================================================
// CONFIG — edit these lines only
// ============================================================
var YOUR_EMAIL     = "fphemmer@gmail.com";
var COWORKER_EMAIL = "coworker@example.com";   // ← update this
// ============================================================

// ------------------------------------------------------------
// SINGLE WEEK — called by the weekly trigger
// ------------------------------------------------------------
function createWeeklySurvey() {
  var monday = getMondayOfCurrentWeek();
  var result = createSurveyForDate(monday);

  MailApp.sendEmail({
    to: YOUR_EMAIL,
    cc: COWORKER_EMAIL,
    subject: "Session Feedback Form Ready – " + result.weekLabel,
    body: buildEmailBody([result])
  });

  Logger.log("Form:      " + result.formUrl);
  Logger.log("Responses: " + result.sheetUrl);
}

// ------------------------------------------------------------
// BULK — call manually to scaffold N weeks ahead
// e.g. createSurveysForNextNWeeks(4)
// ------------------------------------------------------------
function createSurveysForNextNWeeks(n) {
  if (!n || n < 1) n = 4;
  var results = [];
  var monday = getMondayOfCurrentWeek();

  for (var i = 0; i < n; i++) {
    var targetMonday = new Date(monday);
    targetMonday.setDate(monday.getDate() + (i * 7));
    var result = createSurveyForDate(targetMonday);
    results.push(result);
    Logger.log("Created: " + result.weekLabel + " → " + result.formUrl);
  }

  MailApp.sendEmail({
    to: YOUR_EMAIL,
    cc: COWORKER_EMAIL,
    subject: "Session Feedback Forms Created – Next " + n + " Weeks",
    body: "Bulk surveys created for the next " + n + " weeks:\n\n" + buildEmailBody(results)
  });
}

// ------------------------------------------------------------
// CORE — creates one form for a given Monday date
// Returns: { weekLabel, formUrl, sheetUrl }
// ------------------------------------------------------------
function createSurveyForDate(monday) {
  var weekLabel = "Week of " + Utilities.formatDate(monday, Session.getScriptTimeZone(), "MMMM d, yyyy");

  var form = FormApp.create("Session Feedback – " + weekLabel);
  form.setDescription("Please take a moment to share your feedback. It helps us improve future sessions.");
  form.setCollectEmail(false);  // No Google login required to submit

  // Q1 — Overall satisfaction
  form.addMultipleChoiceItem()
    .setTitle("How satisfied are you with the session overall?")
    .setRequired(true)
    .setChoiceValues(["Very satisfied", "Satisfied", "Neutral", "Dissatisfied", "Very dissatisfied"]);

  // Q2 — Relevance
  form.addMultipleChoiceItem()
    .setTitle("How relevant was today's topic to you and your work?")
    .setRequired(true)
    .setChoiceValues(["Very relevant", "Somewhat relevant", "Neutral", "Not very relevant", "Not relevant at all"]);

  // Q3 — Takeaway
  form.addMultipleChoiceItem()
    .setTitle("Did you walk away with something you can apply in your day-to-day work?")
    .setRequired(true)
    .setChoiceValues(["Yes", "Somewhat", "Not this time"]);

  // Q4 — Future suggestions
  form.addParagraphTextItem()
    .setTitle("What suggestions do you have for future sessions?");

  // Q5 — General feedback
  form.addParagraphTextItem()
    .setTitle("Do you have any suggestions for improvements or additional feedback?");

  // One master spreadsheet for all responses (created first run, reused after)
  var props = PropertiesService.getScriptProperties();
  var sheetId = props.getProperty("RESPONSES_SHEET_ID");
  if (!sheetId) {
    var ss = SpreadsheetApp.create("Session Feedback – All Responses");
    sheetId = ss.getId();
    props.setProperty("RESPONSES_SHEET_ID", sheetId);
  }
  form.setDestination(FormApp.DestinationType.SPREADSHEET, sheetId);

  return {
    weekLabel: weekLabel,
    formUrl:   form.shortenFormUrl(form.getPublishedUrl()),
    sheetUrl:  "https://docs.google.com/spreadsheets/d/" + sheetId
  };
}

// ------------------------------------------------------------
// HELPERS
// ------------------------------------------------------------
function getMondayOfCurrentWeek() {
  var today = new Date();
  var day = today.getDay();
  var daysToMonday = (day === 0) ? -6 : 1 - day;
  var monday = new Date(today);
  monday.setDate(today.getDate() + daysToMonday);
  monday.setHours(0, 0, 0, 0);
  return monday;
}

function buildEmailBody(results) {
  var lines = [];
  for (var i = 0; i < results.length; i++) {
    var r = results[i];
    lines.push(
      r.weekLabel + "\n" +
      "  Share this link: " + r.formUrl + "\n" +
      "  Responses sheet: " + r.sheetUrl
    );
  }
  return lines.join("\n\n");
}
