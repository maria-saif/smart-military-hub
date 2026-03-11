import Foundation
import FirebaseStorage

enum StorageHelper {
    static func reference(from stored: String) -> StorageReference {
        let s = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("gs://") || s.hasPrefix("https://") {
            return Storage.storage().reference(forURL: s)
        } else {
            return Storage.storage().reference().child(s)
        }
    }

    static func upload(data: Data, to path: String, contentType: String? = nil) async throws -> URL {
        let ref = Storage.storage().reference().child(path)
        let meta = StorageMetadata()
        meta.contentType = contentType
        _ = try await ref.putDataAsync(data, metadata: meta)
        return try await ref.downloadURL()
    }

    static func downloadURL(from stored: String) async throws -> URL {
        let ref = reference(from: stored)
        return try await ref.downloadURL()
    }
}
