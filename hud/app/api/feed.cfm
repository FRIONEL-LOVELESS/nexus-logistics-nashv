<cfsilent>
<cfscript>
/*
	GET /api/feed.cfm?variant=sectors|companies
	Read-only public JSON. Only whitelisted fields are copied into the payload.
	- Datasource: hud_ro (SELECT on v_public_* views only).
	- CORS: Access-Control-Allow-Origin is echoed only for https://<name>.blogspot.com
	  (plus exact origins in HUD_CORS_EXTRA_ORIGINS, empty by default).
	- Rate limit: HUD_API_RATE_PER_MIN per client IP per minute (default 60), in memory.
	  Add a proxy-level limit for real abuse (see README, "Rate limiting").
	- Responses are cacheable for 60 s so Blogger page views do not hammer the DB.
*/
	hud = new lib.Hud().init();
	method = uCase(cgi.request_method);
	hdrs = getHttpRequestData(false).headers;
	origin = structKeyExists(hdrs, "Origin") ? lcase(trim(hdrs["Origin"])) : "";

	allowed = false;
	if (len(origin)) {
		if (reFind("^https://[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.blogspot\.com$", origin)) allowed = true;
		else if (len(application.cfg.corsExtra) && listFindNoCase(application.cfg.corsExtra, origin)) allowed = true;
	}
	cfheader(name = "Vary", value = "Origin");
	if (allowed) {
		cfheader(name = "Access-Control-Allow-Origin", value = origin);
		cfheader(name = "Access-Control-Allow-Methods", value = "GET, OPTIONS");
		cfheader(name = "Access-Control-Max-Age", value = "600");
	}

	status = 200; payload = {};
	if (method == "OPTIONS") {
		status = 204;
	} else if (method != "GET" && method != "HEAD") {
		status = 405;
		cfheader(name = "Allow", value = "GET, HEAD, OPTIONS");
		payload = ["error": "method_not_allowed"];
	} else if (!hud.allowRequest("api", hud.clientIp(), application.cfg.apiRateLimit, 60)) {
		status = 429;
		cfheader(name = "Retry-After", value = "60");
		payload = ["error": "rate_limited"];
	} else {
		variant = hud.normalizeVariant(url.variant ?: "");
		if (!len(variant)) {
			status = 400;
			payload = ["error": "bad_variant", "allowed": ["sectors", "companies"]];
		} else {
			vq = hud.getVariant(variant);
			orgs = hud.getOrgs(variant);
			items = hud.getItems(variant);
			events = hud.getEvents(variant, 20);

			byOrg = {};
			for (r in items) {
				k = toString(r.org_id);
				if (!structKeyExists(byOrg, k)) byOrg[k] = [];
				if (variant == "sectors" && r.kind == "folder") {
					arrayAppend(byOrg[k], ["label": toString(r.label), "file_count": int(r.file_count), "size_mb": val(r.size_mb)]);
				} else if (variant == "companies" && (r.kind == "project" || r.kind == "link")) {
					one = ["kind": toString(r.kind), "label": toString(r.label)];
					if (r.kind == "link") {
						u = hud.safeUrl(r.url);
						if (!len(u)) continue;
						one["url"] = u;
					}
					arrayAppend(byOrg[k], one);
				}
			}

			entries = [];
			for (o in orgs) {
				kids = byOrg[toString(o.id)] ?: [];
				if (variant == "sectors") {
					arrayAppend(entries, [
						"code": toString(o.code), "name": toString(o.name), "tagline": toString(o.tagline),
						"file_count": int(o.file_count), "size_mb": val(o.size_mb), "top_folders": kids
					]);
				} else {
					projects = []; links = [];
					for (c in kids) {
						if (c.kind == "project") arrayAppend(projects, c.label);
						else arrayAppend(links, ["label": c.label, "url": c.url]);
					}
					arrayAppend(entries, [
						"code": toString(o.code), "name": toString(o.name), "tagline": toString(o.tagline),
						"mission": toString(o.mission), "flagship_projects": projects,
						"volunteer_help": toString(o.volunteer_help), "official_links": links,
						"preservation_notes": toString(o.preservation_notes)
					]);
				}
			}
			ev = [];
			for (x in events) {
				arrayAppend(ev, ["level": toString(x.level), "message": toString(x.message), "at": hud.isoUtc(x.event_at)]);
			}
			payload = [
				"variant": variant,
				"title": vq.recordCount ? toString(vq.title) : "",
				"disclaimer": vq.recordCount ? toString(vq.disclaimer) : "",
				"generated_at": hud.isoUtc(now()),
				"entries": entries,
				"events": ev
			];
		}
	}
	if (status == 200) cfheader(name = "Cache-Control", value = "public, max-age=60");
	else cfheader(name = "Cache-Control", value = "no-store");
	cfheader(statusCode = status);
	body = (status == 204) ? "" : hud.safeJson(payload);
</cfscript>
</cfsilent><cfcontent reset="true" type="application/json; charset=utf-8"><cfif cgi.request_method NEQ "HEAD"><cfoutput>#body#</cfoutput></cfif>
