// The Swift Programming Language
// https://docs.swift.org/swift-book

/**
 Annotate a class as conforming to the ``Router`` protocol and generate necessary code to handle routing strings to annotated methods.

 Generates one async throwing `route` method for each unique return type defined by a function annotated by a ``Route`` macro. The `route` method accepts an unnamed string parameter and attempts to invoke the appropriate annotated method.
 */
@attached(extension, conformances: Router)
@attached(member, names: named(route))
public macro Router() = #externalMacro(module: "RouteKitMacros", type: "RouterMacro")

/**
 Annotate a distinct route within this class which conforms to the ``Router`` protocol. For each unique return type of annotated method the class will receive a `route` method of the form:

 ```
 func route(_ path: String) async throws -> Type
 ```

 This makes it possible to route to methods which return typed responses as well as merely perform an action.

 - Parameters:
    - path: This is the route path and should 
 */
@attached(peer)
public macro Route(_ path: String) = #externalMacro(module: "RouteKitMacros", type: "RouteMacro")
