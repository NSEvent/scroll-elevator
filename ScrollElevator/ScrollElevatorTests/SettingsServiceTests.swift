import XCTest
@testable import ScrollElevator

final class SettingsServiceTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ScrollElevatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testCruiseSpeedDefaultsPersistsAndResets() {
        let settings = SettingsService(defaults: defaults)
        XCTAssertEqual(settings.cruiseSpeedMultiplier, 1)
        XCTAssertTrue(settings.isCruiseDefault)

        settings.cruiseSpeedMultiplier = 0.65
        XCTAssertFalse(settings.isCruiseDefault)

        let reloaded = SettingsService(defaults: defaults)
        XCTAssertEqual(reloaded.cruiseSpeedMultiplier, 0.65, accuracy: 0.001)

        reloaded.resetCruise()
        XCTAssertEqual(reloaded.cruiseSpeedMultiplier, 1)
        XCTAssertTrue(reloaded.isCruiseDefault)
    }

    func testCruiseSpeedClampsCorruptStoredValueOnLoad() {
        defaults.set(99.0, forKey: "cruiseSpeedMultiplier")

        let settings = SettingsService(defaults: defaults)

        XCTAssertEqual(settings.cruiseSpeedMultiplier, 2)
    }
}
