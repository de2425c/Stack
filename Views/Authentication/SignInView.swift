import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var authService = AuthService()
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSignUp = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Back button
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                                .imageScale(.large)
                        }
                        .padding(.top, 20)
                        
                        Text("Sign in")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Enter your username and password")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        // Login Form
                        VStack(spacing: 16) {
                            TextField("Email", text: $email)
                                .textFieldStyle(CustomTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(CustomTextFieldStyle())
                            
                            Button(action: signIn) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Text("Sign in")
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .disabled(isLoading)
                            
                            // Sign up button
                            Button(action: { showingSignUp = true }) {
                                Text("Don't have an account? Sign up")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 32)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarItems(leading: Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            })
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
    }
    
    private func signIn() {
        isLoading = true
        Task {
            do {
                try await authService.signInWithEmail(email: email, password: password)
                DispatchQueue.main.async {
                    authViewModel.authState = .signedIn
                    dismiss()
                }
            } catch let error as AuthError {
                DispatchQueue.main.async {
                    errorMessage = error.message
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
} 