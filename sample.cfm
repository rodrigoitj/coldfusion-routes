<cfscript>
	r = CreateObject("component", "Routing");
	r.reset();
	r
	.add("analytics", {module="analytics", controller="analytics", action="index"})
	.add("analytics/revoke", {module="analytics", controller="analytics", action="revoke"})
	.add("analytics/accounts", {module="analytics", controller="analytics", action="accounts"})
	.add("analytics/properties/:account", {module="analytics", controller="analytics", action="properties", account="[0-9]+"})
	.add("analytics/account-properties/:account", {module="analytics", controller="analytics", action="set-account", account="[0-9]+"})
	.add("analytics/account/:account/web-property/:webProperty", {module="analytics", controller="analytics", action="profiles", account="[0-9]+", webProperty="[0-9]+"})
	.add("analytics/property/:property", {module="analytics", controller="analytics", action="set-property", property="[0-9]+"});
	r.dump();
</cfscript>
