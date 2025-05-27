import SwiftUI
import PhotosUI

struct AddCarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Car da modificare (nil se nuova)
    var carToEdit: Car?
    
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
    
    var isEditing: Bool {
        carToEdit != nil
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
                    }
                    .padding(.vertical)
                }
                
                // Informazioni base
                Section(header: Text("Informazioni auto")) {
                    TextField("Nome auto", text: $name)
                    TextField("Marca", text: $brand)
                    TextField("Modello", text: $model)
                    
                    Picker("Anno", selection: $year) {
                        ForEach((1900...Calendar.current.component(.year, from: Date())), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                }
                
                // Dettagli
                Section(header: Text("Dettagli")) {
                    TextField("Targa", text: $plate)
                        .textCase(.uppercase)
                    
                    DatePicker("Data immatricolazione",
                             selection: $registrationDate,
                             displayedComponents: [.date])
                    
                    TextField("Chilometraggio", text: $mileage)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(isEditing ? "Modifica auto" : "Nuova auto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Salva") {
                        saveCar()
                    }
                    .disabled(name.isEmpty || brand.isEmpty || plate.isEmpty)
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
        withAnimation {
            let car: Car
            
            if let carToEdit = carToEdit {
                car = carToEdit
            } else {
                car = Car(context: viewContext)
                car.id = UUID()
                car.addDate = Date()
            }
            
            car.name = name
            car.brand = brand
            car.model = model
            car.year = Int32(year)
            car.plate = plate.uppercased()
            car.registrationDate = registrationDate
            car.mileage = Int32(mileage) ?? 0
            
            if let image = selectedImage {
                // Comprimi l'immagine per CloudKit (max 1MB per record)
                car.imageData = image.jpegData(compressionQuality: 0.5)
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                print("Errore nel salvataggio: \(error)")
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
