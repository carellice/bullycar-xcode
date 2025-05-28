import SwiftUI
import CloudKit

struct CloudKitTestView: View {
    @State private var iCloudStatus = "Controllo..."
    @State private var syncStatus = "Non verificato"
    @State private var lastSync = "Mai"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test Sincronizzazione iCloud")
                .font(.title)
                .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Stato iCloud:")
                        .fontWeight(.bold)
                    Text(iCloudStatus)
                }
                
                HStack {
                    Text("Sincronizzazione:")
                        .fontWeight(.bold)
                    Text(syncStatus)
                }
                
                HStack {
                    Text("Ultima sync:")
                        .fontWeight(.bold)
                    Text(lastSync)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button("Verifica iCloud") {
                checkiCloudStatus()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Test Sincronizzazione") {
                testSync()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .onAppear {
            checkiCloudStatus()
            
            // Ascolta le notifiche di sincronizzazione
            NotificationCenter.default.addObserver(
                forName: .NSPersistentStoreRemoteChange,
                object: nil,
                queue: .main
            ) { _ in
                syncStatus = "✅ Sincronizzato!"
                lastSync = Date().formatted()
            }
        }
    }
    
    func checkiCloudStatus() {
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    iCloudStatus = "✅ Disponibile"
                case .noAccount:
                    iCloudStatus = "❌ Nessun account"
                case .restricted:
                    iCloudStatus = "⚠️ Limitato"
                case .couldNotDetermine:
                    iCloudStatus = "❓ Sconosciuto"
                case .temporarilyUnavailable:
                    iCloudStatus = "⏳ Temporaneamente non disponibile"
                @unknown default:
                    iCloudStatus = "❌ Errore"
                }
                
                if let error = error {
                    iCloudStatus += " - \(error.localizedDescription)"
                }
            }
        }
    }
    
    func testSync() {
        syncStatus = "🔄 Test in corso..."
        
        // Crea un record di test
        let container = CKContainer(identifier: "iCloud.com.carellice.BullyCar")
        let database = container.privateCloudDatabase
        
        let record = CKRecord(recordType: "TestSync")
        record["timestamp"] = Date()
        record["device"] = UIDevice.current.name
        
        database.save(record) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    syncStatus = "❌ Errore: \(error.localizedDescription)"
                } else {
                    syncStatus = "✅ Test completato!"
                }
            }
        }
    }
}
