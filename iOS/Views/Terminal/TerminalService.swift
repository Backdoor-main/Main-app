//
//  TerminalService.swift
//  backdoor
//
//  Copyright © 2025 Backdoor LLC. All rights reserved.
//

import Foundation
import UIKit

enum TerminalError: Error {
    case invalidURL
    case networkError(String)
    case responseError(String)
    case sessionError(String)
    case parseError(String)
}

typealias TerminalResult<T> = Result<T, TerminalError>

class TerminalService {
    static let shared = TerminalService()
    
    private let baseURL: String
    private let apiKey: String
    private var sessionId: String?
    private var userId: String?
    private let logger = Logger.shared
    
    private init() {
        // Get values from user settings or use defaults
        self.baseURL = UserDefaults.standard.string(forKey: "terminal_server_url") ?? "https://backdoor-backend.onrender.com"
        self.apiKey = UserDefaults.standard.string(forKey: "terminal_api_key") ?? "your-api-key-here"
        
        logger.log("TerminalService initialized with URL: \(baseURL)", category: .network, type: .info)
        
        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func settingsDidChange() {
        // Update settings if they change
        let newURL = UserDefaults.standard.string(forKey: "terminal_server_url") ?? "https://backdoor-backend.onrender.com"
        let newKey = UserDefaults.standard.string(forKey: "terminal_api_key") ?? "your-api-key-here"
        
        // If settings changed, we should invalidate the current session
        if newURL != baseURL || newKey != apiKey {
            baseURL = newURL
            apiKey = newKey
            sessionId = nil
            logger.log("Terminal settings changed, session reset", category: .network, type: .info)
        }
    }
    
    /// Creates a new terminal session for the user
    /// - Parameter completion: Called with the session ID or an error
    func createSession(completion: @escaping (TerminalResult<String>) -> Void) {
        // Check if we already have a valid session
        if let existingSession = sessionId {
            // Validate existing session
            validateSession { result in
                switch result {
                case .success(_):
                    // Session is still valid
                    self.logger.log("Using existing terminal session", category: .network, type: .info)
                    completion(.success(existingSession))
                case .failure(_):
                    // Session is invalid, create a new one
                    self.logger.log("Terminal session expired, creating new one", category: .network, type: .info)
                    self.createNewSession(completion: completion)
                }
            }
        } else {
            // No existing session, create a new one
            self.logger.log("Creating new terminal session", category: .network, type: .info)
            createNewSession(completion: completion)
        }
    }
    
    private func createNewSession(completion: @escaping (TerminalResult<String>) -> Void) {
        guard let url = URL(string: "\(baseURL)/create-session") else {
            logger.log("Invalid URL for terminal session creation", category: .network, type: .error)
            completion(.failure(TerminalError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        // Include device identifier to ensure uniqueness
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let body: [String: Any] = ["userId": deviceId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.log("Network error creating terminal session: \(error.localizedDescription)", category: .network, type: .error)
                completion(.failure(TerminalError.networkError(error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                self.logger.log("No data received from terminal session creation", category: .network, type: .error)
                completion(.failure(TerminalError.responseError("No data received")))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorMessage = json["error"] as? String {
                        self.logger.log("Terminal session creation error: \(errorMessage)", category: .network, type: .error)
                        completion(.failure(TerminalError.responseError(errorMessage)))
                        return
                    }
                    
                    if let newSessionId = json["sessionId"] as? String {
                        self.sessionId = newSessionId
                        self.userId = json["userId"] as? String
                        self.logger.log("Terminal session created successfully", category: .network, type: .info)
                        completion(.success(newSessionId))
                    } else {
                        self.logger.log("Invalid terminal session response format", category: .network, type: .error)
                        completion(.failure(TerminalError.responseError("Invalid response format")))
                    }
                } else {
                    self.logger.log("Could not parse terminal session response", category: .network, type: .error)
                    completion(.failure(TerminalError.responseError("Could not parse response")))
                }
            } catch {
                self.logger.log("JSON parsing error in terminal session response: \(error.localizedDescription)", category: .network, type: .error)
                completion(.failure(TerminalError.parseError("JSON parsing error: \(error.localizedDescription)")))
            }
        }.resume()
    }
    
    private func validateSession(completion: @escaping (TerminalResult<Bool>) -> Void) {
        guard let sessionId = sessionId else {
            logger.log("No active terminal session to validate", category: .network, type: .error)
            completion(.failure(TerminalError.sessionError("No active session")))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/session") else {
            logger.log("Invalid URL for terminal session validation", category: .network, type: .error)
            completion(.failure(TerminalError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.addValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.log("Network error validating terminal session: \(error.localizedDescription)", category: .network, type: .error)
                completion(.failure(TerminalError.networkError(error.localizedDescription)))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                // Session is invalid
                self.sessionId = nil
                self.logger.log("Terminal session expired (HTTP \(httpResponse.statusCode))", category: .network, type: .warning)
                completion(.failure(TerminalError.sessionError("Session expired")))
                return
            }
            
            self.logger.log("Terminal session validated successfully", category: .network, type: .info)
            completion(.success(true))
        }.resume()
    }
    
    /// Executes a command in the user's terminal session
    /// - Parameters:
    ///   - command: The command to execute
    ///   - completion: Called with the command output or an error
    func executeCommand(_ command: String, completion: @escaping (TerminalResult<String>) -> Void) {
        logger.log("Executing terminal command: \(command)", category: .network, type: .info)
        
        // First ensure we have a valid session
        createSession { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessionId):
                self.executeCommandWithSession(command, sessionId: sessionId, completion: completion)
            case .failure(let error):
                self.logger.log("Failed to create session for command execution: \(error.localizedDescription)", category: .network, type: .error)
                completion(.failure(error))
            }
        }
    }
    
    private func executeCommandWithSession(_ command: String, sessionId: String, completion: @escaping (TerminalResult<String>) -> Void) {
        guard let url = URL(string: "\(baseURL)/execute-command") else {
            logger.log("Invalid URL for command execution", category: .network, type: .error)
            completion(.failure(TerminalError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.addValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        
        let body = ["command": command]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.log("Network error executing command: \(error.localizedDescription)", category: .network, type: .error)
                completion(.failure(TerminalError.networkError(error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                self.logger.log("No data received from command execution", category: .network, type: .error)
                completion(.failure(TerminalError.responseError("No data received")))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorMessage = json["error"] as? String {
                        self.logger.log("Command execution error: \(errorMessage)", category: .network, type: .error)
                        completion(.failure(TerminalError.responseError(errorMessage)))
                        return
                    }
                    
                    if let output = json["output"] as? String {
                        self.logger.log("Command executed successfully", category: .network, type: .info)
                        completion(.success(output))
                    } else {
                        self.logger.log("Invalid command response format", category: .network, type: .error)
                        completion(.failure(TerminalError.responseError("Invalid response format")))
                    }
                } else {
                    self.logger.log("Could not parse command response", category: .network, type: .error)
                    completion(.failure(TerminalError.parseError("Could not parse response")))
                }
            } catch {
                self.logger.log("JSON parsing error in command response: \(error.localizedDescription)", category: .network, type: .error)
                completion(.failure(TerminalError.parseError("JSON parsing error: \(error.localizedDescription)")))
            }
        }.resume()
    }
    
    /// Terminates the current session
    func endSession(completion: @escaping (TerminalResult<Void>) -> Void) {
        guard let sessionId = sessionId else {
            logger.log("No active terminal session to end", category: .network, type: .info)
            completion(.success(()))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/session") else {
            logger.log("Invalid URL for terminal session termination", category: .network, type: .error)
            completion(.failure(TerminalError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.addValue(sessionId, forHTTPHeaderField: "X-Session-Id")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.log("Network error ending terminal session: \(error.localizedDescription)", category: .network, type: .error)
                completion(.failure(TerminalError.networkError(error.localizedDescription)))
                return
            }
            
            self.sessionId = nil
            self.logger.log("Terminal session ended successfully", category: .network, type: .info)
            completion(.success(()))
        }.resume()
    }
}

// Legacy compatibility wrapper
class ProcessUtility {
    static let shared = ProcessUtility()
    private let logger = Logger.shared
    
    private init() {}
    
    /// Executes a shell command on the backend server and returns the output.
    /// - Parameters:
    ///   - command: The shell command to be executed.
    ///   - completion: A closure to be called with the command's output or an error message.
    func executeShellCommand(_ command: String, completion: @escaping (String?) -> Void) {
        logger.log("ProcessUtility executing command: \(command)", category: .system, type: .info)
        
        TerminalService.shared.executeCommand(command) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let output):
                self.logger.log("ProcessUtility command executed successfully", category: .system, type: .info)
                completion(output)
            case .failure(let error):
                self.logger.log("ProcessUtility command failed: \(error.localizedDescription)", category: .system, type: .error)
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
}
