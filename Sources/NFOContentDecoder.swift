import CoreFoundation
import Foundation

enum NFOContentDecoder {
    private static let utf8ByteOrderMark = Data([0xEF, 0xBB, 0xBF])

    static func decode(_ data: Data) throws -> String {
        let content: String

        if data.starts(with: utf8ByteOrderMark),
           let utf8Content = String(data: data.dropFirst(utf8ByteOrderMark.count), encoding: .utf8) {
            content = utf8Content
        } else {
            let cfEncoding = CFStringConvertWindowsCodepageToEncoding(437)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            let encoding = String.Encoding(rawValue: nsEncoding)

            guard let cp437Content = String(data: data, encoding: encoding) else {
                throw NSError(
                    domain: NSCocoaErrorDomain,
                    code: NSFileReadInapplicableStringEncodingError
                )
            }
            content = cp437Content
        }

        return removingTrailingLineEnding(from: content)
    }

    private static func removingTrailingLineEnding(from content: String) -> String {
        var scalars = content.unicodeScalars
        guard scalars.last == "\n" else { return content }

        scalars.removeLast()
        if scalars.last == "\r" {
            scalars.removeLast()
        }
        return String(scalars)
    }
}
