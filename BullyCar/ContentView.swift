import SwiftUI
import CoreData
import LocalAuthentication

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("biometricAuthEnabled") private var biometricAuthEnabled = false
    @StateObject private var authManager = BiometricAuthManager.shared
    @State private var showingSplash = true
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.9
    
    var body: some View {
        ZStack {
            if showingSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                // Content with fast smooth animations
                Group {
                    if !hasCompletedOnboarding {
                        OnboardingView()
                    } else if biometricAuthEnabled && !authManager.isAuthenticated {
                        BiometricAuthView()
                    } else {
                        HomeView()
                    }
                }
                .opacity(contentOpacity)
                .scaleEffect(contentScale)
                .animation(.easeOut(duration: 0.4), value: contentOpacity)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: contentScale)
            }
        }
        .onAppear {
            // Splash più veloce - solo 1 secondo
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingSplash = false
                }
                
                // Anima il contenuto immediatamente
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        contentOpacity = 1.0
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        contentScale = 1.0
                    }
                }
            }
        }
        .withErrorHandling()
    }
}

// Splash screen più veloce
struct SplashView: View {
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0
    @State private var logoRotation: Double = 0
    @State private var circleScale: CGFloat = 0.9
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.15),
                    Color.blue.opacity(0.08),
                    Color.blue.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo animato più veloce
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(circleScale)
                        .animation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                            value: circleScale
                        )
                    
                    Image(systemName: "car.fill")
                        .font(.system(size: 60, weight: .regular))
                        .foregroundColor(.blue)
                        .scaleEffect(scale)
                        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                VStack(spacing: 12) {
                    Text("BullyCar")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .opacity(opacity)
                        .scaleEffect(scale * 0.95)
                    
                    Text("Le tue auto, sotto controllo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .opacity(opacity * 0.8)
                        .scaleEffect(scale * 0.9)
                }
            }
        }
        .onAppear {
            // Animazioni più veloci
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                scale = 1.0
            }
            
            withAnimation(.easeIn(duration: 0.3).delay(0.1)) {
                opacity = 1.0
            }
            
            // Pulsazione più veloce
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                circleScale = 1.1
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
