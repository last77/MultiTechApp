//
//  BleDeviceProtocol.swift
//  BleToolsKit
//
//  设备协议 - 定义所有蓝牙设备必须实现的接口
//

import Foundation
import CoreBluetooth

/// 蓝牙设备协议 - 支持多种设备类型
public protocol BleDeviceProtocol {
    /// 设备类型标识
    var deviceType: BleDeviceType { get }
    
    /// 设备唯一标识
    var identifier: String { get }
    
    /// 设备名称
    var name: String { get }
    
    /// 信号强度
    var rssi: Int { get }
    
    /// MAC 地址（可选）
    var macAddress: String? { get }
    
    /// 是否为新设备
    var isNewDevice: Bool { get }
    
    /// 底层 Peripheral 对象
    var peripheral: CBPeripheral { get }
}

/// 蓝牙设备类型枚举
public enum BleDeviceType: String {
    case spirometer = "Spirometer"  // 肺活量计
    case oximeter = "Oximeter"      // 血氧仪
    case thermometer = "Thermometer" // 体温计
    case unknown = "Unknown"        // 未知设备
    
    /// 从设备名称推断设备类型
    static func infer(from name: String) -> BleDeviceType {
        let lowercasedName = name.lowercased()
        
        if lowercasedName.contains("spir") || lowercasedName.contains("fvc") {
            return .spirometer
        } else if lowercasedName.contains("ox") || lowercasedName.contains("spo2") {
            return .oximeter
        } else if lowercasedName.contains("temp") || lowercasedName.contains("therm") {
            return .thermometer
        }
        
        return .unknown
    }
}

