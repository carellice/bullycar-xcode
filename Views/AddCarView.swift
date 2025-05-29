import SwiftUI
import PhotosUI

struct AddCarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    // Car da modificare (nil se nuova)
    var carToEdit: Car?
    
    // Callback per notificare il salvataggio
    var onSave: (() -> Void)?
    
    // Inizializzatore personalizzato
    init(carToEdit: Car? = nil, onSave: (() -> Void)? = nil) {
        self.carToEdit = carToEdit
        self.onSave = onSave
    }
    
    // Stati del form
    @State private var name = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var plate = ""
    @State private var registrationDate = Date()
    @State private var mileage = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingActionSheet = false
    @State private var isSaving = false
    
    var isEditing: Bool {
        carToEdit != nil
    }
    
    var canSave: Bool {
        !name.isEmpty && !brand.isEmpty && !plate.isEmpty && !isSaving
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Sezione immagine
                Section {
                    VStack {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(10)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .cornerRadius(10)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        Button(action: { showingActionSheet = true }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16))
                                Text("Aggiungi foto")
                                    .fontWeight(.medium)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)
                    }
                    .padding(.vertical)
                }
                
                // Informazioni base
                Section(header: Text("Informazioni auto")) {
                    TextField("Nome auto", text: $name)
                        .disabled(isSaving)
                    TextField("Marca", text: $brand)
                        .disabled(isSaving)
                    TextField("Modello", text: $model)
                        .disabled(isSaving)
                    
                    Picker("Anno", selection: $year) {
                        ForEach((1900...Calendar.current.component(.year, from: Date())), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .disabled(isSaving)
                }
                
                // Dettagli
                Section(header: Text("Dettagli")) {
                    TextField("Targa", text: $plate)
                        .textCase(.uppercase)
                        .disabled(isSaving)
                    
                    DatePicker("Data immatricolazione",
                             selection: $registrationDate,
                             displayedComponents: [.date])
                        .disabled(isSaving)
                        .environment(\.locale, Locale(identifier: "it_IT")) // Forza italiano
                    
                    TextField("Chilometraggio", text: $mileage)
                        .keyboardType(.numberPad)
                        .disabled(isSaving)
                }
            }
            .navigationTitle(isEditing ? "Modifica auto" : "Nuova auto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaving ? "Salvataggio..." : "Salva") {
                        saveCar()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Scegli fonte immagine"),
                buttons: [
                    .default(Text("Libreria foto")) {
                        imageSourceType = .photoLibrary
                        showingImagePicker = true
                    },
                    .default(Text("Fotocamera")) {
                        imageSourceType = .camera
                        showingImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: imageSourceType)
        }
        .onAppear {
            if let car = carToEdit {
                // Popola i campi se stiamo modificando
                name = car.name ?? ""
                brand = car.brand ?? ""
                model = car.model ?? ""
                year = Int(car.year)
                plate = car.plate ?? ""
                registrationDate = car.registrationDate ?? Date()
                mileage = String(car.mileage)
                if let imageData = car.imageData {
                    selectedImage = UIImage(data: imageData)
                }
            }
        }
    }
    
    private func saveCar() {
        guard !isSaving else { return }
        
        // Debug: stampa lo stato prima del salvataggio
        print("🔄 Iniziando salvataggio auto...")
        isSaving = true
        
        let car: Car
        
        if let carToEdit = carToEdit {
            car = carToEdit
        } else {
            car = Car(context: viewContext)
            car.id = UUID()
            car.addDate = Date()
        }
        
        car.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        car.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        car.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        car.year = Int32(year)
        car.plate = plate.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        car.registrationDate = registrationDate
        car.mileage = Int32(mileage) ?? 0
        
        if let image = selectedImage {
            car.imageData = image.jpegData(compressionQuality: 0.7)
        }
        
        do {
            try viewContext.save()
            print("✅ Auto salvata con successo - tentativo di chiusura...")
            
            // Chiusura diretta e immediata
            DispatchQueue.main.async {
                self.dismiss()
                print("✅ Dismiss chiamato")
            }
            
        } catch {
            print("❌ Errore nel salvataggio: \(error)")
            isSaving = false
            
            if let nsError = error as NSError? {
                ErrorManager.shared.showError(
                    "Errore di salvataggio",
                    message: "Impossibile salvare l'auto: \(nsError.localizedDescription)",
                    type: .coreData
                )
            }
        }
    }
}

// Image Picker per selezionare foto
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    var completion: ((UIImage?) -> Void)? = nil
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
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.completion?(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
