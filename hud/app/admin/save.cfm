<cfinclude template="_guard.cfm"><cfscript>
requirePost();
requireAuth();
requireCsrf();
hud = new lib.Hud().init();
act = clip(form.action ?: "", 32);
</cfscript>

<cfswitch expression="#act#">

	<cfcase value="org_update">
		<cfset orgId = intIn(form.id ?: "", 0, 2147483647)>
		<cfquery datasource="hud_rw">
			UPDATE sectors_or_orgs SET
				tagline            = <cfqueryparam value="#clip(form.tagline ?: '', 200)#" cfsqltype="cf_sql_varchar" null="#!len(trim(form.tagline ?: ''))#">,
				mission            = <cfqueryparam value="#clip(form.mission ?: '', 4000)#" cfsqltype="cf_sql_longvarchar" null="#!len(trim(form.mission ?: ''))#">,
				volunteer_help     = <cfqueryparam value="#clip(form.volunteer_help ?: '', 4000)#" cfsqltype="cf_sql_longvarchar" null="#!len(trim(form.volunteer_help ?: ''))#">,
				preservation_notes = <cfqueryparam value="#clip(form.preservation_notes ?: '', 4000)#" cfsqltype="cf_sql_longvarchar" null="#!len(trim(form.preservation_notes ?: ''))#">,
				is_public          = <cfqueryparam value="#structKeyExists(form, 'is_public') ? 1 : 0#" cfsqltype="cf_sql_tinyint">
			WHERE id = <cfqueryparam value="#orgId#" cfsqltype="cf_sql_integer">
		</cfquery>
	</cfcase>

	<cfcase value="item_add">
		<cfset orgId = intIn(form.org_id ?: "", 0, 2147483647)>
		<cfset kind = clip(form.kind ?: "", 10)>
		<cfif NOT listFind("folder,project,link", kind)><cfset kind = "project"></cfif>
		<cfset label = clip(form.label ?: "", 200)>
		<cfset itemUrl = "">
		<cfif kind EQ "link">
			<cfset itemUrl = hud.safeUrl(clip(form.url ?: "", 500))>
			<cfif NOT len(itemUrl)><cfset label = ""></cfif><!--- reject non-https links --->
		</cfif>
		<cfif len(label) AND orgId GT 0>
			<cfquery datasource="hud_rw">
				INSERT INTO items (org_id, variant_id, kind, label, file_count, size_mb, url, sort_order)
				SELECT o.id, o.variant_id,
					<cfqueryparam value="#kind#" cfsqltype="cf_sql_varchar">,
					<cfqueryparam value="#label#" cfsqltype="cf_sql_varchar">,
					<cfqueryparam value="#intIn(form.file_count ?: 0, 0, 2147483647)#" cfsqltype="cf_sql_integer">,
					<cfqueryparam value="#max(0, min(999999999, val(form.size_mb ?: 0)))#" cfsqltype="cf_sql_decimal" scale="2">,
					<cfqueryparam value="#itemUrl#" cfsqltype="cf_sql_varchar" null="#!len(itemUrl)#">,
					<cfqueryparam value="#intIn(form.sort_order ?: 50, 0, 9999)#" cfsqltype="cf_sql_smallint">
				FROM sectors_or_orgs o
				WHERE o.id = <cfqueryparam value="#orgId#" cfsqltype="cf_sql_integer">
			</cfquery>
		</cfif>
	</cfcase>

	<cfcase value="item_delete">
		<cfquery datasource="hud_rw">
			DELETE FROM items WHERE id = <cfqueryparam value="#intIn(form.id ?: '', 0, 2147483647)#" cfsqltype="cf_sql_integer">
		</cfquery>
	</cfcase>

	<cfcase value="event_add">
		<cfset slug = hud.normalizeVariant(form.variant ?: "")>
		<cfset lvl = clip(form.level ?: "info", 8)>
		<cfif NOT listFind("info,ok,warn,alert", lvl)><cfset lvl = "info"></cfif>
		<cfset msg = clip(form.message ?: "", 280)>
		<cfif len(slug) AND len(msg)>
			<cfquery datasource="hud_rw">
				INSERT INTO status_events (variant_id, level, message)
				SELECT v.id, <cfqueryparam value="#lvl#" cfsqltype="cf_sql_varchar">, <cfqueryparam value="#msg#" cfsqltype="cf_sql_varchar">
				FROM variants v WHERE v.slug = <cfqueryparam value="#slug#" cfsqltype="cf_sql_varchar">
			</cfquery>
		</cfif>
	</cfcase>

	<cfcase value="event_delete">
		<cfquery datasource="hud_rw">
			DELETE FROM status_events WHERE id = <cfqueryparam value="#intIn(form.id ?: '', 0, 2147483647)#" cfsqltype="cf_sql_integer">
		</cfquery>
	</cfcase>

	<cfdefaultcase>
		<cfheader statuscode="400"><cfoutput>Unknown action.</cfoutput><cfabort>
	</cfdefaultcase>
</cfswitch>

<cflog file="hud" type="information" text="admin action #act#">
<cflocation url="/admin/?saved=1" addtoken="false" statuscode="303">
