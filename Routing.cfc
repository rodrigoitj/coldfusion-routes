<!---
	Class: Routing
	Refactored for readability, cohesion, and safer state handling.
--->
<cfcomponent output="false" singleton="true">
	<cfscript>
		variables.Pattern = CreateObject("java", "java.util.regex.Pattern");

		function reset() {
			variables.instance = {
				routes = [],
				REURIRouteMap = [],
				namedRoutes = {},
				connectedRoutePaths = {},
				NamedArgPattern = variables.Pattern.compile("/?:(?<namedArg>[^:/$]+)"),
				RoutePathPattern = variables.Pattern.compile("(?<slash>/?):(?<namedArg>[^:/$]+)")
			};

			if (StructKeyExists(variables, "currentRoute")) {
				StructDelete(variables, "currentRoute");
			}

			return this;
		}

		reset();
	</cfscript>

	<cffunction name="addNamed" output="false" access="public" returntype="any">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="path" type="string" required="true" />
		<cfargument name="parameters" type="struct" required="true" />
		<cfargument name="options" type="struct" default="#StructNew()#" />

		<cfset var local = {} />
		<cfset local.route = duplicate(arguments) />
		<cfset addRoute(local.route) />
		<cfset addNamedRoute(arguments.name, local.route) />
		<cfset mapRouteByREURI(parseRoutePathToREURI(local.route.path, local.route.parameters), local.route) />

		<cfreturn this />
	</cffunction>

	<cffunction name="add" output="false" access="public" returntype="any">
		<cfargument name="path" type="string" required="true" />
		<cfargument name="parameters" type="struct" required="true" />
		<cfargument name="options" type="struct" default="#StructNew()#" />

		<cfset var local = {} />

		<cfif isConnectedRoute(arguments.path)>
			<cfreturn this />
		</cfif>

		<cfset local.route = duplicate(arguments) />
		<cfset addRoute(local.route) />
		<cfset addConnectedRoute(local.route.path) />
		<cfset mapRouteByREURI(parseRoutePathToREURI(local.route.path, local.route.parameters), local.route) />

		<cfreturn this />
	</cffunction>

	<cffunction name="isConnectedRoute" output="false" access="public" returntype="boolean">
		<cfargument name="path" type="string" required="true" />
		<cfreturn StructKeyExists(variables.instance.connectedRoutePaths, arguments.path) />
	</cffunction>

	<cffunction name="findRouteByURI" output="false" access="public" returntype="any">
		<cfargument name="uri" type="string" required="true" />
		<cfargument name="assignToUrlScope" type="boolean" default="true" />

		<cfset var local = {} />
		<cfset local.normalizedUri = normalizeUri(arguments.uri) />

		<cfloop array="#variables.instance.REURIRouteMap#" index="local.indexRoute">
			<cfif routeMatchesUri(local.indexRoute.REURI, local.normalizedUri)>
				<cfset local.routeDetails = duplicate(local.indexRoute) />
				<cfset local.routeDetails.url = {} />
				<cfset hydrateRouteArguments(local.routeDetails, local.normalizedUri, arguments.assignToUrlScope) />
				<cfreturn local.routeDetails />
			</cfif>
		</cfloop>

		<cfreturn false />
	</cffunction>

	<cffunction name="setCurrentRoute" output="false" access="public" returntype="void">
		<cfargument name="route" type="struct" required="true" />
		<cfset variables.currentRoute = duplicate(arguments.route) />
	</cffunction>

	<cffunction name="getCurrentRoute" output="false" access="public" returntype="struct">
		<cfreturn structKeyExists(variables, "currentRoute") ? duplicate(variables.currentRoute) : {} />
	</cffunction>

	<cffunction name="findRouteByName" output="false" access="public" returntype="any">
		<cfargument name="name" type="string" required="true" />
		<cfif StructKeyExists(variables.instance.namedRoutes, arguments.name)>
			<cfreturn duplicate(variables.instance.namedRoutes[arguments.name]) />
		</cfif>
		<cfreturn false />
	</cffunction>

	<cffunction name="getRoutes" output="false" access="public" returntype="array">
		<cfreturn duplicate(variables.instance.routes) />
	</cffunction>

	<cffunction name="getRoutePathArguments" output="false" access="public" returntype="array">
		<cfargument name="path" type="string" required="true" />
		<cfset var local = {} />
		<cfset local.namedArgs = [] />
		<cfset local.Matcher = variables.instance.NamedArgPattern.matcher(arguments.path) />

		<cfloop condition="local.Matcher.find()">
			<cfset ArrayAppend(local.namedArgs, local.Matcher.group("namedArg")) />
		</cfloop>

		<cfreturn local.namedArgs />
	</cffunction>

	<!--- PRIVATE --->

	<cffunction name="normalizeUri" output="false" access="private" returntype="string">
		<cfargument name="uri" type="string" required="true" />
		<cfif Len(arguments.uri) EQ 0>
			<cfreturn "" />
		</cfif>
		<cfreturn ReReplace(arguments.uri, "/+$", "") & "/" />
	</cffunction>

	<cffunction name="routeMatchesUri" output="false" access="private" returntype="boolean">
		<cfargument name="compiledRoute" type="string" required="true" />
		<cfargument name="uri" type="string" required="true" />

		<cfif Len(arguments.compiledRoute) EQ 0 AND Len(arguments.uri) EQ 0>
			<cfreturn true />
		</cfif>

		<cfif Len(arguments.compiledRoute) GT 0 AND REFindNoCase(arguments.compiledRoute, arguments.uri) NEQ 0>
			<cfreturn true />
		</cfif>

		<cfreturn false />
	</cffunction>

	<cffunction name="hydrateRouteArguments" output="false" access="private" returntype="void">
		<cfargument name="route" type="struct" required="true" />
		<cfargument name="uri" type="string" required="true" />
		<cfargument name="assignToUrlScope" type="boolean" required="true" />

		<cfset var local = {} />
		<cfset local.namedArgMatcher = variables.instance.NamedArgPattern.matcher(arguments.route.path) />
		<cfset local.valueMatcher = variables.Pattern.compile("(?i)" & arguments.route.REURI).matcher(arguments.uri) />
		<cfset local.index = 1 />

		<cfif !local.valueMatcher.find()>
			<cfreturn />
		</cfif>

		<cfloop condition="local.namedArgMatcher.find()">
			<cfset local.argName = local.namedArgMatcher.group("namedArg") />
			<cfset local.argValue = local.valueMatcher.group(local.index++) />

			<cfif arguments.assignToUrlScope>
				<cfset url[local.argName] = local.argValue />
			</cfif>

			<cfset arguments.route.url[local.argName] = local.argValue />
			<cfset arguments.route.parameters[local.argName] = local.argValue />
		</cfloop>
	</cffunction>

	<cffunction name="parseRoutePathToREURI" output="false" access="private" returntype="string">
		<cfargument name="path" type="string" required="true" />
		<cfargument name="parameters" type="struct" required="true" />

		<cfset var local = {} />
		<cfset local.newPath = arguments.path />
		<cfset local.Matcher = variables.instance.RoutePathPattern.matcher(local.newPath) />

		<cfloop condition="local.Matcher.find()">
			<cfset local.thisNamedArg = local.Matcher.group("namedArg") />
			<cfset local.replacementRegex = resolveNamedArgumentRegex(local.thisNamedArg, arguments.parameters) />
			<cfset local.newPath = Replace(
				local.newPath,
				local.Matcher.group(),
				local.Matcher.group("slash") & "(" & local.replacementRegex & ")"
			) />
		</cfloop>

		<cfif local.newPath NEQ "">
			<cfset local.newPath = "^" & local.newPath & "/$" />
		</cfif>

		<cfreturn local.newPath />
	</cffunction>

	<cffunction name="resolveNamedArgumentRegex" output="false" access="private" returntype="string">
		<cfargument name="namedArgument" type="string" required="true" />
		<cfargument name="parameters" type="struct" required="true" />

		<cfif StructKeyExists(arguments.parameters, arguments.namedArgument) AND IsSimpleValue(arguments.parameters[arguments.namedArgument])>
			<cfreturn arguments.parameters[arguments.namedArgument] />
		</cfif>

		<cfreturn "[^/]+" />
	</cffunction>

	<cffunction name="addRoute" output="false" access="private" returntype="boolean">
		<cfargument name="route" type="struct" required="true" />
		<cfreturn ArrayAppend(variables.instance.routes, arguments.route) />
	</cffunction>

	<cffunction name="mapRouteByREURI" output="false" access="private" returntype="boolean">
		<cfargument name="REURI" type="string" required="true" />
		<cfargument name="route" type="struct" required="true" />

		<cfset var local = {} />
		<cfset local.routeToMap = duplicate(arguments.route) />
		<cfset local.routeToMap.REURI = arguments.REURI />
		<cfset local.routeToMap.url = StructKeyExists(local.routeToMap, "url") ? local.routeToMap.url : {} />

		<cfreturn ArrayAppend(variables.instance.REURIRouteMap, local.routeToMap) />
	</cffunction>

	<cffunction name="addNamedRoute" output="false" access="private" returntype="boolean">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="route" type="struct" required="true" />
		<cfreturn StructInsert(variables.instance.namedRoutes, arguments.name, duplicate(arguments.route), true) />
	</cffunction>

	<cffunction name="addConnectedRoute" output="false" access="private" returntype="void">
		<cfargument name="path" type="string" required="true" />
		<cfset variables.instance.connectedRoutePaths[arguments.path] = true />
	</cffunction>

	<cffunction name="dump" output="true" access="public" returntype="void">
		<cfdump var="#variables.instance#" />
	</cffunction>
</cfcomponent>
