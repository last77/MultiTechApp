//
//  新架构使用示例.swift
//  BleToolsKit
//
//  演示如何使用重构后的 SDK
//

import Foundation
import UIKit

// MARK: - 基础使用示例

class BasicUsageViewController: UIViewController {
    
    let ble = BleAPI.shared
    var deviceList: [BleDeviceInfo] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBleCallbacks()
    }
    
    func setupBleCallbacks() {
        // 1️⃣ 扫描回调 - 使用新的 BleDeviceInfo
        ble.onDeviceFound = { [weak self] deviceInfo in
            print("📱 发现设备:")
            print("   名称: \(deviceInfo.deviceName)")
            print("   类型: \(deviceInfo.deviceType.rawValue)")
            print("   信号: \(deviceInfo.rssi) dBm")
            print("   连接: \(deviceInfo.isConnected ? "已连接" : "未连接")")
            print("   新设备: \(deviceInfo.isNewDevice ? "是" : "否")")
            print("   MAC: \(deviceInfo.macAddress ?? "无")")
            
            self?.deviceList.append(deviceInfo)
            self?.tableView.reloadData()
        }
        
        // 2️⃣ 连接回调
        ble.onConnected = { [weak self] in
            print("✅ 设备连接成功")
            self?.showConnectedUI()
        }
        
        // 3️⃣ 数据回调
        ble.onDataReceived = { [weak self] hexString in
            print("📩 收到数据: \(hexString)")
            self?.processReceivedData(hexString)
        }
        
        // 4️⃣ 错误回调
        ble.onError = { [weak self] errorMsg in
            print("❌ 错误: \(errorMsg)")
            self?.showError(errorMsg)
        }
        
        // 5️⃣ 断开连接回调（新增）
        ble.onDisconnected = { [weak self] in
            print("🔌 设备已断开")
            self?.showDisconnectedUI()
        }
        
        // 6️⃣ 日志回调
        ble.onLog = { logMsg in
            print("📝 \(logMsg)")
        }
    }
    
    // MARK: - 扫描
    
    func startScan() {
        deviceList.removeAll()
        
        // 基础扫描（包含已连接设备）
        ble.scan(includeConnectedDevices: true)
        
        // 3秒后停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.ble.stopScan()
            self?.showScanResults()
        }
    }
    
    // MARK: - 连接
    
    func connectToDevice(_ deviceInfo: BleDeviceInfo) {
        ble.connect(deviceId: deviceInfo.deviceId)
    }
    
    // MARK: - UI 更新
    
    func showScanResults() {
        let devices = ble.getScannedDevices()
        print("扫描完成，共发现 \(devices.count) 个设备")
    }
    
    func showConnectedUI() {
        if let device = ble.getCurrentDevice() {
            print("当前连接: \(device.deviceName)")
        }
    }
    
    func showDisconnectedUI() {
        // 更新 UI
    }
    
    func showError(_ message: String) {
        // 显示错误提示
    }
    
    func processReceivedData(_ hexString: String) {
        // 处理接收的数据
    }
}

// MARK: - 高级使用：自定义过滤器

class AdvancedUsageViewController: UIViewController {
    
    let ble = BleAPI.shared
    
    // 示例1: 只扫描特定设备类型
    func scanSpirometersOnly() {
        let filter = BleDeviceTypeFilter(targetTypes: [.spirometer])
        ble.scan(includeConnectedDevices: true, customFilter: filter)
    }
    
    // 示例2: 组合多个过滤器
    func scanWithCompositeFilter() {
        let nameFilter = BleDeviceNameFilter.shared
        let typeFilter = BleDeviceTypeFilter(targetTypes: [.spirometer, .oximeter])
        
        let compositeFilter = CompositeFilter(
            filters: [nameFilter, typeFilter],
            logic: .and  // 必须同时满足
        )
        
        ble.scan(customFilter: compositeFilter)
    }
    
    // 示例3: 自定义过滤器
    func scanWithCustomFilter() {
        class MyFilter: BleFilterProtocol {
            var filterName: String { "MyCustomFilter" }
            
            func shouldInclude(peripheral: CBPeripheral) -> Bool {
                // 自定义逻辑：例如只显示名称包含 "Air" 的设备
                return peripheral.name?.contains("Air") ?? false
            }
        }
        
        let customFilter = MyFilter()
        ble.scan(customFilter: customFilter)
    }
}

// MARK: - 设备类型处理

class DeviceTypeHandlingViewController: UIViewController {
    
    let ble = BleAPI.shared
    
    func handleDeviceByType(_ deviceInfo: BleDeviceInfo) {
        switch deviceInfo.deviceType {
        case .spirometer:
            handleSpirometer(deviceInfo)
        case .oximeter:
            handleOximeter(deviceInfo)
        case .thermometer:
            handleThermometer(deviceInfo)
        case .unknown:
            handleUnknownDevice(deviceInfo)
        }
    }
    
    func handleSpirometer(_ device: BleDeviceInfo) {
        print("这是肺活量计设备")
        // 连接后可以使用 fvc(), vc(), mvv() 等方法
    }
    
    func handleOximeter(_ device: BleDeviceInfo) {
        print("这是血氧仪设备")
        // TODO: 实现血氧仪特定逻辑
    }
    
    func handleThermometer(_ device: BleDeviceInfo) {
        print("这是体温计设备")
        // TODO: 实现体温计特定逻辑
    }
    
    func handleUnknownDevice(_ device: BleDeviceInfo) {
        print("未知设备类型")
    }
}

// MARK: - TableView 集成

class DeviceListViewController: UITableViewController {
    
    let ble = BleAPI.shared
    var devices: [BleDeviceInfo] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ble.onDeviceFound = { [weak self] deviceInfo in
            self?.devices.append(deviceInfo)
            self?.tableView.reloadData()
        }
        
        ble.scan()
    }
    
    // MARK: - TableView DataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        let device = devices[indexPath.row]
        
        // 主标题：设备名称
        cell.textLabel?.text = device.deviceName
        
        // 副标题：详细信息
        cell.detailTextLabel?.text = """
        \(device.deviceType.rawValue) | \
        信号: \(device.rssi) | \
        \(device.isConnected ? "✅ 已连接" : "⭕️ 未连接")
        """
        
        // 根据状态设置图标
        if device.isConnected {
            cell.imageView?.image = UIImage(systemName: "checkmark.circle.fill")
            cell.imageView?.tintColor = .systemGreen
        } else if device.isNewDevice {
            cell.imageView?.image = UIImage(systemName: "star.circle.fill")
            cell.imageView?.tintColor = .systemBlue
        } else {
            cell.imageView?.image = UIImage(systemName: "circle")
            cell.imageView?.tintColor = .systemGray
        }
        
        return cell
    }
    
    // MARK: - TableView Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = devices[indexPath.row]
        
        // 显示连接确认
        let alert = UIAlertController(
            title: "连接设备",
            message: "确定要连接 \(device.deviceName) 吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "连接", style: .default) { [weak self] _ in
            self?.connectToDevice(device)
        })
        
        present(alert, animated: true)
    }
    
    func connectToDevice(_ device: BleDeviceInfo) {
        ble.stopScan()
        ble.connect(deviceId: device.deviceId)
    }
}

// MARK: - 设备详情页面

class DeviceDetailViewController: UIViewController {
    
    let ble = BleAPI.shared
    var deviceInfo: BleDeviceInfo?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let device = deviceInfo else { return }
        
        // 显示设备详情
        showDeviceInfo(device)
        
        // 根据设备类型显示不同的控制按钮
        setupControlButtons(for: device.deviceType)
    }
    
    func showDeviceInfo(_ device: BleDeviceInfo) {
        title = device.deviceName
        
        print("""
        设备信息:
        - ID: \(device.deviceId)
        - 名称: \(device.deviceName)
        - 类型: \(device.deviceType.rawValue)
        - MAC: \(device.macAddress ?? "无")
        - 信号: \(device.rssi) dBm
        - 状态: \(device.isConnected ? "已连接" : "未连接")
        - 类型: \(device.isNewDevice ? "新设备" : "老设备")
        """)
    }
    
    func setupControlButtons(for deviceType: BleDeviceType) {
        switch deviceType {
        case .spirometer:
            setupSpirometerButtons()
        case .oximeter:
            setupOximeterButtons()
        case .thermometer:
            setupThermometerButtons()
        case .unknown:
            break
        }
    }
    
    func setupSpirometerButtons() {
        // FVC 测试按钮
        let fvcButton = UIButton()
        fvcButton.setTitle("FVC 测试", for: .normal)
        fvcButton.addTarget(self, action: #selector(startFVC), for: .touchUpInside)
        
        // VC 测试按钮
        let vcButton = UIButton()
        vcButton.setTitle("VC 测试", for: .normal)
        vcButton.addTarget(self, action: #selector(startVC), for: .touchUpInside)
        
        // MVV 测试按钮
        let mvvButton = UIButton()
        mvvButton.setTitle("MVV 测试", for: .normal)
        mvvButton.addTarget(self, action: #selector(startMVV), for: .touchUpInside)
        
        // 添加到视图...
    }
    
    func setupOximeterButtons() {
        // TODO: 血氧仪按钮
    }
    
    func setupThermometerButtons() {
        // TODO: 体温计按钮
    }
    
    @objc func startFVC() {
        ble.fvc()
    }
    
    @objc func startVC() {
        ble.vc()
    }
    
    @objc func startMVV() {
        ble.mvv()
    }
}

// MARK: - SwiftUI 集成示例

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, *)
struct DeviceListView: View {
    @StateObject private var viewModel = DeviceListViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.devices) { device in
                NavigationLink(destination: DeviceDetailView(device: device)) {
                    DeviceRowView(device: device)
                }
            }
            .navigationTitle("蓝牙设备")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("扫描") {
                        viewModel.startScan()
                    }
                }
            }
        }
        .onAppear {
            viewModel.startScan()
        }
    }
}

@available(iOS 13.0, *)
struct DeviceRowView: View {
    let device: BleDeviceInfo
    
    var body: some View {
        HStack {
            // 图标
            Image(systemName: device.isConnected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(device.isConnected ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(device.deviceName)
                    .font(.headline)
                
                Text("\(device.deviceType.rawValue) | 信号: \(device.rssi)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if device.isConnected {
                Text("已连接")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
}

@available(iOS 13.0, *)
class DeviceListViewModel: ObservableObject {
    @Published var devices: [BleDeviceInfo] = []
    
    let ble = BleAPI.shared
    
    init() {
        setupCallbacks()
    }
    
    func setupCallbacks() {
        ble.onDeviceFound = { [weak self] deviceInfo in
            DispatchQueue.main.async {
                self?.devices.append(deviceInfo)
            }
        }
    }
    
    func startScan() {
        devices.removeAll()
        ble.scan(includeConnectedDevices: true)
    }
}
#endif

// MARK: - 使用说明

/*
 
 ✨ 新架构的主要改进：
 
 1. **结构化的设备信息**
    - 使用 BleDeviceInfo 替代元组 (String, String, Int)
    - 包含更多信息：设备类型、连接状态、新老设备标识等
 
 2. **更丰富的 API**
    - getCurrentDevice() - 获取当前连接的设备
    - getScannedDevices() - 获取所有已扫描设备
    - onDisconnected - 断开连接回调
 
 3. **自定义过滤器支持**
    - 实现 BleFilterProtocol 创建自定义过滤器
    - 使用 CompositeFilter 组合多个过滤器
 
 4. **设备类型识别**
    - 自动识别设备类型（肺活量计、血氧仪、体温计等）
    - 便于实现设备特定的 UI 和逻辑
 
 5. **更好的扩展性**
    - 协议层设计支持未来新设备类型
    - 命令层封装设备特定命令
    - 设备管理器统一管理多设备逻辑
 
 */

