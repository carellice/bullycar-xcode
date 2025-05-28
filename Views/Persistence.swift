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

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Usa NSPersistentContainer normale (senza CloudKit)
        container = NSPersistentContainer(name: "BullyCar")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            print("✅ Core Data caricato (solo locale)")
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // Funzione per salvare il contesto
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
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
                try container.viewContext.save()
                print("✅ Tutti i dati eliminati")
            } catch {
                print("❌ Errore eliminazione dati: \(error)")
            }
        }
    }
}
