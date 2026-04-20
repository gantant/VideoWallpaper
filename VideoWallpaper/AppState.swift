import SwiftUI
import Combine

final class WallpaperViewModel: ObservableObject {
    @Published var wallpaperImage: UIImage?
    
    func loadWallpaper() {
        // Implement wallpaper loading logic here
    }
}

final class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var wallpaperViewModel = WallpaperViewModel()
    
    private init() { }
}
