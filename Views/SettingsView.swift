import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("reminderDays") private var reminderDays = 7
    @State private var showingDeleteAlert = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var refreshID = UUID() // Aggiunto per forzare il refresh
    
    var body: some View {
        NavigationView {
            Form {
                // Sezione aspetto
                Section(header: Text("Aspetto")) {
                    Toggle("Tema scuro", isOn: $themeManager.isDarkMode)
                        .onChange(of: themeManager.isDarkMode) { _ in
                            // Forza il refresh della vista
                            refreshID = UUID()
                        }
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
            .id(refreshID) // Forza il refresh quando cambia l'ID
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light) // Forza lo schema colori
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
        .sheet(isPresented: $showingImportSheet) {
            DocumentImporter()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
    }
    
    private func deleteAllData() {
        PersistenceController.shared.deleteAllData()
        dismiss()
    }
}

// Vista per esportare documenti
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
                ShareSheet(items: [
                    BackupManager.generateBackupFileName(),
                    data
                ])
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

// Vista per importare documenti
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
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(success)
                            .foregroundColor(.green)
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
                    Label("Nota importante:", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.headline)
                    
                    Text("L'importazione aggiungerà i dati del backup a quelli esistenti. Se vuoi sostituire completamente i dati, elimina prima quelli attuali dalle impostazioni.")
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
                        dismiss()
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
        isImporting = true
        errorMessage = nil
        successMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                try BackupManager.importData(data, to: viewContext)
                
                DispatchQueue.main.async {
                    isImporting = false
                    successMessage = "Backup importato con successo!"
                    
                    // Chiudi dopo 2 secondi
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    errorMessage = "Errore importazione: \(error.localizedDescription)"
                }
            }
        }
    }
}
