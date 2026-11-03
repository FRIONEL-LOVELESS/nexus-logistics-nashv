component output="false" {

	// ---- helpers usable in the pseudo-constructor ---------------------------
	private string function env(required string name, string fallback = "") {
		var e = server.system.environment;
		if (structKeyExists(e, arguments.name) && len(trim(e[arguments.name]))) {
			return trim(e[arguments.name]);
		}
		return arguments.fallback;
	}

	this.name = "hud_" & hash(getCurrentTemplatePath(), "MD5");
	this.applicationTimeout = createTimeSpan(1, 0, 0, 0);
	this.timezone = "UTC";
	this.charset.web = "UTF-8";
	this.charset.resource = "UTF-8";
	this.serialization.preserveCaseForStructKey = true;
	this.serialization.preserveCaseForQueryColumn = true;
	this.scriptProtect = "none"; // output is encoded at render time instead
	this.searchImplicitScopes = false;

	// Sessions only for /admin. The public HUD and API set no cookies.
	variables.firstSegment = lcase(listFirst(cgi.script_name, "/"));
	this.sessionManagement = (variables.firstSegment == "admin");
	this.setClientCookies = this.sessionManagement;
	this.sessionType = "cfml";
	this.sessionTimeout = createTimeSpan(0, 0, 30, 0);
	this.sessionCookie = {
		httpOnly: true,
		secure: (env("HUD_COOKIE_SECURE", "false") == "true"),
		sameSite: "Strict",
		timeout: createTimeSpan(0, 0, 30, 0), // cookie lives as long as the session, not years
		disableUpdate: false
	};

	variables.dbHost = env("HUD_DB_HOST", "db");
	variables.dbPort = env("HUD_DB_PORT", "3306");
	variables.dbName = env("MYSQL_DATABASE", "hud");
	variables.jdbc = "jdbc:mysql://" & variables.dbHost & ":" & variables.dbPort & "/" & variables.dbName
		& "?characterEncoding=UTF-8&serverTimezone=UTC&useSSL=false&allowPublicKeyRetrieval=true"
		& "&allowMultiQueries=false&allowLoadLocalInfile=false&autoDeserialize=false";

	// Public pages + API: read-only user, SELECT on v_public_* views only.
	this.datasources["hud_ro"] = {
		class: "com.mysql.cj.jdbc.Driver",
		bundleName: "com.mysql.cj",
		connectionString: variables.jdbc,
		username: env("HUD_RO_USER"),
		password: env("HUD_RO_PASSWORD"),
		connectionLimit: 20,
		liveTimeout: 15,
		blob: false,
		clob: true
	};
	// Admin only: table DML, no DDL.
	this.datasources["hud_rw"] = {
		class: "com.mysql.cj.jdbc.Driver",
		bundleName: "com.mysql.cj",
		connectionString: variables.jdbc,
		username: env("HUD_RW_USER"),
		password: env("HUD_RW_PASSWORD"),
		connectionLimit: 5,
		liveTimeout: 15,
		blob: false,
		clob: true
	};
	this.datasource = "hud_ro";

	public boolean function onApplicationStart() {
		application.cfg = {
			adminPassword: env("HUD_ADMIN_PASSWORD"),
			trustProxy: (env("HUD_TRUST_PROXY", "false") == "true"),
			hsts: (env("HUD_HSTS", "false") == "true"),
			apiRateLimit: val(env("HUD_API_RATE_PER_MIN", "60")),
			corsExtra: env("HUD_CORS_EXTRA_ORIGINS", ""),
			siteTitle: env("HUD_SITE_TITLE", "ARCHIVE//HUD")
		};
		application.rl = {};
		return true;
	}

	public boolean function onRequestStart(required string targetPage) {
		// Hidden folders: never served directly.
		if (listFindNoCase("lib,includes,WEB-INF,META-INF", variables.firstSegment)) {
			notFound();
			return false;
		}
		// Admin ?reinit is not exposed; restart the container to reload env.
		var isApi = (variables.firstSegment == "api");
		var csp = isApi
			? "default-src 'none'; frame-ancestors 'none'; base-uri 'none'"
			: "default-src 'none'; style-src 'self'; img-src 'self' data:; font-src 'none'; script-src 'none'; connect-src 'none'; form-action 'self'; frame-ancestors 'self'; base-uri 'none'; object-src 'none'";
		cfheader(name = "Content-Security-Policy", value = csp);
		cfheader(name = "X-Frame-Options", value = "SAMEORIGIN");
		cfheader(name = "X-Content-Type-Options", value = "nosniff");
		cfheader(name = "Referrer-Policy", value = "strict-origin-when-cross-origin");
		cfheader(name = "Permissions-Policy", value = "camera=(), microphone=(), geolocation=(), payment=(), usb=()");
		cfheader(name = "Cross-Origin-Opener-Policy", value = "same-origin");
		if (application.cfg.hsts) {
			cfheader(name = "Strict-Transport-Security", value = "max-age=31536000; includeSubDomains");
		}
		if (variables.firstSegment == "admin") {
			cfheader(name = "Cache-Control", value = "no-store");
			cfheader(name = "X-Robots-Tag", value = "noindex, nofollow");
		}
		return true;
	}

	// No remote CFC calls are offered.
	public void function onCFCRequest(string cfcname, string method, struct args) {
		notFound();
	}

	public void function onMissingTemplate(required string targetPage) {
		notFound();
	}

	public void function onError(required any exception, required string eventName) {
		try {
			cflog(file = "hud", type = "error", text = (arguments.exception.message ?: "error") & " | " & (arguments.exception.detail ?: ""));
		} catch (any ignore) {}
		try {
			cfcontent(reset = true, type = "text/plain; charset=utf-8");
			cfheader(statusCode = 500, statusText = "Internal Server Error");
		} catch (any ignore) {}
		writeOutput("Something went wrong. The error was logged.");
	}

	private void function notFound() {
		cfcontent(reset = true, type = "text/plain; charset=utf-8");
		cfheader(statusCode = 404, statusText = "Not Found");
		writeOutput("Not found.");
	}
}
