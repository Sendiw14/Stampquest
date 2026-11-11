import SwiftUI

/// The 30 pt close circle with a 44 x 44 target.
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold)) // audit:fixed-glyph: inside a fixed-size badge or icon button
                .foregroundStyle(OnbColor.inkSecondary)
                .frame(width: 30, height: 30)
                .background(OnbColor.closeFill, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("exit.close"))
        .accessibilityHint(Text("exit.close.hint"))
        .accessibilityIdentifier("exitSheet.close")
    }
}
