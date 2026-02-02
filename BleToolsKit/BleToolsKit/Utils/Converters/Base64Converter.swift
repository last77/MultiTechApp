//
//  Base64Converter.swift
//  TabBarTest
//
//  Created by app on 2025/11/5.
//

import Foundation

final class Base64Converter {
    /// Data -> HEX（大写）
    static func hexString(from data: Data) -> String {
        var s = ""
        s.reserveCapacity(data.count * 2)
        for b in data {
            s += String(format: "%02X", b)
        }
        return s
    }
}

/// 与 OC 等价：十六进制字符串 -> NSData
extension NSData {
    /// 允许包含空格/换行；奇数字符长度会在前面补 '0'
    class func fromHexString(_ hexString: String) -> NSData? {
        var hex = hexString
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if hex.isEmpty { return NSData() }

        if hex.count % 2 != 0 {
            hex = "0" + hex
        }

        let data = NSMutableData(capacity: hex.count / 2) ?? NSMutableData()
        var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            let byteStr = hex[i..<j]
            if let v = UInt8(byteStr, radix: 16) {
                var vv = v
                data.append(&vv, length: 1)
            } else {
                // 非法字符，返回 nil
                return nil
            }
            i = j
        }
        return data
    }
}
