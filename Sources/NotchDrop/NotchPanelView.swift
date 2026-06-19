import SwiftUI

// MARK: - Preference Key for file row frames (in global coordinates)

struct FileFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Main Panel

struct NotchPanelView: View {
    @ObservedObject var viewModel: NotchDropManager
    @AppStorage("language") private var _language = ""

    // Rubber‑band selection state
    @State private var selStart: CGPoint? = nil
    @State private var selEnd: CGPoint? = nil
    @State private var fileFrames: [UUID: CGRect] = [:]
    @State private var listGlobalFrame: CGRect = .zero

    private var selRect: CGRect? {
        guard let s = selStart, let e = selEnd else { return nil }
        return CGRect(x: min(s.x, e.x), y: min(s.y, e.y),
                      width: abs(e.x - s.x), height: abs(e.y - s.y))
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(viewModel.isExpanded ? 0.25 : 0.45))
                .frame(width: 56, height: 5).padding(.top, 10).padding(.bottom, 6)

            Group {
                if viewModel.files.isEmpty { emptyStateView }
                else { fileListView }
            }
            .opacity(viewModel.isExpanded ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: viewModel.isExpanded ? .infinity : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.files.count)
        .onTapGesture { viewModel.deselectAll() }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 32, weight: .light)).foregroundColor(.secondary)
                .symbolEffect(.bounce, options: .repeating, value: viewModel.isDropTargeted)
            Text(L.dropFilesHere).font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
            Text(L.dragHint).font(.system(size: 11)).foregroundColor(.secondary.opacity(0.6))
                .multilineTextAlignment(.center).lineSpacing(2)
        }
        .frame(maxHeight: .infinity).padding(.horizontal, 20).padding(.bottom, 30)
    }

    // MARK: - File List + Selection

    private var fileListView: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Scrollable list — rubber‑band gesture is attached to the ScrollView
            ScrollView { fileRows }
                .scrollIndicators(.automatic)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .global)
                        .onChanged { val in
                            if selStart == nil {
                                selStart = val.startLocation
                                viewModel.deselectAll()
                            }
                            selEnd = val.location
                            updateSelection()
                        }
                        .onEnded { _ in
                            selStart = nil; selEnd = nil
                        }
                )
        }
        .frame(maxHeight: .infinity)
    }

    /// Select files whose global frames intersect the current selection rect.
    private func updateSelection() {
        guard let rect = selRect else { return }
        viewModel.selectFiles(in: rect, frames: fileFrames)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text(L.appName).font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
            Spacer()
            if viewModel.selectedFileIDs.isEmpty {
                Text("\(viewModel.files.count)\(L.files)").font(.system(size: 11)).foregroundColor(.secondary)
                Button(action: { viewModel.selectAll() }) { Text("全选").font(.system(size: 9)) }
                    .buttonStyle(.plain).foregroundColor(.blue.opacity(0.7)).padding(.leading, 4)
                Button(action: { viewModel.removeAll() }) { Image(systemName: "arrowshape.turn.up.left").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundColor(.secondary).help("全部移回原位置").padding(.leading, 4)
            } else {
                Text("已选 \(viewModel.selectedFileIDs.count) 个").font(.system(size: 11)).foregroundColor(.blue)
                Button(action: { viewModel.restoreSelected() }) {
                    Image(systemName: "arrowshape.turn.up.left").font(.system(size: 10))
                    Text("移回").font(.system(size: 10))
                }.buttonStyle(.plain).foregroundColor(.blue).padding(.leading, 4)
                Button(action: { viewModel.deselectAll() }) { Text("取消").font(.system(size: 9)) }
                    .buttonStyle(.plain).foregroundColor(.secondary).padding(.leading, 2)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    // MARK: - File Rows

    private var fileRows: some View {
        VStack(spacing: 4) {
            ForEach(Array(viewModel.files.enumerated()), id: \.element.id) { idx, file in
                SelectableFileRow(
                    index: idx,
                    file: file,
                    isSelected: viewModel.selectedFileIDs.contains(file.id),
                    viewModel: viewModel
                )
                .background(GeometryReader { g in
                    Color.clear.preference(
                        key: FileFrameKey.self,
                        value: [file.id: g.frame(in: .global)]
                    )
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)))
            }
        }
        .padding(.horizontal, 10).padding(.bottom, 12)
        .background(GeometryReader { g in
            Color.clear.onAppear { listGlobalFrame = g.frame(in: .global) }
        })
        .onPreferenceChange(FileFrameKey.self) { fileFrames = $0 }
        // Overlay the rubber‑band selection rect
        .overlay {
            if let r = selRect {
                // Convert global rect to local coordinate
                let localRect = CGRect(
                    x: r.minX - listGlobalFrame.minX,
                    y: r.minY - listGlobalFrame.minY,
                    width: r.width, height: r.height
                )
                Rectangle()
                    .fill(.blue.opacity(0.08)).stroke(.blue.opacity(0.4), lineWidth: 1)
                    .frame(width: localRect.width, height: localRect.height)
                    .position(x: localRect.midX, y: localRect.midY)
            }
        }
    }
}

// MARK: - Selectable File Row

struct SelectableFileRow: View {
    let index: Int
    let file: StoredFile
    let isSelected: Bool
    @ObservedObject var viewModel: NotchDropManager

    var body: some View {
        HStack(spacing: 10) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14)).foregroundColor(.blue)
            }
            Image(nsImage: file.icon).resizable().frame(width: 28, height: 28).cornerRadius(4)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name).font(.system(size: 12, weight: .medium))
                    .lineLimit(1).truncationMode(.middle).foregroundColor(.primary)
                Text(file.formattedSize).font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.blue.opacity(0.12) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture {
            let f = NSEvent.modifierFlags
            if f.contains(.command) { viewModel.toggleSelection(file.id) }
            else if f.contains(.shift) { viewModel.selectRange(to: file.id) }
            else { if isSelected { viewModel.openFile(file) } else { viewModel.selectOnly(file.id) } }
        }
        .onDrag {
            let p = NSItemProvider(object: file.originalURL as NSURL)
            p.suggestedName = file.name
            if isSelected && viewModel.selectedFileIDs.count > 1 {
                for f in viewModel.selectedFiles where f.id != file.id {
                    p.registerObject(f.originalURL as NSURL, visibility: .all)
                }
            }
            let toRemove = isSelected && viewModel.selectedFileIDs.count > 1
                ? viewModel.selectedFiles
                : [file]
            for f in toRemove { viewModel.removeFileFromPanel(f) }
            return p
        }
        .contextMenu {
            Button("打开") { viewModel.openFile(file) }
            if isSelected { Button("移回所选 (\(viewModel.selectedFileIDs.count))") { viewModel.restoreSelected() } }
            Divider(); Button("移回原位置") { viewModel.removeFile(file) }
        }
    }
}

// MARK: - Visual Effect

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material; v.blendingMode = blendingMode; v.state = .active
        v.wantsLayer = true; v.layer?.masksToBounds = true
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material; v.blendingMode = blendingMode
    }
}
