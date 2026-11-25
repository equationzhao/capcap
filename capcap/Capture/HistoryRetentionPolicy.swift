import Foundation

enum HistoryRetentionPolicy {
    static let mediaExtensions: Set<String> = ["png", "gif", "mp4"]

    private struct StoredFile {
        let url: URL
        let modificationDate: Date
    }

    @discardableResult
    static func pruneMedia(in directory: URL, limit: Int) -> Int {
        let files = storedFiles(in: directory, allowedExtensions: mediaExtensions)
            .filter { !HistoryManager.isFavorite(url: $0.url) }
            .sorted(by: newestFirst)
        return remove(files.dropFirst(max(0, limit)).map(\.url))
    }

    private static func storedFiles(in directory: URL, allowedExtensions: Set<String>) -> [StoredFile] {
        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .isRegularFileKey,
        ]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard allowedExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isRegularFile != false else { return nil }
            return StoredFile(
                url: url,
                modificationDate: values?.contentModificationDate ?? .distantPast
            )
        }
    }

    private static func newestFirst(_ lhs: StoredFile, _ rhs: StoredFile) -> Bool {
        if lhs.modificationDate != rhs.modificationDate {
            return lhs.modificationDate > rhs.modificationDate
        }
        return lhs.url.lastPathComponent > rhs.url.lastPathComponent
    }

    private static func remove(_ urls: [URL]) -> Int {
        var removedCount = 0
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
                removedCount += 1
            } catch {
                continue
            }
        }
        return removedCount
    }
}
