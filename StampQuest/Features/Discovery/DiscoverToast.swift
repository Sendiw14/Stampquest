import SwiftUI

/// One toast at a time, with an optional Undo. A new toast replaces the old one; it goes away by itself after six seconds.
@MainActor
@Observable
final class ToastCenter {
    /// An optional mark before the message: the gold seal for a verified visit, a warning for something that did not happen.
    enum Icon { case none, seal, warning }

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let undo: (() -> Void)?
        var icon: Icon = .none
    }

    private(set) var current: Toast?
    private var dismissal: Task<Void, Never>?
    var duration: Duration = .seconds(6)

    func show(_ message: String, icon: Icon = .none, duration override: Duration? = nil, undo: (() -> Void)? = nil) {
        dismissal?.cancel()
        let toast = Toast(message: message, undo: undo, icon: icon)
        current = toast
        dismissal = Task { [weak self, id = toast.id, duration = override ?? duration] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self, self.current?.id == id else { return }
            self.current = nil
        }
    }

    /// Runs the Undo action of the visible toast and removes it.
    func undo() {
        guard let toast = current else { return }
        dismissal?.cancel()
        current = nil
        toast.undo?()
    }

    func dismiss() {
        dismissal?.cancel()
        current = nil
    }
}

/// The toast pill: light mode a charcoal pill with cream text, dark mode the reverse.
struct DiscoverToastView: View {
    let toast: ToastCenter.Toast
    let onUndo: () -> Void
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .subheadline) private var size = 15.0

    var body: some View {
        HStack(spacing: 12) {
            switch toast.icon {
            case .seal: VerifiedSeal(size: 22).accessibilityHidden(true)
            case .warning: Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 16)).foregroundStyle(undoColor).accessibilityHidden(true)
            case .none: EmptyView()
            }
            Text(toast.message).font(.system(size: size, weight: .semibold)).lineLimit(3)
            Spacer(minLength: 8)
            if toast.undo != nil {
                Button(action: onUndo) {
                    Text("Undo").font(.system(size: size, weight: .bold)).foregroundStyle(undoColor).frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain).accessibilityIdentifier("toast-undo")
            }
        }
        .foregroundStyle(scheme == .dark ? Color(hex: 0x211E1A) : Color(hex: 0xF6F0E5))
        .padding(.leading, 20).padding(.trailing, 14).frame(minHeight: 52)
        .background(scheme == .dark ? Color(hex: 0xF6F0E5) : Color(hex: 0x2B2927), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain).accessibilityIdentifier("toast")
    }

    private var undoColor: Color { scheme == .dark ? Color(hex: 0x8A4526) : Color(hex: 0xF0A982) }
}

private struct ToastOverlay: ViewModifier {
    let center: ToastCenter
    let bottomInset: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = center.current {
                DiscoverToastView(toast: toast) { center.undo() }
                    .padding(.bottom, bottomInset)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
                    .onAppear { UIAccessibility.post(notification: .announcement, argument: toast.message) }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.85), value: center.current?.id)
    }
}

extension View {
    /// Shows the app's toast, 16 pt above the tab bar (`bottomInset` is the tab bar height plus the gap).
    func discoverToast(_ center: ToastCenter, bottomInset: CGFloat = 96) -> some View { modifier(ToastOverlay(center: center, bottomInset: bottomInset)) }
}
