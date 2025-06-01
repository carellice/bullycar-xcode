# 🚗 BullyCar

**L'app completa per gestire le tue automobili**

BullyCar è un'applicazione iOS nativa sviluppata in SwiftUI che ti permette di tenere traccia di tutto ciò che riguarda le tue auto: manutenzioni, documenti, promemoria e molto altro, tutto in un unico posto.

## ✨ Caratteristiche Principali

### 🚙 Gestione Auto
- **Registra le tue auto** con foto, marca, modello, anno, targa e chilometraggio
- **Visualizzazione elegante** con card personalizzate e targa europea realistica
- **Modifica rapida** delle informazioni dell'auto
- **Note personali** per ogni veicolo

### 🔧 Manutenzione Intelligente
- **Registra tutti gli interventi**: tagliandi, revisioni, bollo, assicurazione, cambio gomme
- **Interventi personalizzati** per esigenze specifiche
- **Cronologia completa** con filtri avanzati per tipo, anno e ricerca testuale
- **Costi e chilometraggio** sempre sotto controllo

### 🔔 Promemoria Avanzati
- **Promemoria automatici** basati su data o chilometraggio
- **Notifiche push** configurabili (1-30 giorni di preavviso)
- **Intervalli ricorrenti** (ogni X mesi/anni)
- **Dashboard promemoria** con livelli di urgenza

### 📁 Gestione Documenti
- **Archivia documenti importanti**: libretto, assicurazione, bollo, multe
- **Scatta foto** o importa PDF direttamente nell'app
- **Ricerca avanzata** per nome e tipo di documento
- **Visualizzatore integrato** per PDF e immagini

### 🔒 Sicurezza e Privacy
- **Autenticazione biometrica** (Face ID / Touch ID / Optic ID)
- **Protezione automatica** quando l'app va in background
- **Dati locali** - tutto rimane sul tuo dispositivo
- **Backup sicuri** in formato JSON criptato

### 🎨 Esperienza Utente
- **Design moderno** con supporto temi chiaro/scuro/automatico
- **Interfaccia italiana** completamente localizzata
- **Animazioni fluide** e feedback aptici
- **Onboarding guidato** per nuovi utenti

## 🛠 Tecnologie Utilizzate

- **Framework**: SwiftUI + UIKit (componenti specifici)
- **Database**: Core Data con sincronizzazione CloudKit ready
- **Architettura**: MVVM con ObservableObject
- **Notifiche**: UserNotifications Framework
- **Sicurezza**: LocalAuthentication Framework
- **Documenti**: PDFKit per visualizzazione PDF
- **Immagini**: PhotosUI per selezione foto

## 📋 Requisiti di Sistema

- **iOS**: 18.0 o superiore
- **Xcode**: 16.3 o superiore
- **Swift**: 5.0 o superiore
- **Dispositivi**: iPhone e iPad (Universal)

## 🚀 Installazione e Setup

### Clone del Repository
```bash
git clone https://github.com/carellice/bullycar-xcode.git
cd bullycar-xcode
```

### Configurazione Xcode
1. Apri `BullyCar.xcodeproj` in Xcode
2. Seleziona il tuo team di sviluppo in Signing & Capabilities
3. Modifica il Bundle Identifier se necessario
4. Compila ed esegui su simulatore o dispositivo

### Permessi Richiesti
L'app richiederà automaticamente i seguenti permessi:
- **Fotocamera**: Per scattare foto di documenti e auto
- **Libreria Foto**: Per selezionare immagini esistenti
- **Notifiche**: Per i promemoria di manutenzione
- **Face ID/Touch ID**: Per la sicurezza (opzionale)

## 📁 Struttura del Progetto

```
BullyCar/
├── 📱 App/
│   ├── BullyCarApp.swift           # Entry point dell'app
│   ├── ContentView.swift           # Vista principale con splash e auth
│   └── Info.plist                 # Configurazione app
├── 🗄️ Models/
│   ├── BullyCar.xcdatamodeld       # Core Data model
│   └── CoreDataExtensions.swift   # Estensioni per entità Core Data
├── 👁️ Views/
│   ├── HomeView.swift              # Schermata principale con lista auto
│   ├── CarDetailView.swift         # Dettaglio auto con tab
│   ├── AddCarView.swift            # Aggiunta/modifica auto
│   ├── AddMaintenanceView.swift    # Aggiunta manutenzioni
│   ├── OnboardingView.swift        # Introduzione per nuovi utenti
│   ├── SettingsView.swift          # Impostazioni app
│   ├── BiometricAuthView.swift     # Autenticazione biometrica
│   ├── DocumentViews.swift         # Visualizzazione documenti
│   ├── BackupManager.swift         # Gestione backup
│   └── Persistence.swift           # Controller Core Data
├── 🎛️ ViewModels/
│   └── [ViewModels per logica business]
├── 🔧 Utilities/
│   ├── NotificationManager.swift   # Gestione notifiche
│   ├── BiometricAuthManager.swift  # Gestione autenticazione
│   ├── ErrorManager.swift          # Gestione errori globali
│   ├── DataModificationTracker.swift # Tracking modifiche
│   ├── AppLifecycleManager.swift   # Gestione ciclo vita app
│   └── SettingsStateManager.swift  # Gestione stato impostazioni
└── 📦 Resources/
    └── [Asset e risorse]
```

## 🎯 Roadmap

### Versione 1.1
- [ ] Widget iOS per promemoria rapidi
- [ ] Sincronizzazione iCloud (Core Data + CloudKit)
- [ ] Export PDF dei report di manutenzione
- [ ] Statistiche avanzate e grafici
- [ ] OCR per riconoscimento automatico documenti

## 🤝 Contribuire

I contributi sono benvenuti! Per contribuire:

1. **Fork** il repository
2. **Crea** un branch per la tua feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** le tue modifiche (`git commit -m 'Add some AmazingFeature'`)
4. **Push** al branch (`git push origin feature/AmazingFeature`)
5. **Apri** una Pull Request

### Linee Guida per i Contributi
- Segui le convenzioni di codice Swift esistenti
- Aggiungi commenti per codice complesso
- Testa le modifiche su dispositivi reali
- Aggiorna la documentazione se necessario

## 🐛 Bug Report e Feature Request

Per segnalare bug o richiedere nuove funzionalità, apri una [issue](https://github.com/carellice/bullycar-xcode/issues) con:

**Per i Bug:**
- Descrizione dettagliata del problema
- Passi per riprodurre il bug
- Screenshot se applicabili
- Versione iOS e modello dispositivo

**Per le Feature:**
- Descrizione chiara della funzionalità
- Casi d'uso e benefici
- Mockup o esempi se disponibili

## 📄 Licenza

Questo progetto è rilasciato sotto licenza MIT. Vedi il file [LICENSE](LICENSE) per i dettagli.

## 👨‍💻 Autore

**Flavio Ceccarelli** - [@carellice](https://github.com/carellice)

---

**📧 Contatti**: Per domande o collaborazioni, apri una issue o contattami tramite GitHub.

**⭐ Ti piace BullyCar?** Lascia una stella al repository e condividilo con altri appassionati di auto!
