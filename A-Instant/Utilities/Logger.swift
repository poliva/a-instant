import Foundation
import os.log

class Logger {
    static let shared = Logger()
    private let fileURL: URL
    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter
    
    private init() {
        // Set up the log directory path
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let logDirectory = cacheDirectory.appendingPathComponent("A-Instant", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }
        
        // Set up the log file path
        fileURL = logDirectory.appendingPathComponent("debug.log")
        
        // Configure date formatter for log entries
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // Log startup
        log("Logger initialized - path: \(fileURL.path)")
    }
    
    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        // Check if debug logging is enabled
        let shouldLog = UserDefaults.standard.bool(forKey: UserDefaultsKeys.enableDebugLogging)
        
        // Always log critical system messages regardless of setting
        let isCriticalMessage = message.contains("Application started") || 
                               message.contains("Application initialization complete") ||
                               message.contains("Error") || 
                               message.contains("Failed")
        
        // Skip logging if debug logging is disabled and this isn't a critical message
        if !shouldLog && !isCriticalMessage {
            return
        }
        
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(filename):\(line) \(function)] \(message)\n"
        
        // Print to console
        print(logMessage, terminator: "")
        
        // Write to file
        appendToLogFile(logMessage)
    }
    
    private func appendToLogFile(_ string: String) {
        do {
            // If file doesn't exist, create it
            if !fileManager.fileExists(atPath: fileURL.path) {
                try "".write(to: fileURL, atomically: true, encoding: .utf8)
            }
            
            // Get file handle for appending
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            fileHandle.seekToEndOfFile()
            
            // Append text
            if let data = string.data(using: .utf8) {
                fileHandle.write(data)
            }
            
            // Close the file
            fileHandle.closeFile()
        } catch {
            os_log("Failed to write to log file: %@", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
    
    func getLogFileContents() -> String {
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            return "Error reading log file: \(error.localizedDescription)"
        }
    }
    
    func getLogFileURL() -> URL {
        return fileURL
    }
    
    func clearLogs() {
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            log("Log file cleared")
        } catch {
            os_log("Failed to clear log file: %@", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
} 