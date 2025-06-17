import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingSettings = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Car.name, ascending: true)],
        animation: .default)
    private var cars: FetchedResults<Car>
    
    @State private var showingAddCar = false
    @State private var refreshID = UUID()
    @State private var forceRefresh = false
    @State private var addCarViewKey = UUID()
    @State private var homeViewKey = UUID()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if cars.isEmpty {
                    ScrollView {
                        VStack(spacing: 24) {
                            // ✅ AGGIUNTO: Backup Status anche quando non ci sono auto
                            BackupStatusCard()
                            
                            EmptyStateView()
                                .padding(.top, 100)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header semplificato
                            simpleHeaderView
                            
                            // ✅ AGGIUNTO: Backup Status Card
                            BackupStatusCard()
                            
                            // Layout delle auto - Una per riga
                            LazyVStack(spacing: 20) {
                                ForEach(cars) { car in
                                    CarCardView(car: car)
                                }
                            }
                            .padding(.horizontal)
                            .id(refreshID)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Dueffe Car")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        print("➕ Tentativo apertura AddCar")
                        addCarViewKey = UUID()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingAddCar = true
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(showingAddCar)
                }
            }
            .sheet(isPresented: $showingAddCar) {
                AddCarView(onSave: {
                    print("🚗 Auto salvata - chiusura sheet")
                    showingAddCar = false
                    refreshView()
                })
                .id(addCarViewKey)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(themeManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CarDataChanged"))) { _ in
                print("📡 Ricevuta notifica CarDataChanged")
                refreshView()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImportCompleted"))) { _ in
                print("📡 Import completato - reset completo dell'interfaccia")
                performCompleteReset()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DataDeleted"))) { _ in
                print("📡 Dati eliminati - reset completo dell'interfaccia")
                performCompleteReset()
            }
        }
        .id(homeViewKey)
        .onAppear {
            viewContext.refreshAllObjects()
            // ✅ FIX: Solo controllo iniziale dello stato, senza forzare l'alert
            BackupStatusManager.shared.checkBackupStatus()
        }
    }
    
    // MARK: - Simple Header View
    private var simpleHeaderView: some View {
        HStack {
            Text("Le tue auto")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Text("\(cars.count) \(cars.count == 1 ? "auto" : "auto")")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.blue.opacity(0.1))
                )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Funzioni private
    private func refreshView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            refreshID = UUID()
            forceRefresh.toggle()
        }
        viewContext.refreshAllObjects()
    }
    
    private func performCompleteReset() {
        print("🔄 Eseguendo reset completo dell'interfaccia...")
        
        showingAddCar = false
        showingSettings = false // ✅ SEMPLIFICA
        
        addCarViewKey = UUID()
        homeViewKey = UUID()
        refreshID = UUID()
        
        viewContext.refreshAllObjects()
        
        withAnimation(.easeInOut(duration: 0.5)) {
            forceRefresh.toggle()
        }
        
        print("✅ Reset completo dell'interfaccia completato")
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Non hai ancora aggiunto auto")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tocca + per aggiungere la tua prima auto")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Card per singola auto
struct CarCardView: View {
    @ObservedObject var car: Car
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditCar = false
    @State private var showingDeleteAlert = false
    @State private var showingCopyFeedback = false
    @State private var showingAddMaintenance = false
    @State private var showingAddDocument = false
    @State private var showingStatusManager = false
    @State private var cardScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        NavigationLink(destination: CarDetailView(car: car)) {
            VStack(spacing: 0) {
                // Header con immagine e overlay
                carImageHeader
                
                // Contenuto principale
                carContentSection
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        car.carStatus != .active ? car.carStatus.color.opacity(0.5) : Color.blue.opacity(0.1),
                        lineWidth: car.carStatus != .active ? 2 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            .scaleEffect(cardScale)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: {
                copyPlateNumber()
            }) {
                Label("Copia targa", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: {
                showingStatusManager = true
            }) {
                Label("Gestisci auto", systemImage: "gear")
            }
            
            Button(action: {
                showingAddMaintenance = true
            }) {
                Label("Aggiungi manutenzione", systemImage: "wrench.and.screwdriver")
            }
            
            Button(action: {
                showingAddDocument = true
            }) {
                Label("Aggiungi documento", systemImage: "doc.badge.plus")
            }
            
            Divider()
            
            Button(action: {
                showingEditCar = true
            }) {
                Label("Modifica", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: {
                showingDeleteAlert = true
            }) {
                Label("Elimina", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditCar) {
            AddCarView(carToEdit: car, onSave: {
                showingEditCar = false
                NotificationCenter.default.post(
                    name: NSNotification.Name("CarDataChanged"),
                    object: nil
                )
            })
        }
        .sheet(isPresented: $showingAddMaintenance) {
            AddMaintenanceView(car: car)
        }
        .sheet(isPresented: $showingAddDocument) {
            DocumentPickerSheet(car: car)
        }
        .sheet(isPresented: $showingStatusManager) {
            CarStatusManagerView(car: car)
        }
        .alert("Elimina auto", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                deleteCar()
            }
        } message: {
            Text("Sei sicuro di voler eliminare \(car.name ?? "questa auto")? Questa azione non può essere annullata.")
        }
        .overlay(
            copyFeedbackToast,
            alignment: .topTrailing
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }
    
    // MARK: - Header con immagine
    private var carImageHeader: some View {
        ZStack {
            // Immagine di sfondo
            if let imageData = car.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .clipped()
            } else {
                // Gradiente di fallback
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.6),
                                Color.purple.opacity(0.4),
                                Color.blue.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)
                    .overlay(
                        // Effetto shimmer
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.3), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: shimmerOffset)
                            .clipped()
                    )
                    .overlay(
                        // Icona auto
                        Image(systemName: "car.fill")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
            }
            
            // Overlay sfumato
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 140)
            
            // Contenuto sovrapposto
            VStack {
                // Header superiore con targa e badge status
                HStack {
                    // ✅ AGGIUNTO: Badge di status se l'auto non è attiva
                    if car.carStatus != .active {
                        HStack(spacing: 4) {
                            Image(systemName: car.carStatus.icon)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(car.carStatus.displayName)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(car.carStatus.color)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                    }
                    
                    Spacer()
                    
                    // Targa europea realistica - dimensioni contenute
                    HStack(spacing: 0) {
                        // Banda blu laterale SINISTRA con stelle europee
                        ZStack {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 14)
                            
                            VStack(spacing: 1) {
                                // Stelle europee stilizzate
                                Image(systemName: "star.fill")
                                    .font(.system(size: 3))
                                    .foregroundColor(.yellow)
                                
                                Text("I")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "star.fill")
                                    .font(.system(size: 3))
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        // Parte bianca con targa - larghezza adattiva
                        Text(car.plate ?? "")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white)
                        
                        // ✅ AGGIUNTO: Banda blu laterale DESTRA con decorazione
                        ZStack {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 14)
                            
                            // Decorazione semplice sulla destra (opzionale)
                            VStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 2))
                                    .foregroundColor(.yellow)
                                
                                Image(systemName: "star.fill")
                                    .font(.system(size: 2))
                                    .foregroundColor(.yellow)
                                
                                Image(systemName: "star.fill")
                                    .font(.system(size: 2))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .frame(height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.black, lineWidth: 0.8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                }
                
                Spacer()
                
                // Nome auto in basso con eventuale data di status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(car.name ?? "")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        Text("\(car.brand ?? "") \(car.model ?? "")")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        // ✅ AGGIUNTO: Mostra data di status se l'auto non è attiva
                        if car.carStatus != .active, let statusDate = car.formattedStatusDate {
                            Text("\(car.carStatus.displayName) il \(statusDate)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 16
            )
        )
    }
    
    // MARK: - Sezione contenuto
    private var carContentSection: some View {
        VStack(spacing: 12) {
            // Solo anno e chilometraggio
            HStack(spacing: 16) {
                // Anno
                compactInfoCard(
                    icon: "calendar",
                    title: "Anno",
                    value: String(car.year),
                    color: .orange
                )
                
                // Chilometraggio
                compactInfoCard(
                    icon: "speedometer",
                    title: "Km",
                    value: formatMileage(car.mileage),
                    color: .green
                )
            }
            
            // Note (se presenti)
            if let notes = car.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.purple)
                        
                        Text("Note")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(16)
    }
    
    // MARK: - Componenti compatti
    private func compactInfoCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
            
            VStack(spacing: 1) {
                Text(value)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
    
    // Toast di feedback compatto
    private var copyFeedbackToast: some View {
        Group {
            if showingCopyFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Copiata")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                )
                .padding(.top, 6)
                .padding(.trailing, 6)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
    
    // MARK: - Funzioni di supporto
    private func formatMileage(_ mileage: Int32) -> String {
        if mileage >= 1000 {
            return String(format: "%.0fK", Double(mileage) / 1000.0)
        } else {
            return "\(mileage)"
        }
    }
    
    private func copyPlateNumber() {
        guard let plate = car.plate, !plate.isEmpty else { return }
        
        // Copia negli appunti
        UIPasteboard.general.string = plate
        
        // Mostra feedback
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showingCopyFeedback = true
        }
        
        // Nascondi feedback dopo 1.5 secondi
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingCopyFeedback = false
            }
        }
        
        // Feedback aptico
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        print("📋 Targa copiata dalla HomeView: \(plate)")
    }
    
    private func deleteCar() {
        withAnimation {
            viewContext.delete(car)
            
            do {
                try viewContext.save()
                
                // Invia notifica per refresh
                NotificationCenter.default.post(
                    name: NSNotification.Name("CarDataChanged"),
                    object: nil
                )
                
                print("✅ Auto eliminata dalla HomeView")
            } catch {
                print("❌ Errore eliminazione auto: \(error)")
            }
        }
    }
}

// MARK: - Document Picker Sheet per aggiunta rapida documenti
struct DocumentPickerSheet: View {
    let car: Car
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var showingNameDialog = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var pendingDocumentData: (data: Data, type: String, originalName: String)?
    @State private var documentName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Aggiungi documento per \(car.name ?? "auto")")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    Button(action: {
                        imageSourceType = .camera
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                                .font(.title3)
                            Text("Scatta foto")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        imageSourceType = .photoLibrary
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo")
                                .font(.title3)
                            Text("Scegli dalla libreria")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "doc")
                                .font(.title3)
                            Text("Importa PDF")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Aggiungi documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(sourceType: imageSourceType) { image in
                if let image = image {
                    handleImageSelection(image)
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPickerView { url in
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
            dismiss()
        } catch {
            print("❌ Errore salvataggio documento: \(error)")
        }
        
        // Reset
        pendingDocumentData = nil
        documentName = ""
    }
}

// MARK: - Image Picker semplificato
struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let completion: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completion(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            parent.dismiss()
        }
    }
}

// MARK: - Document Picker semplificato
struct DocumentPickerView: UIViewControllerRepresentable {
    let completion: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .text, .data])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.completion(url)
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(ThemeManager())
    }
}
