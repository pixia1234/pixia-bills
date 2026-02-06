import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject private var store: BillsStore
    @State private var type: TransactionType = .expense
    @State private var showingEditor = false
    @State private var editingCategory: Category?

    var body: some View {
        List {
            Section {
                Picker("", selection: $type) {
                    ForEach(TransactionType.allCases, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                let list = store.categories(ofType: type)
                ForEach(list) { category in
                    Button {
                        editingCategory = category
                        showingEditor = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.iconName)
                                .foregroundColor(.black)
                                .frame(width: 30, height: 30)
                                .background(Color("SecondaryBackground"))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text(category.name)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .onDelete { offsets in
                    store.deleteCategories(at: offsets, type: type)
                }
                .onMove { source, destination in
                    store.moveCategories(from: source, to: destination, type: type)
                }
            }
        }
        .navigationTitle("分类管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingCategory = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            CategoryEditorSheet(type: type, category: editingCategory)
                .environmentObject(store)
        }
    }
}

private struct CategoryEditorSheet: View {
    @EnvironmentObject private var store: BillsStore
    @Environment(\.dismiss) private var dismiss

    let type: TransactionType
    let category: Category?

    @State private var name: String = ""
    @State private var iconName: String = "tag"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("名称")) {
                    TextField("例如：餐饮", text: $name)
                }

                Section(header: Text("图标（SF Symbols）")) {
                    TextField("例如：fork.knife", text: $iconName)
                    HStack {
                        Text("预览")
                        Spacer()
                        Image(systemName: iconName)
                            .foregroundColor(.black)
                            .frame(width: 34, height: 34)
                            .background(Color("SecondaryBackground"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .navigationTitle(category == nil ? "新增分类" : "编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    iconName = category.iconName
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if var category {
            category.name = trimmed
            category.iconName = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
            store.updateCategory(category)
        } else {
            store.addCategory(type: type, name: trimmed, iconName: iconName.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        dismiss()
    }
}
