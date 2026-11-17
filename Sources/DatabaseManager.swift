import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite persistence manager for MacTimer application sessions.
/// Stores data at ~/Library/Application Support/MacTimer/mactimer.sqlite
final class SessionDatabase: @unchecked Sendable {

    static let shared = SessionDatabase()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.vijay.mactimer.database", qos: .userInitiated)

    let databaseURL: URL

    init(customURL: URL? = nil) {
        if let customURL = customURL {
            self.databaseURL = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("MacTimer", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.databaseURL = dir.appendingPathComponent("mactimer.sqlite")
        }

        openDatabase()
        createTables()
        migrateFromJSONIfNeeded()
    }

    deinit {
        closeDatabase()
    }

    // ── Database Lifecycle ──────────────────────────────────────────────────

    private func openDatabase() {
        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(databaseURL.path, &dbPointer, flags, nil) == SQLITE_OK {
            self.db = dbPointer
            // Enable Write-Ahead Logging (WAL) for fast concurrent reads & writes
            sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", nil, nil, nil)
        } else {
            let errorMsg = dbPointer != nil ? String(cString: sqlite3_errmsg(dbPointer)) : "Unknown error"
            print("[SessionDatabase] Failed to open database at \(databaseURL.path): \(errorMsg)")
        }
    }

    private func closeDatabase() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_name TEXT NOT NULL,
            bundle_id TEXT NOT NULL,
            domain TEXT,
            page_title TEXT,
            start_time REAL NOT NULL,
            end_time REAL NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON sessions(start_time);
        CREATE INDEX IF NOT EXISTS idx_sessions_end_time ON sessions(end_time);
        CREATE INDEX IF NOT EXISTS idx_sessions_bundle ON sessions(bundle_id);
        """
        queue.sync {
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                let errorMsg = db != nil ? String(cString: sqlite3_errmsg(db)) : ""
                print("[SessionDatabase] Failed to create tables: \(errorMsg)")
            }
        }
    }

    // ── Writes ──────────────────────────────────────────────────────────────

    /// Inserts a single finished session
    func insert(session: AppSession) {
        guard let endTime = session.endTime else { return }
        queue.sync {
            let sql = "INSERT INTO sessions (app_name, bundle_id, domain, page_title, start_time, end_time) VALUES (?, ?, ?, ?, ?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (session.appName as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, (session.bundleIdentifier as NSString).utf8String, -1, SQLITE_TRANSIENT)

            if let domain = session.domain {
                sqlite3_bind_text(stmt, 3, (domain as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 3)
            }

            if let title = session.pageTitle {
                sqlite3_bind_text(stmt, 4, (title as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }

            sqlite3_bind_double(stmt, 5, session.startTime.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 6, endTime.timeIntervalSince1970)

            if sqlite3_step(stmt) != SQLITE_DONE {
                let err = String(cString: sqlite3_errmsg(db))
                print("[SessionDatabase] Insert failed: \(err)")
            }
        }
    }

    /// Bulk inserts sessions inside a single transaction (used for migration)
    func insertBatch(sessions: [AppSession]) {
        guard !sessions.isEmpty else { return }
        queue.sync {
            sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)

            let sql = "INSERT INTO sessions (app_name, bundle_id, domain, page_title, start_time, end_time) VALUES (?, ?, ?, ?, ?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                return
            }
            defer { sqlite3_finalize(stmt) }

            for session in sessions {
                let endTime = session.endTime ?? session.startTime
                sqlite3_reset(stmt)

                sqlite3_bind_text(stmt, 1, (session.appName as NSString).utf8String, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, (session.bundleIdentifier as NSString).utf8String, -1, SQLITE_TRANSIENT)

                if let domain = session.domain {
                    sqlite3_bind_text(stmt, 3, (domain as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(stmt, 3)
                }

                if let title = session.pageTitle {
                    sqlite3_bind_text(stmt, 4, (title as NSString).utf8String, -1, SQLITE_TRANSIENT)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }

                sqlite3_bind_double(stmt, 5, session.startTime.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 6, endTime.timeIntervalSince1970)

                _ = sqlite3_step(stmt)
            }

            sqlite3_exec(db, "COMMIT;", nil, nil, nil)
        }
    }

    // ── Queries ─────────────────────────────────────────────────────────────

    /// Fetches all sessions overlapping with [startDate, endDate]
    func fetchSessions(from startDate: Date, to endDate: Date) -> [AppSession] {
        return queue.sync {
            var results: [AppSession] = []
            let sql = """
            SELECT app_name, bundle_id, domain, page_title, start_time, end_time
            FROM sessions
            WHERE start_time < ? AND end_time >= ?
            ORDER BY start_time ASC;
            """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_double(stmt, 1, endDate.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 2, startDate.timeIntervalSince1970)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let appName = String(cString: sqlite3_column_text(stmt, 0))
                let bundleId = String(cString: sqlite3_column_text(stmt, 1))

                let domain: String? = sqlite3_column_type(stmt, 2) != SQLITE_NULL
                    ? String(cString: sqlite3_column_text(stmt, 2))
                    : nil

                let pageTitle: String? = sqlite3_column_type(stmt, 3) != SQLITE_NULL
                    ? String(cString: sqlite3_column_text(stmt, 3))
                    : nil

                let startTime = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
                let endTime = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))

                results.append(AppSession(
                    appName: appName,
                    bundleIdentifier: bundleId,
                    domain: domain,
                    pageTitle: pageTitle,
                    startTime: startTime,
                    endTime: endTime
                ))
            }

            return results
        }
    }

    /// Total count of stored sessions
    func totalCount() -> Int {
        return queue.sync {
            let sql = "SELECT COUNT(*) FROM sessions;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }

            if sqlite3_step(stmt) == SQLITE_ROW {
                return Int(sqlite3_column_int64(stmt, 0))
            }
            return 0
        }
    }

    /// Clears all stored sessions
    func clearAll() {
        queue.sync {
            sqlite3_exec(db, "DELETE FROM sessions;", nil, nil, nil)
            sqlite3_exec(db, "VACUUM;", nil, nil, nil)
        }
    }

    // ── Migration from JSON ─────────────────────────────────────────────────

    private func migrateFromJSONIfNeeded() {
        let migrationKey = "didMigrateToSQLite"
        let home = FileManager.default.homeDirectoryForCurrentUser
        let oldLogURL = home.appendingPathComponent("MacTimer-log.json")

        guard FileManager.default.fileExists(atPath: oldLogURL.path) else { return }

        // If migration already completed previously, nothing to do
        if UserDefaults.standard.bool(forKey: migrationKey) && totalCount() > 0 {
            return
        }

        print("[SessionDatabase] Found existing ~/MacTimer-log.json. Starting migration to SQLite...")

        guard let data = try? Data(contentsOf: oldLogURL) else {
            print("[SessionDatabase] Failed to read ~/MacTimer-log.json for migration.")
            return
        }

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        guard let sessions = try? dec.decode([AppSession].self, from: data) else {
            print("[SessionDatabase] Failed to decode sessions from ~/MacTimer-log.json.")
            return
        }

        insertBatch(sessions: sessions)
        print("[SessionDatabase] Migrated \(sessions.count) sessions into SQLite database.")

        // Rename original file to .backup
        let backupURL = home.appendingPathComponent("MacTimer-log.json.backup")
        try? FileManager.default.removeItem(at: backupURL)
        do {
            try FileManager.default.moveItem(at: oldLogURL, to: backupURL)
            print("[SessionDatabase] Archived original JSON to \(backupURL.path)")
        } catch {
            print("[SessionDatabase] Could not rename original JSON: \(error)")
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
