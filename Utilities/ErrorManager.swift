import SwiftUI

class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var currentError: ErrorInfo?
    
    struct ErrorInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let type: ErrorType
    }
    
    enum ErrorType {
        case cloudKit
        case coreData
        case general
    }
    
    func showError(_ title: String, message: String, type: ErrorType = .general) {
        DispatchQueue.main.async {
            self.currentError = ErrorInfo(title: title, message: message, type: type)
        }
    }
}

// View Modifier per mostrare errori
struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorManager = ErrorManager.shared
    
    func body(content: Content) -> some View {
        content
            .alert(item: $errorManager.currentError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorAlertModifier())
    }
}
