import Foundation
import XCTest
@testable import ClawNest

final class LanguagePreferenceStoreTests: XCTestCase {
    func testLanguageDefaultsToEnglish() {
        let defaults = makeDefaults()
        let store = UserDefaultsLanguagePreferenceStore(defaults: defaults)

        XCTAssertEqual(store.load(), .english)
    }

    func testLanguagePreferencePersistsSimplifiedChinese() {
        let defaults = makeDefaults()
        let store = UserDefaultsLanguagePreferenceStore(defaults: defaults)

        store.save(.simplifiedChinese)

        XCTAssertEqual(store.load(), .simplifiedChinese)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LanguagePreferenceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
