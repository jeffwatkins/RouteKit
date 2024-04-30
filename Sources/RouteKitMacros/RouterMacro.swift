//
//  CustomCodable.swift
//

import Foundation

import SwiftSyntax
import SwiftSyntaxMacros

extension FunctionParameterClauseSyntax {

    var doccString: String {
        var parts: [String] = []
        parts.append(self.leftParen.text)
        for p in self.parameters {
            parts.append("\(p.firstName.text):")
        }
        parts.append(self.rightParen.text)
        return parts.joined()
    }

}

struct Route {
    struct Parameter: Hashable {
        let name: String?
        let syntax: FunctionParameterSyntax
        let capture: String
    }

    let path: String
    let functionName: String
    let docComment: String
    let returnType: TypeSyntax?
    let parameters: [Parameter]
    let regex: String
    let regexName: String?
    let isAsync: Bool
    let isThrowing: Bool

    static let parameterRegex = try! Regex(##":([^!"#$%&'()*+,\-.\/:;<=>?@[\\]^`{|}~\s]+)"##)

    static func regex(from path: String, with parameters: [String: Route.Parameter], method: String) throws -> String {
        guard let components = URLComponents(string: path) else {
            throw CustomError.message("Invalid route: \(path)")
        }
        let pathParts = components.path.split(separator: "/")
        var parameterNames = parameters

        // Collect a regular expression for matching future URLs
        var regexComposite = ""

        for part in pathParts {
            regexComposite += "\\/"
            guard let match = try? parameterRegex.wholeMatch(in: part) else {
                // Handle parts that don't match
                // TODO: escape any special characters
                regexComposite += "\(part)"
                continue
            }
            guard let parameterName = match[1].substring else {
                throw CustomError.message("No match for parameter")
            }
            guard let parameter = parameterNames.removeValue(forKey: String(parameterName)) else {
                throw CustomError.message("Method \(method) does not define parameter: \(parameterName)")
            }
            regexComposite += "(?<\(parameter.capture)>[^\\/]+)"
        }

        guard parameterNames.isEmpty else {
            let message = parameterNames.count > 1 ?
            "Route missing parameters found in method" :
            "Route missing parameter found in method"

            throw CustomError.message("\(message): \(parameterNames.keys.joined(separator: ", "))")
        }
        return "Regex(#\"\(regexComposite)\"#)"
    }

    static func from(function: FunctionDeclSyntax, regexName: String? = nil) throws -> Route {
        let functionName = function.name.text
        guard let macro = function.routeMacro else { throw CustomError.message("No @Route annotation for: \(functionName)") }
        guard let arguments = macro.arguments?.as(LabeledExprListSyntax.self),

                let segments = arguments.first?.expression.as(StringLiteralExprSyntax.self)?.segments,
              case .stringSegment(let path)? = segments.first else {
            throw CustomError.message("@Route annotation requires a string literal")
        }

        let functionParameters = function.signature.parameterClause.parameters
        var parametersByName: [String: Route.Parameter] = [:]
        var parameters: [Route.Parameter] = []
        var parameterIndex = 0

        for p in functionParameters {
            let parameter: Route.Parameter
            let parameterName: String

            let capture = "parameter\(parameterIndex)"
            parameterIndex += 1

            if p.firstName.text == "_",
               let secondName = p.secondName {
                parameterName = secondName.text
                parameter = Route.Parameter(name: nil, syntax: p, capture: capture)
            } else {
                parameterName = p.firstName.text
                parameter = Route.Parameter(name: parameterName, syntax: p, capture: capture)
            }
            parameters.append(parameter)
            parametersByName[parameterName] = parameter
        }

        let regex = try regex(from: path.content.text, with: parametersByName, method: functionName)

        return Route(
            path: path.content.text,
            functionName: functionName,
            docComment: "* `\(path.content.text)` → ``\(functionName)\(function.signature.parameterClause.doccString)``",
            returnType: function.signature.returnClause?.type,
            parameters: parameters,
            regex: regex,
            regexName: regexName,
            isAsync: (function.signature.effectSpecifiers?.asyncSpecifier?.presence ?? .missing) == .present,
            isThrowing: (function.signature.effectSpecifiers?.throwsSpecifier?.presence ?? .missing) == .present
        )
    }
}

public struct RouterMacro {

}

extension RouterMacro: ExtensionMacro {
    public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                                 attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                                 providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
                                 conformingTo protocols: [SwiftSyntax.TypeSyntax],
                                 in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        return [try ExtensionDeclSyntax("extension \(type): Router {}")]
    }
}

private extension DeclSyntaxProtocol {
    var isMethod: Bool {
        return self.as(FunctionDeclSyntax.self) != nil
    }

    var routeMacro: AttributeSyntax? {
        guard let method = self.as(FunctionDeclSyntax.self) else { return nil }
        let attribute = method.attributes.first(where: { element in
            element.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.description == "Route"
        })
        return attribute?.as(AttributeSyntax.self)
    }
}


extension RouterMacro: MemberMacro {
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw CustomError.message("@Route macro must be attached to a class definition.")
        }
        let className = classDecl.name.text

        let memberList = declaration.memberBlock.members.filter {
            $0.decl.isMethod
        }

        var routesByReturnType: [String:[Route]] = [:]

        for member in memberList {
            guard let method = member.decl.as(FunctionDeclSyntax.self) else { continue }
            let regexName = context.makeUniqueName("regex")
            guard let route = try? Route.from(function: method, regexName: regexName.text) else { continue }
            let routes: [Route]

            if let returnType = route.returnType {
                routes = routesByReturnType[returnType.description, default: []]
                routesByReturnType[returnType.description] = routes + [route]
            } else {
                routes = routesByReturnType["Void", default: []]
                routesByReturnType["Void"] = routes + [route]
            }
        }

        var routingFns: [DeclSyntax] = []

        for (type, routes) in routesByReturnType {
            var routeChecks: [String] = []
            var docComments: [String] = []

            for route in routes {
                guard let regexName = route.regexName else { continue }

                var callParameters: [String] = []
                var optionals: [String] = []

                docComments.append("\(route.docComment)")

                let nonOptionals = route.parameters.flatMap { p -> [String] in
                    let capture = p.capture

                    let tempParam = context.makeUniqueName(capture).text
                    let optionalType = p.syntax.type.as(OptionalTypeSyntax.self)

                    if let parameterName = p.name {
                        callParameters.append("\(parameterName): \(tempParam)")
                    } else {
                        callParameters.append(tempParam)
                    }

                    let stringValue = context.makeUniqueName("stringValue_\(capture)")
                    let result = [
                        "let \(stringValue) = match[\"\(capture)\"]?.substring"
                    ]

                    if let optionalType {
                        // Parameter value is optional, so we don't need to fail if we can't find it.
                        optionals.append(
                            "let \(tempParam): \(p.syntax.type) = \(optionalType.wrappedType).from(parameter: String(\(stringValue)))"
                        )
                        return result
                    } else {
                        return result + [
                            "let \(tempParam): \(p.syntax.type) = \(p.syntax.type).from(parameter: String(\(stringValue)))"
                        ]
                    }
                }

                var callPrefix: [String] = []
                if route.isThrowing {
                    callPrefix.append("try")
                }
                if route.isAsync {
                    callPrefix.append("await")
                }

                let match = callParameters.isEmpty ? "_" : "match"

                routeChecks.append("""
                // \(route.path)
                let \(regexName) = try! \(route.regex)

                if let \(match) = try \(regexName).wholeMatch(in: path)\(nonOptionals.isEmpty ? "" : ",")
                    \(nonOptionals.joined(separator: ",\n")) {
                    \(optionals.joined(separator: "\n"))
                    \(type != "Void" ? "return " : "")
                    \(callPrefix.joined(separator: " ")) \(route.functionName)(\(callParameters.joined(separator: ",\n")))
                    \(type == "Void" ? "return " : "")
                }
                """)
            }

            let routeFn: DeclSyntax
            if type == "Void" {
                routeFn = """
                /**
                    Route a path string to the appropriate function in \(raw: className).

                    This function handles the following paths:
                    \(raw: docComments.joined(separator: "\n"))
                
                    - Throws: RouterError.unmatchedPath if the path does not match a route marked with a ``Route`` macro.
                 */
                public func route(_ path: String) async throws {
                \(raw: routeChecks.joined(separator: "\n"))
                throw RouterError.unmatchedPath("No matching route for path: \\(path)")
                }
                """
            } else {
                routeFn = """
                /**
                    Route a path string to the appropriate function in \(raw: className).

                    This function handles the following paths:
                    \(raw: docComments.joined(separator: "\n"))

                    - Returns: \(raw: type)
                    - Throws: RouterError.unmatchedPath if the path does not match a route marked with a ``Route`` macro.
                 */
                public func route(_ path: String) async throws -> \(raw: type) {
                \(raw: routeChecks.joined(separator: "\n"))
                throw RouterError.unmatchedPath("No matching route for path: \\(path)")
                }
                """
            }
            routingFns.append(routeFn)
        }

        return routingFns
    }
}

public struct RouteMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let method = declaration.as(FunctionDeclSyntax.self) else { return [] }
        let _ = try Route.from(function: method)

        // Does nothing, used only to decorate members with data
        return []
    }
}
