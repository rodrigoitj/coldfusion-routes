<!---
	Class: Routing
	
	TODO: this whole thing is new and was hacked out - there will be much change so I'm not bothering on comments or
	much documentation at the moment.
--->
<cfcomponent output="false" singleton="true">
	<!--- Pseudo-constructor --->
	<cfscript>
		function reset() {
			variables.instance = {};
			/* An array of all routes */
			variables.instance.routes = [];
			/* A array of routes */
			variables.instance.REURIRouteMap = [];
			/* A structure of named routes keyed by name */
			variables.instance.namedRoutes = {};
			/* An array of connected routes */
			variables.instance.connectedRoutes = [];
		
			variables.Pattern = CreateObject("java", "java.util.regex.Pattern");
		
			/* Pre-compile static RegEX to save time */
			variables.instance.NamedArgPattern = variables.Pattern.compile("/?:(?<namedArg>[^:/$]+)");
			variables.instance.RoutePathPattern = variables.Pattern.compile("(?<slash>/?):(?<namedArg>[^:/$]+)");
			
		} reset();
	</cfscript>
	
	<cffunction name="addNamed" output="false" access="public">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="path" type="string" required="true" />
		<cfargument name="parameters" type="struct" required="true" />
		<cfargument name="options" type="struct" default="#StructNew()#" />
		<cfset addRoute(arguments) />
		<cfset addNamedRoute(arguments.name, arguments) />
		<cfset mapRouteByREURI(parseRoutePathToREURI(arguments.path, arguments.parameters), arguments) />
	</cffunction>
	
	<cffunction name="add" output="false" access="public">
		<cfargument name="path" type="string" required="true" />
		<cfargument name="parameters" type="struct" required="true" />
		<cfargument name="options" type="struct" default="#StructNew()#" />
		<cfif !isConnectedRoute(arguments.path) >
			<cfset addRoute(arguments) />
			<cfset addConnectedRoute(arguments) />
			<cfset mapRouteByREURI(parseRoutePathToREURI(arguments.path, arguments.parameters), arguments) />
		</cfif>

		<cfreturn this />
	</cffunction>

	<cffunction name="isConnectedRoute">
		<cfargument name="path" type="string" required="true" hint="" displayname="path" />
		<cfloop array="#variables.instance.connectedRoutes#" index="route">
			<cfif arguments.path IS route.PATH >
				<cfreturn true />
			</cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>
	
	<cffunction name="findRouteByURI" output="false" access="public">
		<cfargument name="uri" type="string" required="true" />
		<cfargument name="assignToUrlScope" type="boolean" default="true" />

		<cfset var local = {} />
		
		<cfloop index="indexRoute" array="#variables.instance.REURIRouteMap#">
			
			<!--- Ugly check here that will validate a empty URI/Route-Path --->
			<cfset local.thisRoute = indexRoute.REURI />
			<cfif (Len(local.thisRoute) EQ 0 AND Len(arguments.uri) EQ 0)
				OR (Len(local.thisRoute) GT 0 AND REFindNoCase(local.thisRoute, arguments.uri) NEQ 0)>
				<cfset local.routeDetails = indexRoute /> <!--- //variables.instance.REURIRouteMap[local.thisRoute] --->

				<!--- Extract "URL" variables from named arguments --->
				<cfset local.NamedArgMatcher = variables.instance.NamedArgPattern.matcher(local.routeDetails.path) />
				<cfset local.ValueMatcher = variables.Pattern.compile("(?i)"&local.thisRoute).matcher(arguments.uri) />
				<cfset local.ValueMatcher.find() />
				<cfset local.i = 1 />
				<!--- Loop over named arguments in path and populate URL variables --->
				<cfloop condition="local.NamedArgMatcher.find()">
					<cfset local.valueGroup = local.ValueMatcher.group(local.i++) />
					<cfif arguments.assignToUrlScope IS true >
						<cfset url[local.NamedArgMatcher.group('namedArg')] = local.valueGroup />
					</cfif>
					<cfset local.routeDetails.url[local.NamedArgMatcher.group('namedArg')] = local.valueGroup />
					<cfset local.routeDetails.parameters[local.NamedArgMatcher.group('namedArg')] = local.valueGroup />
				</cfloop>
				<cfreturn local.routeDetails />
			</cfif>
		</cfloop>
		<cfreturn false />
	</cffunction>

	<cffunction name="setCurrentRoute">
		<cfargument name="route" type="struct" required="true" />
		<cfset variables.currentRoute = arguments.route />
	</cffunction>

	<cffunction name="getCurrentRoute">
		<cfreturn structKeyExists(variables, 'currentRoute') ? variables.currentRoute : {} />
	</cffunction>
	
	<cffunction name="findRouteByName" output="false" access="public">
		<cfargument name="name" type="string" required="true" />
		<cfif StructKeyExists(variables.instance.namedRoutes, arguments.name)>
			<cfreturn variables.instance.namedRoutes[arguments.name] />
		</cfif>
		<cfreturn false />
	</cffunction>
	
	<cffunction name="getRoutes" output="false" access="public">
		<cfreturn variables.instance.routes />
	</cffunction>
	
	<cffunction name="getRoutePathArguments" output="false" access="public">
		<cfargument name="path" type="string" required="true" />
		<cfset var local = {} />
		<cfset local.arguments = [] />
		<cfset local.Matcher = variables.instance.NamedArgPattern.matcher(arguments.path) />
		<cfloop condition="local.Matcher.find()">
			<cfset ArrayAppend(local.arguments, local.Matcher.group(1)) />
		</cfloop>
		<cfreturn local.arguments />
	</cffunction>
	
	<!---
		PRIVATE
	--->
	
	<cffunction name="parseRoutePathToREURI" output="false" access="private">

		<cfargument name="path" type="string" required="true" />
		<cfargument name="parameters" type="struct" required="true" />

		<cfset var local = {} />
		<cfset local.newPath = arguments.path />
		<!--- Look for arguments --->
		<cfset local.Matcher = variables.instance.RoutePathPattern.matcher(local.newPath) />

		<!--- Loop over each argument in the path --->
		<cfloop condition="local.Matcher.find()">
			
			<cfset local.thisNamedArg = local.Matcher.group('namedArg') />
			<!--- Check if we have a validator (regex) for the named argument --->
			<cfif StructKeyExists(arguments.parameters, local.thisNamedArg) AND IsSimpleValue(arguments.parameters[local.thisNamedArg])>
				<cfset local.newPath = Replace(local.newPath, local.Matcher.group(),
					local.Matcher.group('slash') & "(" & arguments.parameters[local.thisNamedArg] & ")") />
			<cfelse>
				<cfset local.newPath = Replace(local.newPath, local.Matcher.group(),
					local.Matcher.group('slash') & "([^/]+)") />
			</cfif>
		</cfloop>
		<!--- Leave root route alone --->
		<cfif local.newPath NEQ "">
			<cfset local.newPath = "^" & local.newPath & "/$" />
		</cfif>
		<cfreturn local.newPath />
	</cffunction>
	
	<cffunction name="addRoute" output="false" access="private">
		<cfargument name="route" type="struct" required="true" />
		<cfreturn ArrayAppend(variables.instance.routes, arguments.route) />
	</cffunction>
	
	<cffunction name="mapRouteByREURI" output="false" access="private">
		<cfargument name="REURI" type="string" required="true" />
		<cfargument name="route" type="struct" required="true" />
		<cfset var arguments.route.REURI = arguments.REURI />
		<!--- <cfreturn StructInsert(variables.instance.REURIRouteMap, arguments.REURI, arguments.route, true) /> --->
		<cfreturn ArrayAppend(variables.instance.REURIRouteMap, arguments.route) />
	</cffunction>
	
	<cffunction name="addNamedRoute" output="false" access="private">
		<cfargument name="name" type="string" required="true" />
		<cfargument name="route" type="struct" required="true" />
		<cfreturn StructInsert(variables.instance.namedRoutes, arguments.name, arguments.route, true) />
	</cffunction>
	
	<cffunction name="addConnectedRoute" output="false" access="private">
		<cfargument name="route" type="struct" required="true" />
		<cfreturn ArrayAppend(variables.instance.connectedRoutes, arguments.route) />
	</cffunction>
	
	<cffunction name="dump" output="true" access="public">
		<cfdump var="#variables.instance#" />
	</cffunction>
</cfcomponent>
