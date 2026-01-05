import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

protocol DiaryStorage {
    func loadEntry(for dateKey: String) -> Data?
    func saveEntry(_ data: Data?, for dateKey: String)
    func allDateKeys() -> Set<String>
    func migrateFromUserDefaultsIfNeeded()
    func performBackup(retaining latestCount: Int)
}

final class SQLiteStorageService: DiaryStorage {
    static let shared = SQLiteStorageService()
    
    private let dbURL: URL
    private let backupDirectory: URL
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.jinodiary.storage", qos: .userInitiated)
    
    private init() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("JinoDiary", isDirectory: true)
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let backupDir = directory.appendingPathComponent("Backups", isDirectory: true)
        if !fm.fileExists(atPath: backupDir.path) {
            try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }
        self.dbURL = directory.appendingPathComponent("diary.sqlite")
        self.backupDirectory = backupDir
        openDatabase()
        createTableIfNeeded()
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    private func openDatabase() {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("Failed to open database at \(dbURL.path)")
            db = nil
        }
    }
    
    private func createTableIfNeeded() {
        let sql = """
        CREATE TABLE IF NOT EXISTS entries (
            date TEXT PRIMARY KEY,
            rtf_data BLOB,
            created_at REAL,
            updated_at REAL
        );
        """
        queue.sync {
            execute(sql: sql)
        }
    }
    
    func loadEntry(for dateKey: String) -> Data? {
        var result: Data?
        queue.sync {
            guard let db = db else { return }
            let query = "SELECT rtf_data FROM entries WHERE date = ? LIMIT 1;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, dateKey, -1, SQLITE_TRANSIENT)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let bytes = sqlite3_column_blob(stmt, 0) {
                        let length = Int(sqlite3_column_bytes(stmt, 0))
                        result = Data(bytes: bytes, count: length)
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        return result
    }
    
    func saveEntry(_ data: Data?, for dateKey: String) {
        queue.sync {
            guard let db = db else { return }
            if let data = data {
                let sql = "INSERT OR REPLACE INTO entries(date, rtf_data, created_at, updated_at) VALUES(?, ?, COALESCE((SELECT created_at FROM entries WHERE date = ?), strftime('%s','now')), strftime('%s','now'));"
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, dateKey, -1, SQLITE_TRANSIENT)
                    _ = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                        sqlite3_bind_blob(stmt, 2, ptr.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
                    }
                    sqlite3_bind_text(stmt, 3, dateKey, -1, SQLITE_TRANSIENT)
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            } else {
                let sql = "DELETE FROM entries WHERE date = ?;"
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, dateKey, -1, SQLITE_TRANSIENT)
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
        }
    }
    
    func allDateKeys() -> Set<String> {
        var dates: Set<String> = []
        queue.sync {
            guard let db = db else { return }
            let query = "SELECT date FROM entries;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let cString = sqlite3_column_text(stmt, 0) {
                        dates.insert(String(cString: cString))
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        return dates
    }

    func performBackup(retaining latestCount: Int = 3) {
        queue.async {
            let fm = FileManager.default
            guard fm.fileExists(atPath: self.dbURL.path) else { return }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let filename = "diary-\(formatter.string(from: Date())).sqlite"
            let destination = self.backupDirectory.appendingPathComponent(filename)
            do {
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.copyItem(at: self.dbURL, to: destination)
            } catch {
                print("Backup copy failed: \(error)")
            }
            // Trim old backups
            if let files = try? fm.contentsOfDirectory(at: self.backupDirectory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]) {
                let sorted = files.sorted { $0.lastPathComponent > $1.lastPathComponent } // timestamp in name sorts correctly
                if sorted.count > latestCount {
                    for url in sorted.suffix(from: latestCount) {
                        try? fm.removeItem(at: url)
                    }
                }
            }
        }
    }
    
    func migrateFromUserDefaultsIfNeeded() {
        let key = "dateTextMap"
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if loadAnyEntry() { // DB already has data, skip migration
            return
        }
        if let map = try? JSONDecoder().decode([String: Data].self, from: data) {
            for (dateKey, rtf) in map {
                saveEntry(rtf, for: dateKey)
            }
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        if let legacyMap = try? JSONDecoder().decode([String: String].self, from: data) {
            for (dateKey, plain) in legacyMap {
                let attributed = NSAttributedString(string: plain)
                if let rtf = try? attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                    saveEntry(rtf, for: dateKey)
                }
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    private func loadAnyEntry() -> Bool {
        var hasRow = false
        queue.sync {
            guard let db = db else { return }
            let query = "SELECT 1 FROM entries LIMIT 1;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                hasRow = sqlite3_step(stmt) == SQLITE_ROW
            }
            sqlite3_finalize(stmt)
        }
        return hasRow
    }
    
    private func execute(sql: String) {
        guard let db = db else { return }
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let err = errMsg { print("SQLite error: \(String(cString: err))") }
        }
        if let err = errMsg { sqlite3_free(err) }
    }
}
