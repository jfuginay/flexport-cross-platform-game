import Foundation
import Combine
import SwiftUI
import os.log

// MARK: - Analytics Dashboard Models

/// Comprehensive analytics dashboard for data-driven optimization
@MainActor
public class AnalyticsDashboard: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "FlexPort", category: "AnalyticsDashboard")
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var dashboards: [Dashboard] = []
    @Published public private(set) var activeWidgets: [DashboardWidget] = []
    @Published public private(set) var metrics: [MetricSummary] = []
    @Published public private(set) var insights: [DataInsight] = []
    @Published public private(set) var recommendations: [OptimizationRecommendation] = []
    @Published public private(set) var isLoading = false
    
    private let analyticsEngine: AnalyticsEngine
    private let playerBehaviorAnalyzer: PlayerBehaviorAnalyzer
    private let abTestingManager: ABTestingManager
    private let retentionManager: RetentionManager
    private let monetizationManager: EthicalMonetizationManager
    private let dataProcessor: DataProcessor
    private let insightEngine: InsightEngine
    
    // MARK: - Initialization
    
    public init(analyticsEngine: AnalyticsEngine,
                playerBehaviorAnalyzer: PlayerBehaviorAnalyzer,
                abTestingManager: ABTestingManager,
                retentionManager: RetentionManager,
                monetizationManager: EthicalMonetizationManager) {
        self.analyticsEngine = analyticsEngine
        self.playerBehaviorAnalyzer = playerBehaviorAnalyzer
        self.abTestingManager = abTestingManager
        self.retentionManager = retentionManager
        self.monetizationManager = monetizationManager
        self.dataProcessor = DataProcessor()
        self.insightEngine = InsightEngine()
        
        setupDashboards()
        logger.info("Analytics Dashboard initialized")
    }
    
    // MARK: - Dashboard Management
    
    /// Get all available dashboards
    public func getAvailableDashboards() -> [Dashboard] {
        return dashboards
    }
    
    /// Get dashboard by ID
    public func getDashboard(_ dashboardId: String) -> Dashboard? {
        return dashboards.first { $0.dashboardId == dashboardId }
    }
    
    /// Refresh dashboard data
    public func refreshDashboard(_ dashboardId: String) async {
        isLoading = true
        
        do {
            guard let dashboard = getDashboard(dashboardId) else {
                throw DashboardError.dashboardNotFound
            }
            
            // Update metrics for dashboard widgets
            for widget in dashboard.widgets {
                await updateWidgetData(widget)
            }
            
            // Generate new insights
            let newInsights = await generateInsights(for: dashboard)
            insights = newInsights
            
            // Generate optimization recommendations
            let newRecommendations = await generateRecommendations(for: dashboard)
            recommendations = newRecommendations
            
            logger.info("Dashboard \(dashboardId) refreshed successfully")
            
        } catch {
            logger.error("Failed to refresh dashboard: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Get real-time metrics for a dashboard
    public func getRealTimeMetrics(_ dashboardId: String) -> [MetricSummary] {
        guard let dashboard = getDashboard(dashboardId) else { return [] }
        
        return dashboard.widgets.compactMap { widget in
            generateMetricSummary(for: widget)
        }
    }
    
    // MARK: - Widget Management
    
    /// Add widget to dashboard
    public func addWidget(_ widget: DashboardWidget, to dashboardId: String) {
        guard let dashboardIndex = dashboards.firstIndex(where: { $0.dashboardId == dashboardId }) else {
            return
        }
        
        dashboards[dashboardIndex].widgets.append(widget)
        activeWidgets.append(widget)
        
        // Refresh widget data
        Task {
            await updateWidgetData(widget)
        }
    }
    
    /// Remove widget from dashboard
    public func removeWidget(_ widgetId: String, from dashboardId: String) {
        guard let dashboardIndex = dashboards.firstIndex(where: { $0.dashboardId == dashboardId }) else {
            return
        }
        
        dashboards[dashboardIndex].widgets.removeAll { $0.widgetId == widgetId }
        activeWidgets.removeAll { $0.widgetId == widgetId }
    }
    
    /// Update widget configuration
    public func updateWidget(_ widgetId: String, configuration: WidgetConfiguration) {
        if let widgetIndex = activeWidgets.firstIndex(where: { $0.widgetId == widgetId }) {
            activeWidgets[widgetIndex].configuration = configuration
            
            Task {
                await updateWidgetData(activeWidgets[widgetIndex])
            }
        }
    }
    
    // MARK: - Data Export
    
    /// Export dashboard data
    public func exportDashboardData(_ dashboardId: String, format: ExportFormat) async -> Data? {
        guard let dashboard = getDashboard(dashboardId) else { return nil }
        
        let exportData = DashboardExport(
            dashboard: dashboard,
            metrics: metrics,
            insights: insights,
            recommendations: recommendations,
            exportDate: Date(),
            format: format
        )
        
        return try? await dataProcessor.exportData(exportData, format: format)
    }
    
    /// Schedule automated report
    public func scheduleAutomatedReport(_ schedule: ReportSchedule) {
        // Implementation would set up automated report generation
        logger.info("Scheduled automated report: \(schedule.name)")
    }
    
    // MARK: - Private Methods
    
    private func setupDashboards() {
        dashboards = [
            createOverviewDashboard(),
            createPlayerBehaviorDashboard(),
            createMonetizationDashboard(),
            createRetentionDashboard(),
            createABTestingDashboard(),
            createPerformanceDashboard()
        ]
        
        // Collect all active widgets
        activeWidgets = dashboards.flatMap { $0.widgets }
    }
    
    private func updateWidgetData(_ widget: DashboardWidget) async {
        switch widget.widgetType {
        case .metric:
            await updateMetricWidget(widget)
        case .chart:
            await updateChartWidget(widget)
        case .table:
            await updateTableWidget(widget)
        case .funnel:
            await updateFunnelWidget(widget)
        case .heatmap:
            await updateHeatmapWidget(widget)
        case .cohort:
            await updateCohortWidget(widget)
        }
    }
    
    private func updateMetricWidget(_ widget: DashboardWidget) async {
        // Implementation would fetch and update metric data
        logger.debug("Updated metric widget: \(widget.title)")
    }
    
    private func updateChartWidget(_ widget: DashboardWidget) async {
        // Implementation would fetch and update chart data
        logger.debug("Updated chart widget: \(widget.title)")
    }
    
    private func updateTableWidget(_ widget: DashboardWidget) async {
        // Implementation would fetch and update table data
        logger.debug("Updated table widget: \(widget.title)")
    }
    
    private func updateFunnelWidget(_ widget: DashboardWidget) async {
        // Implementation would fetch funnel analysis data
        logger.debug("Updated funnel widget: \(widget.title)")
    }
    
    private func updateHeatmapWidget(_ widget: DashboardWidget) async {
        // Implementation would fetch heatmap data
        logger.debug("Updated heatmap widget: \(widget.title)")
    }
    
    private func updateCohortWidget(_ widget: DashboardWidget) async {
        // Implementation would fetch cohort analysis data
        logger.debug("Updated cohort widget: \(widget.title)")
    }
    
    private func generateMetricSummary(for widget: DashboardWidget) -> MetricSummary? {
        // Generate metric summary based on widget configuration
        switch widget.widgetType {
        case .metric:
            return MetricSummary(
                metricId: widget.widgetId,
                name: widget.title,
                value: 0.0, // Would calculate actual value
                unit: "count",
                change: MetricChange(value: 0.0, period: .daily, trend: .stable),
                status: .normal,
                lastUpdated: Date()
            )
        default:
            return nil
        }
    }
    
    private func generateInsights(for dashboard: Dashboard) async -> [DataInsight] {
        return await insightEngine.generateInsights(dashboard: dashboard)
    }
    
    private func generateRecommendations(for dashboard: Dashboard) async -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        // Analyze current metrics and suggest optimizations
        for widget in dashboard.widgets {
            let widgetRecommendations = await analyzeWidgetForOptimizations(widget)
            recommendations.append(contentsOf: widgetRecommendations)
        }
        
        return recommendations
    }
    
    private func analyzeWidgetForOptimizations(_ widget: DashboardWidget) async -> [OptimizationRecommendation] {
        // Implementation would analyze widget data and suggest optimizations
        return []
    }
    
    // MARK: - Dashboard Creation
    
    private func createOverviewDashboard() -> Dashboard {
        let widgets = [
            DashboardWidget(
                widgetId: "total_players",
                title: "Total Players",
                description: "Total number of registered players",
                widgetType: .metric,
                dataSource: .analytics,
                configuration: WidgetConfiguration(
                    metricType: "total_players",
                    timeRange: .last30Days,
                    groupBy: nil,
                    filters: [:]
                )
            ),
            DashboardWidget(
                widgetId: "daily_active_users",
                title: "Daily Active Users",
                description: "Number of daily active users over time",
                widgetType: .chart,
                dataSource: .analytics,
                configuration: WidgetConfiguration(
                    metricType: "daily_active_users",
                    timeRange: .last30Days,
                    groupBy: .day,
                    filters: [:]
                )
            ),
            DashboardWidget(
                widgetId: "revenue_overview",
                title: "Revenue Overview",
                description: "Daily revenue trends",
                widgetType: .chart,
                dataSource: .monetization,
                configuration: WidgetConfiguration(
                    metricType: "daily_revenue",
                    timeRange: .last30Days,
                    groupBy: .day,
                    filters: [:]
                )
            )
        ]
        
        return Dashboard(
            dashboardId: "overview",
            name: "Game Overview",
            description: "High-level metrics and KPIs",
            category: .overview,
            widgets: widgets,
            permissions: [.view, .export],
            refreshInterval: 300 // 5 minutes
        )
    }
    
    private func createPlayerBehaviorDashboard() -> Dashboard {
        let widgets = [
            DashboardWidget(
                widgetId: "session_duration",
                title: "Average Session Duration",
                description: "Average time players spend in game per session",
                widgetType: .metric,
                dataSource: .playerBehavior,
                configuration: WidgetConfiguration(
                    metricType: "avg_session_duration",
                    timeRange: .last7Days,
                    groupBy: nil,
                    filters: [:]
                )
            ),
            DashboardWidget(
                widgetId: "player_segments",
                title: "Player Segments",
                description: "Distribution of players by behavior segments",
                widgetType: .chart,
                dataSource: .playerBehavior,
                configuration: WidgetConfiguration(
                    metricType: "player_segments",
                    timeRange: .last30Days,
                    groupBy: .segment,
                    filters: [:]
                )
            ),
            DashboardWidget(
                widgetId: "churn_prediction",
                title: "Churn Risk Distribution",
                description: "Players categorized by churn risk level",
                widgetType: .chart,
                dataSource: .playerBehavior,
                configuration: WidgetConfiguration(
                    metricType: "churn_risk",
                    timeRange: .last7Days,
                    groupBy: .risk_level,
                    filters: [:]
                )
            )
        ]
        
        return Dashboard(
            dashboardId: "player_behavior",
            name: "Player Behavior",
            description: "Player engagement and behavior analytics",
            category: .playerAnalytics,
            widgets: widgets,
            permissions: [.view, .export],
            refreshInterval: 600 // 10 minutes
        )
    }
    
    private func createMonetizationDashboard() -> Dashboard {
        let widgets = [
            DashboardWidget(
                widgetId: "conversion_rate",
                title: "Purchase Conversion Rate",
                description: "Percentage of players who make purchases",
                widgetType: .metric,
                dataSource: .monetization,
                configuration: WidgetConfiguration(
                    metricType: "conversion_rate",
                    timeRange: .last30Days,
                    groupBy: nil,
                    filters: [:]
                )
            ),
            DashboardWidget(
                widgetId: "arpu",
                title: "Average Revenue Per User",
                description: "Average revenue generated per player",
                widgetType: .metric,
                dataSource: .monetization,
                configuration: WidgetConfiguration(
                    metricType: "arpu",
                    timeRange: .last30Days,
                    groupBy: nil,
                    filters: [:]
                )
            ),
            DashboardWidget(
                widgetId: "purchase_funnel",
                title: "Purchase Funnel",
                description: "Conversion rates through purchase process",
                widgetType: .funnel,
                dataSource: .monetization,
                configuration: WidgetConfiguration(
                    metricType: "purchase_funnel",
                    timeRange: .last30Days,
                    groupBy: nil,
                    filters: [:]
                )
            )
        ]
        
        return Dashboard(
            dashboardId: "monetization",
            name: "Monetization",
            description: "Revenue and monetization metrics",
            category: .monetization,
            widgets: widgets,
            permissions: [.view, .export],
            refreshInterval: 300 // 5 minutes
        )
    }
    
    private func createRetentionDashboard() -> Dashboard {
        let widgets = [
            DashboardWidget(
                widgetId: "retention_cohort",
                title: "Retention Cohort Analysis",
                description: "Player retention rates by cohort",
                widgetType: .cohort,
                dataSource: .retention,
                configuration: WidgetConfiguration(
                    metricType: "retention_rate",
                    timeRange: .last90Days,
                    groupBy: .cohort,
                    filters: [:]
                )
            ),
            DashboardWidget(
                widgetId: "daily_rewards_claimed",
                title: "Daily Rewards Claimed",
                description: "Daily reward claim rates",
                widgetType: .chart,
                dataSource: .retention,
                configuration: WidgetConfiguration(
                    metricType: "daily_rewards_claimed",
                    timeRange: .last30Days,
                    groupBy: .day,
                    filters: [:]
                )
            )
        ]
        
        return Dashboard(
            dashboardId: "retention",
            name: "Player Retention",
            description: "Retention and engagement metrics",
            category: .retention,
            widgets: widgets,
            permissions: [.view, .export],
            refreshInterval: 3600 // 1 hour
        )
    }
    
    private func createABTestingDashboard() -> Dashboard {
        let widgets = [
            DashboardWidget(
                widgetId: "active_experiments",
                title: "Active Experiments",
                description: "Currently running A/B tests",
                widgetType: .table,
                dataSource: .abTesting,
                configuration: WidgetConfiguration(
                    metricType: "active_experiments",
                    timeRange: .current,
                    groupBy: nil,
                    filters: [:]
                )
            ),
            DashboardWidget(
                widgetId: "experiment_results",
                title: "Recent Experiment Results",
                description: "Results from completed experiments",
                widgetType: .table,
                dataSource: .abTesting,
                configuration: WidgetConfiguration(
                    metricType: "experiment_results",
                    timeRange: .last30Days,
                    groupBy: nil,
                    filters: [:]
                )
            )
        ]
        
        return Dashboard(
            dashboardId: "ab_testing",
            name: "A/B Testing",
            description: "Experiment management and results",
            category: .abTesting,
            widgets: widgets,
            permissions: [.view, .export, .edit],
            refreshInterval: 600 // 10 minutes
        )
    }
    
    private func createPerformanceDashboard() -> Dashboard {
        let widgets = [
            DashboardWidget(
                widgetId: "crash_rate",
                title: "Crash Rate",
                description: "Application crash rate",
                widgetType: .metric,
                dataSource: .performance,
                configuration: WidgetConfiguration(
                    metricType: "crash_rate",
                    timeRange: .last7Days,
                    groupBy: nil,
                    filters: [:]
                )
            ),
            DashboardWidget(
                widgetId: "load_times",
                title: "Average Load Times",
                description: "Application load time metrics",
                widgetType: .chart,
                dataSource: .performance,
                configuration: WidgetConfiguration(
                    metricType: "load_times",
                    timeRange: .last7Days,
                    groupBy: .hour,
                    filters: [:]
                )
            )
        ]
        
        return Dashboard(
            dashboardId: "performance",
            name: "Performance",
            description: "Application performance metrics",
            category: .performance,
            widgets: widgets,
            permissions: [.view, .export],
            refreshInterval: 300 // 5 minutes
        )
    }
}

// MARK: - Dashboard Models

public struct Dashboard: Identifiable, Codable {
    public let id = UUID()
    public let dashboardId: String
    public let name: String
    public let description: String
    public let category: DashboardCategory
    public var widgets: [DashboardWidget]
    public let permissions: [DashboardPermission]
    public let refreshInterval: TimeInterval
    public let createdDate: Date
    public var lastUpdated: Date
    
    public init(dashboardId: String, name: String, description: String,
                category: DashboardCategory, widgets: [DashboardWidget],
                permissions: [DashboardPermission], refreshInterval: TimeInterval) {
        self.dashboardId = dashboardId
        self.name = name
        self.description = description
        self.category = category
        self.widgets = widgets
        self.permissions = permissions
        self.refreshInterval = refreshInterval
        self.createdDate = Date()
        self.lastUpdated = Date()
    }
}

public enum DashboardCategory: String, Codable, CaseIterable {
    case overview = "overview"
    case playerAnalytics = "player_analytics"
    case monetization = "monetization"
    case retention = "retention"
    case abTesting = "ab_testing"
    case performance = "performance"
    case liveOps = "live_ops"
    case custom = "custom"
}

public enum DashboardPermission: String, Codable {
    case view = "view"
    case edit = "edit"
    case export = "export"
    case share = "share"
    case admin = "admin"
}

public struct DashboardWidget: Identifiable, Codable {
    public let id = UUID()
    public let widgetId: String
    public let title: String
    public let description: String
    public let widgetType: WidgetType
    public let dataSource: DataSource
    public var configuration: WidgetConfiguration
    public var position: WidgetPosition
    public var isVisible: Bool
    public let createdDate: Date
    public var lastUpdated: Date
    
    public init(widgetId: String, title: String, description: String,
                widgetType: WidgetType, dataSource: DataSource,
                configuration: WidgetConfiguration) {
        self.widgetId = widgetId
        self.title = title
        self.description = description
        self.widgetType = widgetType
        self.dataSource = dataSource
        self.configuration = configuration
        self.position = WidgetPosition(x: 0, y: 0, width: 1, height: 1)
        self.isVisible = true
        self.createdDate = Date()
        self.lastUpdated = Date()
    }
}

public enum WidgetType: String, Codable {
    case metric = "metric"
    case chart = "chart"
    case table = "table"
    case funnel = "funnel"
    case heatmap = "heatmap"
    case cohort = "cohort"
}

public enum DataSource: String, Codable {
    case analytics = "analytics"
    case playerBehavior = "player_behavior"
    case monetization = "monetization"
    case retention = "retention"
    case abTesting = "ab_testing"
    case liveOps = "live_ops"
    case performance = "performance"
}

public struct WidgetConfiguration: Codable {
    public var metricType: String
    public var timeRange: TimeRange
    public var groupBy: GroupBy?
    public var filters: [String: String]
    public var visualization: VisualizationSettings
    
    public init(metricType: String, timeRange: TimeRange, groupBy: GroupBy?,
                filters: [String: String], visualization: VisualizationSettings = VisualizationSettings()) {
        self.metricType = metricType
        self.timeRange = timeRange
        self.groupBy = groupBy
        self.filters = filters
        self.visualization = visualization
    }
}

public enum TimeRange: String, Codable {
    case last1Hour = "last_1_hour"
    case last24Hours = "last_24_hours"
    case last7Days = "last_7_days"
    case last30Days = "last_30_days"
    case last90Days = "last_90_days"
    case lastYear = "last_year"
    case current = "current"
    case custom = "custom"
}

public enum GroupBy: String, Codable {
    case minute = "minute"
    case hour = "hour"
    case day = "day"
    case week = "week"
    case month = "month"
    case segment = "segment"
    case cohort = "cohort"
    case risk_level = "risk_level"
}

public struct VisualizationSettings: Codable {
    public var chartType: ChartType
    public var colorScheme: ColorScheme
    public var showLegend: Bool
    public var showDataLabels: Bool
    
    public init(chartType: ChartType = .line, colorScheme: ColorScheme = .default,
                showLegend: Bool = true, showDataLabels: Bool = false) {
        self.chartType = chartType
        self.colorScheme = colorScheme
        self.showLegend = showLegend
        self.showDataLabels = showDataLabels
    }
}

public enum ChartType: String, Codable {
    case line = "line"
    case bar = "bar"
    case pie = "pie"
    case area = "area"
    case scatter = "scatter"
    case heatmap = "heatmap"
}

public enum ColorScheme: String, Codable {
    case `default` = "default"
    case blue = "blue"
    case green = "green"
    case red = "red"
    case purple = "purple"
    case monochrome = "monochrome"
}

public struct WidgetPosition: Codable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
    
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct MetricSummary: Identifiable, Codable {
    public let id = UUID()
    public let metricId: String
    public let name: String
    public let value: Double
    public let unit: String
    public let change: MetricChange
    public let status: MetricStatus
    public let lastUpdated: Date
    
    public init(metricId: String, name: String, value: Double, unit: String,
                change: MetricChange, status: MetricStatus, lastUpdated: Date) {
        self.metricId = metricId
        self.name = name
        self.value = value
        self.unit = unit
        self.change = change
        self.status = status
        self.lastUpdated = lastUpdated
    }
}

public struct MetricChange: Codable {
    public let value: Double
    public let period: TimePeriod
    public let trend: Trend
    
    public init(value: Double, period: TimePeriod, trend: Trend) {
        self.value = value
        self.period = period
        self.trend = trend
    }
}

public enum TimePeriod: String, Codable {
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
}

public enum Trend: String, Codable {
    case up = "up"
    case down = "down"
    case stable = "stable"
}

public enum MetricStatus: String, Codable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
    case improving = "improving"
}

public struct DataInsight: Identifiable, Codable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let insightType: InsightType
    public let severity: InsightSeverity
    public let confidence: Double
    public let relatedMetrics: [String]
    public let actionable: Bool
    public let generatedDate: Date
    
    public init(title: String, description: String, insightType: InsightType,
                severity: InsightSeverity, confidence: Double, relatedMetrics: [String],
                actionable: Bool = true) {
        self.title = title
        self.description = description
        self.insightType = insightType
        self.severity = severity
        self.confidence = confidence
        self.relatedMetrics = relatedMetrics
        self.actionable = actionable
        self.generatedDate = Date()
    }
}

public enum InsightType: String, Codable {
    case anomaly = "anomaly"
    case trend = "trend"
    case correlation = "correlation"
    case opportunity = "opportunity"
    case warning = "warning"
}

public enum InsightSeverity: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

public struct OptimizationRecommendation: Identifiable, Codable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let category: RecommendationCategory
    public let priority: RecommendationPriority
    public let estimatedImpact: ImpactEstimate
    public let implementationDifficulty: ImplementationDifficulty
    public let actions: [RecommendedAction]
    public let createdDate: Date
    
    public init(title: String, description: String, category: RecommendationCategory,
                priority: RecommendationPriority, estimatedImpact: ImpactEstimate,
                implementationDifficulty: ImplementationDifficulty, actions: [RecommendedAction]) {
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.estimatedImpact = estimatedImpact
        self.implementationDifficulty = implementationDifficulty
        self.actions = actions
        self.createdDate = Date()
    }
}

public enum RecommendationCategory: String, Codable {
    case engagement = "engagement"
    case retention = "retention"
    case monetization = "monetization"
    case performance = "performance"
    case userExperience = "user_experience"
}

public enum RecommendationPriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

public struct ImpactEstimate: Codable {
    public let metric: String
    public let estimatedChange: Double
    public let confidence: Double
    public let timeframe: String
    
    public init(metric: String, estimatedChange: Double, confidence: Double, timeframe: String) {
        self.metric = metric
        self.estimatedChange = estimatedChange
        self.confidence = confidence
        self.timeframe = timeframe
    }
}

public enum ImplementationDifficulty: String, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case veryHard = "very_hard"
}

public struct RecommendedAction: Identifiable, Codable {
    public let id = UUID()
    public let actionType: ActionType
    public let description: String
    public let estimatedEffort: String
    public let requiredResources: [String]
    
    public init(actionType: ActionType, description: String, estimatedEffort: String, requiredResources: [String]) {
        self.actionType = actionType
        self.description = description
        self.estimatedEffort = estimatedEffort
        self.requiredResources = requiredResources
    }
}

public enum ActionType: String, Codable {
    case abTest = "ab_test"
    case configChange = "config_change"
    case featureUpdate = "feature_update"
    case contentUpdate = "content_update"
    case uiChange = "ui_change"
    case notification = "notification"
}

// MARK: - Export Models

public struct DashboardExport: Codable {
    public let dashboard: Dashboard
    public let metrics: [MetricSummary]
    public let insights: [DataInsight]
    public let recommendations: [OptimizationRecommendation]
    public let exportDate: Date
    public let format: ExportFormat
    
    public init(dashboard: Dashboard, metrics: [MetricSummary], insights: [DataInsight],
                recommendations: [OptimizationRecommendation], exportDate: Date, format: ExportFormat) {
        self.dashboard = dashboard
        self.metrics = metrics
        self.insights = insights
        self.recommendations = recommendations
        self.exportDate = exportDate
        self.format = format
    }
}

public enum ExportFormat: String, Codable {
    case json = "json"
    case csv = "csv"
    case excel = "excel"
    case pdf = "pdf"
}

public struct ReportSchedule: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let dashboardId: String
    public let frequency: ReportFrequency
    public let recipients: [String]
    public let format: ExportFormat
    public let isActive: Bool
    
    public init(name: String, dashboardId: String, frequency: ReportFrequency,
                recipients: [String], format: ExportFormat, isActive: Bool = true) {
        self.name = name
        self.dashboardId = dashboardId
        self.frequency = frequency
        self.recipients = recipients
        self.format = format
        self.isActive = isActive
    }
}

public enum ReportFrequency: String, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
}

// MARK: - Supporting Classes

/// Processes and transforms analytics data
private class DataProcessor {
    
    func exportData(_ exportData: DashboardExport, format: ExportFormat) async throws -> Data {
        switch format {
        case .json:
            return try JSONEncoder().encode(exportData)
        case .csv:
            return try generateCSV(from: exportData)
        case .excel:
            return try generateExcel(from: exportData)
        case .pdf:
            return try generatePDF(from: exportData)
        }
    }
    
    private func generateCSV(from exportData: DashboardExport) throws -> Data {
        // Implementation would generate CSV data
        return Data()
    }
    
    private func generateExcel(from exportData: DashboardExport) throws -> Data {
        // Implementation would generate Excel data
        return Data()
    }
    
    private func generatePDF(from exportData: DashboardExport) throws -> Data {
        // Implementation would generate PDF data
        return Data()
    }
}

/// Generates insights from analytics data
private class InsightEngine {
    
    func generateInsights(dashboard: Dashboard) async -> [DataInsight] {
        var insights: [DataInsight] = []
        
        // Analyze dashboard widgets for insights
        for widget in dashboard.widgets {
            let widgetInsights = await analyzeWidget(widget)
            insights.append(contentsOf: widgetInsights)
        }
        
        return insights
    }
    
    private func analyzeWidget(_ widget: DashboardWidget) async -> [DataInsight] {
        // Implementation would analyze widget data and generate insights
        return []
    }
}

// MARK: - Error Types

public enum DashboardError: Error {
    case dashboardNotFound
    case widgetNotFound
    case invalidConfiguration
    case dataProcessingError
    case exportError
}

// MARK: - Extensions

extension Dashboard {
    public var widgetCount: Int {
        widgets.count
    }
    
    public var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > refreshInterval
    }
}