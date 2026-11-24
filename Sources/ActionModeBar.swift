import SwiftUI
import UIKit

/// MyRecyclerViewAdapter's action mode (CAB): replaces the top bar while items are selected,
/// with a close button, the selected count and the menu actions.
public struct ActionModeBar<Actions: View>: View {
    @Environment(\.palette) private var palette
    let count: Int
    let onClose: () -> Void
    let actions: () -> Actions

    public init(count: Int, onClose: @escaping () -> Void, @ViewBuilder actions: @escaping () -> Actions) {
        self.count = count
        self.onClose = onClose
        self.actions = actions
    }

    public var body: some View {
        HStack(spacing: 0) {
            IconButton(icon: "xmark", action: onClose)
            Text("\(count)").font(.system(size: 20, weight: .medium)).padding(.leading, 8)
            Spacer()
            actions()
        }
        .foregroundStyle(palette.onPrimary)
        .padding(.horizontal, 4)
        .frame(height: 64)
        .background(palette.primaryColor.ignoresSafeArea(edges: .top))
    }
}

/// The "⋮" overflow menu of a bar.
public struct OverflowMenu<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Menu(content: content) {
            Image(systemName: "ellipsis").rotationEffect(.degrees(90)).font(.system(size: 18)).frame(width: 44, height: 48)
        }
    }
}

/// Toggles `id` in a selection set with the long-press haptic.
public func toggleSelection<ID: Hashable>(_ id: ID, in selection: inout Set<ID>) {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
}
