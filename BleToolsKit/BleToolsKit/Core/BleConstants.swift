//
//  BleConstants.swift
//  BleToolsKit
//
//  Created by app on 2025/11/5.
//

import Foundation

/// 蓝牙工具包常量定义
internal final class BleConstants {
    
    // MARK: - UserDefaults 存储键
    struct StorageKeys {
        /// 设备 MAC 地址映射存储键
        static let deviceMacMapping = "DeviceMacMapping"
    }
    
    // MARK: - 服务 UUID
    struct ServiceUUIDs {
        /// 目标服务 UUID
        static let targetService = "1000"
    }
    
    // MARK: - 特征 UUID
    struct CharacteristicUUIDs {
        /// 写特征 UUID
        static let write = "1001"
        /// 通知特征 UUID
        static let notify = "1002"
    }
    
    private init() {}
}

