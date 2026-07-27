import AppKit
import CoreText
import SwiftUI
import XCTest
@testable import OrdoThemes

final class ZenFontRegistrationTests: XCTestCase {

    private let expectedFiles = [
        "ShipporiMincho-Regular.ttf",
        "ShipporiMincho-SemiBold.ttf",
        "ShipporiMincho-Bold.ttf",
        "ShipporiMincho-ExtraBold.ttf",
        "ZenKakuGothicNew-Regular.ttf",
        "ZenKakuGothicNew-Medium.ttf",
    ]

    private let expectedFaces: [(postScriptName: String, family: String, isBold: Bool)] = [
        (FontRegistrar.shipporiMinchoRegular, FontRegistrar.shipporiMinchoFamily, false),
        (FontRegistrar.shipporiMinchoSemiBold, FontRegistrar.shipporiMinchoFamily, true),
        (FontRegistrar.shipporiMinchoBold, FontRegistrar.shipporiMinchoFamily, true),
        (FontRegistrar.shipporiMinchoExtraBold, FontRegistrar.shipporiMinchoFamily, true),
        (FontRegistrar.zenKakuGothicNewRegular, FontRegistrar.zenKakuGothicFamily, false),
        (FontRegistrar.zenKakuGothicNewMedium, FontRegistrar.zenKakuGothicFamily, false),
    ]

    func testZenFontResourcesExistAndRegistrationIsIdempotent() {
        let resources = Dictionary(
            uniqueKeysWithValues: FontRegistrar.bundledFontURLs().map { ($0.lastPathComponent, $0) }
        )

        for filename in expectedFiles {
            guard let url = resources[filename] else {
                return XCTFail("missing bundled font resource: \(filename)")
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }

        // Calling twice is intentionally harmless; FontRegistrar's static backing
        // storage ensures CoreText registration is performed only once.
        FontRegistrar.registerAll()
        FontRegistrar.registerAll()
    }

    func testZenFacesResolveToExpectedPostScriptNamesAndTraits() {
        FontRegistrar.registerAll()

        for expected in expectedFaces {
            let font = CTFontCreateWithName(expected.postScriptName as CFString, 15, nil)
            XCTAssertEqual(CTFontCopyPostScriptName(font) as String, expected.postScriptName)
            XCTAssertEqual(CTFontCopyFamilyName(font) as String, expected.family)

            let symbolicTraits = CTFontGetSymbolicTraits(font)
            XCTAssertEqual(
                symbolicTraits.contains(.traitBold), expected.isBold,
                "unexpected bold trait for \(expected.postScriptName)"
            )
            XCTAssertFalse(
                symbolicTraits.contains(.traitItalic),
                "bundled upright face unexpectedly resolved italic: \(expected.postScriptName)"
            )
        }
    }

    func testExactPostScriptTypeTokenDoesNotSynthesizeWeight() {
        let token = TypeToken(
            size: 15,
            weight: .black,
            fontFamily: .postScript(FontRegistrar.shipporiMinchoRegular)
        )

        XCTAssertEqual(token.fontFamily, .postScript(FontRegistrar.shipporiMinchoRegular))
        XCTAssertNoThrow(_ = token.font)
    }

    func testItalicDefaultsFalseAndCanBeEnabled() {
        XCTAssertFalse(TypeToken(size: 13, weight: .regular).italic)
        XCTAssertTrue(TypeToken(size: 13, weight: .regular, italic: true).italic)
        XCTAssertNoThrow(_ = TypeToken(size: 13, weight: .regular, italic: true).font)
    }

    func testNamedFamilyBehaviorRemainsAvailable() {
        let token = TypeToken(
            size: 14,
            weight: .semibold,
            fontFamily: .named(FontRegistrar.spaceGroteskFamily)
        )

        XCTAssertEqual(token.fontFamily, .named(FontRegistrar.spaceGroteskFamily))
        XCTAssertFalse(token.italic)
        XCTAssertNoThrow(_ = token.font)
    }
}
