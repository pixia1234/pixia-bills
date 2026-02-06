import SwiftUI

struct AddTransactionSheet: View {
    private enum Step {
        case pickCategory
        case inputAmount
    }

    @EnvironmentObject private var store: BillsStore
    @Environment(\.dismiss) private var dismiss

    @State private var type: TransactionType = .expense
    @State private var step: Step = .pickCategory
    @State private var selectedCategory: Category?

    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var accountId: UUID?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                switch step {
                case .pickCategory:
                    CategoryPickerStep(
                        type: $type,
                        categories: store.categories,
                        onSelect: { category in
                            selectedCategory = category
                            step = .inputAmount
                        }
                    )
                case .inputAmount:
                    AmountInputStep(
                        type: type,
                        category: selectedCategory,
                        accounts: store.accounts,
                        accountId: $accountId,
                        amountText: $amountText,
                        note: $note,
                        date: $date,
                        onBack: {
                            step = .pickCategory
                            selectedCategory = nil
                            amountText = ""
                        },
                        onSave: save
                    )
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        guard let category = selectedCategory else { return }
        guard let amount = DecimalParser.parse(amountText), amount > 0 else { return }

        store.addTransaction(
            type: type,
            amount: amount,
            date: date,
            categoryId: category.id,
            accountId: accountId ?? store.defaultAccountId,
            note: note
        )
        dismiss()
    }
}

private struct CategoryPickerStep: View {
    @Binding var type: TransactionType
    let categories: [Category]
    let onSelect: (Category) -> Void

    private var filtered: [Category] {
        categories
            .filter { $0.type == type }
            .sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("", selection: $type) {
                ForEach(TransactionType.allCases, id: \.self) { t in
                    Text(t.displayName).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filtered) { category in
                        Button {
                            onSelect(category)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 44, height: 44)
                                    .background(Color("SecondaryBackground"))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                Text(category.name)
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct AmountInputStep: View {
    let type: TransactionType
    let category: Category?
    let accounts: [Account]
    @Binding var accountId: UUID?
    @Binding var amountText: String
    @Binding var note: String
    @Binding var date: Date
    let onBack: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(Color("SecondaryBackground"))
                        .clipShape(Circle())
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(category?.name ?? "")
                        .font(.headline)
                }

                Spacer()

                Button("保存") {
                    onSave()
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color("PrimaryYellow"))
                .foregroundColor(.primary)
                .clipShape(Capsule())
                .accessibilityLabel("保存流水")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 10) {
                Text(amountText.isEmpty ? "0" : amountText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    TextField("备注", text: $note)
                        .textFieldStyle(.roundedBorder)

                    DatePicker("", selection: $date, displayedComponents: [.date])
                        .labelsHidden()
                }

                if !accounts.isEmpty {
                    Picker("账户", selection: Binding<UUID>(
                        get: { accountId ?? accounts.first?.id ?? UUID() },
                        set: { accountId = $0 }
                    )) {
                        ForEach(accounts) { account in
                            Text(account.name).tag(account.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0)

            AmountKeypad(text: $amountText)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .onAppear {
            if accountId == nil {
                accountId = accounts.first?.id
            }
        }
    }
}

private struct AmountKeypad: View {
    @Binding var text: String

    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0"], id: \.self) { value in
                KeyButton(title: value) {
                    append(value)
                }
            }

            KeyButton(title: "⌫") {
                if !text.isEmpty {
                    text.removeLast()
                }
            }
        }
    }

    private func append(_ value: String) {
        if value == "." {
            guard !text.contains(".") else { return }
            text = text.isEmpty ? "0." : text + value
            return
        }

        if text == "0" {
            text = value
        } else {
            text += value
        }
    }
}

private struct KeyButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color("SecondaryBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
