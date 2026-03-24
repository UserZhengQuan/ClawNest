import CoreGraphics
import SwiftUI

enum ClawNestLayout {
    enum Window {
        static let defaultWidth: CGFloat = 1400
        static let defaultHeight: CGFloat = 900
        static let minimumWidth: CGFloat = 760
        static let minimumHeight: CGFloat = 680
        static let maximumWidth: CGFloat = 3200
        static let maximumHeight: CGFloat = 2200
        static let zoomedHorizontalInset: CGFloat = 24
        static let zoomedVerticalInset: CGFloat = 22
    }

    enum Spacing {
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 8
        static let large: CGFloat = 10
        static let xLarge: CGFloat = 12
        static let xxLarge: CGFloat = 12
        static let shell: CGFloat = 12
        static let canvas: CGFloat = 12
    }

    enum Typography {
        static let brand: CGFloat = 20
        static let workspaceTitle: CGFloat = 28
        static let heroTitle: CGFloat = 22
        static let sectionTitle: CGFloat = 17
        static let cardTitle: CGFloat = 20
        static let threadTitle: CGFloat = 22
        static let statValue: CGFloat = 17
        static let statusIcon: CGFloat = 28
        static let overlayIcon: CGFloat = 28
        static let avatarIcon: CGFloat = 16
        static let navIcon: CGFloat = 15
    }

    enum Size {
        static let sidebarLogo: CGFloat = 32
        static let statusHeroIconBox: CGFloat = 56
        static let clawHeaderAvatar: CGFloat = 64
        static let clawCardAvatar: CGFloat = 58
        static let momentAvatar: CGFloat = 58
        static let profileAvatar: CGFloat = 56
        static let compactAgentBadge: CGFloat = 34
        static let taskIconBox: CGFloat = 42
        static let pulseDot: CGFloat = 8
        static let sidebarIconWidth: CGFloat = 24
        static let accentBarWidth: CGFloat = 92
        static let accentBarHeight: CGFloat = 2
        static let menuBarWidth: CGFloat = 320
        static let portFieldWidth: CGFloat = 120
        static let sliderValueWidth: CGFloat = 56
        static let overlayTextWidth: CGFloat = 560
        static let actionButtonMinHeight: CGFloat = 34
    }
}

struct WorkspaceLayoutMetrics {
    let containerSize: CGSize

    var isCompactHeight: Bool {
        containerSize.height < 820
    }

    var isVeryCompactHeight: Bool {
        containerSize.height < 720
    }

    var isPortraitLike: Bool {
        containerSize.height > containerSize.width * 0.92
    }

    var rootPadding: CGFloat {
        containerSize.width < 1450 || isCompactHeight ? ClawNestLayout.Spacing.medium : 18
    }

    var surfacePadding: CGFloat {
        if isCompactHeight {
            return ClawNestLayout.Spacing.medium
        }
        return containerSize.width < 1450 ? ClawNestLayout.Spacing.medium : ClawNestLayout.Spacing.large
    }

    var panelPadding: CGFloat {
        isCompactHeight ? ClawNestLayout.Spacing.medium : ClawNestLayout.Spacing.large
    }

    var groupSpacing: CGFloat {
        isCompactHeight ? ClawNestLayout.Spacing.medium : ClawNestLayout.Spacing.large
    }

    var stackSpacing: CGFloat {
        containerSize.width < 1450 || isCompactHeight ? ClawNestLayout.Spacing.medium : ClawNestLayout.Spacing.large
    }

    var cardSpacing: CGFloat {
        isCompactHeight ? ClawNestLayout.Spacing.small : ClawNestLayout.Spacing.medium
    }

    var pageInset: CGFloat {
        containerSize.width < 1450 || isCompactHeight ? ClawNestLayout.Spacing.xSmall : 10
    }

    var sidebarWidth: CGFloat {
        clamped(containerSize.width * 0.10, min: containerSize.width < 900 ? 96 : (containerSize.width < 1100 ? 106 : 114), max: 122)
    }

    var detailCanvasWidth: CGFloat {
        max(320, containerSize.width - (rootPadding * 2) - sidebarWidth - 1 - (surfacePadding * 2))
    }

    var chatRailWidth: CGFloat {
        clamped(detailCanvasWidth * 0.29, min: 250, max: 360)
    }

    var clawsRailWidth: CGFloat {
        clamped(detailCanvasWidth * 0.31, min: 280, max: 420)
    }

    var supportRailWidth: CGFloat {
        clamped(detailCanvasWidth * 0.28, min: 250, max: 360)
    }

    var compactSidebarWidth: CGFloat {
        clamped(detailCanvasWidth * 0.24, min: 240, max: 340)
    }

    var pageUsesVerticalRail: Bool {
        detailCanvasWidth < 900 || (isPortraitLike && detailCanvasWidth < 1180)
    }

    var headerStacksVertically: Bool {
        detailCanvasWidth < 920 || isPortraitLike || isVeryCompactHeight
    }

    var formStacksVertically: Bool {
        detailCanvasWidth < 960 || isPortraitLike || isCompactHeight
    }

    var stacksWideColumns: Bool {
        detailCanvasWidth < 1120 || (isCompactHeight && detailCanvasWidth < 1240) || isPortraitLike
    }

    var stacksMediumColumns: Bool {
        detailCanvasWidth < 980 || isCompactHeight || isPortraitLike
    }

    var metadataWrapWidth: CGFloat {
        clamped(detailCanvasWidth * 0.68, min: 240, max: 760)
    }

    var quickActionMinimumWidth: CGFloat {
        detailCanvasWidth < 900 ? 112 : 142
    }

    var detailFactMinimumWidth: CGFloat {
        detailCanvasWidth < 900 ? 150 : 190
    }

    var settingsColumnMinimumWidth: CGFloat {
        detailCanvasWidth < 980 ? 240 : 320
    }

    var previewMetricMinimumWidth: CGFloat {
        detailCanvasWidth < 940 ? 160 : 220
    }

    var dashboardMinHeight: CGFloat {
        clamped(containerSize.height * 0.52, min: isCompactHeight ? 360 : 420, max: 620)
    }

    var logMinHeight: CGFloat {
        clamped(containerSize.height * 0.30, min: isCompactHeight ? 220 : 280, max: 380)
    }

    private func clamped(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    init(spacing: CGFloat = ClawNestLayout.Spacing.small, rowSpacing: CGFloat? = nil) {
        self.spacing = spacing
        self.rowSpacing = rowSpacing ?? spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: CGRect(origin: .zero, size: CGSize(width: proposal.width ?? .greatestFiniteMagnitude, height: proposal.height ?? .greatestFiniteMagnitude)), subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds, subviews: subviews)
        for (index, point) in result.positions.enumerated() {
            guard index < subviews.count else { continue }
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func layout(in bounds: CGRect, subviews: Subviews) -> (size: CGSize, sizes: [CGSize], positions: [CGPoint]) {
        let availableWidth = bounds.width.isFinite && bounds.width > 0 ? bounds.width : .greatestFiniteMagnitude
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        var positions: [CGPoint] = []
        positions.reserveCapacity(sizes.count)

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for size in sizes {
            let itemX = currentX == 0 ? 0 : currentX + spacing
            let proposedWidth = itemX + size.width
            if proposedWidth > availableWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + rowSpacing
                rowHeight = 0
            }

            let placedX = currentX == 0 ? 0 : currentX + spacing
            positions.append(CGPoint(x: placedX, y: currentY))
            currentX = placedX + size.width
            rowHeight = max(rowHeight, size.height)
            contentWidth = max(contentWidth, currentX)
        }

        return (CGSize(width: contentWidth, height: currentY + rowHeight), sizes, positions)
    }
}
