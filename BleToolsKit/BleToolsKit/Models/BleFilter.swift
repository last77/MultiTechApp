//
//  BleFilter.swift
//  BleToolsKit
//
//  蓝牙扫描过滤器配置
//

import Foundation
import CoreBluetooth

/// 扫描过滤器配置
internal struct BleFilter {
    /// 指定要扫描的 Service（一般建议填你的主服务 UUID），nil 则不过滤
    let serviceUUIDs: [CBUUID]?
    
    /// 是否允许重复回调（默认 false：同一设备只回一次）
    let allowDuplicates: Bool
    
    /// 是否包含系统已连接的设备（默认 true：扫描时会先返回已连接的设备）
    let includeConnectedDevices: Bool
    
    /// 自定义过滤器（可选）
    let customFilter: BleFilterProtocol?
    
    init(
        serviceUUIDs: [CBUUID]? = nil,
        allowDuplicates: Bool = false,
        includeConnectedDevices: Bool = true,
        customFilter: BleFilterProtocol? = nil
    ) {
        self.serviceUUIDs = serviceUUIDs
        self.allowDuplicates = allowDuplicates
        self.includeConnectedDevices = includeConnectedDevices
        self.customFilter = customFilter
    }
}

/// 扫描令牌 - 用于停止扫描
internal protocol ScanToken {
    func stop()
}

