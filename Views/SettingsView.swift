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

                
                // Sezione backup
                Section(header: Text("Backup locale")) {
                    Button(action: { showingExportSheet = true }) {
                        Label("Esporta dati", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingImportSheet = true }) {
                        Label("Importa dati", systemImage: "square.and.arrow.down")
                    }
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Esportazione dati")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Questa funzionalità sarà disponibile prossimamente")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Chiudi") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Esporta")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Vista per importare documenti
struct DocumentImporter: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.badge.arrow.up.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Importazione dati")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Questa funzionalità sarà disponibile prossimamente")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Chiudi") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Importa")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
