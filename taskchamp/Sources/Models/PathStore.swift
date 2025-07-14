import os.log
import SwiftUI

@Observable
class PathStore {
    var path: NavigationPath
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "PathStore")

    private let savePath = URL.documentsDirectory.appending(path: "SavedPath")

    init() {
        if let data = try? Data(contentsOf: savePath) {
            if let decoded = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) {
                path = NavigationPath(decoded)
                return
            }
        }
        path = NavigationPath()
    }

    func save() {
        guard let representation = path.codable else { return }

        do {
            let data = try JSONEncoder().encode(representation)
            try data.write(to: savePath)
        } catch {
            logger.error("Failed to save navigation data: \(error.localizedDescription)")
        }
    }

    func goHome() {
        path = NavigationPath()
    }
}
