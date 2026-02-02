//
//  BleDataConverter.swift
//  BleToolsKit
//
//  Created by app on 2025/10/20.
//

import Foundation

/// 数据转换工具类
internal final class BleDataConverter {
    
    // MARK: - String 转 Data
    
    /// 将十六进制字符串转换为 Data
    /// - Parameter hexString: 十六进制字符串，如 "0102FF"
    /// - Returns: Data 对象，如果格式错误返回 nil
    static func hexStringToData(_ hexString: String) -> Data? {
        var hex = hexString.replacingOccurrences(of: " ", with: "")
        hex = hex.replacingOccurrences(of: "0x", with: "")
        guard hex.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
    
    // MARK: - Data 转 String
    
    /// 将 Data 转换为十六进制字符串
    /// - Parameter data: Data 对象
    /// - Returns: 十六进制字符串，如 "0102ff"（小写）
    static func dataToHexString(_ data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 时间转换
    
    /// 获取当前时间的十六进制表示
    /// - Returns: 当前时间的十六进制字符串，格式为 yyyyMMddHHmmss 转换后的十六进制
    static func getCurrentHexTimes() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        
        let now = Date()
        let currentTimeString = formatter.string(from: now)
        
        // 移除非数字字符(使用正则表达式)
        let formattedTimeString = currentTimeString.replacingOccurrences(
            of: "[^0-9\\s]",
            with: "",
            options: .regularExpression
        )
        
        // 移除空格
        let formattedTimeString1 = formattedTimeString.replacingOccurrences(of: " ", with: "")
        
        var hexString = ""
        
        // 每两位数字转换为十六进制
        var index = 0
        while index < formattedTimeString1.count {
            let startIndex = formattedTimeString1.index(formattedTimeString1.startIndex, offsetBy: index)
            let endIndex = formattedTimeString1.index(startIndex, offsetBy: min(2, formattedTimeString1.count - index))
            let subString = String(formattedTimeString1[startIndex..<endIndex])
            
            var target = convertToHexadecimalFromDecimal(subString)
            if target.count == 1 {
                target = "0" + target
            }
            hexString += target
            
            index += 2
        }
        
        print("hexString = \(hexString)")
        return hexString
    }
    
    // MARK: - 进制转换
    
    /// 十进制转十六进制
    /// - Parameter decimalValue: 十进制字符串
    /// - Returns: 十六进制字符串(小写)
    static func convertToHexadecimalFromDecimal(_ decimalValue: String) -> String {
        guard let decimalInt = Int(decimalValue) else { return "" }
        return String(decimalInt, radix: 16, uppercase: false)
    }
    
}

// MARK: - String Extension（保持向后兼容）
internal extension String {
    /// 将十六进制字符串转换为 Data（兼容旧代码）
    func hexToData() -> Data? {
        return BleDataConverter.hexStringToData(self)
    }
}

