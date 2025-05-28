import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Dati di esempio per preview
        for i in 0..<3 {
            let newCar = Car(context: viewContext)
            newCar.id = UUID()
            newCar.name = "Auto \(i + 1)"
            newCar.brand = ["Fiat", "BMW", "Audi"][i]
            newCar.model = ["Panda", "Serie 3", "A4"][i]
            newCar.year = 2020 + Int32(i)
            newCar.plate = "AB\(100 + i)CD"
            newCar.mileage = Int32(10000 * (i + 1))
            newCar.registrationDate = Date()
            newCar.addDate = Date()
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        // Usa NSPersistentCloudKitContainer invece di NSPersistentContainer
        container = NSPersistentCloudKitContainer(name: "BullyCar")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configura per CloudKit
            container.persistentStoreDescriptions.forEach { storeDescription in
                // Abilita la sincronizzazione remota
                storeDescription.setOption(true as NSNumber,
                                         forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber,
                                         forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                
                // Configura CloudKit
                storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.com.tuonome.BullyCar" // SOSTITUISCI con il tuo ID
                )
                
                // Log per debug
                print("🔵 CloudKit Container ID: \(storeDescription.cloudKitContainerOptions?.containerIdentifier ?? "none")")
            }
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            print("🔵 Core Data store loaded successfully")
            print("🔵 Store URL: \(storeDescription.url?.absoluteString ?? "unknown")")
            print("🔵 Store Type: \(storeDescription.type)")
            
            // Verifica se CloudKit è attivo
            if let cloudKitContainerOptions = storeDescription.cloudKitContainerOptions {
                print("✅ CloudKit container: \(cloudKitContainerOptions.containerIdentifier)")
                
                // Determina l'ambiente
                #if DEBUG
                print("📱 CloudKit Environment: Development (Debug build)")
                #else
                print("📱 CloudKit Environment: Production (Release build)")
                #endif
            } else {
                print("⚠️ CloudKit NOT configured")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configura per sincronizzazione CloudKit
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            print("Errore impostazione query generation: \(error)")
        }
    }
    
    // Funzione per salvare il contesto
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Salvataggio completato")
            } catch {
                let nsError = error as NSError
                print("❌ Errore salvataggio: \(nsError)")
                print("❌ Dettagli: \(nsError.userInfo)")
                
                // Non fare crash in produzione, mostra errore all'utente
                if let reason = nsError.userInfo["reason"] as? String {
                    print("❌ Motivo: \(reason)")
                }
            }
        }
    }
    
    // Funzione per eliminare tutti i dati
    func deleteAllData() {
        let entities = container.managedObjectModel.entities
        
        for entity in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try container.viewContext.execute(deleteRequest)
                try container.viewContext.save()
            } catch {
                print("Errore eliminazione dati: \(error)")
            }
        }
    }
}
