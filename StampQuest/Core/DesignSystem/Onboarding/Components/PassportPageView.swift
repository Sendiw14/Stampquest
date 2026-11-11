import SwiftUI

/// The passport page the onboarding screens put stamps on: paper, hairline, printed decoration and the "VISAS" and
/// page-number headers, with `content` laid out under them. `tilt` rotates the whole page, content included.
struct PassportPageView<Content: View>: View {
    let width: CGFloat
    /// A fixed height, or nil to size to the content.
    var height: CGFloat?
    /// The printed page number, e.g. "PAGE 02".
    let pageNumber: String
    /// The printed "VISAS" and page-number headers.
    var showsHeaders = true
    var tilt: Angle = .zero
    var contentInsets = EdgeInsets(top: PassportPageMetrics.contentTop, leading: PassportPageMetrics.contentSide,
                                   bottom: 12, trailing: PassportPageMetrics.contentSide)
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(contentInsets)
            .frame(width: width, height: height, alignment: .topLeading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: PassportPageMetrics.corner, style: .continuous)
                        .fill(OnbColor.passportPaper)
                        .shadow(color: OnbColor.passportShadow, radius: 10, y: 18)
                    PassportPageDecor()
                }
            }
            .overlay(alignment: .top) { if showsHeaders { headers } }
            .overlay {
                RoundedRectangle(cornerRadius: PassportPageMetrics.corner, style: .continuous)
                    .strokeBorder(OnbColor.passportHairline, lineWidth: 1.2)
            }
            .rotationEffect(tilt)
    }

    private var headers: some View {
        HStack {
            Text("onboarding.interests.page.visas")
            Spacer()
            Text(pageNumber)
        }
        .font(.system(size: 8, weight: .bold))
        .tracking(2.6)
        .foregroundStyle(OnbColor.passportHeader)
        .padding(.horizontal, 26)
        .padding(.top, 25)
        .accessibilityHidden(true)
    }
}

nonisolated enum PassportPageMetrics {
    static let corner: CGFloat = 20
    static let contentSide: CGFloat = 17
    static let contentTop: CGFloat = 40
}
