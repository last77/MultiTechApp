//
//  HomeView.swift
//  Balance
//
//  首页模块：日期、支出/收入、用途、记录列表、盈亏汇总
//

import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LedgerEntry.date, ascending: false)],
        animation: .default
    )
    private var entries: FetchedResults<LedgerEntry>

    @State private var selectedDate = Date()
    @State private var expenseText = ""
    @State private var incomeText = ""
    @State private var purposeText = ""
    @State private var entryBeingEdited: LedgerEntry?
    @State private var editedPurposeText = ""
    @State private var isEditingPurpose = false
    @State private var selectedFilter: EntryFilter = .all
    @FocusState private var focusedField: Field?
    @AppStorage("selectedCurrency") private var selectedCurrencyRaw: String = AppCurrency.CNY.rawValue

    enum Field {
        case expense, income, purpose
    }

    enum EntryFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case expense = "支出"
        case income = "收入"

        var id: String { rawValue }
    }

    private var currency: AppCurrency {
        AppCurrency(rawValue: selectedCurrencyRaw) ?? .CNY
    }

    private var totalIncome: Double {
        entries.reduce(0) { sum, entry in sum + entry.income }
    }

    private var totalExpense: Double {
        entries.reduce(0) { sum, entry in sum + entry.expense }
    }

    private var balance: Double {
        totalIncome - totalExpense
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 20) {
                        summaryOverviewCard
                        addEntryCard
                        entriesListSection
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .background(Color(.systemGroupedBackground))

                balanceBar
            }
            .navigationTitle("记账")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
        }
        .sheet(isPresented: $isEditingPurpose, onDismiss: resetPurposeEditingState) {
            editPurposeSheet
        }
    }

    private var summaryOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("本月总览")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(currentMonthLabel)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("结余")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(formatBalanceWithSign(currentMonthBalance))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 12) {
                SummaryChip(title: "收入", value: formatMoney(currentMonthIncome), icon: "arrow.down.right.circle.fill", tint: .green)
                SummaryChip(title: "支出", value: formatMoney(currentMonthExpense), icon: "arrow.up.right.circle.fill", tint: .red)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor,
                    Color.accentColor.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.accentColor.opacity(0.25), radius: 18, x: 0, y: 8)
    }

    // MARK: - 添加记录卡片
    private var addEntryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("记一笔")
                .font(.headline)
                .foregroundStyle(.primary)

            DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("支出")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $expenseText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .expense)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .contentShape(Rectangle())
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)
                Text(currency.symbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .expense }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("收入")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $incomeText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .income)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .contentShape(Rectangle())
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)
                Text(currency.symbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .income }

            VStack(alignment: .leading, spacing: 6) {
                Text("用途")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("如：餐饮、交通", text: $purposeText)
                    .focused($focusedField, equals: .purpose)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .contentShape(Rectangle())
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .purpose }

            Button {
                selectedCurrencyRaw = currency == .CNY ? AppCurrency.USD.rawValue : AppCurrency.CNY.rawValue
            } label: {
                HStack {
                    Text("货币")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currency.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button(action: addEntry) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加记录")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - 记录列表
    private var entriesListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("最近记录")
                        .font(.headline)
                    Spacer()
                    if !entries.isEmpty {
                        Text("共 \(entries.count) 条")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("记录筛选", selection: $selectedFilter) {
                    ForEach(EntryFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            if entries.isEmpty {
                ContentUnavailableView {
                    Label("暂无记录", systemImage: "tray")
                } description: {
                    Text("点击上方「添加记录」开始记账")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if filteredEntries.isEmpty {
                ContentUnavailableView {
                    Label("暂无符合条件的记录", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("试试切换筛选条件或新增一条记录。")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredEntries, id: \.objectID) { entry in
                        EntryRow(
                            entry: entry,
                            currency: currency,
                            onDelete: { deleteEntry(entry) },
                            onLongPress: { beginEditingPurpose(for: entry) }
                        )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteEntry(entry)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - 底部盈亏栏
    private var balanceBar: some View {
        VStack(spacing: 4) {
            Text("盈亏")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(formatBalanceWithSign(balance))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(balance >= 0 ? Color.green : Color.red)
            if balance < 0 {
                Text("支出大于收入")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions
    private func addEntry() {
        let expense = Double(expenseText.replacingOccurrences(of: ",", with: "")) ?? 0
        let income = Double(incomeText.replacingOccurrences(of: ",", with: "")) ?? 0
        if expense <= 0 && income <= 0 { return }

        let entry = LedgerEntry(context: viewContext)
        entry.date = selectedDate
        entry.expense = expense
        entry.income = income
        entry.currency = selectedCurrencyRaw
        entry.purpose = purposeText.isEmpty ? nil : purposeText
        entry.createdAt = Date()

        let detail = entrySummary(for: entry)
        logActivity(.add, detail: detail)
        expenseText = ""
        incomeText = ""
        purposeText = ""
        focusedField = nil

        saveContext()
    }

    private func deleteEntry(_ entry: LedgerEntry) {
        let detail = entrySummary(for: entry)
        viewContext.delete(entry)
        logActivity(.delete, detail: detail)
        saveContext()
    }

    private func beginEditingPurpose(for entry: LedgerEntry) {
        entryBeingEdited = entry
        editedPurposeText = entry.purpose ?? ""
        isEditingPurpose = true
    }

    private func saveEditedPurpose() {
        guard let entry = entryBeingEdited else { return }
        let trimmed = editedPurposeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldPurpose = displayPurpose(for: entry)
        entry.purpose = trimmed.isEmpty ? nil : trimmed
        let newPurpose = displayPurpose(for: entry)
        logActivity(.updatePurpose, detail: "\(oldPurpose) → \(newPurpose)")
        saveContext()
        dismissPurposeEditor()
    }

    private func dismissPurposeEditor() {
        isEditingPurpose = false
    }

    private func resetPurposeEditingState() {
        entryBeingEdited = nil
        editedPurposeText = ""
        isEditingPurpose = false
    }

    private func logActivity(_ action: LedgerActivityAction, detail: String) {
        let activity = LedgerActivity(context: viewContext)
        activity.id = UUID()
        activity.timestamp = Date()
        activity.action = action.rawValue
        activity.detail = detail
    }

    private func entrySummary(for entry: LedgerEntry) -> String {
        let purpose = displayPurpose(for: entry)
        let entryCurrency = AppCurrency(rawValue: entry.currency ?? AppCurrency.CNY.rawValue) ?? .CNY
        var parts: [String] = []
        if entry.income > 0 {
            parts.append("+\(formattedValue(entry.income, currency: entryCurrency))")
        }
        if entry.expense > 0 {
            parts.append("-\(formattedValue(entry.expense, currency: entryCurrency))")
        }
        let amountDescription = parts.joined(separator: " | ")
        if amountDescription.isEmpty {
            return purpose
        }
        return "\(purpose) · \(amountDescription)"
    }

    private func displayPurpose(for entry: LedgerEntry) -> String {
        (entry.purpose?.isEmpty == false) ? (entry.purpose ?? "") : "未设置"
    }

    private func formattedValue(_ value: Double, currency: AppCurrency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amount = formatter.string(from: NSNumber(value: value)) ?? "0.00"
        return amount + " " + currency.symbol
    }

    private var filteredEntries: [LedgerEntry] {
        switch selectedFilter {
        case .all:
            return Array(entries)
        case .expense:
            return entries.filter { $0.expense > 0 }
        case .income:
            return entries.filter { $0.income > 0 }
        }
    }

    private var currentMonthEntries: [LedgerEntry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        }
    }

    private var currentMonthIncome: Double {
        currentMonthEntries.reduce(0) { $0 + $1.income }
    }

    private var currentMonthExpense: Double {
        currentMonthEntries.reduce(0) { $0 + $1.expense }
    }

    private var currentMonthBalance: Double {
        currentMonthIncome - currentMonthExpense
    }

    private var currentMonthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: Date())
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }

    private func formatMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: value)) ?? "0.00") + " " + currency.symbol
    }

    /// 盈亏显示：大于等于 0 显示 + 金额，小于 0 显示 - 金额
    private func formatBalanceWithSign(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let numStr = formatter.string(from: NSNumber(value: abs(value))) ?? "0.00"
        let sign = value >= 0 ? "+ " : "- "
        return sign + numStr + " " + currency.symbol
    }
}

private extension HomeView {
    var editPurposeSheet: some View {
        NavigationStack {
            Form {
                Section("用途") {
                    TextField("请输入用途", text: $editedPurposeText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("编辑用途")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismissPurposeEditor() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveEditedPurpose() }
                }
            }
        }
    }
}

private struct SummaryChip: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.15))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 单条记录行
private struct EntryRow: View {
    let entry: LedgerEntry
    let currency: AppCurrency
    var onDelete: (() -> Void)?
    var onLongPress: (() -> Void)?

    private var displayPurpose: String {
        (entry.purpose?.isEmpty == false) ? (entry.purpose ?? "") : "—"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(displayPurpose)
                    .font(.subheadline.weight(.semibold))
                Text(entry.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !detailTag.isEmpty {
                    Text(detailTag)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(iconColor.opacity(0.15))
                        .foregroundStyle(iconColor)
                        .clipShape(Capsule())
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if entry.income > 0 {
                    Text("+\(format(entry.income))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
                if entry.expense > 0 {
                    Text("-\(format(entry.expense))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
                Text(entryTimeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if onDelete != nil {
                Button(role: .destructive, action: { onDelete?() }, label: {
                    Image(systemName: "trash")
                        .font(.body)
                })
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onLongPressGesture {
            onLongPress?()
        }
    }

    private func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: value)) ?? "0.00") + currency.symbol
    }

    private var iconName: String {
        if entry.income > 0 && entry.expense == 0 {
            return "arrow.down.right.circle.fill"
        } else if entry.expense > 0 && entry.income == 0 {
            return "arrow.up.right.circle.fill"
        } else {
            return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    private var iconColor: Color {
        if entry.income > 0 && entry.expense == 0 {
            return .green
        } else if entry.expense > 0 && entry.income == 0 {
            return .red
        } else {
            return .blue
        }
    }

    private var detailTag: String {
        if entry.income > 0 && entry.expense == 0 {
            return "收入"
        } else if entry.expense > 0 && entry.income == 0 {
            return "支出"
        } else if entry.income > 0 && entry.expense > 0 {
            return "收支"
        } else {
            return ""
        }
    }

    private var entryTimeText: String {
        let date = entry.date ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
