import SwiftUI

/// DataStore 变化通知名称
extension Notification.Name {
    static let clipboardDataChanged = Notification.Name("com.clipboardhistory.dataChanged")
}

@main
struct ClipboardHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 360, idealWidth: 380, maxWidth: 420,
                       minHeight: 400, idealHeight: 480, maxHeight: 600)
        }
        .windowResizability(.contentSize)
    }
}
