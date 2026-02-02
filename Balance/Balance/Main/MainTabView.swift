//
//  MainTabView.swift
//  Balance
//
//  主框架：底部 TabBar 容器
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabItem = .home

    enum TabItem: Int, CaseIterable {
        case home
        case mine

        var title: String {
            switch self {
            case .home: return "首页"
            case .mine: return "我的"
            }
        }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .mine: return "person.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(TabItem.home.title, systemImage: TabItem.home.icon)
                }
                .tag(TabItem.home)

            MineView()
                .tabItem {
                    Label(TabItem.mine.title, systemImage: TabItem.mine.icon)
                }
                .tag(TabItem.mine)
        }
    }
}

#Preview {
    MainTabView()
}
