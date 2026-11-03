<cfcomponent output="false" hint="Read-only data access and helpers for the public HUD and API. Uses the hud_ro datasource (SELECT on v_public_* views only).">

	<cffunction name="init" access="public" returntype="any" output="false">
		<cfset variables.dsn = "hud_ro">
		<cfreturn this>
	</cffunction>

	<!--- Whitelist the variant slug. Anything else becomes "" so callers can reject it. --->
	<cffunction name="normalizeVariant" access="public" returntype="string" output="false">
		<cfargument name="raw" type="any" required="true">
		<cfset var v = lcase(trim(toString(arguments.raw)))>
		<cfif v EQ "sectors" OR v EQ "companies">
			<cfreturn v>
		</cfif>
		<cfreturn "">
	</cffunction>

	<cffunction name="getVariants" access="public" returntype="query" output="false">
		<cfset var q = "">
		<cfquery name="q" datasource="#variables.dsn#" cachedwithin="#createTimeSpan(0,0,0,30)#">
			SELECT slug, title, subtitle, disclaimer
			FROM v_public_variants
			WHERE slug IN (<cfqueryparam value="sectors,companies" cfsqltype="cf_sql_varchar" list="true">)
			ORDER BY sort_order
		</cfquery>
		<cfreturn q>
	</cffunction>

	<cffunction name="getVariant" access="public" returntype="query" output="false">
		<cfargument name="slug" type="string" required="true">
		<cfset var q = "">
		<cfquery name="q" datasource="#variables.dsn#" cachedwithin="#createTimeSpan(0,0,0,30)#">
			SELECT slug, title, subtitle, disclaimer
			FROM v_public_variants
			WHERE slug = <cfqueryparam value="#arguments.slug#" cfsqltype="cf_sql_varchar" maxlength="32">
		</cfquery>
		<cfreturn q>
	</cffunction>

	<cffunction name="getOrgs" access="public" returntype="query" output="false">
		<cfargument name="slug" type="string" required="true">
		<cfset var q = "">
		<cfquery name="q" datasource="#variables.dsn#" cachedwithin="#createTimeSpan(0,0,0,30)#">
			SELECT id, code, name, tagline, mission, volunteer_help, preservation_notes, file_count, size_mb
			FROM v_public_orgs
			WHERE variant_slug = <cfqueryparam value="#arguments.slug#" cfsqltype="cf_sql_varchar" maxlength="32">
			ORDER BY sort_order, id
		</cfquery>
		<cfreturn q>
	</cffunction>

	<cffunction name="getItems" access="public" returntype="query" output="false">
		<cfargument name="slug" type="string" required="true">
		<cfset var q = "">
		<cfquery name="q" datasource="#variables.dsn#" cachedwithin="#createTimeSpan(0,0,0,30)#">
			SELECT org_id, kind, label, detail, file_count, size_mb, url
			FROM v_public_items
			WHERE variant_slug = <cfqueryparam value="#arguments.slug#" cfsqltype="cf_sql_varchar" maxlength="32">
			ORDER BY org_id, kind, sort_order
		</cfquery>
		<cfreturn q>
	</cffunction>

	<cffunction name="getEvents" access="public" returntype="query" output="false">
		<cfargument name="slug" type="string" required="true">
		<cfargument name="limit" type="numeric" required="false" default="12">
		<cfset var q = "">
		<cfset var n = max(1, min(50, int(arguments.limit)))>
		<cfquery name="q" datasource="#variables.dsn#" cachedwithin="#createTimeSpan(0,0,0,30)#">
			SELECT level, message, event_at
			FROM v_public_events
			WHERE variant_slug = <cfqueryparam value="#arguments.slug#" cfsqltype="cf_sql_varchar" maxlength="32">
			ORDER BY event_at DESC, id DESC
			LIMIT <cfqueryparam value="#n#" cfsqltype="cf_sql_integer">
		</cfquery>
		<cfreturn q>
	</cffunction>

	<!--- Percent of max, as an integer 0-100 for the .w-N width classes (keeps CSP free of inline styles). --->
	<cffunction name="pct" access="public" returntype="numeric" output="false">
		<cfargument name="value" type="numeric" required="true">
		<cfargument name="maxValue" type="numeric" required="true">
		<cfset var p = 0>
		<cfif arguments.maxValue LTE 0 OR arguments.value LTE 0>
			<cfreturn 0>
		</cfif>
		<cfset p = round((arguments.value / arguments.maxValue) * 100)>
		<cfreturn max(1, min(100, p))>
	</cffunction>

	<cffunction name="fmtInt" access="public" returntype="string" output="false">
		<cfargument name="n" type="numeric" required="true">
		<cfreturn numberFormat(arguments.n, ",")>
	</cffunction>

	<!--- Human size from MB: GB above 1,000 MB. --->
	<cffunction name="fmtSize" access="public" returntype="string" output="false">
		<cfargument name="mb" type="numeric" required="true">
		<cfif arguments.mb GTE 1000>
			<cfreturn numberFormat(arguments.mb / 1000, ",.0") & " GB">
		</cfif>
		<cfreturn numberFormat(arguments.mb, ",.0") & " MB">
	</cffunction>

	<cffunction name="isoUtc" access="public" returntype="string" output="false">
		<cfargument name="d" type="any" required="true">
		<cfif NOT isDate(arguments.d)>
			<cfreturn "">
		</cfif>
		<cfreturn dateTimeFormat(arguments.d, "yyyy-mm-dd'T'HH:nn:ss'Z'", "UTC")>
	</cffunction>

	<!--- Only https links ever reach the page or the feed. --->
	<cffunction name="safeUrl" access="public" returntype="string" output="false">
		<cfargument name="u" type="any" required="true">
		<cfset var s = trim(toString(arguments.u))>
		<cfif reFindNoCase("^https://[a-z0-9.-]+(:[0-9]{2,5})?(/[^\s""'<>]*)?$", s)>
			<cfreturn s>
		</cfif>
		<cfreturn "">
	</cffunction>

	<!--- Client IP. Trust X-Forwarded-For only when HUD_TRUST_PROXY=true (i.e. behind Caddy). --->
	<cffunction name="clientIp" access="public" returntype="string" output="false">
		<cfset var hdrs = getHttpRequestData(false).headers>
		<cfset var xff = "">
		<cfif application.cfg.trustProxy AND structKeyExists(hdrs, "X-Forwarded-For")>
			<cfset xff = trim(listLast(hdrs["X-Forwarded-For"], ","))>
			<cfif len(xff) AND len(xff) LTE 45>
				<cfreturn xff>
			</cfif>
		</cfif>
		<cfreturn cgi.remote_addr>
	</cffunction>

	<!---
		Fixed-window in-memory rate limiter (per Lucee instance). Good enough for one small VM.
		For more, add a limit at the proxy (see README) or a shared store.
	--->
	<cffunction name="allowRequest" access="public" returntype="boolean" output="false">
		<cfargument name="bucket" type="string" required="true">
		<cfargument name="key" type="string" required="true">
		<cfargument name="limit" type="numeric" required="true">
		<cfargument name="windowSeconds" type="numeric" required="true">
		<cfset var nowS = int(getTickCount() / 1000)>
		<cfset var win = int(nowS / arguments.windowSeconds)>
		<cfset var k = arguments.bucket & "|" & arguments.key & "|" & win>
		<cfset var ok = true>
		<cflock name="hud_ratelimit" type="exclusive" timeout="2" throwontimeout="false">
			<cfif NOT structKeyExists(application, "rl") OR structCount(application.rl) GT 20000>
				<cfset application.rl = {}>
			</cfif>
			<cfif NOT structKeyExists(application.rl, k)>
				<cfset application.rl[k] = 0>
			</cfif>
			<cfset application.rl[k] = application.rl[k] + 1>
			<cfset ok = application.rl[k] LTE arguments.limit>
		</cflock>
		<cfreturn ok>
	</cffunction>

	<!--- Escape characters that could let JSON be sniffed or break out of a <script> context. --->
	<cffunction name="safeJson" access="public" returntype="string" output="false">
		<cfargument name="data" type="any" required="true">
		<cfset var s = serializeJSON(arguments.data)>
		<cfset s = replace(s, "<", "\u003c", "all")>
		<cfset s = replace(s, ">", "\u003e", "all")>
		<cfset s = replace(s, "&", "\u0026", "all")>
		<cfset s = replace(s, chr(8232), "\u2028", "all")>
		<cfset s = replace(s, chr(8233), "\u2029", "all")>
		<cfreturn s>
	</cffunction>

</cfcomponent>
