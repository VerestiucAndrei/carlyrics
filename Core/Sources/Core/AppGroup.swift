import Foundation

public enum AppGroup {
    public static let fallbackID = "group.com.carlyrics"

    /// SideStore/AltStore rewrite bundle and app-group identifiers at sign time (team id suffix),
    /// so the id we compiled against is not the one we were entitled with. Read the real one
    /// from the provisioning profile embedded in this bundle (app and appex each carry their own).
    public static let id: String = entitledGroups(in: .main).first ?? fallbackID

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    public static func entitledGroups(in bundle: Bundle) -> [String] {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return [] }
        return groups(inProfile: data)
    }

    /// The profile is a CMS envelope around an XML plist; slicing on the plist tags is enough.
    public static func groups(inProfile data: Data) -> [String] {
        guard let start = data.range(of: Data("<plist".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.upperBound..<data.endIndex),
              let obj = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil),
              let ent = (obj as? [String: Any])?["Entitlements"] as? [String: Any]
        else { return [] }
        return ent["com.apple.security.application-groups"] as? [String] ?? []
    }
}
