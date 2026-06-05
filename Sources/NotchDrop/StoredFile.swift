import Foundation
import SwiftUI

/// Represents a file stored in the notch drop zone.
/// The file is moved into internal storage; originalURL tracks where it came from.
struct StoredFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL              // current location in internal storage
    let originalURL: URL      // original location (for restore)
    let name: String
    let size: Int64
    let icon: NSImage
    let addedDate: Date

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    init(url: URL, originalURL: URL) {
        self.url = url
        self.originalURL = originalURL
        self.name = url.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self.addedDate = Date()
        var fileSize: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            fileSize = (attrs[.size] as? Int64) ?? 0
        }
        self.size = fileSize
    }

    static func == (lhs: StoredFile, rhs: StoredFile) -> Bool { lhs.id == rhs.id }
}
