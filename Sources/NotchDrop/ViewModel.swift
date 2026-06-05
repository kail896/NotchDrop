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

    // MARK: - File Ingestion

    /// Move `src` into internal storage. Returns the storage URL on success.
    /// **Safety contract**: if we return a URL, the file is safely in storage.
    /// The original is deleted only AFTER a confirmed copy.
    private static func ingest(_ src: URL) -> URL? {
        let dest = storageDir.appendingPathComponent(src.lastPathComponent)
        // Remove any stale file at destination (internal storage only)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            // Copy confirmed — now safe to remove the original.
            try FileManager.default.removeItem(at: src)
            return dest
        } catch {
            // If copy succeeded but remove failed, the storage copy exists.
            // Rather than returning nil (which would orphan it), check and return dest.
            if FileManager.default.fileExists(atPath: dest.path) {
                return dest  // storage copy exists, orphan is better than data loss
            }
            NSLog("NotchDrop: ingest error \(error.localizedDescription)")
            return nil
        }
    }

    /// Permanently delete a storage copy.
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

        guard let stored = Self.ingest(resolved) else { return }

        let file = StoredFile(url: stored, originalURL: resolved)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { files.append(file) }
        persistFiles()
    }

    /// Restore single file to its original location. If restore fails, the file
    /// stays in the panel and the storage copy is preserved.
    func removeFile(_ file: StoredFile) {
        let ok = restoreToOriginal(file)
        if ok {
            withAnimation(.easeOut(duration: 0.2)) { files.removeAll { $0.id == file.id } }
            persistFiles(); cleanOrphanedStorage(); if files.isEmpty { onFilesEmpty?() }
        }
    }

    func restoreSelected() {
        let toRestore = selectedFiles; deselectAll()
        var failed: [StoredFile] = []
        for f in toRestore {
            if !restoreToOriginal(f) { failed.append(f) }
        }
        let succeeded = toRestore.filter { f in !failed.contains(where: { $0.id == f.id }) }
        if !succeeded.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                files.removeAll { f in succeeded.contains(where: { $0.id == f.id }) }
            }
        }
        persistFiles(); cleanOrphanedStorage(); if files.isEmpty { onFilesEmpty?() }
    }

    func removeAll() {
        let all = files
        var failed: [StoredFile] = []
        for f in all {
            if !restoreToOriginal(f) { failed.append(f) }
        }
        withAnimation(.easeOut(duration: 0.2)) { files = failed }
        persistFiles(); cleanOrphanedStorage()
        if files.isEmpty { onFilesEmpty?() }
    }

    /// Drag-out: remove the panel reference only. Storage file stays until
    /// the system finishes copying it to the drop destination.
    func removeFileFromPanel(_ file: StoredFile) {
        withAnimation(.easeOut(duration: 0.2)) {
            files.removeAll { $0.id == file.id }
            selectedFileIDs.remove(file.id)
        }
        // Delay eviction so the system can finish copying to the drop destination
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            Self.evict(file.url)
            self?.cleanOrphanedStorage()
        }
        persistFiles(); if files.isEmpty { onFilesEmpty?() }
    }

    func openFile(_ file: StoredFile) { NSWorkspace.shared.open(file.url); onUserInteraction?() }

    // MARK: - Restore Helper

    /// Copy the storage file back to its original URL. Returns `true` on success.
    /// If it fails, the storage file is NOT deleted.
    private func restoreToOriginal(_ file: StoredFile) -> Bool {
        let fm = FileManager.default
        let dest = file.originalURL
        // Ensure the target directory exists
        try? fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Verify storage file still exists
        guard fm.fileExists(atPath: file.url.path) else {
            NSLog("NotchDrop: storage file missing for \(file.name)")
            return false
        }
        do {
            if fm.fileExists(atPath: dest.path) {
                _ = try fm.replaceItemAt(dest, withItemAt: file.url)
            } else {
                try fm.copyItem(at: file.url, to: dest)
            }
            // Restore confirmed — safe to evict storage copy
            Self.evict(file.url)
            return true
        } catch {
            NSLog("NotchDrop: restore failed for \(file.name): \(error.localizedDescription)")
            return false
        }
    }

    /// Clean up unreferenced storage files (files in storage/ not in the panel).
    /// Call on launch to clean up from previous sessions.
    func cleanOrphanedStorage() {
        let activePaths = Set(files.map { $0.url.resolvingSymlinksInPath().path })
        guard let enumerator = FileManager.default.enumerator(
            at: Self.storageDir, includingPropertiesForKeys: nil
        ) else { return }
        for case let url as URL in enumerator {
            let resolved = url.resolvingSymlinksInPath()
            if !activePaths.contains(resolved.path) {
                try? FileManager.default.removeItem(at: resolved)
            }
        }
    }

    // MARK: - Quit

    /// Called when the app is about to terminate.
    /// Tries to restore all files. Files that cannot be restored stay in storage
    /// and will be available next launch (if rememberFiles is on).
    func prepareForQuit() {
        for f in files {
            if !restoreToOriginal(f) {
                // File stays in storage — it will be recovered next launch
                // if rememberFiles is enabled.
                NSLog("NotchDrop: will NOT restore \(f.name) on quit (storage preserved)")
            }
        }
        // Clean any storage files that aren't in the panel
        cleanOrphanedStorage()
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
            // Use the saved path as storage URL; originalURL is unknown after restart,
            // so treat the storage path as the fallback original.
            files.append(StoredFile(url: url, originalURL: url))
        }
    }
}
