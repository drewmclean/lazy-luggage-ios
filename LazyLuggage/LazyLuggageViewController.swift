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
    static let arduinoSendIntervalMilliseconds = 500
    
}

class LazyLuggageViewController: UIViewController {
    
    @IBOutlet weak var leftSignal: UILabel!
    @IBOutlet weak var rightSignal: UILabel!
    
    fileprivate var centralManager : CBCentralManager!
    fileprivate var isConnectingToArduino : Bool = false
    fileprivate var isConnectedToArduino : Bool = false
    fileprivate var arduinoPeripheral : CBPeripheral?
    fileprivate var arduinoService : CBService?
    fileprivate var arduinoCharacteristic : CBCharacteristic?
    fileprivate var peripherals = [String : HM10Peripheral]()
    
    var leftHM10 : HM10Peripheral = HM10Peripheral(name: TransferService.leftPeripheralName, convertToAbsolute: true)
    var rightHM10 : HM10Peripheral = HM10Peripheral(name: TransferService.rightPeripheralName, convertToAbsolute: false)
    
    fileprivate var writeTimer : Timer?
    
    fileprivate var bluetoothQueue : DispatchQueue = DispatchQueue.global()
    
    fileprivate var dataToSend : Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: peripherals, options: .prettyPrinted)
            return jsonData
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lazy Luggage"
        // Start up the CBCentralManager
        
        centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        centralManager?.stopScan()
        UIApplication.shared.isIdleTimerDisabled = false
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
        
        guard central.state == .poweredOn else {
            return
        }
        
        scan()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
//        print("\(#function) name:\(peripheral.name) RSSI: \(RSSI)")

        guard let name = peripheral.name else {
            return
        }
        
        if name == "ARDUINO 101-8873" {
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
        
        sampleRSSI(forHM10Named: name, withRSSI: RSSI)
        
    }
    
    func beginWrite() {
        guard writeTimer == nil else { return }

        let timeInterval : TimeInterval = Double(TransferService.arduinoSendIntervalMilliseconds / 1000)
        

        DispatchQueue.main.async {
            self.writeTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(LazyLuggageViewController.sendBoth), userInfo: nil, repeats: true)
        }
        
//        writeTimer = Timer(timeInterval: timeInterval, repeats: true, block: { (timer: Timer) in
//            self.sendBoth()
//        })
        
    }

    func endWrite() {
        writeTimer?.invalidate()
    }
    
    func sampleRSSI(forHM10Named name : String, withRSSI RSSI: NSNumber) {
        if name == TransferService.leftPeripheralName {
            sample(RSSI: RSSI.int8Value, hm10: leftHM10)
        }
        else if name == TransferService.rightPeripheralName {
            sample(RSSI: RSSI.int8Value, hm10: rightHM10)
        }
    }

    func sample(RSSI : Int8, hm10: HM10Peripheral) {
//        print("Sampling from \(hm10.name) RSSI: \(RSSI)")
        hm10.sampleRSSI(rssiValue: RSSI)
    }
    
    func sendBoth() {
        send(hm10: leftHM10, label: leftSignal)
        send(hm10: rightHM10, label: rightSignal)
    }
    
    func send(hm10 : HM10Peripheral, label:UILabel) {
        
        let average = hm10.average
        let raw = hm10.lastSampled
        let data = hm10.rssiData
        
        bluetoothQueue.async {
            print("Writing \(hm10.name) raw: \(raw) avg: \(average) hashValue: \(data.hashValue)")
            self.writeRSSIValueToArduino(data: data)
        }
        
        DispatchQueue.main.async {
            self.logRSSI(label: label, raw: raw, average: average)
        }
    }
    
    func logRSSI(label : UILabel, raw : Int8, average : Int8) {
        label.text = "\(raw)\n\(average)"
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
            beginWrite()
        }
//        peripheral.setNotifyValue(true, for: characteristic)
        
        print("characteristic: \(characteristic.uuid.uuidString)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("error discovering descriptor: \(error!)")
            
            return
        }
        
//        print("descriptors: \(characteristic.descriptors)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("error writing value: \(error!)")
            return
        }
        
//        print("did write value! \(characteristic.service)")
    }
    
    func writeRSSIValueToArduino(data : Data) {
        
        guard let peripheral = arduinoPeripheral else {
            return
        }
        guard let characteristic = arduinoCharacteristic else {
            return
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }
}
