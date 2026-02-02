//
//  BleAPI.swift
//  BleToolsKit
//
//  蓝牙SDK - 对外API接口
//

import Foundation
import CoreBluetooth

/// 蓝牙SDK - 对外暴露的核心接口
public final class BleAPI {
    
    // MARK: - 单例
    public static let shared = BleAPI()
    
    // MARK: - 配置
    
    /// 连接超时时间（秒），默认10秒
    public var timeout: TimeInterval = 10
    
    // MARK: - 回调
    
    /// 扫描到设备回调
    /// - Parameters:
    ///   - deviceInfo: 设备信息（包含ID、名称、信号强度、是否已连接等）
    public var onDeviceFound: ((BleDeviceInfo) -> Void)?
    
    /// 连接成功回调
    public var onConnected: (() -> Void)?
    
    /// 收到数据回调 (十六进制字符串)
    public var onDataReceived: ((String) -> Void)?
    
    /// 错误回调
    public var onError: ((String) -> Void)?
    
    /// 日志回调（用于调试）
    public var onLog: ((String) -> Void)? {
        didSet {
            central.onLog = onLog
        }
    }
    
    /// 断开连接回调
    public var onDisconnected: (() -> Void)?
    
    // MARK: - 内部状态
    private let central = BleCentral.shared
    private let deviceManager = BleDeviceManager.shared
    private var scanToken: ScanToken?
    private var scannedDevices: [String: BleDevice] = [:]
    private var currentDeviceId: String?
    private var currentDevice: BleDevice?
    private var currentPeripheral: CBPeripheral?
    private var characteristics: [CBCharacteristic] = []
    
    private init() {}
    
    // MARK: - ⭐️ 核心接口 ⭐️
    
    /// 1️⃣ 扫描设备
    /// - Parameters:
    ///   - includeConnectedDevices: 是否包含系统已连接的设备（默认 true）
    ///   - customFilter: 自定义过滤器（可选）
    public func scan(
        includeConnectedDevices: Bool = true,
        customFilter: BleFilterProtocol? = nil
    ) {
        scanToken?.stop()
        scannedDevices.removeAll()
        
        let filter = BleFilter(
            serviceUUIDs: nil,
            allowDuplicates: false,
            includeConnectedDevices: includeConnectedDevices,
            customFilter: customFilter
        )
        
        scanToken = central.startScan(filter: filter) { [weak self] device in
            guard let self = self else { return }
            
            // 应用自定义过滤器
            if let customFilter = customFilter {
                guard customFilter.shouldInclude(peripheral: device.peripheral) else {
                    return
                }
            }
            
            self.scannedDevices[device.identifier] = device
            
            // 将内部 BleDevice 转换为对外的 BleDeviceInfo
            let deviceInfo = BleDeviceInfo(from: device)
            self.onDeviceFound?(deviceInfo)
            
            // 记录日志
            let connectedStatus = device.isConnected ? "已连接" : "未连接"
            let deviceTypeStr = device.deviceType.rawValue
            self.onLog?("📱 发现设备: \(device.name) | 类型: \(deviceTypeStr) | 状态: \(connectedStatus) | RSSI: \(device.rssi)")
        } onError: { [weak self] error in
            self?.onError?(error.localizedDescription)
        }
    }
    
    /// 2️⃣ 连接设备
    /// - Parameter deviceId: 设备ID（从扫描回调中获取）
    public func connect(deviceId: String) {
        guard let device = scannedDevices[deviceId] else {
            onError?("设备未找到，请先扫描")
            return
        }
        
        scanToken?.stop()
        currentDeviceId = deviceId
        currentDevice = device
        
        // 根据设备类型获取服务和特征 UUID
        let services = deviceManager.getServiceUUIDs(for: device.deviceType)
        let chars = deviceManager.getCharacteristicUUIDs(for: device.deviceType)
        
        onLog?("🔗 开始连接设备: \(device.name) | 类型: \(device.deviceType.rawValue)")
        
        central.connect(device, timeout: timeout) { [weak self] peripheral in
            guard let self = self else { return }
            self.currentPeripheral = peripheral
            
            self.onLog?("✅ 设备连接成功，开始发现服务...")
            
            self.central.discoverCharacteristics(
                for: peripheral,
                serviceUUIDs: services,
                characteristicUUIDs: chars
            ) { [weak self] foundChars in
                guard let self = self else { return }
                self.characteristics = foundChars
                
                self.onLog?("✅ 服务发现成功，共找到 \(foundChars.count) 个特征")
                
                // 自动订阅所有支持通知的特征
                for char in foundChars where char.properties.contains(.notify) {
                    self.central.setNotify(true, for: char, onUpdate: { [weak self] hexString in
                        guard let self = self else { return }
                        self.onLog?("📩 收到数据: \(hexString)")
                        self.onDataReceived?(hexString)
                    }, onError: { _ in })
                }
                
                self.onConnected?()
            } onError: { [weak self] error in
                self?.onError?("发现服务失败: \(error.localizedDescription)")
            }
        } onError: { [weak self] error in
            self?.onError?("连接失败: \(error.localizedDescription)")
        }
    }
    
    /// 3️⃣ 发送数据
    /// - Parameter hexString: 十六进制字符串（如 "0102FF"）
    public func send(_ hexString: String) {
        guard !characteristics.isEmpty else {
            onError?("未连接或未发现特征")
            return
        }
        
        guard let data = BleDataConverter.hexStringToData(hexString) else {
            onError?("数据格式错误")
            return
        }
        
        guard let writeChar = characteristics.first(where: {
            $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse)
        }) else {
            onError?("未找到可写特征")
            return
        }
        
        onLog?("📤 发送数据: \(hexString)")
        
        central.write(data: data, to: writeChar) { [weak self] error in
            self?.onError?("发送失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 辅助方法
    
    /// 停止扫描
    public func stopScan() {
        scanToken?.stop()
        onLog?("⏹ 停止扫描")
    }
    
    /// 断开连接
    public func disconnect() {
        if let peripheral = currentPeripheral {
            central.disconnect(peripheral)
            onLog?("🔌 断开连接: \(currentDevice?.name ?? "未知设备")")
        }
        currentPeripheral = nil
        currentDeviceId = nil
        currentDevice = nil
        characteristics.removeAll()
        onDisconnected?()
    }
    
    /// 获取当前连接的设备信息
    /// - Returns: 设备信息（如果已连接）
    public func getCurrentDevice() -> BleDeviceInfo? {
        guard let device = currentDevice else {
            return nil
        }
        return BleDeviceInfo(from: device)
    }
    
    /// 获取已扫描到的所有设备
    /// - Returns: 设备信息数组
    public func getScannedDevices() -> [BleDeviceInfo] {
        return scannedDevices.values.map { BleDeviceInfo(from: $0) }
    }
    
    // MARK: - 肺活量计专用方法
    
    /// FVC 测试
    public func fvc() {
        guard let device = currentDevice else {
            onError?("设备未连接")
            return
        }
        
        onLog?("🔵 [FVC] 开始发送 FVC 测试指令")
        central.fvc { [weak self] error in
            self?.onError?("FVC 测试失败: \(error.localizedDescription)")
            self?.onLog?("🔴 [FVC] 测试失败: \(error.localizedDescription)")
        }
    }
    
    /// VC 测试
    public func vc() {
        guard let device = currentDevice else {
            onError?("设备未连接")
            return
        }
        
        onLog?("🔵 [VC] 开始发送 VC 测试指令")
        central.vc { [weak self] error in
            self?.onError?("VC 测试失败: \(error.localizedDescription)")
            self?.onLog?("🔴 [VC] 测试失败: \(error.localizedDescription)")
        }
    }
    
    /// MVV 测试
    public func mvv() {
        guard let device = currentDevice else {
            onError?("设备未连接")
            return
        }
        
        onLog?("🔵 [MVV] 开始发送 MVV 测试指令")
        central.mvv { [weak self] error in
            self?.onError?("MVV 测试失败: \(error.localizedDescription)")
            self?.onLog?("🔴 [MVV] 测试失败: \(error.localizedDescription)")
        }
    }
    
    /// 停止 FVC 测试
    public func stopFvc() {
        central.stopFvc { [weak self] error in
            self?.onError?("停止 FVC 测试失败: \(error.localizedDescription)")
        }
    }
    
    /// 停止 VC 测试
    public func stopVc() {
        central.stopVc { [weak self] error in
            self?.onError?("停止 VC 测试失败: \(error.localizedDescription)")
        }
    }
    
    /// 停止 MVV 测试
    public func stopMvv() {
        central.stopMvv { [weak self] error in
            self?.onError?("停止 MVV 测试失败: \(error.localizedDescription)")
        }
    }
}

