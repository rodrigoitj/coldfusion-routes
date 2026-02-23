<cfscript>
/**
 * Lightweight tests for Routing.cfc.
 * Run with a CFML engine, for example:
 *   box server start
 *   box server open tests/RoutingTests.cfm
 */

function assertTrue(required boolean condition, required string message) {
	if (!arguments.condition) {
		throw(type="AssertionFailed", message=arguments.message);
	}
}

function assertEquals(required any expected, required any actual, required string message) {
	if (!isSimpleValue(arguments.expected) || !isSimpleValue(arguments.actual)) {
		if (!serializeJSON(arguments.expected).equals(serializeJSON(arguments.actual))) {
			throw(
				type="AssertionFailed",
				message=arguments.message & " | expected: " & serializeJSON(arguments.expected) & " actual: " & serializeJSON(arguments.actual)
			);
		}
		return;
	}

	if (arguments.expected neq arguments.actual) {
		throw(type="AssertionFailed", message=arguments.message & " | expected: " & arguments.expected & " actual: " & arguments.actual);
	}
}

r = CreateObject("component", "Routing").reset();

// test: add() stores unique connected route paths only once
r.add("analytics", {module="analytics", controller="analytics", action="index"});
r.add("analytics", {module="analytics", controller="analytics", action="index"});
assertEquals(1, arrayLen(r.getRoutes()), "add() should ignore duplicate connected routes");

// test: findRouteByURI() matches and hydrates named arguments
r.add("analytics/property/:property", {module="analytics", controller="analytics", action="set-property", property="[0-9]+"});
matched = r.findRouteByURI("analytics/property/123", false);
assertTrue(isStruct(matched), "findRouteByURI() should return a route struct when matched");
assertEquals("123", matched.url.property, "findRouteByURI() should populate url argument map");
assertEquals("123", matched.parameters.property, "findRouteByURI() should hydrate parameters with captured values");

// test: findRouteByName() returns a duplicate, not mutable internal state
r.addNamed("analyticsNamed", "analytics/revoke", {module="analytics", controller="analytics", action="revoke"});
named = r.findRouteByName("analyticsNamed");
assertTrue(isStruct(named), "findRouteByName() should return route struct for known names");
named.parameters.action = "mutated";
namedAgain = r.findRouteByName("analyticsNamed");
assertEquals("revoke", namedAgain.parameters.action, "findRouteByName() should return a defensive copy");

writeOutput("PASS: Routing tests completed successfully.");
</cfscript>
