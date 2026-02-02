//
//  BleDevice.swift
//  BleToolsKit
//
//  蓝牙设备模型
//

import Foundation
import CoreBluetooth

/// 蓝牙设备 - 内部使用，不对外暴露
internal struct BleDevice: Hashable, BleDeviceProtocol {
    let peripheral: CBPeripheral
    let name: String
    let identifier: String
    let rssi: Int
    let macAddress: String?
    let isNewDevice: Bool
    let deviceType: BleDeviceType
    let isConnected: Bool  // 是否为已连接设备（RSSI=0表示已连接）
    
    init(peripheral: CBPeripheral, rssi: Int, macAddress: String? = nil) {
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Unknown"
        self.identifier = peripheral.identifier.uuidString
        self.rssi = rssi
        self.macAddress = macAddress
        self.isConnected = (rssi == 0)  // RSSI为0表示已连接设备
        
        // 判断是否为新设备
        self.isNewDevice = BleStorage.shared.isNewDevice(uuidString: peripheral.identifier.uuidString)
        
        // 推断设备类型
        self.deviceType = BleDeviceType.infer(from: self.name)
    }
    
    // Hashable 实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    
    static func == (lhs: BleDevice, rhs: BleDevice) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

/// 设备信息 - 对外暴露的简化版本
public struct BleDeviceInfo {
    public let deviceId: String
    public let deviceName: String
    public let rssi: Int
    public let macAddress: String?
    public let isNewDevice: Bool
    public let deviceType: BleDeviceType
    public let isConnected: Bool
    
    internal init(from device: BleDevice) {
        self.deviceId = device.identifier
        self.deviceName = device.name
        self.rssi = device.rssi
        self.macAddress = device.macAddress
        self.isNewDevice = device.isNewDevice
        self.deviceType = device.deviceType
        self.isConnected = device.isConnected
    }
}

