import XCTest

/// Comprehensive UI automation tests for FlexPort iOS
final class FlexPortUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Launch app for each test
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        
        // Configure test environment
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunch() throws {
        // Given
        app.launch()
        
        // Then
        XCTAssertTrue(app.state == .runningForeground)
        
        // Verify main elements are present
        XCTAssertTrue(app.staticTexts["FlexPort"].exists)
    }
    
    func testAppLaunchPerformance() throws {
        // Measure app launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
    
    // MARK: - Main Menu Tests
    
    func testMainMenuNavigation() throws {
        // Given
        app.launch()
        
        // When & Then - Test navigation to different screens
        testNavigationToNewGame()
        testNavigationToSettings()
        testNavigationBackToMainMenu()
    }
    
    private func testNavigationToNewGame() {
        // When
        let newGameButton = app.buttons["New Game"]
        XCTAssertTrue(newGameButton.exists, "New Game button should exist")
        newGameButton.tap()
        
        // Then
        let gameView = app.otherElements["GameView"]
        XCTAssertTrue(gameView.waitForExistence(timeout: 5.0), "Game view should appear")
        
        // Verify game UI elements
        XCTAssertTrue(app.staticTexts["Turn: 1"].exists || app.staticTexts["Turn: 0"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Money:'")).firstMatch.exists)
    }
    
    private func testNavigationToSettings() {
        // When
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.exists, "Settings button should exist")
        settingsButton.tap()
        
        // Then
        let settingsView = app.otherElements["SettingsView"]
        XCTAssertTrue(settingsView.waitForExistence(timeout: 5.0), "Settings view should appear")
        
        // Verify settings elements
        XCTAssertTrue(app.staticTexts["Settings"].exists)
    }
    
    private func testNavigationBackToMainMenu() {
        // When
        let backButton = app.buttons["Back"] // Assuming there's a back button
        if backButton.exists {
            backButton.tap()
        } else {
            // Alternative: swipe or navigate back via menu
            app.swipeRight()
        }
        
        // Then
        let mainMenuView = app.otherElements["MainMenuView"]
        XCTAssertTrue(mainMenuView.waitForExistence(timeout: 5.0), "Should return to main menu")
    }
    
    // MARK: - Game Flow Tests
    
    func testCompleteGameFlow() throws {
        app.launch()
        
        // Start new game
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.otherElements["GameView"].waitForExistence(timeout: 5.0))
        
        // Test basic game interactions
        testGameUIInteractions()
        testShipManagement()
        testTradeOperations()
        testPortNavigation()
    }
    
    private func testGameUIInteractions() {
        // Test main game UI elements
        XCTAssertTrue(app.buttons["Menu"].exists || app.buttons["☰"].exists, "Menu button should exist")
        
        // Test money display
        let moneyLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Money:'")).firstMatch
        XCTAssertTrue(moneyLabel.exists, "Money display should be visible")
        
        // Test turn counter
        let turnLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Turn:'")).firstMatch
        XCTAssertTrue(turnLabel.exists, "Turn counter should be visible")
        
        // Test reputation meter
        let reputationElement = app.otherElements.containing(NSPredicate(format: "identifier CONTAINS 'reputation'")).firstMatch
        // Note: Reputation might be displayed as a progress bar or other element
    }
    
    private func testShipManagement() {
        // Try to access fleet management
        let fleetButton = app.buttons["Fleet"] ?? app.buttons["Ships"]
        if fleetButton.exists {
            fleetButton.tap()
            
            // Verify fleet view
            XCTAssertTrue(app.otherElements["FleetView"].waitForExistence(timeout: 3.0) ||
                         app.staticTexts["Fleet Management"].waitForExistence(timeout: 3.0))
            
            // Test ship purchase if available
            let buyShipButton = app.buttons["Buy Ship"] ?? app.buttons["Purchase"]
            if buyShipButton.exists {
                buyShipButton.tap()
                
                // Verify purchase dialog or view
                let purchaseView = app.alerts.firstMatch ?? app.sheets.firstMatch
                if purchaseView.exists {
                    // Cancel purchase for test
                    let cancelButton = purchaseView.buttons["Cancel"] ?? purchaseView.buttons["Close"]
                    if cancelButton.exists {
                        cancelButton.tap()
                    }
                }
            }
        }
    }
    
    private func testTradeOperations() {
        // Test trade interface
        let tradeButton = app.buttons["Trade"] ?? app.buttons["Markets"]
        if tradeButton.exists {
            tradeButton.tap()
            
            // Verify trade view
            XCTAssertTrue(app.otherElements["TradeView"].waitForExistence(timeout: 3.0) ||
                         app.staticTexts["Trade Routes"].waitForExistence(timeout: 3.0))
            
            // Test commodity selection
            let commodityButtons = app.buttons.allElementsBoundByIndex.filter { 
                $0.label.contains("Oil") || $0.label.contains("Grain") || $0.label.contains("Electronics")
            }
            
            if !commodityButtons.isEmpty {
                commodityButtons.first?.tap()
                
                // Verify commodity details
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Price:'")).firstMatch.exists ||
                             app.staticTexts.containing(NSPredicate(format: "label CONTAINS '$'")).firstMatch.exists)
            }
        }
    }
    
    private func testPortNavigation() {
        // Test map/port navigation
        let mapButton = app.buttons["Map"] ?? app.buttons["Ports"]
        if mapButton.exists {
            mapButton.tap()
            
            // Verify map view
            XCTAssertTrue(app.otherElements["MapView"].waitForExistence(timeout: 3.0) ||
                         app.staticTexts["World Map"].waitForExistence(timeout: 3.0))
            
            // Test port selection
            let ports = app.buttons.allElementsBoundByIndex.filter { 
                $0.label.contains("Port") || $0.label.contains("Harbor")
            }
            
            if !ports.isEmpty {
                ports.first?.tap()
                
                // Verify port details
                let portDetailsView = app.otherElements["PortDetailsView"]
                // Port details might be shown in various ways
            }
        }
    }
    
    // MARK: - Settings Tests
    
    func testSettingsConfiguration() throws {
        app.launch()
        
        // Navigate to settings
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.otherElements["SettingsView"].waitForExistence(timeout: 5.0))
        
        testAudioSettings()
        testGameplaySettings()
        testPrivacySettings()
    }
    
    private func testAudioSettings() {
        // Test audio controls
        let soundToggle = app.switches["Sound Effects"] ?? app.switches["Audio"]
        if soundToggle.exists {
            let initialState = soundToggle.value as? String
            soundToggle.tap()
            
            // Verify state changed
            let newState = soundToggle.value as? String
            XCTAssertNotEqual(initialState, newState, "Audio toggle should change state")
            
            // Toggle back
            soundToggle.tap()
        }
        
        // Test volume slider
        let volumeSlider = app.sliders["Volume"] ?? app.sliders.firstMatch
        if volumeSlider.exists {
            volumeSlider.adjust(toNormalizedSliderPosition: 0.5)
            XCTAssertEqual(volumeSlider.normalizedSliderPosition, 0.5, accuracy: 0.1)
        }
    }
    
    private func testGameplaySettings() {
        // Test difficulty setting
        let difficultyButton = app.buttons["Difficulty"] ?? app.segmentedControls.firstMatch
        if difficultyButton.exists {
            difficultyButton.tap()
        }
        
        // Test auto-save toggle
        let autoSaveToggle = app.switches["Auto Save"] ?? app.switches["Automatic Saving"]
        if autoSaveToggle.exists {
            autoSaveToggle.tap()
        }
    }
    
    private func testPrivacySettings() {
        // Test analytics toggle
        let analyticsToggle = app.switches["Analytics"] ?? app.switches["Data Collection"]
        if analyticsToggle.exists {
            let initialState = analyticsToggle.value as? String
            analyticsToggle.tap()
            
            let newState = analyticsToggle.value as? String
            XCTAssertNotEqual(initialState, newState)
        }
        
        // Test crash reporting toggle
        let crashReportingToggle = app.switches["Crash Reporting"] ?? app.switches["Error Reporting"]
        if crashReportingToggle.exists {
            crashReportingToggle.tap()
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityFeatures() throws {
        app.launch()
        
        // Test VoiceOver labels
        testVoiceOverLabels()
        
        // Test dynamic type support
        testDynamicTypeSupport()
        
        // Test contrast and visual accessibility
        testVisualAccessibility()
    }
    
    private func testVoiceOverLabels() {
        // Verify important UI elements have accessibility labels
        let newGameButton = app.buttons["New Game"]
        XCTAssertNotNil(newGameButton.label)
        XCTAssertFalse(newGameButton.label.isEmpty)
        
        let settingsButton = app.buttons["Settings"]
        XCTAssertNotNil(settingsButton.label)
        XCTAssertFalse(settingsButton.label.isEmpty)
    }
    
    private func testDynamicTypeSupport() {
        // This would require system-level settings changes
        // In a real implementation, you would test with different accessibility text sizes
        
        // For now, just verify text elements exist and are readable
        let titleElements = app.staticTexts.allElementsBoundByIndex
        for element in titleElements {
            XCTAssertFalse(element.label.isEmpty, "Text elements should have content")
        }
    }
    
    private func testVisualAccessibility() {
        // Test button sizes (should be at least 44x44 points)
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            let frame = button.frame
            XCTAssertGreaterThanOrEqual(frame.width, 44, "Button width should be at least 44 points")
            XCTAssertGreaterThanOrEqual(frame.height, 44, "Button height should be at least 44 points")
        }
    }
    
    // MARK: - Performance Tests
    
    func testUIPerformance() throws {
        app.launch()
        
        // Measure navigation performance
        measure(metrics: [XCTClockMetric()]) {
            app.buttons["New Game"].tap()
            _ = app.otherElements["GameView"].waitForExistence(timeout: 10.0)
            
            // Navigate back
            if app.buttons["Back"].exists {
                app.buttons["Back"].tap()
            } else {
                app.swipeRight()
            }
            _ = app.otherElements["MainMenuView"].waitForExistence(timeout: 10.0)
        }
    }
    
    func testScrollingPerformance() throws {
        app.launch()
        
        // Navigate to a scrollable view (e.g., fleet or trade list)
        app.buttons["New Game"].tap()
        
        let scrollableView = app.scrollViews.firstMatch
        if scrollableView.exists {
            measure(metrics: [XCTClockMetric()]) {
                // Perform scrolling operations
                for _ in 0..<10 {
                    scrollableView.swipeUp()
                    scrollableView.swipeDown()
                }
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() throws {
        // This would require mock network conditions
        // For now, test that the app handles offline state gracefully
        
        app.launchArguments.append("--offline-mode")
        app.launch()
        
        // Verify app still functions in offline mode
        XCTAssertTrue(app.staticTexts["FlexPort"].exists)
        
        app.buttons["New Game"].tap()
        
        // Verify offline indicators or messages
        let offlineIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Offline'")).firstMatch
        // Note: This would depend on the actual offline UI implementation
    }
    
    func testLowMemoryConditions() throws {
        // Simulate low memory conditions
        app.launchArguments.append("--simulate-memory-pressure")
        app.launch()
        
        // Verify app handles memory pressure gracefully
        app.buttons["New Game"].tap()
        
        // App should continue to function
        XCTAssertTrue(app.otherElements["GameView"].waitForExistence(timeout: 10.0))
    }
    
    // MARK: - Integration Tests
    
    func testFullGameplaySession() throws {
        app.launch()
        
        // Start a complete gameplay session
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.otherElements["GameView"].waitForExistence(timeout: 5.0))
        
        // Simulate typical user actions
        simulateGameplayActions()
        
        // Verify game state is maintained
        verifyGameStateConsistency()
    }
    
    private func simulateGameplayActions() {
        // Simulate 5 minutes of gameplay
        let endTime = Date().addingTimeInterval(30) // 30 seconds for testing
        
        while Date() < endTime {
            // Randomly perform actions
            let actions = ["Fleet", "Trade", "Map", "Menu"]
            let randomAction = actions.randomElement()!
            
            let button = app.buttons[randomAction]
            if button.exists {
                button.tap()
                
                // Wait a bit
                usleep(500_000) // 0.5 second
                
                // Go back or perform sub-actions
                if app.buttons["Back"].exists {
                    app.buttons["Back"].tap()
                } else if randomAction == "Menu" {
                    // Close menu
                    app.tap()
                }
            }
            
            usleep(1_000_000) // 1 second between actions
        }
    }
    
    private func verifyGameStateConsistency() {
        // Verify that game state elements are still consistent
        let moneyLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Money:'")).firstMatch
        XCTAssertTrue(moneyLabel.exists, "Money display should still be visible")
        
        let turnLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Turn:'")).firstMatch
        XCTAssertTrue(turnLabel.exists, "Turn counter should still be visible")
    }
    
    // MARK: - Device Rotation Tests
    
    func testDeviceRotation() throws {
        app.launch()
        
        // Test portrait orientation
        XCUIDevice.shared.orientation = .portrait
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.otherElements["GameView"].waitForExistence(timeout: 5.0))
        
        // Test landscape orientation
        XCUIDevice.shared.orientation = .landscapeLeft
        
        // Verify UI adapts to landscape
        XCTAssertTrue(app.otherElements["GameView"].exists)
        
        // Test rotating back
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.otherElements["GameView"].exists)
    }
    
    // MARK: - Multitasking Tests
    
    func testAppBackgroundingAndResuming() throws {
        app.launch()
        app.buttons["New Game"].tap()
        
        // Background the app
        XCUIDevice.shared.press(.home)
        
        // Wait a moment
        sleep(2)
        
        // Resume the app
        app.activate()
        
        // Verify app state is preserved
        XCTAssertTrue(app.otherElements["GameView"].exists)
        
        // Verify game data is still present
        let moneyLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Money:'")).firstMatch
        XCTAssertTrue(moneyLabel.exists)
    }
}

// MARK: - Test Helpers

extension XCTestCase {
    
    /// Wait for element to appear with custom timeout
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    /// Take a screenshot with custom name
    func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    /// Verify element is visible on screen
    func verifyElementIsVisible(_ element: XCUIElement) {
        XCTAssertTrue(element.exists, "Element should exist")
        XCTAssertTrue(element.isHittable, "Element should be hittable")
    }
}