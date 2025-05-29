import SwiftUI

struct CarDetailView: View {
    @ObservedObject var car: Car
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @State private var showingEditCar = false
    @State private var showingDeleteAlert = false
    @State private var showingAddMaintenance = false
    @State private var showingCopyFeedback = false
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
        // Toast per feedback copia targa
        .overlay(
            copyFeedbackToast,
            alignment: .top
        )
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
                // Targa copiabile
                CopyableInfoItem(
                    title: "Targa",
                    value: car.plate ?? "",
                    onCopy: {
                        copyPlateNumber()
                    }
                )
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
    
    // Toast di feedback per la copia
    var copyFeedbackToast: some View {
        Group {
            if showingCopyFeedback {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    Text("Targa copiata negli appunti")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.top, 10)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
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
                MaintenanceTabView(car: car, showingAddMaintenance: $showingAddMaintenance)
            case 1:
                DocumentsTabView(car: car)
            case 2:
                RemindersTabView(car: car)
            case 3:
                NotesTabView(car: car)
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
    
    private func copyPlateNumber() {
        guard let plate = car.plate, !plate.isEmpty else { return }
        
        // Copia negli appunti
        UIPasteboard.general.string = plate
        
        // Mostra feedback
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showingCopyFeedback = true
        }
        
        // Nascondi feedback dopo 2 secondi
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingCopyFeedback = false
            }
        }
        
        // Feedback aptico
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        print("📋 Targa copiata: \(plate)")
    }
}

// MARK: - Tab Views

struct MaintenanceTabView: View {
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
        if let reminder = maintenance.reminder {
            viewContext.delete(reminder)
        }
        viewContext.delete(maintenance)
        
        do {
            try viewContext.save()
        } catch {
            print("Errore eliminazione intervento: \(error)")
        }
    }
}

struct MaintenanceRowView: View {
    let maintenance: Maintenance
    let onDelete: () -> Void
    @State private var showingEditMaintenance = false
    
    var maintenanceTypeName: String {
        switch maintenance.type {
        case "tagliando": return "Tagliando"
        case "revisione": return "Revisione"
        case "bollo": return "Bollo"
        case "assicurazione": return "Assicurazione"
        case "gomme": return "Cambio gomme"
        case "custom": return maintenance.customType ?? "Personalizzato"
        default: return maintenance.type ?? ""
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
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .sheet(isPresented: $showingEditMaintenance) {
            if let car = maintenance.car {
                AddMaintenanceView(car: car, maintenanceToEdit: maintenance)
            }
        }
    }
}

struct DocumentsTabView: View {
    @ObservedObject var car: Car
    @State private var showingDocumentPicker = false
    @State private var showingImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingActionSheet = false
    @State private var showingNameDialog = false
    @State private var pendingDocumentData: (data: Data, type: String, originalName: String)?
    @State private var documentName = ""
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
                            DocumentRowView(document: document)
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
                    handleImageSelection(image)
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                handleDocumentSelection(url)
            }
        }
        .alert("Nome documento", isPresented: $showingNameDialog) {
            TextField("Nome documento", text: $documentName)
                .textInputAutocapitalization(.words)
            
            Button("Annulla", role: .cancel) {
                pendingDocumentData = nil
                documentName = ""
            }
            
            Button("Salva") {
                saveDocumentWithName()
            }
            .disabled(documentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
        } message: {
            Text("Inserisci un nome per il documento")
        }
    }
    
    private func handleImageSelection(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let defaultName = "Foto_\(Date().formatted(date: .abbreviated, time: .omitted))"
        pendingDocumentData = (data: imageData, type: "image/jpeg", originalName: defaultName)
        documentName = defaultName
        showingNameDialog = true
    }
    
    private func handleDocumentSelection(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let fileName = url.deletingPathExtension().lastPathComponent
            let fileType = url.pathExtension == "pdf" ? "application/pdf" : "application/octet-stream"
            
            pendingDocumentData = (data: data, type: fileType, originalName: fileName)
            documentName = fileName
            showingNameDialog = true
        } catch {
            print("Errore lettura documento: \(error)")
        }
    }
    
    private func saveDocumentWithName() {
        guard let documentData = pendingDocumentData else { return }
        
        let document = Document(context: viewContext)
        document.id = UUID()
        document.name = documentName.trimmingCharacters(in: .whitespacesAndNewlines)
        document.type = documentData.type
        document.size = Int64(documentData.data.count)
        document.data = documentData.data
        document.dateAdded = Date()
        document.car = car
        
        do {
            try viewContext.save()
            print("✅ Documento salvato con nome: \(document.name ?? "")")
        } catch {
            print("❌ Errore salvataggio documento: \(error)")
        }
        
        // Reset
        pendingDocumentData = nil
        documentName = ""
    }
}

struct DocumentRowView: View {
    let document: Document
    @State private var showingDeleteAlert = false
    @State private var showingDocument = false
    @State private var showingRenameDialog = false
    @State private var newDocumentName = ""
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
            
            Menu {
                Button(action: {
                    newDocumentName = document.name ?? ""
                    showingRenameDialog = true
                }) {
                    Label("Rinomina", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive, action: { showingDeleteAlert = true }) {
                    Label("Elimina", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
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
        .alert("Rinomina documento", isPresented: $showingRenameDialog) {
            TextField("Nome documento", text: $newDocumentName)
                .textInputAutocapitalization(.words)
            
            Button("Annulla", role: .cancel) {
                newDocumentName = ""
            }
            
            Button("Salva") {
                renameDocument()
            }
            .disabled(newDocumentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
        } message: {
            Text("Inserisci il nuovo nome per il documento")
        }
        .sheet(isPresented: $showingDocument) {
            DocumentViewerView(document: document)
        }
    }
    
    private func deleteDocument() {
        viewContext.delete(document)
        
        do {
            try viewContext.save()
            print("✅ Documento eliminato")
        } catch {
            print("❌ Errore eliminazione documento: \(error)")
        }
    }
    
    private func renameDocument() {
        let trimmedName = newDocumentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        document.name = trimmedName
        
        do {
            try viewContext.save()
            print("✅ Documento rinominato in: \(trimmedName)")
        } catch {
            print("❌ Errore rinomina documento: \(error)")
        }
        
        newDocumentName = ""
    }
}

struct RemindersTabView: View {
    @ObservedObject var car: Car
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Promemoria")
                .font(.headline)
            
            Text("Funzionalità promemoria in arrivo")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
}

struct NotesTabView: View {
    @ObservedObject var car: Car
    @State private var isEditing = false
    @State private var tempNotes = ""
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        VStack {
            if let notes = car.notes, !notes.isEmpty, !isEditing {
                // Mostra note esistenti
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Le mie note")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Modifica") {
                            tempNotes = notes
                            isEditing = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Text(notes)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            } else if isEditing {
                // Modalità modifica
                VStack {
                    HStack {
                        Button("Annulla") {
                            isEditing = false
                            tempNotes = ""
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Salva") {
                            saveNotes()
                        }
                        .foregroundColor(.blue)
                        .disabled(tempNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    
                    TextEditor(text: $tempNotes)
                        .focused($isTextEditorFocused)
                        .frame(minHeight: 200)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .onAppear {
                    isTextEditorFocused = true
                }
            } else {
                // Stato vuoto
                VStack(spacing: 20) {
                    Image(systemName: "note.text")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Nessuna nota")
                        .font(.headline)
                    
                    Text("Aggiungi note per ricordare informazioni importanti")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Aggiungi note") {
                        tempNotes = ""
                        isEditing = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 40)
            }
        }
    }
    
    private func saveNotes() {
        let trimmedNotes = tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        car.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        
        do {
            try viewContext.save()
            isEditing = false
            tempNotes = ""
        } catch {
            print("Errore salvataggio note: \(error)")
        }
    }
}

// MARK: - Components

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

struct CopyableInfoItem: View {
    let title: String
    let value: String
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: onCopy) {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CarDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let car = Car(context: context)
        car.name = "Auto Test"
        car.brand = "BMW"
        car.model = "Serie 3"
        car.plate = "AB123CD"
        
        return CarDetailView(car: car)
            .environment(\.managedObjectContext, context)
    }
}
