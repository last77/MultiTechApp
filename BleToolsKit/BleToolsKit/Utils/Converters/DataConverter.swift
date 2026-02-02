//
//  DataConverter.swift
//  TabBarTest
//
//  Created by app on 2025/11/5.
//

import Foundation

import Foundation

final class DataConverter {
    
    /// 将十六进制字符串转换为 Data
    /// - Parameter hexString: 仅包含 0-9A-F 的十六进制字符串，可大写或小写
    /// - Returns: 转换后的 Data，如果字符串无效则返回空 Data
    static func data(from hexString: String) -> Data {
        var data = Data()
        var hex = hexString
        
        // 去除空格和换行符
        hex = hex.replacingOccurrences(of: " ", with: "")
                   .replacingOccurrences(of: "\n", with: "")
        
        // 若长度为奇数，补 0
        if hex.count % 2 != 0 {
            hex = "0" + hex
        }
        
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<nextIndex]
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }
    
    /// 从十六进制字符串计算 CRC 校验值
    /// - Parameter hexString: 十六进制字符串
    /// - Returns: CRC 校验值（2位十六进制字符串，小写）
    static func calculateCRC(from hexString: String) -> String {
        var sum = 0
        
        // 每两个字符一组
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let endIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
            let hexPair = String(hexString[index..<endIndex])
            
            if let value = Int(hexPair, radix: 16) {
                sum += value
            }
            
            index = endIndex
        }
        
        // 转换为十六进制字符串（小写）
        let crcHex = String(format: "%x", sum)
        
        // 取最后两位作为 CRC 校验值
        if crcHex.count >= 2 {
            return String(crcHex.suffix(2))
        } else if crcHex.count == 1 {
            return "0" + crcHex
        } else {
            return "00"
        }
    }
    
    /// 将十六进制字符串转换为 Data（带 CRC）
    /// - Parameter hexString: 十六进制字符串
    /// - Returns: 转换后的 Data
    static func dataWithHexString(_ hexString: String) -> Data {
        return data(from: hexString)
    }
    ///mac地址转为字符串格式
    static func reversedHexString(from data: Data) -> String {
        let bytes = [UInt8](data)
        var hex = ""

        // 前两个字节交换
        if bytes.count >= 2 {
            hex += String(format: "%02x%02x", bytes[1], bytes[0])
        } else if bytes.count == 1 {
            hex += String(format: "%02x", bytes[0])
        }

        // 后面字节逆序输出（从末尾到 index=2）
        if bytes.count > 2 {
            for i in stride(from: bytes.count - 1, through: 2, by: -1) {
                hex += String(format: "%02x", bytes[i])
            }
        }
        return hex
    }
    
    /// 计算校验和（Terminator）- 将十六进制字符串每两个字符相加，返回最后两位十六进制
    /// - Parameter hexString: 十六进制字符串
    /// - Returns: 校验和（2位十六进制字符串，小写）
    static func getTerminator(from hexString: String) -> String {
        var sum = 0
        var index = hexString.startIndex
        
        // 每两个字符一组
        while index < hexString.endIndex {
            let endIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
            let hexPair = String(hexString[index..<endIndex])
            
            if let value = Int(hexPair, radix: 16) {
                sum += value
            }
            
            index = endIndex
        }
        
        // 转换为十六进制字符串（小写）
        let hexResult = String(format: "%x", sum)
        
        // 取最后两位作为校验和
        if hexResult.count >= 2 {
            return String(hexResult.suffix(2))
        } else if hexResult.count == 1 {
            return "0" + hexResult
        } else {
            return "00"
        }
    }
    
    /// 从十六进制字符串计算 CRC 校验值（与 calculateCRC 功能相同，保持兼容性）
    /// - Parameter hexString: 十六进制字符串
    /// - Returns: CRC 校验值（2位十六进制字符串，小写）
    static func calculateCRCFromHexString(_ hexString: String) -> String {
        return calculateCRC(from: hexString)
    }
}


extension NSData {
    /// 将十六进制字符串转换为 NSData
    /// - Parameter hexString: 形如 "88dd1f1503..." 的十六进制字符串
    /// - Returns: NSData 对象
    class func dataWithHexString(_ hexString: String) -> NSData {
        let data = NSMutableData()
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
                           .replacingOccurrences(of: " ", with: "")
        
        // 补齐奇数位（防止崩溃）
        if hex.count % 2 != 0 {
            hex = "0" + hex
        }

        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<nextIndex]
            if let byte = UInt8(byteString, radix: 16) {
                var value = byte
                data.append(&value, length: 1)
            }
            index = nextIndex
        }
        return data
    }
    ///NSData 再转回十六进制字符串
    func hexString() -> String {
        var bytes = [UInt8](repeating: 0, count: self.length)
        self.getBytes(&bytes, length: self.length)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    
}
