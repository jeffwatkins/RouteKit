import XCTest
@testable import RouteKit
@testable import RouteKitMacros

final class RouteKitTests: XCTestCase {

    static let parameterRegex = try! Regex(##":[^!"#$%&'()*+,\-.\/:;<=>?@[\]^`{|}~\s]+"##)

    func testMatchStaticRoute() throws {
        let path = "/venue/:venueID/:style/:😀"
        let components = try XCTUnwrap(URLComponents(string: path))
        let pathParts = components.path.split(separator: "/")

        XCTAssertEqual(pathParts, ["venue", ":venueID", ":style", ":😀"])

        var numberOfMatches = 0
        for part in pathParts {
            guard let match = try Route.parameterRegex.wholeMatch(in: part) else { continue }

            numberOfMatches += 1
        }

        XCTAssertEqual(numberOfMatches, 3)
    }
    
}
