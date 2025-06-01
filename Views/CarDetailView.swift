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
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.string(from: date)
    }
    
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
                         value: formatDate(car.registrationDate))
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
            try DataModificationTracker.saveContext(viewContext)
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
    @State private var refreshID = UUID()
    @State private var showingFilters = false
    @State private var selectedFilter: MaintenanceFilter = .all
    @State private var selectedYear: Int = 0
    @State private var searchText = ""
    
    enum MaintenanceFilter: String, CaseIterable {
        case all = "Tutti"
        case tagliando = "Tagliando"
        case revisione = "Revisione"
        case bollo = "Bollo"
        case assicurazione = "Assicurazione"
        case gomme = "Cambio gomme"
        case custom = "Personalizzati"
        
        var icon: String {
            switch self {
            case .all: return "line.3.horizontal.decrease"
            case .tagliando: return "wrench.and.screwdriver"
            case .revisione: return "checkmark.shield"
            case .bollo: return "doc.text"
            case .assicurazione: return "shield"
            case .gomme: return "circle"
            case .custom: return "gear"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .blue
            case .tagliando: return .orange
            case .revisione: return .green
            case .bollo: return .red
            case .assicurazione: return .purple
            case .gomme: return .brown
            case .custom: return .gray
            }
        }
    }
    
    var filteredMaintenances: [Maintenance] {
        let allMaintenances = car.maintenanceArray
        var filtered = allMaintenances
        
        // Filtro per tipo
        if selectedFilter != .all {
            filtered = filtered.filter { maintenance in
                if selectedFilter == .custom {
                    return maintenance.type == "custom"
                } else {
                    return maintenance.type == selectedFilter.rawValue.lowercased()
                }
            }
        }
        
        // Filtro per anno
        if selectedYear > 0 {
            filtered = filtered.filter { maintenance in
                guard let date = maintenance.date else { return false }
                return Calendar.current.component(.year, from: date) == selectedYear
            }
        }
        
        // Filtro per testo di ricerca
        if !searchText.isEmpty {
            filtered = filtered.filter { maintenance in
                let searchLower = searchText.lowercased()
                let typeMatch = maintenance.displayType.lowercased().contains(searchLower)
                let notesMatch = maintenance.notes?.lowercased().contains(searchLower) ?? false
                let costMatch = String(format: "%.2f", maintenance.cost).contains(searchLower)
                return typeMatch || notesMatch || costMatch
            }
        }
        
        return filtered
    }
    
    var availableYears: [Int] {
        let years = Set(car.maintenanceArray.compactMap { maintenance -> Int? in
            guard let date = maintenance.date else { return nil }
            return Calendar.current.component(.year, from: date)
        })
        return Array(years).sorted(by: >)
    }
    
    var hasActiveFilters: Bool {
        return selectedFilter != .all || selectedYear > 0 || !searchText.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con filtri
            filterHeaderView
            
            // Lista manutenzioni filtrate
            if filteredMaintenances.isEmpty {
                if hasActiveFilters {
                    // Stato vuoto con filtri attivi
                    filteredEmptyStateView
                } else {
                    // Stato vuoto normale
                    normalEmptyStateView
                }
            } else {
                // Lista con risultati
                maintenanceListView
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MaintenanceDataChanged"))) { _ in
            print("📡 Ricevuta notifica MaintenanceDataChanged")
            refreshMaintenanceList()
        }
        .sheet(isPresented: $showingFilters) {
            MaintenanceFiltersSheet(
                selectedFilter: $selectedFilter,
                selectedYear: $selectedYear,
                availableYears: availableYears,
                searchText: $searchText
            )
        }
    }
    
    // MARK: - Filter Header
    private var filterHeaderView: some View {
        VStack(spacing: 12) {
            // Riga principale con conteggio e filtri
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manutenzioni")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if hasActiveFilters {
                        Text("\(filteredMaintenances.count) di \(car.maintenanceArray.count) interventi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(car.maintenanceArray.count) interventi totali")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Bottone filtri
                    Button(action: { showingFilters = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundColor(hasActiveFilters ? .white : .blue)
                            
                            if hasActiveFilters {
                                Text("Filtri")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, hasActiveFilters ? 12 : 8)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(hasActiveFilters ? Color.blue : Color.blue.opacity(0.1))
                        )
                    }
                    
                    // Bottone aggiungi
                    Button(action: { showingAddMaintenance = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.horizontal)
            
            // Indicatori filtri attivi
            if hasActiveFilters {
                activeFiltersView
            }
        }
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Active Filters Indicators
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Filtro tipo
                if selectedFilter != .all {
                    FilterChip(
                        text: selectedFilter.rawValue,
                        icon: selectedFilter.icon,
                        color: selectedFilter.color
                    ) {
                        selectedFilter = .all
                    }
                }
                
                // Filtro anno
                if selectedYear > 0 {
                    FilterChip(
                        text: String(selectedYear),
                        icon: "calendar",
                        color: .orange
                    ) {
                        selectedYear = 0
                    }
                }
                
                // Filtro ricerca
                if !searchText.isEmpty {
                    FilterChip(
                        text: "'\(searchText)'",
                        icon: "magnifyingglass",
                        color: .purple
                    ) {
                        searchText = ""
                    }
                }
                
                // Pulsante reset tutti
                Button(action: {
                    selectedFilter = .all
                    selectedYear = 0
                    searchText = ""
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                        Text("Reset")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Lista manutenzioni
    private var maintenanceListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMaintenances) { maintenance in
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
            .padding(.vertical)
        }
        .id(refreshID)
    }
    
    // MARK: - Empty States
    private var normalEmptyStateView: some View {
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
    }
    
    private var filteredEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Nessun risultato")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Non ci sono interventi che corrispondono ai filtri selezionati")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("Reset filtri") {
                    selectedFilter = .all
                    selectedYear = 0
                    searchText = ""
                }
                .buttonStyle(.bordered)
                
                Button("Aggiungi intervento") {
                    showingAddMaintenance = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Funzioni private
    private func refreshMaintenanceList() {
        withAnimation(.easeInOut(duration: 0.3)) {
            refreshID = UUID()
            viewContext.refresh(car, mergeChanges: true)
        }
        print("🔄 Lista manutenzioni aggiornata")
    }
    
    private func deleteMaintenance(_ maintenance: Maintenance) {
        if let reminder = maintenance.reminder {
            viewContext.delete(reminder)
        }
        viewContext.delete(maintenance)
        
        do {
            try DataModificationTracker.saveContext(viewContext)
            refreshMaintenanceList()
        } catch {
            print("Errore eliminazione intervento: \(error)")
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let text: String
    let icon: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color)
        )
    }
}

// MARK: - Filters Sheet
struct MaintenanceFiltersSheet: View {
    @Binding var selectedFilter: MaintenanceTabView.MaintenanceFilter
    @Binding var selectedYear: Int
    let availableYears: [Int]
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Sezione ricerca
                Section(header: Text("Ricerca")) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Cerca per tipo, note o costo...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    
                    if !searchText.isEmpty {
                        Button("Cancella ricerca") {
                            searchText = ""
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // Sezione tipo intervento
                Section(header: Text("Tipo Intervento")) {
                    ForEach(MaintenanceTabView.MaintenanceFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            HStack {
                                Image(systemName: filter.icon)
                                    .foregroundColor(filter.color)
                                    .frame(width: 24)
                                
                                Text(filter.rawValue)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Sezione anno
                if !availableYears.isEmpty {
                    Section(header: Text("Anno")) {
                        Button(action: {
                            selectedYear = 0
                        }) {
                            HStack {
                                Text("Tutti gli anni")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedYear == 0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        ForEach(availableYears, id: \.self) { year in
                            Button(action: {
                                selectedYear = year
                            }) {
                                HStack {
                                    Text(String(year))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedYear == year {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Sezione reset
                Section {
                    Button("Reset tutti i filtri") {
                        selectedFilter = .all
                        selectedYear = 0
                        searchText = ""
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Filtri Manutenzioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        dismiss()
                    }
                }
            }
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
    
    var formattedDate: String {
        guard let date = maintenance.date else { return "" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(maintenanceTypeName)
                        .font(.headline)
                    
                    Text(formattedDate)
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
            try DataModificationTracker.saveContext(viewContext)
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
                    
                    Text(formatDate(document.dateAdded))
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
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        return formatter.string(from: date)
    }
    
    private func deleteDocument() {
        viewContext.delete(document)
        
        do {
            try DataModificationTracker.saveContext(viewContext)
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
            try DataModificationTracker.saveContext(viewContext)
            print("✅ Documento rinominato in: \(trimmedName)")
        } catch {
            print("❌ Errore rinomina documento: \(error)")
        }
        
        newDocumentName = ""
    }
}

struct RemindersTabView: View {
    @ObservedObject var car: Car
    @State private var upcomingReminders: [ReminderInfo] = []
    @State private var refreshID = UUID()
    
    var body: some View {
        VStack(spacing: 16) {
            if upcomingReminders.isEmpty {
                // Stato vuoto
                VStack(spacing: 20) {
                    Image(systemName: "bell.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Nessun promemoria attivo")
                        .font(.headline)
                    
                    Text("I promemoria vengono creati automaticamente quando aggiungi interventi di manutenzione")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 40)
            } else {
                // Header con statistiche
                ReminderStatsView(reminders: upcomingReminders)
                    .padding(.horizontal)
                
                // Lista promemoria
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(upcomingReminders) { reminderInfo in
                            ReminderRowView(reminderInfo: reminderInfo)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .id(refreshID)
        .onAppear {
            loadReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MaintenanceDataChanged"))) { _ in
            loadReminders()
        }
    }
    
    private func loadReminders() {
        upcomingReminders = NotificationManager.shared.getUpcomingReminders(for: car, within: 365)
        refreshID = UUID()
        print("🔔 Caricati \(upcomingReminders.count) promemoria per \(car.name ?? "auto")")
    }
}

// Vista statistiche promemoria
struct ReminderStatsView: View {
    let reminders: [ReminderInfo]
    
    var overdueCount: Int {
        reminders.filter { $0.isDue }.count
    }
    
    var urgentCount: Int {
        reminders.filter { $0.urgencyLevel == .high && !$0.isDue }.count
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Promemoria scaduti
            StatCard(
                title: "Scaduti",
                count: overdueCount,
                color: .red,
                icon: "exclamationmark.triangle.fill"
            )
            
            // Promemoria urgenti
            StatCard(
                title: "Urgenti",
                count: urgentCount,
                color: .orange,
                icon: "clock.fill"
            )
            
            // Totale promemoria
            StatCard(
                title: "Totale",
                count: reminders.count,
                color: .blue,
                icon: "bell.fill"
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// Vista singolo promemoria
struct ReminderRowView: View {
    let reminderInfo: ReminderInfo
    @State private var showingMaintenanceDetail = false
    
    var urgencyColor: Color {
        switch reminderInfo.urgencyLevel {
        case .overdue: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        }
    }
    
    var urgencyText: String {
        if reminderInfo.isDue {
            return "Scaduto"
        } else if let days = reminderInfo.daysUntilDue {
            if days == 0 {
                return "Oggi"
            } else if days == 1 {
                return "Domani"
            } else {
                return "Tra \(days) giorni"
            }
        } else {
            return "Da verificare"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Indicatore urgenza
            Rectangle()
                .fill(urgencyColor)
                .frame(width: 4)
                .cornerRadius(2)
            
            VStack(alignment: .leading, spacing: 6) {
                // Tipo manutenzione con indicatore se è calcolato
                HStack {
                    Text(reminderInfo.maintenanceDisplayType)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if reminderInfo.isCalculated {
                        Text("previsto")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                
                // Messaggio promemoria
                Text(reminderInfo.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Urgenza
                HStack {
                    Image(systemName: reminderInfo.isDue ? "exclamationmark.circle.fill" : "clock")
                        .font(.caption)
                        .foregroundColor(urgencyColor)
                    
                    Text(urgencyText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(urgencyColor)
                }
            }
            
            Spacer()
            
            // Freccia
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(urgencyColor.opacity(0.3), lineWidth: reminderInfo.isDue ? 2 : 0)
        )
        .onTapGesture {
            // Solo per promemoria reali (non calcolati)
            if !reminderInfo.isCalculated {
                showingMaintenanceDetail = true
            }
        }
        .sheet(isPresented: $showingMaintenanceDetail) {
            if !reminderInfo.isCalculated,
               let realMaintenance = reminderInfo.maintenance as? Maintenance {
                AddMaintenanceView(car: reminderInfo.car, maintenanceToEdit: realMaintenance)
            }
        }
    }
}

struct NotesTabView: View {
    @ObservedObject var car: Car
    @State private var isEditing = false
    @State private var tempNotes = ""
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var isTextEditorFocused: Bool
    @State private var showingSaveAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let notes = car.notes, !notes.isEmpty, !isEditing {
                // Vista di lettura delle note esistenti
                notesReadView(notes: notes)
            } else if isEditing {
                // Vista di modifica
                notesEditView
            } else {
                // Stato vuoto
                notesEmptyView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isEditing)
        .overlay(
            // Animazione di salvataggio
            saveSuccessOverlay,
            alignment: .top
        )
    }
    
    // MARK: - Vista lettura note
    private func notesReadView(notes: String) -> some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        Text("Le mie note")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        tempNotes = notes
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isEditing = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextEditorFocused = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.caption)
                            Text("Modifica")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Divider decorativo
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.1), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 20)
            }
            
            // Contenuto note
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(notes)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Info sulla data di ultima modifica (opzionale)
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Ultima modifica: oggi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(notes.count) caratteri")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Vista modifica
    private var notesEditView: some View {
        VStack(spacing: 0) {
            // Header modifica
            VStack(spacing: 16) {
                HStack {
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isEditing = false
                        }
                        tempNotes = ""
                        isTextEditorFocused = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.caption)
                            Text("Annulla")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red)
                        )
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Modifica note")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        saveNotes()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                            Text("Salva")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(tempNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.green)
                        )
                    }
                    .disabled(tempNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Info caratteri
                HStack {
                    Text("\(tempNotes.count) caratteri")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if tempNotes.count > 500 {
                        Text("Note lunghe")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 20)
                
                // Divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .green.opacity(0.1), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 20)
            }
            
            // Editor di testo
            VStack(spacing: 12) {
                TextEditor(text: $tempNotes)
                    .focused($isTextEditorFocused)
                    .font(.body)
                    .lineSpacing(4)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isTextEditorFocused ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                            .animation(.easeInOut(duration: 0.2), value: isTextEditorFocused)
                    )
                    .frame(minHeight: 200)
                    .padding(.horizontal, 20)
                
                // Suggerimenti rapidi
                if tempNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Idee per le tue note:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            quickSuggestionButton("• Problemi riscontrati")
                            quickSuggestionButton("• Modifiche effettuate")
                            quickSuggestionButton("• Promemoria personali")
                            quickSuggestionButton("• Accessori aggiunti")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.05))
                    )
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Vista stato vuoto
    private var notesEmptyView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icona animata
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .blue.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("Nessuna nota")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Aggiungi note personali per ricordare\ninformazioni importanti su questa auto")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            Button(action: {
                tempNotes = ""
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isEditing = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextEditorFocused = true
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    
                    Text("Aggiungi le tue note")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isEditing)
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Componenti di supporto
    private func quickSuggestionButton(_ text: String) -> some View {
        Button(action: {
            if !tempNotes.isEmpty {
                tempNotes += "\n"
            }
            tempNotes += text
        }) {
            Text(text)
                .font(.caption)
                .foregroundColor(.blue)
        }
    }
    
    private var saveSuccessOverlay: some View {
        Group {
            if showingSaveAnimation {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    Text("Note salvate")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding(.top, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }
    
    // MARK: - Funzioni
    private func saveNotes() {
        let trimmedNotes = tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        car.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        
        do {
            try DataModificationTracker.saveContext(viewContext)
            
            // Mostra animazione di successo
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showingSaveAnimation = true
                isEditing = false
            }
            
            // Nascondi l'animazione dopo 2 secondi
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showingSaveAnimation = false
                }
            }
            
            tempNotes = ""
            isTextEditorFocused = false
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
