import SwiftUI

struct WebDAVSyncSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: BillsStore

    @State private var message: IdentifiableMessage?

    var body: some View {
        Form {
            Section(header: Text("服务器"), footer: Text("建议使用 https。若使用 http，可能会被 iOS 的网络安全策略限制。")) {
                Picker("协议", selection: $settings.webDAVScheme) {
                    Text("https").tag("https")
                    Text("http").tag("http")
                }
                .pickerStyle(.segmented)

                TextField("地址（Host）", text: $settings.webDAVHost)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)

                TextField("端口（可选）", text: $settings.webDAVPort)
                    .keyboardType(.numberPad)

                TextField("路径（目录）", text: $settings.webDAVPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section(header: Text("认证"), footer: Text("如服务器支持匿名访问，可不填用户名密码。")) {
                TextField("用户名", text: $settings.webDAVUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                SecureField("密码", text: $settings.webDAVPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section(header: Text("加密"), footer: Text("使用 AES-256-GCM 对同步文件加密。两台设备必须填写同一密钥才能互相解密。")) {
                SecureField("加密密钥", text: $settings.webDAVEncryptionKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section(header: Text("预览")) {
                HStack {
                    Text("目标")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settings.webDAVConfiguration.endpointDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section(header: Text("手动同步"), footer: Text("开启 WebDAV 同步后，应用会在本地变更、配置更新和回到前台时自动拉取合并并回写。以下按钮用于手动排查与强制同步。")) {
                Button {
                    Task {
                        let text = await store.refreshICloudSyncStatusNow(configuration: settings.webDAVConfiguration)
                        message = IdentifiableMessage(message: text)
                    }
                } label: {
                    Label("检查状态", systemImage: "waveform.path.ecg")
                }

                Button {
                    Task {
                        let text = await store.pullFromICloudNow(configuration: settings.webDAVConfiguration)
                        message = IdentifiableMessage(message: text)
                    }
                } label: {
                    Label("拉取并合并", systemImage: "arrow.down.circle")
                }

                Button {
                    Task {
                        let text = await store.pushToICloudNow(configuration: settings.webDAVConfiguration)
                        message = IdentifiableMessage(message: text)
                    }
                } label: {
                    Label("推送", systemImage: "arrow.up.circle")
                }

                NavigationLink {
                    SyncLogsView()
                } label: {
                    Label("同步日志", systemImage: "text.justify")
                }
            }
        }
        .navigationTitle("WebDAV 同步")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $message) { message in
            Alert(title: Text("提示"), message: Text(message.message), dismissButton: .default(Text("知道了")))
        }
    }
}
