//
//  ContentView.swift
//  cleanandchecked2
//
//  Created by adam jonah on 8/19/24.
//

import SwiftUI
import GoogleSignInSwift
import AVFoundation
import Firebase
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import SafariServices


struct ContentView: View {
    @StateObject private var loginViewModel = LoginViewModel()
    @State private var isAnonymousMode = false


//    var body: some View {
//        Group {
//            if loginViewModel.isUserAuthenticated {
//                MainTabView()
//            } else {
//                LoginView()
//            }
//        }
//        .environmentObject(loginViewModel)
//    }
    var body: some View {
        Group {
            if loginViewModel.isUserAuthenticated || isAnonymousMode {
                MainTabView()
            } else {
                LoginView(isAnonymousMode: $isAnonymousMode)
            }
        }
        .environmentObject(loginViewModel)
    }
}

struct AppleSignInButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "applelogo")
                    .foregroundColor(.white)
                Text("Sign in with Apple")
                    .foregroundColor(.white)
            }
            .frame(width: 280, height: 55)
            .background(Color.black)
            .cornerRadius(8)
        }
    }
}
struct LoginView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    @State private var showingSafariView = false
    @Binding var isAnonymousMode: Bool

    
    var body: some View {
        VStack {
            Text("Welcome to Clean and Checked")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            Text("Create an account to:")
                .font(.headline)
                .padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("• Analyze food labels instantly")
                Text("• Save and track your food history")
                Text("• Get personalized health insights")
            }
            .padding(.bottom, 30)
            
            GoogleSignInButton(action: loginViewModel.signInWithGoogle)
                .frame(width: 280, height: 55)
                .cornerRadius(8)
                .shadow(color: .gray.opacity(0.4), radius: 3, x: 0, y: 2)
            
//            AppleSignInButton(action: loginViewModel.signInWithApple)
//                .padding(.top, 10)
//                .shadow(color: .gray.opacity(0.4), radius: 3, x: 0, y: 2)
            
            Button(action: {
                         isAnonymousMode = true
                     }) {
                         Text("Try Without Signing In")
                             .foregroundColor(.blue)
                             .padding()
                     }
                     
            
            HStack(spacing: 0) {
                Text("By creating an account, you agree to our ")
                Text("Terms of Service and Privacy Policy")
                    .foregroundColor(.blue)
                    .underline()
                    .onTapGesture {
                        showingSafariView = true
                    }
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .padding(.top, 20)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .alert(isPresented: $loginViewModel.showError) {
            Alert(title: Text("Error"), message: Text(loginViewModel.errorMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showingSafariView) {
            SafariView(url: URL(string: "https://regal-engine-a25.notion.site/Welcome-to-Clean-and-Checked-3c093ef08e784725a7c62d6bbd926f24?pvs=74")!)
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 1
    
    var body: some View {
        NavigationView {
            ZStack {
                // Content based on selected tab
                Group {
                    if selectedTab == 0 {
                        HistoryView()
                    } else if selectedTab == 1 {
                        CameraView()
                    } else if selectedTab == 2 {
                        SettingsView()
                    }
                }
                
                // Custom tab bar at the bottom
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $selectedTab)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // Removed .toolbar modifier
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: { selectedTab = 0 }) {
                VStack {
                    Image(systemName: "clock")
                    Text("History")
                }
            }
            Spacer()
            Button(action: { selectedTab = 1 }) {
                VStack {
                    Image(systemName: "camera")
                    Text("Camera")
                }
            }
            Spacer()
            Button(action: { selectedTab = 2 }) {
                VStack {
                    Image(systemName: "gear")
                    Text("Settings")
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

struct SquareOverlay: View {
    var body: some View {
        Rectangle()
            .stroke(Color.white, lineWidth: 2)
            .frame(width: 250, height: 250)
            .cornerRadius(20)
    }
}

struct CameraView: View {
    @StateObject private var cameraController = CameraController()
    @State private var showingResult = false
    @State private var analysis: PhotoAnalysis?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var capturedImageURL: URL?
    @State private var cameraError: String?

    var body: some View {
        ZStack {
            if cameraController.isCameraAvailable() {
                CameraPreviewView(camera: cameraController)
                
                SquareOverlay()
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                
                VStack {
                    Spacer()
                    Button(action: {
                        isLoading = true
                        captureAndAnalyzePhoto()
                    }) {
                        Image(systemName: "camera")
                            .font(.largeTitle)
                            .padding()
                            .background(Color.white.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 120)
                }
            } else {
                Text("Camera not available")
                    .foregroundColor(.red)
            }
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            cameraController.checkCameraPermission()
        }
        .sheet(isPresented: $showingResult) {
            if let analysis = analysis, let imageURL = capturedImageURL {
                ResultView(analysis: analysis, imageURL: imageURL)
            }
        }
        .alert(item: Binding(
            get: { errorMessage.map { ErrorWrapper(message: $0) } },
            set: { errorMessage = $0?.message }
        )) { error in
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .alert(item: Binding(
            get: { cameraError.map { ErrorWrapper(message: $0) } },
            set: { cameraError = $0?.message }
        )) { error in
            Alert(title: Text("Camera Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
    }
    
    func captureAndAnalyzePhoto() {
        cameraController.capturePhoto { imageData in
            saveImageToFirebase(imageData) { url in
                if let url = url {
                    self.capturedImageURL = url
                    sendURLForAnalysis(url) { result in
                        if let result = result {
                            self.analysis = result
                            self.showingResult = true
                            saveAnalysisToFirestore(imageURL: url, analysis: result)
                        } else {
                            self.errorMessage = "Failed to analyze the image. Please check the console for more details."
                        }
                        self.isLoading = false
                    }
                } else {
                    self.errorMessage = "Failed to upload the image. Please try again."
                    self.isLoading = false
                }
            }
        }
    }
}
//struct CameraView: View {
//    @StateObject private var cameraController = CameraController()
//    @State private var showingResult = false
//    @State private var analysis: PhotoAnalysis?
//    @State private var errorMessage: String?
//    @State private var isLoading = false
//    @State private var capturedImageURL: URL?
//    @State private var cameraError: String?
//
//    var body: some View {
//           ZStack {
//               if cameraController.isCameraAvailable() {
//                   CameraPreviewView(camera: cameraController)
//
//                   SquareOverlay()
//                       .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
//
//                   VStack {
//                       Spacer()
//                       Button(action: {
//                           isLoading = true
//                           captureAndAnalyzePhoto()
//                       }) {
//                           Image(systemName: "camera")
//                               .font(.largeTitle)
//                               .padding()
//                               .background(Color.white.opacity(0.7))
//                               .clipShape(Circle())
//                       }
//                       .padding(.bottom, 120)
//                   }
//               } else {
//                   Text("Camera not available")
//                       .foregroundColor(.red)
//               }
//
//               if isLoading {
//                   ProgressView()
//                       .scaleEffect(1.5)
//                       .progressViewStyle(CircularProgressViewStyle(tint: .white))
//               }
//           }
//           .edgesIgnoringSafeArea(.all)
//           .onAppear {
//               cameraController.checkCameraPermission()
//           }
//        .sheet(isPresented: $showingResult) {
//            if let analysis = analysis, let imageURL = capturedImageURL {
//                ResultView(analysis: analysis, imageURL: imageURL)
//            }
//        }
//        .alert(item: Binding(
//            get: { errorMessage.map { ErrorWrapper(message: $0) } },
//            set: { errorMessage = $0?.message }
//        )) { error in
//            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
//        }
//        .alert(item: Binding(
//            get: { cameraError.map { ErrorWrapper(message: $0) } },
//            set: { cameraError = $0?.message }
//        )) { error in
//            Alert(title: Text("Camera Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
//        }
//    }
//
//    func captureAndAnalyzePhoto() {
//        cameraController.capturePhoto { imageData in
//            saveImageToFirebase(imageData) { url in
//                if let url = url {
//                    self.capturedImageURL = url
//                    sendURLForAnalysis(url) { result in
//                        if let result = result {
//                            self.analysis = result
//                            self.showingResult = true
//                            saveAnalysisToFirestore(imageURL: url, analysis: result)
//                        } else {
//                            self.errorMessage = "Failed to analyze the image. Please check the console for more details."
//                        }
//                        self.isLoading = false
//                    }
//                } else {
//                    self.errorMessage = "Failed to upload the image. Please try again."
//                    self.isLoading = false
//                }
//            }
//        }
//    } }
struct ErrorWrapper: Identifiable {
    let id = UUID()
    let message: String
}

class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var cameraError: Error? // Add this line

    private let output = AVCapturePhotoOutput()
    private var completionHandler: ((Data) -> Void)?
    
    override init() {
        super.init()
        setupSession()
    }
    
    func isCameraAvailable() -> Bool {
         return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
     }
    
    
//    func checkCameraPermission() {
//        switch AVCaptureDevice.authorizationStatus(for: .video) {
//        case .authorized:
//            startSession()
//        case .notDetermined:
//            requestCameraAccessWithCustomMessage { granted in
//                if granted {
//                    self.startSession()
//                }
//            }
//        case .denied, .restricted:
//            requestCameraAccessWithCustomMessage { _ in }
//        @unknown default:
//            break
//        }
//    }
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            requestCameraPermission { granted in
                if granted {
                    self.startSession()
                }
            }
        case .denied, .restricted:
            // Handle the case where permission is denied
            print("Camera access is denied or restricted")
        @unknown default:
            break
        }
    }

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func setupSession() {
        do {
            session.beginConfiguration()
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw NSError(domain: "CameraError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get camera device"])
            }
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
        } catch {
            DispatchQueue.main.async {
                self.cameraError = error // Use the published property
            }
        }
    }
//
//    func checkCameraPermission() {
//        switch AVCaptureDevice.authorizationStatus(for: .video) {
//        case .authorized:
//            startSession()
//        case .notDetermined:
//            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
//                if granted {
//                    DispatchQueue.main.async {
//                        self?.startSession()
//                    }
//                }
//            }
//        case .denied, .restricted:
//            print("Camera permission denied")
//        @unknown default:
//            break
//        }
//    }
//
//    private func setupSession() {
//        session.beginConfiguration()
//
//        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
//              let input = try? AVCaptureDeviceInput(device: device) else {
//            print("Failed to set up camera")
//            return
//        }
//
//        if session.canAddInput(input) {
//            session.addInput(input)
//        }
//
//        if session.canAddOutput(output) {
//            session.addOutput(output)
//        }
//
//        session.commitConfiguration()
//    }
    
    func startSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    func capturePhoto(completion: @escaping (Data) -> Void) {
        self.completionHandler = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        completionHandler?(imageData)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraController
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
//
//struct SettingsView: View {
//    @EnvironmentObject var loginViewModel: LoginViewModel
//
//    var body: some View {
//        NavigationView {
//            List {
//                Button(action: {
//                    loginViewModel.signOut()
//                }) {
//                    Text("Sign Out")
//                        .foregroundColor(.red)
//                }
//            }
//            .navigationTitle("Settings")
//        }
//    }
//}


struct SettingsView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    @State private var showingAbout = false
    @State private var showingInstagram = false
    @State private var showingDeleteConfirmation = false

    
    var body: some View {
        NavigationView {
            List {
                Button(action: {
                    showingAbout = true
                }) {
                    Text("About Clean and Checked")
                }
                
                Button(action: {
                    showingInstagram = true
                }) {
                    Text("Follow us on Instagram")
                }
                
                Button(action: {
                    loginViewModel.signOut()
                }) {
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
                Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                Text("Delete Account")
                                    .foregroundColor(.red)
                            }
            }
            .navigationTitle("Settings")
            .alert(isPresented: $showingDeleteConfirmation) {
                     Alert(
                         title: Text("Delete Account"),
                         message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                         primaryButton: .destructive(Text("Delete")) {
                             loginViewModel.deleteAccount()
                         },
                         secondaryButton: .cancel()
                     )
                 }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingInstagram) {
                SafariView(url: URL(string: "https://www.instagram.com/cleanandchecked/")!)
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("About Clean and Checked")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Our Mission")
                    .font(.headline)
                
                Text("Clean and Checked is dedicated to helping you live a cleaner, healthier life. We believe that understanding what's in your food is the first step towards making better dietary choices.")
                
                Text("How to Use the App")
                    .font(.headline)
                
                Text("1. Take a picture of any ingredient list.")
                Text("2. Our AI analyzes the ingredients.")
                Text("3. Get instant feedback on what's healthy and what's not.")
                Text("4. Make informed decisions about your food choices.")
                
                Text("By using Clean and Checked, you're taking an active step towards a healthier lifestyle. We're here to support you on your journey to clean eating!")
            }
            .padding()
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
    }
}
struct ResultView: View {
    let analysis: PhotoAnalysis
    let imageURL: URL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(analysis.title)
                    .font(.title)
                    .padding()
                
                AsyncImage(url: imageURL) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 200)
                
                Text("Clean and Checked Score: \(analysis.score)")
                    .font(.headline)
                
                Text("Overall Sources:")
                    .font(.headline)
                ForEach(analysis.overallSources, id: \.self) { source in
                    Link(source, destination: URL(string: source) ?? URL(string: "https://www.example.com")!)
                        .font(.caption)
                }
                
                Text("Ingredient Analysis:")
                    .font(.headline)
                
                ForEach(analysis.ingredients) { ingredient in
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: ingredient.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(ingredient.isHealthy ? .green : .red)
                            Text(ingredient.name)
                                .font(.subheadline)
                        }
                        Text(ingredient.explanation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Sources:")
                            .font(.caption2)
                            .fontWeight(.bold)
                        ForEach(ingredient.sources, id: \.self) { source in
                            Link(source, destination: URL(string: source) ?? URL(string: "https://www.example.com")!)
                                .font(.caption2)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .padding()
        }
    }
}

struct PhotoAnalysis: Codable {
    let title: String
    let score: Int
    let ingredients: [IngredientAnalysis]
    let overallSources: [String]
}

struct IngredientAnalysis: Codable, Identifiable {
    let id: UUID
    let name: String
    let isHealthy: Bool
    let explanation: String
    let sources: [String]

    enum CodingKeys: String, CodingKey {
        case name, isHealthy, explanation, sources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        isHealthy = try container.decode(Bool.self, forKey: .isHealthy)
        explanation = try container.decode(String.self, forKey: .explanation)
        sources = try container.decode([String].self, forKey: .sources)
        id = UUID()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(isHealthy, forKey: .isHealthy)
        try container.encode(explanation, forKey: .explanation)
        try container.encode(sources, forKey: .sources)
    }
}

struct APIResponse: Codable {
    let analysis: PhotoAnalysis
}
func saveImageToFirebase(_ imageData: Data, completion: @escaping (URL?) -> Void) {
    guard let user = Auth.auth().currentUser else {
        completion(nil)
        return
    }
    
    let storage = Storage.storage()
    let imageRef = storage.reference().child("images/\(user.uid)/\(UUID().uuidString).jpg")
    
    imageRef.putData(imageData, metadata: nil) { metadata, error in
        guard error == nil else {
            print("Error uploading image: \(error!.localizedDescription)")
            completion(nil)
            return
        }
        
        imageRef.downloadURL { url, error in
            completion(url)
        }
    }
}
func sendURLForAnalysis(_ url: URL, completion: @escaping (PhotoAnalysis?) -> Void) {
    let functionUrl = URL(string: "https://us-central1-cleanandchecked.cloudfunctions.net/analyzeFood")!
    var request = URLRequest(url: functionUrl)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = ["image_url": url.absoluteString]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Network error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        guard let data = data else {
            print("No data received from the server")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        print("Received data from cloud function:", String(data: data, encoding: .utf8) ?? "Unable to convert data to string")
             
        do {
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(APIResponse.self, from: data)
            print("Parsed API Response:", apiResponse)
            DispatchQueue.main.async {
                completion(apiResponse.analysis)
            }
        } catch {
            print("Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Key '\(key)' not found:", context.debugDescription)
                case .valueNotFound(let value, let context):
                    print("Value '\(value)' not found:", context.debugDescription)
                case .typeMismatch(let type, let context):
                    print("Type '\(type)' mismatch:", context.debugDescription)
                case .dataCorrupted(let context):
                    print("Data corrupted:", context.debugDescription)
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON string:", jsonString)
            }
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }.resume()
}
func saveAnalysisToFirestore(imageURL: URL, analysis: PhotoAnalysis) {
    guard let user = Auth.auth().currentUser else { return }
    
    let db = Firestore.firestore()
    let data: [String: Any] = [
        "imageURL": imageURL.absoluteString,
        "title": analysis.title,
        "score": analysis.score,
        "ingredients": analysis.ingredients.map { ingredient in
            [
                "name": ingredient.name,
                "isHealthy": ingredient.isHealthy,
                "explanation": ingredient.explanation
            ]
        },
        "timestamp": FieldValue.serverTimestamp()
    ]
    
    print("Saving analysis to Firestore:", data)
    
    db.collection("users").document(user.uid).collection("analyses").addDocument(data: data) { error in
        if let error = error {
            print("Error saving analysis: \(error.localizedDescription)")
        } else {
            print("Analysis saved successfully")
        }
    }
}

struct HistoryView: View {
    @State private var analyses: [AnalysisItem] = []
    @State private var isLoading = false
    
    var body: some View {
        List(analyses) { item in
            NavigationLink(destination: AnalysisDetailView(item: item)) {
                HStack {
                    AsyncImage(url: URL(string: item.imageURL)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.timestamp.timestamp.dateValue(), style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("History")
        .onAppear(perform: fetchAnalyses)
    }
    
    func fetchAnalyses() {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).collection("analyses")
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                isLoading = false
                if let error = error {
                    print("Error fetching analyses: \(error.localizedDescription)")
                    return
                }
                
                analyses = snapshot?.documents.compactMap { document in
                    try? document.data(as: AnalysisItem.self)
                } ?? []
            }
    }
}
struct AnalysisItem: Identifiable, Codable {
    @DocumentID var id: String?
    let imageURL: String
    let title: String
    let score: Int?
    let ingredients: [IngredientAnalysis]
    let timestamp: TimestampCodable

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL
        case title
        case score
        case ingredients
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        imageURL = try container.decode(String.self, forKey: .imageURL)
        title = try container.decode(String.self, forKey: .title)
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        ingredients = try container.decode([IngredientAnalysis].self, forKey: .ingredients)
        timestamp = try container.decode(TimestampCodable.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(imageURL, forKey: .imageURL)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(timestamp, forKey: .timestamp)
    }
}
struct TimestampCodable: Codable {
    let timestamp: Timestamp

    init(_ timestamp: Timestamp) {
        self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let seconds = try container.decode(Int64.self)
        self.timestamp = Timestamp(seconds: seconds, nanoseconds: 0)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(timestamp.seconds)
    }
}


struct AnalysisDetailView: View {
    let item: AnalysisItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(item.title)
                    .font(.title)
                    .padding()
                
                AsyncImage(url: URL(string: item.imageURL)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 200)
                
                if let score = item.score {
                    Text("Clean and Checked Score: \(score)")
                        .font(.headline)
                } else {
                    Text("Score not available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Text("Ingredient Analysis:")
                    .font(.headline)
                
                ForEach(item.ingredients) { ingredient in
                    HStack {
                        Image(systemName: ingredient.isHealthy ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(ingredient.isHealthy ? .green : .red)
                        VStack(alignment: .leading) {
                            Text(ingredient.name)
                                .font(.subheadline)
                            Text(ingredient.explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                Text("Analyzed on: \(item.timestamp.timestamp.dateValue(), style: .date)")
                

                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Analysis Details")
    }
}
