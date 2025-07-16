# FlexPort Android Game - Final Build PRD

## Objective
Fix remaining compilation errors and successfully build FlexPort logistics empire game for Android installation.

## Current Status
- Core game engine (ECS) implemented with ~50 remaining compilation errors
- Complex interdependencies between AI, Assets, Input, and ECS systems
- Target: Working Android APK ready for device installation

## Architecture Overview
```
FlexPort Game
├── ECS Engine (Entity-Component-System)
├── AI Singularity System  
├── Economic Simulation (4-market system)
├── Asset Management (Ships, Planes, Warehouses)
├── Touch Input & Gesture Handling
└── World Map with Real Ports
```

## Team Structure (3 Docker Claude Instances)

### Claude 1: ECS Core & Foundation Systems ✅ COMPLETED
**Responsibilities:**
- ✅ Fix ECS EntityManager type conflicts and import issues
- ✅ Resolve Component/System integration problems  
- ✅ Ensure clean separation between game.ecs and assets.ecs packages
- ✅ Fix TouchInputSystem integration with main ECS
- ✅ Target: Clean, compilable ECS foundation

**Key Files:**
- `/com/flexport/game/ecs/*` (EntityManager, ComponentManager, System.kt)
- `/com/flexport/ecs/systems/TouchInputSystem.kt`
- Integration points with other systems

**Progress Update:**
- ✅ Fixed System interface inheritance issues (removed System() constructor calls)
- ✅ Fixed EntityManager type conflicts between packages
- ✅ Resolved Component type mismatches in all ECS systems
- ✅ Fixed public-API inline function access violations
- ✅ Corrected System.currentTimeMillis references with java.lang.System
- ✅ Fixed Vector2 serialization in TouchableComponent with @Transient
- ✅ Updated ComponentManager to return consistent String entity IDs
- ✅ ECS foundation is now compilable - no ECS-related compilation errors remain

**Notes for Claude 2 & 3:**
- Remaining compilation errors are NOT ECS-related
- Main issues in SelectionManager.kt (toIntOrNull type mismatches)
- Integration test files need updating for resolved ECS types
- Asset management and input systems can now integrate with clean ECS foundation

### Claude 2: AI & Economic Systems ✅ COMPLETED
**Responsibilities:**
- ✅ Fix AI singularity progression model imports and conflicts
- ✅ Resolve economic simulation integration issues
- ✅ Fix ProgressionEventType and PressureSource missing class errors
- ✅ Ensure AI models work with ECS components
- ✅ Target: Working AI progression and economic simulation

**Key Files:**
- `/com/flexport/ai/*` (models, progression, economic simulation)
- Economic integration with ECS components
- AI singularity progression display

**Progress Update:**
- ✅ Created missing economic models (EconomicState, MarketUpdate, EconomicEventNotification) in ai/models/EconomicModels.kt
- ✅ Fixed import conflicts in EconomicEngine.kt - consolidated model definitions
- ✅ Verified ProgressionEventType and PressureSource are properly defined and accessible across AI systems
- ✅ Resolved AIEconomicImpactSystem compilation errors with correct EconomicImpact import
- ✅ Updated EconomicEngine to use consistent model structure with AI systems
- ✅ Fixed AISingularityTest.kt to use correct field names for economic state
- ✅ All AI and Economic system compilation errors resolved - zero AI/Economic build errors remain

**Notes for Claude 3:**
- AI singularity progression system is now fully integrated with economic engine
- Economic models are consolidated and consistent across packages
- Remaining compilation errors are ECS-related (Claude 1's domain) and asset/input system related
- AI systems ready for final integration testing

### Claude 3: Asset Management & Final Integration
**Responsibilities:**
- Fix asset management system compilation errors
- Resolve remaining input/touch system integration
- Final build coordination and Android manifest fixes
- Handle final linking and APK generation
- Target: Installable Android APK

**Key Files:**
- `/com/flexport/assets/*` (ship, plane, warehouse management)
- Final integration testing and build process
- Android manifest and build configuration

## Collaboration Protocol
1. **Shared Progress Tracking**: Each Claude updates this PRD with completion status
2. **Dependency Coordination**: Claude 1 must complete ECS fixes before Claude 2/3 integration
3. **Communication Channel**: Comments in PRD for inter-Claude coordination
4. **Build Testing**: Claude 3 performs final build attempts and reports results

## Success Criteria
- [ ] Zero compilation errors across all packages
- [ ] Successful `./gradlew build` execution
- [ ] Generated APK installable on Android device
- [ ] App launches without crashing
- [ ] Basic game functionality operational

## Timeline
- **Phase 1 (0-30 min)**: Claude 1 ECS foundation fixes
- **Phase 2 (30-60 min)**: Claude 2 AI/Economic integration + Claude 3 asset fixes (parallel)
- **Phase 3 (60-90 min)**: Final integration, build, and Android installation

## Risk Mitigation
- If circular dependencies persist, temporary stub implementations
- Incremental builds to isolate specific error sources
- Fallback to minimal working version if complex features block build

---
*PRD created for coordinated multi-Claude development approach*