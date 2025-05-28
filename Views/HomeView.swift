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
    @State private var refreshID = UUID() // Per forzare refresh
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if cars.isEmpty {
                    EmptyStateView()
                } else {
                    CarListView(cars: Array(cars))
                        .id(refreshID) // Forza refresh quando cambia
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
                AddCarView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(themeManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CarDataChanged"))) { _ in
                // Forza il refresh quando i dati cambiano
                refreshID = UUID()
            }
        }
        .onAppear {
            // Aggiorna quando la vista appare
            viewContext.refreshAllObjects()
        }
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
    @ObservedObject var car: Car // Cambiato da let a @ObservedObject
    
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
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(ThemeManager())
    }
}
