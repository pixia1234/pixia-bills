import SwiftUI
import UIKit

struct LLMImageImportView: View {
    @EnvironmentObject private var store: BillsStore
    @EnvironmentObject private var settings: AppSettings

    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var extraInstruction: String = ""
    @State private var drafts: [LLMImportedTransactionDraft] = []
    @State private var selectedDraftIDs: Set<UUID> = []
    @State private var isAnalyzing = false
    @State private var message: IdentifiableMessage?

    private let service = LLMImportService()

    var body: some View {
        List {
            Section(header: Text("图片")) {
                Button {
                    showingImagePicker = true
                } label: {
                    Label(selectedImage == nil ? "选择图片" : "重新选择图片", systemImage: "photo")
                }

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Section(header: Text("识别选项")) {
                TextField("额外要求（可选，例如：只导入餐饮）", text: $extraInstruction)
                Button {
                    analyzeImage()
                } label: {
                    if isAnalyzing {
                        HStack {
                            ProgressView()
                            Text("识别中…")
                        }
                    } else {
                        Label("让大语言模型识别并生成导入选项", systemImage: "wand.and.stars")
                    }
                }
                .disabled(!canAnalyze)
            }

            if !drafts.isEmpty {
                Section(header: Text("导入选项（\(selectedDraftIDs.count)/\(drafts.count)）")) {
                    ForEach(drafts) { draft in
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                toggleSelection(for: draft.id)
                            } label: {
                                Image(systemName: selectedDraftIDs.contains(draft.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedDraftIDs.contains(draft.id) ? .accentColor : .secondary)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(draft.type == "income" ? "收入" : "支出") · \(draft.amount)")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("分类：\(draft.categoryName.isEmpty ? "未识别" : draft.categoryName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("账户：\(draft.accountName.isEmpty ? "默认账户" : draft.accountName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if !draft.note.isEmpty {
                                    Text("备注：\(draft.note)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Button {
                        importSelectedDrafts()
                    } label: {
                        Label("导入所选项", systemImage: "square.and.arrow.down")
                    }
                    .disabled(selectedDraftIDs.isEmpty)
                }
            }
        }
        .navigationTitle("AI 图片导入")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImagePicker) {
            PhotoLibraryImagePicker(image: $selectedImage)
        }
        .alert(item: $message) { message in
            Alert(title: Text("提示"), message: Text(message.message), dismissButton: .default(Text("知道了")))
        }
    }

    private var canAnalyze: Bool {
        guard selectedImage != nil else { return false }
        let config = LLMImportConfiguration(apiBase: settings.llmAPIBase, apiKey: settings.llmAPIKey, model: settings.llmModel)
        return config.endpointURL != nil && !config.normalizedKey.isEmpty && !config.normalizedModel.isEmpty && !isAnalyzing
    }

    private func analyzeImage() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.9) else {
            message = IdentifiableMessage(message: "请先选择要识别的图片")
            return
        }

        let configuration = LLMImportConfiguration(
            apiBase: settings.llmAPIBase,
            apiKey: settings.llmAPIKey,
            model: settings.llmModel
        )

        isAnalyzing = true
        Task {
            defer { isAnalyzing = false }
            do {
                let result = try await service.parseTransactionsFromImage(
                    imageData: imageData,
                    configuration: configuration,
                    extraInstruction: extraInstruction
                )
                drafts = result
                selectedDraftIDs = Set(result.map(\.id))
            } catch {
                message = IdentifiableMessage(message: error.localizedDescription)
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedDraftIDs.contains(id) {
            selectedDraftIDs.remove(id)
        } else {
            selectedDraftIDs.insert(id)
        }
    }

    private func importSelectedDrafts() {
        let selected = drafts.filter { selectedDraftIDs.contains($0.id) }
        let count = store.importTransactionsFromLLM(selected)

        if count > 0 {
            message = IdentifiableMessage(message: "已成功导入 \(count) 笔流水")
            drafts = []
            selectedDraftIDs = []
            selectedImage = nil
            extraInstruction = ""
        } else {
            message = IdentifiableMessage(message: "未导入任何流水，请检查识别结果")
        }
    }
}
