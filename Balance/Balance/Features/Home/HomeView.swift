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
    @FocusState private var focusedField: Field?

    enum Field {
        case expense, income, purpose
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

    private var currency: AppCurrency { .CNY }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 20) {
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
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Text(currency.symbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("收入")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $incomeText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .income)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Text(currency.symbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("用途")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("如：餐饮、交通", text: $purposeText)
                    .focused($focusedField, equals: .purpose)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Text("货币")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(currency.displayName)
                    .font(.subheadline.weight(.medium))
            }

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
        VStack(alignment: .leading, spacing: 12) {
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

            if entries.isEmpty {
                ContentUnavailableView {
                    Label("暂无记录", systemImage: "tray")
                } description: {
                    Text("点击上方「添加记录」开始记账")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(entries, id: \.objectID) { entry in
                        EntryRow(entry: entry, currency: currency)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteEntry(entry)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
        }
    }

    // MARK: - 底部盈亏栏
    private var balanceBar: some View {
        VStack(spacing: 4) {
            Text("盈亏")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(formatMoney(abs(balance)))
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
        entry.currency = currency.rawValue
        entry.purpose = purposeText.isEmpty ? nil : purposeText
        entry.createdAt = Date()

        expenseText = ""
        incomeText = ""
        purposeText = ""
        focusedField = nil

        saveContext()
    }

    private func deleteEntry(_ entry: LedgerEntry) {
        viewContext.delete(entry)
        saveContext()
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
}

// MARK: - 单条记录行
private struct EntryRow: View {
    let entry: LedgerEntry
    let currency: AppCurrency

    private var displayPurpose: String {
        (entry.purpose?.isEmpty == false) ? (entry.purpose ?? "") : "—"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayPurpose)
                    .font(.subheadline.weight(.medium))
                Text(entry.date ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                let income = entry.income
                let expense = entry.expense
                if income > 0 {
                    Text("+\(format(income))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
                if expense > 0 {
                    Text("-\(format(expense))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: value)) ?? "0.00") + currency.symbol
    }
}

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
