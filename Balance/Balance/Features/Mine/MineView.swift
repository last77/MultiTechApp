//
//  MineView.swift
//  Balance
//
//  我的模块：展示记录操作动态
//

import SwiftUI
import CoreData

struct MineView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LedgerActivity.timestamp, ascending: false)],
        animation: .default
    )
    private var activities: FetchedResults<LedgerActivity>

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("动态概览")) {
                    activityOverview
                }

                if activitySections.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("暂无动态", systemImage: "bell.slash")
                        } description: {
                            Text("新增、删除或修改记录后，这里会显示完整的操作历史。")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                } else {
                    ForEach(activitySections) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.activities, id: \.objectID) { activity in
                                ActivityRow(activity: activity)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var activityOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近 30 天概览")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(activityStats) { stat in
                    ActivityStatCard(stat: stat)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var activityStats: [ActivityStat] {
        [
            ActivityStat(title: "新增", count: count(for: .add), icon: "plus.circle.fill", color: .green),
            ActivityStat(title: "删除", count: count(for: .delete), icon: "trash.circle.fill", color: .red),
            ActivityStat(title: "修改", count: count(for: .updatePurpose), icon: "pencil.circle.fill", color: .blue)
        ]
    }

    private func count(for action: LedgerActivityAction) -> Int {
        activities.filter { $0.action == action.rawValue }.count
    }

    private var activitySections: [ActivitySection] {
        let grouped = Dictionary(grouping: activities) { activity in
            Calendar.current.startOfDay(for: activity.timestamp ?? Date())
        }
        return grouped
            .map { date, items in
                ActivitySection(
                    date: date,
                    title: sectionTitle(for: date),
                    activities: items.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMMdEEE")
        return formatter.string(from: date)
    }
}

private struct ActivitySection: Identifiable {
    let date: Date
    let title: String
    let activities: [LedgerActivity]

    var id: Date { date }
}

private struct ActivityStat: Identifiable {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var id: String { title }
}

private struct ActivityStatCard: View {
    let stat: ActivityStat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(stat.title, systemImage: stat.icon)
                .font(.caption)
                .foregroundStyle(stat.color)
            Text("\(stat.count)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("累计次数")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(stat.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ActivityRow: View {
    let activity: LedgerActivity

    private var action: LedgerActivityAction? {
        LedgerActivityAction(rawValue: activity.action ?? "")
    }

    private var iconName: String {
        switch action {
        case .add: return "plus"
        case .delete: return "trash"
        case .updatePurpose: return "pencil"
        case .none: return "clock"
        }
    }

    private var tintColor: Color {
        switch action {
        case .add: return .green
        case .delete: return .red
        case .updatePurpose: return .blue
        case .none: return .gray
        }
    }

    private var titleText: String {
        action?.rawValue ?? "操作"
    }

    private var detailText: String {
        activity.detail?.isEmpty == false ? (activity.detail ?? "") : "暂无详情"
    }

    private var timeText: String {
        let date = activity.timestamp ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "\(iconName).circle.fill")
                    .font(.title3)
                    .foregroundStyle(tintColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.subheadline.weight(.semibold))
                Text(detailText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(timeText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    MineView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
