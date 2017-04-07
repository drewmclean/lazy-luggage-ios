//
//  MovingAverage.swift
//  LazyLuggage
//
//  Created by Andrew McLean on 4/2/17.
//  Copyright © 2017 LazyLuggage. All rights reserved.
//

import Foundation

class MovingAverage {
    var samples: Array<Double>
    var sampleCount = 0
    var period = 20
    
    init(period: Int = 20) {
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
        
        samples.append(value)
        
        if samples.count > period {
            samples.remove(at: 0)
        }
        
        let a =  average
        
//        print("Actual: \(value) - Average: \(a) - Samples: \(samples)")
        
        return a
    }
}
