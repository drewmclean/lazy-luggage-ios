//
//  HM10Peripheral.swift
//  LazyLuggage
//
//  Created by Andrew McLean on 4/14/17.
//  Copyright © 2017 LacyLuggage. All rights reserved.
//

import UIKit
import CoreBluetooth

class HM10Peripheral {
    
    var name : String
    fileprivate var convertToAbsolute : Bool
    fileprivate var movingAverage : MovingAverage = MovingAverage(period: 10)
    
    var lastSampled : Int8 = 50
    var average : Int8 {
        return Int8(movingAverage.average)
    }
    
    var rssiData : Data {
        let data = Data.dataWithInt8Value(value: average)
        return data
    }
    
    func sampleRSSI(rssiValue value: Int8) {
        let rawRSSI : Int8 = convertToAbsolute ? abs(value) : value
        let _ : Int8 = Int8(movingAverage.addSample(value: Double(rawRSSI)))
        lastSampled = rawRSSI
    }
    
    init(name: String, convertToAbsolute : Bool = false) {
        self.name = name
        self.convertToAbsolute = convertToAbsolute
    }
}
