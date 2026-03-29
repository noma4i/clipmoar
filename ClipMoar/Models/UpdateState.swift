import Foundation

enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String, notes: String, downloadURL: URL)
    case downloading(progress: Double)
    case installing
    case installed
    case error(String)
    case homebrewManaged
}

struct GitHubRelease: Decodable {
    let tagName: String
    let body: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case assets
    }
}

struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}
