import SwiftUI

struct AboutView: View {
    private let githubURL = URL(string: "https://github.com/pixia1234/pixia-bills")!

    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 10) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 72, height: 72)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("pixia-bills")
                        .font(.headline)

                    Text(versionText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section(header: Text("项目")) {
                Link(destination: githubURL) {
                    Label("GitHub 仓库", systemImage: "link")
                }

                Text(githubURL.absoluteString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "版本 \(version) (\(build))"
    }
}
