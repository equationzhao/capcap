import XCTest
import AppKit
@testable import capcap

final class MagnifierLensPanelTests: XCTestCase {

    func testPixelCoordinateMapsGlobalToImageSpace() {
        // Screen occupies (0, 0) → (1440, 900) in points. Snapshot is 2880×1800
        // (2x scale). Cursor is at the screen center (720, 450).
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let snapshotSize = CGSize(width: 2880, height: 1800)
        let globalPoint = NSPoint(x: 720, y: 450)

        let mapped = MagnifierLensPanelSampler.pixelCoordinate(
            globalPoint: globalPoint,
            screenFrame: screenFrame,
            snapshotSize: snapshotSize
        )

        XCTAssertEqual(mapped.x, 1440, accuracy: 0.001)
        XCTAssertEqual(mapped.y, 900, accuracy: 0.001)
    }

    func testPixelCoordinateHandlesOffsetScreens() {
        // Secondary screen placed to the LEFT of the primary. Its AppKit frame
        // starts at x = -1920 and extends to x = 0. Cursor sits at the
        // secondary screen's center in absolute desktop coords.
        let screenFrame = NSRect(x: -1920, y: 0, width: 1920, height: 1080)
        let snapshotSize = CGSize(width: 1920, height: 1080)
        let globalPoint = NSPoint(x: -960, y: 540)

        let mapped = MagnifierLensPanelSampler.pixelCoordinate(
            globalPoint: globalPoint,
            screenFrame: screenFrame,
            snapshotSize: snapshotSize
        )

        XCTAssertEqual(mapped.x, 960, accuracy: 0.001)
        XCTAssertEqual(mapped.y, 540, accuracy: 0.001)
    }

    /// Verifies the y-axis is read correctly: each row of the snapshot
    /// has a distinct colour so a flipped sample would be detected.
    func testPixelCoordinateClampsToValidRange() {
        // Mouse on the very top edge of the screen should map to the top row
        // (y=0), not out-of-bounds.
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let snapshotSize = CGSize(width: 2880, height: 1800)
        let mapped = MagnifierLensPanelSampler.pixelCoordinate(
            globalPoint: NSPoint(x: 720, y: 900), // top edge in AppKit coords
            screenFrame: screenFrame,
            snapshotSize: snapshotSize
        )
        XCTAssertEqual(mapped.y, 0, accuracy: 0.001)
    }

    func testDefaultsLensVisualDefaults() {
        let keys = [
            "magnifierLensPanelMagnifiedSize",
            "magnifierLensPanelMagnification",
            "magnifierLensPanelOffsetX",
            "magnifierLensPanelOffsetY",
            "magnifierLensPanelFollowSystemAppearance",
            "magnifierLensPanelDarkBackgroundAlpha",
            "magnifierLensPanelLightBackgroundAlpha",
            "magnifierLensPanelDarkBackgroundRed",
            "magnifierLensPanelLightBackgroundGreen",
            "magnifierLensPanelCrosshairRed",
            "magnifierLensPanelCrosshairGreen",
            "magnifierLensPanelCrosshairBlue",
            "magnifierLensPanelCrosshairAlpha",
            "magnifierLensPanelCrosshairWidth",
        ]
        defer {
            for key in keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        // Magnified size defaults to 144.
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelMagnifiedSize")
        XCTAssertEqual(Defaults.magnifierLensPanelMagnifiedSize, 144)
        Defaults.magnifierLensPanelMagnifiedSize = 123
        XCTAssertEqual(Defaults.magnifierLensPanelMagnifiedSize, 144)
        Defaults.magnifierLensPanelMagnifiedSize = 192
        XCTAssertEqual(Defaults.magnifierLensPanelMagnifiedSize, 192)
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelMagnification")
        XCTAssertEqual(Defaults.magnifierLensPanelMagnification, 4.0, accuracy: 0.001)
        Defaults.magnifierLensPanelMagnification = .infinity
        XCTAssertEqual(Defaults.magnifierLensPanelMagnification, 4.0, accuracy: 0.001)
        Defaults.magnifierLensPanelMagnification = 0.25
        XCTAssertEqual(Defaults.magnifierLensPanelMagnification, 1.0, accuracy: 0.001)
        Defaults.magnifierLensPanelMagnification = 40
        XCTAssertEqual(Defaults.magnifierLensPanelMagnification, 16.0, accuracy: 0.001)
        Defaults.magnifierLensPanelMagnification = 8
        XCTAssertEqual(Defaults.magnifierLensPanelMagnification, 8.0, accuracy: 0.001)
        // Offsets default to (15, 15).
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelOffsetX")
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelOffsetY")
        XCTAssertEqual(Defaults.magnifierLensPanelOffsetX, 15)
        XCTAssertEqual(Defaults.magnifierLensPanelOffsetY, 15)
        // Hint toggles default on.
        // Follow-system defaults on; dark/light RGBA defaults match docs.
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelFollowSystemAppearance")
        XCTAssertTrue(Defaults.magnifierLensPanelFollowSystemAppearance)
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelDarkBackgroundAlpha")
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelLightBackgroundAlpha")
        XCTAssertEqual(Defaults.magnifierLensPanelDarkBackgroundAlpha, 0.8, accuracy: 0.001)
        XCTAssertEqual(Defaults.magnifierLensPanelLightBackgroundAlpha, 0.8, accuracy: 0.001)
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelCrosshairRed")
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelCrosshairGreen")
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelCrosshairBlue")
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelCrosshairAlpha")
        UserDefaults.standard.removeObject(forKey: "magnifierLensPanelCrosshairWidth")
        XCTAssertEqual(Defaults.magnifierLensPanelCrosshairRed, 0xA8 / 255.0, accuracy: 0.001)
        XCTAssertEqual(Defaults.magnifierLensPanelCrosshairGreen, 0xBD / 255.0, accuracy: 0.001)
        XCTAssertEqual(Defaults.magnifierLensPanelCrosshairBlue, 0xFC / 255.0, accuracy: 0.001)
        XCTAssertEqual(Defaults.magnifierLensPanelCrosshairAlpha, 0.65, accuracy: 0.001)
        XCTAssertEqual(Defaults.magnifierLensPanelCrosshairWidth, 6.0, accuracy: 0.001)
        // Alpha setter clamps to 0…1.
        Defaults.magnifierLensPanelDarkBackgroundAlpha = 5
        XCTAssertEqual(Defaults.magnifierLensPanelDarkBackgroundAlpha, 1.0, accuracy: 0.001)
        Defaults.magnifierLensPanelDarkBackgroundAlpha = -1
        XCTAssertEqual(Defaults.magnifierLensPanelDarkBackgroundAlpha, 0.0, accuracy: 0.001)
        Defaults.magnifierLensPanelDarkBackgroundRed = 5
        XCTAssertEqual(Defaults.magnifierLensPanelDarkBackgroundRed, 1.0, accuracy: 0.001)
        Defaults.magnifierLensPanelDarkBackgroundRed = -1
        XCTAssertEqual(Defaults.magnifierLensPanelDarkBackgroundRed, 0.0, accuracy: 0.001)
        Defaults.magnifierLensPanelLightBackgroundGreen = 5
        XCTAssertEqual(Defaults.magnifierLensPanelLightBackgroundGreen, 1.0, accuracy: 0.001)
        Defaults.magnifierLensPanelLightBackgroundGreen = -1
        XCTAssertEqual(Defaults.magnifierLensPanelLightBackgroundGreen, 0.0, accuracy: 0.001)
        Defaults.magnifierLensPanelCrosshairBlue = 5
        XCTAssertEqual(Defaults.magnifierLensPanelCrosshairBlue, 1.0, accuracy: 0.001)
        Defaults.magnifierLensPanelCrosshairBlue = -1
        XCTAssertEqual(Defaults.magnifierLensPanelCrosshairBlue, 0.0, accuracy: 0.001)
    }
}
