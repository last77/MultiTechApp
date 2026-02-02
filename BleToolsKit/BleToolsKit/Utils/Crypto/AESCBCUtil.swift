//
//  AESCBCutil.swift
//  TabBarTest
//
//  Created by app on 2025/11/5.
//

import Foundation
import CommonCrypto
/// 固定密钥/IV（示例占位，务必替换为你项目中的真实值，16字节）
private let kAESKey: [UInt8] = [
    0xE4, 0xf5, 0x06, 0x17, 0x28, 0x39, 0x4A, 0x5B,
    0x6C, 0x7D, 0x11, 0x33, 0x55, 0x77, 0x99, 0xBB
]
/// 初始化向量 IV (16字节)
private let kAESIV: [UInt8] = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
]
private let keyPool: [[UInt8]] = [
    [0x2B,0x7E,0x15,0x16,0x28,0xAE,0xD2,0xA6,0xAB,0xF7,0x15,0x88,0x09,0xCF,0x4F,0x3C],
    [0x00,0x01,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xDD,0xEE,0xFF],
    [0xFF,0xEE,0xDD,0xCC,0xBB,0xAA,0x99,0x88,0x77,0x66,0x55,0x44,0x33,0x22,0x11,0x00],
    [0x1A,0xCF,0x78,0x34,0x9D,0xE0,0x52,0xB7,0xAC,0x6F,0x05,0x91,0xBB,0x2E,0x48,0x7C],
    [0xA0,0xB1,0xC2,0xD3,0xE4,0xF5,0x06,0x17,0x28,0x39,0x4A,0x5B,0x6C,0x7D,0x8E,0x9F],
    [0xF0,0x0E,0x1D,0x2C,0x3B,0x4A,0x59,0x68,0x77,0x86,0x95,0xA4,0xB3,0xC2,0xD1,0xE0],
    [0x09,0x87,0x65,0x43,0x21,0x0F,0xED,0xCB,0xA9,0x87,0x65,0x43,0x21,0x0F,0xED,0xCB],
    [0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA],
    [0x13,0x57,0x9B,0xDF,0x24,0x68,0xAC,0xE0,0x35,0x79,0xBD,0x01,0x46,0x8A,0xCE,0x12],
    [0xC5,0xE9,0x0D,0x31,0x75,0xB9,0xFD,0x21,0x65,0xA9,0xD3,0xB7,0x9B,0x5F,0x23,0x47]
]

final class AESCBCUtil {
    /// 使用固定密钥加密十六进制字符串数据（Zero 填充 + AES-CBC + NoPadding）
    /// - Parameter hexString: 输入十六进制字符串（支持大小写与空白）
    /// - Returns: 加密后的十六进制（大写），失败返回 nil
    static func encryptHexStringWithFixedKey(_ hexString: String?) -> String? {
        guard let hexString = hexString, !hexString.isEmpty else { return nil }
        
        // 1) hex -> Data
        guard let sourceData = NSData.dataWithHexString(hexString) as Data? else { return nil }
        
        // 2) Zero 填充到 16 字节边界（与 OC 版本一致：即使已是整块，也再加一整块 16 字节零）
        let padded = zeroPadData(sourceData)
        
        // 3) AES-CBC/NoPadding（因为我们自己做了 Zero 填充）
        guard let encrypted = performAESOperationWithFixedKey(operation: CCOperation(kCCEncrypt),
                                                              data: padded) else {
            return nil
        }
        
        // 4) 输出为大写十六进制
        return Base64Converter.hexString(from: encrypted).uppercased()
    }
    /// 使用固定密钥解密十六进制字符串数据（Zero 填充 + AES-CBC + NoPadding）
    /// - Parameter encryptedHexString: 待解密的十六进制字符串
    /// - Returns: 解密后的十六进制（大写），失败返回 nil
    static func decryptHexStringWithFixedKey(_ encryptedHexString: String?) -> String? {
        guard let encryptedHexString = encryptedHexString, !encryptedHexString.isEmpty else { return nil }
        
        // 1) HEX -> Data
        guard let encryptedData = NSData.dataWithHexString(encryptedHexString) as Data? else { return nil }
        
        // 2) 如不是 16 的整数倍，先 Zero 补齐（与 OC 行为一致）
        let input: Data
        if encryptedData.count % kCCBlockSizeAES128 != 0 {
            input = zeroPadData(encryptedData)
            // 如需日志，可在此打印原长度/填充后长度
        } else {
            input = encryptedData
        }
        
        // 3) 解密（AES-CBC / NoPadding）
        guard let decrypted = performAESOperationWithFixedKey(operation: CCOperation(kCCDecrypt),
                                                              data: input) else {
            return nil
        }
        
        // 4) 去掉结尾的 Zero 填充（注意：Zero padding 无法区分真实末尾 0 与填充 0）
        let unpadded = removeZeroPadding(decrypted)
        
        // 5) 输出为大写十六进制
        return Base64Converter.hexString(from: unpadded).uppercased()
    }
    
    // MARK: - 对外：使用 keyIndex + 密钥池 加密（Zero 填充）
    /// 使用指定密钥ID加密十六进制字符串数据（Zero 填充 + AES-CBC + NoPadding）
    /// - Parameters:
    ///   - hexString: 待加密十六进制字符串
    ///   - keyIndex: 密钥池索引 0...9
    /// - Returns: 加密后的十六进制（大写），失败返回 nil
    static func encryptHexStringZeroPadding(_ hexString: String, keyIndex: Int) -> String? {
        guard !hexString.isEmpty else { return nil }
        guard let sourceData = NSData.fromHexString(hexString) as Data? else { return nil }
        
        // Zero 填充到 ((len/16)+1)*16 —— 与 OC 一致
        let padded = zeroPadData(sourceData)
        
        // AES-CBC / NoPadding（我们已手动填充）
        guard let encrypted = performAESOperationZeroPadding(operation: CCOperation(kCCEncrypt),
                                                             data: padded,
                                                             keyIndex: keyIndex) else {
            return nil
        }
        return Base64Converter.hexString(from: encrypted).uppercased()
    }
    
    // （可选）解密：便于联调验证
    static func decryptHexStringZeroPadding(_ encryptedHexString: String, keyIndex: Int) -> String? {
        guard !encryptedHexString.isEmpty else { return nil }
        guard let enc = NSData.fromHexString(encryptedHexString) as Data? else { return nil }
        
        // 如果不是 16 整数倍，先补零（与 OC 一致）
        let input = (enc.count % kCCBlockSizeAES128 == 0) ? enc : zeroPadData(enc)
        
        guard let decrypted = performAESOperationZeroPadding(operation: CCOperation(kCCDecrypt),
                                                             data: input,
                                                             keyIndex: keyIndex) else {
            return nil
        }
        let unpadded = removeZeroPadding(decrypted)
        return Base64Converter.hexString(from: unpadded).uppercased()
    }
    
    // MARK: - 核心 AES 调用（Zero 填充模式）
    private static func performAESOperationZeroPadding(operation: CCOperation, data: Data, keyIndex: Int) -> Data? {
        // 生成 key = keyPool[keyIndex] XOR kAESKey
        guard let keyData = generateKey(keyIndex: keyIndex) else { return nil }
        
        let dataLength = data.count
        var out = Data(count: dataLength)     // NoPadding 下输出与输入等长
        let outCount = out.count              // 避免闭包中访问 out 引发 overlapping access
        var bytesProcessed: size_t = 0
        
        let status: CCCryptorStatus = out.withUnsafeMutableBytes { outBuf -> CCCryptorStatus in
            guard let outPtr = outBuf.baseAddress else { return CCCryptorStatus(kCCMemoryFailure) }
            
            return data.withUnsafeBytes { inBuf -> CCCryptorStatus in
                guard let inPtr = inBuf.baseAddress else { return CCCryptorStatus(kCCMemoryFailure) }
                
                return keyData.withUnsafeBytes { keyBuf -> CCCryptorStatus in
                    guard let keyPtr = keyBuf.baseAddress else { return CCCryptorStatus(kCCMemoryFailure) }
                    
                    return kAESIV.withUnsafeBytes { ivBuf -> CCCryptorStatus in
                        guard let ivPtr = ivBuf.baseAddress else { return CCCryptorStatus(kCCMemoryFailure) }
                        
                        return CCCrypt(operation,
                                       CCAlgorithm(kCCAlgorithmAES128),
                                       CCOptions(0), // NoPadding（我们自己做了 Zero 填充）
                                       keyPtr, kCCKeySizeAES128,
                                       ivPtr,
                                       inPtr, dataLength,
                                       outPtr, outCount,
                                       &bytesProcessed)
                    }
                }
            }
        }
        
        if status == kCCSuccess {
            return out.prefix(bytesProcessed)
        } else {
            // print("AES \(operation == CCOperation(kCCEncrypt) ? "Encrypt" : "Decrypt") failed: \(status)")
            return nil
        }
    }
    // MARK: - 密钥池 / 异或生成新密钥
    private static func generateKey(keyIndex: Int) -> Data? {
        guard keyIndex >= 0, keyIndex < keyPool.count else { return nil }
        let pool = keyPool[keyIndex]
        guard pool.count == kCCKeySizeAES128 else { return nil }
        
        var xorKey = [UInt8](repeating: 0, count: kCCKeySizeAES128)
        for i in 0..<kCCKeySizeAES128 {
            xorKey[i] = pool[i] ^ kAESKey[i]
        }
        return Data(xorKey)
    }
    /// 移除 Zero 填充（从尾部剔除 0x00）
    private static func removeZeroPadding(_ data: Data) -> Data {
        var end = data.count
        while end > 0 && data[end - 1] == 0 { end -= 1 }
        return data.prefix(end)
    }
    /// Zero 填充到 16 字节边界（总是多加一块，就像你的 OC 实现）
    private static func zeroPadData(_ data: Data) -> Data {
        let dataLength = data.count
        let paddedLength = ((dataLength / kCCBlockSizeAES128) + 1) * kCCBlockSizeAES128
        var out = Data(data)
        let paddingLength = paddedLength - dataLength
        if paddingLength > 0 {
            out.append(Data(repeating: 0x00, count: paddingLength))
        }
        return out
    }
    private static func performAESOperationWithFixedKey(operation: CCOperation, data: Data) -> Data? {
        let dataLength = data.count
        var out = Data(count: dataLength)
        let outCount = out.count
        var bytesProcessed: size_t = 0
        
        let status: CCCryptorStatus = out.withUnsafeMutableBytes { outBuf -> CCCryptorStatus in
            guard let outPtr = outBuf.baseAddress else { return CCCryptorStatus(kCCMemoryFailure) }
            
            return data.withUnsafeBytes { inBuf -> CCCryptorStatus in
                guard let inPtr = inBuf.baseAddress else { return CCCryptorStatus(kCCMemoryFailure) }
                
                return kAESKey.withUnsafeBytes { keyBuf -> CCCryptorStatus in
                    guard let keyPtr = keyBuf.baseAddress else { return CCCryptorStatus(kCCMemoryFailure) }
                    
                    return kAESIV.withUnsafeBytes { ivBuf -> CCCryptorStatus in
                        guard let ivPtr = ivBuf.baseAddress else { return CCCryptorStatus(kCCMemoryFailure) }
                        
                        return CCCrypt(operation,
                                       CCAlgorithm(kCCAlgorithmAES128),
                                       CCOptions(0),            // NoPadding（你已手动 Zero 填充）
                                       keyPtr, kCCKeySizeAES128,
                                       ivPtr,
                                       inPtr, dataLength,
                                       outPtr, outCount,
                                       &bytesProcessed)
                    }
                }
            }
        }
        
        if status == kCCSuccess {
            return out.prefix(bytesProcessed)
        } else {
            return nil
        }
    }
}
