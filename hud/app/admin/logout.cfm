<cfinclude template="_guard.cfm"><cfscript>
requirePost();
requireCsrf();
session.hudAdmin = false;
sessionInvalidate();
location(url = "/admin/", addToken = false, statusCode = 303);
</cfscript>
