<cfinclude template="_guard.cfm"><cfsilent>
<cfset tok = CSRFGenerateToken("hudadmin")>
<cfif isAuthed>
	<cfquery name="orgs" datasource="hud_rw">
		SELECT o.id, v.slug AS variant_slug, o.code, o.name, o.tagline, o.mission, o.volunteer_help, o.preservation_notes, o.is_public
		FROM sectors_or_orgs o JOIN variants v ON v.id = o.variant_id
		WHERE v.slug IN (<cfqueryparam value="sectors,companies" cfsqltype="cf_sql_varchar" list="true">)
		ORDER BY v.sort_order, o.sort_order
	</cfquery>
	<cfquery name="items" datasource="hud_rw">
		SELECT i.id, i.org_id, i.kind, i.label, i.file_count, i.size_mb, i.url
		FROM items i
		WHERE i.kind IN (<cfqueryparam value="folder,project,link" cfsqltype="cf_sql_varchar" list="true">)
		ORDER BY i.org_id, i.kind, i.sort_order
	</cfquery>
	<cfquery name="events" datasource="hud_rw">
		SELECT e.id, v.slug AS variant_slug, e.level, e.message, e.event_at
		FROM status_events e JOIN variants v ON v.id = e.variant_id
		WHERE e.event_at > <cfqueryparam value="#createDate(2000,1,1)#" cfsqltype="cf_sql_timestamp">
		ORDER BY e.event_at DESC, e.id DESC
		LIMIT <cfqueryparam value="100" cfsqltype="cf_sql_integer">
	</cfquery>
</cfif>
</cfsilent><!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>HUD admin</title>
<link rel="stylesheet" href="/assets/hud.css">
</head>
<body class="hud admin">
<cfoutput>
<header class="hud-top">
	<div class="brand"><span class="blip" aria-hidden="true"></span>HUD // ADMIN</div>
	<nav class="tabs"><a class="tab" href="/">View HUD</a></nav>
</header>
<main class="wrap">
<cfif NOT adminEnabled>
	<p class="disclaimer">Admin is disabled. Set HUD_ADMIN_PASSWORD (12+ characters) in .env and restart the app container.</p>
<cfelseif NOT isAuthed>
	<form class="panel login" method="post" action="/admin/login.cfm" autocomplete="off">
		<h2>Sign in</h2>
		<cfif structKeyExists(url, "err")><p class="warn">Wrong password.</p></cfif>
		<input type="hidden" name="csrf" value="#a(tok)#">
		<label>Password <input type="password" name="password" required maxlength="200" autocomplete="current-password"></label>
		<button type="submit">Enter</button>
	</form>
<cfelse>
	<cfif structKeyExists(url, "saved")><p class="ok">Saved.</p></cfif>
	<form method="post" action="/admin/logout.cfm" class="inline"><input type="hidden" name="csrf" value="#a(tok)#"><button type="submit">Sign out</button></form>

	<h2 class="sec-h">Status ticker</h2>
	<form class="panel row-form" method="post" action="/admin/save.cfm">
		<input type="hidden" name="csrf" value="#a(tok)#"><input type="hidden" name="action" value="event_add">
		<select name="variant"><option value="sectors">7 Sectors</option><option value="companies">3 Companies</option></select>
		<select name="level"><option>info</option><option>ok</option><option>warn</option><option>alert</option></select>
		<input name="message" maxlength="280" required placeholder="Status line (280 chars max)">
		<button type="submit">Add</button>
	</form>
	<ul class="admin-list">
	<cfloop query="events">
		<li><span class="code">#e(events.variant_slug)# / #e(events.level)#</span> #e(events.message)#
			<form method="post" action="/admin/save.cfm" class="inline">
				<input type="hidden" name="csrf" value="#a(tok)#"><input type="hidden" name="action" value="event_delete"><input type="hidden" name="id" value="#a(events.id)#">
				<button type="submit">Delete</button>
			</form>
		</li>
	</cfloop>
	</ul>

	<h2 class="sec-h">Sectors and organizations</h2>
	<cfloop query="orgs">
		<cfset oid = orgs.id>
		<section class="panel">
			<header class="panel-h"><span class="code">#e(orgs.variant_slug)# / #e(orgs.code)#</span><h2>#e(orgs.name)#</h2></header>
			<form method="post" action="/admin/save.cfm" class="stack">
				<input type="hidden" name="csrf" value="#a(tok)#"><input type="hidden" name="action" value="org_update"><input type="hidden" name="id" value="#a(oid)#">
				<label>Tagline <input name="tagline" maxlength="200" value="#a(orgs.tagline)#"></label>
				<cfif orgs.variant_slug EQ "companies">
					<label>Mission <textarea name="mission" maxlength="4000" rows="3">#e(orgs.mission)#</textarea></label>
					<label>How volunteers can help <textarea name="volunteer_help" maxlength="4000" rows="3">#e(orgs.volunteer_help)#</textarea></label>
					<label>Knowledge preservation notes <textarea name="preservation_notes" maxlength="4000" rows="3">#e(orgs.preservation_notes)#</textarea></label>
				</cfif>
				<label class="check"><input type="checkbox" name="is_public" value="1"<cfif orgs.is_public> checked</cfif>> Public</label>
				<button type="submit">Save</button>
			</form>
			<ul class="admin-list">
			<cfloop query="items">
				<cfif items.org_id EQ oid>
				<li><span class="code">#e(items.kind)#</span> #e(items.label)#<cfif len(items.url)> &rarr; #e(items.url)#</cfif><cfif items.kind EQ "folder"> (#numberFormat(items.file_count, ",")# files)</cfif>
					<form method="post" action="/admin/save.cfm" class="inline">
						<input type="hidden" name="csrf" value="#a(tok)#"><input type="hidden" name="action" value="item_delete"><input type="hidden" name="id" value="#a(items.id)#">
						<button type="submit">Delete</button>
					</form>
				</li>
				</cfif>
			</cfloop>
			</ul>
			<form method="post" action="/admin/save.cfm" class="row-form">
				<input type="hidden" name="csrf" value="#a(tok)#"><input type="hidden" name="action" value="item_add"><input type="hidden" name="org_id" value="#a(oid)#">
				<select name="kind">
					<cfif orgs.variant_slug EQ "sectors"><option value="folder">folder</option><cfelse><option value="project">project</option><option value="link">link</option></cfif>
				</select>
				<input name="label" maxlength="200" required placeholder="Label">
				<cfif orgs.variant_slug EQ "sectors">
					<input name="file_count" inputmode="numeric" placeholder="Files"><input name="size_mb" inputmode="decimal" placeholder="MB">
				<cfelse>
					<input name="url" maxlength="500" placeholder="https:// (links only)">
				</cfif>
				<button type="submit">Add</button>
			</form>
		</section>
	</cfloop>
</cfif>
</main>
</cfoutput>
</body>
</html>
