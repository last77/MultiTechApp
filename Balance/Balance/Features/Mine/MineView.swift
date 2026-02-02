//
//  MineView.swift
//  Balance
//
//  我的模块
//

import SwiftUI

struct MineView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("我的")
                    .font(.title)
                Text("设置与个人中心将显示在这里")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MineView()
}
