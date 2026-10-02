/// Names and glyphs for popular apps and the iOS system services that show
/// up in captured traffic, so they're named right away and without a
/// network lookup. App Store listings fill in icons, and names for
/// everything not listed here.
public enum KnownApps {
    /// The well-known app with this bundle identifier, if any. Matching
    /// ignores case; the returned app keeps `bundleIdentifier` as given.
    public static func app(bundleIdentifier: String) -> SourceApp? {
        guard let entry = entries[bundleIdentifier.lowercased()] else { return nil }
        return SourceApp(bundleIdentifier: bundleIdentifier, displayName: entry.name, symbolName: entry.symbol)
    }

    /// Keyed by lowercased bundle identifier.
    private static let entries: [String: (name: String, symbol: String)] = [
        // Popular apps
        "net.whatsapp.whatsapp": ("WhatsApp", "bubble.left.and.bubble.right.fill"),
        "net.whatsapp.whatsappsmb": ("WhatsApp Business", "briefcase.fill"),
        "com.burbn.instagram": ("Instagram", "camera.fill"),
        "com.burbn.barcelona": ("Threads", "at"),
        "com.facebook.facebook": ("Facebook", "person.2.fill"),
        "com.facebook.messenger": ("Messenger", "message.fill"),
        "com.zhiliaoapp.musically": ("TikTok", "music.note"),
        "com.toyopagroup.picaboo": ("Snapchat", "camera.viewfinder"),
        "ph.telegra.telegraph": ("Telegram", "paperplane.fill"),
        "org.whispersystems.signal": ("Signal", "lock.fill"),
        "com.atebits.tweetie2": ("X", "text.bubble.fill"),
        "com.google.ios.youtube": ("YouTube", "play.rectangle.fill"),
        "com.google.gmail": ("Gmail", "envelope.fill"),
        "com.google.googlemobile": ("Google", "magnifyingglass"),
        "com.google.chrome.ios": ("Chrome", "globe"),
        "com.google.maps": ("Google Maps", "map.fill"),
        "com.spotify.client": ("Spotify", "music.note"),
        "com.netflix.netflix": ("Netflix", "tv.fill"),
        "com.hammerandchisel.discord": ("Discord", "gamecontroller.fill"),
        "com.reddit.reddit": ("Reddit", "text.bubble.fill"),
        "com.linkedin.linkedin": ("LinkedIn", "briefcase.fill"),
        "pinterest": ("Pinterest", "pin.fill"),
        "com.ubercab.uberclient": ("Uber", "car.fill"),
        "com.amazon.amazon": ("Amazon", "cart.fill"),
        "us.zoom.videomeetings": ("Zoom", "video.fill"),
        "com.tinyspeck.chatlyio": ("Slack", "number"),
        "com.microsoft.skype.teams": ("Microsoft Teams", "person.3.fill"),
        "com.microsoft.office.outlook": ("Outlook", "envelope.fill"),
        "com.viber": ("Viber", "phone.fill"),
        "com.yourcompany.ppclient": ("PayPal", "creditcard.fill"),
        "com.omarkar.networkinspector": ("Network Inspector", "network"),

        // Apple apps
        "com.apple.mobilesafari": ("Safari", "safari.fill"),
        "com.apple.mobilemail": ("Mail", "envelope.fill"),
        "com.apple.mobilesms": ("Messages", "message.fill"),
        "com.apple.facetime": ("FaceTime", "video.fill"),
        "com.apple.mobilephone": ("Phone", "phone.fill"),
        "com.apple.maps": ("Maps", "map.fill"),
        "com.apple.appstore": ("App Store", "bag.fill"),
        "com.apple.music": ("Music", "music.note"),
        "com.apple.podcasts": ("Podcasts", "antenna.radiowaves.left.and.right"),
        "com.apple.mobileslideshow": ("Photos", "photo.fill"),
        "com.apple.weather": ("Weather", "cloud.sun.fill"),
        "com.apple.news": ("News", "newspaper.fill"),
        "com.apple.tv": ("TV", "tv.fill"),
        "com.apple.preferences": ("Settings", "gearshape.fill"),
        "com.apple.mobilenotes": ("Notes", "note.text"),
        "com.apple.mobilecal": ("Calendar", "calendar"),
        "com.apple.health": ("Health", "heart.fill"),
        "com.apple.passbook": ("Wallet", "wallet.pass.fill"),
        "com.apple.documentsapp": ("Files", "folder.fill"),
        "com.apple.stocks": ("Stocks", "chart.line.uptrend.xyaxis"),
        "com.apple.findmy": ("Find My", "location.fill"),
        "com.apple.shortcuts": ("Shortcuts", "square.stack.3d.up.fill"),
        "com.apple.testflight": ("TestFlight", "airplane"),

        // iOS system services
        "com.apple.nsurlsessiond": ("Background Transfers", "arrow.up.arrow.down.circle.fill"),
        "com.apple.apsd": ("Push Notifications", "bell.badge.fill"),
        "com.apple.mdnsresponder": ("DNS", "network"),
        "com.apple.identityservicesd": ("iMessage & FaceTime Service", "message.fill"),
        "com.apple.cloudd": ("iCloud", "icloud.fill"),
        "com.apple.bird": ("iCloud Drive", "icloud.fill"),
        "com.apple.appstored": ("App Store Downloads", "arrow.down.circle.fill"),
        "com.apple.softwareupdateservicesd": ("Software Update", "arrow.triangle.2.circlepath"),
        "com.apple.mobileassetd": ("System Downloads", "arrow.down.circle.fill"),
        "com.apple.trustd": ("Certificate Checks", "checkmark.shield.fill"),
        "com.apple.geod": ("Maps & Location Data", "location.fill"),
        "com.apple.locationd": ("Location Services", "location.fill"),
        "com.apple.timed": ("Time Sync", "clock.fill"),
        "com.apple.assistantd": ("Siri", "waveform"),
        "com.apple.parsecd": ("Siri Suggestions", "sparkles"),
        "com.apple.dataaccess.dataaccessd": ("Mail & Calendar Sync", "arrow.triangle.2.circlepath"),
        "com.apple.webkit.networking": ("Web Content", "globe")
    ]
}
