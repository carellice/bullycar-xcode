import SwiftUI

struct AddMaintenanceView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let car: Car
    var maintenanceToEdit: Maintenance?
    
    // Stati del form
    @State private var maintenanceType = "tagliando"
    @State private var customType = ""
    @State private var date = Date()
    @State private var mileage = ""
    @State private var cost = ""
    @State private var notes = ""
    @State private var enableReminder = false
    @State private var reminderType = "date" // date, interval, mileage, both
    @State private var reminderDate = Date()
    @State private var reminderMileage = ""
    @State private var intervalValue = 1
    @State private var intervalUnit = "months" // months, years
    
    let maintenanceTypes = [
        ("tagliando", "Tagliando"),
        ("revisione", "Revisione"),
        ("bollo", "Bollo"),
        ("assicurazione", "Assicurazione"),
        ("gomme", "Cambio gomme"),
        ("custom", "Personalizzato")
    ]
    
    let reminderTypes = [
        ("date", "Data specifica"),
        ("interval", "Intervallo di tempo"),
        ("mileage", "Chilometraggio"),
        ("both", "Data e chilometraggio")
    ]
    
    var isEditing: Bool {
        maintenanceToEdit != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Tipo di intervento
                Section(header: Text("Tipo di intervento")) {
                    Picker("Tipo", selection: $maintenanceType) {
                        ForEach(maintenanceTypes, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: maintenanceType) { newValue in
                        // Solo per nuovi interventi, imposta promemoria automatici
                        if maintenanceToEdit == nil {
                            setupAutoRemindersForType(newValue)
                        }
                    }
                    
                    if maintenanceType == "custom" {
                        TextField("Nome intervento personalizzato", text: $customType)
                    }
                }
                
                // Dettagli intervento
                Section(header: Text("Dettagli")) {
                    DatePicker("Data intervento", selection: $date, displayedComponents: [.date])
                        .environment(\.locale, Locale(identifier: "it_IT")) // Forza italiano
                    
                    HStack {
                        Text("Chilometraggio")
                        Spacer()
                        TextField("km", text: $mileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Costo")
                        Spacer()
                        TextField("€", text: $cost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                // Note
                Section(header: Text("Note")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                // Promemoria
                Section(header: Text("Promemoria prossimo intervento")) {
                    Toggle("Imposta promemoria", isOn: $enableReminder)
                    
                    if enableReminder {
                        Picker("Tipo di promemoria", selection: $reminderType) {
                            ForEach(reminderTypes, id: \.0) { type in
                                Text(type.1).tag(type.0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        // Mostra campi in base al tipo di promemoria
                        if reminderType == "date" || reminderType == "both" {
                            DatePicker("Data prossimo intervento",
                                     selection: $reminderDate,
                                     in: Date()...,
                                     displayedComponents: [.date])
                                .environment(\.locale, Locale(identifier: "it_IT")) // Forza italiano
                        }
                        
                        if reminderType == "interval" {
                            HStack {
                                Text("Ripeti ogni")
                                
                                Picker("", selection: $intervalValue) {
                                    ForEach(1...24, id: \.self) { value in
                                        Text("\(value)").tag(value)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 60)
                                
                                Picker("", selection: $intervalUnit) {
                                    Text("mesi").tag("months")
                                    Text("anni").tag("years")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                        }
                        
                        if reminderType == "mileage" || reminderType == "both" {
                            HStack {
                                Text("Chilometraggio prossimo intervento")
                                Spacer()
                                TextField("km", text: $reminderMileage)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifica intervento" : "Nuovo intervento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        saveMaintenance()
                    }
                    .disabled(maintenanceType == "custom" && customType.isEmpty)
                }
            }
        }
        .environment(\.locale, Locale.current) // Localizzazione per tutta la vista
        .onAppear {
            setupInitialData()
        }
    }
    
    private func setupInitialData() {
        // Precompila con chilometraggio attuale
        mileage = String(car.mileage)
        
        if let maintenance = maintenanceToEdit {
            // Popola i campi se stiamo modificando
            maintenanceType = maintenance.type ?? "tagliando"
            customType = maintenance.customType ?? ""
            date = maintenance.date ?? Date()
            mileage = String(maintenance.mileage)
            cost = String(format: "%.2f", maintenance.cost)
            notes = maintenance.notes ?? ""
            
            if let reminder = maintenance.reminder {
                enableReminder = true
                reminderType = reminder.type ?? "date"
                reminderDate = reminder.date ?? Date()
                reminderMileage = String(reminder.mileage ?? 0)
                intervalValue = Int(reminder.intervalValue ?? 1)
                intervalUnit = reminder.intervalUnit ?? "months"
            }
        }
        
        // Imposta automaticamente i promemoria per revisione e bollo
        if maintenanceToEdit == nil {
            setupAutoRemindersForType(maintenanceType)
        }
    }
    
    private func setupAutoRemindersForType(_ type: String) {
        switch type {
        case "revisione":
            enableReminder = true
            reminderType = "interval"
            intervalValue = 2
            intervalUnit = "years"
        case "bollo":
            enableReminder = true
            reminderType = "interval"
            intervalValue = 1
            intervalUnit = "years"
        case "tagliando":
            enableReminder = true
            reminderType = "interval"
            intervalValue = 1
            intervalUnit = "years"
        case "assicurazione":
            enableReminder = true
            reminderType = "interval"
            intervalValue = 1
            intervalUnit = "years"
        case "gomme":
            enableReminder = true
            reminderType = "interval"
            intervalValue = 6
            intervalUnit = "months"
        default:
            // Per custom o altri, lascia le impostazioni attuali
            break
        }
    }
    
    private func calculateReminderDate() -> Date? {
        if reminderType == "interval" {
            var dateComponent = DateComponents()
            if intervalUnit == "months" {
                dateComponent.month = intervalValue
            } else {
                dateComponent.year = intervalValue
            }
            return Calendar.current.date(byAdding: dateComponent, to: date)
        }
        return nil
    }
    
    private func saveMaintenance() {
        withAnimation {
            let maintenance: Maintenance
            
            if let maintenanceToEdit = maintenanceToEdit {
                maintenance = maintenanceToEdit
            } else {
                maintenance = Maintenance(context: viewContext)
                maintenance.id = UUID()
            }
            
            // Assegna sempre la relazione con l'auto
            maintenance.car = car
            
            // Salva i dati base
            maintenance.type = maintenanceType
            maintenance.customType = maintenanceType == "custom" ? customType : nil
            maintenance.date = date
            maintenance.mileage = Int32(mileage) ?? 0
            maintenance.cost = Double(cost.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            maintenance.notes = notes.isEmpty ? nil : notes
            
            // Gestione promemoria
            if enableReminder {
                let reminder: Reminder
                if let existingReminder = maintenance.reminder {
                    reminder = existingReminder
                } else {
                    reminder = Reminder(context: viewContext)
                    reminder.id = UUID()
                }
                
                reminder.type = reminderType
                
                // Salva i dati del promemoria in base al tipo
                switch reminderType {
                case "date":
                    reminder.date = reminderDate
                    reminder.mileage = 0
                    reminder.intervalValue = 0
                    reminder.intervalUnit = nil
                    
                case "interval":
                    reminder.date = calculateReminderDate()
                    reminder.intervalValue = Int32(intervalValue)
                    reminder.intervalUnit = intervalUnit
                    reminder.mileage = 0
                    
                case "mileage":
                    reminder.date = nil
                    reminder.mileage = Int32(reminderMileage) ?? 0
                    reminder.intervalValue = 0
                    reminder.intervalUnit = nil
                    
                case "both":
                    reminder.date = reminderDate
                    reminder.mileage = Int32(reminderMileage) ?? 0
                    reminder.intervalValue = 0
                    reminder.intervalUnit = nil
                    
                default:
                    break
                }
                
                maintenance.reminder = reminder
                
            } else if let existingReminder = maintenance.reminder {
                // Rimuovi promemoria se disabilitato
                viewContext.delete(existingReminder)
                maintenance.reminder = nil
            }
            
            // Aggiorna chilometraggio auto se necessario
            if let currentMileage = Int32(mileage), currentMileage > car.mileage {
                car.mileage = currentMileage
            }
            
            do {
                try DataModificationTracker.saveContext(viewContext)
                print("✅ Manutenzione salvata")
                
                // Aggiorna le notifiche per questa auto
                NotificationManager.shared.updateNotifications(for: car)
                
                // PRIMA chiudi la vista con animazione fluida
                dismiss()
                
                // POI invia la notifica con un piccolo delay
                // per permettere all'animazione di completarsi
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("MaintenanceDataChanged"),
                        object: nil
                    )
                    print("📡 Notifica MaintenanceDataChanged inviata dopo chiusura")
                }
                
            } catch {
                print("❌ Errore nel salvataggio: \(error)")
            }
        }
    }
}
