//
//  Clipboard.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 11/02/2024.
//

import Foundation

#if os(macOS)
import AppKit
#elseif !os(watchOS)
import UIKit
#endif

final class Clipboard: Sendable {
    static let shared = Clipboard()

    func setString(_ message: String) {
#if os(iOS)
        UIPasteboard.general.string = message
#elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(message, forType: .string)
#endif
        // watchOS: no pasteboard API, no-op
    }

    func getImage() -> PlatformImage? {
#if os(iOS)
        return UIPasteboard.general.image
#elseif os(macOS)
        let pb = NSPasteboard.general
        let type = NSPasteboard.PasteboardType.tiff
        guard let imgData = pb.data(forType: type) else { return nil }
        return NSImage(data: imgData)
#else
        return nil
#endif
    }

    func getText() -> String? {
#if os(iOS) || os(visionOS)
        return UIPasteboard.general.string
#elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
#else
        return nil
#endif
    }

    func paste() -> (text: String?, image: PlatformImage?) {
        let text = getText()
        let image = getImage()
        return (text, image)
    }
}
