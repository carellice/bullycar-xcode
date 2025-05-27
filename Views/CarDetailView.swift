import SwiftUI

struct CarDetailView: View {
    @ObservedObject var car: Car
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @State private var showingEditCar = false
    @State private var showingDeleteAlert = false
    @State private var showingAddMaintenance = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header con immagine
                carImageHeader
                
                // Info auto
                carInfoSection
                
                // Tab per manutenzione, documenti, promemoria, note
                tabSection
            }
        }
        .navigationTitle(car.name ?? "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingEditCar = true }) {
                        Label("Modifica", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Elimina", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditCar) {
            AddCarView(carToEdit: car)
        }
        .sheet(isPresented: $showingAddMaintenance) {
            AddMaintenanceView(car: car)
        }
        .alert("Elimina auto", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                deleteCar()
            }
        } message: {
            Text("Sei sicuro di voler eliminare questa auto? Questa azione non può essere annullata.")
        }
    }
    
    var carImageHeader: some View {
        ZStack {
            if let imageData = car.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 250)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 250)
                    .overlay(
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    var carInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                InfoItem(title: "Marca", value: car.brand ?? "")
                Divider()
                InfoItem(title: "Modello", value: car.model ?? "")
            }
            
            HStack {
                InfoItem(title: "Anno", value: String(car.year))
                Divider()
                InfoItem(title: "Targa", value: car.plate ?? "")
            }
            
            HStack {
                InfoItem(title: "Immatricolazione",
                        value: car.registrationDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                Divider()
                InfoItem(title: "Chilometraggio", value: "\(car.mileage) km")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    var tabSection: some View {
        VStack {
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Manutenzione").tag(0)
                Text("Documenti").tag(1)
                Text("Promemoria").tag(2)
                Text("Note").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Tab content
            switch selectedTab {
            case 0:
                MaintenanceListView(car: car, showingAddMaintenance: $showingAddMaintenance)
            case 1:
                DocumentsListView(car: car)
            case 2:
                RemindersListView(car: car)
            case 3:
                NotesView(car: car)
            default:
                EmptyView()
            }
        }
    }
    
    private func deleteCar() {
        viewContext.delete(car)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Errore eliminazione auto: \(error)")
        }
    }
}

// Vista per le note dell'auto
struct NotesView: View {
    @ObservedObject var car: Car
    @State private var isEditing = false
    @State private var tempNotes = ""
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var isTextEditorFocused: Bool
    @State private var characterCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                // Modalità modifica
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: {
                            tempNotes = car.notes ?? ""
                            isEditing = false
                            isTextEditorFocused = false
                        }) {
                            Text("Annulla")
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Text("Modifica Note")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { saveNotes() }) {
                            Text("Salva")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .disabled(tempNotes == (car.notes ?? ""))
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    
                    Divider()
                    
                    // Editor area
                    ZStack(alignment: .topLeading) {
                        // Placeholder
                        if tempNotes.isEmpty {
                            Text("Scrivi le tue note qui...\n\nPuoi annotare:\n• Dove hai parcheggiato\n• Problemi da controllare\n• Contatti del meccanico\n• Prossimi interventi programmati\n• Qualsiasi informazione utile")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        
                        // Text Editor
                        TextEditor(text: $tempNotes)
                            .padding(4)
                            .focused($isTextEditorFocused)
                            .onChange(of: tempNotes) { newValue in
                                characterCount = newValue.count
                            }
                            .frame(minHeight: 300) // Altezza minima fissa
                    }
                    .font(.body)
                    .background(Color(UIColor.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(UIColor.separator), lineWidth: 0.5)
                    )
                    .padding()
                    
                    // Contatore caratteri
                    HStack {
                        Spacer()
                        Text("\(characterCount) caratteri")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Suggerimenti rapidi
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickNotes, id: \.self) { note in
                                Button(action: {
                                    if !tempNotes.isEmpty {
                                        tempNotes += "\n"
                                    }
                                    tempNotes += note
                                }) {
                                    Text(note)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(15)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
                .background(Color(UIColor.systemGroupedBackground))
                .onAppear {
                    characterCount = tempNotes.count
                    // Attiva automaticamente la tastiera
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isTextEditorFocused = true
                    }
                }
            } else {
                // Modalità visualizzazione
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let notes = car.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "note.text")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                    
                                    Text("Le mie note")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text("\(notes.count) caratteri")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                
                                Text(notes)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                            )
                        } else {
                            // Empty state
                            VStack(spacing: 20) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "note.text")
                                        .font(.system(size: 35))
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(spacing: 8) {
                                    Text("Nessuna nota")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    
                                    Text("Aggiungi note per ricordare informazioni importanti su questa auto")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                Button(action: {
                                    tempNotes = car.notes ?? ""
                                    isEditing = true
                                }) {
                                    Label("Aggiungi note", systemImage: "square.and.pencil")
                                        .font(.body)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(25)
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Floating Action Button per modifica
                if car.notes != nil && !car.notes!.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                tempNotes = car.notes ?? ""
                                isEditing = true
                            }) {
                                Image(systemName: "pencil")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(Color.blue))
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .onAppear {
            tempNotes = car.notes ?? ""
        }
    }
    
    private let quickNotes = [
        "📍 Parcheggiata in: ",
        "⚠️ Da controllare: ",
        "📅 Prossimo appuntamento: ",
        "🔧 Problema: ",
        "✅ Fatto: "
    ]
    
    private func saveNotes() {
        withAnimation {
            car.notes = tempNotes.isEmpty ? nil : tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            
            do {
                try viewContext.save()
                isEditing = false
                isTextEditorFocused = false
            } catch {
                print("Errore salvataggio note: \(error)")
            }
        }
    }
}

// Componente per info singola
struct InfoItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Vista lista manutenzioni
struct MaintenanceListView: View {
    @ObservedObject var car: Car
    @Binding var showingAddMaintenance: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var maintenanceToDelete: Maintenance?
    @State private var showingDeleteAlert = false
    
    var maintenances: [Maintenance] {
        let set = car.maintenances as? Set<Maintenance> ?? []
        return set.sorted {
            $0.date ?? Date() > $1.date ?? Date()
        }
    }
    
    var body: some View {
        VStack {
            if maintenances.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Nessun intervento registrato")
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingAddMaintenance = true }) {
                        Label("Aggiungi intervento", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 40)
            } else {
                Button(action: { showingAddMaintenance = true }) {
                    Label("Aggiungi intervento", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                
                ForEach(maintenances) { maintenance in
                    MaintenanceRowView(
                        maintenance: maintenance,
                        onDelete: {
                            maintenanceToDelete = maintenance
                            showingDeleteAlert = true
                        }
                    )
                    .padding(.horizontal)
                }
            }
        }
        .alert("Elimina intervento", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                if let maintenance = maintenanceToDelete {
                    deleteMaintenance(maintenance)
                }
            }
        } message: {
            Text("Sei sicuro di voler eliminare questo intervento? Questa azione non può essere annullata.")
        }
    }
    
    private func deleteMaintenance(_ maintenance: Maintenance) {
        // Se c'è un promemoria associato, eliminalo
        if let reminder = maintenance.reminder {
            viewContext.delete(reminder)
        }
        
        // Elimina l'intervento
        viewContext.delete(maintenance)
        
        do {
            try viewContext.save()
        } catch {
            print("Errore eliminazione intervento: \(error)")
        }
    }
}

// Riga singola manutenzione
struct MaintenanceRowView: View {
    let maintenance: Maintenance
    let onDelete: () -> Void
    @State private var showingEditMaintenance = false
    
    var maintenanceTypeName: String {
        switch maintenance.type {
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
            return maintenance.customType ?? "Personalizzato"
        default:
            return maintenance.type ?? ""
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(maintenanceTypeName)
                        .font(.headline)
                    
                    Text(maintenance.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("€ \(maintenance.cost, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text("\(maintenance.mileage) km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Menu con opzioni
                Menu {
                    Button(action: { showingEditMaintenance = true }) {
                        Label("Modifica", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Elimina", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            if let notes = maintenance.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Mostra info promemoria se presente
            if let reminder = maintenance.reminder {
                HStack {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text(getReminderText(reminder))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .contextMenu {
            Button(action: { showingEditMaintenance = true }) {
                Label("Modifica", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Elimina", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditMaintenance) {
            if let car = maintenance.car {
                AddMaintenanceView(car: car, maintenanceToEdit: maintenance)
            }
        }
    }
    
    private func getReminderText(_ reminder: Reminder) -> String {
        switch reminder.type {
        case "date":
            if let date = reminder.date {
                return "Prossimo: \(date.formatted(date: .abbreviated, time: .omitted))"
            }
        case "interval":
            if reminder.intervalValue > 0, let unit = reminder.intervalUnit {
                let unitText = unit == "months" ? "mesi" : "anni"
                return "Ogni \(reminder.intervalValue) \(unitText)"
            }
        case "mileage":
            if reminder.mileage > 0 {
                return "A \(reminder.mileage) km"
            }
        case "both":
            var text = ""
            if let date = reminder.date {
                text = "Prossimo: \(date.formatted(date: .abbreviated, time: .omitted))"
            }
            if reminder.mileage > 0 {
                text += " o \(reminder.mileage) km"
            }
            return text
        default:
            break
        }
        return "Promemoria impostato"
    }
}

// Vista lista documenti
struct DocumentsListView: View {
    @ObservedObject var car: Car
    @State private var showingDocumentPicker = false
    @State private var showingImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingActionSheet = false
    @Environment(\.managedObjectContext) private var viewContext
    
    var documents: [Document] {
        let set = car.documents as? Set<Document> ?? []
        return set.sorted {
            ($0.dateAdded ?? Date.distantPast) > ($1.dateAdded ?? Date.distantPast)
        }
    }
    
    var body: some View {
        VStack {
            if documents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Nessun documento salvato")
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingActionSheet = true }) {
                        Label("Aggiungi documento", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 40)
            } else {
                Button(action: { showingActionSheet = true }) {
                    Label("Aggiungi documento", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(documents) { document in
                            DocumentRowView(document: document, car: car)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Aggiungi documento"),
                buttons: [
                    .default(Text("Scatta foto")) {
                        imageSourceType = .camera
                        showingImagePicker = true
                    },
                    .default(Text("Scegli dalla libreria")) {
                        imageSourceType = .photoLibrary
                        showingImagePicker = true
                    },
                    .default(Text("Importa PDF")) {
                        showingDocumentPicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: .constant(nil), sourceType: imageSourceType) { image in
                if let image = image {
                    saveImageAsDocument(image)
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                saveDocumentFromURL(url)
            }
        }
    }
    
    private func saveImageAsDocument(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let document = Document(context: viewContext)
        document.id = UUID()
        document.name = "Foto_\(Date().formatted(date: .abbreviated, time: .omitted))"
        document.type = "image/jpeg"
        document.size = Int64(imageData.count)
        document.data = imageData
        document.dateAdded = Date()
        document.car = car
        
        do {
            try viewContext.save()
        } catch {
            print("Errore salvataggio documento: \(error)")
        }
    }
    
    private func saveDocumentFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            
            let document = Document(context: viewContext)
            document.id = UUID()
            document.name = url.lastPathComponent
            document.type = url.pathExtension == "pdf" ? "application/pdf" : "application/octet-stream"
            document.size = Int64(data.count)
            document.data = data
            document.dateAdded = Date()
            document.car = car
            
            try viewContext.save()
        } catch {
            print("Errore importazione documento: \(error)")
        }
    }
}

// Vista per singolo documento
struct DocumentRowView: View {
    let document: Document
    let car: Car
    @State private var showingDeleteAlert = false
    @State private var showingDocument = false
    @Environment(\.managedObjectContext) private var viewContext
    
    var fileIcon: String {
        if document.type?.contains("image") == true {
            return "photo"
        } else if document.type == "application/pdf" {
            return "doc.text"
        } else {
            return "doc"
        }
    }
    
    var fileSizeText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: document.size)
    }
    
    var body: some View {
        HStack {
            Image(systemName: fileIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name ?? "Documento")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(fileSizeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(document.dateAdded?.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { showingDeleteAlert = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .onTapGesture {
            showingDocument = true
        }
        .alert("Elimina documento", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                deleteDocument()
            }
        } message: {
            Text("Sei sicuro di voler eliminare questo documento?")
        }
        .sheet(isPresented: $showingDocument) {
            DocumentViewerView(document: document)
        }
    }
    
    private func deleteDocument() {
        viewContext.delete(document)
        
        do {
            try viewContext.save()
        } catch {
            print("Errore eliminazione documento: \(error)")
        }
    }
}

// Vista lista promemoria
struct RemindersListView: View {
    @ObservedObject var car: Car
    @State private var showOnlyActive = true
    
    var reminders: [(maintenance: Maintenance, reminder: Reminder, status: ReminderStatus)] {
        let set = car.maintenances as? Set<Maintenance> ?? []
        let maintenances = set.sorted {
            ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast)
        }
        var remindersList: [(Maintenance, Reminder, ReminderStatus)] = []
        
        for maintenance in maintenances {
            if let reminder = maintenance.reminder {
                let status = getReminderStatus(reminder, carMileage: car.mileage)
                if !showOnlyActive || status != .completed {
                    remindersList.append((maintenance, reminder, status))
                }
            }
        }
        
        // Ordina per urgenza
        return remindersList.sorted { first, second in
            if first.2.priority != second.2.priority {
                return first.2.priority < second.2.priority
            }
            
            // Se hanno la stessa priorità, ordina per data
            let firstDate = first.1.date ?? Date.distantFuture
            let secondDate = second.1.date ?? Date.distantFuture
            return firstDate < secondDate
        }
    }
    
    var body: some View {
        VStack {
            // Toggle per mostrare solo promemoria attivi
            Toggle("Mostra solo promemoria attivi", isOn: $showOnlyActive)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            if reminders.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: showOnlyActive ? "bell.slash" : "bell")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text(showOnlyActive ? "Nessun promemoria attivo" : "Nessun promemoria impostato")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(reminders, id: \.maintenance.id) { item in
                            ReminderCardView(
                                maintenance: item.maintenance,
                                reminder: item.reminder,
                                status: item.status,
                                carMileage: car.mileage
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    func getReminderStatus(_ reminder: Reminder, carMileage: Int32) -> ReminderStatus {
        let today = Date()
        var isExpired = false
        var isNear = false
        var daysRemaining: Int? = nil
        var kmRemaining: Int32? = nil
        
        // Controlla la data
        if let dueDate = reminder.date {
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
            daysRemaining = days
            
            if days < 0 {
                isExpired = true
            } else if days <= 30 {
                isNear = true
            }
        }
        
        // Controlla il chilometraggio
        if reminder.mileage > 0 {
            let kmDiff = reminder.mileage - carMileage
            kmRemaining = kmDiff
            
            if kmDiff < 0 {
                isExpired = true
            } else if kmDiff <= 1000 {
                isNear = true
            }
        }
        
        if isExpired {
            return .expired(daysRemaining: daysRemaining, kmRemaining: kmRemaining)
        } else if isNear {
            return .near(daysRemaining: daysRemaining, kmRemaining: kmRemaining)
        } else {
            return .future(daysRemaining: daysRemaining, kmRemaining: kmRemaining)
        }
    }
}

// Enum per lo stato del promemoria
enum ReminderStatus: Equatable {
    case expired(daysRemaining: Int?, kmRemaining: Int32?)
    case near(daysRemaining: Int?, kmRemaining: Int32?)
    case future(daysRemaining: Int?, kmRemaining: Int32?)
    case completed
    
    var color: Color {
        switch self {
        case .expired:
            return .red
        case .near:
            return .orange
        case .future:
            return .green
        case .completed:
            return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .expired:
            return "exclamationmark.circle.fill"
        case .near:
            return "bell.badge.fill"
        case .future:
            return "bell.fill"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    var priority: Int {
        switch self {
        case .expired:
            return 0
        case .near:
            return 1
        case .future:
            return 2
        case .completed:
            return 3
        }
    }
}

// Vista per singola card promemoria
struct ReminderCardView: View {
    let maintenance: Maintenance
    let reminder: Reminder
    let status: ReminderStatus
    let carMileage: Int32
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: status.icon)
                    .font(.title2)
                    .foregroundColor(status.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(getMaintenanceTypeName(maintenance))
                        .font(.headline)
                    
                    Text("Ultimo: \(maintenance.date?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Dettagli promemoria
            VStack(alignment: .leading, spacing: 8) {
                if let date = reminder.date {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        Text("Scadenza: \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        // Mostra giorni rimanenti
                        if case let .expired(days, _) = status, let days = days {
                            Text("Scaduto da \(abs(days)) giorni")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if case let .near(days, _) = status, let days = days {
                            Text(days == 0 ? "Oggi" : "Tra \(days) giorni")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else if case let .future(days, _) = status, let days = days {
                            Text("Tra \(days) giorni")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                if reminder.mileage > 0 {
                    HStack {
                        Image(systemName: "gauge")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        Text("A: \(reminder.mileage) km")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        // Mostra km rimanenti
                        let kmDiff = reminder.mileage - carMileage
                        if kmDiff < 0 {
                            Text("Superato di \(abs(kmDiff)) km")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("Mancano \(kmDiff) km")
                                .font(.caption)
                                .foregroundColor(kmDiff <= 1000 ? .orange : .green)
                        }
                    }
                }
                
                if reminder.intervalValue > 0, let unit = reminder.intervalUnit {
                    HStack {
                        Image(systemName: "repeat")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        let unitText = unit == "months" ? "mesi" : "anni"
                        Text("Ripete ogni \(reminder.intervalValue) \(unitText)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func getMaintenanceTypeName(_ maintenance: Maintenance) -> String {
        switch maintenance.type {
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
            return maintenance.customType ?? "Personalizzato"
        default:
            return maintenance.type ?? "Intervento"
        }
    }
}
