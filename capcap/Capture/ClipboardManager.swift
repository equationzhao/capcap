import AppKit

struct ClipboardManager {
    static func copyToClipboard(
        image: NSImage,
        pasteboard: NSPasteboard = .general
    ) {
        pasteboard.clearContents()

        if let pngData = image.pngDataPreservingBacking() {
            pasteboard.setData(pngData, forType: .png)
        }

        if let tiffData = image.tiffDataPreservingBacking() {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }

    static func copyToClipboard(imageOutput: EncodedClipboardImageOutput) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(imageOutput.primary.data, forType: imageOutput.primary.pasteboardType)
        if let tiffData = imageOutput.tiffData {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }

    @discardableResult
    static func copyFileURLsToClipboard(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects(urls.map { $0 as NSURL }) else { return false }
        return true
    }

    static func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
