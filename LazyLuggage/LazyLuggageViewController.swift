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
    static let allowedPeripheralNames = [TransferService.leftPeripheralName, TransferService.rightPeripheralName]
}

class LazyLuggageViewController: UIViewController {
    
    @IBOutlet weak var scanSwifch: UISwitch!
    @IBOutlet weak var leftSignal: UILabel!
    @IBOutlet weak var rightSignal: UILabel!
    
    fileprivate var centralManager : CBCentralManager!
    
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
    fileprivate var startedAdverstising : Bool = false
    fileprivate var peripheralManager : CBPeripheralManager!
    fileprivate var transferCharacteristic: CBMutableCharacteristic?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start up the CBCentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
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
            
        print("\(#line) \(#function) name:\(name) RSSI: \(RSSI)")
        
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
        
        broadcastLuggageRSSIs()
    }
    
}

extension LazyLuggageViewController {
    
    func broadcastLuggageRSSIs() {
        
        guard !startedAdverstising else {
            return
        }
        
        peripheralManager!.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey : [TransferService.serviceUUID]
        ])
        
        startedAdverstising = true
        
    }
    
}
extension LazyLuggageViewController : CBPeripheralManagerDelegate {
    
    /** Required protocol method.  A full app should take care of all the possible states,
     *  but we're just waiting for  to know when the CBPeripheralManager is ready
     */
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // Opt out from any other state
        if (peripheral.state != .poweredOn) {
            return
        }
        
        // We're in CBPeripheralManagerStatePoweredOn state...
        print("self.peripheralManager powered on.")
        
        // Start with the CBMutableCharacteristic
        transferCharacteristic = CBMutableCharacteristic(
            type: TransferService.serviceUUID,
            properties: CBCharacteristicProperties.notify,
            value: nil,
            permissions: CBAttributePermissions.readable
        )
        
        // Then the service
        let transferService = CBMutableService(
            type: TransferService.serviceUUID,
            primary: true
        )
        
        // Add the characteristic to the service
        transferService.characteristics = [transferCharacteristic!]
        
        // And add it to the peripheral manager
        peripheralManager!.add(transferService)
    }
    
    /** Catch when someone subscribes to our characteristic, then start sending them data
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic")
        
        sendData()
    }
    
    /** Recognise when the central unsubscribes
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic")
    }
    
    /** Sends the next amount of data to the connected central
     */
    fileprivate func sendData() {
        
        guard let data = dataToSend else {
            return
        }
        
        guard let characteristic = transferCharacteristic else {
            return
        }
        
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        
    }
    
    /** This callback comes in when the PeripheralManager is ready to send the next chunk of data.
     *  This is to ensure that packets will arrive in the order they are sent
     */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        
        sendData()
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("Peripheral did start advertising")
        
        print(error ?? "UNKNOWN ERROR")
    }
    
}
