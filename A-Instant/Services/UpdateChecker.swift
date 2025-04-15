import Foundation

/// A service that checks for application updates from GitHub releases
class UpdateChecker {
    private let githubRepoPath = "poliva/a-instant"
    private let githubApiUrl = "https://api.github.com/repos/poliva/a-instant/releases/latest"
    private var updateTimer: Timer?
    private let checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
    
    /// GitHub release response structure
    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlUrl: URL
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }
    
    /// Errors that can occur during update checking
    enum UpdateCheckerError: Error {
        case networkError(Error)
        case apiError(Int)
        case parsingError(Error)
        case noVersionFound
        case missingBundleInfo
    }
    
    deinit {
        stopPeriodicChecks()
    }
    
    /// Starts periodic update checks
    /// - Parameter showNoUpdatesAlert: Whether to show an alert when no updates are available
    func startPeriodicChecks(showNoUpdatesAlert: Bool = false) {
        stopPeriodicChecks() // Cancel any existing timer
        
        Logger.shared.log("Starting periodic update checks (interval: \(checkInterval) seconds)")
        
        // Create a repeating timer that fires every 24 hours
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForUpdates(completion: { result in
                // Only handle successful updates, silently ignore errors
                if case .success(let url) = result, let updateURL = url {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("UpdateAvailableNotification"),
                            object: nil,
                            userInfo: ["updateURL": updateURL]
                        )
                    }
                }
            })
        }
        
        // Make sure the timer continues running in the background
        updateTimer?.tolerance = 60 // 1 minute tolerance to allow better power management
        RunLoop.main.add(updateTimer!, forMode: .common)
        
        // Ensure the timer is maintained across sleep/wake cycles
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillWakeUp),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        Logger.shared.log("Periodic update checks started")
    }
    
    @objc private func applicationWillWakeUp(_ notification: Notification) {
        Logger.shared.log("System woke from sleep, ensuring update timer is active")
        // Trigger a check after wake up
        checkForUpdates { _ in }
        
        // Restart timer if needed
        if updateTimer == nil {
            startPeriodicChecks()
        }
    }
    
    /// Stops periodic update checks
    func stopPeriodicChecks() {
        if let timer = updateTimer {
            timer.invalidate()
            updateTimer = nil
            Logger.shared.log("Periodic update checks stopped")
        }
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    /// Check for updates and call the completion handler with the result
    /// - Parameter completion: Callback with Result containing the release URL if an update is available
    func checkForUpdates(completion: @escaping (Result<URL?, Error>) -> Void) {
        Logger.shared.log("Checking for updates...")
        
        guard let currentVersion = getCurrentVersion() else {
            Logger.shared.log("Failed to get current version")
            completion(.failure(UpdateCheckerError.missingBundleInfo))
            return
        }
        
        Logger.shared.log("Current version: \(currentVersion)")
        
        guard let url = URL(string: githubApiUrl) else {
            Logger.shared.log("Invalid GitHub API URL")
            completion(.failure(UpdateCheckerError.missingBundleInfo))
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle network errors
            if let error = error {
                Logger.shared.log("Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.networkError(error)))
                }
                return
            }
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.shared.log("Invalid HTTP response")
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.noVersionFound))
                }
                return
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                Logger.shared.log("API error: status code \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.apiError(httpResponse.statusCode)))
                }
                return
            }
            
            // Ensure we have data
            guard let data = data else {
                Logger.shared.log("No data received")
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.noVersionFound))
                }
                return
            }
            
            // Parse JSON
            do {
                let decoder = JSONDecoder()
                let release = try decoder.decode(GitHubRelease.self, from: data)
                
                // Extract version from tag name (remove leading 'v' if present)
                var latestVersion = release.tagName
                if latestVersion.starts(with: "v") {
                    latestVersion.removeFirst()
                }
                
                Logger.shared.log("Latest version: \(latestVersion)")
                
                // Compare versions
                if self.isVersionNewer(currentVersion: currentVersion, latestVersion: latestVersion) {
                    Logger.shared.log("Update available: \(latestVersion)")
                    DispatchQueue.main.async {
                        completion(.success(release.htmlUrl))
                    }
                } else {
                    Logger.shared.log("No update available")
                    DispatchQueue.main.async {
                        completion(.success(nil))
                    }
                }
            } catch {
                Logger.shared.log("JSON parsing error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.parsingError(error)))
                }
            }
        }.resume()
    }
    
    /// Get the current app version from the bundle
    /// - Returns: The current version string
    private func getCurrentVersion() -> String? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return version
    }
    
    /// Compare two version strings
    /// - Parameters:
    ///   - currentVersion: The current app version
    ///   - latestVersion: The latest version from GitHub
    /// - Returns: True if the latest version is newer
    private func isVersionNewer(currentVersion: String, latestVersion: String) -> Bool {
        // Simple string comparison for initial implementation
        // For more sophisticated comparison, a semantic versioning library could be used
        let currentParts = currentVersion.split(separator: ".").compactMap { Int($0) }
        let latestParts = latestVersion.split(separator: ".").compactMap { Int($0) }
        
        // Compare version components
        let maxComponents = max(currentParts.count, latestParts.count)
        for i in 0..<maxComponents {
            let current = i < currentParts.count ? currentParts[i] : 0
            let latest = i < latestParts.count ? latestParts[i] : 0
            
            if latest > current {
                return true
            } else if current > latest {
                return false
            }
        }
        
        // Versions are identical
        return false
    }
} 