import Foundation
import Combine
import os.log
import UIKit

/// Comprehensive crash reporting and error handling system
@MainActor
public class CrashReporter: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "FlexPort", category: "CrashReporter")
    
    @Published public private(set) var isEnabled: Bool = true
    @Published public private(set) var lastCrashReport: CrashReport?
    @Published public private(set) var errorCount: Int = 0
    
    private var errorReports: [ErrorReport] = []
    private var crashReports: [CrashReport] = []
    private var uncaughtExceptionHandler: (@convention(c) (NSException) -> Void)?
    
    // Publishers for crash events
    public let crashOccurred = PassthroughSubject<CrashReport, Never>()
    public let errorOccurred = PassthroughSubject<ErrorReport, Never>()
    
    // Configuration
    private let maxReportsInMemory = 100
    private let reportingQueue = DispatchQueue(label: "com.flexport.crashreporter", qos: .utility)
    private let fileManager = FileManager.default
    private lazy var reportsDirectory: URL = {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("CrashReports")
    }()
    
    // Device info for crash reports
    private lazy var deviceInfo: CrashDeviceInfo = {
        return CrashDeviceInfo(
            model: UIDevice.current.model,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            identifierForVendor: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        )
    }()
    
    // MARK: - Initialization
    
    public init() {
        setupCrashReporting()
        setupReportsDirectory()
        loadPreviousCrashReports()
    }
    
    deinit {
        cleanupCrashReporting()
    }
    
    // MARK: - Public Interface
    
    /// Enable or disable crash reporting
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        
        if enabled {
            setupCrashReporting()
        } else {
            cleanupCrashReporting()
        }
        
        logger.info("Crash reporting \(enabled ? "enabled" : "disabled")")
    }
    
    /// Report a handled error
    public func reportError(
        _ error: Error,
        context: String = "",
        severity: ErrorSeverity = .medium,
        additionalInfo: [String: Any] = [:]
    ) {
        guard isEnabled else { return }
        
        let errorReport = ErrorReport(
            id: UUID(),
            timestamp: Date(),
            error: error,
            context: context,
            severity: severity,
            additionalInfo: additionalInfo,
            stackTrace: Thread.callStackSymbols,
            deviceInfo: deviceInfo
        )
        
        recordError(errorReport)
    }
    
    /// Report a custom error with message
    public func reportError(
        message: String,
        context: String = "",
        severity: ErrorSeverity = .medium,
        additionalInfo: [String: Any] = [:]
    ) {
        let customError = CustomError(message: message)
        reportError(customError, context: context, severity: severity, additionalInfo: additionalInfo)
    }
    
    /// Report a performance issue
    public func reportPerformanceIssue(
        operation: String,
        duration: TimeInterval,
        threshold: TimeInterval,
        additionalInfo: [String: Any] = [:]
    ) {
        let performanceError = PerformanceError(
            operation: operation,
            duration: duration,
            threshold: threshold
        )
        
        var info = additionalInfo
        info["operation"] = operation
        info["duration_ms"] = duration * 1000
        info["threshold_ms"] = threshold * 1000
        info["performance_ratio"] = duration / threshold
        
        reportError(
            performanceError,
            context: "Performance monitoring",
            severity: duration > threshold * 2 ? .high : .medium,
            additionalInfo: info
        )
    }
    
    /// Get all error reports
    public func getErrorReports(limit: Int? = nil) -> [ErrorReport] {
        if let limit = limit {
            return Array(errorReports.suffix(limit))
        }
        return errorReports
    }
    
    /// Get all crash reports
    public func getCrashReports(limit: Int? = nil) -> [CrashReport] {
        if let limit = limit {
            return Array(crashReports.suffix(limit))
        }
        return crashReports
    }
    
    /// Export all reports as JSON
    public func exportReports() throws -> Data {
        let exportData = CrashReportExport(
            timestamp: Date(),
            deviceInfo: deviceInfo,
            crashReports: crashReports,
            errorReports: errorReports
        )
        
        return try JSONEncoder().encode(exportData)
    }
    
    /// Clear all reports
    public func clearReports() {
        reportingQueue.async { [weak self] in
            self?.errorReports.removeAll()
            self?.crashReports.removeAll()
            self?.clearReportsFromDisk()
            
            DispatchQueue.main.async {
                self?.errorCount = 0
                self?.lastCrashReport = nil
            }
        }
        
        logger.info("All crash reports cleared")
    }
    
    /// Generate detailed crash report summary
    public func generateSummaryReport() -> CrashSummaryReport {
        let last24Hours = Date().addingTimeInterval(-24 * 60 * 60)
        
        let recentErrors = errorReports.filter { $0.timestamp > last24Hours }
        let recentCrashes = crashReports.filter { $0.timestamp > last24Hours }
        
        let errorsBySeverity = Dictionary(grouping: recentErrors) { $0.severity }
        let errorsByType = Dictionary(grouping: recentErrors) { String(describing: type(of: $0.error)) }
        
        return CrashSummaryReport(
            generatedAt: Date(),
            totalErrors: errorReports.count,
            totalCrashes: crashReports.count,
            errorsLast24Hours: recentErrors.count,
            crashesLast24Hours: recentCrashes.count,
            errorsBySeverity: errorsBySeverity.mapValues { $0.count },
            errorsByType: errorsByType.mapValues { $0.count },
            mostCommonErrors: getMostCommonErrors(),
            deviceInfo: deviceInfo
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupCrashReporting() {
        guard isEnabled else { return }
        
        // Set up uncaught exception handler
        setupUncaughtExceptionHandler()
        
        // Set up signal handlers for crashes
        setupSignalHandlers()
        
        logger.info("Crash reporting initialized")
    }
    
    private func cleanupCrashReporting() {
        // Reset exception handler
        NSSetUncaughtExceptionHandler(nil)
        
        // Reset signal handlers to default
        signal(SIGABRT, SIG_DFL)
        signal(SIGILL, SIG_DFL)
        signal(SIGSEGV, SIG_DFL)
        signal(SIGFPE, SIG_DFL)
        signal(SIGBUS, SIG_DFL)
        signal(SIGPIPE, SIG_DFL)
    }
    
    private func setupUncaughtExceptionHandler() {
        uncaughtExceptionHandler = { [weak self] exception in
            self?.handleUncaughtException(exception)
        }
        
        NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)
    }
    
    private func setupSignalHandlers() {
        let signals = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE]
        
        for signalType in signals {
            signal(signalType) { [weak self] signal in
                self?.handleSignal(signal)
            }
        }
    }
    
    private func handleUncaughtException(_ exception: NSException) {
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            type: .exception,
            reason: exception.reason ?? "Unknown exception",
            stackTrace: exception.callStackSymbols,
            deviceInfo: deviceInfo,
            appState: getCurrentAppState()
        )
        
        recordCrash(crashReport)
    }
    
    private func handleSignal(_ signal: Int32) {
        let signalName = getSignalName(signal)
        
        let crashReport = CrashReport(
            id: UUID(),
            timestamp: Date(),
            type: .signal,
            reason: "Signal \(signal) (\(signalName))",
            stackTrace: Thread.callStackSymbols,
            deviceInfo: deviceInfo,
            appState: getCurrentAppState()
        )
        
        recordCrash(crashReport)
        
        // Re-raise the signal with default handler
        signal(signal, SIG_DFL)
        kill(getpid(), signal)
    }
    
    private func recordError(_ errorReport: ErrorReport) {
        reportingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Add to memory
            self.errorReports.append(errorReport)
            
            // Limit memory usage
            if self.errorReports.count > self.maxReportsInMemory {
                self.errorReports.removeFirst()
            }
            
            // Save to disk
            self.saveErrorReport(errorReport)
            
            // Update counters on main thread
            DispatchQueue.main.async {
                self.errorCount = self.errorReports.count
                self.errorOccurred.send(errorReport)
            }
            
            self.logger.error("Error reported: \(errorReport.error.localizedDescription)")
        }
    }
    
    private func recordCrash(_ crashReport: CrashReport) {
        reportingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Add to memory
            self.crashReports.append(crashReport)
            
            // Save to disk immediately
            self.saveCrashReport(crashReport)
            
            // Update on main thread
            DispatchQueue.main.async {
                self.lastCrashReport = crashReport
                self.crashOccurred.send(crashReport)
            }
            
            self.logger.critical("Crash reported: \(crashReport.reason)")
        }
    }
    
    private func setupReportsDirectory() {
        do {
            try fileManager.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create reports directory: \(error)")
        }
    }
    
    private func saveErrorReport(_ report: ErrorReport) {
        do {
            let filename = "error_\(report.id.uuidString).json"
            let fileURL = reportsDirectory.appendingPathComponent(filename)
            let data = try JSONEncoder().encode(report)
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save error report: \(error)")
        }
    }
    
    private func saveCrashReport(_ report: CrashReport) {
        do {
            let filename = "crash_\(report.id.uuidString).json"
            let fileURL = reportsDirectory.appendingPathComponent(filename)
            let data = try JSONEncoder().encode(report)
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save crash report: \(error)")
        }
    }
    
    private func loadPreviousCrashReports() {
        reportingQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try self.fileManager.contentsOfDirectory(at: self.reportsDirectory, includingPropertiesForKeys: nil)
                
                for file in files {
                    if file.lastPathComponent.hasPrefix("crash_") {
                        if let data = try? Data(contentsOf: file),
                           let crashReport = try? JSONDecoder().decode(CrashReport.self, from: data) {
                            self.crashReports.append(crashReport)
                        }
                    } else if file.lastPathComponent.hasPrefix("error_") {
                        if let data = try? Data(contentsOf: file),
                           let errorReport = try? JSONDecoder().decode(ErrorReport.self, from: data) {
                            self.errorReports.append(errorReport)
                        }
                    }
                }
                
                // Sort by timestamp
                self.crashReports.sort { $0.timestamp < $1.timestamp }
                self.errorReports.sort { $0.timestamp < $1.timestamp }
                
                DispatchQueue.main.async {
                    self.errorCount = self.errorReports.count
                    self.lastCrashReport = self.crashReports.last
                }
                
            } catch {
                self.logger.error("Failed to load previous reports: \(error)")
            }
        }
    }
    
    private func clearReportsFromDisk() {
        do {
            let files = try fileManager.contentsOfDirectory(at: reportsDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            logger.error("Failed to clear reports from disk: \(error)")
        }
    }
    
    private func getCurrentAppState() -> AppState {
        let memoryUsage = getMemoryUsage()
        
        return AppState(
            memoryUsage: memoryUsage,
            batteryLevel: UIDevice.current.batteryLevel,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: ProcessInfo.processInfo.thermalState.rawValue,
            backgroundTimeRemaining: UIApplication.shared.backgroundTimeRemaining
        )
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024 / 1024 // Convert to MB
        }
        
        return 0
    }
    
    private func getSignalName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGPIPE: return "SIGPIPE"
        default: return "UNKNOWN"
        }
    }
    
    private func getMostCommonErrors() -> [String: Int] {
        let errorTypes = errorReports.map { String(describing: type(of: $0.error)) }
        let counts = Dictionary(errorTypes.map { ($0, 1) }, uniquingKeysWith: +)
        
        return Dictionary(
            counts.sorted { $0.value > $1.value }
                  .prefix(10)
                  .map { ($0.key, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

// MARK: - Supporting Types

public struct CrashReport: Codable {
    public let id: UUID
    public let timestamp: Date
    public let type: CrashType
    public let reason: String
    public let stackTrace: [String]
    public let deviceInfo: CrashDeviceInfo
    public let appState: AppState
}

public enum CrashType: String, Codable, CaseIterable {
    case exception, signal, hang, memoryWarning
}

public struct ErrorReport: Codable {
    public let id: UUID
    public let timestamp: Date
    public let error: CodableError
    public let context: String
    public let severity: ErrorSeverity
    public let additionalInfo: [String: String] // Simplified for Codable
    public let stackTrace: [String]
    public let deviceInfo: CrashDeviceInfo
    
    public init(id: UUID, timestamp: Date, error: Error, context: String, severity: ErrorSeverity, additionalInfo: [String: Any], stackTrace: [String], deviceInfo: CrashDeviceInfo) {
        self.id = id
        self.timestamp = timestamp
        self.error = CodableError(error: error)
        self.context = context
        self.severity = severity
        self.additionalInfo = additionalInfo.compactMapValues { "\($0)" }
        self.stackTrace = stackTrace
        self.deviceInfo = deviceInfo
    }
}

public enum ErrorSeverity: String, Codable, CaseIterable {
    case low, medium, high, critical
}

public struct CrashDeviceInfo: Codable {
    public let model: String
    public let systemName: String
    public let systemVersion: String
    public let identifierForVendor: String
    public let locale: String
    public let timezone: String
    public let appVersion: String
    public let buildNumber: String
}

public struct AppState: Codable {
    public let memoryUsage: Double
    public let batteryLevel: Float
    public let isLowPowerModeEnabled: Bool
    public let thermalState: Int
    public let backgroundTimeRemaining: TimeInterval
}

public struct CrashReportExport: Codable {
    public let timestamp: Date
    public let deviceInfo: CrashDeviceInfo
    public let crashReports: [CrashReport]
    public let errorReports: [ErrorReport]
}

public struct CrashSummaryReport: Codable {
    public let generatedAt: Date
    public let totalErrors: Int
    public let totalCrashes: Int
    public let errorsLast24Hours: Int
    public let crashesLast24Hours: Int
    public let errorsBySeverity: [ErrorSeverity: Int]
    public let errorsByType: [String: Int]
    public let mostCommonErrors: [String: Int]
    public let deviceInfo: CrashDeviceInfo
}

// MARK: - Custom Error Types

public struct CustomError: Error, LocalizedError {
    public let message: String
    
    public var errorDescription: String? {
        return message
    }
}

public struct PerformanceError: Error, LocalizedError {
    public let operation: String
    public let duration: TimeInterval
    public let threshold: TimeInterval
    
    public var errorDescription: String? {
        return "Performance issue in \(operation): took \(duration * 1000)ms (threshold: \(threshold * 1000)ms)"
    }
}

// MARK: - Codable Error Wrapper

public struct CodableError: Codable {
    public let domain: String
    public let code: Int
    public let localizedDescription: String
    public let failureReason: String?
    public let recoverySuggestion: String?
    
    public init(error: Error) {
        if let nsError = error as NSError? {
            self.domain = nsError.domain
            self.code = nsError.code
            self.localizedDescription = nsError.localizedDescription
            self.failureReason = nsError.localizedFailureReason
            self.recoverySuggestion = nsError.localizedRecoverySuggestion
        } else {
            self.domain = "Unknown"
            self.code = 0
            self.localizedDescription = error.localizedDescription
            self.failureReason = nil
            self.recoverySuggestion = nil
        }
    }
}