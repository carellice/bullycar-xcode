import SwiftUI
import Combine

class AppLifecycleManager: ObservableObject {
    @AppStorage("biometricAuthEnabled") private var biometricAuthEnabled = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupLifecycleObservers()
    }
    
    private func setupLifecycleObservers() {
        // Osserva quando l'app va in background
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        
        // Osserva quando l'app ritorna in foreground
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppWillResignActive() {
        // Quando l'app va in background, reset dell'autenticazione se abilitata
        if biometricAuthEnabled {
            BiometricAuthManager.shared.resetAuthentication()
            print("🔒 App in background - autenticazione resettata")
        }
    }
    
    private func handleAppDidBecomeActive() {
        // Quando l'app torna in foreground, l'autenticazione verrà richiesta automaticamente
        if biometricAuthEnabled {
            print("🔓 App in foreground - autenticazione richiesta")
        }
    }
}

// Aggiungi questo al BullyCarApp.swift:
/*
@main
struct BullyCarApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var lifecycleManager = AppLifecycleManager() // ← Aggiungi questo
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(themeManager)
                .environmentObject(lifecycleManager) // ← Aggiungi questo
                .preferredColorScheme(themeManager.colorScheme)
                .environment(\.locale, Locale(identifier: "it_IT"))
                .onAppear {
                    setupNotifications()
                }
        }
    }
    
    // ... resto del codice
}
*/
