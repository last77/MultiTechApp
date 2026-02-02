//
//  BleFilterProtocol.swift
//  BleToolsKit
//
//  过滤器协议 - 支持自定义设备过滤逻辑
//

import Foundation
import CoreBluetooth

/// 蓝牙设备过滤器协议
public protocol BleFilterProtocol {
    /// 判断设备是否符合过滤条件
    /// - Parameter peripheral: 外设对象
    /// - Returns: 是否通过过滤
    func shouldInclude(peripheral: CBPeripheral) -> Bool
    
    /// 过滤器名称（用于调试）
    var filterName: String { get }
}

/// 组合过滤器 - 支持多个过滤器逻辑组合
public class CompositeFilter: BleFilterProtocol {
    private let filters: [BleFilterProtocol]
    private let logicType: LogicType
    
    public enum LogicType {
        case and  // 所有过滤器都通过
        case or   // 任一过滤器通过
    }
    
    public init(filters: [BleFilterProtocol], logic: LogicType = .and) {
        self.filters = filters
        self.logicType = logic
    }
    
    public func shouldInclude(peripheral: CBPeripheral) -> Bool {
        switch logicType {
        case .and:
            return filters.allSatisfy { $0.shouldInclude(peripheral: peripheral) }
        case .or:
            return filters.contains { $0.shouldInclude(peripheral: peripheral) }
        }
    }
    
    public var filterName: String {
        let logic = logicType == .and ? "AND" : "OR"
        let names = filters.map { $0.filterName }.joined(separator: ", ")
        return "CompositeFilter(\(logic): [\(names)])"
    }
}

