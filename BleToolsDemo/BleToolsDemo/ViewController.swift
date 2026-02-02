//
//  ViewController.swift
//  BleToolsDemo
//
//  Created by app on 2025/10/20.
// Extra 121A

import UIKit
import BleToolsKit
import SnapKit

final class ViewController: UIViewController {

    // MARK: - Properties
    private var discoveredDevices: [BleDevice] = []
    private var deviceListView: DeviceListView?
    
    // MARK: - UI
    private let scanBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("扫描设备", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        return b
    }()
    private let disconnectBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("断开", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        return b
    }()
    private let logView: UITextView = {
        let t = UITextView()
        t.isEditable = false
        t.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        return t
    }()
    private let fvcBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("测试 FVC", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        return b
    }()
    private let vcBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("测试 VC", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        return b
    }()
    private let mvvBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("测试 MVV", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        return b
    }()
    private let stopFvcBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("停止 FVC", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        return b
    }()
    private let stopVcBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("停止 VC", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        return b
    }()
    private let stopMvvBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("停止 MVV", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        layoutUI()
        scanBtn.addTarget(self, action: #selector(onScan), for: .touchUpInside)
        disconnectBtn.addTarget(self, action: #selector(onDisconnect), for: .touchUpInside)
        fvcBtn.addTarget(self, action: #selector(onTestFVC), for: .touchUpInside)
        vcBtn.addTarget(self, action: #selector(onTestVC), for: .touchUpInside)
        mvvBtn.addTarget(self, action: #selector(onTestMVV), for: .touchUpInside)
        stopFvcBtn.addTarget(self, action: #selector(onStopFVC), for: .touchUpInside)
        stopVcBtn.addTarget(self, action: #selector(onStopVC), for: .touchUpInside)
        stopMvvBtn.addTarget(self, action: #selector(onStopMVV), for: .touchUpInside)
        append("App Ready.")
        // BLE SDK 回调配置
        BleAPI.shared.timeout = 10
        BleAPI.shared.onDeviceFound = { [weak self] deviceInfo in
            if deviceInfo.rssi == 0 {
                self?.append("📱 发现设备: \(deviceInfo.deviceName) [系统已连接]")
            } else {
                self?.append("📱 发现设备: \(deviceInfo.deviceName)  RSSI:\(deviceInfo.rssi)")
            }
            self?.addOrUpdateDevice(deviceId: deviceInfo.deviceId, deviceName: deviceInfo.deviceName, rssi: deviceInfo.rssi)
        }
        BleAPI.shared.onConnected = { [weak self] in
            self?.append("✅ 设备已连接")
        }
        BleAPI.shared.onDataReceived = { [weak self] hex in
            self?.append("📨 收到数据: \(hex)")
        }
        BleAPI.shared.onError = { [weak self] msg in
            self?.append("❌ 错误: \(msg)")
        }
        BleAPI.shared.onLog = {[weak self] log in
            self?.append("📱 [SDK] \(log)")
        }
    }

    private func layoutUI() {
        view.addSubview(scanBtn)
        view.addSubview(disconnectBtn)
        view.addSubview(logView)
        view.addSubview(fvcBtn)
        view.addSubview(vcBtn)
        view.addSubview(mvvBtn)
        view.addSubview(stopFvcBtn)
        view.addSubview(stopVcBtn)
        view.addSubview(stopMvvBtn)

        scanBtn.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().inset(16)
            make.height.equalTo(48)
        }

        disconnectBtn.snp.makeConstraints { make in
            make.top.equalTo(scanBtn.snp.bottom).offset(12)
            make.left.right.height.equalTo(scanBtn)
        }

        // 底部两行按钮：第一行测试，第二行停止
        stopFvcBtn.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(12)
            make.height.equalTo(40)
        }
        stopMvvBtn.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(12)
            make.centerY.equalTo(stopFvcBtn)
            make.width.equalTo(stopFvcBtn)
            make.height.equalTo(stopFvcBtn)
        }
        stopVcBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(stopFvcBtn)
            make.width.equalTo(stopFvcBtn)
            make.height.equalTo(stopFvcBtn)
        }

        fvcBtn.snp.makeConstraints { make in
            make.left.width.height.equalTo(stopFvcBtn)
            make.bottom.equalTo(stopFvcBtn.snp.top).offset(-8)
        }
        mvvBtn.snp.makeConstraints { make in
            make.right.width.height.equalTo(stopMvvBtn)
            make.centerY.equalTo(fvcBtn)
        }
        vcBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.height.equalTo(stopVcBtn)
            make.centerY.equalTo(fvcBtn)
        }

        logView.snp.makeConstraints { make in
            make.top.equalTo(disconnectBtn.snp.bottom).offset(16)
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().inset(12)
            make.bottom.equalTo(fvcBtn.snp.top).offset(-16)
        }
    }

    // MARK: - Actions

    @objc private func onScan() {
        append("🔍 开始扫描设备…")
        discoveredDevices.removeAll()
        showDeviceListView()
        BleAPI.shared.scan()
    }

    @objc private func onDisconnect() {
        BleAPI.shared.disconnect()
        append("🔚 已断开连接")
    }

    // MARK: - FVC / VC / MVV Actions
    @objc private func onTestFVC() {
        append("🚀 开始 FVC 测试")
        // TODO: 这里可以调用 BleAPI.shared.send(...) 下发真实指令
        BleAPI.shared.fvc()
    }

    @objc private func onTestVC() {
        append("🚀 开始 VC 测试")
        BleAPI.shared.vc()
    }

    @objc private func onTestMVV() {
        append("🚀 开始 MVV 测试")
        BleAPI.shared.mvv()
    }

    @objc private func onStopFVC() {
        append("⏹ 停止 FVC 测试")
        BleAPI.shared.stopFvc()
    }

    @objc private func onStopVC() {
        append("⏹ 停止 VC 测试")
        BleAPI.shared.stopVc()
    }

    @objc private func onStopMVV() {
        append("⏹ 停止 MVV 测试")
        BleAPI.shared.stopMvv()
    }

    // MARK: - Device Management
    
    private func addOrUpdateDevice(deviceId: String, deviceName: String, rssi: Int) {
        let device = BleDevice(deviceId: deviceId, deviceName: deviceName, rssi: rssi)
        
        if let index = discoveredDevices.firstIndex(where: { $0.deviceId == deviceId }) {
            // 更新已存在的设备
            discoveredDevices[index] = device
        } else {
            // 添加新设备
            discoveredDevices.append(device)
        }
        
        // 排序规则：
        // 1. 已连接设备（RSSI=0）排在最前面
        // 2. 其他设备按信号强度排序（RSSI 从高到低）
        discoveredDevices.sort { device1, device2 in
            // 如果设备1是已连接设备，排在前面
            if device1.isSystemConnected && !device2.isSystemConnected {
                return true
            }
            // 如果设备2是已连接设备，排在前面
            if !device1.isSystemConnected && device2.isSystemConnected {
                return false
            }
            // 如果都是已连接设备或都不是，按RSSI排序
            return device1.rssi > device2.rssi
        }
        
        // 更新设备列表视图
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.deviceListView?.updateDevices(self.discoveredDevices)
        }
    }
    
    private func showDeviceListView() {
        let listView = DeviceListView()
        listView.onDeviceSelected = { [weak self] device in
            self?.connectToDevice(device)
        }
        listView.onClose = { [weak self] in
            BleAPI.shared.stopScan()
            self?.append("⏸ 停止扫描")
            self?.deviceListView = nil
        }
        listView.show(in: self.view)
        self.deviceListView = listView
    }
    
    private func connectToDevice(_ device: BleDevice) {
        BleAPI.shared.stopScan()
        append("🔗 正在连接: \(device.displayName)")
        append("📍 设备ID: \(device.deviceId)")
        BleAPI.shared.connect(deviceId: device.deviceId)
    }
    
    // MARK: - log
    private func append(_ s: String) {
        DispatchQueue.main.async {
            let time = Self.ts()
            self.logView.text.append("[\(time)] \(s)\n")
            let range = NSMakeRange(self.logView.text.count - 1, 1)
            self.logView.scrollRangeToVisible(range)
        }
    }
    private static func ts() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}
