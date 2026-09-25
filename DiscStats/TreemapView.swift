import SwiftUI
import AppKit

// MARK: - Color palette
//
// Lit Field data palette (DESIGN.md Part II, 6): the world's neutrals plus
// the functional series hues, flat fills only. The brand accent is kept out
// of the categories and reserved for the user's own focus: the selected
// cell. Each category names the label ink that clears 4.5:1 on its fill.

enum FileCategory: CaseIterable {
    case folder, video, image, audio, document, archive, other

    init(node: FileNode) {
        if node.isDirectory {
            self = .folder
            return
        }
        switch node.url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif",
             "bmp", "webp", "raw", "arw", "cr2", "nef", "dng", "psd", "svg":
            self = .image
        case "mp4", "mov", "m4v", "mkv", "avi", "webm", "wmv", "flv", "mpg", "mpeg":
            self = .video
        case "mp3", "m4a", "wav", "flac", "aac", "ogg", "aif", "aiff", "alac":
            self = .audio
        case "pdf", "doc", "docx", "pages", "rtf", "txt", "md", "markdown", "odt", "epub",
             "xls", "xlsx", "numbers", "csv", "tsv", "ppt", "pptx", "key", "log",
             "swift", "py", "js", "jsx", "ts", "tsx", "rb", "go", "rs", "java",
             "kt", "c", "cpp", "cc", "h", "hpp", "m", "mm", "cs", "php",
             "html", "htm", "css", "scss", "sh", "json", "xml", "yaml", "yml", "toml":
            self = .document
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "tgz",
             "app", "ipa", "pkg", "deb":
            self = .archive
        default:
            self = .other
        }
    }

    var title: String {
        switch self {
        case .folder:   return "Folders"
        case .video:    return "Video"
        case .image:    return "Images"
        case .audio:    return "Audio"
        case .document: return "Documents and code"
        case .archive:  return "Archives and installers"
        case .other:    return "Other files"
        }
    }

    /// Cell fill. Contrast of the label ink on each fill is noted inline.
    var fill: Color {
        switch self {
        case .folder:   return Color(hex: 0xC4CACD) // ink 11.8:1
        case .video:    return AppColor.statusInfo    // #14507A, white 8.5:1
        case .image:    return AppColor.statusSuccess // #0F5D3A, white 7.9:1
        case .audio:    return AppColor.statusWarning // #7A4B00, white 7.4:1
        case .document: return AppColor.ink2          // #23262B, white 15:1
        case .archive:  return AppColor.statusError   // #9F1239, white 8.0:1
        case .other:    return Color(hex: 0x6B7178)   // white 4.9:1
        }
    }

    /// Label ink on `fill`.
    var labelInk: Color {
        self == .folder ? AppColor.ink : .white
    }

    /// Glyph for this category on a light ground (side panel, status bar).
    /// Light fills are too faint as a glyph, so folders use `ink3`.
    var glyphInk: Color {
        self == .folder ? AppColor.ink3 : fill
    }
}

// MARK: - Layout item

struct TreemapItem: Equatable {
    let node: FileNode
    let rect: CGRect
    static func == (l: TreemapItem, r: TreemapItem) -> Bool { l.node.id == r.node.id }
}

// MARK: - Treemap view

struct TreemapView: View {
    let node: FileNode
    let selectedId: UUID?
    let onSelect: (FileNode) -> Void
    let onDrillIn: (FileNode) -> Void
    let onHover: (FileNode?) -> Void

    @State private var hoveredId: UUID? = nil

    var body: some View {
        GeometryReader { geo in
            // Derive the layout inline so it stays in lockstep with `node`.
            // Storing it in @State and updating via .onChange caused gesture
            // closures to capture stale items for one render cycle, which
            // made clicks "miss" right after drilling into a folder.
            let items = TreemapLayout.layout(
                children: node.children.filter { $0.size > 0 },
                in: CGRect(origin: .zero, size: geo.size)
            )

            Canvas(rendersAsynchronously: false) { context, _ in
                for item in items {
                    drawCell(item: item, baseCtx: context)
                }
            }
            .onChange(of: node) { _ in
                hoveredId = nil
                onHover(nil)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let p):
                    let hit = items.last(where: { $0.rect.contains(p) })
                    if hit?.node.id != hoveredId {
                        hoveredId = hit?.node.id
                        onHover(hit?.node)
                    }
                case .ended:
                    if hoveredId != nil {
                        hoveredId = nil
                        onHover(nil)
                    }
                }
            }
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { v in
                        if let hit = items.last(where: { $0.rect.contains(v.location) }),
                           hit.node.isDirectory, !hit.node.children.isEmpty {
                            onDrillIn(hit.node)
                        }
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture(count: 1)
                    .onEnded { v in
                        if let hit = items.last(where: { $0.rect.contains(v.location) }) {
                            onSelect(hit.node)
                        }
                    }
            )
        }
    }

    // MARK: Drawing

    private func drawCell(item: TreemapItem, baseCtx: GraphicsContext) {
        let ctx = baseCtx
        let rect = item.rect
        let path = Path(roundedRect: rect, cornerRadius: 2)
        let category = FileCategory(node: item.node)
        let isSel = item.node.id == selectedId
        let isHov = item.node.id == hoveredId

        // Flat fills only: no gradient fills and no shadows on data.
        // The selected cell is the one full-chroma object, with ink on it.
        let fill = isSel ? AppColor.accent : category.fill
        let ink = isSel ? AppColor.ink : category.labelInk
        ctx.fill(path, with: .color(fill))

        if isSel {
            ctx.stroke(path, with: .color(AppColor.ink), lineWidth: 2)
        } else if isHov {
            ctx.fill(path, with: .color(.white.opacity(0.14)))
            ctx.stroke(path, with: .color(ink), lineWidth: 1.5)
        } else {
            // Internal divider between marks, not a panel outline.
            ctx.stroke(path, with: .color(AppColor.hairStrong), lineWidth: 0.5)
        }

        guard rect.width > 48, rect.height > 24 else { return }

        let nameText = Text(item.node.name)
            .font(AppFont.display(11, weight: .semibold))
            .foregroundColor(ink)

        let resolved = ctx.resolve(nameText)
        let textSize = resolved.measure(in: CGSize(width: rect.width - 12, height: rect.height - 10))
        ctx.draw(resolved,
                 in: CGRect(x: rect.minX + 6, y: rect.minY + 5,
                            width: max(0, rect.width - 12), height: textSize.height))

        if rect.height > 38 && textSize.height < rect.height - 22 {
            let sizeText = Text(item.node.size.formattedSize)
                .font(AppFont.display(10, weight: .semibold).monospacedDigit())
                .foregroundColor(ink)
            ctx.draw(sizeText,
                     at: CGPoint(x: rect.minX + 6, y: rect.minY + 6 + textSize.height + 1),
                     anchor: .topLeading)
        }
    }
}

// MARK: - Squarified treemap layout

enum TreemapLayout {
    static func layout(children: [FileNode], in rect: CGRect) -> [TreemapItem] {
        guard !children.isEmpty, rect.width > 1, rect.height > 1 else { return [] }
        let total = children.reduce(Int64(0)) { $0 + $1.size }
        guard total > 0 else { return [] }

        let sorted = children.sorted { $0.size > $1.size }
        let area = Double(rect.width) * Double(rect.height)
        let pairs: [(FileNode, Double)] = sorted.map {
            ($0, (Double($0.size) / Double(total)) * area)
        }

        var result: [TreemapItem] = []
        squarify(items: pairs, rect: rect, into: &result)
        return result
    }

    private static func squarify(items: [(FileNode, Double)],
                                 rect: CGRect,
                                 into result: inout [TreemapItem]) {
        var remaining = items
        var current = rect

        while !remaining.isEmpty, current.width > 0.5, current.height > 0.5 {
            var row: [(FileNode, Double)] = []
            let shortSide = Double(min(current.width, current.height))

            while !remaining.isEmpty {
                let candidate = row + [remaining[0]]
                if row.isEmpty
                    || worstRatio(row: candidate, shortSide: shortSide)
                        <= worstRatio(row: row, shortSide: shortSide) {
                    row = candidate
                    remaining.removeFirst()
                } else {
                    break
                }
            }

            let (rowRects, newRect) = layoutRow(row: row, in: current)
            for (pair, r) in zip(row, rowRects) {
                let inset = r.insetBy(dx: 0.5, dy: 0.5)
                if inset.width > 0 && inset.height > 0 {
                    result.append(TreemapItem(node: pair.0, rect: inset))
                }
            }
            current = newRect
        }
    }

    private static func worstRatio(row: [(FileNode, Double)], shortSide: Double) -> Double {
        guard !row.isEmpty, shortSide > 0 else { return .infinity }
        let sum = row.reduce(0.0) { $0 + $1.1 }
        guard sum > 0 else { return .infinity }
        let s2 = shortSide * shortSide
        let sum2 = sum * sum
        var worst = 0.0
        for (_, area) in row {
            guard area > 0 else { continue }
            let ratio = max((s2 * area) / sum2, sum2 / (s2 * area))
            worst = max(worst, ratio)
        }
        return worst
    }

    private static func layoutRow(row: [(FileNode, Double)],
                                  in rect: CGRect) -> ([CGRect], CGRect) {
        let sum = row.reduce(0.0) { $0 + $1.1 }
        guard sum > 0 else { return ([], rect) }

        var rects: [CGRect] = []
        if rect.width >= rect.height {
            let sliceWidth = CGFloat(sum / Double(rect.height))
            var y = rect.minY
            for (_, area) in row {
                let h = CGFloat(area / sum) * rect.height
                rects.append(CGRect(x: rect.minX, y: y, width: sliceWidth, height: h))
                y += h
            }
            let newRect = CGRect(x: rect.minX + sliceWidth,
                                 y: rect.minY,
                                 width: max(0, rect.width - sliceWidth),
                                 height: rect.height)
            return (rects, newRect)
        } else {
            let sliceHeight = CGFloat(sum / Double(rect.width))
            var x = rect.minX
            for (_, area) in row {
                let w = CGFloat(area / sum) * rect.width
                rects.append(CGRect(x: x, y: rect.minY, width: w, height: sliceHeight))
                x += w
            }
            let newRect = CGRect(x: rect.minX,
                                 y: rect.minY + sliceHeight,
                                 width: rect.width,
                                 height: max(0, rect.height - sliceHeight))
            return (rects, newRect)
        }
    }
}
