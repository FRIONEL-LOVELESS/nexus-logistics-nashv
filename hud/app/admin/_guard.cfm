<cfsilent>
<cfscript>
// Shared admin helpers. Included by every admin page (never served directly: leading underscore is blocked below).
if (listLast(cgi.script_name, "/") == "_guard.cfm") { cfheader(statusCode = 404); abort; }

adminEnabled = len(application.cfg.adminPassword) >= 12;
isAuthed = adminEnabled && (session.hudAdmin ?: false) == true;

function requirePost() {
	if (uCase(cgi.request_method) != "POST") {
		cfheader(statusCode = 405); cfheader(name = "Allow", value = "POST");
		writeOutput("POST only."); abort;
	}
}
function requireCsrf() {
	if (!CSRFVerifyToken(form.csrf ?: "", "hudadmin")) {
		cfheader(statusCode = 403); writeOutput("Bad or expired form token. Go back and reload the page."); abort;
	}
}
function requireAuth() {
	if (!isAuthed) { location(url = "/admin/", addToken = false, statusCode = 303); }
}
function constantTimeEquals(required string x, required string y) {
	var md = createObject("java", "java.security.MessageDigest");
	var hx = md.getInstance("SHA-256").digest(arguments.x.getBytes("UTF-8"));
	var hy = md.getInstance("SHA-256").digest(arguments.y.getBytes("UTF-8"));
	return md.isEqual(hx, hy);
}
function clip(any v, numeric n) { return left(trim(toString(arguments.v)), arguments.n); }
function intIn(any v, numeric lo, numeric hi) {
	var s = trim(toString(arguments.v));
	if (!reFind("^-?[0-9]{1,10}$", s)) return arguments.lo;
	return max(arguments.lo, min(arguments.hi, int(s)));
}
e = function(s) { return encodeForHTML(toString(s)); };
a = function(s) { return encodeForHTMLAttribute(toString(s)); };
</cfscript>
</cfsilent>
