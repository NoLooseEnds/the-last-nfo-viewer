import CoreGraphics

enum NFOTextAlignment {
    case left
    case center
    case right
}

struct NFOContentLayout: Equatable {
    let textViewWidth: CGFloat
    let textContainerWidth: CGFloat?
    let horizontalInset: CGFloat
    let widthTracksTextView: Bool
    let scrollsHorizontally: Bool
}

enum NFOLayoutPolicy {
    static let minimumWindowDimension: CGFloat = 240
    static let horizontalWindowPadding: CGFloat = 60
    static let verticalWindowPadding: CGFloat = 40
    static let minimumTextPadding: CGFloat = 20
    static let oversizedContentHeightRatio: CGFloat = 0.75
    static let frameComparisonTolerance: CGFloat = 1

    static func contentLayout(
        contentWidth: CGFloat,
        availableWidth: CGFloat,
        alignment: NFOTextAlignment
    ) -> NFOContentLayout {
        let requiredWidth = contentWidth + minimumTextPadding * 2

        guard availableWidth + frameComparisonTolerance >= requiredWidth else {
            return NFOContentLayout(
                textViewWidth: requiredWidth,
                textContainerWidth: requiredWidth,
                horizontalInset: minimumTextPadding,
                widthTracksTextView: false,
                scrollsHorizontally: true
            )
        }

        switch alignment {
        case .left:
            return NFOContentLayout(
                textViewWidth: availableWidth,
                textContainerWidth: nil,
                horizontalInset: minimumTextPadding,
                widthTracksTextView: true,
                scrollsHorizontally: false
            )
        case .center:
            return NFOContentLayout(
                textViewWidth: availableWidth,
                textContainerWidth: nil,
                horizontalInset: floor((availableWidth - contentWidth) / 2),
                widthTracksTextView: true,
                scrollsHorizontally: false
            )
        case .right:
            return NFOContentLayout(
                textViewWidth: availableWidth,
                textContainerWidth: ceil(contentWidth),
                horizontalInset: floor(availableWidth - contentWidth - minimumTextPadding),
                widthTracksTextView: false,
                scrollsHorizontally: false
            )
        }
    }

    static func autoFitFrame(
        idealWindowSize: CGSize,
        currentFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGRect {
        let targetSize = autoFitSize(
            idealSize: idealWindowSize,
            visibleSize: visibleFrame.size
        )

        let targetWidth = targetSize.width
        let targetHeight = targetSize.height

        var targetFrame = CGRect(
            x: currentFrame.midX - targetWidth / 2,
            y: currentFrame.midY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
        targetFrame.origin.x = min(
            max(targetFrame.origin.x, visibleFrame.minX),
            visibleFrame.maxX - targetWidth
        )
        targetFrame.origin.y = min(
            max(targetFrame.origin.y, visibleFrame.minY),
            visibleFrame.maxY - targetHeight
        )
        return targetFrame
    }

    static func autoFitSize(
        idealSize: CGSize,
        visibleSize: CGSize
    ) -> CGSize {
        let targetWidth = min(
            max(idealSize.width, minimumWindowDimension),
            visibleSize.width
        )
        let heightLimit = idealSize.height <= visibleSize.height
            ? visibleSize.height
            : floor(visibleSize.height * oversizedContentHeightRatio)
        let targetHeight = min(
            max(idealSize.height, minimumWindowDimension),
            heightLimit
        )
        return CGSize(width: targetWidth, height: targetHeight)
    }

    static func framesAreApproximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < frameComparisonTolerance
            && abs(lhs.origin.y - rhs.origin.y) < frameComparisonTolerance
            && abs(lhs.width - rhs.width) < frameComparisonTolerance
            && abs(lhs.height - rhs.height) < frameComparisonTolerance
    }
}
