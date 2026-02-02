# BleToolsKit SDK 重构说明

## 📋 重构概述

本次重构将 SDK 进行了模块化分层设计，提升了代码的可维护性和扩展性，为未来接入其他设备类型奠定了基础。

## 🏗️ 新的文件夹结构

```
BleToolsKit/
├── Core/                          # 核心层
│   ├── BleAPI.swift              # 对外 API 接口
│   ├── BleCentral.swift          # 蓝牙中心管理器
│   └── BleConstants.swift        # 常量定义
│
├── Models/                        # 数据模型层
│   ├── BleDevice.swift           # 设备模型
│   ├── BleFilter.swift           # 过滤器配置
│   └── BleError.swift            # 错误定义
│
├── Protocols/                     # 协议层（扩展接口）
│   ├── BleDeviceProtocol.swift   # 设备协议
│   ├── BleFilterProtocol.swift   # 过滤器协议
│   └── BleCommandProtocol.swift  # 命令协议
│
├── Filters/                       # 过滤器层
│   └── BleDeviceNameFilter.swift # 设备名称过滤器
│                                  # （可扩展：RSSI过滤器、设备类型过滤器等）
│
├── Devices/                       # 设备管理层
│   └── BleDeviceManager.swift    # 设备管理器（处理多设备类型）
│
├── Commands/                      # 命令层
│   └── SpiromerterCommands.swift # 肺活量计命令
│                                  # （可扩展：血氧仪命令、体温计命令等）
│
├── Storage/                       # 存储层
│   └── BleStorage.swift          # 本地存储管理
│
└── Utils/                         # 工具层
    ├── Crypto/                    # 加密工具
    │   └── AESCBCUtil.swift      # AES-CBC 加密
    ├── Converters/                # 数据转换工具
    │   ├── BleDataConverter.swift
    │   ├── DataConverter.swift
    │   └── Base64Converter.swift
    └── Extensions/                # 扩展（预留）
        └── Data+Hex.swift
```

## 🎯 设计原则

### 1. 分层架构

- **Core 层**：核心功能，不依赖具体设备
- **Models 层**：数据模型，定义数据结构
- **Protocols 层**：协议接口，定义扩展规范
- **Devices 层**：设备逻辑，处理设备特定行为
- **Commands 层**：命令定义，封装设备命令
- **Utils 层**：工具类，提供通用功能

### 2. 面向协议编程

通过定义协议接口，支持多种设备类型和过滤器的扩展：

```swift
// 设备协议
public protocol BleDeviceProtocol {
    var deviceType: BleDeviceType { get }
    var identifier: String { get }
    // ...
}

// 过滤器协议
public protocol BleFilterProtocol {
    func shouldInclude(peripheral: CBPeripheral) -> Bool
}

// 命令协议
public protocol BleCommandProtocol {
    var commandName: String { get }
    func buildCommand(isNewDevice: Bool, poolIndex: Int) -> String
}
```

### 3. 单一职责原则

每个类/文件只负责一个特定功能：

- `BleAPI`：对外接口
- `BleCentral`：蓝牙通信
- `BleDeviceManager`：设备管理
- `SpirometerCommands`：肺活量计命令

### 4. 开闭原则

对扩展开放，对修改关闭：

- 新增设备类型：创建新的 `Commands` 文件
- 新增过滤器：实现 `BleFilterProtocol`
- 新增功能：扩展现有类，不修改核心代码

## 🔧 核心改进

### 1. 设备信息增强

新增 `BleDeviceInfo` 结构体，包含更多设备信息：

```swift
public struct BleDeviceInfo {
    public let deviceId: String       // 设备ID
    public let deviceName: String     // 设备名称
    public let rssi: Int             // 信号强度
    public let macAddress: String?    // MAC地址
    public let isNewDevice: Bool      // 是否新设备
    public let deviceType: BleDeviceType  // 设备类型
    public let isConnected: Bool      // 是否已连接
}
```

### 2. 设备类型识别

自动识别设备类型：

```swift
public enum BleDeviceType: String {
    case spirometer = "Spirometer"    // 肺活量计
    case oximeter = "Oximeter"        // 血氧仪
    case thermometer = "Thermometer"  // 体温计
    case unknown = "Unknown"
    
    static func infer(from name: String) -> BleDeviceType
}
```

### 3. 自定义过滤器支持

```swift
// 使用自定义过滤器
let rssiFilter = BleRSSIFilter(minimumRSSI: -70)
ble.scan(customFilter: rssiFilter)

// 组合多个过滤器
let nameFilter = BleDeviceNameFilter.shared
let typeFilter = BleDeviceTypeFilter(targetTypes: [.spirometer])
let compositeFilter = CompositeFilter(filters: [nameFilter, typeFilter], logic: .and)
ble.scan(customFilter: compositeFilter)
```

### 4. 设备管理器

统一管理不同设备类型的逻辑：

```swift
class BleDeviceManager {
    // 构建设备特定命令
    func buildCommand(for device: BleDevice, command: Any, poolIndex: Int) -> String?
    
    // 解析设备数据
    func parseData(for device: BleDevice, hexString: String) -> Any?
    
    // 获取设备配置
    func getServiceUUIDs(for deviceType: BleDeviceType) -> [CBUUID]
    func getCharacteristicUUIDs(for deviceType: BleDeviceType) -> [CBUUID]
}
```

## 📖 使用方式对比

### 旧版本（简化）

```swift
let ble = BleAPI.shared

ble.onDeviceFound = { deviceId, deviceName, rssi in
    print("发现设备: \(deviceName)")
}

ble.scan()
```

### 新版本（增强）

```swift
let ble = BleAPI.shared

ble.onDeviceFound = { deviceInfo in
    print("发现设备: \(deviceInfo.deviceName)")
    print("设备类型: \(deviceInfo.deviceType.rawValue)")
    print("是否已连接: \(deviceInfo.isConnected)")
    print("是否新设备: \(deviceInfo.isNewDevice)")
}

// 支持自定义过滤器
ble.scan(includeConnectedDevices: true, customFilter: nil)

// 获取当前设备信息
if let currentDevice = ble.getCurrentDevice() {
    print("当前连接: \(currentDevice.deviceName)")
}

// 获取所有已扫描设备
let devices = ble.getScannedDevices()
```

## 🚀 扩展示例

### 1. 添加新设备类型（血氧仪）

#### Step 1: 在 `BleDeviceType` 中添加类型

```swift
public enum BleDeviceType: String {
    case spirometer = "Spirometer"
    case oximeter = "Oximeter"  // ✨ 新增
    // ...
}
```

#### Step 2: 创建命令文件

```swift
// Commands/OximeterCommands.swift
public enum OximeterCommand: String {
    case startMeasure = "开始测量"
    case stopMeasure = "停止测量"
    
    var rawCommand: String {
        switch self {
        case .startMeasure: return "AA01BB"
        case .stopMeasure: return "AA00BB"
        }
    }
}

internal class OximeterCommandBuilder {
    static func buildCommand(_ command: OximeterCommand) -> String {
        // 实现命令构建逻辑
    }
}
```

#### Step 3: 在 `BleDeviceManager` 中添加处理

```swift
func buildCommand(for device: BleDevice, command: Any, poolIndex: Int) -> String? {
    switch device.deviceType {
    case .spirometer:
        // 肺活量计逻辑
    case .oximeter:  // ✨ 新增
        if let oximeterCmd = command as? OximeterCommand {
            return OximeterCommandBuilder.buildCommand(oximeterCmd)
        }
    // ...
    }
}
```

#### Step 4: 在 `BleAPI` 中添加接口

```swift
// 血氧仪测量方法
public func startOximeterMeasure() {
    guard let device = currentDevice, device.deviceType == .oximeter else {
        onError?("当前设备不是血氧仪")
        return
    }
    // 发送命令
}
```

### 2. 添加自定义过滤器

```swift
// Filters/CustomFilter.swift
class MyCustomFilter: BleFilterProtocol {
    var filterName: String { return "MyCustomFilter" }
    
    func shouldInclude(peripheral: CBPeripheral) -> Bool {
        // 实现自定义过滤逻辑
        return peripheral.name?.hasPrefix("My") ?? false
    }
}

// 使用
let customFilter = MyCustomFilter()
ble.scan(customFilter: customFilter)
```

## 📊 迁移指南

### 旧代码

```swift
ble.onDeviceFound = { deviceId, deviceName, rssi in
    if rssi == 0 {
        print("已连接设备")
    }
}
```

### 新代码

```swift
ble.onDeviceFound = { deviceInfo in
    // 使用结构化的设备信息
    if deviceInfo.isConnected {
        print("已连接设备")
    }
    
    // 访问更多信息
    print("设备类型: \(deviceInfo.deviceType)")
    print("MAC地址: \(deviceInfo.macAddress ?? "无")")
}
```

## ⚠️ 注意事项

### 1. 向后兼容

- 旧的 API 接口仍然保留在根目录下（`BleAPI.swift`）
- 新代码在 `Core/BleAPI.swift` 中
- 建议逐步迁移到新架构

### 2. 文件迁移

原始文件已复制到新位置：

- `AESCBCutil.swift` → `Utils/Crypto/AESCBCUtil.swift`
- `BleDataConverter.swift` → `Utils/Converters/BleDataConverter.swift`
- `BleStorage.swift` → `Storage/BleStorage.swift`
- 等等...

### 3. 命名规范

- **协议**：以 `Protocol` 结尾（如 `BleDeviceProtocol`）
- **命令**：以 `Commands` 结尾（如 `SpirometerCommands`）
- **管理器**：以 `Manager` 结尾（如 `BleDeviceManager`）
- **工具类**：以 `Util` 或 `Converter` 结尾

## 🎯 未来规划

### 短期目标

1. ✅ 完成文件夹结构重构
2. ✅ 实现协议层
3. ✅ 创建设备管理器
4. ⏳ 更新 Xcode 项目文件引用
5. ⏳ 单元测试覆盖

### 中期目标

1. 支持更多设备类型（血氧仪、体温计）
2. 完善数据解析模块
3. 添加设备状态机
4. 优化连接重连逻辑

### 长期目标

1. 支持设备固件升级
2. 设备数据本地缓存
3. 云端数据同步
4. 多设备并发管理

## 📚 相关文档

- [已连接设备扫描功能说明.md](./已连接设备扫描功能说明.md)
- [SDK使用示例_带日志.swift](./SDK使用示例_带日志.swift)
- [多设备使用示例.swift](./多设备使用示例.swift)

## 🤝 贡献指南

添加新功能时，请遵循以下步骤：

1. **确定功能分类**：属于哪一层（协议、设备、命令等）
2. **创建对应文件**：按照命名规范创建文件
3. **实现协议接口**：如果涉及扩展，实现对应协议
4. **更新设备管理器**：在 `BleDeviceManager` 中添加处理逻辑
5. **暴露公开接口**：在 `BleAPI` 中添加对外方法
6. **编写文档和示例**：更新相关文档

---

**重构完成日期**: 2025年12月11日  
**版本**: v2.0  
**作者**: BleToolsKit Team

