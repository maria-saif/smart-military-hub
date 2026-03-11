import SwiftUI
import Combine
import QuickLook
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UniformTypeIdentifiers
import SafariServices
import UIKit

enum DocType: String, Codable, CaseIterable, Identifiable {
    case pdf, image, video, doc, other
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .pdf:   return "doc.text.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .doc:   return "doc.richtext.fill"
        case .other: return "tray.full.fill"
        }
    }
    var color: Color {
        switch self {
        case .pdf: return .red
        case .image: return .blue
        case .video: return .purple
        case .doc: return .teal
        case .other: return .gray
        }
    }
}

struct FieldDoc: Identifiable, Hashable {
    var id: String
    var title: String
    var type: DocType
    var downloadURL: String?
    var storagePath: String?
    var bucket: String?
    var size: Int?
    var updatedAt: Date?
    var tags: [String]
    var isFavorite: Bool
    var isSample: Bool

    init(id: String,
         title: String,
         type: DocType,
         downloadURL: String? = nil,
         storagePath: String? = nil,
         bucket: String? = nil,
         size: Int? = nil,
         updatedAt: Date? = nil,
         tags: [String] = [],
         isFavorite: Bool = false,
         isSample: Bool = false) {
        self.id = id
        self.title = title
        self.type = type
        self.downloadURL = downloadURL
        self.storagePath = storagePath
        self.bucket = bucket
        self.size = size
        self.updatedAt = updatedAt
        self.tags = tags
        self.isFavorite = isFavorite
        self.isSample = isSample
    }

    init?(id: String, dict: [String: Any]) {
        guard let title = dict["title"] as? String else { return nil }
        let typeRaw = (dict["type"] as? String) ?? "other"
        let type = DocType(rawValue: typeRaw) ?? .other
        let updatedAt: Date? = (dict["updatedAt"] as? Timestamp)?.dateValue()
        self.init(
            id: id,
            title: title,
            type: type,
            downloadURL: dict["downloadURL"] as? String,
            storagePath: dict["storagePath"] as? String,
            bucket: dict["bucket"] as? String,
            size: dict["size"] as? Int,
            updatedAt: updatedAt,
            tags: dict["tags"] as? [String] ?? [],
            isFavorite: dict["isFavorite"] as? Bool ?? false,
            isSample: dict["isSample"] as? Bool ?? false
        )
    }
}

final class FieldLibraryRepository {
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func path(uid: String) -> CollectionReference {
        db.collection("soldiers").document(uid).collection("library")
    }

    func listen(uid: String, onChange: @escaping ([FieldDoc]) -> Void) {
        listener?.remove()
        listener = path(uid: uid)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Listen error:", error.localizedDescription)
                    onChange([])
                    return
                }
                let docs = snapshot?.documents
                    .compactMap { FieldDoc(id: $0.documentID, dict: $0.data()) }
                    .filter { $0.isSample == false } ?? []

                print("LIB LOADED (\(docs.count)) ->", docs.map { "\($0.title): \($0.downloadURL ?? "-") [\($0.storagePath ?? "-")]" })
                onChange(docs)
            }
    }

    func stop() { listener?.remove(); listener = nil }

    func addSample(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let data: [String: Any] = [
            "title": "تعليمات الطوارئ (عيّنة)",
            "type": "pdf",
            "downloadURL": "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
            "size": 245_760,
            "updatedAt": FieldValue.serverTimestamp(),
            "tags": ["سلامة", "ميدان"],
            "isFavorite": false,
            "isSample": true
        ]
        path(uid: uid).addDocument(data: data) { err in
            if let err = err { completion(.failure(err)) }
            else { completion(.success(())) }
        }
    }

    func addLink(uid: String, title: String, url: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let data: [String: Any] = [
            "title": title,
            "type": "pdf",
            "downloadURL": url,
            "storagePath": "",
            "bucket": "",
            "size": 0,
            "updatedAt": FieldValue.serverTimestamp(),
            "tags": ["رابط خارجي"],
            "isFavorite": false,
            "isSample": false
        ]
        path(uid: uid).addDocument(data: data) { err in
            if let err = err { completion(.failure(err)) }
            else { completion(.success(())) }
        }
    }

    func backfillAllTimestamps(uid: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let col = path(uid: uid)
        col.getDocuments { snap, err in
            if let err = err { completion(.failure(err)); return }
            let docs = snap?.documents ?? []
            let batch = self.db.batch()
            var edited = 0
            for d in docs {
                if (d.data()["updatedAt"] == nil) || (d.data()["updatedAt"] is NSNull) {
                    batch.setData(["updatedAt": FieldValue.serverTimestamp()], forDocument: d.reference, merge: true)
                    edited += 1
                }
            }
            if edited == 0 { completion(.success(0)); return }
            batch.commit { err2 in
                if let err2 = err2 { completion(.failure(err2)) }
                else { completion(.success(edited)) }
            }
        }
    }

    private func fetchDownloadURLWithRetry(
        ref: StorageReference,
        attempts: Int = 12,
        baseDelayMs: UInt64 = 700
    ) async throws -> URL {
        var lastError: Error?
        for i in 0..<attempts {
            do {
                let url = try await withCheckedThrowingContinuation { cont in
                    ref.downloadURL { url, err in
                        if let url = url { cont.resume(returning: url) }
                        else { cont.resume(throwing: err ?? NSError(domain: "downloadURL", code: -1)) }
                    }
                }
                return url
            } catch {
                lastError = error
                if let e = error as NSError?,
                   e.domain == StorageErrorDomain,
                   (e.code == StorageErrorCode.objectNotFound.rawValue ||
                    e.code == StorageErrorCode.unknown.rawValue) {
                    let jitter = UInt64(Int.random(in: 0...200))
                    let waitMs = (baseDelayMs * UInt64(i + 1)) + jitter
                    try? await Task.sleep(nanoseconds: waitMs * 1_000_000)
                    continue
                } else {
                    throw error
                }
            }
        }
        throw lastError ?? NSError(domain: "downloadURL", code: -2,
                                   userInfo: [NSLocalizedDescriptionKey: "Failed after retries"])
    }

    func uploadPDF(uid: String,
                   localURL: URL,
                   onProgress: @escaping (Double) -> Void = { _ in },
                   completion: @escaping (Result<Void, Error>) -> Void) {

        let storage = Storage.storage()
        let filename = localURL.lastPathComponent.isEmpty
            ? "file-\(UUID().uuidString.prefix(6)).pdf"
            : localURL.lastPathComponent
        let ref = storage.reference().child("soldiers/\(uid)/library/\(filename)")

        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"

        let task = ref.putFile(from: localURL, metadata: metadata) { meta, error in
            if let error = error { completion(.failure(error)); return }

            Task {
                var urlString: String? = nil
                do {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                    let url = try await self.fetchDownloadURLWithRetry(ref: ref)
                    urlString = url.absoluteString
                } catch {
                    print("⚠️ downloadURL not ready yet (saving without it): \(error.localizedDescription)")
                }

                var fileSize = Int(meta?.size ?? 0)
                if fileSize == 0 {
                    let attrs = (try? FileManager.default.attributesOfItem(atPath: localURL.path)) ?? [:]
                    fileSize = (attrs[.size] as? NSNumber)?.intValue ?? 0
                }

                let data: [String: Any] = [
                    "title": filename.replacingOccurrences(of: ".pdf", with: ""),
                    "type": "pdf",
                    "downloadURL": urlString as Any,
                    "storagePath": ref.fullPath,
                    "bucket": ref.bucket,
                    "size": fileSize,
                    "updatedAt": FieldValue.serverTimestamp(),
                    "tags": ["مرفوع"],
                    "isFavorite": false,
                    "isSample": false
                ]
                self.path(uid: uid).addDocument(data: data) { err2 in
                    if let err2 = err2 { completion(.failure(err2)) }
                    else { completion(.success(())) }
                }
            }
        }

        task.observe(.progress) { snap in
            guard let p = snap.progress else { return }
            let ratio = p.totalUnitCount > 0 ? Double(p.completedUnitCount) / Double(p.totalUnitCount) : 0
            onProgress(ratio)
        }
    }

    func delete(doc: FieldDoc, uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        func deleteFirestore() {
            path(uid: uid).document(doc.id).delete { err in
                if let err = err { completion(.failure(err)) }
                else { completion(.success(())) }
            }
        }

        if let storagePath = doc.storagePath, !storagePath.isEmpty {
            let storageRef = Storage.storage().reference(withPath: storagePath)
            storageRef.delete { _ in deleteFirestore() }
        } else {
            deleteFirestore()
        }
    }
}

enum FileCacheError: Error { case writeFailed, notPDF }

final class FileCache {
    static let shared = FileCache(); private init() {}

    private func safeFolder() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let folder = caches.appendingPathComponent("SMH-Library", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func cachedURL(for remote: URL) -> URL {
        let key = remote.absoluteString
        let safe = key.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return safeFolder().appendingPathComponent(safe + ".bin")
    }

    func wipe() {
        let folder = safeFolder()
        try? FileManager.default.removeItem(at: folder)
        _ = safeFolder()
    }

    @discardableResult
    func ensureDownloaded(from remote: URL) async throws -> URL {
        let dest = cachedURL(for: remote)
        if FileManager.default.fileExists(atPath: dest.path) { return dest }

        let (data, response) = try await URLSession.shared.data(from: remote)

        let head = String(decoding: data.prefix(5), as: UTF8.self)
        let mime = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
        let looksLikePDF = head.hasPrefix("%PDF-") || mime.lowercased().contains("application/pdf")
        guard looksLikePDF else { throw FileCacheError.notPDF }

        try data.write(to: dest, options: .atomic)
        return dest
    }
}

@MainActor
final class FieldLibraryViewModel: ObservableObject {
    @Published var items: [FieldDoc] = []
    @Published var query: String = ""
    @Published var alertMsg: String?
    @Published var showHUD: Bool = false

    @Published var previewURL: URL?
    @Published var showPreview: Bool = false

    @Published var showDocPicker = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0

    @Published var safariURL: URL?
    @Published var showSafari: Bool = false

    @Published var showAddLink = false
    @Published var newLinkTitle = ""
    @Published var newLinkURL = ""

    private let repo = FieldLibraryRepository()
    private var uid: String?

    func onAppear() {
        let currentUID = Auth.auth().currentUser?.uid
        print("DEBUG UID:", currentUID ?? "nil")
        guard let uid = currentUID else {
            alertMsg = "لا يوجد مستخدم مسجّل دخول. يرجى تسجيل الدخول ثم إعادة المحاولة."
            items.removeAll()
            return
        }
        self.uid = uid
        repo.listen(uid: uid) { [weak self] docs in
            Task { @MainActor in self?.items = docs }
        }
    }

    func onDisappear() { repo.stop() }

    var filteredItems: [FieldDoc] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return items }
        let q = query.lowercased()
        return items.filter {
            $0.title.lowercased().contains(q) ||
            $0.tags.joined(separator: " ").lowercased().contains(q) ||
            $0.type.rawValue.lowercased().contains(q)
        }
    }

    func addSampleTapped() {
        guard let uid = uid ?? Auth.auth().currentUser?.uid else {
            alertMsg = "لا يوجد مستخدم مسجّل دخول."
            return
        }
        showHUD = true
        repo.addSample(uid: uid) { [weak self] result in
            Task { @MainActor in
                self?.showHUD = false
                switch result {
                case .success:
                    self?.alertMsg = "تمت إضافة العيّنة ✅ (لن تظهر في القائمة)"
                case .failure(let e):
                    self?.alertMsg = "تعذّر إضافة العيّنة: \(e.localizedDescription)"
                }
            }
        }
    }

    func uploadTapped() {
        guard Auth.auth().currentUser?.uid != nil else {
            alertMsg = "لا يوجد مستخدم مسجّل دخول."
            return
        }
        showDocPicker = true
    }

    func addLinkTapped() { showAddLink = true }

    func confirmAddLink() {
        guard let uid = Auth.auth().currentUser?.uid else {
            alertMsg = "لا يوجد مستخدم مسجّل دخول."; return
        }
        let title = newLinkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let u = URL(string: url), u.scheme?.hasPrefix("http") == true else {
            alertMsg = "تحقّقي من العنوان والرابط."; return
        }
        showAddLink = false
        showHUD = true
        repo.addLink(uid: uid, title: title, url: url) { [weak self] result in
            Task { @MainActor in
                self?.showHUD = false
                self?.newLinkTitle = ""; self?.newLinkURL = ""
                switch result {
                case .success: self?.alertMsg = "تمت إضافة الرابط ✅"
                case .failure(let e): self?.alertMsg = "تعذّرت الإضافة: \(e.localizedDescription)"
                }
            }
        }
    }

    func fixTimestampsTapped() {
        guard let uid = Auth.auth().currentUser?.uid else {
            alertMsg = "لا يوجد مستخدم مسجّل دخول."
            return
        }
        showHUD = true
        repo.backfillAllTimestamps(uid: uid) { [weak self] result in
            Task { @MainActor in
                self?.showHUD = false
                switch result {
                case .success(let n):
                    self?.alertMsg = n == 0 ? "كل التواريخ سليمة ✅" : "تم إصلاح \(n) عنصرًا ✅"
                case .failure(let e):
                    self?.alertMsg = "تعذّر الإصلاح: \(e.localizedDescription)"
                }
            }
        }
    }

    func handlePicked(_ url: URL) {
        guard let uid = Auth.auth().currentUser?.uid else {
            alertMsg = "لا يوجد مستخدم مسجّل دخول."
            return
        }
        isUploading = true
        uploadProgress = 0
        do {
            let local = try secureCopyIfNeeded(url)
            repo.uploadPDF(uid: uid, localURL: local, onProgress: { [weak self] p in
                Task { @MainActor in self?.uploadProgress = p }
            }, completion: { [weak self] result in
                Task { @MainActor in
                    self?.isUploading = false
                    switch result {
                    case .success:
                        self?.alertMsg = "تم رفع الملف وحفظه ✅"
                    case .failure(let e):
                        self?.alertMsg = "فشل رفع الملف: \(e.localizedDescription)"
                    }
                }
            })
        } catch {
            isUploading = false
            alertMsg = "تعذّر الوصول للملف المحدد."
        }
    }

    func deleteTapped(_ doc: FieldDoc) {
        guard let uid = Auth.auth().currentUser?.uid else {
            alertMsg = "لا يوجد مستخدم مسجّل دخول."
            return
        }
        showHUD = true
        repo.delete(doc: doc, uid: uid) { [weak self] result in
            Task { @MainActor in
                self?.showHUD = false
                switch result {
                case .success:
                    self?.alertMsg = "تم حذف الملف ✅"
                case .failure(let e):
                    self?.alertMsg = "تعذّر حذف الملف: \(e.localizedDescription)"
                }
            }
        }
    }

    func open(_ doc: FieldDoc) {
        if (doc.downloadURL == nil || doc.downloadURL?.isEmpty == true),
           let path = doc.storagePath, !path.isEmpty {
            showHUD = true
            Task {
                do {
                    let ref = Storage.storage().reference(withPath: path)
                    let remote = try await withCheckedThrowingContinuation { cont in
                        ref.downloadURL { url, err in
                            if let url = url { cont.resume(returning: url) }
                            else { cont.resume(throwing: err ?? NSError(domain: "downloadURL", code: -1)) }
                        }
                    }
                    do {
                        let local = try await FileCache.shared.ensureDownloaded(from: remote)
                        await MainActor.run {
                            self.previewURL = local
                            self.showPreview = true
                            self.showHUD = false
                        }
                    } catch FileCacheError.notPDF {
                        await MainActor.run {
                            self.safariURL = remote
                            self.showSafari = true
                            self.showHUD = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.alertMsg = "تعذّر تجهيز رابط المعاينة."
                        self.showHUD = false
                    }
                }
            }
            return
        }

        guard let s = doc.downloadURL else {
            alertMsg = "لا يوجد رابط تنزيل لهذا الملف."
            return
        }
        if s.hasPrefix("file://"), let local = URL(string: s) {
            previewURL = local
            showPreview = true
            return
        }
        guard let remote = URL(string: s) else {
            alertMsg = "رابط غير صالح."
            return
        }
        print("OPEN TAP ->", doc.title, s)
        showHUD = true
        Task {
            do {
                let local = try await FileCache.shared.ensureDownloaded(from: remote)
                await MainActor.run {
                    self.previewURL = local
                    self.showPreview = true
                    self.showHUD = false
                }
            } catch FileCacheError.notPDF {
                await MainActor.run {
                    self.showHUD = false
                    self.alertMsg = "هذا الرابط ليس PDF مباشر. سيتم فتحه في Safari."
                    self.safariURL = remote
                    self.showSafari = true
                }
            } catch {
                await MainActor.run {
                    self.alertMsg = "فشل تحميل الملف للمعاينة."
                    self.showHUD = false
                }
            }
        }
    }

    func clearCacheTapped() {
        FileCache.shared.wipe()
        alertMsg = "تم مسح كاش الملفات ✅"
    }

    // MARK: - Secure copy for picker URLs
    private func secureCopyIfNeeded(_ url: URL) throws -> URL {
        var didStart = false
        if url.startAccessingSecurityScopedResource() { didStart = true }
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let tmpFolder = FileManager.default.temporaryDirectory.appendingPathComponent("SMH-Uploads", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpFolder, withIntermediateDirectories: true)
        let destName = url.lastPathComponent.isEmpty ? "file-\(UUID().uuidString.prefix(6)).pdf" : url.lastPathComponent
        let dest = tmpFolder.appendingPathComponent(destName)
        _ = try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }
}

struct FieldLibraryView: View {
    @StateObject private var vm = FieldLibraryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.black.opacity(0.95), Color.green.opacity(0.35)],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                content
            }
            .navigationTitle("المكتبة الميدانية")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("رفع PDF حقيقي") { vm.uploadTapped() }
                        Button("إضافة رابط خارجي") { vm.addLinkTapped() }
                        Button("إضافة عيّنة تجريبية") { vm.addSampleTapped() }
                        Divider()
                        Button("إصلاح التواريخ") { vm.fixTimestampsTapped() }
                        Button("مسح الكاش") { vm.clearCacheTapped() }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                }
            }
        }
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .alert(item: Binding(
            get: { vm.alertMsg.map { AlertItem(message: $0) } },
            set: { _ in vm.alertMsg = nil }
        )) { item in
            Alert(title: Text(item.message))
        }
        .sheet(isPresented: $vm.showPreview) {
            if let url = vm.previewURL { QuickLookPreview(url: url).ignoresSafeArea() }
        }
        .sheet(isPresented: $vm.showSafari) {
            if let u = vm.safariURL { SafariView(url: u).ignoresSafeArea() }
        }
        .sheet(isPresented: $vm.showDocPicker) {
            PDFDocumentPicker { pickedURL in vm.handlePicked(pickedURL) }
        }
        .sheet(isPresented: $vm.showAddLink) {
            NavigationStack {
                Form {
                    Section("العنوان") {
                        TextField("مثال: تعليمات الطوارئ", text: $vm.newLinkTitle)
                    }
                    Section("الرابط") {
                        TextField("https://...", text: $vm.newLinkURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Section(footer: Text("لو الرابط ليس PDF مباشر، سيفتح في Safari تلقائيًا.")) { EmptyView() }
                }
                .navigationTitle("إضافة رابط")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("إلغاء") { vm.showAddLink = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("حفظ") { vm.confirmAddLink() }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 12) {
            List {
                if vm.filteredItems.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("اضغطي زر “+” لإضافة ملف أو رابط")
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(vm.filteredItems) { doc in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(doc.type.color.opacity(0.18))
                                    .frame(width: 42, height: 42)
                                Image(systemName: doc.type.icon)
                                    .foregroundStyle(doc.type.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.title).font(.headline)
                                HStack(spacing: 8) {
                                    Text(doc.type.rawValue.uppercased())
                                    if let size = doc.size { Text("• \(formatBytes(size))") }
                                    if let date = doc.updatedAt { Text("• \(relative(date))") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if doc.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { vm.open(doc) }
                        .contextMenu {
                            if let s = doc.downloadURL, !s.isEmpty {
                                Button { UIPasteboard.general.string = s } label: {
                                    Label("نسخ الرابط", systemImage: "link")
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { vm.deleteTapped(doc) } label: {
                                Label("حذف", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
        }
        .searchable(text: $vm.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text("ابحث في الملفات…"))
        .overlay {
            if vm.showHUD || vm.isUploading {
                VStack(spacing: 8) {
                    if vm.isUploading {
                        ProgressView(value: vm.uploadProgress)
                        Text("جارٍ رفع الملف… \(Int(vm.uploadProgress * 100))%")
                            .font(.footnote)
                    } else {
                        ProgressView()
                        Text("جارٍ المعالجة…").font(.footnote)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.top, 4)
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return "\(Int(kb)) KB" }
        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }

    private func relative(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

final class QLItem: NSObject, QLPreviewItem {
    let url: URL
    init(_ url: URL) { self.url = url }
    var previewItemURL: URL? { url }
}
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController(); c.dataSource = context.coordinator; return c
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url) }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let item: QLItem
        init(_ url: URL) { self.item = QLItem(url) }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { item }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct PDFDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf]
        let c = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        c.allowsMultipleSelection = false
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

private struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
