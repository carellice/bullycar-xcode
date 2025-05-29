import SwiftUI

@main
struct BullyCarApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .environment(\.locale, Locale(identifier: "it_IT")) // Forza italiano globalmente
        }
    }
}

// Gestore del tema con supporto automatico
class ThemeManager: ObservableObject {
    enum ThemeMode: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case automatic = "automatic"
        
        var displayName: String {
            switch self {
            case .light:
                return "Chiaro"
            case .dark:
                return "Scuro"
            case .automatic:
                return "Automatico"
            }
        }
        
        var systemImage: String {
            switch self {
            case .light:
                return "sun.max.fill"
            case .dark:
                return "moon.fill"
            case .automatic:
                return "circle.lefthalf.filled"
            }
        }
    }
    
    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
            print("🎨 Tema cambiato a: \(themeMode.displayName)")
        }
    }
    
    var colorScheme: ColorScheme? {
        switch themeMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .automatic:
            return nil // nil significa che segue il sistema
        }
    }
    
    // Proprietà di compatibilità per il vecchio sistema
    var isDarkMode: Bool {
        get {
            switch themeMode {
            case .dark:
                return true
            case .light:
                return false
            case .automatic:
                // In modalità automatica, controlla le impostazioni del sistema
                return UITraitCollection.current.userInterfaceStyle == .dark
            }
        }
        set {
            // Per compatibilità con il vecchio toggle
            themeMode = newValue ? .dark : .light
        }
    }
    
    init() {
        // Carica il tema salvato, con default automatico
        let savedTheme = UserDefaults.standard.string(forKey: "themeMode") ?? ThemeMode.automatic.rawValue
        self.themeMode = ThemeMode(rawValue: savedTheme) ?? .automatic
        
        print("🎨 Tema inizializzato: \(themeMode.displayName)")
    }
}
