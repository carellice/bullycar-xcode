import Foundation
import CoreData
import SwiftUI

// MARK: - Estensioni per Car Status
extension Car {
    
    enum CarStatus: String, CaseIterable {
        case active = "active"
        case sold = "sold"
        case scrapped = "scrapped"
        
        var displayName: String {
            switch self {
            case .active:
                return "Attiva"
            case .sold:
                return "Venduta"
            case .scrapped:
                return "Rottamata"
            }
        }
        
        var icon: String {
            switch self {
            case .active:
                return "car.fill"
            case .sold:
                return "dollarsign.circle.fill"
            case .scrapped:
                return "trash.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .active:
                return .blue
            case .sold:
                return .green
            case .scrapped:
                return .red
            }
        }
        
        var description: String {
            switch self {
            case .active:
                return "Auto in uso"
            case .sold:
                return "Auto venduta"
            case .scrapped:
                return "Auto rottamata"
            }
        }
    }
    
    // Computed property per lo status
    var carStatus: CarStatus {
        get {
            return CarStatus(rawValue: status ?? "active") ?? .active
        }
        set {
            status = newValue.rawValue
            // Imposta automaticamente la data di vendita/rottamazione
            if newValue != .active && statusDate == nil {
                statusDate = Date()
            } else if newValue == .active {
                statusDate = nil
            }
        }
    }
    
    // Proprietà computed per verificare se l'auto è attiva
    var isActive: Bool {
        return carStatus == .active
    }
    
    // Proprietà computed per verificare se l'auto è venduta o rottamata
    var isInactive: Bool {
        return carStatus != .active
    }
    
    // Formatta la data di cambio status
    var formattedStatusDate: String? {
        guard let date = statusDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.string(from: date)
    }
    
    // Descrizione completa dello status
    var statusDescription: String {
        let baseDescription = carStatus.description
        
        if let dateString = formattedStatusDate, carStatus != .active {
            return "\(baseDescription) il \(dateString)"
        }
        
        return baseDescription
    }
}
