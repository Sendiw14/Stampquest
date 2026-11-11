import SwiftUI

@main
struct StampQuestApp: App {
    @State private var bootstrap = AppBootstrap()

    init() { FontRegistration.verifyInDebug() }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if LaunchConfiguration.current.showsArtGallery {
                    ArtGalleryView()
                        .task {
                            if ProcessInfo.processInfo.arguments.contains("-art-gallery-export") { ArtGalleryView.exportSheets() }
                        }
                } else {
                    content
                }
                #else
                content
                #endif
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch bootstrap.state {
        case .ready(let environment):
            RootView()
                .environment(environment)
                .modelContainer(environment.container)
        case .failed(let failure):
            StartupFailureView(failure: failure, retry: bootstrap.retry, startFresh: bootstrap.startFresh)
        }
    }
}
