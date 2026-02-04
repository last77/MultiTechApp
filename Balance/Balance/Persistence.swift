//
//  Persistence.swift
//  Balance
//
//  Created by app on 2026/2/2.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // 预览用 LedgerEntry 样本数据
        let purposes = ["餐饮", "交通", "购物", "工资", "兼职"]
        let base = Date()
        let dates = [base, Calendar.current.date(byAdding: .day, value: -1, to: base) ?? base, Calendar.current.date(byAdding: .day, value: -2, to: base) ?? base]
        for (i, date) in dates.enumerated() {
            let entry = LedgerEntry(context: viewContext)
            entry.date = date
            entry.createdAt = date
            entry.currency = "CNY"
            entry.purpose = purposes[i % purposes.count]
            if i % 2 == 0 {
                entry.expense = Double((i + 1) * 25)
                entry.income = 0
            } else {
                entry.expense = 0
                entry.income = Double((i + 1) * 500)
            }

            let activity = LedgerActivity(context: viewContext)
            activity.id = UUID()
            activity.timestamp = date
            activity.action = i % 2 == 0 ? "新增记录" : "删除记录"
            activity.detail = "\(entry.purpose ?? "未设置") · \(entry.currency ?? "CNY")"
        }
        let editActivity = LedgerActivity(context: viewContext)
        editActivity.id = UUID()
        editActivity.timestamp = Calendar.current.date(byAdding: .hour, value: -6, to: base) ?? base
        editActivity.action = "修改用途"
        editActivity.detail = "购物 → 生活日用"
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Balance")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
