import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: BillsStore

    @State private var exportURL: IdentifiableURL?
    @State private var exportErrorMessage: IdentifiableMessage?

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("数据")) {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("分类管理", systemImage: "square.grid.2x2")
                    }

                    NavigationLink {
                        BudgetsView()
                    } label: {
                        Label("预算", systemImage: "chart.pie")
                    }

                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label("账户与转账", systemImage: "creditcard")
                    }

                    NavigationLink {
                        RecurringTransactionsView()
                    } label: {
                        Label("周期记账", systemImage: "repeat")
                    }

                    Button {
                        do {
                            exportURL = IdentifiableURL(url: try store.exportTransactionsCSV())
                        } catch {
                            exportErrorMessage = IdentifiableMessage(message: error.localizedDescription)
                        }
                    } label: {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                    }
                }

                Section(header: Text("其他（第二阶段）")) {
                    Toggle("iCloud 同步", isOn: .constant(false))
                        .disabled(true)
                    Toggle("FaceID/TouchID 解锁", isOn: .constant(false))
                        .disabled(true)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $exportURL) { url in
                ShareSheet(activityItems: [url.url])
            }
            .alert(item: $exportErrorMessage) { message in
                Alert(title: Text("导出失败"), message: Text(message.message), dismissButton: .default(Text("知道了")))
            }
        }
    }
}
