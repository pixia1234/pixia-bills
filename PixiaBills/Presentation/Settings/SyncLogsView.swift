import SwiftUI

struct SyncLogsView: View {
    @EnvironmentObject private var store: BillsStore

    var body: some View {
        List {
            if store.iCloudSyncLogs.isEmpty {
                Text("暂无同步日志")
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.iCloudSyncLogs) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.message)
                            .font(.system(size: 14))
                        Text(Self.logDateFormatter.string(from: entry.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("同步日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清空") {
                    store.clearICloudSyncLogs()
                }
                .disabled(store.iCloudSyncLogs.isEmpty)
            }
        }
    }

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter
    }()
}
