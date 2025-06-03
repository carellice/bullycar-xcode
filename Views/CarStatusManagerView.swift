import SwiftUI
import CoreData

// MARK: - Vista per gestire lo status dell'auto
struct CarStatusManagerView: View {
    @ObservedObject var car: Car
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedStatus: Car.CarStatus
    @State private var statusDate = Date()
    @State private var showingConfirmation = false
    @State private var notes = ""
    
    init(car: Car) {
        self.car = car
        self._selectedStatus = State(initialValue: car.carStatus)
        self._statusDate = State(initialValue: car.statusDate ?? Date())
        self._notes = State(initialValue: car.notes ?? "")
    }
    
    var hasChanges: Bool {
        return selectedStatus != car.carStatus
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Sezione informazioni auto
                Section {
                    HStack {
                        // Immagine auto
                        Group {
                            if let imageData = car.imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "car.fill")
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(car.name ?? "Auto")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("\(car.brand ?? "") \(car.model ?? "")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Targa: \(car.plate ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Status attuale
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: car.carStatus.icon)
                                    .font(.caption)
                                    .foregroundColor(car.carStatus.color)
                                
                                Text(car.carStatus.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(car.carStatus.color)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(car.carStatus.color.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(car.carStatus.color.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            
                            if let statusDescription = car.formattedStatusDate, car.carStatus != .active {
                                Text("dal \(statusDescription)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Sezione cambio status
                Section(header: Text("Cambia Status")) {
                    ForEach(Car.CarStatus.allCases, id: \.self) { status in
                        Button(action: {
                            selectedStatus = status
                            if status != .active && car.carStatus == .active {
                                statusDate = Date()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: status.icon)
                                    .font(.title3)
                                    .foregroundColor(status.color)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(status.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(status.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedStatus == status {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Data quando si cambia status a venduta/rottamata
                if selectedStatus != .active {
                    Section(header: Text("Data \(selectedStatus.displayName.lowercased())")) {
                        DatePicker("Data", selection: $statusDate, displayedComponents: [.date])
                            .environment(\.locale, Locale(identifier: "it_IT"))
                    }
                }
                
                // Note aggiuntive
                Section(header: Text("Note aggiuntive")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                // Informazioni importanti
                if selectedStatus != .active {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Cosa succede quando cambi lo status:")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                StatusChangeInfo(
                                    icon: "archivebox.fill",
                                    text: "L'auto verrà spostata nella sezione \"Auto Archiviate\""
                                )
                                
                                StatusChangeInfo(
                                    icon: "bell.slash.fill",
                                    text: "Tutti i promemoria verranno disattivati"
                                )
                                
                                StatusChangeInfo(
                                    icon: "doc.fill",
                                    text: "Documenti e cronologia manutenzioni verranno conservati"
                                )
                                
                                StatusChangeInfo(
                                    icon: "arrow.clockwise",
                                    text: "Potrai sempre ripristinare l'auto come \"Attiva\""
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else if car.carStatus != .active && selectedStatus == .active {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundColor(.green)
                                Text("Ripristino come auto attiva:")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                StatusChangeInfo(
                                    icon: "car.fill",
                                    text: "L'auto tornerà nella sezione principale"
                                )
                                
                                StatusChangeInfo(
                                    icon: "bell.fill",
                                    text: "I promemoria verranno riattivati"
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Gestisci Auto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        if hasChanges {
                            showingConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(!hasChanges)
                    .fontWeight(hasChanges ? .semibold : .regular)
                }
            }
        }
        .alert("Conferma Modifica", isPresented: $showingConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Conferma") {
                saveStatusChange()
            }
        } message: {
            Text("Sei sicuro di voler cambiare lo status dell'auto a \"\(selectedStatus.displayName)\"?")
        }
    }
    
    private func saveStatusChange() {
        car.carStatus = selectedStatus
        
        if selectedStatus != .active {
            car.statusDate = statusDate
        } else {
            car.statusDate = nil
        }
        
        // Salva le note se presenti
        car.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try DataModificationTracker.saveContext(viewContext)
            
            // Notifica il cambiamento
            NotificationCenter.default.post(
                name: NSNotification.Name("CarStatusChanged"),
                object: car
            )
            
            print("✅ Status auto aggiornato: \(selectedStatus.displayName)")
            dismiss()
            
        } catch {
            print("❌ Errore salvataggio status: \(error)")
        }
    }
}

// MARK: - Componente per le informazioni di cambio status
struct StatusChangeInfo: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}
