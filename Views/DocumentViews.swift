import SwiftUI
import UniformTypeIdentifiers

// Document Picker per importare PDF e altri documenti
struct DocumentPicker: UIViewControllerRepresentable {
    let completion: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Usa più tipi di file per compatibilità
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf,
            .image,
            .text,
            .data, // Tipo generico per file non riconosciuti
            UTType(filenameExtension: "pdf")! // Backup per PDF
        ])
        
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        print("📁 DocumentPicker inizializzato con tipi: PDF, immagini, testo, dati generici")
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                print("❌ Nessun URL selezionato")
                return
            }
            
            print("📄 File selezionato: \(url.lastPathComponent)")
            print("📄 Dimensione path: \(url.path)")
            print("📄 Estensione: \(url.pathExtension)")
            print("📄 Security scoped: \(url.startAccessingSecurityScopedResource())")
            
            // Verifica che il file esista e sia accessibile
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                print("📄 Dimensione file: \(fileSize) bytes (\(fileSize / 1024) KB)")
                
                // Verifica limite dimensione (10MB)
                if fileSize > 10 * 1024 * 1024 {
                    print("⚠️ File troppo grande: \(fileSize / 1024 / 1024) MB")
                }
                
                // Verifica che il file sia leggibile
                let testData = try Data(contentsOf: url)
                print("✅ File leggibile: \(testData.count) bytes letti")
                
                parent.completion(url)
                
            } catch {
                print("❌ Errore accesso file: \(error)")
                print("❌ Dettagli errore: \(error.localizedDescription)")
                
                // Prova con security scoped resource
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    do {
                        let testData = try Data(contentsOf: url)
                        print("✅ File leggibile con security scope: \(testData.count) bytes")
                        parent.completion(url)
                    } catch {
                        print("❌ Errore anche con security scope: \(error)")
                    }
                }
            }
            
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("📄 Selezione file annullata")
            parent.dismiss()
        }
    }
}

// Viewer per visualizzare documenti
struct DocumentViewerView: View {
    let document: Document
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if let data = document.data {
                    if document.type?.contains("image") == true {
                        // Mostra immagine
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    } else if document.type == "application/pdf" {
                        // Mostra PDF
                        PDFKitView(data: data)
                    } else {
                        // Altri tipi di file
                        VStack(spacing: 20) {
                            Image(systemName: "doc")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Anteprima non disponibile")
                                .font(.headline)
                            
                            Text("Usa il pulsante di condivisione per aprire in un'altra app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    Text("Documento non disponibile")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(document.name ?? "Documento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let data = document.data {
                ShareSheet(items: [data])
            }
        }
    }
}

// Vista per PDF usando PDFKit
import PDFKit

struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// Share Sheet per condividere documenti
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
