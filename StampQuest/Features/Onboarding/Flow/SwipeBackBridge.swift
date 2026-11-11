import SwiftUI
import UIKit

/// Hiding the system back button also disables the interactive pop gesture. This puts it back, for the
/// navigation controller that hosts the onboarding stack only.
struct SwipeBackBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enable()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enable()
        }

        private func enable() {
            guard let navigation = navigationController, let gesture = navigation.interactivePopGestureRecognizer else { return }
            SwipeBackDelegate.shared.navigation = navigation
            gesture.delegate = SwipeBackDelegate.shared
            gesture.isEnabled = true
        }
    }
}

@MainActor
final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = SwipeBackDelegate()
    weak var navigation: UINavigationController?
    /// Set while a flight or save is in progress: leaving then would read as lost progress.
    var isLocked = false

    /// Only pop when there is something to pop to; never from the root.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        !isLocked && (navigation?.viewControllers.count ?? 0) > 1
    }
}
