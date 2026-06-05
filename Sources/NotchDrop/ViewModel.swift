import Foundation
import SwiftUI

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

    // MARK: - Storage Directory

    private static let storageDir: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("NotchDrop/Storage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Move file into internal storage (removes original permanently, no trash).
    private static func ingest(_ src: URL) -> URL? {
        let fn = src.lastPathComponent
        var dest = storageDir.appendingPathComponent(fn)
        if FileManager.default.fileExists(atPath: dest.path) {
            let ext = dest.pathExtension
            let base = dest.deletingPathExtension().lastPathComponent
            var c = 1
            repeat {
                dest = storageDir.appendingPathComponent("\(base)_\(c).\(ext)")
                c += 1
            } while FileManager.default.fileExists(atPath: dest.path)
        }
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            try FileManager.default.removeItem(at: src)  // delete original, no trash
            return dest
        } catch {
            NSLog("NotchDrop: ingest error \(error.localizedDescription)")
            return nil
        }
    }

    /// Permanently delete a storage copy (no trash).
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

        // Move file into internal storage (original is permanently removed).
        guard let stored = Self.ingest(resolved) else { return }

        let file = StoredFile(url: stored, originalURL: resolved)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { files.append(file) }
        persistFiles()
    }

    /// Restore single file to original location.
    func removeFile(_ file: StoredFile) {
        restoreToOriginal(file)
        withAnimation(.easeOut(duration: 0.2)) { files.removeAll { $0.id == file.id } }
        persistFiles(); if files.isEmpty { onFilesEmpty?() }
    }

    /// Restore selected files.
    func restoreSelected() {
        let toRestore = selectedFiles; deselectAll()
        for f in toRestore { restoreToOriginal(f) }
        withAnimation(.easeOut(duration: 0.2)) {
            files.removeAll { f in toRestore.contains(where: { $0.id == f.id }) }
        }
        persistFiles(); if files.isEmpty { onFilesEmpty?() }
    }

    /// Restore all files.
    func removeAll() {
        let all = files
        for f in all { restoreToOriginal(f) }
        withAnimation(.easeOut(duration: 0.2)) { files.removeAll() }
        persistFiles(); onFilesEmpty?()
    }

    /// Drag-out: copy storage file to destination is handled by system.
    /// We just remove the reference; storage file will be cleaned up later.
    func removeFileFromPanel(_ file: StoredFile) {
        withAnimation(.easeOut(duration: 0.2)) {
            files.removeAll { $0.id == file.id }
            selectedFileIDs.remove(file.id)
        }
        // Don't evict here — the system may still be copying the file
        // to the drop destination. Cleanup happens on restore/clear.
        persistFiles(); if files.isEmpty { onFilesEmpty?() }
    }

    func openFile(_ file: StoredFile) { NSWorkspace.shared.open(file.url); onUserInteraction?() }

    // MARK: - Restore Helper

    private func restoreToOriginal(_ file: StoredFile) {
        let fm = FileManager.default
        let dest = file.originalURL
        try? fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            if fm.fileExists(atPath: dest.path) {
                _ = try fm.replaceItemAt(dest, withItemAt: file.url)
            } else {
                try fm.copyItem(at: file.url, to: dest)
            }
            Self.evict(file.url)  // storage copy gone, not trash
        } catch {
            NSLog("NotchDrop: restoreToOriginal error: \(error.localizedDescription)")
        }
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
