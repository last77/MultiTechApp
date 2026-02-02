//
//  SpiromerterCommands.swift
//  BleToolsKit
//
//  肺活量计设备命令定义
//

import Foundation

/// 肺活量计命令枚举
public enum SpirometerCommand: String, CaseIterable {
    case bind = "绑定指令"
    case fvc = "FVC测试"
    case vc = "VC测试"
    case mvv = "MVV测试"
    case stopFvc = "停止FVC"
    case stopVc = "停止VC"
    case stopMvv = "停止MVV"
    
    /// 命令的原始十六进制字符串
    var rawCommand: String {
        switch self {
        case .bind:
            return "" // 绑定指令需要动态生成
        case .fvc:
            return "e2010101"
        case .vc:
            return "e2010201"
        case .mvv:
            return "e2010301"
        case .stopFvc:
            return "e2010100e4"
        case .stopVc:
            return "e2010200e5"
        case .stopMvv:
            return "e2010300e6"
        }
    }
    
    /// 是否需要加密
    var requiresEncryption: Bool {
        return true // 所有命令都需要加密（针对新设备）
    }
    
    /// 是否使用密钥池
    var useKeyPool: Bool {
        switch self {
        case .bind:
            return false // 绑定指令使用固定密钥
        default:
            return true // 其他命令使用密钥池
        }
    }
}

/// 肺活量计命令构建器
internal class SpirometerCommandBuilder {
    
    /// 构建绑定指令
    /// - Parameters:
    ///   - isNewDevice: 是否为新设备
    ///   - poolIndex: 密钥池索引
    /// - Returns: 完整的绑定指令
    static func buildBindCommand(isNewDevice: Bool, poolIndex: Int = 0) -> String {
        if isNewDevice {
            // 新设备：88dd1E00000000000000000000000000000000 + CRC
            let commandString = "88dd1E00000000000000000000000000000000"
            let crc = DataConverter.calculateCRC(from: commandString)
            return commandString + crc
        } else {
            // 老设备：e200 + 当前时间十六进制 + 校验和
            let currentHexTime = BleDataConverter.getCurrentHexTimes()
            let info = "e200" + currentHexTime
            let endStr = DataConverter.getTerminator(from: info)
            return info + endStr
        }
    }
    
    /// 构建测试命令（FVC/VC/MVV）
    /// - Parameters:
    ///   - command: 命令类型
    ///   - isNewDevice: 是否为新设备
    ///   - poolIndex: 密钥池索引
    /// - Returns: 完整的测试命令
    static func buildTestCommand(
        _ command: SpirometerCommand,
        isNewDevice: Bool,
        poolIndex: Int = 0
    ) -> String? {
        guard command == .fvc || command == .vc || command == .mvv else {
            return nil
        }
        
        let rawCmd = command.rawCommand
        let terminator = DataConverter.getTerminator(from: rawCmd)
        let commandWithChecksum = rawCmd + terminator
        
        return commandWithChecksum
    }
    
    /// 构建停止命令
    /// - Parameters:
    ///   - command: 命令类型
    ///   - isNewDevice: 是否为新设备
    ///   - poolIndex: 密钥池索引
    /// - Returns: 完整的停止命令
    static func buildStopCommand(
        _ command: SpirometerCommand,
        isNewDevice: Bool,
        poolIndex: Int = 0
    ) -> String? {
        guard command == .stopFvc || command == .stopVc || command == .stopMvv else {
            return nil
        }
        
        return command.rawCommand
    }
}

/// 肺活量计命令实现
internal struct SpirometerCommandImpl: BleCommandProtocol {
    let command: SpirometerCommand
    
    var commandName: String {
        return command.rawValue
    }
    
    var rawCommand: String {
        return command.rawCommand
    }
    
    var requiresEncryption: Bool {
        return command.requiresEncryption
    }
    
    var useKeyPool: Bool {
        return command.useKeyPool
    }
    
    func buildCommand(isNewDevice: Bool, poolIndex: Int) -> String {
        switch command {
        case .bind:
            return SpirometerCommandBuilder.buildBindCommand(isNewDevice: isNewDevice, poolIndex: poolIndex)
        case .fvc, .vc, .mvv:
            return SpirometerCommandBuilder.buildTestCommand(command, isNewDevice: isNewDevice, poolIndex: poolIndex) ?? ""
        case .stopFvc, .stopVc, .stopMvv:
            return SpirometerCommandBuilder.buildStopCommand(command, isNewDevice: isNewDevice, poolIndex: poolIndex) ?? ""
        }
    }
}

