import Foundation
import UserNotifications
import CoreData

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    // Richiede il permesso per le notifiche
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Permesso notifiche concesso")
                } else {
                    print("❌ Permesso notifiche negato")
                }
                
                if let error = error {
                    print("⚠️ Errore permesso notifiche: \(error)")
                }
            }
        }
    }
    
    // Pianifica una notifica per un promemoria
    func scheduleNotification(for reminder: Reminder, maintenance: Maintenance, car: Car) {
        // Ottieni i giorni di preavviso dalle impostazioni
        let reminderDays = UserDefaults.standard.integer(forKey: "reminderDays")
        let advanceDays = reminderDays > 0 ? reminderDays : 7 // Default 7 giorni se non impostato
        
        let content = UNMutableNotificationContent()
        content.title = "Promemoria Manutenzione"
        content.body = createNotificationMessage(for: reminder, maintenance: maintenance, car: car, advanceDays: advanceDays)
        content.sound = .default
        content.badge = 1
        
        // Crea il trigger in base al tipo di promemoria CON preavviso
        guard let trigger = createTrigger(for: reminder, car: car, advanceDays: advanceDays) else {
            print("⚠️ Impossibile creare trigger per promemoria")
            return
        }
        
        let identifier = "reminder_\(reminder.id?.uuidString ?? UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Errore pianificazione notifica: \(error)")
            } else {
                print("✅ Notifica pianificata con \(advanceDays) giorni di preavviso: \(identifier)")
            }
        }
    }
    
    // Rimuove una notifica pianificata
    func removeNotification(for reminder: Reminder) {
        let identifier = "reminder_\(reminder.id?.uuidString ?? UUID().uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Notifica rimossa: \(identifier)")
    }
    
    // Aggiorna tutte le notifiche per un'auto
    func updateNotifications(for car: Car) {
        // Rimuovi tutte le notifiche esistenti per questa auto
        removeAllNotifications(for: car)
        
        // Crea nuove notifiche per tutti i promemoria attivi
        let maintenances = car.maintenanceArray
        for maintenance in maintenances {
            if let reminder = maintenance.reminder {
                scheduleNotification(for: reminder, maintenance: maintenance, car: car)
            }
        }
    }
    
    // Debug: Mostra tutte le notifiche programmate
    func logScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                print("📱 Notifiche programmate: \(requests.count)")
                for request in requests {
                    if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                       let nextTriggerDate = trigger.nextTriggerDate() {
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "it_IT")
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        
                        print("📅 \(request.identifier): \(formatter.string(from: nextTriggerDate))")
                        print("   Contenuto: \(request.content.body)")
                    }
                }
            }
        }
    }
    
    // Rimuove tutte le notifiche per un'auto
    func removeAllNotifications(for car: Car) {
        let maintenances = car.maintenanceArray
        for maintenance in maintenances {
            if let reminder = maintenance.reminder {
                removeNotification(for: reminder)
            }
        }
    }
    
    // Ottieni i promemoria in scadenza e calcola i prossimi interventi
    func getUpcomingReminders(for car: Car, within days: Int = 365) -> [ReminderInfo] {
        var upcomingReminders: [ReminderInfo] = []
        
        // 1. TUTTI i promemoria espliciti (con date/km impostati dall'utente)
        for maintenance in car.maintenanceArray {
            if let reminder = maintenance.reminder {
                let daysUntil = calculateDaysUntilDue(reminder: reminder, car: car)
                let isDue = isReminderDue(reminder: reminder, car: car)
                
                let reminderInfo = ReminderInfo(
                    reminder: reminder,
                    maintenance: maintenance,
                    car: car,
                    daysUntilDue: daysUntil,
                    isDue: isDue,
                    message: createReminderMessage(for: reminder, maintenance: maintenance),
                    isCalculated: false
                )
                
                // Mostra tutti i promemoria espliciti entro il periodo o se scaduti
                if isDue || (daysUntil ?? Int.max) <= days || (daysUntil ?? 0) > -90 {
                    upcomingReminders.append(reminderInfo)
                    print("✅ Aggiunto promemoria esplicito: \(maintenance.displayType), giorni: \(daysUntil ?? 0)")
                }
            }
        }
        
        // 2. Calcola i prossimi interventi SOLO per tipi già esistenti senza promemoria esplicito
        let calculatedReminders = calculateNextMaintenanceIntervals(for: car, within: days, existingReminders: upcomingReminders)
        upcomingReminders.append(contentsOf: calculatedReminders)
        
        print("📊 Totale promemoria trovati: \(upcomingReminders.count)")
        
        // Ordina per urgenza
        return upcomingReminders.sorted { reminder1, reminder2 in
            if reminder1.isDue && !reminder2.isDue { return true }
            if !reminder1.isDue && reminder2.isDue { return false }
            
            guard let days1 = reminder1.daysUntilDue, let days2 = reminder2.daysUntilDue else {
                return reminder1.isDue
            }
            
            return days1 < days2
        }
    }
    
    // Calcola i prossimi interventi SOLO per tipi già esistenti
    private func calculateNextMaintenanceIntervals(for car: Car, within days: Int, existingReminders: [ReminderInfo]) -> [ReminderInfo] {
        var calculatedReminders: [ReminderInfo] = []
        
        // Trova tutti i tipi di manutenzione già fatti
        let performedMaintenanceTypes = Set(car.maintenanceArray.compactMap { $0.type })
        
        // Trova i tipi che hanno già un promemoria esplicito
        let typesWithExplicitReminders = Set(existingReminders.compactMap { $0.maintenanceType })
        
        // Calcola promemoria solo per tipi già eseguiti ma senza promemoria esplicito
        for type in performedMaintenanceTypes {
            if !typesWithExplicitReminders.contains(type) {
                if let nextReminder = calculateNextMaintenanceForType(type, car: car, within: days) {
                    calculatedReminders.append(nextReminder)
                }
            }
        }
        
        return calculatedReminders
    }
    
    private func calculateNextMaintenanceForType(_ type: String, car: Car, within days: Int) -> ReminderInfo? {
        // Trova tutte le manutenzioni di questo tipo
        let maintenancesOfType = car.maintenanceArray.filter { $0.type == type }
        guard !maintenancesOfType.isEmpty else {
            return nil // Non creare più promemoria per tipi mai eseguiti
        }
        
        // Ordina per data
        let sortedMaintenances = maintenancesOfType.sorted {
            ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast)
        }
        
        guard let lastMaintenance = sortedMaintenances.last,
              let lastDate = lastMaintenance.date else { return nil }
        
        // Calcola l'intervallo medio se ci sono multiple manutenzioni
        var averageInterval: TimeInterval = 0
        if sortedMaintenances.count > 1 {
            var totalInterval: TimeInterval = 0
            for i in 1..<sortedMaintenances.count {
                if let prevDate = sortedMaintenances[i-1].date,
                   let currDate = sortedMaintenances[i].date {
                    totalInterval += currDate.timeIntervalSince(prevDate)
                }
            }
            averageInterval = totalInterval / Double(sortedMaintenances.count - 1)
        }
        
        // Se non c'è un pattern, usa intervalli standard
        if averageInterval == 0 {
            averageInterval = getStandardInterval(for: type)
        }
        
        // Calcola la prossima data
        let nextDate = lastDate.addingTimeInterval(averageInterval)
        
        // Verifica se è entro il periodo richiesto
        let daysUntilNext = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
        guard daysUntilNext <= days && daysUntilNext > -30 else { return nil }
        
        // Crea un reminder calcolato SENZA Core Data
        let calculatedReminderData = CalculatedReminderData(
            type: "date",
            date: nextDate,
            mileage: 0,
            intervalValue: 0,
            intervalUnit: nil
        )
        
        // Crea una manutenzione calcolata SENZA Core Data
        let futureMaintenanceData = CalculatedMaintenanceData(
            type: type,
            customType: nil,
            date: nextDate,
            mileage: 0,
            cost: 0.0,
            notes: nil
        )
        
        return ReminderInfo(
            reminder: calculatedReminderData,
            maintenance: futureMaintenanceData,
            car: car,
            daysUntilDue: daysUntilNext,
            isDue: daysUntilNext <= 0,
            message: createCalculatedReminderMessage(type: type, date: nextDate, daysUntil: daysUntilNext),
            isCalculated: true
        )
    }
    
    private func getStandardInterval(for type: String) -> TimeInterval {
        switch type {
        case "tagliando":
            return 365 * 24 * 60 * 60 // 1 anno
        case "revisione":
            return 2 * 365 * 24 * 60 * 60 // 2 anni
        case "bollo":
            return 365 * 24 * 60 * 60 // 1 anno
        case "assicurazione":
            return 365 * 24 * 60 * 60 // 1 anno
        case "gomme":
            return 0.5 * 365 * 24 * 60 * 60 // 6 mesi
        default:
            return 365 * 24 * 60 * 60 // 1 anno di default
        }
    }
    
    // MARK: - Private Methods
    
    private func createTrigger(for reminder: Reminder, car: Car, advanceDays: Int) -> UNNotificationTrigger? {
        switch reminder.type {
        case "date":
            guard let originalDate = reminder.date else { return nil }
            
            // Calcola la data di notifica sottraendo i giorni di preavviso
            let notificationDate = Calendar.current.date(byAdding: .day, value: -advanceDays, to: originalDate) ?? originalDate
            
            // Non inviare notifiche per date passate
            guard notificationDate > Date() else {
                print("⚠️ Data di notifica già passata: \(notificationDate)")
                return nil
            }
            
            // Imposta sempre alle 10:00 del mattino
            let dateComponents = createMorningNotificationComponents(from: notificationDate)
            print("📅 Notifica programmata per: \(dateComponents.day!)/\(dateComponents.month!)/\(dateComponents.year!) alle 10:00 (\(advanceDays) giorni prima di \(originalDate))")
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
        case "interval":
            // Per gli intervalli, calcola la data di scadenza e poi sottrai il preavviso
            guard let maintenance = reminder.maintenance,
                  let maintenanceDate = maintenance.date,
                  reminder.intervalValue > 0,
                  let unit = reminder.intervalUnit else { return nil }
            
            var dateComponent = DateComponents()
            if unit == "months" {
                dateComponent.month = Int(reminder.intervalValue)
            } else if unit == "years" {
                dateComponent.year = Int(reminder.intervalValue)
            }
            
            guard let dueDate = Calendar.current.date(byAdding: dateComponent, to: maintenanceDate) else { return nil }
            
            // Sottrai i giorni di preavviso
            let notificationDate = Calendar.current.date(byAdding: .day, value: -advanceDays, to: dueDate) ?? dueDate
            
            // Non inviare notifiche per date passate
            guard notificationDate > Date() else {
                print("⚠️ Data di notifica intervallo già passata: \(notificationDate)")
                return nil
            }
            
            // Imposta sempre alle 10:00 del mattino
            let dateComponents = createMorningNotificationComponents(from: notificationDate)
            print("📅 Notifica intervallo programmata per: \(dateComponents.day!)/\(dateComponents.month!)/\(dateComponents.year!) alle 10:00 (\(advanceDays) giorni prima di \(dueDate))")
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
        case "mileage":
            // Per il chilometraggio, non possiamo fare preavvisi precisi
            // La notifica si attiva quando l'app viene aperta e controlla i km
            print("⚠️ Notifiche chilometraggio non supportate in background")
            return nil
            
        case "both":
            // Usa la data se disponibile, altrimenti il chilometraggio non è supportato
            guard let originalDate = reminder.date else { return nil }
            
            let notificationDate = Calendar.current.date(byAdding: .day, value: -advanceDays, to: originalDate) ?? originalDate
            
            guard notificationDate > Date() else {
                print("⚠️ Data di notifica 'both' già passata: \(notificationDate)")
                return nil
            }
            
            // Imposta sempre alle 10:00 del mattino
            let dateComponents = createMorningNotificationComponents(from: notificationDate)
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
        default:
            return nil
        }
    }
    
    // Crea i componenti per una notifica alle 10:00 del mattino
    private func createMorningNotificationComponents(from date: Date) -> DateComponents {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        
        // Imposta sempre alle 10:00 del mattino
        dateComponents.hour = 10
        dateComponents.minute = 0
        dateComponents.second = 0
        
        return dateComponents
    }
    
    private func createNotificationMessage(for reminder: Reminder, maintenance: Maintenance, car: Car, advanceDays: Int) -> String {
        let carName = car.name ?? "Auto"
        let maintenanceType = maintenance.displayType
        
        switch reminder.type {
        case "date":
            if let date = reminder.date {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "it_IT")
                formatter.dateStyle = .medium
                
                if advanceDays > 0 {
                    return "Promemoria: \(maintenanceType) per \(carName) previsto tra \(advanceDays) giorni (\(formatter.string(from: date)))"
                } else {
                    return "È tempo di fare \(maintenanceType) per \(carName)"
                }
            }
        case "interval":
            if let maintenance = reminder.maintenance,
               let maintenanceDate = maintenance.date,
               reminder.intervalValue > 0,
               let unit = reminder.intervalUnit {
                
                var dateComponent = DateComponents()
                if unit == "months" {
                    dateComponent.month = Int(reminder.intervalValue)
                } else if unit == "years" {
                    dateComponent.year = Int(reminder.intervalValue)
                }
                
                if let dueDate = Calendar.current.date(byAdding: dateComponent, to: maintenanceDate) {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "it_IT")
                    formatter.dateStyle = .medium
                    
                    if advanceDays > 0 {
                        return "Promemoria: \(maintenanceType) per \(carName) previsto tra \(advanceDays) giorni (\(formatter.string(from: dueDate)))"
                    } else {
                        return "È tempo di fare \(maintenanceType) per \(carName)"
                    }
                }
            }
        case "mileage":
            return "\(carName) ha raggiunto i \(reminder.mileage) km. È tempo di fare \(maintenanceType)"
        case "both":
            if advanceDays > 0 {
                return "Promemoria: \(maintenanceType) per \(carName) in scadenza tra \(advanceDays) giorni"
            } else {
                return "È tempo di fare \(maintenanceType) per \(carName)"
            }
        default:
            break
        }
        
        return "Promemoria manutenzione per \(carName)"
    }
    
    private func createReminderMessage(for reminder: Reminder, maintenance: Maintenance) -> String {
        let maintenanceType = maintenance.displayType
        
        switch reminder.type {
        case "date":
            if let date = reminder.date {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "it_IT")
                formatter.dateStyle = .medium
                return "Scadenza \(maintenanceType): \(formatter.string(from: date))"
            }
        case "interval":
            if let maintenanceDate = maintenance.date,
               reminder.intervalValue > 0,
               let unit = reminder.intervalUnit {
                
                var dateComponent = DateComponents()
                if unit == "months" {
                    dateComponent.month = Int(reminder.intervalValue)
                } else if unit == "years" {
                    dateComponent.year = Int(reminder.intervalValue)
                }
                
                if let nextDate = Calendar.current.date(byAdding: dateComponent, to: maintenanceDate) {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "it_IT")
                    formatter.dateStyle = .medium
                    
                    let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
                    
                    if daysUntil <= 0 {
                        return "\(maintenanceType) scaduto il \(formatter.string(from: nextDate))"
                    } else if daysUntil <= 30 {
                        return "Prossimo \(maintenanceType) tra \(daysUntil) giorni (\(formatter.string(from: nextDate)))"
                    } else {
                        return "Prossimo \(maintenanceType): \(formatter.string(from: nextDate))"
                    }
                }
            }
            return "Prossimo \(maintenanceType) programmato"
        case "mileage":
            return "\(maintenanceType) a \(reminder.mileage) km"
        case "both":
            var message = maintenanceType
            if let date = reminder.date {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "it_IT")
                formatter.dateStyle = .short
                message += " entro \(formatter.string(from: date))"
            }
            if reminder.mileage > 0 {
                message += " o a \(reminder.mileage) km"
            }
            return message
        default:
            break
        }
        
        return maintenanceType
    }
    
    private func createCalculatedReminderMessage(type: String, date: Date, daysUntil: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        
        let typeDisplay = getMaintenanceTypeDisplay(type)
        
        if daysUntil <= 0 {
            return "\(typeDisplay) previsto per il \(formatter.string(from: date))"
        } else if daysUntil <= 7 {
            return "\(typeDisplay) previsto tra \(daysUntil) giorni"
        } else {
            return "\(typeDisplay) previsto per il \(formatter.string(from: date))"
        }
    }
    
    private func getMaintenanceTypeDisplay(_ type: String) -> String {
        switch type {
        case "tagliando": return "Tagliando"
        case "revisione": return "Revisione"
        case "bollo": return "Bollo"
        case "assicurazione": return "Assicurazione"
        case "gomme": return "Cambio gomme"
        default: return "Manutenzione"
        }
    }
    
    private func calculateDaysUntilDue(reminder: Reminder, car: Car) -> Int? {
        switch reminder.type {
        case "date":
            guard let date = reminder.date else { return nil }
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: date)
            return components.day
            
        case "interval":
            // Per gli intervalli, calcola dalla data della manutenzione + intervallo
            guard reminder.intervalValue > 0,
                  let unit = reminder.intervalUnit,
                  let maintenance = reminder.maintenance,
                  let maintenanceDate = maintenance.date else {
                print("❌ Dati mancanti per calcolo intervallo: intervalValue=\(reminder.intervalValue), unit=\(reminder.intervalUnit ?? "nil"), maintenanceDate=\(reminder.maintenance?.date?.description ?? "nil")")
                return nil
            }
            
            var dateComponent = DateComponents()
            if unit == "months" {
                dateComponent.month = Int(reminder.intervalValue)
            } else if unit == "years" {
                dateComponent.year = Int(reminder.intervalValue)
            }
            
            guard let nextDueDate = Calendar.current.date(byAdding: dateComponent, to: maintenanceDate) else {
                print("❌ Impossibile calcolare prossima data per intervallo")
                return nil
            }
            
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: nextDueDate)
            let daysUntil = components.day ?? 0
            
            print("📅 Calcolo intervallo: manutenzione=\(maintenanceDate), intervallo=\(reminder.intervalValue) \(unit), prossima=\(nextDueDate), giorni=\(daysUntil)")
            
            return daysUntil
            
        case "mileage":
            if reminder.mileage > car.mileage {
                // Stima giorni basata su utilizzo medio (ipotizzando 50 km/giorno)
                let kmRemaining = reminder.mileage - car.mileage
                return Int(kmRemaining / 50)
            }
            return 0
            
        case "both":
            let dateDays = reminder.date.map { date in
                Calendar.current.dateComponents([.day], from: Date(), to: date).day
            }
            let mileageDays = reminder.mileage > car.mileage ? Int((reminder.mileage - car.mileage) / 50) : 0
            
            // Restituisci il più piccolo (più urgente)
            if let dateDays = dateDays {
                return min(dateDays ?? 0, mileageDays)
            } else {
                return mileageDays
            }
            
        default:
            return nil
        }
    }
    
    private func isReminderDue(reminder: Reminder, car: Car) -> Bool {
        switch reminder.type {
        case "date":
            guard let date = reminder.date else { return false }
            return date <= Date()
        case "interval":
            // Per gli intervalli, usa calculateDaysUntilDue
            if let days = calculateDaysUntilDue(reminder: reminder, car: car) {
                return days <= 0
            }
            return false
        case "mileage":
            return car.mileage >= reminder.mileage
        case "both":
            let dateDue = reminder.date.map { $0 <= Date() } ?? false
            let mileageDue = car.mileage >= reminder.mileage
            return dateDue || mileageDue
        default:
            return false
        }
    }
}

// Struttura per le informazioni del promemoria
struct ReminderInfo: Identifiable {
    let id = UUID()
    let reminder: Any // Può essere Reminder o CalculatedReminderData
    let maintenance: Any // Può essere Maintenance o CalculatedMaintenanceData
    let car: Car
    let daysUntilDue: Int?
    let isDue: Bool
    let message: String
    let isCalculated: Bool
    
    // Computed properties per accesso sicuro ai dati
    var maintenanceType: String? {
        if let realMaintenance = maintenance as? Maintenance {
            return realMaintenance.type
        } else if let calculatedMaintenance = maintenance as? CalculatedMaintenanceData {
            return calculatedMaintenance.type
        }
        return nil
    }
    
    var maintenanceDisplayType: String {
        if let realMaintenance = maintenance as? Maintenance {
            return realMaintenance.displayType
        } else if let calculatedMaintenance = maintenance as? CalculatedMaintenanceData {
            return calculatedMaintenance.displayType
        }
        return "Manutenzione"
    }
    
    var urgencyLevel: UrgencyLevel {
        if isDue { return .overdue }
        guard let days = daysUntilDue else { return .low }
        if days <= 30 { return .high }      // Urgenti: 1-30 giorni
        if days <= 90 { return .medium }    // Medi: 31-90 giorni
        return .low                         // Bassi: oltre 90 giorni
    }
    
    var urgencyColor: String {
        switch urgencyLevel {
        case .overdue: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "green"
        }
    }
}

enum UrgencyLevel {
    case overdue, high, medium, low
}

// Strutture dati per promemoria calcolati (NON Core Data)
struct CalculatedReminderData {
    let id = UUID()
    let type: String?
    let date: Date?
    let mileage: Int32
    let intervalValue: Int32
    let intervalUnit: String?
}

struct CalculatedMaintenanceData {
    let id = UUID()
    let type: String?
    let customType: String?
    let date: Date?
    let mileage: Int32
    let cost: Double
    let notes: String?
    
    var displayType: String {
        switch type {
        case "tagliando": return "Tagliando"
        case "revisione": return "Revisione"
        case "bollo": return "Bollo"
        case "assicurazione": return "Assicurazione"
        case "gomme": return "Cambio gomme"
        case "custom": return customType ?? "Personalizzato"
        default: return type ?? "Intervento"
        }
    }
}
