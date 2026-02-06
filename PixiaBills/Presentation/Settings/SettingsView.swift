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

                Section(header: Text("同步（第二阶段）")) {
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

private struct IdentifiableMessage: Identifiable {
    let id = UUID()
    let message: String
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
