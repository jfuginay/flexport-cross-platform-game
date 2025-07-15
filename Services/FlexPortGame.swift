//
//  FlexPortGame.swift
//  FlexPort iOS
//
//  Created by J Wylie on 7/15/25.
//

import Foundation

public class FlexPortGame {
    public var economicSystem: SimpleEconomicSystem
    
    public init() {
        self.economicSystem = SimpleEconomicSystem()
    }
    
    public func tick(deltaTime: Double) {
        economicSystem.tick(deltaTime: deltaTime)
    }
}