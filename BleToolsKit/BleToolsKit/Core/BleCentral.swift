//
//  BleCentral.swift
//  BleToolsKit
//
//  Created by app on 2025/10/20.
//

import Foundation
import CoreBluetooth

// 内部类，不对外暴露
internal final class BleCentral: NSObject {

    // MARK: Singleton（也可自行实例化）
    internal static let shared = BleCentral()
    private override init() {
        queue = DispatchQueue(label: "ble.central.queue")
        super.init()
        central = CBCentralManager(delegate: self, queue: queue)
        loadDeviceMacMapping()
    }

    // MARK: Private state
    private let queue: DispatchQueue
    private var central: CBCentralManager!
    private var seen = Set<UUID>()
    private var onFound: ((BleDevice) -> Void)?
    private var onScanError: ((Error) -> Void)?
    private var scanFilter: BleFilter = .init()
    
    // 日志回调
    internal var onLog: ((String) -> Void)?

    // 连接态
    private var connectContinuations: [UUID: (Result<CBPeripheral, Error>) -> Void] = [:]
    private var notifyHandlers: [CBUUID: (String) -> Void] = [:]
    private var valueHandlers:  [CBUUID: (Result<String, Error>) -> Void] = [:]
    
    // 特征缓存
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    // 设备缓存：用于在连接时获取设备信息（包括 isNewDevice）
    private var discoveredDevices: [UUID: BleDevice] = [:]
    
    // MAC 地址映射：设备 UUID -> MAC 地址
    private var deviceMacMapping: [String: String] = [:]
    
    // 当前设备的 MAC 地址（全局变量，供其他地方使用）
    internal var macAddress: String?
    
    // 密钥池索引（用于加密通信）
    internal var poolIndex: Int = 0
    private var isNewDevice: Bool = false
    
    // 目标 UUID 常量
    private let targetServiceUUID = CBUUID(string: BleConstants.ServiceUUIDs.targetService)
    private let writeCharUUID = CBUUID(string: BleConstants.CharacteristicUUIDs.write)
    private let notifyCharUUID = CBUUID(string: BleConstants.CharacteristicUUIDs.notify)

    // MARK: Scanning
    @discardableResult
    internal func startScan(
        filter: BleFilter = .init(),
        onFound: @escaping (BleDevice) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ScanToken {
        self.scanFilter = filter
        self.onFound = onFound
        self.onScanError = onError

        if central.state == .poweredOn {
            beginScan()
        } else {
            reportStateErrorIfNeeded()
        }

        return Token { [weak self] in self?.stopScan() }
    }

    internal func stopAllScans() { stopScan() }

    // MARK: Connect
    /// 超时（秒）可选，默认 10 秒
    internal func connect(
        _ device: BleDevice,
        timeout: TimeInterval = 10,
        onReady: @escaping (CBPeripheral) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let p = device.peripheral
        p.delegate = self
        connectContinuations[p.identifier] = { result in
            switch result {
            case .success(let per): onReady(per)
            case .failure(let e):   onError(e)
            }
        }

        queue.async { [weak self] in
            guard let self else { return }
            self.central.connect(p, options: nil)
            // 超时逻辑
            self.queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self else { return }
                if self.connectContinuations[p.identifier] != nil {
                    self.central.cancelPeripheralConnection(p)
                    self.finishConnect(p, with: .failure(BleError.timeout))
                }
            }
        }
    }

    internal func disconnect(_ peripheral: CBPeripheral) {
        queue.async { [weak self] in self?.central.cancelPeripheralConnection(peripheral) }
    }

    // MARK: Discover services/chars
    /// 连接后发现服务与特征
    internal func discoverCharacteristics(
        for peripheral: CBPeripheral,
        serviceUUIDs: [CBUUID],
        characteristicUUIDs: [CBUUID],
        onReady: @escaping ([CBCharacteristic]) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        peripheral.delegate = self
        peripheral.discoverServices(serviceUUIDs)

        // 暂存一个一次性的完成回调：发现所有特征后返回
        // 简化：我们在 didDiscoverCharacteristicsFor 每次累计，全部找到后回调
        DiscoverContext.shared.setExpectation(
            periph: peripheral,
            targetServiceUUIDs: Set(serviceUUIDs),
            targetCharUUIDs: Set(characteristicUUIDs),
            onReady: onReady, onError: onError
        )
    }

    // MARK: Write / Read / Notify
    internal func write(
        data: Data,
        to characteristic: CBCharacteristic,
        onError: @escaping (Error) -> Void
    ) {
        guard let p = characteristic.service?.peripheral else {
            onError(BleError.unknown); return
        }
        // 优先使用 withResponse
        let props = characteristic.properties
        let type: CBCharacteristicWriteType = props.contains(.write) ? .withResponse : .withoutResponse
        p.writeValue(data, for: characteristic, type: type)
        // 若需要回执/错误，可在 peripheral:didWriteValueFor 捕获错误
        WriteContext.shared.remember(char: characteristic, onError: onError)
    }

    internal func setNotify(
        _ enabled: Bool,
        for characteristic: CBCharacteristic,
        onUpdate: ((String) -> Void)?,
        onError: @escaping (Error) -> Void
    ) {
        guard let p = characteristic.service?.peripheral else { onError(BleError.unknown); return }
        notifyHandlers[characteristic.uuid] = onUpdate
        p.setNotifyValue(enabled, for: characteristic)
        // 成功与否在 didUpdateNotificationStateFor 回调
        NotifyContext.shared.remember(char: characteristic, onError: onError)
    }

    internal func readValue(
        for characteristic: CBCharacteristic,
        onValue: @escaping (Result<String, Error>) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        guard let p = characteristic.service?.peripheral else { onError(BleError.unknown); return }
        valueHandlers[characteristic.uuid] = onValue
        p.readValue(for: characteristic)
        // 结果见 didUpdateValueFor
    }

    // MARK: Internal helpers
    private func beginScan() {
        seen.removeAll()
        
        // 如果需要包含已连接设备，先获取并返回它们
        if scanFilter.includeConnectedDevices {
            retrieveConnectedDevices()
        }
        
        let opts: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: scanFilter.allowDuplicates
        ]
        central.scanForPeripherals(withServices: scanFilter.serviceUUIDs, options: opts)
    }
    
    /// 获取系统中已连接的设备
    private func retrieveConnectedDevices() {
        // 使用目标服务 UUID 获取已连接的设备
        let serviceUUIDs = scanFilter.serviceUUIDs ?? [targetServiceUUID]
        let connectedPeripherals = central.retrieveConnectedPeripherals(withServices: serviceUUIDs)
        
        #if DEBUG
        print("📱 检索到 \(connectedPeripherals.count) 个已连接设备")
        #endif
        
        for peripheral in connectedPeripherals {
            // 判断是否为目标设备
            if BleDeviceNameFilter.shared.isTargetDevice(peripheral: peripheral) {
                let deviceUUID = peripheral.identifier.uuidString
                
                #if DEBUG
                print("✅ 发现已连接的目标设备: \(peripheral.name ?? "nil")")
                #endif
                
                // 尝试从存储中获取 MAC 地址
                if let existingMacAddress = BleStorage.shared.getMacAddress(for: deviceUUID) {
                    self.macAddress = existingMacAddress
                    deviceMacMapping[deviceUUID] = existingMacAddress
                    #if DEBUG
                    print("使用已保存的MAC地址映射: \(deviceUUID) -> \(existingMacAddress)")
                    #endif
                }
                
                // 创建设备对象（RSSI 设为 0，因为已连接设备无法获取实时 RSSI）
                let device = BleDevice(peripheral: peripheral, rssi: 0, macAddress: self.macAddress)
                
                // 缓存设备信息
                discoveredDevices[peripheral.identifier] = device
                
                // 标记为已发现，避免扫描时重复回调
                if !scanFilter.allowDuplicates {
                    seen.insert(peripheral.identifier)
                }
                
                #if DEBUG
                print("缓存已连接设备信息: UUID=\(deviceUUID), MAC=\(self.macAddress ?? "nil"), 是否新设备=\(device.isNewDevice ? "是" : "否")")
                #endif
                
                // 回调给上层
                onFound?(device)
            }
        }
    }

    private func stopScan() {
        central.stopScan()
        seen.removeAll()
        // 注意：不清空 discoveredDevices，以便连接时使用
    }

    private func finishConnect(_ p: CBPeripheral, with result: Result<CBPeripheral, Error>) {
        let key = p.identifier
        let cont = connectContinuations.removeValue(forKey: key)
        cont?(result)
    }

    private func reportStateErrorIfNeeded() {
        switch central.state {
        case .poweredOn: break
        case .unsupported: onScanError?(BleError.unsupported)
        case .unauthorized: onScanError?(BleError.unauthorized)
        case .poweredOff:  onScanError?(BleError.poweredOff)
        default: break
        }
    }
    
    // MARK: - MAC 地址映射管理
    /// 加载已保存的设备 MAC 地址映射
    private func loadDeviceMacMapping() {
        deviceMacMapping = BleStorage.shared.loadDeviceMacMapping()
        #if DEBUG
        if deviceMacMapping.isEmpty {
            print("没有找到已保存的设备MAC映射")
        } else {
            print("加载已保存的设备MAC映射，共 \(deviceMacMapping.count) 条记录")
        }
        #endif
    }
    
    // MARK: - 发送绑定指令
    private func sendBindCommand() {
        guard let writeChar = writeCharacteristic,
              let peripheral = writeChar.service?.peripheral,
              let device = discoveredDevices[peripheral.identifier] else {
            #if DEBUG
            print("写特征未准备好或设备信息不存在，无法发送绑定指令")
            #endif
            return
        }
        
        // 使用 BleDeviceManager 构建绑定指令
        let commandHex = BleDeviceManager.shared.buildBindCommand(for: device, poolIndex: poolIndex)
        
        guard !commandHex.isEmpty else {
            #if DEBUG
            print("❌ 绑定指令构建失败")
            #endif
            return
        }
        
        let logMsg = "📲 [\(device.isNewDevice ? "新设备" : "老设备")] 发送绑定指令: \(commandHex)"
        onLog?(logMsg)
        #if DEBUG
        print(logMsg)
        #endif
        
        // 转换为 Data 并发送
        let commandData = DataConverter.dataWithHexString(commandHex)
        peripheral.writeValue(commandData, for: writeChar, type: .withResponse)
    }
    
    // MARK: - 测试方法（fvc, vc, mvv）
    
    /// FVC 测试方法
    /// - Parameter onError: 错误回调
    internal func fvc(onError: @escaping (Error) -> Void) {
        sendSpirometerCommand(.fvc, onError: onError)
    }
    
    /// VC 测试方法
    /// - Parameter onError: 错误回调
    internal func vc(onError: @escaping (Error) -> Void) {
        sendSpirometerCommand(.vc, onError: onError)
    }
    
    /// MVV 测试方法
    /// - Parameter onError: 错误回调
    internal func mvv(onError: @escaping (Error) -> Void) {
        sendSpirometerCommand(.mvv, onError: onError)
    }
    
    // MARK: - 停止测试方法
    
    /// 停止 FVC 测试方法
    /// - Parameter onError: 错误回调
    internal func stopFvc(onError: @escaping (Error) -> Void) {
        sendSpirometerCommand(.stopFvc, onError: onError)
    }
    
    /// 停止 VC 测试方法
    /// - Parameter onError: 错误回调
    internal func stopVc(onError: @escaping (Error) -> Void) {
        sendSpirometerCommand(.stopVc, onError: onError)
    }
    
    /// 停止 MVV 测试方法
    /// - Parameter onError: 错误回调
    internal func stopMvv(onError: @escaping (Error) -> Void) {
        sendSpirometerCommand(.stopMvv, onError: onError)
    }
    
    /// 发送肺活量计命令的通用方法
    /// - Parameters:
    ///   - command: 肺活量计命令枚举
    ///   - onError: 错误回调
    private func sendSpirometerCommand(_ command: SpirometerCommand, onError: @escaping (Error) -> Void) {
        guard let writeChar = writeCharacteristic else {
            let errorMsg = "❌ 写特征未准备好，无法发送命令"
            onLog?(errorMsg)
            #if DEBUG
            print(errorMsg)
            #endif
            onError(BleError.characteristicNotFound)
            return
        }
        
        // 使用 SpirometerCommandBuilder 构建命令
        let commandImpl = SpirometerCommandImpl(command: command)
        let commandHex = commandImpl.buildCommand(isNewDevice: isNewDevice, poolIndex: poolIndex)
        
        guard !commandHex.isEmpty else {
            let errorMsg = "❌ 命令构建失败"
            onLog?(errorMsg)
            #if DEBUG
            print(errorMsg)
            #endif
            onError(BleError.invalidData)
            return
        }
        
        let logMsg = "📤 发送 \(command.rawValue) 命令: \(commandHex)"
        onLog?(logMsg)
        #if DEBUG
        print(logMsg)
        #endif
        
        // 发送命令（使用密钥池加密）
        sendCommandWithCrc(origin: commandHex, usePool: true, to: writeChar, onError: onError)
    }
    
    // MARK: - 发送命令（带 CRC 和加密）
    
    /// 发送带 CRC 的命令（支持加密）- 内部方法
    /// - Parameters:
    ///   - origin: 原始十六进制字符串
    ///   - usePool: 是否使用密钥池加密
    ///   - characteristic: 写入特征
    ///   - onError: 错误回调
    private func sendCommandWithCrc(origin: String, usePool: Bool, to characteristic: CBCharacteristic, onError: @escaping (Error) -> Void) {
        guard !origin.isEmpty else {
            onError(BleError.invalidData)
            return
        }
        
        // 如果是老设备，直接发送原始数据，不加密
        if !isNewDevice {
            let logMsg = "📱 [老设备] 直接发送原始数据: \(origin)"
            onLog?(logMsg)
            #if DEBUG
            print(logMsg)
            #endif
            let commandData = DataConverter.data(from: origin)
            write(data: commandData, to: characteristic, onError: onError)
            return
        }
        
        // 新设备：使用 BleCommandBuilder 加密
        guard let encryptedHex = BleCommandBuilder.buildEncryptedCommand(
            origin,
            isNewDevice: isNewDevice,
            poolIndex: poolIndex,
            usePool: usePool
        ) else {
            let logMsg = "❌ [新设备] 加密失败"
            onLog?(logMsg)
            #if DEBUG
            print(logMsg)
            #endif
            onError(BleError.encryptionFailed)
            return
        }
        
        let logMsg = "🔐 [新设备] \(usePool ? "密钥池(\(poolIndex))" : "固定密钥")加密完成"
        onLog?(logMsg)
        #if DEBUG
        print(logMsg)
        print("   原始: \(origin)")
        print("   加密: \(encryptedHex)")
        #endif
        
        // 转换为 Data 并写入
        let commandData = DataConverter.data(from: encryptedHex)
        write(data: commandData, to: characteristic, onError: onError)
    }
}

// MARK: Token
private final class Token: ScanToken {
    private var stopped = false
    private let stopper: () -> Void
    init(_ s: @escaping () -> Void) { stopper = s }
    func stop() {
        guard !stopped else { return }
        stopped = true; stopper()
    }
}

// MARK: CBCentralManagerDelegate
extension BleCentral: CBCentralManagerDelegate {
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { beginScan() }
        else { reportStateErrorIfNeeded() }
    }

    internal func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {
        if !scanFilter.allowDuplicates {
            guard !seen.contains(peripheral.identifier) else { return }
            seen.insert(peripheral.identifier)
        }
        
        // 判断设备名称是否为目标设备
        if BleDeviceNameFilter.shared.isTargetDevice(peripheral: peripheral) {
            #if DEBUG
            print("发现目标设备: \(peripheral.name ?? "nil")")
            #endif
            
            // 提取并保存 MAC 地址
            let deviceUUID = peripheral.identifier.uuidString
            
            // 先检查是否已有保存的 MAC 地址
            if let existingMacAddress = BleStorage.shared.getMacAddress(for: deviceUUID) {
                self.macAddress = existingMacAddress
                // 同步到本地缓存
                deviceMacMapping[deviceUUID] = existingMacAddress
                #if DEBUG
                print("使用已保存的MAC地址映射: \(deviceUUID) -> \(existingMacAddress)")
                #endif
            } else if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
                // 提取新的 MAC 地址
                self.macAddress = DataConverter.reversedHexString(from: manufacturerData)
                
                // 保存新的 MAC 地址映射
                if let mac = self.macAddress, !mac.isEmpty {
                    deviceMacMapping[deviceUUID] = mac
                    BleStorage.shared.saveMacAddress(mac, for: deviceUUID)
                    #if DEBUG
                    print("保存新的MAC地址映射: \(deviceUUID) -> \(mac)")
                    #endif
                }
            }
            
            // 创建设备对象（初始化时会自动判断是否为新设备）
            let device = BleDevice(peripheral: peripheral, rssi: RSSI.intValue, macAddress: self.macAddress)
            
            // 缓存设备信息，供连接时使用
            discoveredDevices[peripheral.identifier] = device
            
            #if DEBUG
            print("缓存设备信息: UUID=\(deviceUUID), MAC=\(self.macAddress ?? "nil"), 是否新设备=\(device.isNewDevice ? "是" : "否")")
            #endif
            
            onFound?(device)
        }
    }

    internal func centralManager(_ central: CBCentralManager,
                               didConnect peripheral: CBPeripheral) {
        // 连接成功后，从缓存获取设备信息（包括 isNewDevice）
        if let cachedDevice = discoveredDevices[peripheral.identifier] {
            isNewDevice = cachedDevice.isNewDevice
            #if DEBUG
            print("[连接] 设备连接成功（从缓存获取），UUID: \(peripheral.identifier.uuidString), 是否为新设备: \(isNewDevice ? "是" : "否")")
            #endif
        } else {
            // 如果缓存中没有，则重新判断（兜底逻辑）
            let deviceUUID = peripheral.identifier.uuidString
            isNewDevice = BleStorage.shared.isNewDevice(uuidString: deviceUUID)
            #if DEBUG
            print("[连接] 设备连接成功（重新判断），UUID: \(deviceUUID), 是否为新设备: \(isNewDevice ? "是" : "否")")
            #endif
        }
        
        finishConnect(peripheral, with: .success(peripheral))
    }

    internal func centralManager(_ central: CBCentralManager,
                               didFailToConnect peripheral: CBPeripheral,
                               error: Error?) {
        finishConnect(peripheral, with: .failure(error ?? BleError.unknown))
    }

    internal func centralManager(_ central: CBCentralManager,
                               didDisconnectPeripheral peripheral: CBPeripheral,
                               error: Error?) {
        // 广播通知或回调给上层也行，这里简单处理
    }
}

// MARK: CBPeripheralDelegate
extension BleCentral: CBPeripheralDelegate {
    internal func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            #if DEBUG
            print("发现服务失败: \(error.localizedDescription)")
            #endif
            DiscoverContext.shared.handleDidDiscoverServices(peripheral, error: error)
            return
        }
        
        // 过滤目标服务 UUID "1000"
        guard let services = peripheral.services,
              let targetService = services.first(where: { $0.uuid == targetServiceUUID }) else {
            #if DEBUG
            print("未找到目标服务 UUID: 1000")
            #endif
            DiscoverContext.shared.handleDidDiscoverServices(peripheral, error: BleError.unknown)
            return
        }
        
        #if DEBUG
        print("找到目标服务: \(targetService.uuid)")
        #endif
        
        // 发现特征
        peripheral.discoverCharacteristics([writeCharUUID, notifyCharUUID], for: targetService)
        
        DiscoverContext.shared.handleDidDiscoverServices(peripheral, error: error)
    }

    internal func peripheral(_ peripheral: CBPeripheral,
                           didDiscoverCharacteristicsFor service: CBService,
                           error: Error?) {
        if let error = error {
            #if DEBUG
            print("发现特征失败: \(error.localizedDescription)")
            #endif
            DiscoverContext.shared.handleDidDiscoverChars(peripheral, service: service, error: error)
            return
        }
        
        guard let characteristics = service.characteristics else {
            DiscoverContext.shared.handleDidDiscoverChars(peripheral, service: service, error: error)
            return
        }
        
        // 查找写特征 "1001" 和通知特征 "1002"
        for characteristic in characteristics {
            if characteristic.uuid == writeCharUUID {
                writeCharacteristic = characteristic
                #if DEBUG
                print("找到写特征: \(characteristic.uuid)")
                #endif
            } else if characteristic.uuid == notifyCharUUID &&
                      characteristic.properties.contains(.notify) {
                notifyCharacteristic = characteristic
                #if DEBUG
                print("找到通知特征: \(characteristic.uuid)")
                #endif
                
                // 启用通知
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // 延迟 0.2 秒发送绑定指令
        if writeCharacteristic != nil {
            queue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.sendBindCommand()
            }
        }
        
        DiscoverContext.shared.handleDidDiscoverChars(peripheral, service: service, error: error)
    }

    internal func peripheral(_ peripheral: CBPeripheral,
                           didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        WriteContext.shared.handleDidWrite(char: characteristic, error: error)
    }

    internal func peripheral(_ peripheral: CBPeripheral,
                           didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        NotifyContext.shared.handleDidSetNotify(char: characteristic, error: error)
    }

    internal func peripheral(_ peripheral: CBPeripheral,
                           didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            valueHandlers[characteristic.uuid]?(.failure(error))
            valueHandlers[characteristic.uuid] = nil
            return
        }
        guard let data = characteristic.value else { return }
        
        // 先将 data 转为 string
        let dataString = (data as NSData).hexString()
        
        // 主动 read 的回调
        if let handler = valueHandlers[characteristic.uuid] {
            handler(.success(dataString))
            valueHandlers[characteristic.uuid] = nil
        }
        // 通知（notify）回调
        if let handler = notifyHandlers[characteristic.uuid] {
            handler(dataString)
        }
    }
}

// MARK: Small Context Helpers
private final class DiscoverContext {
    static let shared = DiscoverContext()
    private struct Expect {
        var wantServices: Set<CBUUID>
        var wantChars: Set<CBUUID>
        var foundChars: [CBCharacteristic] = []
        var onReady: ([CBCharacteristic]) -> Void
        var onError: (Error) -> Void
    }
    private var map: [UUID: Expect] = [:]

    func setExpectation(periph: CBPeripheral,
                        targetServiceUUIDs: Set<CBUUID>,
                        targetCharUUIDs: Set<CBUUID>,
                        onReady: @escaping ([CBCharacteristic]) -> Void,
                        onError: @escaping (Error) -> Void) {
        map[periph.identifier] = Expect(wantServices: targetServiceUUIDs,
                                        wantChars: targetCharUUIDs,
                                        foundChars: [],
                                        onReady: onReady, onError: onError)
    }

    func handleDidDiscoverServices(_ p: CBPeripheral, error: Error?) {
        guard var exp = map[p.identifier] else { return }
        if let error = error { exp.onError(error); map[p.identifier] = nil; return }

        let target = exp.wantServices
        for s in p.services ?? [] where target.isEmpty || target.contains(s.uuid) {
            p.discoverCharacteristics(Array(exp.wantChars), for: s)
        }
        map[p.identifier] = exp
    }

    func handleDidDiscoverChars(_ p: CBPeripheral, service: CBService, error: Error?) {
        guard var exp = map[p.identifier] else { return }
        if let error = error { exp.onError(error); map[p.identifier] = nil; return }

        let chars = service.characteristics ?? []
        for c in chars where exp.wantChars.isEmpty || exp.wantChars.contains(c.uuid) {
            exp.foundChars.append(c)
        }
        // 当已找到目标特征数量达到目标集合大小时回调
        if !exp.wantChars.isEmpty && Set(exp.foundChars.map { $0.uuid }).isSuperset(of: exp.wantChars) {
            exp.onReady(exp.foundChars)
            map[p.identifier] = nil
        } else if exp.wantChars.isEmpty {
            // 没指定特征则直接全部返回
            exp.onReady(chars)
            map[p.identifier] = nil
        } else {
            map[p.identifier] = exp
        }
    }
}

private final class WriteContext {
    static let shared = WriteContext()
    private var map: [CBUUID: (Error) -> Void] = [:]
    func remember(char: CBCharacteristic, onError: @escaping (Error) -> Void) { map[char.uuid] = onError }
    func handleDidWrite(char: CBCharacteristic, error: Error?) {
        if let error = error { map[char.uuid]?(error) }
        map[char.uuid] = nil
    }
}

private final class NotifyContext {
    static let shared = NotifyContext()
    private var map: [CBUUID: (Error) -> Void] = [:]
    func remember(char: CBCharacteristic, onError: @escaping (Error) -> Void) { map[char.uuid] = onError }
    func handleDidSetNotify(char: CBCharacteristic, error: Error?) {
        if let error = error { map[char.uuid]?(error) }
        map[char.uuid] = nil
    }
}
