import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingSplash = true
    
    var body: some View {
        ZStack {
            if showingSplash {
                SplashView()
                    .transition(.opacity)
            } else if !hasCompletedOnboarding {
                OnboardingView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                HomeView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    showingSplash = false
                }
            }
        }
        .withErrorHandling() // Aggiungi gestione errori
    }
}

// Splash screen migliorata
struct SplashView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var logoRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo animato
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(scale * 1.2)
                    
                    Image(systemName: "car.fill")
                        .font(.system(size: 60, weight: .regular))
                        .foregroundColor(.blue)
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(logoRotation))
                }
                
                VStack(spacing: 12) {
                    Text("BullyCar")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .opacity(opacity)
                    
                    Text("Le tue auto, sotto controllo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .opacity(opacity * 0.8)
                }
            }
        }
        .onAppear {
            // Animazione logo
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                scale = 1.0
            }
            
            // Animazione testo
            withAnimation(.easeIn(duration: 0.6).delay(0.3)) {
                opacity = 1.0
            }
            
            // Rotazione sottile del logo
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                logoRotation = 360
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
