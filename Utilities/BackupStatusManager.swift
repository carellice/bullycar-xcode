import Foundation
import SwiftUI

class BackupStatusManager: ObservableObject {
    static let shared = BackupStatusManager()
    
    @Published var backupStatus: BackupStatus = .unknown
    
    enum BackupStatus {
        case upToDate      // Backup aggiornato
        case needsBackup   // Serve nuovo backup
        case neverExported // Mai fatto un backup
        case unknown       // Stato indeterminato
        
        var title: String {
            switch self {
            case .upToDate:
                return "Backup aggiornato"
            case .needsBackup:
                return "Backup consigliato"
            case .neverExported:
                return "Backup non presente"
            case .unknown:
                return "Stato backup"
            }
        }
        
        var message: String {
            switch self {
            case .upToDate:
                return "Il tuo backup è allineato con gli ultimi dati inseriti"
            case .needsBackup:
                return "Hai apportato modifiche dall'ultimo backup. Ti consigliamo di esportare un nuovo backup per proteggere i tuoi dati"
            case .neverExported:
                return "Non hai ancora creato un backup dei tuoi dati. Ti consigliamo di esportarne uno per sicurezza"
            case .unknown:
                return "Verifica lo stato del backup nelle impostazioni"
            }
        }
        
        var icon: String {
            switch self {
            case .upToDate:
                return "checkmark.shield.fill"
            case .needsBackup:
                return "exclamationmark.triangle.fill"
            case .neverExported:
                return "info.circle.fill"
            case .unknown:
                return "questionmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .upToDate:
                return .green
            case .needsBackup:
                return .orange
            case .neverExported:
                return .blue
            case .unknown:
                return .gray
            }
        }
        
        var shouldShowCard: Bool {
            return self == .needsBackup || self == .neverExported
        }
    }
    
    private init() {
        checkBackupStatus()
    }
    
    // SEMPLIFICATO: Funzione che calcola solo lo stato, niente observer automatici
    func checkBackupStatus() {
        let lastExportDate = UserDefaults.standard.double(forKey: "lastExportDate")
        let lastDataModification = UserDefaults.standard.double(forKey: "lastDataModification")
        
        let newStatus: BackupStatus
        
        if lastExportDate == 0 {
            newStatus = .neverExported
        } else if lastDataModification == 0 {
            newStatus = .upToDate
        } else if lastExportDate >= lastDataModification {
            newStatus = .upToDate
        } else {
            newStatus = .needsBackup
        }
        
        DispatchQueue.main.async {
            self.backupStatus = newStatus
            print("📊 Stato backup: \(newStatus)")
        }
    }
    
    func markBackupExported() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastExportDate")
        checkBackupStatus()
        print("✅ Backup esportato - stato aggiornato")
    }
    
    // Calcola il tempo trascorso dall'ultimo backup
    func timeSinceLastBackup() -> String? {
        let lastExportDate = UserDefaults.standard.double(forKey: "lastExportDate")
        guard lastExportDate > 0 else { return nil }
        
        let backupDate = Date(timeIntervalSince1970: lastExportDate)
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.day, .hour], from: backupDate, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1 giorno fa" : "\(days) giorni fa"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 ora fa" : "\(hours) ore fa"
        } else {
            return "Poco fa"
        }
    }
    
    // Calcola il tempo dall'ultima modifica
    func timeSinceLastModification() -> String? {
        let lastModification = UserDefaults.standard.double(forKey: "lastDataModification")
        guard lastModification > 0 else { return nil }
        
        let modificationDate = Date(timeIntervalSince1970: lastModification)
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.day, .hour, .minute], from: modificationDate, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1 giorno fa" : "\(days) giorni fa"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 ora fa" : "\(hours) ore fa"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minuto fa" : "\(minutes) minuti fa"
        } else {
            return "Ora"
        }
    }
}
