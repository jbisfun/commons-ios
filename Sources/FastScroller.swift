import SwiftUI
import UIKit

/// RecyclerViewFastScroller (used by every Fossify list): a draggable handle on the right edge
/// with a bubble showing the item under it. Overlay it on a list and wire `position` to the
/// list's top item index (e.g. `.scrollPosition(id:)`) and `onScroll` to scrolling there.
public struct FastScroller: View {
    @Environment(\.palette) private var palette
    let count: Int
    let position: Int
    let bubbleText: (Int) -> String
    let onScroll: (Int) -> Void

    @State private var dragIndex: Int?
    @State private var visible = false
    @State private var hideTask: Task<Void, Never>?

    public init(count: Int, position: Int, bubbleText: @escaping (Int) -> String, onScroll: @escaping (Int) -> Void) {
        self.count = count
        self.position = position
        self.bubbleText = bubbleText
        self.onScroll = onScroll
    }

    public var body: some View {
        GeometryReader { geo in
            let handle: CGFloat = 48
            let index = dragIndex ?? position
            let fraction = count > 1 ? CGFloat(min(max(index, 0), count - 1)) / CGFloat(count - 1) : 0
            let y = fraction * max(geo.size.height - handle, 0)
            ZStack(alignment: .topTrailing) {
                if visible || dragIndex != nil {
                    Capsule()
                        .fill(palette.primaryColor)
                        .frame(width: 6, height: handle)
                        .padding(.trailing, 4)
                        .offset(y: y)
                        .allowsHitTesting(false)
                    if let dragIndex {
                        Text(bubbleText(dragIndex))
                            .font(.system(size: 20, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(palette.onPrimary)
                            .padding(.horizontal, 16)
                            .frame(minWidth: 56, minHeight: 56)
                            .background(
                                UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 28, bottomTrailingRadius: 4, topTrailingRadius: 28)
                                    .fill(palette.primaryColor)
                            )
                            .frame(maxWidth: geo.size.width - 60, alignment: .trailing)
                            .offset(x: -24, y: max(0, y + handle / 2 - 56))
                            .allowsHitTesting(false)
                    }
                }
                FastScrollTouchStrip { touchY in
                    guard let touchY else {
                        dragIndex = nil
                        scheduleHide()
                        return
                    }
                    let f = min(max((touchY - handle / 2) / max(geo.size.height - handle, 1), 0), 1)
                    let i = Int((f * CGFloat(max(count - 1, 0))).rounded())
                    if dragIndex != i {
                        dragIndex = i
                        visible = true
                        onScroll(i)
                    }
                }
                .frame(width: 28)
                .allowsHitTesting(visible || dragIndex != nil)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
        }
        .opacity(count > 1 ? 1 : 0)
        .onChange(of: position) { _, _ in
            visible = true
            scheduleHide()
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled && dragIndex == nil { withAnimation { visible = false } }
        }
    }
}

/// Reports the finger's y position (nil when lifted) and makes enclosing scroll views (the list,
/// a tab pager) wait, which a SwiftUI DragGesture inside a paging TabView can't do.
struct FastScrollTouchStrip: UIViewRepresentable {
    let onTouch: (CGFloat?) -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let g = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        g.minimumPressDuration = 0
        g.allowableMovement = .greatestFiniteMagnitude
        g.delegate = context.coordinator
        v.addGestureRecognizer(g)
        return v
    }

    func updateUIView(_ v: UIView, context: Context) { context.coordinator.onTouch = onTouch }
    func makeCoordinator() -> Coordinator { Coordinator(onTouch: onTouch) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTouch: (CGFloat?) -> Void
        init(onTouch: @escaping (CGFloat?) -> Void) { self.onTouch = onTouch }

        @objc func handle(_ g: UILongPressGestureRecognizer) {
            switch g.state {
            case .began, .changed: onTouch(g.location(in: g.view).y)
            default: onTouch(nil)
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other.view is UIScrollView
        }
    }
}
