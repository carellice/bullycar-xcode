import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var systemColorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("reminderDays") private var reminderDays = 7
    @State private var showingDeleteAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var refreshID = UUID()
    @State private var showingAutomaticThemeAlert = false // Alert per tema automatico
    
    var body: some View {
        NavigationView {
            Form {
                // Sezione aspetto
                Section(header: Text("Aspetto")) {
                    // Menu a tendina per la selezione del tema
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        
                        Text("Tema")
                            .font(.body)
                        
                        Spacer()
                        
                        Menu {
                            ForEach(ThemeManager.ThemeMode.allCases, id: \.self) { mode in
                                Button(action: {
                                    // Se stiamo passando ad automatico, mostra prima l'alert
                                    if mode == .automatic && themeManager.themeMode != .automatic {
                                        showingAutomaticThemeAlert = true
                                    } else {
                                        // Per gli altri temi, cambia normalmente
                                        themeManager.themeMode = mode
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: mode.systemImage)
                                        Text(mode.displayName)
                                        
                                        if themeManager.themeMode == mode {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: themeManager.themeMode.systemImage)
                                    .foregroundColor(.secondary)
                                Text(themeManager.themeMode.displayName)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Descrizione della modalità selezionata
                    Text(getThemeDescription(themeManager.themeMode))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 32)
                }
                
                // Sezione notifiche
                Section(header: Text("Notifiche")) {
                    Toggle("Abilita notifiche", isOn: $enableNotifications)
                    
                    if enableNotifications {
                        Stepper("Avvisa \(reminderDays) giorni prima",
                               value: $reminderDays,
                               in: 1...30)
                    }
                }
                
                // Sezione backup locale
                Section(header: Text("Backup Locale")) {
                    Button(action: { showingExportSheet = true }) {
                        Label("Esporta dati", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingImportSheet = true }) {
                        Label("Importa dati", systemImage: "square.and.arrow.down")
                    }
                    
                    Text("I backup includono tutte le auto, manutenzioni, documenti e promemoria")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Sezione info app
                Section(header: Text("Informazioni")) {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("Rivedi Onboarding")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Sezione pericolosa
                Section {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Cancella tutti i dati", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .id("\(refreshID)_\(themeManager.themeMode.rawValue)") // Usa il tema come parte dell'ID
        }
        .id(themeManager.themeMode.rawValue) // NavigationView si ricrea quando cambia il tema
        .preferredColorScheme(themeManager.themeMode == .automatic ? nil : themeManager.colorScheme)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert("Impostazione Tema Automatico", isPresented: $showingAutomaticThemeAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Conferma") {
                // Cambia il tema
                themeManager.themeMode = .automatic
                
                // Chiudi le impostazioni con un breve delay per permettere al tema di cambiare
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        } message: {
            Text("Il tema seguirà le impostazioni del sistema. Le impostazioni si chiuderanno per applicare il cambiamento.")
        }
        .alert("Cancella tutti i dati", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Cancella", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("Questa operazione cancellerà definitivamente tutti i dati dell'app. Non può essere annullata.")
        }
        .sheet(isPresented: $showingExportSheet) {
            DocumentExporter()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.themeMode == .automatic ? nil : themeManager.colorScheme)
        }
        .sheet(isPresented: $showingImportSheet) {
            DocumentImporter()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.themeMode == .automatic ? nil : themeManager.colorScheme)
        }
    }
    
    private func deleteAllData() {
        print("🗑️ Iniziando eliminazione di tutti i dati...")
        
        do {
            let carRequest: NSFetchRequest<Car> = Car.fetchRequest()
            let cars = try viewContext.fetch(carRequest)
            
            for car in cars {
                viewContext.delete(car)
            }
            
            try viewContext.save()
            viewContext.reset()
            
            // Notifica eliminazione dati PRIMA di chiudere
            NotificationCenter.default.post(
                name: NSNotification.Name("DataDeleted"),
                object: nil
            )
            
            print("✅ Tutti i dati eliminati con successo")
            
            // Chiudi le impostazioni con delay per permettere il reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dismiss()
                
                // Notifica aggiuntiva per refresh
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CarDataChanged"),
                        object: nil
                    )
                }
            }
            
        } catch {
            print("❌ Errore eliminazione: \(error)")
        }
    }
    
    private func getThemeDescription(_ mode: ThemeManager.ThemeMode) -> String {
        switch mode {
        case .light:
            return "L'app userà sempre il tema chiaro"
        case .dark:
            return "L'app userà sempre il tema scuro"
        case .automatic:
            return "L'app seguirà le impostazioni del dispositivo"
        }
    }
}

// MARK: - Document Export
struct DocumentExporter: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedData: Data?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Esporta Backup")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Crea un backup completo di tutti i tuoi dati:\n• Auto\n• Manutenzioni\n• Documenti\n• Promemoria\n• Note")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if isExporting {
                    ProgressView("Preparazione backup...")
                        .padding()
                } else {
                    Button(action: exportData) {
                        Label("Esporta Backup", systemImage: "doc.badge.arrow.up")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Esporta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let data = exportedData {
                BackupShareSheet(data: data)
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        errorMessage = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                exportedData = try BackupManager.exportData(from: viewContext)
                isExporting = false
                showingShareSheet = true
            } catch {
                isExporting = false
                errorMessage = "Errore esportazione: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Document Import
struct DocumentImporter: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingFilePicker = false
    @State private var isImporting = false
    @State private var successMessage: String?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "square.and.arrow.down.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Importa Backup")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Seleziona un file di backup BullyCar (.json) per ripristinare i tuoi dati")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if isImporting {
                    ProgressView("Importazione in corso...")
                        .padding()
                } else {
                    Button(action: { showingFilePicker = true }) {
                        Label("Seleziona Backup", systemImage: "doc.badge.arrow.down")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                if let success = successMessage {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(success)
                                .foregroundColor(.green)
                        }
                        
                        Button("Chiudi") {
                            handleSuccessfulImport()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("Importante:", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.headline)
                    
                    Text("L'importazione sostituirà completamente tutti i dati esistenti. I dati attuali verranno eliminati e sostituiti con quelli del backup selezionato.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Importa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        if !isImporting {
                            dismiss()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker { url in
                importData(from: url)
            }
        }
    }
    
    private func importData(from url: URL) {
        print("📥 Iniziando importazione da: \(url.lastPathComponent)")
        
        isImporting = true
        errorMessage = nil
        successMessage = nil
        
        // Notifica inizio importazione
        NotificationCenter.default.post(
            name: NSNotification.Name("ImportStarted"),
            object: nil
        )
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Elimina tutti i dati esistenti
                DispatchQueue.main.sync {
                    self.deleteAllLocalData()
                }
                
                // Importa i nuovi dati
                let data = try Data(contentsOf: url)
                try BackupManager.importData(data, to: viewContext)
                
                DispatchQueue.main.async {
                    print("✅ Importazione completata con successo")
                    self.isImporting = false
                    self.successMessage = "Backup importato con successo!"
                }
                
            } catch {
                DispatchQueue.main.async {
                    print("❌ Errore importazione: \(error)")
                    self.isImporting = false
                    self.errorMessage = "Errore importazione: \(error.localizedDescription)"
                    
                    // Sblocca il sistema anche in caso di errore
                    self.resetSystemState()
                }
            }
        }
    }
    
    private func handleSuccessfulImport() {
        print("🎯 Gestendo completamento importazione")
        
        // Chiudi immediatamente l'importer
        dismiss()
        
        // Esegui il reset del sistema con sequenza ottimizzata
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.resetSystemState()
        }
    }
    
    private func resetSystemState() {
        print("🔄 Resettando stato del sistema post-importazione")
        
        // Sequenza ottimizzata di notifiche
        NotificationCenter.default.post(
            name: NSNotification.Name("CarDataChanged"),
            object: nil
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("ImportCompleted"),
                object: nil
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(
                name: NSNotification.Name("ForceSettingsReset"),
                object: nil
            )
        }
        
        print("✅ Reset sistema completato")
    }
    
    private func deleteAllLocalData() {
        print("🗑️ Eliminando dati locali per importazione")
        do {
            let carRequest: NSFetchRequest<Car> = Car.fetchRequest()
            let cars = try viewContext.fetch(carRequest)
            
            for car in cars {
                viewContext.delete(car)
            }
            
            try viewContext.save()
            viewContext.reset()
            print("✅ Dati locali eliminati")
        } catch {
            print("❌ Errore eliminazione dati locali: \(error)")
        }
    }
}

// MARK: - Backup Share Sheet
struct BackupShareSheet: UIViewControllerRepresentable {
    let data: Data
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let fileName = BackupManager.generateBackupFileName()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            let controller = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let popover = controller.popoverPresentationController {
                popover.sourceView = UIView()
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            return controller
        } catch {
            let controller = UIActivityViewController(activityItems: [data], applicationActivities: nil)
            return controller
        }
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
