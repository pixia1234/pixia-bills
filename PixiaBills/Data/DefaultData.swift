import Foundation

enum DefaultData {
    static let accounts: [Account] = [
        Account(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "现金",
            type: .cash,
            initialBalance: 0
        ),
        Account(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "储蓄卡",
            type: .bank,
            initialBalance: 0
        )
    ]

    static let categories: [Category] = {
        func expense(_ name: String, _ icon: String, _ order: Int) -> Category {
            Category(
                id: UUID(),
                type: .expense,
                name: name,
                iconName: icon,
                sortOrder: order,
                isDefault: true
            )
        }

        func income(_ name: String, _ icon: String, _ order: Int) -> Category {
            Category(
                id: UUID(),
                type: .income,
                name: name,
                iconName: icon,
                sortOrder: order,
                isDefault: true
            )
        }

        return [
            expense("餐饮", "fork.knife", 0),
            expense("购物", "bag", 1),
            expense("交通", "car", 2),
            expense("居家", "house", 3),
            expense("娱乐", "gamecontroller", 4),
            expense("通讯", "phone", 5),
            expense("医疗", "cross.case", 6),
            expense("学习", "book", 7),
            expense("其他", "ellipsis", 8),
            income("工资", "banknote", 0),
            income("兼职", "briefcase", 1),
            income("红包", "gift", 2),
            income("其他", "ellipsis", 3)
        ]
    }()
}
