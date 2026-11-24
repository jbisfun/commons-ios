import SwiftUI
import UIKit

/// com.reddit.indicatorfastscroll's FastScrollerView + FastScrollerThumbView (contacts lists of
/// Contacts, Phone, ...): a column of letters along the right edge with a bubble showing the
/// letter being scrolled to. `onSelect` gets the touched letter; scroll the list there.
public struct LetterFastScroller: View {
    @Environment(\.palette) private var palette
    let letters: [String]
    let onSelect: (String) -> Void
    @State private var active: String?
    @State private var activeY: CGFloat = 0

    public init(letters: [String], onSelect: @escaping (String) -> Void) {
        self.letters = letters
        self.onSelect = onSelect
    }

    /// (letter, id of the first item with that letter) in list order, for `letters` / scrolling.
    public static func firstIDs<ID>(_ items: [(letter: String, id: ID)]) -> [(String, ID)] {
        var seen = Set<String>()
        var out: [(String, ID)] = []
        for item in items where seen.insert(item.letter).inserted { out.append((item.letter, item.id)) }
        return out
    }

    public var body: some View {
        GeometryReader { geo in
            let rowH = min(18, geo.size.height / CGFloat(max(letters.count, 1)))
            let total = rowH * CGFloat(letters.count)
            let top = (geo.size.height - total) / 2
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    ForEach(letters, id: \.self) { l in
                        Text(l)
                            .font(.system(size: min(12, rowH * 0.8), weight: .medium))
                            .foregroundStyle(l == active ? palette.primaryColor : palette.textColor)
                            .frame(width: 24, height: rowH)
                    }
                }
                .frame(width: 24)
                .padding(.top, top)
                .overlay {
                    // UIKit touch strip: a SwiftUI DragGesture here gets cancelled by a
                    // tab pager's UIScrollView pan as soon as the finger moves.
                    LetterScrollerTouchStrip { y in
                        guard let y else { active = nil; return }
                        let idx = min(max(Int((y - top) / rowH), 0), letters.count - 1)
                        guard letters.indices.contains(idx) else { return }
                        activeY = top + CGFloat(idx) * rowH + rowH / 2
                        if active != letters[idx] {
                            active = letters[idx]
                            UISelectionFeedbackGenerator().selectionChanged()
                            onSelect(letters[idx])
                        }
                    }
                }

                if let active {
                    Text(active)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(palette.onPrimary)
                        .frame(width: 64, height: 64)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: 32, bottomTrailingRadius: 4, topTrailingRadius: 32)
                                .fill(palette.primaryColor)
                        )
                        .offset(x: -40, y: activeY - 32)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
        }
        .frame(width: 110)
    }
}

/// Reports the finger's y position (nil when lifted) from touch-down on, and makes
/// every enclosing scroll view (list, tab pager) wait until the finger is lifted.
struct LetterScrollerTouchStrip: UIViewRepresentable {
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

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            false
        }
    }
}
