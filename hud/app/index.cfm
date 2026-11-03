<cfsilent>
<cfscript>
	hud = new lib.Hud().init();
	variant = hud.normalizeVariant(url.variant ?: "sectors");
	if (!len(variant)) variant = "sectors";
	vq = hud.getVariant(variant);
	allV = hud.getVariants();
	orgs = hud.getOrgs(variant);
	items = hud.getItems(variant);
	events = hud.getEvents(variant, 12);

	// Group items by org id.
	byOrg = {};
	for (row in items) {
		k = toString(row.org_id);
		if (!structKeyExists(byOrg, k)) byOrg[k] = [];
		arrayAppend(byOrg[k], row);
	}
	totalFiles = 0; totalMb = 0; maxFiles = 0; maxMb = 0; biggest = "";
	for (o in orgs) {
		totalFiles += o.file_count; totalMb += o.size_mb;
		if (o.file_count > maxFiles) { maxFiles = o.file_count; biggest = o.code; }
		if (o.size_mb > maxMb) maxMb = o.size_mb;
	}
	projectCount = 0; linkCount = 0;
	for (row in items) {
		if (row.kind == "project") projectCount++;
		if (row.kind == "link") linkCount++;
	}
	title = vq.recordCount ? vq.title : "HUD";
	e = function(s) { return encodeForHTML(toString(s)); };
	a = function(s) { return encodeForHTMLAttribute(toString(s)); };
</cfscript>
</cfsilent><!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><cfoutput>#e(application.cfg.siteTitle)# :: #e(title)#</cfoutput></title>
<link rel="stylesheet" href="/assets/hud.css">
</head>
<body class="hud">
<cfoutput>
<div class="scan" aria-hidden="true"></div>
<header class="hud-top">
	<div class="brand"><span class="blip" aria-hidden="true"></span>#e(application.cfg.siteTitle)#</div>
	<nav class="tabs" aria-label="Dashboard variant">
		<cfloop query="allV">
			<a class="tab<cfif allV.slug EQ variant> is-on</cfif>" href="/?variant=#a(allV.slug)#"<cfif allV.slug EQ variant> aria-current="page"</cfif>>#e(allV.title)#</a>
		</cfloop>
	</nav>
</header>

<cfif events.recordCount>
<section class="ticker" aria-label="Status feed">
	<span class="ticker-tag">STATUS</span>
	<div class="ticker-window"><div class="ticker-track">
		<cfloop from="1" to="2" index="pass">
			<cfloop query="events">
				<span class="tick lvl-#a(events.level)#"<cfif pass EQ 2> aria-hidden="true"</cfif>>[#e(uCase(events.level))#] #e(events.message)#</span>
			</cfloop>
		</cfloop>
	</div></div>
</section>
</cfif>

<main class="wrap">
	<cfif vq.recordCount AND len(vq.subtitle)><p class="sub">#e(vq.subtitle)#</p></cfif>

	<cfif variant EQ "sectors">
		<section class="tiles" aria-label="Totals">
			<div class="tile"><span class="k">Sectors</span><span class="v">#orgs.recordCount#</span></div>
			<div class="tile"><span class="k">Files mapped</span><span class="v">#hud.fmtInt(totalFiles)#</span></div>
			<div class="tile"><span class="k">Total size</span><span class="v">#e(hud.fmtSize(totalMb))#</span></div>
			<div class="tile"><span class="k">Largest sector</span><span class="v">#e(biggest)#</span></div>
		</section>

		<section class="grid" aria-label="Sectors">
		<cfloop query="orgs">
			<article class="panel">
				<header class="panel-h">
					<span class="code">#e(orgs.code)#</span>
					<h2>#e(orgs.name)#</h2>
					<cfif len(orgs.tagline)><p class="tag">#e(orgs.tagline)#</p></cfif>
				</header>
				<div class="meter">
					<span class="mk">FILES</span>
					<span class="bar"><span class="fill f-cyan w-#hud.pct(orgs.file_count, maxFiles)#"></span></span>
					<span class="mv">#hud.fmtInt(orgs.file_count)#</span>
				</div>
				<div class="meter">
					<span class="mk">SIZE</span>
					<span class="bar"><span class="fill f-amber w-#hud.pct(orgs.size_mb, maxMb)#"></span></span>
					<span class="mv">#e(hud.fmtSize(orgs.size_mb))#</span>
				</div>
				<cfset rows = byOrg[toString(orgs.id)] ?: []>
				<cfif arrayLen(rows)>
					<cfset fMax = 0><cfloop array="#rows#" item="r"><cfset fMax = max(fMax, r.file_count)></cfloop>
					<ul class="roll" aria-label="Top folders">
					<cfloop array="#rows#" item="r">
						<li>
							<span class="rl" title="#a(r.label)#">#e(r.label)#</span>
							<span class="bar thin"><span class="fill f-cyan w-#hud.pct(r.file_count, fMax)#"></span></span>
							<span class="rv">#hud.fmtInt(r.file_count)# &middot; #e(hud.fmtSize(r.size_mb))#</span>
						</li>
					</cfloop>
					</ul>
				</cfif>
			</article>
		</cfloop>
		</section>
	<cfelse>
		<p class="disclaimer" role="note">#e(len(vq.disclaimer) ? vq.disclaimer : "Independent fan dashboard. Not affiliated with or endorsed by Wikimedia, Mozilla, or the Linux Foundation.")#</p>
		<section class="tiles" aria-label="Totals">
			<div class="tile"><span class="k">Organizations</span><span class="v">#orgs.recordCount#</span></div>
			<div class="tile"><span class="k">Flagship projects</span><span class="v">#projectCount#</span></div>
			<div class="tile"><span class="k">Official links</span><span class="v">#linkCount#</span></div>
			<div class="tile"><span class="k">Status lines</span><span class="v">#events.recordCount#</span></div>
		</section>
		<section class="grid cards" aria-label="Organizations">
		<cfloop query="orgs">
			<cfset rows = byOrg[toString(orgs.id)] ?: []>
			<article class="panel card">
				<header class="panel-h">
					<span class="code">#e(orgs.code)#</span>
					<h2>#e(orgs.name)#</h2>
					<cfif len(orgs.tagline)><p class="tag">#e(orgs.tagline)#</p></cfif>
				</header>
				<h3>Mission</h3>
				<p>#e(orgs.mission)#</p>
				<h3>Flagship projects</h3>
				<ul class="chips">
					<cfloop array="#rows#" item="r"><cfif r.kind EQ "project"><li>#e(r.label)#</li></cfif></cfloop>
				</ul>
				<h3>How volunteers can help</h3>
				<p>#e(orgs.volunteer_help)#</p>
				<h3>Official links</h3>
				<ul class="links">
					<cfloop array="#rows#" item="r">
						<cfif r.kind EQ "link" AND len(hud.safeUrl(r.url))>
							<li><a href="#a(hud.safeUrl(r.url))#" rel="noopener noreferrer nofollow" target="_blank">#e(r.label)#</a></li>
						</cfif>
					</cfloop>
				</ul>
				<h3>Knowledge preservation notes</h3>
				<p class="notes">#e(orgs.preservation_notes)#</p>
			</article>
		</cfloop>
		</section>
	</cfif>
</main>

<footer class="hud-foot">
	<span>Read-only feed: <code>/api/feed.cfm?variant=#e(variant)#</code></span>
	<cfif variant EQ "companies"><span>Independent fan dashboard. Not affiliated with or endorsed by Wikimedia, Mozilla, or the Linux Foundation. No logos used.</span></cfif>
</footer>
</cfoutput>
</body>
</html>
