import SwiftUI

@main
struct WindirStatMacApp: App {
    @State private var viewModel = ScanViewModel()

    var body: some Scene {
        WindowGroup {
            MainWindowView(viewModel: viewModel)
                .frame(minWidth: 640, minHeight: 420)
        }
        .defaultSize(width: 900, height: 600)
    }
}
