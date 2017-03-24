//
//  Data.swift
//  LazyLuggage
//
//  Created by Andrew Mclean on 3/15/17.
//  Copyright © 2017 LacyLuggage. All rights reserved.
//

import Foundation

extension Data {
    
    static func dataWithUInt16Value(value: UInt16) -> Data {
        var variableValue = value
        return Data(buffer: UnsafeBufferPointer(start: &variableValue, count: 16))
    }
    
    static func dataWithInt8Value(value: Int8) -> Data {
        var variableValue = value
        return Data(buffer: UnsafeBufferPointer(start: &variableValue, count:  MemoryLayout<Int8>.size))
    }
    
    func int8Value() -> Int8 {
        return Int8(bitPattern: self[0])
    }
    
}


