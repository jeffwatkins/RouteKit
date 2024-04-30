//
//  Router.swift
//

import Foundation

public enum RouterError: Error, CustomStringConvertible, Equatable {
    case unmatchedPath(_ message: String)

    public var description: String {
        switch self {
            case .unmatchedPath(let text):
                return text
        }
    }
}

/// A protocol indicating a class performs routing.
public protocol Router {
}
