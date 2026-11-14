import Foundation
@testable import MoonbaseAcademy

/// The science package ships in the app bundle; hosted tests reach it through the app's main bundle.
final class AppBundleMarker {
    static var bundle: Bundle { Bundle.main }
}
