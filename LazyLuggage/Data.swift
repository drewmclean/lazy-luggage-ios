//
//  Data.swift
//  LazyLuggage
//
//  Created by Andrew Mclean on 3/15/17.
//  Copyright © 2017 LacyLuggage. All rights reserved.
//

import Foundation

extension Data {
    
    static func dataWithValue(value: UInt16) -> Data {
        var variableValue = value
        return Data(buffer: UnsafeBufferPointer(start: &variableValue, count: 1))
    }
    
    func int8Value() -> Int8 {
        return Int8(bitPattern: self[0])
    }
    
}


