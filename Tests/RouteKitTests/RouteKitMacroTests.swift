//
//  RouteKitMacroTests.swift
//  

import XCTest
@testable import RouteKit

public struct VenueID {
    let value: Int
}

extension VenueID: RouteParameterConvertible {
    public static func from(parameter: String) -> VenueID? {
        guard let value = Int(parameter) else { return nil }
        return VenueID(value: value)
    }
}

extension VenueID: Equatable {}

extension VenueID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value: value)
    }
}

@Router
public class Foo {
    let expectation: XCTestExpectation?

    init(expectation: XCTestExpectation?) {
        self.expectation = expectation
    }

    /// Something that uses a ``VenueID`` and eventually calls ``book(scheduleID:)``
    @Route("/venue/:venueID/:style")
    public func test(venueID: VenueID, style: String) -> Int {
        XCTAssertEqual(venueID, 2)
        XCTAssertEqual(style, "gold")
        return 1
    }

    @Route("/schedule/:scheduleID")
    public func book(scheduleID: Int) async throws {
        XCTAssertEqual(scheduleID, 1)
        try await Task.sleep(for: .seconds(1))
        self.expectation?.fulfill()
    }

    @Route("/emoji-is-popular/:😀")
    public func emoji(😀: Int) async throws {
        XCTAssertEqual(😀, 2)
        try await Task.sleep(for: .seconds(1))
        self.expectation?.fulfill()
    }

    /// An adjunct to ``test(venueID:style:)``
    public func moof() {

    }
}

func TAAssert<T, E: Error & Equatable>(_ expression: @autoclosure () async throws -> T, throws error: E, message: @autoclosure () -> String = "No exception thrown", in file: StaticString = #file, line: UInt = #line) async {
    var thrownError: Error?
    do {
        _ = try await expression()
        XCTFail(message())
    } catch {
        thrownError = error
    }
    XCTAssertTrue(thrownError is E, "Unexpected error type: \(type(of: thrownError))", file: file, line: line)
    XCTAssertEqual(thrownError as? E, error, file: file, line: line)
}

final class RouteKitMacroTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInvokeTestRoute() async throws {
        let foo = Foo(expectation: nil)
        let result: Int = try await foo.route("/venue/2/gold")
        XCTAssertEqual(result, 1)
    }

    func testAsyncRoute() async throws {
        let expectation = expectation(description: "book complete")
        let foo = Foo(expectation: expectation)
        try await foo.route("/schedule/1") as Void
        await fulfillment(of: [expectation])
    }

    func testAsyncRouteFailsToMatchWithWrongReturnType() async throws {
        let foo = Foo(expectation: nil)
        await TAAssert(try await foo.route("/schedule/1") as Int, throws: RouterError.unmatchedPath("No matching route for path: /schedule/1"))
    }

    func testShouldFailToMatch() async throws {
        let foo = Foo(expectation: nil)
        await TAAssert(try await foo.route("/venue/monkey/gold") as Int, throws: RouterError.unmatchedPath("No matching route for path: /venue/monkey/gold"))
    }

    func testShouldRouteToEmoji() async throws {
        let expectation = expectation(description: "Emoji called")
        let foo = Foo(expectation: expectation)
        try await foo.route("/emoji-is-popular/2") as Void
        await fulfillment(of: [expectation])
    }

}
