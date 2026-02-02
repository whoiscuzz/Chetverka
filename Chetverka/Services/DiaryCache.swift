import Foundation

final class DiaryCache {
    
    private static func fileURL(for pupilid: String) -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Создаем уникальное имя файла для каждого пользователя
        return directory.appendingPathComponent("diary_\(pupilid).json")
    }
    
    func save(_ response: DiaryResponse, for pupilid: String) {
        do {
            let url = Self.fileURL(for: pupilid)
            let data = try JSONEncoder().encode(response)
            try data.write(to: url, options: .atomic)
            print("✅ Diary saved to cache for pupil \(pupilid).")
        } catch {
            print("❌ Failed to save diary to cache:", error)
        }
    }
    
    func load(for pupilid: String) -> DiaryResponse? {
        do {
            let url = Self.fileURL(for: pupilid)
            let data = try Data(contentsOf: url)
            let response = try JSONDecoder().decode(DiaryResponse.self, from: data)
            print("✅ Diary loaded from cache for pupil \(pupilid).")
            return response
        } catch {
            print("ℹ️ Could not load diary from cache for pupil \(pupilid):", error.localizedDescription)
            return nil
        }
    }
}
