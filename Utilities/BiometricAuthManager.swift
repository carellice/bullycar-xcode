import Foundation
import LocalAuthentication

class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    @Published var isAuthenticated = false
    @Published var authError: String?
    
    enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID
    }
    
    enum AuthError: Error, LocalizedError {
        case biometryNotAvailable
        case biometryNotEnrolled
        case biometryLockout
        case authenticationFailed
        case userCancel
        case systemCancel
        case passcodeNotSet
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .biometryNotAvailable:
                return "L'autenticazione biometrica non è disponibile su questo dispositivo"
            case .biometryNotEnrolled:
                return "Nessuna impronta digitale o Face ID configurato"
            case .biometryLockout:
                return "Autenticazione biometrica bloccata. Usa il codice"
            case .authenticationFailed:
                return "Autenticazione fallita"
            case .userCancel:
                return "Autenticazione annullata dall'utente"
            case .systemCancel:
                return "Autenticazione annullata dal sistema"
            case .passcodeNotSet:
                return "Codice di accesso non impostato"
            case .unknown(let error):
                return "Errore sconosciuto: \(error.localizedDescription)"
            }
        }
    }
    
    private init() {}
    
    // Controlla il tipo di biometria disponibile
    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }
    
    // Descrizione del tipo di biometria
    func biometricTypeDescription() -> String {
        switch biometricType() {
        case .none:
            return "Non disponibile"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }
    
    // Icona per il tipo di biometria
    func biometricIcon() -> String {
        switch biometricType() {
        case .none:
            return "lock"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        }
    }
    
    // Controlla se la biometria è disponibile
    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // Esegue l'autenticazione biometrica
    func authenticateWithBiometrics() async -> Result<Void, AuthError> {
        let context = LAContext()
        var error: NSError?
        
        // Controlla se la biometria è disponibile
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    return .failure(.biometryNotAvailable)
                case LAError.biometryNotEnrolled.rawValue:
                    return .failure(.biometryNotEnrolled)
                case LAError.passcodeNotSet.rawValue:
                    return .failure(.passcodeNotSet)
                default:
                    return .failure(.unknown(error))
                }
            }
            return .failure(.biometryNotAvailable)
        }
        
        // Imposta il messaggio in base al tipo di biometria
        let reason: String
        switch biometricType() {
        case .faceID:
            reason = "Usa Face ID per accedere a BullyCar"
        case .touchID:
            reason = "Usa Touch ID per accedere a BullyCar"
        case .opticID:
            reason = "Usa Optic ID per accedere a BullyCar"
        case .none:
            reason = "Autenticati per accedere a BullyCar"
        }
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                await MainActor.run {
                    self.isAuthenticated = true
                    self.authError = nil
                }
                return .success(())
            } else {
                return .failure(.authenticationFailed)
            }
        } catch {
            let authError = mapLAError(error)
            await MainActor.run {
                self.authError = authError.errorDescription
            }
            return .failure(authError)
        }
    }
    
    // Autentica con passcode come fallback
    func authenticateWithPasscode() async -> Result<Void, AuthError> {
        let context = LAContext()
        let reason = "Inserisci il tuo codice per accedere a BullyCar"
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if success {
                await MainActor.run {
                    self.isAuthenticated = true
                    self.authError = nil
                }
                return .success(())
            } else {
                return .failure(.authenticationFailed)
            }
        } catch {
            let authError = mapLAError(error)
            await MainActor.run {
                self.authError = authError.errorDescription
            }
            return .failure(authError)
        }
    }
    
    // Reset dell'autenticazione (per logout)
    func resetAuthentication() {
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.authError = nil
        }
    }
    
    // Mappa gli errori LAError ai nostri AuthError
    private func mapLAError(_ error: Error) -> AuthError {
        guard let laError = error as? LAError else {
            return .unknown(error)
        }
        
        switch laError.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancel
        case .systemCancel:
            return .systemCancel
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockout
        default:
            return .unknown(error)
        }
    }
}
