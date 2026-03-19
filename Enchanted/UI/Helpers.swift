//
//  Helpers.swift
//  Re-Enchanted
//
//  Originally created by Augustinas Malinauskas on 09/02/2024.
//

import SwiftUI

#if os(iOS) || os(visionOS) || os(watchOS)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif
