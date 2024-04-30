//
//  RouteRegexForming.swift
//

import Foundation

protocol RouteRegexForming {
    typealias RouteRegexFragment = Regex<AnyRegexOutput>

    static var routeRegexFragment: String { get }
}

extension String: RouteRegexForming {
    static var routeRegexFragment: String { #"[^\/]+[^\/\s]"# }
}

extension Int: RouteRegexForming {
    static var routeRegexFragment: String { #"\d+"# }
}
