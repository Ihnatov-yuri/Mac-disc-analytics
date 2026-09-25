import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var progress = ScanProgress()
    @State private var currentNode: FileNode? = nil
    @State private var path: [FileNode] = []
    @State private var selectedNode: FileNode? = nil
    @State private var hoveredNode: FileNode? = nil
    @State private var showDeleteConfirm = false
    @State private var deleteError: String? = nil

    var body: some View {
        ZStack {
            LitField()
            VStack(spacing: 0) {
                topbar
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                statusBar
            }
        }
        .navigationTitle(windowTitle)
        .onChange(of: progress.root) { newRoot in
            if let r = newRoot {
                currentNode = r
                path = [r]
                selectedNode = nil
                hoveredNode = nil
            }
        }
        .alert("Move to Trash?", isPresented: $showDeleteConfirm, presenting: selectedNode) { node in
            Button("Move to Trash", role: .destructive) { moveToTrash(node) }
            Button("Cancel", role: .cancel) { }
        } message: { node in
            Text("“\(node.name)” (\(node.size.formattedSize)) will be moved to the Trash. You can restore it from there.")
        }
        .alert("Couldn’t delete", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .background(KeyShortcutsView(
            onUp: goUp,
            onClearSelection: { selectedNode = nil }
        ))
    }

    private var windowTitle: String {
        if let n = currentNode {
            return "DiscStats — \(n.name)"
        }
        return "DiscStats"
    }

    // MARK: - Topbar

    /// Sticky chrome on the topbar veil with a seam shadow, never a lifted
    /// panel: a lifted bar over content would read as a second plane.
    private var topbar: some View {
        VStack(spacing: 0) {
            toolbarRow
            if !path.isEmpty {
                Hairline()
                breadcrumbBar
            }
        }
        .background(Color(.sRGB, red: 238 / 255, green: 238 / 255, blue: 236 / 255, opacity: 0.72))
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.ink.opacity(0.07)).frame(height: 1)
        }
    }

    private var toolbarRow: some View {
        HStack(spacing: AppMetric.xs) {
            Button {
                pickFolder()
            } label: {
                Label("Choose Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.lit(.ghost, size: .compact))
            .keyboardShortcut("o", modifiers: .command)
            .disabled(progress.isScanning)
            .help("Choose a folder to scan (⌘O)")

            Button {
                if let r = progress.root {
                    startScan(url: r.url)
                }
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.lit(.ghost, size: .compact))
            .keyboardShortcut("r", modifiers: .command)
            .disabled(progress.isScanning || progress.root == nil)
            .help("Re-scan current folder (⌘R)")

            Button {
                goUp()
            } label: {
                Label("Up", systemImage: "arrow.up")
            }
            .buttonStyle(.lit(.ghost, size: .compact))
            .keyboardShortcut("[", modifiers: .command)
            .disabled(path.count <= 1)
            .help("Go up one folder (⌘[)")

            if progress.isScanning {
                Button {
                    progress.cancelled = true
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
                .buttonStyle(.lit(.secondary, size: .compact))
                .help("Cancel scan")
            }

            Spacer()

            if let current = currentNode, !progress.isScanning {
                HStack(spacing: 6) {
                    Text(current.size.formattedSize)
                        .font(AppFont.display(13.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(AppColor.ink)
                    Text("\(current.itemCount.formatted()) items")
                        .font(AppFont.display(13.5).monospacedDigit())
                        .foregroundStyle(AppColor.ink3)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.66), in: Capsule())
                .overlay(Capsule().strokeBorder(AppColor.hair, lineWidth: 1))
            }
        }
        .padding(.horizontal, AppMetric.m)
        .padding(.vertical, AppMetric.s)
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(path.enumerated()), id: \.element.id) { idx, node in
                    if idx > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppColor.ink4)
                            .padding(.horizontal, 2)
                    }
                    CrumbButton(title: node.name,
                                isRoot: idx == 0,
                                isCurrent: idx == path.count - 1) {
                        navigate(to: idx)
                    }
                }
            }
            .padding(.horizontal, AppMetric.m)
            .padding(.vertical, AppMetric.xs)
        }
    }

    // MARK: - Content area

    @ViewBuilder
    private var content: some View {
        if progress.isScanning {
            scanningView
        } else if let current = currentNode {
            HSplitView {
                treemapPanel(current: current)
                    .padding([.leading, .vertical], AppMetric.m)
                    .padding(.trailing, AppMetric.s)
                    .frame(minWidth: 500)
                sidePanel
                    .padding([.trailing, .vertical], AppMetric.m)
                    .padding(.leading, AppMetric.s)
                    .frame(minWidth: 270, idealWidth: 320, maxWidth: 420)
            }
            // Only re-key on tree mutations (delete). Plain drill/back navigation
            // updates the node prop in place so the split view + side panel don't
            // tear down — that was the main source of switching lag.
            .id(progress.dataVersion)
        } else {
            emptyState
        }
    }

    private var scanningView: some View {
        VStack(spacing: AppMetric.l) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning…")
                .font(AppFont.display(22, weight: .bold))
                .foregroundStyle(AppColor.ink)
            VStack(spacing: AppMetric.xs) {
                Text("\(progress.filesScanned.formatted()) files · \(progress.bytesSeen.formattedSize)")
                    .font(AppFont.display(15).monospacedDigit())
                    .foregroundStyle(AppColor.ink2)
                if progress.scanElapsed > 0.5 {
                    let rate = Double(progress.filesScanned) / max(progress.scanElapsed, 0.001)
                    Text("\(formatElapsed(progress.scanElapsed)) · \(Int(rate).formatted()) files/sec")
                        .font(AppFont.display(13).monospacedDigit())
                        .foregroundStyle(AppColor.ink3)
                }
            }
            Text(progress.currentPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColor.ink4)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 520)
                .padding(.top, AppMetric.xs)
        }
        .padding(AppMetric.xl + 8)
        .frame(maxWidth: 600)
        .litPanel(lift: .two, radius: 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppMetric.l)
    }

    /// One sentence on what will appear, and one action. No illustration.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppMetric.m) {
            Text("See where your disk space goes")
                .font(AppFont.display(26, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(AppColor.ink)
            Text("Choose a folder and DiscStats maps everything inside it. Each rectangle is a file or folder, sized by the space it takes. Click one to inspect it, double-click a folder to drill in.")
                .font(AppFont.text(15))
                .foregroundStyle(AppColor.ink3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                pickFolder()
            } label: {
                Label("Choose Folder…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.lit(.primary, size: .large))
            .keyboardShortcut("o", modifiers: .command)
            .padding(.top, AppMetric.s)
        }
        .padding(AppMetric.xl + 8)
        .frame(maxWidth: 520, alignment: .leading)
        .litPanel(lift: .two, radius: 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppMetric.l)
    }

    private func treemapPanel(current: FileNode) -> some View {
        ZStack {
            if current.children.isEmpty || current.size == 0 {
                Text(current.children.isEmpty
                     ? "This folder is empty. Go up with ⌘[ or choose another folder."
                     : "Every item here reports 0 bytes, so there is nothing to map.")
                    .font(AppFont.text(15))
                    .foregroundStyle(AppColor.ink3)
                    .multilineTextAlignment(.center)
                    .padding(AppMetric.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TreemapView(
                    node: current,
                    selectedId: selectedNode?.id,
                    onSelect: { selectedNode = $0 },
                    onDrillIn: { drillInto($0) },
                    onHover: { hoveredNode = $0 }
                )
                .padding(6)
            }
        }
        .litPanel(lift: .one, radius: AppMetric.radiusPanel)
    }

    // MARK: - Side panel

    private var sidePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppMetric.m) {
                if let node = selectedNode {
                    selectionHeader(node: node)
                    Hairline()
                    selectionDetails(node: node)
                    Hairline()
                    actionButtons(node: node)
                    if node.isDirectory, !node.children.isEmpty {
                        Hairline()
                        topItems(node: node)
                    }
                } else {
                    placeholderPanel
                }
            }
            .padding(AppMetric.l)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .litPanel(lift: .one, radius: AppMetric.radiusPanel)
    }

    private func selectionHeader(node: FileNode) -> some View {
        let category = FileCategory(node: node)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName(for: node))
                .font(.system(size: 22))
                .foregroundStyle(category.glyphInk)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(AppFont.display(17, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(node.size.formattedSize)
                    .font(AppFont.display(26, weight: .bold).monospacedDigit())
                    .tracking(-0.9)
                    .foregroundStyle(AppColor.ink)
            }
        }
    }

    private func selectionDetails(node: FileNode) -> some View {
        VStack(alignment: .leading, spacing: AppMetric.s) {
            HStack(spacing: AppMetric.s) {
                Text(node.isDirectory ? "Folder" : "File")
                    .font(AppFont.display(12.5))
                    .foregroundStyle(AppColor.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.66), in: Capsule())
                    .overlay(Capsule().strokeBorder(AppColor.hair, lineWidth: 1))
                if node.isDirectory {
                    Text("\(node.children.count.formatted()) items")
                        .font(AppFont.display(13).monospacedDigit())
                        .foregroundStyle(AppColor.ink3)
                }
                Spacer()
            }
            if let parent = currentNode, parent.size > 0 {
                let pct = Double(node.size) / Double(parent.size) * 100
                HStack(spacing: AppMetric.s) {
                    // Track in hair-strong, filled portion in the accent:
                    // the selection is the user's own figure.
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColor.hairStrong)
                            Capsule()
                                .fill(AppColor.accent)
                                .frame(width: geo.size.width * CGFloat(min(pct, 100) / 100))
                        }
                    }
                    .frame(height: 4)
                    Text(String(format: "%.1f%%", pct))
                        .font(AppFont.display(13).monospacedDigit())
                        .foregroundStyle(AppColor.ink3)
                        .frame(width: 52, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: "%.1f percent of the current folder", pct))
            }
            // A path is real data, so monospace is allowed here.
            Text(node.url.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColor.ink4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func actionButtons(node: FileNode) -> some View {
        VStack(alignment: .leading, spacing: AppMetric.s) {
            if node.isDirectory, !node.children.isEmpty {
                Button {
                    drillInto(node)
                } label: {
                    Label("Open Folder", systemImage: "arrow.down.right")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.lit(.secondary, size: .compact))
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            } label: {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.lit(.secondary, size: .compact))
            Button {
                showDeleteConfirm = true
            } label: {
                Label("Move to Trash", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.lit(.destructive, size: .compact))
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }

    private func topItems(node: FileNode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Largest items")
                .font(AppFont.display(13))
                .foregroundStyle(AppColor.ink3)
                .padding(.bottom, 6)
            Rectangle().fill(AppColor.hairStrong).frame(height: 1)
            ForEach(Array(node.children.prefix(8))) { child in
                HStack(spacing: AppMetric.s) {
                    Image(systemName: iconName(for: child))
                        .font(.system(size: 11))
                        .foregroundStyle(FileCategory(node: child).glyphInk)
                        .frame(width: 16)
                    Text(child.name)
                        .font(AppFont.text(13))
                        .foregroundStyle(AppColor.ink2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: AppMetric.s)
                    Text(child.size.formattedSize)
                        .font(AppFont.display(12.5).monospacedDigit())
                        .foregroundStyle(AppColor.ink3)
                }
                .padding(.vertical, 7)
                Hairline()
            }
        }
    }

    private var placeholderPanel: some View {
        VStack(alignment: .leading, spacing: AppMetric.m) {
            Text("Nothing selected")
                .font(AppFont.display(17, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(AppColor.ink)
            Text("Click a rectangle to inspect it. Double-click a folder to drill in.")
                .font(AppFont.text(14))
                .foregroundStyle(AppColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
            Hairline().padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(FileCategory.allCases, id: \.self) { category in
                    HStack(spacing: AppMetric.s) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(category.fill)
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(AppColor.hairStrong, lineWidth: 0.5))
                            .frame(width: 12, height: 12)
                        Text(category.title)
                            .font(AppFont.text(13))
                            .foregroundStyle(AppColor.ink2)
                    }
                }
            }
            Hairline().padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 7) {
                shortcutRow(keys: "⌘O", desc: "Choose folder")
                shortcutRow(keys: "⌘R", desc: "Rescan")
                shortcutRow(keys: "⌘[", desc: "Go up")
                shortcutRow(keys: "⌘⌫", desc: "Move selection to Trash")
                shortcutRow(keys: "Esc", desc: "Clear selection")
            }
        }
    }

    private func shortcutRow(keys: String, desc: String) -> some View {
        HStack(spacing: AppMetric.s) {
            Text(keys)
                .font(AppFont.display(12))
                .foregroundStyle(AppColor.ink2)
                .frame(minWidth: 30)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.66), in: Capsule())
                .overlay(Capsule().strokeBorder(AppColor.hair, lineWidth: 1))
            Text(desc)
                .font(AppFont.text(13))
                .foregroundStyle(AppColor.ink3)
            Spacer()
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: AppMetric.s) {
            if progress.isScanning {
                Text("Scanning… \(progress.filesScanned.formatted()) files")
                    .font(AppFont.text(12).monospacedDigit())
                    .foregroundStyle(AppColor.ink3)
            } else if let hov = hoveredNode {
                Image(systemName: iconName(for: hov))
                    .foregroundStyle(FileCategory(node: hov).glyphInk)
                Text(hov.name)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(hov.size.formattedSize)
                    .font(AppFont.display(12).monospacedDigit())
                    .foregroundStyle(AppColor.ink2)
                if let parent = currentNode, parent.size > 0 {
                    let pct = Double(hov.size) / Double(parent.size) * 100
                    Text(String(format: "%.1f%%", pct))
                        .font(AppFont.display(12).monospacedDigit())
                        .foregroundStyle(AppColor.ink4)
                }
            } else if let sel = selectedNode {
                Circle()
                    .fill(AppColor.accent)
                    .frame(width: 7, height: 7)
                Text(sel.name)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(sel.size.formattedSize)
                    .font(AppFont.display(12).monospacedDigit())
                    .foregroundStyle(AppColor.ink2)
            } else if currentNode != nil {
                Text("Ready")
                    .foregroundStyle(AppColor.ink4)
            } else {
                Text("No folder loaded")
                    .foregroundStyle(AppColor.ink4)
            }
            Spacer()
            if !progress.isScanning, progress.scanElapsed > 0, currentNode != nil {
                Text("Scanned in \(formatElapsed(progress.scanElapsed))")
                    .font(AppFont.text(12).monospacedDigit())
                    .foregroundStyle(AppColor.ink4)
            }
        }
        .font(AppFont.text(12))
        .padding(.horizontal, AppMetric.m)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.sRGB, red: 238 / 255, green: 238 / 255, blue: 236 / 255, opacity: 0.72))
        .overlay(alignment: .top) {
            Rectangle().fill(AppColor.ink.opacity(0.07)).frame(height: 1)
        }
    }

    // MARK: - Actions

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to scan"
        panel.prompt = "Scan"
        if panel.runModal() == .OK, let url = panel.url {
            startScan(url: url)
        }
    }

    private func startScan(url: URL) {
        currentNode = nil
        path = []
        selectedNode = nil
        hoveredNode = nil
        Scanner.startScan(url: url, progress: progress)
    }

    private func drillInto(_ node: FileNode) {
        guard node.isDirectory, !node.children.isEmpty else { return }
        path.append(node)
        currentNode = node
        selectedNode = nil
        hoveredNode = nil
    }

    private func navigate(to idx: Int) {
        guard idx >= 0, idx < path.count else { return }
        path = Array(path.prefix(idx + 1))
        currentNode = path.last
        selectedNode = nil
        hoveredNode = nil
    }

    private func goUp() {
        guard path.count > 1 else { return }
        navigate(to: path.count - 2)
    }

    private func moveToTrash(_ node: FileNode) {
        do {
            try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            removeFromTree(node)
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func removeFromTree(_ node: FileNode) {
        let sizeDelta = node.size
        let countDelta = node.itemCount
        if let parent = node.parent,
           let idx = parent.children.firstIndex(where: { $0.id == node.id }) {
            parent.children.remove(at: idx)
            var cursor: FileNode? = parent
            while let c = cursor {
                c.size -= sizeDelta
                c.itemCount -= countDelta
                cursor = c.parent
            }
        } else {
            currentNode = nil
            path = []
            progress.root = nil
        }
        if selectedNode?.id == node.id { selectedNode = nil }
        if hoveredNode?.id == node.id { hoveredNode = nil }
        progress.dataVersion &+= 1
    }

    // MARK: - Helpers

    private func iconName(for node: FileNode) -> String {
        if node.isDirectory { return "folder.fill" }
        let ext = node.url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif",
             "bmp", "webp", "svg":
            return "photo.fill"
        case "mp4", "mov", "m4v", "mkv", "avi", "webm", "wmv":
            return "film.fill"
        case "mp3", "m4a", "wav", "flac", "aac", "ogg", "aif", "aiff":
            return "music.note"
        case "pdf":
            return "doc.richtext.fill"
        case "doc", "docx", "pages", "rtf", "txt", "md", "markdown":
            return "doc.text.fill"
        case "xls", "xlsx", "numbers", "csv":
            return "tablecells.fill"
        case "ppt", "pptx", "key":
            return "rectangle.on.rectangle.fill"
        case "zip", "rar", "7z", "tar", "gz", "bz2", "dmg", "iso":
            return "shippingbox.fill"
        case "app":
            return "app.fill"
        case "swift", "py", "js", "ts", "rb", "go", "rs", "java",
             "c", "cpp", "h", "json", "xml", "html", "css", "sh":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.fill"
        }
    }

    private func formatElapsed(_ s: TimeInterval) -> String {
        if s < 60 { return String(format: "%.1fs", s) }
        let mins = Int(s) / 60
        let secs = Int(s) % 60
        return "\(mins)m \(secs)s"
    }
}

// MARK: - Breadcrumb item
//
// Active item: ink text on an accent rule, never a filled block.

private struct CrumbButton: View {
    let title: String
    let isRoot: Bool
    let isCurrent: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isRoot {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                }
                Text(title)
                    .font(AppFont.display(13))
                    .lineLimit(1)
            }
            .foregroundStyle(isCurrent || hovering ? AppColor.ink : AppColor.ink3)
            .padding(.horizontal, 8)
            .frame(minHeight: 28)
            .background(
                Capsule().fill(Color.white.opacity(hovering && !isCurrent ? 0.55 : 0))
            )
            .overlay(alignment: .bottom) {
                if isCurrent {
                    Rectangle()
                        .fill(AppColor.accent)
                        .frame(height: 2)
                        .padding(.horizontal, 8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

// MARK: - Hidden keyboard shortcut sink (Esc + macOS 13 arrow keys)
//
// SwiftUI `.keyboardShortcut` works on visible Buttons; for Esc and a
// few menu-less shortcuts we route through an invisible NSView responder.

struct KeyShortcutsView: NSViewRepresentable {
    var onUp: () -> Void
    var onClearSelection: () -> Void

    func makeNSView(context: Context) -> KeyHandlingView {
        let v = KeyHandlingView()
        v.onUp = onUp
        v.onClearSelection = onClearSelection
        return v
    }

    func updateNSView(_ nsView: KeyHandlingView, context: Context) {
        nsView.onUp = onUp
        nsView.onClearSelection = onClearSelection
    }
}

final class KeyHandlingView: NSView {
    var onUp: (() -> Void)?
    var onClearSelection: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        // Esc
        if event.keyCode == 53 {
            onClearSelection?()
            return
        }
        // Cmd + Up arrow
        if event.keyCode == 126, event.modifierFlags.contains(.command) {
            onUp?()
            return
        }
        super.keyDown(with: event)
    }
}
