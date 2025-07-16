import Foundation
import Combine
import UIKit
import CoreData
import os.log

/// Privacy-first analytics engine with ethical data collection
@MainActor
public class AnalyticsEngine: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "FlexPort", category: "Analytics")
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var currentSession: PlayerSession?
    @Published public private(set) var isTrackingEnabled: Bool = true
    @Published public private(set) var isOnline: Bool = true
    
    private let localStorageManager: AnalyticsStorageManager
    private let networkManager: AnalyticsNetworkManager
    private let privacyManager: AnalyticsPrivacyManager
    private let behaviorAnalyzer: PlayerBehaviorAnalyzer
    
    private var eventQueue: [AnalyticsEvent] = []
    private var uploadTimer: Timer?
    private let maxQueueSize = 1000
    private let uploadInterval: TimeInterval = 30.0 // 30 seconds
    
    // MARK: - Initialization
    
    public init(coreDataManager: CoreDataManager, networkConfiguration: NetworkConfiguration) {
        self.localStorageManager = AnalyticsStorageManager(coreDataManager: coreDataManager)
        self.networkManager = AnalyticsNetworkManager(configuration: networkConfiguration)
        self.privacyManager = AnalyticsPrivacyManager()
        self.behaviorAnalyzer = PlayerBehaviorAnalyzer()
        
        setupAnalytics()
        startEventUploadTimer()
    }
    
    deinit {
        endCurrentSession()
        uploadTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    /// Start a new player session
    public func startSession(userId: UUID? = nil, gameState: GameStateSnapshot? = nil) {
        endCurrentSession() // End any existing session
        
        let deviceInfo = collectDeviceInfo()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        currentSession = PlayerSession(
            userId: userId,
            appVersion: appVersion,
            deviceInfo: deviceInfo,
            gameStateAtStart: gameState
        )
        
        trackEvent(.sessionStart, parameters: [
            "user_id": .string(userId?.uuidString ?? "anonymous"),
            "app_version": .string(appVersion),
            "device_model": .string(deviceInfo.deviceModel),
            "os_version": .string(deviceInfo.osVersion)
        ])
        
        logger.info("Analytics session started")
    }
    
    /// End the current player session
    public func endCurrentSession(gameState: GameStateSnapshot? = nil) {
        guard var session = currentSession else { return }
        
        session.endSession(gameState: gameState)
        
        trackEvent(.sessionEnd, parameters: [
            "session_duration": .double(session.duration),
            "events_count": .integer(session.events.count),
            "crash_occurred": .boolean(session.crashOccurred)
        ])
        
        // Save session to local storage
        localStorageManager.saveSession(session)
        
        // Update player behavior profile
        if let userId = session.userId {
            behaviorAnalyzer.updateProfile(from: session, userId: userId)
        }
        
        currentSession = nil
        logger.info("Analytics session ended - Duration: \(session.duration)s")
    }
    
    /// Track an analytics event
    public func trackEvent(_ eventType: EventType, parameters: [String: AnalyticsValue] = [:], gameState: GameStateSnapshot? = nil) {
        guard isTrackingEnabled else { return }
        guard privacyManager.canTrackEvent(eventType) else { return }
        
        guard let session = currentSession else {
            logger.warning("Attempted to track event \(eventType.rawValue) without active session")
            return
        }
        
        let event = AnalyticsEvent(
            eventType: eventType,
            parameters: parameters,
            gameState: gameState,
            sessionId: session.id
        )
        
        // Add to current session
        currentSession?.events.append(event)
        
        // Add to upload queue
        eventQueue.append(event)
        
        // Process immediately for critical events
        if isCriticalEvent(eventType) {
            uploadEvents()
        }
        
        logger.debug("Tracked event: \(eventType.rawValue)")
    }
    
    /// Track screen view
    public func trackScreen(_ screenName: String, parameters: [String: AnalyticsValue] = [:]) {
        var params = parameters
        params["screen_name"] = .string(screenName)
        trackEvent(.screenViewed, parameters: params)
    }
    
    /// Track feature usage
    public func trackFeatureUsage(_ featureName: String, parameters: [String: AnalyticsValue] = [:]) {
        var params = parameters
        params["feature_name"] = .string(featureName)
        trackEvent(.featureUsed, parameters: params)
    }
    
    /// Track error occurrence
    public func trackError(_ error: Error, context: String = "", parameters: [String: AnalyticsValue] = [:]) {
        var params = parameters
        params["error_domain"] = .string((error as NSError).domain)
        params["error_code"] = .integer((error as NSError).code)
        params["error_description"] = .string(error.localizedDescription)
        params["context"] = .string(context)
        
        trackEvent(.errorEncountered, parameters: params)
        
        currentSession?.crashOccurred = true
        logger.error("Error tracked: \(error.localizedDescription)")
    }
    
    /// Update privacy settings
    public func updateTrackingConsent(_ enabled: Bool) {
        isTrackingEnabled = enabled
        privacyManager.updateConsent(enabled)
        
        if !enabled {
            // Clear pending events and local storage if tracking disabled
            eventQueue.removeAll()
            localStorageManager.clearAllData()
        }
        
        logger.info("Analytics tracking consent updated: \(enabled)")
    }
    
    /// Force upload of pending events
    public func uploadEvents() {
        guard !eventQueue.isEmpty else { return }
        guard isOnline else {
            logger.info("Offline - deferring event upload")
            return
        }
        
        let eventsToUpload = Array(eventQueue.prefix(50)) // Upload in batches of 50
        
        Task {
            do {
                try await networkManager.uploadEvents(eventsToUpload)
                await MainActor.run {
                    eventQueue.removeFirst(min(50, eventQueue.count))
                    logger.info("Successfully uploaded \(eventsToUpload.count) events")
                }
            } catch {
                logger.error("Failed to upload events: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Player Behavior Analysis
    
    /// Get player behavior profile
    public func getPlayerBehaviorProfile(for playerId: UUID) -> PlayerBehaviorProfile? {
        return behaviorAnalyzer.getProfile(for: playerId)
    }
    
    /// Get retention analysis for a cohort
    public func getCohortAnalysis(for cohortName: String) -> PlayerCohort? {
        return behaviorAnalyzer.getCohort(named: cohortName)
    }
    
    /// Get funnel analysis
    public func getFunnelAnalysis(for funnelName: String) -> AnalyticsFunnel? {
        return behaviorAnalyzer.getFunnel(named: funnelName)
    }
    
    // MARK: - Private Methods
    
    private func setupAnalytics() {
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppForeground()
            }
            .store(in: &cancellables)
        
        // Monitor network connectivity
        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .sink { [weak self] notification in
                if let isOnline = notification.userInfo?["isOnline"] as? Bool {
                    self?.isOnline = isOnline
                    if isOnline {
                        self?.uploadEvents()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func startEventUploadTimer() {
        uploadTimer = Timer.scheduledTimer(withTimeInterval: uploadInterval, repeats: true) { [weak self] _ in
            self?.uploadEvents()
        }
    }
    
    private func handleAppBackground() {
        trackEvent(.sessionPause)
        uploadEvents() // Upload before going to background
    }
    
    private func handleAppForeground() {
        trackEvent(.sessionResume)
    }
    
    private func collectDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        let screen = UIScreen.main
        let locale = Locale.current
        let timeZone = TimeZone.current
        
        return DeviceInfo(
            deviceModel: device.model,
            osVersion: device.systemVersion,
            screenSize: "\(Int(screen.bounds.width))x\(Int(screen.bounds.height))",
            memoryGB: Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024),
            storageGB: getAvailableStorage(),
            batteryLevel: device.batteryLevel >= 0 ? Double(device.batteryLevel) : nil,
            networkType: getCurrentNetworkType(),
            timezone: timeZone.identifier,
            locale: locale.identifier
        )
    }
    
    private func getAvailableStorage() -> Double {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: path),
               let totalSize = attributes[.systemSize] as? NSNumber {
                return totalSize.doubleValue / (1024 * 1024 * 1024)
            }
        }
        return 0
    }
    
    private func getCurrentNetworkType() -> String {
        // This would typically use Network framework for detailed network info
        return "unknown"
    }
    
    private func isCriticalEvent(_ eventType: EventType) -> Bool {
        switch eventType {
        case .crashOccurred, .errorEncountered, .purchaseCompleted:
            return true
        default:
            return false
        }
    }
}

// MARK: - Supporting Classes

/// Manages local storage of analytics data
private class AnalyticsStorageManager {
    private let coreDataManager: CoreDataManager
    private let logger = Logger(subsystem: "FlexPort", category: "AnalyticsStorage")
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    func saveSession(_ session: PlayerSession) {
        // Implementation would save to Core Data
        logger.info("Session saved to local storage")
    }
    
    func clearAllData() {
        // Implementation would clear all analytics data
        logger.info("Analytics data cleared")
    }
}

/// Manages network uploads of analytics data
private class AnalyticsNetworkManager {
    private let configuration: NetworkConfiguration
    private let logger = Logger(subsystem: "FlexPort", category: "AnalyticsNetwork")
    
    init(configuration: NetworkConfiguration) {
        self.configuration = configuration
    }
    
    func uploadEvents(_ events: [AnalyticsEvent]) async throws {
        // Implementation would upload to analytics server
        logger.info("Uploading \(events.count) events")
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

/// Manages privacy and consent for analytics
private class AnalyticsPrivacyManager {
    private var hasConsent = true
    private let sensitiveEvents: Set<EventType> = [
        .purchaseCompleted,
        .errorEncountered,
        .crashOccurred
    ]
    
    func updateConsent(_ hasConsent: Bool) {
        self.hasConsent = hasConsent
    }
    
    func canTrackEvent(_ eventType: EventType) -> Bool {
        guard hasConsent else { return false }
        
        // Additional privacy checks could be added here
        return true
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("NetworkStatusChanged")
}