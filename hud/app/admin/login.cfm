<cfinclude template="_guard.cfm"><cfscript>
requirePost();
requireCsrf();
if (!adminEnabled) { location(url = "/admin/", addToken = false, statusCode = 303); }

hud = new lib.Hud().init();
ip = hud.clientIp();
// 5 attempts per IP per 15 minutes, successful or not.
if (!hud.allowRequest("login", ip, 5, 900)) {
	cfheader(statusCode = 429); cfheader(name = "Retry-After", value = "900");
	writeOutput("Too many attempts. Wait 15 minutes."); abort;
}
if (constantTimeEquals(form.password ?: "", application.cfg.adminPassword)) {
	sessionRotate();
	session.hudAdmin = true;
	session.loginAt = now();
	cflog(file = "hud", type = "information", text = "admin login ok from " & ip);
	location(url = "/admin/", addToken = false, statusCode = 303);
}
cflog(file = "hud", type = "warning", text = "admin login failed from " & ip);
sleep(750);
location(url = "/admin/?err=1", addToken = false, statusCode = 303);
</cfscript>
