import SwiftUI

struct BiometricAuthView: View {
    @StateObject private var authManager = BiometricAuthManager.shared
    @State private var isAuthenticating = false
    @State private var showingError = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.blue.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo e nome
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
                        
                        Image(systemName: "car.fill")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("BullyCar")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Le tue auto, sotto controllo")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Sezione autenticazione
                VStack(spacing: 30) {
                    // Icona biometrica
                    VStack(spacing: 16) {
                        Image(systemName: authManager.biometricIcon())
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                        
                        Text("Accedi con \(authManager.biometricTypeDescription())")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Bottone di autenticazione principale
                    Button(action: {
                        authenticateWithBiometrics()
                    }) {
                        HStack(spacing: 12) {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: authManager.biometricIcon())
                                    .font(.title3)
                            }
                            
                            Text(isAuthenticating ? "Autenticazione..." : "Sblocca con \(authManager.biometricTypeDescription())")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                    }
                    .disabled(isAuthenticating || !authManager.isBiometricAvailable())
                    .padding(.horizontal, 40)
                    
                    // Bottone passcode alternativo
                    Button(action: {
                        authenticateWithPasscode()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "key")
                                .font(.caption)
                            Text("Usa codice di accesso")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(Color.white.opacity(0.1))
                                )
                        )
                    }
                    .disabled(isAuthenticating)
                }
                
                Spacer()
                
                // Info sulla privacy
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("I tuoi dati sono protetti e criptati")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("L'autenticazione viene gestita dal sistema iOS")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            pulseAnimation = true
            
            // Avvia automaticamente l'autenticazione se disponibile
            if authManager.isBiometricAvailable() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    authenticateWithBiometrics()
                }
            }
        }
        .alert("Errore di autenticazione", isPresented: $showingError) {
            Button("Riprova") {
                authenticateWithBiometrics()
            }
            Button("Usa codice", role: .cancel) {
                authenticateWithPasscode()
            }
        } message: {
            Text(authManager.authError ?? "Errore sconosciuto")
        }
    }
    
    private func authenticateWithBiometrics() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        
        Task {
            let result = await authManager.authenticateWithBiometrics()
            
            await MainActor.run {
                isAuthenticating = false
                
                switch result {
                case .success:
                    // Autenticazione riuscita - l'app si sbloccherà automaticamente
                    print("✅ Autenticazione biometrica riuscita")
                    
                case .failure(let error):
                    // Gestisci diversi tipi di errore
                    switch error {
                    case .userCancel, .systemCancel:
                        // Non mostrare errore per cancellazioni
                        break
                    case .biometryLockout:
                        // Suggerisci il passcode
                        authenticateWithPasscode()
                    default:
                        // Mostra errore per altri casi
                        showingError = true
                    }
                    
                    print("❌ Errore autenticazione: \(error.errorDescription ?? "Sconosciuto")")
                }
            }
        }
    }
    
    private func authenticateWithPasscode() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        
        Task {
            let result = await authManager.authenticateWithPasscode()
            
            await MainActor.run {
                isAuthenticating = false
                
                switch result {
                case .success:
                    print("✅ Autenticazione con passcode riuscita")
                    
                case .failure(let error):
                    if case .userCancel = error {
                        // Non mostrare errore per cancellazione
                        break
                    } else {
                        showingError = true
                        print("❌ Errore autenticazione passcode: \(error.errorDescription ?? "Sconosciuto")")
                    }
                }
            }
        }
    }
}
