import Foundation
import SwiftUI

/// Central state — files are **copied** into cache storage but the original
/// file stays at its source location.  The panel references the cache for its
/// own use; drag‑out provides the original URL so the destination gets the real file.
@MainActor
class NotchDropManager: ObservableObject {
    @Published var files: [StoredFile] = []
    @Published var selectedFileIDs: Set<UUID> = []
    @Published var isExpanded = false
    @Published var isDropTargeted = false
    @Published var isHovering = false
    @Published var isDraggingFile = false

    var onFilesEmpty: (() -> Void)?
    var onUserInteraction: (() -> Void)?

    // MARK: - Selection

    var selectedFiles: [StoredFile] { files.filter { selectedFileIDs.contains($0.id) } }

    func selectOnly(_ id: UUID) { selectedFileIDs = [id]; onUserInteraction?() }
    func toggleSelection(_ id: UUID) {
        if selectedFileIDs.contains(id) { selectedFileIDs.remove(id) }
        else { selectedFileIDs.insert(id) }
        onUserInteraction?()
    }
    func selectAll() { selectedFileIDs = Set(files.map(\.id)); onUserInteraction?() }
    func deselectAll() { selectedFileIDs = []; onUserInteraction?() }
    func selectFiles(in rect: CGRect, frames: [UUID: CGRect]) {
        selectedFileIDs = Set(frames.filter { $0.value.intersects(rect) }.keys)
        onUserInteraction?()
    }
    func selectRange(to id: UUID) {
        guard let lastSel = selectedFileIDs.sorted(by: { a, b in
            guard let ia = files.firstIndex(where: { $0.id == a }),
                  let ib = files.firstIndex(where: { $0.id == b }) else { return false }
            return ia < ib
        }).last ?? files.first?.id else { selectOnly(id); return }
        guard let from = files.firstIndex(where: { $0.id == lastSel }),
              let to = files.firstIndex(where: { $0.id == id }) else { return }
        let range = min(from, to)...max(from, to)
        for i in range { selectedFileIDs.insert(files[i].id) }
        onUserInteraction?()
    }

    // MARK: - Cache Directory

    private static let cacheDir: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("NotchDrop/Cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Copy source into cache.  Original file is NOT touched.
    private static func cache(_ src: URL) -> URL? {
        let dest = cacheDir.appendingPathComponent(src.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)  // overwrite stale cache
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            return dest
        } catch {
            NSLog("NotchDrop: cache error \(error.localizedDescription)")
            return nil
        }
    }

    private static func evict(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - File Management

    func addFile(at url: URL) {
        let resolved = url.resolvingSymlinksInPath()
        guard resolved.isFileURL, FileManager.default.fileExists(atPath: resolved.path) else { return }
        if files.contains(where: { $0.url.path == resolved.path }) { return }
        let attrs = try? FileManager.default.attributesOfItem(atPath: resolved.path)
        let droppedSize = (attrs?[.size] as? Int64) ?? 0
        if files.contains(where: { $0.name == resolved.lastPathComponent && $0.size == droppedSize }) { return }
        let isTemp = resolved.path.hasPrefix("/var/") || resolved.path.hasPrefix("/private/var/")
        if isTemp && droppedSize > 0 && files.contains(where: { $0.size == droppedSize }) { return }

        // Cache the file, then delete the original (cut, no trash).
        guard let cached = Self.cache(resolved) else { return }
        try? FileManager.default.removeItem(at: resolved)

        let file = StoredFile(url: cached, originalURL: resolved)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { files.append(file) }
        persistFiles()
    }

    /// Remove file — the original is still at originalURL, just clean the cache.
    func removeFile(_ file: StoredFile) {
        Self.evict(file.url)
        withAnimation(.easeOut(duration: 0.2)) { files.removeAll { $0.id == file.id } }
        persistFiles(); cleanOrphanedCache(); if files.isEmpty { onFilesEmpty?() }
    }

    /// Restore selected files — they're already at originalURL, just clean caches.
    func restoreSelected() {
        let toRemove = selectedFiles; deselectAll()
        for f in toRemove { Self.evict(f.url) }
        withAnimation(.easeOut(duration: 0.2)) {
            files.removeAll { f in toRemove.contains(where: { $0.id == f.id }) }
        }
        persistFiles(); cleanOrphanedCache(); if files.isEmpty { onFilesEmpty?() }
    }

    /// "Restore all" = just clean all caches, remove all references.
    func removeAll() {
        for f in files { Self.evict(f.url) }
        withAnimation(.easeOut(duration: 0.2)) { files.removeAll() }
        persistFiles(); cleanOrphanedCache(); onFilesEmpty?()
    }

    /// Drag-out — remove reference only.  Cache stays until the next
    /// cleanup pass so the system can finish copying to the destination.
    func removeFileFromPanel(_ file: StoredFile) {
        withAnimation(.easeOut(duration: 0.2)) {
            files.removeAll { $0.id == file.id }
            selectedFileIDs.remove(file.id)
        }
        persistFiles(); if files.isEmpty { onFilesEmpty?() }
        onUserInteraction?()
    }

    /// Open the ORIGINAL file (not the cache copy).
    func openFile(_ file: StoredFile) {
        NSWorkspace.shared.open(file.url)
        onUserInteraction?()
    }

    // MARK: - Cache Cleanup

    func cleanOrphanedCache() {
        let activePaths = Set(files.map { $0.url.resolvingSymlinksInPath().path })
        guard let enumerator = FileManager.default.enumerator(
            at: Self.cacheDir, includingPropertiesForKeys: nil
        ) else { return }
        let systemFiles: Set<String> = [".DS_Store", "Icon\r", ".localized"]
        for case let url as URL in enumerator {
            guard !systemFiles.contains(url.lastPathComponent) else { continue }
            let resolved = url.resolvingSymlinksInPath()
            if !activePaths.contains(resolved.path) {
                try? FileManager.default.removeItem(at: resolved)
            }
        }
    }

    // MARK: - Quit

    func prepareForQuit() {
        // Clean all caches — originals are still at originalURL.
        cleanOrphanedCache()
    }

    // MARK: - Persistence

    func persistFiles() {
        guard AppSettings.shared.rememberFiles else { return }
        AppSettings.shared.savedFilePaths = files.map { $0.url.path }
    }

    func restoreSavedFiles() {
        let paths = AppSettings.shared.savedFilePaths
        guard !paths.isEmpty else { return }
        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            guard !files.contains(where: { $0.url.path == url.path }) else { continue }
            files.append(StoredFile(url: url, originalURL: url))
        }
    }
}
