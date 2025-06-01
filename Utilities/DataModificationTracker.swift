import Foundation
import CoreData

class DataModificationTracker {
    static let shared = DataModificationTracker()
    
    private init() {}
    
    // Registra una modifica ai dati
    static func recordDataModification() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastDataModification")
        print("📝 Registrata modifica dati: \(Date().formatted(date: .abbreviated, time: .shortened))")
    }
    
    // Salva il context e registra la modifica
    static func saveContext(_ context: NSManagedObjectContext) throws {
        try context.save()
        recordDataModification()
    }
    
    // Ottieni l'ultima modifica
    static func getLastModification() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: "lastDataModification")
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
}
