import SwiftUI
import Combine

// Gestore dello stato delle impostazioni per evitare bug di apertura/chiusura
class SettingsStateManager: ObservableObject {
    @Published var isShowingSettings = false
    @Published var settingsViewKey = UUID()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listener per reset automatico dopo importazione
        NotificationCenter.default.publisher(for: NSNotification.Name("ImportCompleted"))
            .sink { [weak self] _ in
                print("📡 Importazione completata - reset settings state")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.resetSettingsState()
                }
            }
            .store(in: &cancellables)
        
        // Listener per reset forzato
        NotificationCenter.default.publisher(for: NSNotification.Name("ForceSettingsReset"))
            .sink { [weak self] _ in
                print("📡 Reset forzato settings - chiusura immediata")
                DispatchQueue.main.async {
                    self?.isShowingSettings = false
                    self?.resetSettingsState()
                }
            }
            .store(in: &cancellables)
    }
    
    func openSettings() {
        print("🎛️ Apertura impostazioni richiesta")
        
        // Reset preventivo per assicurarsi che non ci siano conflitti
        resetSettingsState()
        
        // Apertura ritardata per dare tempo al reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isShowingSettings = true
            print("✅ Impostazioni aperte")
        }
    }
    
    func closeSettings() {
        print("🎛️ Chiusura impostazioni")
        isShowingSettings = false
        
        // Reset dopo chiusura per pulire lo stato
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.resetSettingsState()
        }
    }
    
    // Metodo pubblico per reset forzato
    func resetSettingsState() {
        print("🔄 Reset pubblico stato impostazioni")
        settingsViewKey = UUID()
        
        // Se le impostazioni sono aperte durante un reset, chiudile
        if isShowingSettings {
            isShowingSettings = false
        }
    }
}
