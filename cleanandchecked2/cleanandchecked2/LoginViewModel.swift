//
//  LoginViewModel.swift
//  cleanandchecked2
//
//  Created by adam jonah on 8/19/24.
//
//
//  LoginViewModel.swift
//  cleanandchecked2
//
//  Created by adam jonah on 8/19/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import FirebaseCore

class LoginViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isUserAuthenticated = false
    @Published var userSession: FirebaseAuth.User?
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    private var currentNonce: String?
    
    override init() {
        super.init()
        self.userSession = Auth.auth().currentUser
        self.isUserAuthenticated = userSession != nil
    }
    
    func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            print("No user logged in")
            return
        }
        
        // Delete user data from Firestore
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).delete { error in
            if let error = error {
                print("Error deleting user data: \(error.localizedDescription)")
            } else {
                print("User data deleted successfully")
                
                // Delete the user account
                user.delete { error in
                    if let error = error {
                        print("Error deleting user account: \(error.localizedDescription)")
                    } else {
                        print("User account deleted successfully")
                        DispatchQueue.main.async {
                            self.isUserAuthenticated = false
                            self.userSession = nil
                        }
                    }
                }
            }
        }
    }

    func signOut() {
         do {
             try Auth.auth().signOut()
             GIDSignIn.sharedInstance.signOut()
             self.isUserAuthenticated = false
             self.userSession = nil
         } catch {
             print("Error signing out: \(error.localizedDescription)")
             self.errorMessage = error.localizedDescription
             self.showError = true
         }
     }
    
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
       
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError(
                        "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                    )
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
       
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
   
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("There is no root view controller!")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [unowned self] result, error in
            if let error = error {
                print("Error during Google sign-in: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.showError = true
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Failed to get ID token.")
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Error during Firebase sign-in: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    return
                }

                if let user = authResult?.user {
                    self.isUserAuthenticated = true
                    self.userSession = user
                    
                    // Save user data to Firestore if needed
                    let db = Firestore.firestore()
                    db.collection("users").document(user.uid).setData([
                        "email": user.email ?? "",
                        "name": user.displayName ?? ""
                    ], merge: true) { err in
                        if let err = err {
                            print("Error writing document: \(err)")
                        } else {
                            print("Document successfully written!")
                        }
                    }
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                print("Invalid state: A login callback was received, but no login request was sent.")
                self.errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                self.showError = true
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                self.errorMessage = "Unable to fetch identity token"
                self.showError = true
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                self.errorMessage = "Unable to serialize token string from data"
                self.showError = true
                return
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            Auth.auth().signIn(with: credential) { (authResult, error) in
                if let error = error {
                    print("Error during Firebase sign-in: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    return
                }
                
                if let user = authResult?.user {
                    self.isUserAuthenticated = true
                    self.userSession = user
                    
                    // Save user data to Firestore if needed
                    let db = Firestore.firestore()
                    db.collection("users").document(user.uid).setData([
                        "email": user.email ?? "",
                        "name": user.displayName ?? ""
                    ], merge: true) { err in
                        if let err = err {
                            print("Error writing document: \(err)")
                        } else {
                            print("Document successfully written!")
                        }
                    }
                }
            }
        }
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("Unable to get the key window")
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple errored: \(error)")
        self.errorMessage = error.localizedDescription
        self.showError = true
    }
}
