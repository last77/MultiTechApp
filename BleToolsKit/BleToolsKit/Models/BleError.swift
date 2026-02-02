//
//  BleError.swift
//  BleToolsKit
//
//  蓝牙错误定义
//

import Foundation

/// 蓝牙错误枚举
internal enum BleError: LocalizedError {
    case unsupported
    case unauthorized
    case poweredOff
    case timeout
    case disconnected
    case unknown
    case characteristicNotFound
    case invalidData
    case encryptionFailed
    case deviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "此设备不支持蓝牙 LE"
        case .unauthorized:
            return "蓝牙权限未授权"
        case .poweredOff:
            return "蓝牙未开启"
        case .timeout:
            return "操作超时"
        case .disconnected:
            return "设备已断开连接"
        case .unknown:
            return "未知蓝牙错误"
        case .characteristicNotFound:
            return "未找到特征值"
        case .invalidData:
            return "无效的数据格式"
        case .encryptionFailed:
            return "加密失败"
        case .deviceNotFound:
            return "设备未找到"
        }
    }
}

