//
//  BleDeviceNameFilter.swift
//  BleToolsKit
//
//  设备名称过滤器 - 根据设备名称进行过滤
//

import Foundation
import CoreBluetooth

/// 设备名称过滤器
internal final class BleDeviceNameFilter: BleFilterProtocol {
    
    // MARK: - Singleton
    static let shared = BleDeviceNameFilter()
    
    private init() {}
    
    // MARK: - Properties
    
    /// 目标设备名称列表（支持多个设备名称）
    private var targetDeviceNames: [String] = ["Air Smart Extra"]
    
    // MARK: - BleFilterProtocol
    
    var filterName: String {
        return "DeviceNameFilter(\(targetDeviceNames.joined(separator: ", ")))"
    }
    
    func shouldInclude(peripheral: CBPeripheral) -> Bool {
        guard let name = peripheral.name else {
            return false
        }
        
        // 检查设备名称是否包含任一目标名称
        return targetDeviceNames.contains { targetName in
            name.contains(targetName)
        }
    }
    
    // MARK: - Public Methods
    
    /// 判断设备名称是否匹配目标设备
    /// - Parameter deviceName: 设备名称
    /// - Returns: true 表示匹配，false 表示不匹配
    func isTargetDevice(deviceName: String?) -> Bool {
        guard let name = deviceName else {
            return false
        }
        
        return targetDeviceNames.contains { targetName in
            name.contains(targetName)
        }
    }
    
    /// 判断蓝牙外设是否为目标设备
    /// - Parameter peripheral: 蓝牙外设
    /// - Returns: true 表示匹配，false 表示不匹配
    func isTargetDevice(peripheral: CBPeripheral) -> Bool {
        return shouldInclude(peripheral: peripheral)
    }
    
    // MARK: - Configuration
    
    /// 添加目标设备名称
    /// - Parameter name: 设备名称
    func addTargetDeviceName(_ name: String) {
        if !targetDeviceNames.contains(name) {
            targetDeviceNames.append(name)
        }
    }
    
    /// 移除目标设备名称
    /// - Parameter name: 设备名称
    func removeTargetDeviceName(_ name: String) {
        targetDeviceNames.removeAll { $0 == name }
    }
    
    /// 设置目标设备名称列表
    /// - Parameter names: 设备名称数组
    func setTargetDeviceNames(_ names: [String]) {
        targetDeviceNames = names
    }
    
    /// 获取当前目标设备名称列表
    /// - Returns: 设备名称数组
    func getTargetDeviceNames() -> [String] {
        return targetDeviceNames
    }
}

/// RSSI 过滤器 - 根据信号强度过滤
internal class BleRSSIFilter: BleFilterProtocol {
    private let minimumRSSI: Int
    
    init(minimumRSSI: Int = -80) {
        self.minimumRSSI = minimumRSSI
    }
    
    var filterName: String {
        return "RSSIFilter(min: \(minimumRSSI))"
    }
    
    func shouldInclude(peripheral: CBPeripheral) -> Bool {
        // 注意：此过滤器需要在扫描回调中使用 RSSI 值
        // 这里仅作为协议实现，实际过滤在扫描回调中进行
        return true
    }
}

/// 设备类型过滤器 - 根据设备类型过滤
internal class BleDeviceTypeFilter: BleFilterProtocol {
    private let targetTypes: [BleDeviceType]
    
    init(targetTypes: [BleDeviceType]) {
        self.targetTypes = targetTypes
    }
    
    var filterName: String {
        let types = targetTypes.map { $0.rawValue }.joined(separator: ", ")
        return "DeviceTypeFilter(\(types))"
    }
    
    func shouldInclude(peripheral: CBPeripheral) -> Bool {
        guard let name = peripheral.name else {
            return false
        }
        
        let deviceType = BleDeviceType.infer(from: name)
        return targetTypes.contains(deviceType)
    }
}

