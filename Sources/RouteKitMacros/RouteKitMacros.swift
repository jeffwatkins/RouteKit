//
//  RouteKitMacros.swift
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct RoutingKitPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        RouterMacro.self,
        RouteMacro.self
    ]
}

enum CustomError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
            case .message(let text):
                return text
        }
    }
}
