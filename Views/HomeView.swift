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
    @State private var addCarViewKey = UUID() // Chiave per resettare AddCarView
    
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
                        LazyVStack(spacing: 16) {
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
                }
            }
            .navigationTitle("BullyCar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        settingsManager.openSettings()
                    }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Reset chiave prima di aprire
                        addCarViewKey = UUID()
                        showingAddCar = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCar) {
                AddCarView(onSave: {
                    showingAddCar = false
                    refreshID = UUID()
                })
                .id(addCarViewKey) // Usa chiave per forzare ricreazione vista
            }
            .sheet(isPresented: $settingsManager.isShowingSettings, onDismiss: {
                print("🎛️ Impostazioni chiuse - cleanup")
                settingsManager.closeSettings()
            }) {
                SettingsView()
                    .environmentObject(themeManager)
                    .id(settingsManager.settingsViewKey)
                    .onDisappear {
                        // Cleanup aggiuntivo quando la vista scompare
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
                print("📡 Import completato - refresh completo")
                refreshView()
                // Reset anche la chiave di AddCar per evitare conflitti
                addCarViewKey = UUID()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceSettingsReset"))) { _ in
                print("📡 Reset forzato impostazioni")
                settingsManager.resetSettingsState()
                // Reset anche AddCar
                addCarViewKey = UUID()
            }
        }
        .onAppear {
            viewContext.refreshAllObjects()
        }
        .id(forceRefresh)
    }
    
    private func refreshView() {
        refreshID = UUID()
        forceRefresh.toggle()
        viewContext.refreshAllObjects()
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

// Card per singola auto - Layout orizzontale per una card per riga
struct CarCardView: View {
    @ObservedObject var car: Car
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditCar = false
    @State private var showingDeleteAlert = false
    @State private var showingCopyFeedback = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Immagine auto (più piccola a sinistra)
            ZStack {
                if let imageData = car.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(10)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                        .overlay(
                            Image(systemName: "car.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        )
                }
            }
            
            // Info auto (a destra dell'immagine)
            VStack(alignment: .leading, spacing: 6) {
                // Nome e targa (riga principale)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(car.name ?? "")
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(car.plate ?? "")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                // Marca, modello e anno
                Text("\(car.brand ?? "") \(car.model ?? "") • \(String(car.year))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Chilometraggio (spostato qui)
                Text("\(car.mileage) km")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                // Note (se presenti)
                if let notes = car.notes, !notes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .padding(16)
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
