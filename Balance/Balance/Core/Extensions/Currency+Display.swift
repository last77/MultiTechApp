//
//  Currency+Display.swift
//  Balance
//
//  货币展示扩展，后续可扩展美元等
//

import Foundation

enum AppCurrency: String, CaseIterable {
    case CNY = "CNY"
    case USD = "USD"

    var displayName: String {
        switch self {
        case .CNY: return "人民币"
        case .USD: return "美元"
        }
    }

    var symbol: String {
        switch self {
        case .CNY: return "¥"
        case .USD: return "$"
        }
    }
}
