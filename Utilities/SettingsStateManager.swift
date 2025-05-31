import SwiftUI
import Combine

// Gestore dello stato delle impostazioni per evitare bug di apertura/chiusura
class SettingsStateManager: ObservableObject {
    @Published var isShowingSettings = false
    @Published var settingsViewKey = UUID()
    
    private var cancellables = Set<AnyCancellable>()
    private var isOperationInProgress = false
    
    init() {
        setupNotificationListeners()
    }
    
    private func setupNotificationListeners() {
        // Listener per inizio importazione
        NotificationCenter.default.publisher(for: NSNotification.Name("ImportStarted"))
            .sink { [weak self] _ in
                print("📡 Importazione iniziata - bloccando operazioni")
                self?.isOperationInProgress = true
            }
            .store(in: &cancellables)
        
        // Listener per completamento importazione
        NotificationCenter.default.publisher(for: NSNotification.Name("ImportCompleted"))
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📡 Importazione completata - preparando reset")
                self?.handleImportCompletion()
            }
            .store(in: &cancellables)
        
        // Listener per reset forzato (dopo importazione)
        NotificationCenter.default.publisher(for: NSNotification.Name("ForceSettingsReset"))
            .sink { [weak self] _ in
                print("📡 Reset forzato - sbloccando sistema")
                self?.forceReset()
            }
            .store(in: &cancellables)
        
        // Listener per eliminazione dati
        NotificationCenter.default.publisher(for: NSNotification.Name("DataDeleted"))
            .sink { [weak self] _ in
                print("📡 Dati eliminati - reset leggero")
                self?.handleDataDeletion()
            }
            .store(in: &cancellables)
    }
    
    func openSettings() {
        guard !isOperationInProgress else {
            print("⚠️ Operazione in corso - apertura impostazioni bloccata")
            return
        }
        
        guard !isShowingSettings else {
            print("⚠️ Impostazioni già aperte")
            return
        }
        
        print("🎛️ Apertura impostazioni richiesta")
        
        // Reset prima dell'apertura
        settingsViewKey = UUID()
        
        // Apertura immediata
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingSettings = true
        }
        print("✅ Impostazioni aperte")
    }
    
    func closeSettings() {
        print("🎛️ Chiusura impostazioni")
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingSettings = false
        }
    }
    
    private func handleImportCompletion() {
        print("🔄 Gestendo completamento importazione")
        
        // Chiudi immediatamente le impostazioni se aperte
        if isShowingSettings {
            isShowingSettings = false
            print("🎛️ Impostazioni chiuse automaticamente post-importazione")
        }
        
        // Reset con delay breve
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.settingsViewKey = UUID()
            print("🔄 SettingsViewKey resettata post-importazione")
        }
    }
    
    private func forceReset() {
        print("🔄 Reset forzato in corso")
        
        // Sblocca immediatamente il sistema
        isOperationInProgress = false
        
        // Chiudi impostazioni se aperte
        if isShowingSettings {
            isShowingSettings = false
        }
        
        // Reset della chiave
        settingsViewKey = UUID()
        
        print("✅ Reset forzato completato - sistema sbloccato")
    }
    
    private func handleDataDeletion() {
        print("🔄 Gestendo eliminazione dati")
        
        // Per l'eliminazione dati, non bloccare le operazioni
        // Reset semplice della vista
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.settingsViewKey = UUID()
        }
    }
    
    // Reset completo dello stato
    func resetSettingsState() {
        print("🔄 Reset completo stato impostazioni")
        settingsViewKey = UUID()
        isOperationInProgress = false
        
        // Assicurati che le impostazioni siano chiuse
        if isShowingSettings {
            isShowingSettings = false
        }
    }
}
