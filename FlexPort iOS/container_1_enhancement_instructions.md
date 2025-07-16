# Container 1 Enhancement Instructions

## Task: Advanced Metal Map Renderer

## Description
Transform basic ocean view into realistic world map with Metal rendering

## Current Working State
- BasicWorldMapView at: Sources/FlexPort/UI/GameView.swift (lines 445-528)
- Ship models at: Sources/FlexPort/Core/GameManager.swift (lines 84-99)
- Trade route creation working in BasicPortDetailsView
- App successfully builds and runs in simulator

## Your Mission
1. Analyze current working code
2. Enhance/replace with advanced implementation
3. Test in simulator before committing
4. Update ENHANCEMENT_PROGRESS.md every 20 minutes
5. Create feature branch: enhancement-container-1
6. Coordinate with other containers through progress file

## Key Requirements
- Maintain compatibility with existing working systems
- Test thoroughly in iOS simulator
- Follow iOS development best practices
- Update progress regularly
- Handle any merge conflicts collaboratively

## Files to Focus On
- Container 1: Sources/FlexPort/UI/Metal/* and GameView.swift
- Container 2: Sources/FlexPort/Core/GameManager.swift and new AI systems
- Container 3: Sources/FlexPort/Core/Economics/* (create new)
- Container 4: Sources/FlexPort/UI/* (enhance existing)
- Container 5: Sources/FlexPort/Game/* (create progression)

## Success Criteria
- Feature works in iOS simulator
- Integrates with existing working systems
- Performance maintained (60 FPS)
- Code follows Swift/iOS conventions
