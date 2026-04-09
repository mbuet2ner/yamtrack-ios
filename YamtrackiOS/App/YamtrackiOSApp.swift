import Foundation
import SwiftUI

@main
struct YamtrackiOSApp: App {
    private let rootView: RootView

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let invalidAuth = arguments.contains("-ui-testing-invalid-auth")
        let session = SessionController.live(
            validator: invalidAuth ? UIInvalidAuthSessionInfoValidator() : URLSessionSessionInfoValidator()
        )

        if arguments.contains("-ui-testing-reset-session") {
            session.logout()
        }

        rootView = RootView(session: session)
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }
}

private struct UIInvalidAuthSessionInfoValidator: SessionInfoValidating {
    func validate(_ request: URLRequest) async throws {
        throw SessionError.invalidToken
    }
}
