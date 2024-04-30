//
//  RouteParameterConvertible.swift
//

import Foundation

/**
 Protocol for converting route parameters into strongly-typed values.
 */
public protocol RouteParameterConvertible {
    /**
     Convert the parameter string value into the conforming value type if possible.
     - Returns: The parameter converted into the type or `nil` if a conversion is not possible.
     */
    static func from(parameter: String) -> Self?
}

/// Add ``RouteParameterConvertible`` conformance to ``Swift/String``.
extension String: RouteParameterConvertible {
    public static func from(parameter: String) -> String? {
        return parameter
    }
}

/// Add ``RouteParameterConvertible`` conformance to ``Swift/Int``.
extension Int: RouteParameterConvertible {
    public static func from(parameter: String) -> Int? {
        return Int(parameter)
    }
}

/// Add ``RouteParameterConvertible`` conformance to ``Swift/Double``.
extension Double: RouteParameterConvertible {
    public static func from(parameter: String) -> Double? {
        return Double(parameter)
    }
}

/// Add ``RouteParameterConvertible`` conformance to ``Swift/Float``.
extension Float: RouteParameterConvertible {
    public static func from(parameter: String) -> Float? {
        return Float(parameter)
    }
}
