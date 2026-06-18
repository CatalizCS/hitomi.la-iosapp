// PrivacyLockView.swift
// HitomiReader
//
// Full-screen overlay to secure the application. Evaluates FaceID/TouchID or passcode.

import SwiftUI
import LocalAuthentication

struct PrivacyLockView: View {
    let onUnlock: () -> Void
    
    @State private var authError: String? = nil
    @State private var isAuthenticating = false
    
    var body: some View {
        ZStack {
            Color(hex: "0D0D0D").ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Lock Icon with glowing background
                ZStack {
                    Circle()
                        .fill(Color(hex: "FF2D78").opacity(0.15))
                        .frame(width: 120, height: 120)
                        .blur(radius: 8)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Color(hex: "FF2D78"))
                }
                .padding(.bottom, 8)
                
                VStack(spacing: 8) {
                    Text("App Locked")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Privacy lock is enabled to protect your reading content.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                if let error = authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                            .font(.headline)
                        Text("Unlock App")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color(hex: "FF2D78"))
                    .clipShape(Capsule())
                }
                .disabled(isAuthenticating)
                .buttonStyle(PressedScaleButtonStyle())
            }
        }
        .onAppear {
            authenticate()
        }
    }
    
    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        authError = nil
        
        let context = LAContext()
        var error: NSError?
        
        // Use deviceOwnerAuthentication so user can fall back to phone Passcode if biometrics aren't configured or fail
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Unlock Hitomi Reader to resume reading."
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    isAuthenticating = false
                    if success {
                        onUnlock()
                    } else {
                        if let error = authenticationError as? LAError {
                            switch error.code {
                            case .userCancel:
                                self.authError = "Authentication cancelled."
                            case .systemCancel:
                                self.authError = "System cancelled authentication."
                            default:
                                self.authError = "Failed to authenticate: \(error.localizedDescription)"
                            }
                        } else {
                            self.authError = "Authentication failed."
                        }
                    }
                }
            }
        } else {
            isAuthenticating = false
            self.authError = error?.localizedDescription ?? "FaceID/Passcode is not available on this device."
        }
    }
}

#Preview {
    PrivacyLockView(onUnlock: {})
}
