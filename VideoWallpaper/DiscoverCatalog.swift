import Foundation

struct WallpaperItem: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let genre: String
    let sourceName: String
    let sourcePageURL: String
    let videoURL: String
    let thumbURL: String
    let tags: [String]

    var isAvailable: Bool { !videoURL.isEmpty }
}

enum DiscoverCatalog {
    static let categories: [String] = [
        "Featured", "Nature", "City", "Cyberpunk", "Space", "Water", "Abstract", "Anime"
    ]

    // Curated from commonly recommended wallpaper genres and free sources.
    static let items: [WallpaperItem] = [
        WallpaperItem(
            id: "abstract-1",
            name: "Abstract 1",
            category: "Abstract",
            genre: "Ambient Abstract",
            sourceName: "Pexels",
            sourcePageURL: "https://www.pexels.com/videos/",
            videoURL: "https://www.pexels.com/download/video/28561594/",
            thumbURL: "https://images.pexels.com/videos/28561594/3d-rendering-abstract-ai-animation-28561594.jpeg",
            tags: ["abstract", "glow", "ambient", "loop"]
        ),
        WallpaperItem(
            id: "abstract-2",
            name: "Abstract 2",
            category: "Abstract",
            genre: "Neon",
            sourceName: "Pexels",
            sourcePageURL: "https://www.pexels.com/videos/",
            videoURL: "https://www.pexels.com/download/video/32399542/",
            thumbURL: "https://intelloai.com/hero-intello-poster.jpg",
            tags: ["abstract", "neon", "3d", "loop", "synthwave"]
        ),
        WallpaperItem(
            id: "abstract-3",
            name: "Abstract 3",
            category: "Abstract",
            genre: "Neon",
            sourceName: "Pexels",
            sourcePageURL: "https://www.pexels.com/videos/",
            videoURL: "https://www.pexels.com/download/video/30090680/",
            thumbURL: "https://images.pexels.com/videos/30090680/pexels-photo-30090680.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
            tags: ["neon", "3d", "loop", "synthwave"]
        ),
        WallpaperItem(
            id: "abstract-4",
            name: "Abstract 4",
            category: "Abstract",
            genre: "Neon",
            sourceName: "Pexels",
            sourcePageURL: "https://www.pexels.com/videos/",
            videoURL: "https://www.pexels.com/download/video/29460403/",
            thumbURL: "https://images.pexels.com/videos/29460403/3d-abstract-architecture-background-29460403.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
            tags: ["city", "night", "rain", "lofi"]
        ),
        WallpaperItem(
            id: "abstract-5",
            name: "Abstract 5",
            category: "Abstract",
            genre: "Abstract",
            sourceName: "Pexels",
            sourcePageURL: "https://www.pexels.com/videos/",
            videoURL: "https://www.pexels.com/download/video/8733062/",
            thumbURL: "https://i.ytimg.com/vi/7DCY3faeJUc/maxresdefault.jpg",
            tags: ["forest", "waterfall", "nature", "green"]
        ),
        WallpaperItem(
            id: "nature-cloudscape",
            name: "Cloudscape",
            category: "Nature",
            genre: "Sky",
            sourceName: "Coverr",
            sourcePageURL: "https://coverr.co/search?q=clouds",
            videoURL: "",
            thumbURL: "https://images.pexels.com/photos/355465/pexels-photo-355465.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
            tags: ["clouds", "sky", "calm"]
        ),
        WallpaperItem(
            id: "water-ocean-swell",
            name: "Ocean Swell",
            category: "Water",
            genre: "Ocean",
            sourceName: "Mixkit",
            sourcePageURL: "https://mixkit.co/free-stock-video/ocean/",
            videoURL: "",
            thumbURL: "https://images.pexels.com/photos/1001682/pexels-photo-1001682.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
            tags: ["ocean", "water", "waves", "blue"]
        ),
        WallpaperItem(
            id: "water-river-drone",
            name: "River Drift",
            category: "Water",
            genre: "River",
            sourceName: "Pexels",
            sourcePageURL: "https://www.pexels.com/search/videos/river/",
            videoURL: "",
            thumbURL: "https://images.pexels.com/photos/460621/pexels-photo-460621.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
            tags: ["river", "drone", "calm", "nature"]
        ),
        WallpaperItem(
            id: "space-iss-window",
            name: "ISS Earth Window",
            category: "Space",
            genre: "Space",
            sourceName: "NASA",
            sourcePageURL: "https://www.nasa.gov/international-space-station/desktop-and-mobile-wallpapers/",
            videoURL: "",
            thumbURL: "https://www.nasa.gov/wp-content/uploads/2023/03/iss067e174905.jpg",
            tags: ["space", "earth", "nasa", "orbit"]
        ),
        WallpaperItem(
            id: "space-deep-stars",
            name: "Deep Space Drift",
            category: "Space",
            genre: "Sci-Fi",
            sourceName: "Pexels",
            sourcePageURL: "https://www.pexels.com/search/videos/space/",
            videoURL: "",
            thumbURL: "https://images.pexels.com/photos/1169754/pexels-photo-1169754.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
            tags: ["space", "stars", "dark", "sci-fi"]
        ),
        WallpaperItem(
            id: "cyberpunk-neon-alley",
            name: "Neon Alley",
            category: "Cyberpunk",
            genre: "Cyberpunk",
            sourceName: "Wallpaper Engine Trends",
            sourcePageURL: "https://steamcommunity.com/workshop/browse/?appid=431960&requiredtags%5B%5D=Cyberpunk&section=readytouseitems",
            videoURL: "",
            thumbURL: "https://images.pexels.com/photos/316902/pexels-photo-316902.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
            tags: ["cyberpunk", "neon", "city", "night"]
        ),
        WallpaperItem(
            id: "anime-cyber-city",
            name: "Anime Neon City",
            category: "Anime",
            genre: "Anime",
            sourceName: "DesktopHut",
            sourcePageURL: "https://www.desktophut.com/4K-PC-Anime-Girl-In-Cyberpunk-City-Live-Wallpaper",
            videoURL: "",
            thumbURL: "https://i.ytimg.com/vi/7DCY3faeJUc/maxresdefault.jpg",
            tags: ["anime", "cyberpunk", "girl", "city"]
        ),
        WallpaperItem(
            id: "featured-lush-nature",
            name: "Lush Nature Loop",
            category: "Featured",
            genre: "Nature",
            sourceName: "Pexels",
            sourcePageURL: "https://www.pexels.com/videos/",
            videoURL: "",
            thumbURL: "https://images.pexels.com/photos/417173/pexels-photo-417173.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
            tags: ["featured", "nature", "calm"]
        ),
        WallpaperItem(
            id: "featured-neon-city",
            name: "Neon Commute",
            category: "Featured",
            genre: "Cyberpunk",
            sourceName: "Pexels",
            sourcePageURL: "https://www.pexels.com/search/videos/neon/",
            videoURL: "",
            thumbURL: "https://images.pexels.com/photos/1105766/pexels-photo-1105766.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
            tags: ["featured", "neon", "city", "night"]
        )
    ]
}
