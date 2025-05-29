import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var themeManager: ThemeManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Car.name, ascending: true)],
        animation: .default)
    private var cars: FetchedResults<Car>
    
    @State private var showingAddCar = false
    @State private var showingSettings = false
    @State private var refreshID = UUID()
    @State private var forceRefresh = false // Nuovo stato per forzare il refresh
    
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
                    .refreshable {
                        await refreshData()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                            ForEach(cars) { car in
                                NavigationLink(destination: CarDetailView(car: car)) {
                                    CarCardView(car: car)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                        .id(refreshID)
                    }
                    .refreshable {
                        await refreshData()
                    }
                }
            }
            .navigationTitle("BullyCar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCar = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCar) {
                AddCarView(onSave: {
                    print("🏠 Callback onSave ricevuta - chiudendo sheet...")
                    showingAddCar = false
                    
                    // Forza il refresh della vista dopo la chiusura
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        refreshID = UUID()
                        print("🏠 HomeView refreshed")
                    }
                })
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(themeManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CarDataChanged"))) { _ in
                print("📡 Ricevuta notifica CarDataChanged - forzando refresh completo")
                Task { @MainActor in
                    // Refresh molto più aggressivo
                    viewContext.reset()
                    
                    // Forza il re-fetch dei dati
                    let request: NSFetchRequest<Car> = Car.fetchRequest()
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \Car.name, ascending: true)]
                    
                    do {
                        _ = try viewContext.fetch(request)
                        print("✅ Dati re-fetchati con successo")
                    } catch {
                        print("❌ Errore nel re-fetch: \(error)")
                    }
                    
                    refreshID = UUID()
                    forceRefresh.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                print("📱 App diventata attiva - refresh")
                Task { @MainActor in
                    refreshID = UUID()
                    viewContext.refreshAllObjects()
                }
            }
        }
        .environment(\.locale, Locale.current) // Localizzazione per tutta la HomeView
        .onAppear {
            print("🏠 HomeView appeared")
            viewContext.refreshAllObjects()
        }
        .id(forceRefresh) // Usa il nuovo stato per forzare il re-render
    }
    
    // Funzione per il refresh dei dati
    @MainActor
    private func refreshData() async {
        // Aggiorna il contesto Core Data
        viewContext.refreshAllObjects()
        
        // Aggiorna l'ID per forzare il refresh della vista
        refreshID = UUID()
        
        // Piccola pausa per dare feedback visivo
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 secondi
    }
}

// Vista per stato vuoto
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

// Vista lista auto
struct CarListView: View {
    let cars: [Car]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                ForEach(cars) { car in
                    NavigationLink(destination: CarDetailView(car: car)) {
                        CarCardView(car: car)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

// Card per singola auto
struct CarCardView: View {
    @ObservedObject var car: Car
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditCar = false
    @State private var showingDeleteAlert = false
    @State private var showingCopyFeedback = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Immagine auto
            ZStack {
                if let imageData = car.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "car.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
            }
            
            // Info auto
            VStack(alignment: .leading, spacing: 4) {
                Text(car.name ?? "")
                    .font(.headline)
                    .lineLimit(1)
                
                Text(car.plate ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(car.brand ?? "") \(car.model ?? "")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(car.mileage) km")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Anteprima note se presenti
                if let notes = car.notes, !notes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text(notes)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            // Context menu con pressione lunga
            Button(action: { copyPlateNumber() }) {
                Label("Copia targa", systemImage: "doc.on.doc")
            }
            
            Button(action: { showingEditCar = true }) {
                Label("Modifica", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                Label("Elimina", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditCar) {
            AddCarView(carToEdit: car, onSave: {
                showingEditCar = false
                // Invia notifica per refresh
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
        // Toast per feedback copia targa
        .overlay(
            copyFeedbackToast,
            alignment: .topTrailing
        )
    }
    
    // Toast di feedback per la copia targa
    var copyFeedbackToast: some View {
        Group {
            if showingCopyFeedback {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Copiata")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
                .padding(.top, 8)
                .padding(.trailing, 8)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(ThemeManager())
    }
}
