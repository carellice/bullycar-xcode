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
            try DataModificationTracker.saveContext(viewContext) // ← CORRETTO
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BullyCar")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configurazione corretta per risolvere il problema di Persistent History
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }
            
            // Abilita la cronologia persistente
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Opzioni aggiuntive per la stabilità
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("⚠️ Errore caricamento Core Data: \(error)")
                print("💡 Prova a resettare il simulatore o eliminare l'app")
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
            print("✅ Core Data caricato correttamente")
        }
        
        // Configurazione del contesto
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Configurazione per la gestione degli errori di concorrenza
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Abilita la notifica automatica delle modifiche remote
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // Funzione per salvare il contesto
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try DataModificationTracker.saveContext(context) // ← CORRETTO
                print("✅ Dati salvati localmente")
            } catch {
                let nsError = error as NSError
                print("❌ Errore salvataggio: \(nsError)")
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
                try DataModificationTracker.saveContext(container.viewContext) // ← CORRETTO
                print("✅ Tutti i dati eliminati")
            } catch {
                print("❌ Errore eliminazione dati: \(error)")
            }
        }
    }
}
