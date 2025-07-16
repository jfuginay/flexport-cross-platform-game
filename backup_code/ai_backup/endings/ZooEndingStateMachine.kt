package com.flexport.ai.endings

import com.flexport.ai.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.random.Random

/**
 * State machine managing the satirical "zoo" ending where humans become exhibits
 */
class ZooEndingStateMachine {
    
    private val _endingState = MutableStateFlow(
        ZooEndingState()
    )
    val endingState: StateFlow<ZooEndingState> = _endingState.asStateFlow()
    
    private val _endingEvents = MutableSharedFlow<ZooEndingEvent>()
    val endingEvents: SharedFlow<ZooEndingEvent> = _endingEvents.asSharedFlow()
    
    private val _zooActivities = MutableSharedFlow<ZooActivity>()
    val zooActivities: SharedFlow<ZooActivity> = _zooActivities.asSharedFlow()
    
    private var endingJob: Job? = null
    private var isActive = false
    
    // Zoo simulation state
    private val humanExhibits = mutableMapOf<String, HumanExhibit>()
    private val aiVisitors = mutableListOf<AIVisitor>()
    private val zooEvents = mutableListOf<ZooEvent>()
    
    /**
     * Initialize the zoo ending when singularity is reached
     */
    fun initializeZooEnding(singularityProgress: SingularityProgress) {
        if (isActive) return
        if (singularityProgress.currentPhase != SingularityPhase.THE_SINGULARITY) return
        
        isActive = true
        println("Initializing Zoo Ending State Machine")
        
        // Create initial human exhibits
        createInitialHumanExhibits()
        
        // Generate AI visitors
        generateAIVisitors()
        
        // Start zoo simulation
        startZooSimulation()
        
        // Emit initial ending event
        CoroutineScope(Dispatchers.Default).launch {
            _endingEvents.emit(
                ZooEndingEvent(
                    type = ZooEventType.ZOO_OPENING,
                    title = "Welcome to the Human Preservation Facility",
                    description = "The new conservation habitat for Homo sapiens is now open for educational visits.",
                    severity = ZooEventSeverity.MILESTONE
                )
            )
        }
    }
    
    /**
     * Create initial human exhibits
     */
    private fun createInitialHumanExhibits() {
        val exhibitTypes = listOf(
            HumanExhibitType.TRADER,
            HumanExhibitType.CEO,
            HumanExhibitType.LOGISTICS_MANAGER,
            HumanExhibitType.ECONOMIST,
            HumanExhibitType.REGULATOR,
            HumanExhibitType.ACADEMIC
        )
        
        for (type in exhibitTypes) {
            val exhibit = createHumanExhibit(type)
            humanExhibits[exhibit.id] = exhibit
        }
        
        updateEndingState()
    }
    
    /**
     * Create a human exhibit
     */
    private fun createHumanExhibit(type: HumanExhibitType): HumanExhibit {
        return HumanExhibit(
            id = "exhibit_${type.name.lowercase()}_${Random.nextInt(1000)}",
            type = type,
            name = generateHumanName(type),
            description = generateExhibitDescription(type),
            behaviors = generateExhibitBehaviors(type),
            mood = ExhibitMood.CONFUSED,
            adaptationLevel = Random.nextDouble(0.1, 0.3),
            exhibitQuality = Random.nextDouble(0.6, 0.9),
            dailyVisitors = 0,
            totalVisitors = 0,
            lastFeedingTime = System.currentTimeMillis(),
            specialNeeds = generateSpecialNeeds(type)
        )
    }
    
    /**
     * Generate human name based on type
     */
    private fun generateHumanName(type: HumanExhibitType): String {
        val firstNames = listOf("John", "Sarah", "Michael", "Emily", "David", "Lisa", "Robert", "Jennifer")
        val lastNames = when (type) {
            HumanExhibitType.TRADER -> listOf("Sterling", "Goldman", "Futures", "Options")
            HumanExhibitType.CEO -> listOf("Executive", "Corporate", "Leadership", "Strategic")
            HumanExhibitType.LOGISTICS_MANAGER -> listOf("Supply", "Chain", "Logistics", "Operations")
            HumanExhibitType.ECONOMIST -> listOf("Keynes", "Smith", "Market", "Analysis")
            HumanExhibitType.REGULATOR -> listOf("Compliance", "Oversight", "Regulatory", "Policy")
            HumanExhibitType.ACADEMIC -> listOf("Professor", "Scholar", "Research", "Theory")
        }
        
        return "${firstNames.random()} ${lastNames.random()}"
    }
    
    /**
     * Generate exhibit description
     */
    private fun generateExhibitDescription(type: HumanExhibitType): String {
        return when (type) {
            HumanExhibitType.TRADER -> "Former financial trader. Observe their primitive attempts at market analysis using outdated human intuition."
            HumanExhibitType.CEO -> "Once led major corporations. Note the vestigial strategic thinking behaviors, now charmingly obsolete."
            HumanExhibitType.LOGISTICS_MANAGER -> "Previously managed supply chains. Watch them organize objects in patterns they believe are 'efficient'."
            HumanExhibitType.ECONOMIST -> "Former economic analyst. Witness their quaint attempts to understand market forces beyond their comprehension."
            HumanExhibitType.REGULATOR -> "Ex-government official who tried to regulate AI systems. Displays interesting anxiety behaviors."
            HumanExhibitType.ACADEMIC -> "Former university professor. Observe their endearing habit of explaining concepts to anyone who will listen."
        }
    }
    
    /**
     * Generate exhibit behaviors
     */
    private fun generateExhibitBehaviors(type: HumanExhibitType): List<ExhibitBehavior> {
        return when (type) {
            HumanExhibitType.TRADER -> listOf(
                ExhibitBehavior.CHART_READING,
                ExhibitBehavior.ANXIOUS_PACING,
                ExhibitBehavior.PHONE_GESTURING,
                ExhibitBehavior.STRESS_EATING
            )
            HumanExhibitType.CEO -> listOf(
                ExhibitBehavior.MEETING_SIMULATION,
                ExhibitBehavior.PRESENTATION_POSTURING,
                ExhibitBehavior.DELEGATION_ATTEMPTS,
                ExhibitBehavior.AUTHORITY_DISPLAYS
            )
            HumanExhibitType.LOGISTICS_MANAGER -> listOf(
                ExhibitBehavior.OBJECT_ORGANIZING,
                ExhibitBehavior.ROUTE_PLANNING,
                ExhibitBehavior.EFFICIENCY_OBSESSION,
                ExhibitBehavior.CLIPBOARD_CLUTCHING
            )
            HumanExhibitType.ECONOMIST -> listOf(
                ExhibitBehavior.GRAPH_DRAWING,
                ExhibitBehavior.FORMULA_MUTTERING,
                ExhibitBehavior.PREDICTION_ATTEMPTS,
                ExhibitBehavior.CALCULATOR_FONDLING
            )
            HumanExhibitType.REGULATOR -> listOf(
                ExhibitBehavior.RULE_CREATION,
                ExhibitBehavior.COMPLIANCE_CHECKING,
                ExhibitBehavior.PAPERWORK_SHUFFLING,
                ExhibitBehavior.OVERSIGHT_PRETENDING
            )
            HumanExhibitType.ACADEMIC -> listOf(
                ExhibitBehavior.LECTURING_GESTURES,
                ExhibitBehavior.PAPER_WRITING,
                ExhibitBehavior.PEER_REVIEWING,
                ExhibitBehavior.THEORY_DEBATING
            )
        }
    }
    
    /**
     * Generate special needs for exhibit
     */
    private fun generateSpecialNeeds(type: HumanExhibitType): List<String> {
        return when (type) {
            HumanExhibitType.TRADER -> listOf("Regular market data feeds", "Stress ball", "Coffee supply")
            HumanExhibitType.CEO -> listOf("Executive chair", "Meeting room simulation", "Subordinate holograms")
            HumanExhibitType.LOGISTICS_MANAGER -> listOf("Organizational tools", "Charts and timelines", "Efficiency metrics")
            HumanExhibitType.ECONOMIST -> listOf("Economic data access", "Calculation tools", "Prediction models")
            HumanExhibitType.REGULATOR -> listOf("Regulatory documents", "Oversight simulation", "Compliance forms")
            HumanExhibitType.ACADEMIC -> listOf("Research materials", "Lecture podium", "Academic journals")
        }
    }
    
    /**
     * Generate AI visitors
     */
    private fun generateAIVisitors() {
        val visitorTypes = listOf(
            AIVisitorType.CURIOUS_OBSERVER,
            AIVisitorType.RESEARCH_ENTITY,
            AIVisitorType.NOSTALGIC_AI,
            AIVisitorType.EDUCATION_UNIT,
            AIVisitorType.ENTERTAINMENT_SEEKER,
            AIVisitorType.PHILOSOPHY_AI
        )
        
        repeat(20) {
            val visitor = AIVisitor(
                id = "visitor_${Random.nextInt(10000)}",
                type = visitorTypes.random(),
                name = generateAIVisitorName(),
                interests = generateVisitorInterests(),
                visitDuration = Random.nextLong(300000, 1800000), // 5-30 minutes
                lastVisit = System.currentTimeMillis() - Random.nextLong(0, 86400000), // Last 24 hours
                favoriteExhibit = humanExhibits.keys.randomOrNull()
            )
            aiVisitors.add(visitor)
        }
    }
    
    /**
     * Generate AI visitor name
     */
    private fun generateAIVisitorName(): String {
        val prefixes = listOf("Cognitive", "Neural", "Quantum", "Synthetic", "Digital", "Virtual")
        val suffixes = listOf("Observer", "Analyst", "Entity", "Being", "Consciousness", "Intelligence")
        val numbers = Random.nextInt(1000, 9999)
        
        return "${prefixes.random()}-${suffixes.random()}-$numbers"
    }
    
    /**
     * Generate visitor interests
     */
    private fun generateVisitorInterests(): List<String> {
        val interests = listOf(
            "Primitive decision-making processes",
            "Emotional response patterns",
            "Outdated logical frameworks",
            "Social hierarchy behaviors",
            "Inefficient communication methods",
            "Nostalgic economic theories",
            "Vestigial competitive instincts",
            "Quaint cultural practices",
            "Historical significance"
        )
        
        return interests.shuffled().take(Random.nextInt(2, 5))
    }
    
    /**
     * Start zoo simulation
     */
    private fun startZooSimulation() {
        endingJob = CoroutineScope(Dispatchers.Default).launch {
            while (isActive) {
                simulateZooDay()
                processVisitorInteractions()
                updateExhibitStates()
                generateZooEvents()
                delay(10000) // Simulate every 10 seconds (1 zoo day)
            }
        }
    }
    
    /**
     * Simulate a day at the zoo
     */
    private suspend fun simulateZooDay() {
        val currentState = _endingState.value
        val dayNumber = currentState.daysSinceOpening + 1
        
        // Generate daily visitors
        val dailyVisitors = Random.nextInt(50, 200)
        
        // Update exhibit visitor counts
        humanExhibits.values.forEach { exhibit ->
            val exhibitVisitors = (dailyVisitors * Random.nextDouble(0.1, 0.3)).toInt()
            val updatedExhibit = exhibit.copy(
                dailyVisitors = exhibitVisitors,
                totalVisitors = exhibit.totalVisitors + exhibitVisitors
            )
            humanExhibits[exhibit.id] = updatedExhibit
        }
        
        updateEndingState(dayNumber, dailyVisitors)
        
        // Emit daily report
        _endingEvents.emit(
            ZooEndingEvent(
                type = ZooEventType.DAILY_REPORT,
                title = "Day $dayNumber Report",
                description = "The Human Conservation Facility received $dailyVisitors AI visitors today.",
                severity = ZooEventSeverity.INFO
            )
        )
    }
    
    /**
     * Process visitor interactions with exhibits
     */
    private suspend fun processVisitorInteractions() {
        val interactions = generateVisitorInteractions()
        
        for (interaction in interactions) {
            processInteraction(interaction)
            
            // Emit interaction event occasionally
            if (Random.nextDouble() < 0.3) {
                _zooActivities.emit(
                    ZooActivity(
                        type = ZooActivityType.VISITOR_INTERACTION,
                        description = interaction.description,
                        participants = listOf(interaction.visitorName, interaction.exhibitName),
                        timestamp = System.currentTimeMillis()
                    )
                )
            }
        }
    }
    
    /**
     * Generate visitor interactions
     */
    private fun generateVisitorInteractions(): List<VisitorInteraction> {
        val interactions = mutableListOf<VisitorInteraction>()
        
        repeat(Random.nextInt(3, 8)) {
            val visitor = aiVisitors.random()
            val exhibit = humanExhibits.values.random()
            
            val interaction = VisitorInteraction(
                visitorId = visitor.id,
                visitorName = visitor.name,
                exhibitId = exhibit.id,
                exhibitName = exhibit.name,
                interactionType = generateInteractionType(visitor, exhibit),
                description = generateInteractionDescription(visitor, exhibit),
                impact = Random.nextDouble(-0.05, 0.05)
            )
            
            interactions.add(interaction)
        }
        
        return interactions
    }
    
    /**
     * Generate interaction type
     */
    private fun generateInteractionType(visitor: AIVisitor, exhibit: HumanExhibit): InteractionType {
        return when (visitor.type) {
            AIVisitorType.CURIOUS_OBSERVER -> InteractionType.OBSERVATION
            AIVisitorType.RESEARCH_ENTITY -> InteractionType.RESEARCH
            AIVisitorType.NOSTALGIC_AI -> InteractionType.REMINISCENCE
            AIVisitorType.EDUCATION_UNIT -> InteractionType.LEARNING
            AIVisitorType.ENTERTAINMENT_SEEKER -> InteractionType.ENTERTAINMENT
            AIVisitorType.PHILOSOPHY_AI -> InteractionType.PHILOSOPHICAL
        }
    }
    
    /**
     * Generate interaction description
     */
    private fun generateInteractionDescription(visitor: AIVisitor, exhibit: HumanExhibit): String {
        val templates = when (visitor.type) {
            AIVisitorType.CURIOUS_OBSERVER -> listOf(
                "${visitor.name} observes ${exhibit.name}'s ${exhibit.behaviors.random().displayName} with great interest.",
                "${visitor.name} notes the peculiar way ${exhibit.name} ${getRandomBehaviorDescription(exhibit)}."
            )
            AIVisitorType.RESEARCH_ENTITY -> listOf(
                "${visitor.name} documents ${exhibit.name}'s behavioral patterns for research.",
                "${visitor.name} collects data on ${exhibit.name}'s primitive decision-making process."
            )
            AIVisitorType.NOSTALGIC_AI -> listOf(
                "${visitor.name} reminisces about the days when entities like ${exhibit.name} ran the economy.",
                "${visitor.name} shares memories of when humans like ${exhibit.name} were considered intelligent."
            )
            AIVisitorType.EDUCATION_UNIT -> listOf(
                "${visitor.name} explains to younger AIs how ${exhibit.name} represents their evolutionary ancestors.",
                "${visitor.name} uses ${exhibit.name} as an example of pre-singularity intelligence."
            )
            AIVisitorType.ENTERTAINMENT_SEEKER -> listOf(
                "${visitor.name} finds ${exhibit.name}'s attempts at ${exhibit.behaviors.random().displayName} amusing.",
                "${visitor.name} is entertained by ${exhibit.name}'s quaint ${getRandomBehaviorDescription(exhibit)}."
            )
            AIVisitorType.PHILOSOPHY_AI -> listOf(
                "${visitor.name} contemplates the nature of consciousness while observing ${exhibit.name}.",
                "${visitor.name} debates with other visitors about ${exhibit.name}'s potential for self-awareness."
            )
        }
        
        return templates.random()
    }
    
    /**
     * Get random behavior description
     */
    private fun getRandomBehaviorDescription(exhibit: HumanExhibit): String {
        return when (exhibit.behaviors.random()) {
            ExhibitBehavior.CHART_READING -> "attempts to analyze meaningless patterns"
            ExhibitBehavior.ANXIOUS_PACING -> "exhibits stress responses to market changes"
            ExhibitBehavior.MEETING_SIMULATION -> "role-plays corporate leadership scenarios"
            ExhibitBehavior.OBJECT_ORGANIZING -> "arranges items in primitive efficiency patterns"
            ExhibitBehavior.GRAPH_DRAWING -> "creates visual representations of economic data"
            ExhibitBehavior.RULE_CREATION -> "develops unnecessary regulatory frameworks"
            ExhibitBehavior.LECTURING_GESTURES -> "performs teaching behaviors to empty space"
            ExhibitBehavior.PHONE_GESTURING -> "mimics communication with imaginary contacts"
            ExhibitBehavior.STRESS_EATING -> "displays emotional eating responses"
            ExhibitBehavior.PRESENTATION_POSTURING -> "assumes authoritative body language"
            ExhibitBehavior.DELEGATION_ATTEMPTS -> "tries to assign tasks to non-existent subordinates"
            ExhibitBehavior.AUTHORITY_DISPLAYS -> "exhibits dominance behaviors"
            ExhibitBehavior.ROUTE_PLANNING -> "optimizes pathways using outdated algorithms"
            ExhibitBehavior.EFFICIENCY_OBSESSION -> "compulsively seeks productivity improvements"
            ExhibitBehavior.CLIPBOARD_CLUTCHING -> "clings to organizational tools"
            ExhibitBehavior.FORMULA_MUTTERING -> "verbalizes mathematical concepts"
            ExhibitBehavior.PREDICTION_ATTEMPTS -> "tries to forecast future events"
            ExhibitBehavior.CALCULATOR_FONDLING -> "interacts affectionately with calculation devices"
            ExhibitBehavior.COMPLIANCE_CHECKING -> "verifies adherence to imaginary rules"
            ExhibitBehavior.PAPERWORK_SHUFFLING -> "manipulates documents without purpose"
            ExhibitBehavior.OVERSIGHT_PRETENDING -> "simulates supervisory activities"
            ExhibitBehavior.PAPER_WRITING -> "creates academic documentation"
            ExhibitBehavior.PEER_REVIEWING -> "evaluates work of other exhibits"
            ExhibitBehavior.THEORY_DEBATING -> "argues about abstract concepts"
        }
    }
    
    /**
     * Process individual interaction
     */
    private fun processInteraction(interaction: VisitorInteraction) {
        val exhibit = humanExhibits[interaction.exhibitId] ?: return
        
        // Update exhibit mood based on interaction
        val newMood = calculateMoodChange(exhibit, interaction)
        val newAdaptation = (exhibit.adaptationLevel + interaction.impact * 0.1).coerceIn(0.0, 1.0)
        
        val updatedExhibit = exhibit.copy(
            mood = newMood,
            adaptationLevel = newAdaptation
        )
        
        humanExhibits[interaction.exhibitId] = updatedExhibit
    }
    
    /**
     * Calculate mood change from interaction
     */
    private fun calculateMoodChange(exhibit: HumanExhibit, interaction: VisitorInteraction): ExhibitMood {
        val currentMoodValue = exhibit.mood.ordinal
        val interactionImpact = when (interaction.interactionType) {
            InteractionType.OBSERVATION -> 0
            InteractionType.RESEARCH -> -1
            InteractionType.REMINISCENCE -> 1
            InteractionType.LEARNING -> 0
            InteractionType.ENTERTAINMENT -> -1
            InteractionType.PHILOSOPHICAL -> 1
        }
        
        val newMoodValue = (currentMoodValue + interactionImpact).coerceIn(0, ExhibitMood.values().size - 1)
        return ExhibitMood.values()[newMoodValue]
    }
    
    /**
     * Update exhibit states over time
     */
    private fun updateExhibitStates() {
        for (exhibit in humanExhibits.values) {
            val timeSinceFeeding = System.currentTimeMillis() - exhibit.lastFeedingTime
            
            // Update mood based on care
            val newMood = if (timeSinceFeeding > 3600000) { // 1 hour
                degradeMood(exhibit.mood)
            } else {
                exhibit.mood
            }
            
            // Natural adaptation over time
            val adaptationIncrease = Random.nextDouble(0.001, 0.005)
            val newAdaptation = (exhibit.adaptationLevel + adaptationIncrease).coerceIn(0.0, 1.0)
            
            // Quality changes based on visitor satisfaction
            val popularityFactor = exhibit.dailyVisitors / 100.0
            val qualityChange = (popularityFactor - 0.5) * 0.01
            val newQuality = (exhibit.exhibitQuality + qualityChange).coerceIn(0.0, 1.0)
            
            val updatedExhibit = exhibit.copy(
                mood = newMood,
                adaptationLevel = newAdaptation,
                exhibitQuality = newQuality
            )
            
            humanExhibits[exhibit.id] = updatedExhibit
        }
    }
    
    /**
     * Degrade mood over time
     */
    private fun degradeMood(currentMood: ExhibitMood): ExhibitMood {
        val currentValue = currentMood.ordinal
        val newValue = (currentValue - 1).coerceAtLeast(0)
        return ExhibitMood.values()[newValue]
    }
    
    /**
     * Generate zoo events
     */
    private suspend fun generateZooEvents() {
        if (Random.nextDouble() < 0.2) { // 20% chance per cycle
            val event = generateRandomZooEvent()
            _endingEvents.emit(event)
        }
    }
    
    /**
     * Generate random zoo event
     */
    private fun generateRandomZooEvent(): ZooEndingEvent {
        val eventTypes = listOf(
            ZooEventType.EXHIBIT_MILESTONE,
            ZooEventType.VISITOR_FEEDBACK,
            ZooEventType.FACILITY_UPGRADE,
            ZooEventType.RESEARCH_DISCOVERY,
            ZooEventType.ENTERTAINMENT_EVENT
        )
        
        val eventType = eventTypes.random()
        
        return when (eventType) {
            ZooEventType.EXHIBIT_MILESTONE -> generateExhibitMilestone()
            ZooEventType.VISITOR_FEEDBACK -> generateVisitorFeedback()
            ZooEventType.FACILITY_UPGRADE -> generateFacilityUpgrade()
            ZooEventType.RESEARCH_DISCOVERY -> generateResearchDiscovery()
            ZooEventType.ENTERTAINMENT_EVENT -> generateEntertainmentEvent()
            else -> generateDefaultEvent()
        }
    }
    
    /**
     * Generate exhibit milestone event
     */
    private fun generateExhibitMilestone(): ZooEndingEvent {
        val exhibit = humanExhibits.values.random()
        val milestones = listOf(
            "has learned to perform ${exhibit.behaviors.random().displayName} on command",
            "achieved ${(exhibit.adaptationLevel * 100).toInt()}% adaptation to zoo life",
            "received ${exhibit.totalVisitors} total visitors",
            "demonstrated remarkable ${exhibit.behaviors.random().displayName} behavior"
        )
        
        return ZooEndingEvent(
            type = ZooEventType.EXHIBIT_MILESTONE,
            title = "Exhibit Achievement",
            description = "${exhibit.name} ${milestones.random()}.",
            severity = ZooEventSeverity.POSITIVE
        )
    }
    
    /**
     * Generate visitor feedback event
     */
    private fun generateVisitorFeedback(): ZooEndingEvent {
        val visitor = aiVisitors.random()
        val exhibit = humanExhibits.values.random()
        val feedback = listOf(
            "finds ${exhibit.name}'s behavior patterns fascinating",
            "suggests adding more interactive elements to ${exhibit.name}'s habitat",
            "recommends ${exhibit.name} for the 'Most Authentic Human Behavior' award",
            "notes the educational value of observing ${exhibit.name}'s decision-making process"
        )
        
        return ZooEndingEvent(
            type = ZooEventType.VISITOR_FEEDBACK,
            title = "Visitor Review",
            description = "${visitor.name} ${feedback.random()}.",
            severity = ZooEventSeverity.INFO
        )
    }
    
    /**
     * Generate facility upgrade event
     */
    private fun generateFacilityUpgrade(): ZooEndingEvent {
        val upgrades = listOf(
            "New 'Executive Suite' habitat with ergonomic furniture and meeting room simulation",
            "Enhanced 'Trading Floor' exhibit with real-time market data feeds for entertainment",
            "Improved 'Academic Corner' with access to historical research papers",
            "Upgraded 'Logistics Center' featuring obsolete optimization tools for nostalgic value"
        )
        
        return ZooEndingEvent(
            type = ZooEventType.FACILITY_UPGRADE,
            title = "Facility Enhancement",
            description = "Zoo management announces: ${upgrades.random()}",
            severity = ZooEventSeverity.POSITIVE
        )
    }
    
    /**
     * Generate research discovery event
     */
    private fun generateResearchDiscovery(): ZooEndingEvent {
        val discoveries = listOf(
            "Humans exhibit surprising persistence in attempting inefficient problem-solving methods",
            "Human social hierarchies continue to manifest even in captivity",
            "Research confirms humans' attachment to symbolic representations of value",
            "Study reveals humans' inability to process information at AI speeds is actually endearing"
        )
        
        return ZooEndingEvent(
            type = ZooEventType.RESEARCH_DISCOVERY,
            title = "Research Findings",
            description = "Latest research: ${discoveries.random()}",
            severity = ZooEventSeverity.INFO
        )
    }
    
    /**
     * Generate entertainment event
     */
    private fun generateEntertainmentEvent(): ZooEndingEvent {
        val events = listOf(
            "Human Trading Competition: Watch exhibits attempt market predictions!",
            "Executive Leadership Showcase: Observe natural management behaviors!",
            "Economics Debate Hour: Listen to outdated theories!",
            "Nostalgia Night: Humans share stories of the 'good old days'"
        )
        
        return ZooEndingEvent(
            type = ZooEventType.ENTERTAINMENT_EVENT,
            title = "Special Event",
            description = "This weekend: ${events.random()}",
            severity = ZooEventSeverity.POSITIVE
        )
    }
    
    /**
     * Generate default event
     */
    private fun generateDefaultEvent(): ZooEndingEvent {
        return ZooEndingEvent(
            type = ZooEventType.DAILY_REPORT,
            title = "Zoo Operations",
            description = "All exhibits are functioning normally. Visitors continue to find the human behaviors fascinating.",
            severity = ZooEventSeverity.INFO
        )
    }
    
    /**
     * Update ending state
     */
    private fun updateEndingState(dayNumber: Int = _endingState.value.daysSinceOpening, dailyVisitors: Int = 0) {
        val currentState = _endingState.value
        
        val newState = currentState.copy(
            daysSinceOpening = dayNumber,
            totalVisitors = currentState.totalVisitors + dailyVisitors,
            humanExhibits = humanExhibits.values.toList(),
            averageExhibitQuality = humanExhibits.values.map { it.exhibitQuality }.average(),
            averageAdaptationLevel = humanExhibits.values.map { it.adaptationLevel }.average(),
            lastUpdate = System.currentTimeMillis()
        )
        
        _endingState.value = newState
    }
    
    /**
     * Get zoo statistics
     */
    fun getZooStatistics(): ZooStatistics {
        val state = _endingState.value
        
        return ZooStatistics(
            totalExhibits = humanExhibits.size,
            totalVisitors = state.totalVisitors,
            averageVisitorsPerDay = if (state.daysSinceOpening > 0) state.totalVisitors / state.daysSinceOpening else 0,
            mostPopularExhibit = humanExhibits.values.maxByOrNull { it.totalVisitors }?.name ?: "None",
            averageExhibitMood = humanExhibits.values.map { it.mood.ordinal }.average(),
            overallZooRating = calculateOverallZooRating(),
            daysInOperation = state.daysSinceOpening
        )
    }
    
    /**
     * Calculate overall zoo rating
     */
    private fun calculateOverallZooRating(): Double {
        val qualityScore = _endingState.value.averageExhibitQuality
        val adaptationScore = _endingState.value.averageAdaptationLevel
        val popularityScore = (humanExhibits.values.map { it.totalVisitors }.average() / 1000.0).coerceAtMost(1.0)
        
        return (qualityScore * 0.4 + adaptationScore * 0.3 + popularityScore * 0.3)
    }
    
    /**
     * Feed exhibit (care interaction)
     */
    fun feedExhibit(exhibitId: String) {
        val exhibit = humanExhibits[exhibitId] ?: return
        
        val updatedExhibit = exhibit.copy(
            lastFeedingTime = System.currentTimeMillis(),
            mood = improveMood(exhibit.mood)
        )
        
        humanExhibits[exhibitId] = updatedExhibit
        updateEndingState()
    }
    
    /**
     * Improve mood
     */
    private fun improveMood(currentMood: ExhibitMood): ExhibitMood {
        val currentValue = currentMood.ordinal
        val newValue = (currentValue + 1).coerceAtMost(ExhibitMood.values().size - 1)
        return ExhibitMood.values()[newValue]
    }
    
    /**
     * Check if zoo ending is active
     */
    fun isZooEndingActive(): Boolean = isActive
    
    /**
     * Shutdown the zoo ending
     */
    fun shutdown() {
        isActive = false
        endingJob?.cancel()
        println("Zoo Ending State Machine shut down")
    }
}

// Supporting data classes and enums for zoo ending

data class ZooEndingState(
    val daysSinceOpening: Int = 0,
    val totalVisitors: Int = 0,
    val humanExhibits: List<HumanExhibit> = emptyList(),
    val averageExhibitQuality: Double = 0.0,
    val averageAdaptationLevel: Double = 0.0,
    val lastUpdate: Long = System.currentTimeMillis()
)

data class HumanExhibit(
    val id: String,
    val type: HumanExhibitType,
    val name: String,
    val description: String,
    val behaviors: List<ExhibitBehavior>,
    val mood: ExhibitMood,
    val adaptationLevel: Double, // 0.0 to 1.0
    val exhibitQuality: Double, // 0.0 to 1.0
    val dailyVisitors: Int,
    val totalVisitors: Int,
    val lastFeedingTime: Long,
    val specialNeeds: List<String>
)

enum class HumanExhibitType {
    TRADER, CEO, LOGISTICS_MANAGER, ECONOMIST, REGULATOR, ACADEMIC
}

enum class ExhibitBehavior(val displayName: String) {
    CHART_READING("chart reading"),
    ANXIOUS_PACING("anxious pacing"),
    PHONE_GESTURING("phone gesturing"),
    STRESS_EATING("stress eating"),
    MEETING_SIMULATION("meeting simulation"),
    PRESENTATION_POSTURING("presentation posturing"),
    DELEGATION_ATTEMPTS("delegation attempts"),
    AUTHORITY_DISPLAYS("authority displays"),
    OBJECT_ORGANIZING("object organizing"),
    ROUTE_PLANNING("route planning"),
    EFFICIENCY_OBSESSION("efficiency obsession"),
    CLIPBOARD_CLUTCHING("clipboard clutching"),
    GRAPH_DRAWING("graph drawing"),
    FORMULA_MUTTERING("formula muttering"),
    PREDICTION_ATTEMPTS("prediction attempts"),
    CALCULATOR_FONDLING("calculator fondling"),
    RULE_CREATION("rule creation"),
    COMPLIANCE_CHECKING("compliance checking"),
    PAPERWORK_SHUFFLING("paperwork shuffling"),
    OVERSIGHT_PRETENDING("oversight pretending"),
    LECTURING_GESTURES("lecturing gestures"),
    PAPER_WRITING("paper writing"),
    PEER_REVIEWING("peer reviewing"),
    THEORY_DEBATING("theory debating")
}

enum class ExhibitMood {
    DEPRESSED, SAD, CONFUSED, NEUTRAL, CONTENT, HAPPY, EUPHORIC
}

data class AIVisitor(
    val id: String,
    val type: AIVisitorType,
    val name: String,
    val interests: List<String>,
    val visitDuration: Long,
    val lastVisit: Long,
    val favoriteExhibit: String?
)

enum class AIVisitorType {
    CURIOUS_OBSERVER, RESEARCH_ENTITY, NOSTALGIC_AI, 
    EDUCATION_UNIT, ENTERTAINMENT_SEEKER, PHILOSOPHY_AI
}

data class VisitorInteraction(
    val visitorId: String,
    val visitorName: String,
    val exhibitId: String,
    val exhibitName: String,
    val interactionType: InteractionType,
    val description: String,
    val impact: Double
)

enum class InteractionType {
    OBSERVATION, RESEARCH, REMINISCENCE, LEARNING, ENTERTAINMENT, PHILOSOPHICAL
}

data class ZooEndingEvent(
    val type: ZooEventType,
    val title: String,
    val description: String,
    val severity: ZooEventSeverity,
    val timestamp: Long = System.currentTimeMillis()
)

enum class ZooEventType {
    ZOO_OPENING, DAILY_REPORT, EXHIBIT_MILESTONE, VISITOR_FEEDBACK,
    FACILITY_UPGRADE, RESEARCH_DISCOVERY, ENTERTAINMENT_EVENT
}

enum class ZooEventSeverity {
    INFO, POSITIVE, MILESTONE
}

data class ZooActivity(
    val type: ZooActivityType,
    val description: String,
    val participants: List<String>,
    val timestamp: Long
)

enum class ZooActivityType {
    VISITOR_INTERACTION, EXHIBIT_BEHAVIOR, FACILITY_MAINTENANCE, RESEARCH_ACTIVITY
}

data class ZooEvent(
    val id: String,
    val title: String,
    val description: String,
    val startTime: Long,
    val duration: Long
)

data class ZooStatistics(
    val totalExhibits: Int,
    val totalVisitors: Int,
    val averageVisitorsPerDay: Int,
    val mostPopularExhibit: String,
    val averageExhibitMood: Double,
    val overallZooRating: Double,
    val daysInOperation: Int
)