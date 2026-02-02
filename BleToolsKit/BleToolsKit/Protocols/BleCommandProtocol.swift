//
//  BleCommandProtocol.swift
//  BleToolsKit
//
//  命令协议 - 定义设备命令的标准接口
//

import Foundation

/// 蓝牙命令协议
public protocol BleCommandProtocol {
    /// 命令名称
    var commandName: String { get }
    
    /// 命令的原始十六进制字符串
    var rawCommand: String { get }
    
    /// 是否需要加密
    var requiresEncryption: Bool { get }
    
    /// 是否使用密钥池加密（新设备）
    var useKeyPool: Bool { get }
    
    /// 构建完整的命令数据（包含校验和、加密等）
    /// - Parameters:
    ///   - isNewDevice: 是否为新设备
    ///   - poolIndex: 密钥池索引（新设备使用）
    /// - Returns: 完整的命令十六进制字符串
    func buildCommand(isNewDevice: Bool, poolIndex: Int) -> String
}

/// 命令构建器 - 提供命令构建的通用逻辑
public class BleCommandBuilder {
    
    /// 构建带校验和的命令
    /// - Parameter origin: 原始命令字符串
    /// - Returns: 添加校验和后的命令
    public static func buildWithChecksum(_ origin: String) -> String {
        let terminator = DataConverter.getTerminator(from: origin)
        return origin + terminator
    }
    
    /// 构建带 CRC 的命令
    /// - Parameter origin: 原始命令字符串
    /// - Returns: 添加 CRC 后的命令
    public static func buildWithCRC(_ origin: String) -> String {
        let crc = DataConverter.calculateCRC(from: origin)
        return origin + crc
    }
    
    /// 构建加密命令
    /// - Parameters:
    ///   - origin: 原始命令字符串
    ///   - isNewDevice: 是否为新设备
    ///   - poolIndex: 密钥池索引
    ///   - usePool: 是否使用密钥池
    /// - Returns: 加密后的命令
    public static func buildEncryptedCommand(
        _ origin: String,
        isNewDevice: Bool,
        poolIndex: Int = 0,
        usePool: Bool = true
    ) -> String? {
        // 老设备不加密
        guard isNewDevice else {
            return origin
        }
        
        // 新设备加密
        if usePool {
            return AESCBCUtil.encryptHexStringZeroPadding(origin, keyIndex: poolIndex)
        } else {
            let payloadWithCRC = origin + DataConverter.calculateCRCFromHexString(origin)
            return AESCBCUtil.encryptHexStringWithFixedKey(payloadWithCRC)
        }
    }
}

