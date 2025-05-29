import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var showingApp = false
    
    let pages = [
        OnboardingPage(
            icon: "car.fill",
            title: "Benvenuto in BullyCar",
            description: "L'app completa per gestire le tue automobili. Tieni traccia di tutto in un unico posto.",
            color: .blue
        ),
        OnboardingPage(
            icon: "wrench.and.screwdriver.fill",
            title: "Gestisci la Manutenzione",
            description: "Registra tutti gli interventi e imposta promemoria per non dimenticare mai tagliandi e revisioni.",
            color: .green
        ),
        OnboardingPage(
            icon: "doc.text.fill",
            title: "Archivia i Documenti",
            description: "Salva foto di libretto, assicurazione e altri documenti importanti direttamente nell'app.",
            color: .orange
        ),
        OnboardingPage(
            icon: "bell.fill",
            title: "Promemoria Intelligenti",
            description: "Ricevi notifiche per scadenze importanti basate su data o chilometraggio.",
            color: .red
        ),
        OnboardingPage(
            icon: "icloud.and.arrow.up.fill",
            title: "Backup Sicuro",
            description: "Esporta e importa i tuoi dati facilmente. Le tue informazioni sono sempre al sicuro.",
            color: .purple
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [pages[currentPage].color.opacity(0.1), pages[currentPage].color.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack(spacing: 0) {
                // Header con logo e skip
                HStack {
                    // Logo placeholder
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("BullyCar")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    // Skip button (solo se non è l'ultima pagina)
                    if currentPage < pages.count - 1 {
                        Button("Salta") {
                            completeOnboarding()
                        }
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Main content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? pages[currentPage].color : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
                    }
                }
                .padding(.vertical, 20)
                
                // Bottom buttons
                VStack(spacing: 16) {
                    if currentPage < pages.count - 1 {
                        // Next button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("Continua")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(pages[currentPage].color)
                            )
                        }
                    } else {
                        // Get started button
                        Button(action: {
                            completeOnboarding()
                        }) {
                            HStack {
                                Text("Inizia Subito")
                                    .fontWeight(.semibold)
                                Image(systemName: "checkmark")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [pages[currentPage].color, pages[currentPage].color.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                    }
                    
                    // Back button (se non è la prima pagina)
                    if currentPage > 0 {
                        Button("Indietro") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Piccola animazione di entrata
            withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                // Animation setup if needed
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }
}

// Singola pagina dell'onboarding
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon con animazione
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Image(systemName: page.icon)
                    .font(.system(size: 50, weight: .regular))
                    .foregroundColor(page.color)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.1), value: isAnimating)
            }
            
            VStack(spacing: 20) {
                // Title
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                // Description
                Text(page.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// Modello per le pagine
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
