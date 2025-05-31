import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var settingsManager = SettingsStateManager()
    
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
                        EmptyStateView()
                            .padding(.top, 100)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header semplificato
                            simpleHeaderView
                            
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
            .navigationTitle("BullyCar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        print("🎛️ Tentativo apertura impostazioni")
                        settingsManager.openSettings()
                    }) {
                        Image(systemName: "gear")
                    }
                    .disabled(settingsManager.isShowingSettings)
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
            .sheet(isPresented: $settingsManager.isShowingSettings, onDismiss: {
                print("🎛️ Impostazioni chiuse - cleanup")
                settingsManager.closeSettings()
            }) {
                SettingsView()
                    .environmentObject(themeManager)
                    .id(settingsManager.settingsViewKey)
                    .onDisappear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            settingsManager.resetSettingsState()
                        }
                    }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CarDataChanged"))) { _ in
                print("📡 Ricevuta notifica CarDataChanged")
                refreshView()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImportCompleted"))) { _ in
                print("📡 Import completato - reset completo dell'interfaccia")
                performCompleteReset()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceSettingsReset"))) { _ in
                print("📡 Reset forzato impostazioni")
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
        }
    }
    
    // MARK: - Simple Header View
    private var simpleHeaderView: some View {
        VStack(spacing: 16) {
            // Titolo sezione
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
        settingsManager.resetSettingsState()
        
        addCarViewKey = UUID()
        homeViewKey = UUID()
        refreshID = UUID()
        
        viewContext.refreshAllObjects()
        
        withAnimation(.easeInOut(duration: 0.5)) {
            forceRefresh.toggle()
        }
        
        print("✅ Reset completo dell'interfaccia completato")
    }
    
    // MARK: - Funzioni di supporto per le statistiche (rimosse)
    // Funzioni rimosse: formatTotalMileage, mostRecentCarYear, getTotalReminders
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

// MARK: - Card per singola auto - Design corretto con navigazione
struct CarCardView: View {
    @ObservedObject var car: Car
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditCar = false
    @State private var showingDeleteAlert = false
    @State private var showingCopyFeedback = false
    @State private var cardScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        NavigationLink(destination: CarDetailView(car: car)) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingEditCar) {
            AddCarView(carToEdit: car, onSave: {
                showingEditCar = false
                NotificationCenter.default.post(
                    name: NSNotification.Name("CarDataChanged"),
                    object: nil
                )
            })
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
    
    private var cardContent: some View {
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
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        .scaleEffect(cardScale)
        .contextMenu {
            Button(action: {
                copyPlateNumber()
            }) {
                Label("Copia targa", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                showingEditCar = true
            }) {
                Label("Modifica", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                showingDeleteAlert = true
            }) {
                Label("Elimina", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Header con immagine (dimensioni ottimizzate)
    private var carImageHeader: some View {
        ZStack {
            // Immagine di sfondo
            if let imageData = car.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140) // Ridotta l'altezza
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
                // Badge targa in alto a destra
                HStack {
                    Spacer()
                    
                    Button(action: {
                        copyPlateNumber()
                    }) {
                        HStack(spacing: 4) {
                            Text(car.plate ?? "")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.black.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .onTapGesture {
                        copyPlateNumber()
                    }
                }
                
                Spacer()
                
                // Nome auto in basso
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
    
    // MARK: - Sezione contenuto (solo km, anno e note opzionali)
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
    
    private func calculateYearlyUsage() -> Int {
        guard let addDate = car.addDate else { return 0 }
        let years = max(1, Int(Date().timeIntervalSince(addDate) / (365.25 * 24 * 3600)))
        return Int(car.mileage) / years
    }
    
    private func progressColor(for mileage: Int32) -> Color {
        let percentage = Double(mileage) / 200000.0
        if percentage < 0.3 { return .green }
        if percentage < 0.7 { return .orange }
        return .red
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(ThemeManager())
    }
}
