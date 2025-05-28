import Foundation
import CoreData
import UIKit

struct BackupManager {
    
    // Struttura del backup
    struct BackupData: Codable {
        let version: String
        let exportDate: Date
        let deviceName: String
        let cars: [CarData]
        
        struct CarData: Codable {
            let id: UUID
            let name: String?
            let brand: String?
            let model: String?
            let year: Int32
            let plate: String?
            let mileage: Int32
            let registrationDate: Date?
            let addDate: Date?
            let notes: String?
            let imageData: Data?
            let maintenances: [MaintenanceData]
            let documents: [DocumentData]
        }
        
        struct MaintenanceData: Codable {
            let id: UUID
            let type: String?
            let customType: String?
            let date: Date?
            let mileage: Int32
            let cost: Double
            let notes: String?
            let reminder: ReminderData?
        }
        
        struct ReminderData: Codable {
            let id: UUID
            let type: String?
            let date: Date?
            let mileage: Int32
            let intervalValue: Int32
            let intervalUnit: String?
        }
        
        struct DocumentData: Codable {
            let id: UUID
            let name: String?
            let type: String?
            let size: Int64
            let data: Data?
            let dateAdded: Date?
        }
    }
    
    // Esporta tutti i dati
    static func exportData(from context: NSManagedObjectContext) throws -> Data {
        let fetchRequest: NSFetchRequest<Car> = Car.fetchRequest()
        let cars = try context.fetch(fetchRequest)
        
        var carDataArray: [BackupData.CarData] = []
        
        for car in cars {
            // Esporta manutenzioni
            var maintenanceArray: [BackupData.MaintenanceData] = []
            if let maintenances = car.maintenances as? Set<Maintenance> {
                for maintenance in maintenances {
                    var reminderData: BackupData.ReminderData? = nil
                    
                    if let reminder = maintenance.reminder {
                        reminderData = BackupData.ReminderData(
                            id: reminder.id ?? UUID(),
                            type: reminder.type,
                            date: reminder.date,
                            mileage: reminder.mileage,
                            intervalValue: reminder.intervalValue,
                            intervalUnit: reminder.intervalUnit
                        )
                    }
                    
                    let maintenanceData = BackupData.MaintenanceData(
                        id: maintenance.id ?? UUID(),
                        type: maintenance.type,
                        customType: maintenance.customType,
                        date: maintenance.date,
                        mileage: maintenance.mileage,
                        cost: maintenance.cost,
                        notes: maintenance.notes,
                        reminder: reminderData
                    )
                    maintenanceArray.append(maintenanceData)
                }
            }
            
            // Esporta documenti
            var documentArray: [BackupData.DocumentData] = []
            if let documents = car.documents as? Set<Document> {
                for document in documents {
                    let documentData = BackupData.DocumentData(
                        id: document.id ?? UUID(),
                        name: document.name,
                        type: document.type,
                        size: document.size,
                        data: document.data,
                        dateAdded: document.dateAdded
                    )
                    documentArray.append(documentData)
                }
            }
            
            // Crea i dati dell'auto
            let carData = BackupData.CarData(
                id: car.id ?? UUID(),
                name: car.name,
                brand: car.brand,
                model: car.model,
                year: car.year,
                plate: car.plate,
                mileage: car.mileage,
                registrationDate: car.registrationDate,
                addDate: car.addDate,
                notes: car.notes,
                imageData: car.imageData,
                maintenances: maintenanceArray,
                documents: documentArray
            )
            carDataArray.append(carData)
        }
        
        // Crea il backup completo
        let backup = BackupData(
            version: "1.0",
            exportDate: Date(),
            deviceName: UIDevice.current.name,
            cars: carDataArray
        )
        
        // Codifica in JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try encoder.encode(backup)
    }
    
    // Importa i dati
    static func importData(_ data: Data, to context: NSManagedObjectContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backup = try decoder.decode(BackupData.self, from: data)
        
        // Elimina tutti i dati esistenti (opzionale)
        // PersistenceController.shared.deleteAllData()
        
        // Importa ogni auto
        for carData in backup.cars {
            let car = Car(context: context)
            car.id = carData.id
            car.name = carData.name
            car.brand = carData.brand
            car.model = carData.model
            car.year = carData.year
            car.plate = carData.plate
            car.mileage = carData.mileage
            car.registrationDate = carData.registrationDate
            car.addDate = carData.addDate
            car.notes = carData.notes
            car.imageData = carData.imageData
            
            // Importa manutenzioni
            for maintenanceData in carData.maintenances {
                let maintenance = Maintenance(context: context)
                maintenance.id = maintenanceData.id
                maintenance.type = maintenanceData.type
                maintenance.customType = maintenanceData.customType
                maintenance.date = maintenanceData.date
                maintenance.mileage = maintenanceData.mileage
                maintenance.cost = maintenanceData.cost
                maintenance.notes = maintenanceData.notes
                maintenance.car = car
                
                // Importa promemoria
                if let reminderData = maintenanceData.reminder {
                    let reminder = Reminder(context: context)
                    reminder.id = reminderData.id
                    reminder.type = reminderData.type
                    reminder.date = reminderData.date
                    reminder.mileage = reminderData.mileage
                    reminder.intervalValue = reminderData.intervalValue
                    reminder.intervalUnit = reminderData.intervalUnit
                    maintenance.reminder = reminder
                }
            }
            
            // Importa documenti
            for documentData in carData.documents {
                let document = Document(context: context)
                document.id = documentData.id
                document.name = documentData.name
                document.type = documentData.type
                document.size = documentData.size
                document.data = documentData.data
                document.dateAdded = documentData.dateAdded
                document.car = car
            }
        }
        
        // Salva tutto
        try context.save()
    }
    
    // Crea nome file per il backup
    static func generateBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = formatter.string(from: Date())
        return "BullyCar_Backup_\(dateString).json"
    }
}
