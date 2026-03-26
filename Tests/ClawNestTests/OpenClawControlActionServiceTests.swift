import Foundation
import XCTest
@testable import ClawNest

final class OpenClawControlActionServiceTests: XCTestCase {
    func testOfficialCommandMappingsUseExpectedDefaults() {
        let defaults = OpenClawDefaults.standard(
            homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        )
        let service = OpenClawControlActionService(defaults: defaults, runner: ProcessCommandRunner())

        XCTAssertEqual(service.descriptor(for: .start)?.renderedCommand, "openclaw gateway start")
        XCTAssertEqual(service.descriptor(for: .restart)?.renderedCommand, "openclaw gateway restart")
        XCTAssertEqual(service.descriptor(for: .stop)?.renderedCommand, "openclaw gateway stop")
        XCTAssertEqual(service.descriptor(for: .repair)?.renderedCommand, "openclaw doctor --fix")
    }

    func testNonCommandActionsDoNotExposeDescriptors() {
        let service = OpenClawControlActionService()

        XCTAssertNil(service.descriptor(for: .refresh))
        XCTAssertNil(service.descriptor(for: .openChat))
    }
}
