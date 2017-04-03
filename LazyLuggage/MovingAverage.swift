//
//  MovingAverage.swift
//  LazyLuggage
//
//  Created by Andrew McLean on 4/2/17.
//  Copyright © 2017 LacyLuggage. All rights reserved.
//

import Foundation

class MovingAverage {
    var samples: Array<Double>
    var sampleCount = 0
    var period = 5
    
    init(period: Int = 5) {
        self.period = period
        samples = Array<Double>()
    }
    
    var average: Double {
        let sum: Double = samples.reduce(0, +)
        
        if period > samples.count {
            return sum / Double(samples.count)
        } else {
            return sum / Double(period)
        }
    }
    
    func addSample(value: Double) -> Double {
        sampleCount += 1
        let pos = Int(fmodf(Float(sampleCount), Float(period)))
        
        if pos >= samples.count {
            samples.append(value)
        } else {
            samples[pos] = value
        }
        
        return average
    }
}
