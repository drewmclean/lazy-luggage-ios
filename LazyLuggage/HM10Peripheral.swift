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
    var convertToAbsolute : Bool
    var movingAverage : MovingAverage = MovingAverage(period: 10)
    
    var rssiData : Data {
        let data = Data.dataWithInt8Value(value: Int8(self.movingAverage.average))
        return data
    }
    
    func sampleRSSI(rssiValue value: Int8) -> Data {
        let rawRSSI : Int8 = convertToAbsolute ? abs(value) : value
        var _ : Int8 = Int8(movingAverage.addSample(value: Double(rawRSSI)))
        return rssiData
    }
    
    init(name: String, convertToAbsolute : Bool = false) {
        self.name = name
        self.convertToAbsolute = convertToAbsolute
    }
}
