import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: BillsStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var lockManager: BiometricLockManager

    @State private var exportURL: IdentifiableURL?
    @State private var alertMessage: IdentifiableMessage?
    @State private var showingCSVImporter = false

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
                            alertMessage = IdentifiableMessage(message: "导出失败：\(error.localizedDescription)")
                        }
                    } label: {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingCSVImporter = true
                    } label: {
                        Label("导入 CSV", systemImage: "square.and.arrow.down")
                    }
                }

                Section(header: Text("同步与安全")) {
                    Toggle("iCloud 云盘同步", isOn: Binding(
                        get: { settings.iCloudSyncEnabled },
                        set: { settings.iCloudSyncEnabled = $0 }
                    ))

                    if settings.iCloudSyncEnabled {
                        HStack {
                            Text("状态")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(store.iCloudSyncStatus)
                        }

                        if let syncedAt = store.iCloudLastSyncedAt {
                            HStack {
                                Text("最近同步")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Self.syncDateFormatter.string(from: syncedAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button {
                            alertMessage = IdentifiableMessage(message: store.refreshICloudSyncStatusNow())
                        } label: {
                            Label("检查同步状态", systemImage: "waveform.path.ecg")
                        }

                        Button {
                            alertMessage = IdentifiableMessage(message: store.pullFromICloudNow())
                        } label: {
                            Label("立即拉取并合并", systemImage: "arrow.down.circle")
                        }

                        Button {
                            alertMessage = IdentifiableMessage(message: store.pushToICloudNow())
                        } label: {
                            Label("立即推送", systemImage: "arrow.up.circle")
                        }

                        NavigationLink {
                            ICloudSyncLogsView()
                        } label: {
                            Label("同步日志", systemImage: "text.justify")
                        }
                    }

                    Toggle("FaceID/TouchID 解锁", isOn: Binding(
                        get: { settings.biometricLockEnabled },
                        set: { enabled in
                            settings.biometricLockEnabled = enabled
                            lockManager.setEnabled(enabled)
                            if enabled {
                                Task {
                                    await lockManager.unlockIfNeeded()
                                }
                            }
                        }
                    ))

                    if let message = lockManager.errorMessage, !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("AI 一键导入"), footer: Text("填写 OpenAI 兼容配置后，可上传图片并由大语言模型生成导入选项。")) {
                    NavigationLink {
                        LLMImageImportView()
                    } label: {
                        Label("从图片导入流水", systemImage: "wand.and.stars")
                    }

                    TextField("LLM API Base", text: $settings.llmAPIBase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.URL)

                    SecureField("LLM API Key", text: $settings.llmAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    TextField("模型（如 gpt-4o-mini）", text: $settings.llmModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section(header: Text("关于")) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于 pixia-bills", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $exportURL) { url in
                ShareSheet(activityItems: [url.url])
            }
            .fileImporter(
                isPresented: $showingCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                handleCSVImport(result)
            }
            .alert(item: $alertMessage) { message in
                Alert(title: Text("提示"), message: Text(message.message), dismissButton: .default(Text("知道了")))
            }
        }
    }

    private static let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()

    private func handleCSVImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importCSV(from: url)
        case .failure(let error):
            alertMessage = IdentifiableMessage(message: "导入失败：\(error.localizedDescription)")
        }
    }

    private func importCSV(from url: URL) {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let importedCount = try store.importTransactionsCSV(from: url)
            if importedCount > 0 {
                alertMessage = IdentifiableMessage(message: "已成功导入 \(importedCount) 笔流水")
            } else {
                alertMessage = IdentifiableMessage(message: "没有可导入的新流水（可能已存在或格式无效）")
            }
        } catch {
            alertMessage = IdentifiableMessage(message: "导入失败：\(error.localizedDescription)")
        }
    }
}
