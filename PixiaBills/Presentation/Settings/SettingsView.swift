import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: BillsStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var lockManager: BiometricLockManager

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

                Section(header: Text("同步与安全")) {
                    Toggle("iCloud 同步", isOn: Binding(
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

    private static let syncDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()
}
