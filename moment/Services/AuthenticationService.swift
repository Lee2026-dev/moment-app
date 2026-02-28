//
//  AuthenticationService.swift
//  moment
//
//  Created by Sisyphus on 2026/01/30.
//

import SwiftUI
import Combine

@MainActor
class AuthenticationService: ObservableObject {
    @Published private(set) var isCheckingAuth: Bool = true
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: UserProfile?
    @Published var cachedAvatarData: Data?    // local-first avatar cache
    @Published var aiSummarizeCount: Int = 0
    @Published var authError: String?
    
    static let shared = AuthenticationService()
    
    private init() {
        print("Initializing AuthenticationService")
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        Task {
            defer {
                self.isCheckingAuth = false
            }

            if await APIService.shared.isAuthenticated {
                await MainActor.run { self.isLoggedIn = true }
                await fetchCurrentUser()
            } else {
                await MainActor.run { 
                    self.isLoggedIn = false
                    self.currentUser = nil
                    self.aiSummarizeCount = 0
                }
            }
        }
    }
    
    func fetchCurrentUser() async {
        do {
            let profile: UserProfile = try await APIService.shared.request("/auth/me")
            self.currentUser = profile
            self.isLoggedIn = true
            await fetchUserStats()
            
            // Refresh avatar in background if remote key changed
            Task {
                await refreshAvatarCacheIfNeeded(for: profile.avatarUrl)
            }
            
            // Trigger sync after fetching user profile (successful session)
            Task {
                await SyncEngine.shared.sync()
            }
        } catch {
            print("Failed to fetch user profile: \(error)")
            // If 401, logout
            if let apiError = error as? APIError, case .unauthorized = apiError {
                signOut()
            }
        }
    }

    func refreshSessionIfNeeded() async {
        guard await APIService.shared.isAuthenticated else { return }
        await fetchCurrentUser()
    }

    func fetchUserStats() async {
        do {
            let stats: UserStatsResponse = try await APIService.shared.request("/auth/me/stats")
            self.aiSummarizeCount = stats.ai_summarize_count
        } catch {
            print("Failed to fetch user stats: \(error)")
            if let apiError = error as? APIError, case .unauthorized = apiError {
                signOut()
                return
            }
            self.aiSummarizeCount = 0
        }
    }
    
    func signIn(email: String, password: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("Attempting sign in for \(trimmedEmail)")
        authError = nil
        
        Task {
            do {
                let token = try await APIService.shared.login(email: trimmedEmail, password: trimmedPassword)
                
                await APIService.shared.setTokens(accessToken: token.access_token, refreshToken: token.refresh_token)
                await fetchCurrentUser()
                
            } catch {
                print("Sign in failed: \(error)")
                self.authError = error.localizedDescription
            }
        }
    }
    
    func signUp(name: String, email: String, password: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("Attempting sign up for \(trimmedEmail)")
        authError = nil
        
        Task {
            do {
                // Register
                let payload = RegisterRequest(email: trimmedEmail, password: trimmedPassword)
                let _: RegisterResponse = try await APIService.shared.request("/auth/register", method: "POST", body: payload)
                
                print("Sign up successful, logging in...")
                // Auto login after sign up
                signIn(email: trimmedEmail, password: trimmedPassword)
                
            } catch {
                print("Sign up failed: \(error)")
                self.authError = error.localizedDescription
            }
        }
    }
    
    func updateUserProfile(name: String?, avatarUrl: String?) async throws {
        struct UpdateProfileRequest: Encodable {
            let name: String?
            let avatar_url: String?
        }
        
        let payload = UpdateProfileRequest(name: name, avatar_url: avatarUrl)
        let profile: UserProfile = try await APIService.shared.request("/auth/me", method: "PATCH", body: payload)
        
        await MainActor.run {
            self.currentUser = profile
        }
        // Refresh avatar cache in background if key changed
        Task {
            await refreshAvatarCacheIfNeeded(for: profile.avatarUrl)
        }
    }
    
    func uploadProfileImage(data: Data) async throws -> String {
        let filename = "avatar_\(UUID().uuidString).png"
        let storageReq = StorageRequest(filename: filename, content_type: "image/png")
        let storageRes: StorageResponse = try await APIService.shared.request("/storage/presigned-url", method: "POST", body: storageReq)
        
        guard let uploadURL = URL(string: storageRes.upload_url) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, data: nil)
        }
        
        // Immediately warm the local cache with the freshly uploaded data
        let fileKey = storageRes.file_key
        AvatarCache.shared.save(data: data, forKey: fileKey)
        await MainActor.run { self.cachedAvatarData = data }
        
        return fileKey
    }
    
    // MARK: - Avatar Cache Refresh
    
    private func refreshAvatarCacheIfNeeded(for fileKey: String?) async {
        guard let fileKey else {
            // No avatar; clear cached data
            await MainActor.run { self.cachedAvatarData = nil }
            return
        }
        
        // 1. Serve from on-disk cache immediately
        if let cached = AvatarCache.shared.load(forKey: fileKey) {
            await MainActor.run { self.cachedAvatarData = cached }
            return  // Local hit — no network needed
        }
        
        // 2. Cache miss → fetch from backend redirect endpoint
        guard let url = URL(string: Secrets.backendURL + "/storage/file/" + fileKey) else { return }
        do {
            var req = URLRequest(url: url)
            // Attach auth token so the server-side auth check passes
            if let token = await APIService.shared.currentAccessToken {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, _) = try await URLSession.shared.data(for: req)
            guard !data.isEmpty else { return }
            // Persist to disk and publish
            AvatarCache.shared.save(data: data, forKey: fileKey)
            await MainActor.run { self.cachedAvatarData = data }
        } catch {
            print("Avatar fetch failed: \(error)")
        }
    }

    func signOut() {
        Task {
            await APIService.shared.logout()
            AvatarCache.shared.clearAll()
            self.isLoggedIn = false
            self.currentUser = nil
            self.cachedAvatarData = nil
            self.aiSummarizeCount = 0
        }
    }
}

// MARK: - AvatarCache

/// Simple file-system-backed cache for avatar images.
/// Keys are the Supabase storage `file_key` strings.
final class AvatarCache {
    static let shared = AvatarCache()
    private let cacheDir: URL
    
    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = base.appendingPathComponent("AvatarCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    private func fileURL(forKey key: String) -> URL {
        // Use a hash of the key as the filename to avoid path separator issues
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return cacheDir.appendingPathComponent(safe)
    }
    
    func save(data: Data, forKey key: String) {
        let url = fileURL(forKey: key)
        try? data.write(to: url, options: .atomic)
    }
    
    func load(forKey key: String) -> Data? {
        let url = fileURL(forKey: key)
        return try? Data(contentsOf: url)
    }
    
    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
}

// MARK: - Models

struct UserProfile: Decodable {
    let id: String
    let email: String
    let created_at: String?
    let loadedName: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case created_at
        case loadedName = "name"
        case avatarUrl = "avatar_url"
    }

    // Compatibility with existing UI which expects 'name'
    var name: String {
        if let n = loadedName, !n.isEmpty {
            return n
        }
        return email.components(separatedBy: "@").first ?? "User"
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
}

struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
}

struct UserStatsResponse: Decodable {
    let ai_summarize_count: Int
}

// Generic response for when we don't care about the body (or it's just a message)
struct RegisterResponse: Decodable {
    let message: String?
}

// MARK: - APIService (Moved here to fix build issues if file not added to target)

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case unauthorized
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response."
        case .serverError(let statusCode, let data):
            if let message = APIError.parseServerMessage(from: data) {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (\(statusCode)): \(HTTPURLResponse.localizedString(forStatusCode: statusCode))"
        case .decodingError(let error):
            return "Failed to decode server response: \(error.localizedDescription)"
        case .unauthorized:
            return "Session expired. Please log in again."
        }
    }

    private static func parseServerMessage(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }

        if let payload = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = payload as? [String: Any] {
            if let message = dict["message"] as? String, !message.isEmpty {
                return message
            }
            if let detail = dict["detail"] as? String, !detail.isEmpty {
                return detail
            }
            if let detailList = dict["detail"] as? [[String: Any]] {
                let messages = detailList.compactMap { $0["msg"] as? String }.filter { !$0.isEmpty }
                if !messages.isEmpty {
                    return messages.joined(separator: "; ")
                }
            }
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }

        return nil
    }
}

actor APIService {
    static let shared = APIService()
    
    private let baseURL = Secrets.backendURL
    private let service = "moment-service"
    private var refreshTask: Task<Bool, Never>?
    private var authToken: String? {
        get { KeychainHelper.standard.read(service: service, account: "auth-token") }
        set {
            if let value = newValue {
                KeychainHelper.standard.save(value, service: service, account: "auth-token")
            } else {
                KeychainHelper.standard.delete(service: service, account: "auth-token")
            }
        }
    }
    private var refreshToken: String? {
        get { KeychainHelper.standard.read(service: service, account: "refresh-token") }
        set {
            if let value = newValue {
                KeychainHelper.standard.save(value, service: service, account: "refresh-token")
            } else {
                KeychainHelper.standard.delete(service: service, account: "refresh-token")
            }
        }
    }
    
    private init() {}
    
    // MARK: - Auth
    
    var isAuthenticated: Bool {
        return authToken != nil || refreshToken != nil
    }
    
    func logout() {
        authToken = nil
        refreshToken = nil
    }
    
    func setToken(_ token: String) {
        authToken = token
    }

    func setTokens(accessToken: String, refreshToken: String) {
        authToken = accessToken
        self.refreshToken = refreshToken
    }

    func login(email: String, password: String) async throws -> TokenResponse {
        let payload = LoginRequest(email: email, password: password)
        return try await request("/auth/login", method: "POST", body: payload)
    }
    
    func getToken() -> String? {
        return authToken
    }
    
    var currentAccessToken: String? {
        return authToken
    }
    
    nonisolated func getTokenUserID() -> String? {
        // Simple JWT decoding (just extracting payload part) to get sub (user id)
        // This avoids async call to check currentUser or fetch /me
        // Assuming authToken is accessible via Keychain helper directly without Actor isolation issue?
        // Ah, authToken is private var on actor. We need to read keychain directly.
        guard let token = KeychainHelper.standard.read(service: "moment-service", account: "auth-token") else { return nil }
        
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        
        var base64String = segments[1]
        // Pad if needed
        let requiredLength = (4 * ceil(Double(base64String.count) / 4.0))
        let nbrPaddings = Int(requiredLength) - base64String.count
        if nbrPaddings > 0 {
            let padding = String(repeating: "=", count: nbrPaddings)
            base64String = base64String + padding
        }
        
        base64String = base64String.replacingOccurrences(of: "-", with: "+")
                                   .replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: base64String),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = json as? [String: Any],
              let sub = dict["sub"] as? String else {
            return nil
        }
        return sub
    }
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        let bodyData: Data?
        if let body = body {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                bodyData = try encoder.encode(body)
            } catch {
                throw APIError.networkError(error)
            }
        } else {
            bodyData = nil
        }

        if shouldAttachAuthorization(for: endpoint) {
            _ = await refreshAccessTokenIfNeeded(force: false)
        }
        
        do {
            let (data, httpResponse) = try await performRequest(url: url, endpoint: endpoint, method: method, bodyData: bodyData)

            if httpResponse.statusCode == 401, shouldAttachAuthorization(for: endpoint) {
                let didRefresh = await refreshAccessTokenIfNeeded(force: true)
                if didRefresh {
                    let (retryData, retryResponse) = try await performRequest(url: url, endpoint: endpoint, method: method, bodyData: bodyData)
                    return try decodeResponseData(retryData, response: retryResponse)
                }
                throw APIError.unauthorized
            }
            return try decodeResponseData(data, response: httpResponse)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func performRequest(
        url: URL,
        endpoint: String,
        method: String,
        bodyData: Data?
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        if shouldAttachAuthorization(for: endpoint), let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (data, httpResponse)
    }

    private func decodeResponseData<T: Decodable>(_ data: Data, response: HTTPURLResponse) throws -> T {
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(statusCode: response.statusCode, data: data)
        }

        do {
            if T.self == EmptyResponse.self {
                return try JSONDecoder().decode(T.self, from: "{}".data(using: .utf8)!)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                let formatterWithFraction = ISO8601DateFormatter()
                formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatterWithFraction.date(from: dateString) {
                    return date
                }

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }

            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingError(error)
        }
    }

    private func shouldAttachAuthorization(for endpoint: String) -> Bool {
        !endpoint.hasPrefix("/auth/login") &&
        !endpoint.hasPrefix("/auth/register") &&
        !endpoint.hasPrefix("/auth/refresh")
    }

    private func refreshAccessTokenIfNeeded(force: Bool) async -> Bool {
        if !force, let token = authToken, !isTokenExpiringSoon(token) {
            return true
        }

        if let existingTask = refreshTask {
            return await existingTask.value
        }

        let task = Task<Bool, Never> {
            defer { self.clearRefreshTask() }
            guard let token = self.refreshToken else { return false }

            do {
                let refreshed = try await self.refreshTokens(using: token)
                self.authToken = refreshed.access_token
                self.refreshToken = refreshed.refresh_token
                return true
            } catch {
                print("Token refresh failed: \(error)")
                self.authToken = nil
                self.refreshToken = nil
                return false
            }
        }

        refreshTask = task
        return await task.value
    }

    private func clearRefreshTask() {
        refreshTask = nil
    }

    private func refreshTokens(using token: String) async throws -> TokenResponse {
        guard let url = URL(string: baseURL + "/auth/refresh") else {
            throw APIError.invalidURL
        }

        struct RefreshRequest: Encodable {
            let refresh_token: String
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshRequest(refresh_token: token))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func isTokenExpiringSoon(_ token: String, leeway: TimeInterval = 300) -> Bool {
        guard let expiryDate = jwtExpirationDate(token: token) else { return true }
        return expiryDate.timeIntervalSinceNow <= leeway
    }

    private func jwtExpirationDate(token: String) -> Date? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }

        var payload = segments[1]
        let requiredLength = Int(4 * ceil(Double(payload.count) / 4.0))
        let paddingCount = requiredLength - payload.count
        if paddingCount > 0 {
            payload += String(repeating: "=", count: paddingCount)
        }

        payload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: Any],
              let exp = dict["exp"] as? TimeInterval else {
            return nil
        }

        return Date(timeIntervalSince1970: exp)
    }
}

// MARK: - Helpers

struct EmptyResponse: Decodable {}

class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}
    
    func save(_ data: Data, service: String, account: String) {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary
        
        // Add or Update
        let status = SecItemAdd(query, nil)
        if status == errSecDuplicateItem {
            let query = [
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecClass: kSecClassGenericPassword,
            ] as CFDictionary
            
            let attributesToUpdate = [kSecValueData: data] as CFDictionary
            SecItemUpdate(query, attributesToUpdate)
        }
    }
    
    func save(_ string: String, service: String, account: String) {
        if let data = string.data(using: .utf8) {
            save(data, service: service, account: account)
        }
    }
    
    func readData(service: String, account: String) -> Data? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        return result as? Data
    }
    
    func read(service: String, account: String) -> String? {
        if let data = readData(service: service, account: account) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func delete(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
        ] as CFDictionary
        
        SecItemDelete(query)
    }
}
//
//  SyncEngine.swift
//  moment
//
//  Created by Sisyphus on 2026/01/30.
//

import Foundation
import CoreData
import Combine

class SyncEngine: ObservableObject {
    static let shared = SyncEngine()
    
    @Published var isSyncing = false
    @Published var lastSyncError: String?
    
    private let defaults = UserDefaults.standard
    private let lastSyncedAtKey = "lastSyncedAt"
    
    private init() {}
    
    func sync() async {
        guard await APIService.shared.isAuthenticated else { return }
        guard !isSyncing else { return }
        
        await MainActor.run { isSyncing = true; lastSyncError = nil }
        
        defer {
            Task { @MainActor in isSyncing = false }
        }
        
        let context = PersistenceController.shared.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        
        do {
            try await context.perform {
                context.refreshAllObjects()
                let changes = self.gatherLocalChanges(in: context)
            }
            
            // Refactored flow to handle async properly
            try await self.performSync(context: context)
            
        } catch {
            print("Sync failed: \(error)")
            
            // Handle 401 unauthorized - token expired or invalid
            if let apiError = error as? APIError, case .unauthorized = apiError {
                await MainActor.run {
                    AuthenticationService.shared.signOut()
                }
            }
            
            await MainActor.run { lastSyncError = error.localizedDescription }
        }
    }
    
    private func performSync(context: NSManagedObjectContext) async throws {
        // 1. Upload Pending Media
         try await uploadMediaFiles(context: context)
        
        // 2. Gather Changes & Sync Metadata
        var payload: SyncRequest?
        var lastSyncedAt: Date?
        
        try context.performAndWait {
            lastSyncedAt = self.defaults.object(forKey: self.lastSyncedAtKey) as? Date
            let changes = self.gatherLocalChanges(in: context)
            payload = SyncRequest(last_synced_at: lastSyncedAt, changes: changes)
        }
        
        guard let requestPayload = payload else { return }
        
        let response: SyncResponse = try await APIService.shared.request("/sync", method: "POST", body: requestPayload)
        
        // 3. Process Response
        try await context.perform {
            self.processServerChanges(response.changes, in: context)
            self.markUploadedChangesAsSynced(requestPayload.changes, in: context)
            try context.save()
            self.defaults.set(response.last_synced_at, forKey: self.lastSyncedAtKey)
        }
    }
    
    private func uploadMediaFiles(context: NSManagedObjectContext) async throws {
        var imagesToUpload: [NoteImage] = []
        
        context.performAndWait {
            let request: NSFetchRequest<NoteImage> = NoteImage.fetchRequest()
            request.predicate = NSPredicate(format: "remoteURL == nil") 
            if let results = try? context.fetch(request) {
                imagesToUpload = results.filter { $0.imageData != nil || $0.localFilename != nil }
            }
        }
        
        for image in imagesToUpload {
            var data: Data?
            var filename = ""
            
            context.performAndWait {
                filename = image.localFilename ?? "\(UUID().uuidString).jpg"
                if let binary = image.imageData {
                    data = binary
                }
            }
            
            guard let fileData = data else { continue }
            
            let storageReq = StorageRequest(filename: filename, content_type: "image/jpeg")
            let storageRes: StorageResponse = try await APIService.shared.request("/storage/presigned-url", method: "POST", body: storageReq)
            
            try await uploadToURL(url: storageRes.upload_url, data: fileData, contentType: "image/jpeg")
            
            try await context.perform {
                image.remoteURL = storageRes.file_key
                image.localFilename = filename
                try? context.save()
            }
        }
    }
    
    private func uploadToURL(url: String, data: Data, contentType: String) async throws {
        guard let uploadURL = URL(string: url) else { return }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, data: nil)
        }
    }
    
    private func gatherLocalChanges(in context: NSManagedObjectContext) -> [String: EntityChanges] {
        var changes: [String: EntityChanges] = [:]
        
        // We need to fetch current user ID safely.
        // SyncEngine is running in a background context usually (inside perform), so accessing MainActor `AuthenticationService.shared.currentUser` directly is unsafe if not awaited.
        // However, `gatherLocalChanges` is synchronous.
        // Workaround: We rely on a cached userId in SyncEngine or fetch it from APIService (if thread safe) or pass it in.
        // But `AuthenticationService` (MainActor) calls `SyncEngine.shared.sync()`.
        // Let's modify `sync()` to pass the userId or cache it.
        
        // For now, to fix the build error, assume we capture it before calling gather.
        // Actually, `APIService` actor is async.
        // We can't await inside this synchronous function easily without significant refactor.
        
        // Quick Fix: Access the token from Keychain directly (via helper) -> decode JWT -> get sub? Too complex.
        // Better: Make SyncEngine store currentUserId when `sync()` is called.
        
        let currentUserId = APIService.shared.getTokenUserID() // Need to implement this helper in APIService if possible, or just hack it for now.
        
        // Notes
        var noteChanges = EntityChanges()
        let notesReq: NSFetchRequest<Note> = Note.fetchRequest()
        
        if let uid = currentUserId {
            notesReq.predicate = NSPredicate(format: "syncStatus != 0 AND (userId == %@ OR userId == nil)", uid)
        } else {
            notesReq.predicate = NSPredicate(format: "syncStatus != 0")
        }
        
        if let notes = try? context.fetch(notesReq) {
            for note in notes {
                // Auto-bind legacy notes
                if note.userId == nil, let uid = currentUserId {
                    note.userId = uid
                }
                
                if note.deletedAt != nil {
                    noteChanges.deleted.append(note.id?.uuidString ?? "")
                } else {
                    var noteDict: Dict = [:]
                    if let id = note.id?.uuidString { noteDict["id"] = id }
                    if let title = note.title { noteDict["title"] = title }
                    noteDict["content"] = note.content ?? "" // Default to empty string to avoid NOT NULL violation
                    noteDict["transcript"] = note.transcript ?? ""
                    noteDict["transcript_segments"] = (note.value(forKey: "transcriptSegments") as? String) ?? ""
                    
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    if let timestamp = note.timestamp { 
                        noteDict["created_at"] = isoFormatter.string(from: timestamp) 
                    }
                    if let updatedAt = note.updatedAt {
                        noteDict["updated_at"] = isoFormatter.string(from: updatedAt)
                    }
                    noteDict["is_favorite"] = note.isFavorite
                    noteDict["audio_url"] = note.audioURL ?? ""
                    if let parentNoteID = note.parentNoteID?.uuidString {
                        noteDict["parent_note_id"] = parentNoteID
                    }
                    
                    noteChanges.updated.append(noteDict)
                }
            }
        }
        changes["notes"] = noteChanges
        
        // Tags
        var tagChanges = EntityChanges()
        let tagsReq: NSFetchRequest<Tag> = Tag.fetchRequest()
        tagsReq.predicate = NSPredicate(format: "syncStatus != 0")
        if let tags = try? context.fetch(tagsReq) {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            for tag in tags {
                if tag.deletedAt != nil {
                    tagChanges.deleted.append(tag.id?.uuidString ?? "")
                } else {
                    var tagDict: Dict = [:]
                    if let id = tag.id?.uuidString { tagDict["id"] = id }
                    if let name = tag.name { tagDict["name"] = name }
                    if let color = tag.color { tagDict["color"] = color }
                    if let createdAt = tag.createdAt { tagDict["created_at"] = isoFormatter.string(from: createdAt) }
                    if let updatedAt = tag.updatedAt { tagDict["updated_at"] = isoFormatter.string(from: updatedAt) }
                    
                    tagChanges.updated.append(tagDict)
                }
            }
        }
        changes["tags"] = tagChanges
        
        // TodoItems
        var todoChanges = EntityChanges()
        let todosReq: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        todosReq.predicate = NSPredicate(format: "syncStatus != 0")
        if let todos = try? context.fetch(todosReq) {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            for todo in todos {
                if todo.deletedAt != nil {
                    todoChanges.deleted.append(todo.id?.uuidString ?? "")
                } else {
                    var todoDict: Dict = [:]
                    if let id = todo.id?.uuidString { todoDict["id"] = id }
                    if let text = todo.text { todoDict["text"] = text }
                    todoDict["is_completed"] = todo.isCompleted
                    todoDict["line_index"] = Int(todo.lineIndex)
                    if let deadline = todo.deadline { todoDict["deadline"] = isoFormatter.string(from: deadline) }
                    if let updatedAt = todo.updatedAt { todoDict["updated_at"] = isoFormatter.string(from: updatedAt) }
                    if let noteId = todo.parentNote?.id?.uuidString { todoDict["note_id"] = noteId }
                    
                    todoChanges.updated.append(todoDict)
                }
            }
        }
        changes["todo_items"] = todoChanges
        
        return changes
    }
    
    /// Parse ISO8601 date strings, handling both with and without fractional seconds
    private func parseISO8601Date(_ string: String) -> Date? {
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: string) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    
    private func processServerChanges(_ changes: [String: EntityChanges], in context: NSManagedObjectContext) {
        processNotes(changes["notes"], in: context)
        processTags(changes["tags"], in: context)
        processTodoItems(changes["todo_items"], in: context)
    }
    
    private func processNotes(_ entityChanges: EntityChanges?, in context: NSManagedObjectContext) {
        guard let entityChanges = entityChanges else { return }
        
        for noteDict in entityChanges.updated {
            guard let idString = noteDict["id"] as? String,
                  let id = UUID(uuidString: idString) else { continue }
            
            let serverUpdatedAt: Date? = {
                guard let updatedAtStr = noteDict["updated_at"] as? String else { return nil }
                return parseISO8601Date(updatedAtStr)
            }()
            
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let note: Note
            if let existing = try? context.fetch(request).first {
                if existing.syncStatus != 0,
                   let localUpdatedAt = existing.updatedAt,
                   let serverUpdatedAt,
                   localUpdatedAt > serverUpdatedAt {
                    // Keep newer local pending changes; don't let stale server payload overwrite them.
                    continue
                }
                note = existing
            } else {
                note = Note(context: context)
                note.id = id
                note.timestamp = Date() // Default for new notes; will be overwritten below if server provides created_at
            }
            
            if let title = noteDict["title"] as? String { note.title = title }
            if let content = noteDict["content"] as? String { note.content = content }
            if let transcript = noteDict["transcript"] as? String { note.transcript = transcript }
            if let transcriptSegments = noteDict["transcript_segments"] as? String, !transcriptSegments.isEmpty {
                note.setValue(transcriptSegments, forKey: "transcriptSegments")
            }
            if let audioURL = noteDict["audio_url"] as? String { note.audioURL = audioURL }
            if let parentNoteIDString = noteDict["parent_note_id"] as? String,
               let parentNoteID = UUID(uuidString: parentNoteIDString) {
                note.parentNoteID = parentNoteID
            } else {
                note.parentNoteID = nil
            }
            if let isFav = noteDict["is_favorite"] as? Bool {
                note.isFavorite = isFav
            }
            if let timestampStr = noteDict["created_at"] as? String,
               let timestamp = parseISO8601Date(timestampStr) {
                note.timestamp = timestamp
            }
            if let serverUpdatedAt {
                note.updatedAt = serverUpdatedAt
            }
            if let userIdStr = noteDict["user_id"] as? String { note.userId = userIdStr }
            
            note.syncStatus = 0
        }
        
        for idString in entityChanges.deleted {
            guard let id = UUID(uuidString: idString) else { continue }
            
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            if let note = try? context.fetch(request).first {
                note.deletedAt = Date()
            }
        }
    }
    
    private func processTags(_ entityChanges: EntityChanges?, in context: NSManagedObjectContext) {
        guard let entityChanges = entityChanges else { return }
        
        for tagDict in entityChanges.updated {
            guard let idString = tagDict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = tagDict["name"] as? String else { continue }
            
            let request: NSFetchRequest<Tag> = Tag.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let tag: Tag
            if let existing = try? context.fetch(request).first {
                tag = existing
            } else {
                tag = Tag(context: context)
                tag.id = id
                tag.createdAt = Date()
            }
            
            tag.name = name
            if let color = tagDict["color"] as? String { tag.color = color }
            if let updatedAtStr = tagDict["updated_at"] as? String,
               let updatedAt = parseISO8601Date(updatedAtStr) {
                tag.updatedAt = updatedAt
            }
            if let userIdStr = tagDict["user_id"] as? String { tag.userId = userIdStr }
            
            tag.syncStatus = 0
        }
        
        for idString in entityChanges.deleted {
            guard let id = UUID(uuidString: idString) else { continue }
            
            let request: NSFetchRequest<Tag> = Tag.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            if let tag = try? context.fetch(request).first {
                tag.deletedAt = Date()
            }
        }
    }
    
    private func processTodoItems(_ entityChanges: EntityChanges?, in context: NSManagedObjectContext) {
        guard let entityChanges = entityChanges else { return }
        
        for todoDict in entityChanges.updated {
            guard let idString = todoDict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let noteIdString = todoDict["note_id"] as? String,
                  let noteId = UUID(uuidString: noteIdString) else { continue }
            
            let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
            noteRequest.predicate = NSPredicate(format: "id == %@", noteId as CVarArg)
            guard let parentNote = try? context.fetch(noteRequest).first else { continue }
            
            let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let todo: TodoItem
            if let existing = try? context.fetch(request).first {
                todo = existing
            } else {
                todo = TodoItem(context: context)
                todo.id = id
                todo.parentNote = parentNote
            }
            
            if let text = todoDict["text"] as? String { todo.text = text }
            if let isCompleted = todoDict["is_completed"] as? Bool {
                todo.isCompleted = isCompleted
            }
            if let lineIndex = todoDict["line_index"] as? Int {
                todo.lineIndex = Int16(lineIndex)
            }
            if let deadlineStr = todoDict["deadline"] as? String,
               let deadline = parseISO8601Date(deadlineStr) {
                todo.deadline = deadline
            }
            if let updatedAtStr = todoDict["updated_at"] as? String,
               let updatedAt = parseISO8601Date(updatedAtStr) {
                todo.updatedAt = updatedAt
            }
            if let userIdStr = todoDict["user_id"] as? String { todo.userId = userIdStr }
            
            todo.syncStatus = 0
        }
        
        for idString in entityChanges.deleted {
            guard let id = UUID(uuidString: idString) else { continue }
            
            let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            if let todo = try? context.fetch(request).first {
                todo.deletedAt = Date()
            }
        }
    }
    
    private func markUploadedChangesAsSynced(_ uploadedChanges: [String: EntityChanges], in context: NSManagedObjectContext) {
        func markEntityAsSynced(entityName: String, changes: EntityChanges?) {
            guard let changes = changes else { return }
            
            for dict in changes.updated {
                guard let idString = dict["id"] as? String,
                      let id = UUID(uuidString: idString) else { continue }
                
                var sentUpdatedAt: Date?
                if let updatedAtString = dict["updated_at"] as? String {
                    sentUpdatedAt = parseISO8601Date(updatedAtString)
                }
                
                let req = NSFetchRequest<NSManagedObject>(entityName: entityName)
                req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                req.fetchLimit = 1
                
                guard let object = try? context.fetch(req).first else { continue }
                let syncStatus = object.value(forKey: "syncStatus") as? Int16 ?? 0
                guard syncStatus != 0 else { continue }
                
                // If object changed again after this payload was built, keep it pending.
                if let sentUpdatedAt,
                   let localUpdatedAt = object.value(forKey: "updatedAt") as? Date,
                   localUpdatedAt > sentUpdatedAt {
                    continue
                }
                
                object.setValue(Int16(0), forKey: "syncStatus")
            }
            
            for idString in changes.deleted {
                guard let id = UUID(uuidString: idString) else { continue }
                
                let req = NSFetchRequest<NSManagedObject>(entityName: entityName)
                req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                req.fetchLimit = 1
                
                guard let object = try? context.fetch(req).first else { continue }
                let syncStatus = object.value(forKey: "syncStatus") as? Int16 ?? 0
                guard syncStatus != 0 else { continue }
                
                object.setValue(Int16(0), forKey: "syncStatus")
            }
        }
        
        markEntityAsSynced(entityName: "Note", changes: uploadedChanges["notes"])
        markEntityAsSynced(entityName: "Tag", changes: uploadedChanges["tags"])
        markEntityAsSynced(entityName: "TodoItem", changes: uploadedChanges["todo_items"])
    }
}

// MARK: - DTOs

struct SyncRequest: Encodable {
    let last_synced_at: Date?
    let changes: [String: EntityChanges]
}

struct SyncResponse: Decodable {
    let changes: [String: EntityChanges]
    let last_synced_at: Date
}

struct EntityChanges {
    var created: [Dict] = []
    var updated: [Dict] = []
    var deleted: [String] = []
}

extension EntityChanges: Codable {
    enum CodingKeys: String, CodingKey {
        case created, updated, deleted
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.deleted = (try? container.decode([String].self, forKey: .deleted)) ?? []
        
        if let createdArray = try? container.decode([[String: AnyCodableValue]].self, forKey: .created) {
            self.created = createdArray.map { dict in
                dict.mapValues { $0.value }
            }
        } else {
            self.created = []
        }
        
        if let updatedArray = try? container.decode([[String: AnyCodableValue]].self, forKey: .updated) {
            self.updated = updatedArray.map { dict in
                dict.mapValues { $0.value }
            }
        } else {
            self.updated = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(deleted, forKey: .deleted)
        
        let createdArray = created.map { dict -> [String: AnyCodableValue] in
            dict.mapValues { AnyCodableValue($0) }
        }
        try container.encode(createdArray, forKey: .created)
        
        let updatedArray = updated.map { dict -> [String: AnyCodableValue] in
            dict.mapValues { AnyCodableValue($0) }
        }
        try container.encode(updatedArray, forKey: .updated)
    }
}

struct AnyCodableValue: Codable {
    let value: Any?
    
    init(_ value: Any?) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = nil
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else {
            self.value = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if value == nil {
            try container.encodeNil()
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let int16 = value as? Int16 {
            try container.encode(Int(int16))
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else {
            try container.encodeNil()
        }
    }
}

typealias Dict = [String: Any?]

struct StorageRequest: Encodable {
    let filename: String
    let content_type: String
}

struct StorageResponse: Decodable {
    let upload_url: String
    let file_key: String
}
