//
//  ViewController.swift
//  LazyLuggage
//
//  Created by Andrew McLean on 3/5/17.
//  Copyright © 2017 LacyLuggage. All rights reserved.
//

import UIKit
import CoreBluetooth

struct TransferService {
    
    static let leftPeripheralName = "BT05"
    static let rightPeripheralName = "?"
    static let serviceUUID = CBUUID(string: "615c5c66-7928-4804-a281-4a865a67b3cd")
    static let arduinoServiceUUID = CBUUID(string: "9DF4299E-05B7-11E7-93AE-92361F002671")
    static let arduinoCharacteristicUUID = CBUUID(string: "9DF42E94-05B7-11E7-93AE-92361F002671")
    static let allowedPeripheralNames = [TransferService.leftPeripheralName, TransferService.rightPeripheralName]
}

class LazyLuggageViewController: UIViewController {
    
    @IBOutlet weak var scanSwifch: UISwitch!
    @IBOutlet weak var leftSignal: UILabel!
    @IBOutlet weak var rightSignal: UILabel!
    
    fileprivate var centralManager : CBCentralManager!
    fileprivate var isConnectingToArduino : Bool = false
    fileprivate var isConnectedToArduino : Bool = false
    fileprivate var arduinoPeripheral : CBPeripheral?
    fileprivate var arduinoService : CBService?
    fileprivate var arduinoCharacteristic : CBCharacteristic?
    
    fileprivate var peripherals = [String : NSNumber]()
    
    fileprivate var dataToSend : Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: peripherals, options: .prettyPrinted)
            return jsonData
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
//    fileprivate var startedAdverstising : Bool = false
//    fileprivate var peripheralManager : CBPeripheralManager!
//    fileprivate var transferCharacteristic: CBMutableCharacteristic?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start up the CBCentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)
//        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        centralManager?.stopScan()
//        peripheralManager?.stopAdvertising()
    }

}

// MARK: Central

extension LazyLuggageViewController {
    
    func scan() {
        
        centralManager.scanForPeripherals(
            withServices: nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(value: true as Bool)
            ]
        )
        
        print("Scanning started")
    }
    
}

extension LazyLuggageViewController : CBCentralManagerDelegate {
    
    /** centralManagerDidUpdateState is a required protocol method.
     *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
     *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
     *  the Central is ready to be used.
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("\(#line) \(#function)")
        
        guard central.state  == .poweredOn else {
            return
        }
        
        scan()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        guard let name = peripheral.name else {
            return
        }
            
//        print("\(#function) name:\(name) RSSI: \(RSSI)")
        
        if name == "ARDUINO 101-8412" {
            
            if isConnectingToArduino == false && isConnectedToArduino == false {
                isConnectingToArduino = true
                arduinoPeripheral = peripheral
                centralManager.connect(arduinoPeripheral!, options: nil)
            }
            return
        }
        
        guard TransferService.allowedPeripheralNames.contains(name) else {
            return
        }
        
        if name == TransferService.leftPeripheralName {
            leftSignal.text = "\(RSSI)"
        }
        if name == TransferService.rightPeripheralName {
            rightSignal.text = "\(RSSI)"
        }
        
        peripherals[name] = RSSI
        
        writeRSSIValuesToArduino()
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnectingToArduino = false
        isConnectedToArduino = true
        
        peripheral.delegate = self
        peripheral.discoverServices([TransferService.arduinoServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnectingToArduino = false
        isConnectedToArduino = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnectedToArduino = false
    }
    
}

extension LazyLuggageViewController : CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("error discovering service: \(error!)")
            return
        }
        
        guard let service = peripheral.services?.first else {
            print("no service in peripheral")
            return
        }
        
        print("service: \(service.uuid.uuidString)")
            
        peripheral.discoverCharacteristics([TransferService.arduinoCharacteristicUUID], for: service)

    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard error == nil else {
            print("error discovering characteristic: \(error!)")
            return
        }
        
        guard let characteristic = service.characteristics?.first else {
            print("characteristic non-existent for service")
            return
        }
        
        if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
            arduinoCharacteristic = characteristic
        }
        peripheral.setNotifyValue(true, for: characteristic)
        
        print("characteristic: \(characteristic.uuid.uuidString)")
        
        writeRSSIValuesToArduino()
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("error discovering descriptor: \(error!)")
            
            return
        }
        
        print("descriptors: \(characteristic.descriptors)")
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("error writing value: \(error!)")
            
            return
        }
        
        print("did write value!")
    }
    
    func writeRSSIValuesToArduino() {
        
        guard let peripheral = arduinoPeripheral else { return }
        guard let characteristic = arduinoCharacteristic else { return }

        peripherals.forEach { (key, value) in
            var rssi : Int8 = value.int8Value
            
//            if key == TransferService.rightPeripheralName {
//                let bitmask : UInt16 = 0b1000000000000000
//                rssi = rssi | bitmask
//            }
            
            let data = Data(buffer: UnsafeBufferPointer(start: &rssi, count: MemoryLayout<Int8>.size))
            print(data as NSData)
            
//            let data = Data.dataWithInt8Value(value: rssi)
            
            print("Writing -> Name: \(key) RSSI: \(rssi) data: \(data.hashValue) length: \(data.count)")
            
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
        
    }
}
