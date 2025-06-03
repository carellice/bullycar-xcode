import SwiftUI

// MARK: - Backup Status Card SEMPLIFICATA
struct BackupStatusCard: View {
    @StateObject private var backupManager = BackupStatusManager.shared
    @State private var showingExportSheet = false
    @State private var isExpanded = false
    @State private var isCardVisible = true // Controllo locale della visibilità
    
    var body: some View {
        // SEMPLIFICATO: Usa solo lo stato locale per la visibilità
        if isCardVisible && backupManager.backupStatus.shouldShowCard {
            VStack(spacing: 0) {
                // Header principale
                HStack(spacing: 12) {
                    // Icona
                    ZStack {
                        Circle()
                            .fill(backupManager.backupStatus.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: backupManager.backupStatus.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(backupManager.backupStatus.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(backupManager.backupStatus.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(backupManager.backupStatus.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                    
                    Spacer()
                    
                    // Pulsante espandi
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Sezione espandibile
                if isExpanded {
                    VStack(spacing: 16) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                        
                        // Dettagli timing
                        VStack(spacing: 8) {
                            if let lastBackupTime = backupManager.timeSinceLastBackup() {
                                DetailRow(
                                    icon: "clock.arrow.circlepath",
                                    title: "Ultimo backup",
                                    value: lastBackupTime,
                                    color: .blue
                                )
                            }
                            
                            if let lastModificationTime = backupManager.timeSinceLastModification() {
                                DetailRow(
                                    icon: "pencil.circle",
                                    title: "Ultima modifica",
                                    value: lastModificationTime,
                                    color: .orange
                                )
                            }
                        }
                        
                        // Pulsanti azione
                        HStack(spacing: 12) {
                            Button(action: {
                                showingExportSheet = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption)
                                    Text("Esporta Backup")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(backupManager.backupStatus.color)
                                )
                            }
                            
                            if backupManager.backupStatus == .needsBackup {
                                Button(action: {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        isCardVisible = false
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                        Text("Ignora")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backupManager.backupStatus.color.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(backupManager.backupStatus.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .sheet(isPresented: $showingExportSheet) {
                SimpleBackupExporter { success in
                    if success {
                        // Nasconde la card dopo un backup riuscito
                        withAnimation(.easeOut(duration: 0.5)) {
                            isCardVisible = false
                        }
                        // Aggiorna lo stato
                        backupManager.markBackupExported()
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Backup Exporter SUPER SEMPLIFICATO
struct SimpleBackupExporter: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedData: Data?
    @State private var errorMessage: String?
    
    let onCompletion: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if isExporting {
                    // Vista caricamento
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Creazione backup...")
                            .font(.headline)
                    }
                } else if exportedData != nil {
                    // Vista successo
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Backup Pronto!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Button("Condividi") {
                            showingShareSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                } else {
                    // Vista iniziale
                    VStack(spacing: 20) {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Esporta Backup")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Button("Crea Backup") {
                            startExport()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        onCompletion(exportedData != nil)
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
        .onAppear {
            // Auto-start solo se necessario
            if !isExporting && exportedData == nil {
                startExport()
            }
        }
    }
    
    private func startExport() {
        guard !isExporting else { return }
        
        isExporting = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try BackupManager.exportData(from: self.viewContext)
                
                DispatchQueue.main.async {
                    self.exportedData = data
                    self.isExporting = false
                    print("✅ Backup esportato con successo")
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.errorMessage = "Errore: \(error.localizedDescription)"
                    print("❌ Errore esportazione: \(error)")
                }
            }
        }
    }
}

// MARK: - Backup Status Badge per SettingsView
struct BackupStatusBadge: View {
    @StateObject private var backupManager = BackupStatusManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: backupManager.backupStatus.icon)
                .font(.caption)
                .foregroundColor(backupManager.backupStatus.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(backupManager.backupStatus.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(backupManager.backupStatus.color)
                
                if let timeSince = backupManager.timeSinceLastBackup() {
                    Text("Ultimo backup: \(timeSince)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Nessun backup presente")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backupManager.backupStatus.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(backupManager.backupStatus.color.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            backupManager.checkBackupStatus()
        }
    }
}

// NOTA: BackupShareSheet è già definito in SettingsView.swift, quindi non lo ridefinisco qui
