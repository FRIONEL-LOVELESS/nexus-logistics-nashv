/**
 * NEXUS LOGISTICS SPU — PART TWO
 * Daily Blogger drafts (Gemini API + Blogger API v3) and Drive intake into the Nexus.
 *
 * SETUP (once, in the Apps Script editor signed in as your-main-account@gmail.com)
 * 1. Project Settings > Script Properties, add:
 *      GEMINI_API_KEY    = free key from aistudio.google.com (no card needed)
 *      BLOG_ID           = the number in your Blogger dashboard URL
 *      NEXUS_FOLDER_ID   = Drive ID of 30_GALBADIA_GARDEN_HQ (source notes)
 *      AIRLOCK_FOLDER_ID = Drive ID of 00_INBOX_AIRLOCK (intake landing zone)
 * 2. Project Settings > "Show appsscript.json", then add:
 *      "oauthScopes": [
 *        "https://www.googleapis.com/auth/blogger",
 *        "https://www.googleapis.com/auth/drive",
 *        "https://www.googleapis.com/auth/documents",
 *        "https://www.googleapis.com/auth/script.external_request",
 *        "https://www.googleapis.com/auth/script.scriptapp"
 *      ]
 * 3. Run installDailyTrigger() once and approve the permissions.
 *
 * Posts are saved as Blogger DRAFTS. Read each one, add your own lines, then
 * hit Publish. Human-edited posts are what AdSense approves.
 */

const CAMPAIGN_DAYS = 45;
const MODEL = 'gemini-2.5-flash';
const SCIENCE_RSS = 'https://www.science.org/rss/news_current.xml';

/* ---------- A-POSITIVE CAMPAIGN: S(x) = A(G(ER) + F(ER))+ ---------- */

function phaseFor_(day) {
  if (day <= 15) {
    return 'Phase G(ER)+, the A+ Industrial Front: Gundam Thunderbolt-style heavy engineering ' +
      'answering the ER threat (Evangelion x R-Type Delta, read through a Black Mesa lens). ' +
      'Earnest, organized optimism about building and maintaining the machines.';
  }
  if (day <= 30) {
    return 'Phase F(ER)+, the A+ Kinetic Front: Olympic fencing as a B-movie series. ' +
      'Human discipline, footwork and nerve over engines.';
  }
  return 'Phase A(...)+, the A+ Constitutional Climax: the full system S(x) = A(G(ER) + F(ER))+, ' +
    'with the Bill of Rights as the wrapper that keeps engines and blades serving people.';
}

function runDailyPost() {
  const p = PropertiesService.getScriptProperties();
  const day = Number(p.getProperty('DAY') || 1);
  if (day > CAMPAIGN_DAYS) { Logger.log('Campaign complete.'); return; }

  const source = pickSourceNote_(p.getProperty('NEXUS_FOLDER_ID'), day);
  const science = latestScience_(3);
  const html = generatePost_(p.getProperty('GEMINI_API_KEY'), day, source, science);

  const h1 = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  const title = 'S(x) Day ' + day + ': ' + (h1 ? h1[1].replace(/<[^>]+>/g, '') : 'Nexus Logistics Dispatch');
  const body = h1 ? html.replace(h1[0], '') : html;

  const post = createBloggerDraft_(p.getProperty('BLOG_ID'), title, body);
  p.setProperty('DAY', String(day + 1));
  Logger.log('Day ' + day + ' draft saved: ' + (post.url || post.id));
}

/** Picks one Doc or text file from the Nexus folder per day, in name order. */
function pickSourceNote_(folderId, day) {
  if (!folderId) return { name: 'none', text: '' };
  const files = [];
  const it = DriveApp.getFolderById(folderId).getFiles();
  while (it.hasNext()) {
    const f = it.next();
    const t = f.getMimeType();
    if (t === MimeType.GOOGLE_DOCS || t === MimeType.PLAIN_TEXT) files.push(f);
  }
  if (!files.length) return { name: 'none', text: '' };
  files.sort(function (a, b) { return a.getName().localeCompare(b.getName()); });
  const f = files[(day - 1) % files.length];
  const text = f.getMimeType() === MimeType.GOOGLE_DOCS
    ? DocumentApp.openById(f.getId()).getBody().getText()
    : f.getBlob().getDataAsString();
  return { name: f.getName(), text: text.slice(0, 6000) };
}

/** Latest Science (AAAS) headlines with links, for real outbound citations. */
function latestScience_(n) {
  try {
    const xml = UrlFetchApp.fetch(SCIENCE_RSS, { muteHttpExceptions: true }).getContentText();
    const root = XmlService.parse(xml).getRootElement();
    const ns = root.getNamespace();
    let items = root.getChild('channel', ns) ? root.getChild('channel', ns).getChildren('item', ns) : [];
    if (!items.length) items = root.getChildren().filter(function (e) { return e.getName() === 'item'; });
    return items.slice(0, n).map(function (it) {
      const get = function (tag) {
        const c = it.getChildren().filter(function (e) { return e.getName() === tag; })[0];
        return c ? c.getText().trim() : '';
      };
      return { title: get('title'), link: get('link'), summary: get('description').replace(/<[^>]+>/g, '').slice(0, 400) };
    });
  } catch (e) {
    Logger.log('Science feed skipped: ' + e);
    return [];
  }
}

function generatePost_(apiKey, day, source, science) {
  const sci = science.map(function (s, i) {
    return (i + 1) + '. ' + s.title + ' | ' + s.link + ' | ' + s.summary;
  }).join('\n');

  const prompt = [
    'Write blog post ' + day + ' of ' + CAMPAIGN_DAYS + ' for Nexus Logistics, a Nashville tech and retro-media blog by Jonathan Kelly.',
    phaseFor_(day),
    'Voice: confident, rhythmic, a little rapper swagger, A-Positive: organized and hopeful even at the end of the world.',
    'Give readers something useful: an IT upgrade that saves household money, a retro-vehicle insight (2002 Infiniti QX4, 2016 Hyundai Elantra), or a sharp take on Evangelion, Gundam: Thunderbolt, R-Type Delta, Black Mesa, or B-movies.',
    'Build from this note from his Drive (' + source.name + '):\n' + (source.text || '(no note today, write from the phase)'),
    sci ? 'Break up the text with 1-2 of these Science headlines as <blockquote> excerpts, each with an <a href> to its link. Use only these, never invent a citation:\n' + sci : '',
    'Output clean HTML only: one <h1> title, short <p> paragraphs, <h2> subheads. No markdown, no code fences.'
  ].join('\n\n');

  const res = UrlFetchApp.fetch(
    'https://generativelanguage.googleapis.com/v1beta/models/' + MODEL + ':generateContent',
    {
      method: 'post',
      contentType: 'application/json',
      headers: { 'x-goog-api-key': apiKey },
      payload: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
      muteHttpExceptions: true
    });
  const json = JSON.parse(res.getContentText());
  if (!json.candidates) throw new Error('Gemini error: ' + res.getContentText());
  return json.candidates[0].content.parts.map(function (p) { return p.text || ''; }).join('')
    .replace(/^```html\s*|```\s*$/g, '');
}

function createBloggerDraft_(blogId, title, html) {
  const res = UrlFetchApp.fetch(
    'https://www.googleapis.com/blogger/v3/blogs/' + blogId + '/posts?isDraft=true',
    {
      method: 'post',
      contentType: 'application/json',
      headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
      payload: JSON.stringify({ kind: 'blogger#post', title: title, content: html, labels: ['Nexus Logistics', 'S(x)'] }),
      muteHttpExceptions: true
    });
  if (res.getResponseCode() >= 300) throw new Error('Blogger error: ' + res.getContentText());
  return JSON.parse(res.getContentText());
}

function installDailyTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'runDailyPost') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('runDailyPost').timeBased().everyDays(1).atHour(9).create();
  Logger.log('Daily trigger set for about 9 AM.');
}

/* ---------- DRIVE INTAKE: every account's Drive into the Nexus ---------- */
/* From each account, share its top folder with your-main-account@gmail.com (Editor),
   paste the folder ID below, then run intakeAll(). It COPIES (never deletes)
   into 00_INBOX_AIRLOCK/<label>, skips files already copied, and stops at ~5 min.
   Run it again (or set a 10-minute trigger) until the log says done. */

const INTAKE_SOURCES = [
  { label: 'bitjetkit',             folderId: '' },
  { label: 'tomatoloveless',        folderId: '' },
  { label: 'jkelly8008',            folderId: '' },
  { label: 'jonakel-regent',        folderId: '' },
  { label: 'pbjloveless',           folderId: '' },
  { label: 'alucardmardukloveless', folderId: '' },
  { label: 'frionelloveless',       folderId: '' }
];

function intakeAll() {
  const start = Date.now();
  const airlock = DriveApp.getFolderById(PropertiesService.getScriptProperties().getProperty('AIRLOCK_FOLDER_ID'));
  let done = true;
  INTAKE_SOURCES.forEach(function (src) {
    if (!src.folderId || !done) return;
    const dest = childFolder_(airlock, src.label);
    done = copyTree_(DriveApp.getFolderById(src.folderId), dest, start);
    Logger.log(src.label + (done ? ': done' : ': paused, run again'));
  });
}

function copyTree_(from, to, start) {
  const existing = {};
  const have = to.getFiles();
  while (have.hasNext()) existing[have.next().getName()] = true;

  const files = from.getFiles();
  while (files.hasNext()) {
    if (Date.now() - start > 5 * 60 * 1000) return false;
    const f = files.next();
    if (!existing[f.getName()]) f.makeCopy(f.getName(), to);
  }
  const subs = from.getFolders();
  while (subs.hasNext()) {
    const s = subs.next();
    if (!copyTree_(s, childFolder_(to, s.getName()), start)) return false;
  }
  return true;
}

function childFolder_(parent, name) {
  const it = parent.getFoldersByName(name);
  return it.hasNext() ? it.next() : parent.createFolder(name);
}
