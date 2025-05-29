import SwiftUI
import Combine

// Gestore dello stato delle impostazioni per evitare bug di apertura/chiusura
class SettingsStateManager: ObservableObject {
    @Published var isShowingSettings = false
    @Published var settingsViewKey = UUID()
    
    private var cancellables = Set<AnyCancellable>()
    private var isImportInProgress = false
    
    init() {
        setupNotificationListeners()
    }
    
    private func setupNotificationListeners() {
        // Listener per completamento importazione
        NotificationCenter.default.publisher(for: NSNotification.Name("ImportCompleted"))
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📡 Importazione completata - reset completo")
                self?.handleImportCompletion()
            }
            .store(in: &cancellables)
        
        // Listener per reset forzato
        NotificationCenter.default.publisher(for: NSNotification.Name("ForceSettingsReset"))
            .sink { [weak self] _ in
                print("📡 Reset forzato settings")
                self?.forceReset()
            }
            .store(in: &cancellables)
        
        // Listener per inizio importazione
        NotificationCenter.default.publisher(for: NSNotification.Name("ImportStarted"))
            .sink { [weak self] _ in
                print("📡 Importazione iniziata")
                self?.isImportInProgress = true
            }
            .store(in: &cancellables)
    }
    
    func openSettings() {
        guard !isImportInProgress else {
            print("⚠️ Importazione in corso - apertura impostazioni bloccata")
            return
        }
        
        print("🎛️ Apertura impostazioni richiesta")
        
        // Reset completo prima dell'apertura
        resetSettingsState()
        
        // Apertura con delay per garantire pulizia stato
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isShowingSettings = true
            }
            print("✅ Impostazioni aperte")
        }
    }
    
    func closeSettings() {
        print("🎛️ Chiusura impostazioni")
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingSettings = false
        }
        
        // Reset dopo chiusura
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.cleanupAfterClose()
        }
    }
    
    private func handleImportCompletion() {
        isImportInProgress = false
        
        // Chiudi immediatamente le impostazioni se aperte
        if isShowingSettings {
            isShowingSettings = false
        }
        
        // Reset completo con delay maggiore
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.resetSettingsState()
            print("✅ Reset post-importazione completato")
        }
    }
    
    private func forceReset() {
        isImportInProgress = false
        isShowingSettings = false
        
        DispatchQueue.main.async {
            self.resetSettingsState()
        }
    }
    
    private func cleanupAfterClose() {
        if !isImportInProgress {
            resetSettingsState()
        }
    }
    
    // Reset completo dello stato
    func resetSettingsState() {
        print("🔄 Reset completo stato impostazioni")
        settingsViewKey = UUID()
        
        // Assicurati che le impostazioni siano chiuse
        if isShowingSettings {
            isShowingSettings = false
        }
    }
}
