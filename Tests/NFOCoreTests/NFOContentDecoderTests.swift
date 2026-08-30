import Foundation
import XCTest
@testable import NFOCore

final class NFOContentDecoderTests: XCTestCase {
    func testDecodesASCIIAndRemovesOneTrailingLineEnding() throws {
        XCTAssertEqual(
            try NFOContentDecoder.decode(Data("first\r\nsecond\r\n".utf8)),
            "first\r\nsecond"
        )
        XCTAssertEqual(
            try NFOContentDecoder.decode(Data("first\nsecond\n\n".utf8)),
            "first\nsecond\n"
        )
    }

    func testDecodesBOMMarkedUTF8() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(contentsOf: "café\n".utf8)

        XCTAssertEqual(try NFOContentDecoder.decode(data), "café")
    }

    func testFallsBackToCodePage437() throws {
        let decoded = try NFOContentDecoder.decode(Data([0xDB, 0x20, 0xB3]))
        XCTAssertEqual(decoded, "█ │")
    }

    func testValidUTF8ByteSequenceStillUsesCodePage437WithoutBOM() throws {
        XCTAssertEqual(
            try NFOContentDecoder.decode(Data([0xC3, 0xA9])),
            "├⌐"
        )
    }

    func testDoesNotRemoveBareCarriageReturn() throws {
        XCTAssertEqual(
            try NFOContentDecoder.decode(Data("line\r".utf8)),
            "line\r"
        )
    }
}
