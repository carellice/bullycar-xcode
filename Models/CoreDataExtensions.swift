import Foundation
import CoreData

// Estensioni per rendere le entità Core Data conformi a Identifiable
// extension Car: Identifiable { }
// extension Maintenance: Identifiable { }
// extension Reminder: Identifiable { }
// extension Document: Identifiable { }

// Estensione per Car per gestire meglio le relazioni
extension Car {
    var maintenanceArray: [Maintenance] {
        let set = maintenances as? Set<Maintenance> ?? []
        return set.sorted {
            ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast)
        }
    }
    
    var documentsArray: [Document] {
        let set = documents as? Set<Document> ?? []
        return set.sorted {
            ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast)
        }
    }
    
    func addMaintenance(_ maintenance: Maintenance) {
        self.addToMaintenances(maintenance)
    }
    
    func removeMaintenance(_ maintenance: Maintenance) {
        self.removeFromMaintenances(maintenance)
    }
    
    func addDocument(_ document: Document) {
        self.addToDocuments(document)
    }
    
    func removeDocument(_ document: Document) {
        self.removeFromDocuments(document)
    }
}

// Estensione per Maintenance
extension Maintenance {
    var displayType: String {
        switch type {
        case "tagliando":
            return "Tagliando"
        case "revisione":
            return "Revisione"
        case "bollo":
            return "Bollo"
        case "assicurazione":
            return "Assicurazione"
        case "gomme":
            return "Cambio gomme"
        case "custom":
            return customType ?? "Personalizzato"
        default:
            return type ?? "Intervento"
        }
    }
    
    var formattedCost: String {
        return String(format: "€ %.2f", cost)
    }
}

// Estensione per Reminder
extension Reminder {
    var isExpired: Bool {
        guard let date = date else { return false }
        return date < Date()
    }
    
    var daysUntilDue: Int? {
        guard let date = date else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: date)
        return components.day
    }
    
    var formattedReminderText: String {
        var text = ""
        
        switch type {
        case "date":
            if let date = date {
                text = "Scadenza: \(date.formatted(date: .abbreviated, time: .omitted))"
            }
        case "interval":
            if intervalValue > 0, let unit = intervalUnit {
                let unitText = unit == "months" ? "mesi" : "anni"
                text = "Ogni \(intervalValue) \(unitText)"
            }
        case "mileage":
            if mileage > 0 {
                text = "A \(mileage) km"
            }
        case "both":
            if let date = date {
                text = "Scadenza: \(date.formatted(date: .abbreviated, time: .omitted))"
            }
            if mileage > 0 {
                text += text.isEmpty ? "" : " o "
                text += "a \(mileage) km"
            }
        default:
            text = "Promemoria impostato"
        }
        
        return text
    }
}

// Estensione per Document
extension Document {
    var fileIcon: String {
        if type?.contains("image") == true {
            return "photo"
        } else if type == "application/pdf" {
            return "doc.text"
        } else {
            return "doc"
        }
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
