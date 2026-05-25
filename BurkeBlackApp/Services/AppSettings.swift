import Foundation
import SwiftUI

// MARK: - Centralized App Settings
//
// All user-facing settings live here with explicit, namespaced keys.
// This prevents:
//   - Typo'd @AppStorage keys across multiple files
//   - Accidental key collisions
//   - Settings that silently reset (using @State instead of persistence)
//   - Breaking user settings when refactoring
//
// To add a new setting:
//   1. Add a static let key in Keys
//   2. Add an @AppStorage property below
//   3. Use AppSettings.shared.propertyName in your view

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Keys (namespaced to avoid collisions)

    private enum Keys {
        // Giveaways
        static let giveawayPopupsEnabled = "settings.giveaways.popupsEnabled"

        // Notification toggles
        static let notifBurkeStreamEnabled = "settings.notif.burkeStream.enabled"
        static let notifBurkeStreamAllDay = "settings.notif.burkeStream.allDay"
        static let notifBurkeStreamDays = "settings.notif.burkeStream.days"
        static let notifBurkeStreamFromHour = "settings.notif.burkeStream.fromHour"
        static let notifBurkeStreamFromMinute = "settings.notif.burkeStream.fromMinute"
        static let notifBurkeStreamToHour = "settings.notif.burkeStream.toHour"
        static let notifBurkeStreamToMinute = "settings.notif.burkeStream.toMinute"

        static let notifBurke40kEnabled = "settings.notif.burke40k.enabled"
        static let notifBurke40kAllDay = "settings.notif.burke40k.allDay"
        static let notifBurke40kDays = "settings.notif.burke40k.days"
        static let notifBurke40kFromHour = "settings.notif.burke40k.fromHour"
        static let notifBurke40kFromMinute = "settings.notif.burke40k.fromMinute"
        static let notifBurke40kToHour = "settings.notif.burke40k.toHour"
        static let notifBurke40kToMinute = "settings.notif.burke40k.toMinute"

        static let notifBurkeAnnouncements = "settings.notif.burkeAnnouncements"
        static let notifModAnnouncements = "settings.notif.modAnnouncements"
        static let notifSpecialEvents = "settings.notif.specialEvents"
        static let notifTidings = "settings.notif.tidings"

        // Debug
        static let debugShowCaptainsDispatch = "settings.debug.showCaptainsDispatch"
        static let debugOverrideInteractionsDisabled = "settings.debug.overrideInteractionsDisabled"
        static let debugUseTestOverlay = "settings.debug.useTestOverlay"

        // Social media notifications
        static let notifYoutubeVideos = "settings.notif.youtubeVideos"
        static let notifYoutubeShorts = "settings.notif.youtubeShorts"
        static let notifTiktokVideos = "settings.notif.tiktokVideos"
        static let notifTwitterPosts = "settings.notif.twitterPosts"

        // UI
        static let presentationMode = "settings.ui.presentationMode"
        static let pirateThemeEnabled = "settings.ui.pirateTheme"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Giveaways

    @AppStorage(Keys.giveawayPopupsEnabled)
    var giveawayPopupsEnabled: Bool = true

    // MARK: - Notification Toggles

    @AppStorage(Keys.notifBurkeAnnouncements)
    var burkeAnnouncements: Bool = true

    @AppStorage(Keys.notifModAnnouncements)
    var modAnnouncements: Bool = true

    @AppStorage(Keys.notifSpecialEvents)
    var specialEvents: Bool = true

    @AppStorage(Keys.notifTidings)
    var tidings: Bool = true

    @AppStorage(Keys.notifYoutubeVideos)
    var youtubeVideos: Bool = true

    @AppStorage(Keys.notifYoutubeShorts)
    var youtubeShorts: Bool = true

    @AppStorage(Keys.notifTiktokVideos)
    var tiktokVideos: Bool = true

    @AppStorage(Keys.notifTwitterPosts)
    var twitterPosts: Bool = true

    // MARK: - Appearance

    @AppStorage(Keys.pirateThemeEnabled)
    var pirateThemeEnabled: Bool = true

    // MARK: - UI

    @AppStorage(Keys.presentationMode)
    var presentationMode: Bool = false

    // MARK: - Debug

    @AppStorage(Keys.debugShowCaptainsDispatch)
    var debugShowCaptainsDispatch: Bool = false

    @AppStorage(Keys.debugOverrideInteractionsDisabled)
    var debugOverrideInteractionsDisabled: Bool = false

    @AppStorage(Keys.debugUseTestOverlay)
    var debugUseTestOverlay: Bool = false

    // MARK: - Stream Schedules

    // Burke stream schedule
    @AppStorage(Keys.notifBurkeStreamEnabled)
    var burkeStreamEnabled: Bool = true

    @AppStorage(Keys.notifBurkeStreamAllDay)
    var burkeStreamAllDay: Bool = true

    var burkeStreamDays: Set<Int> {
        get { loadIntSet(key: Keys.notifBurkeStreamDays, defaultValue: Set(0...6)) }
        set { saveIntSet(key: Keys.notifBurkeStreamDays, value: newValue); objectWillChange.send() }
    }

    @AppStorage(Keys.notifBurkeStreamFromHour)
    var burkeStreamFromHour: Int = 9

    @AppStorage(Keys.notifBurkeStreamFromMinute)
    var burkeStreamFromMinute: Int = 0

    @AppStorage(Keys.notifBurkeStreamToHour)
    var burkeStreamToHour: Int = 23

    @AppStorage(Keys.notifBurkeStreamToMinute)
    var burkeStreamToMinute: Int = 0

    // Burke40k stream schedule
    @AppStorage(Keys.notifBurke40kEnabled)
    var burke40kEnabled: Bool = true

    @AppStorage(Keys.notifBurke40kAllDay)
    var burke40kAllDay: Bool = true

    var burke40kDays: Set<Int> {
        get { loadIntSet(key: Keys.notifBurke40kDays, defaultValue: Set(0...6)) }
        set { saveIntSet(key: Keys.notifBurke40kDays, value: newValue); objectWillChange.send() }
    }

    @AppStorage(Keys.notifBurke40kFromHour)
    var burke40kFromHour: Int = 9

    @AppStorage(Keys.notifBurke40kFromMinute)
    var burke40kFromMinute: Int = 0

    @AppStorage(Keys.notifBurke40kToHour)
    var burke40kToHour: Int = 23

    @AppStorage(Keys.notifBurke40kToMinute)
    var burke40kToMinute: Int = 0

    // MARK: - Helpers

    private func loadIntSet(key: String, defaultValue: Set<Int>) -> Set<Int> {
        guard let array = defaults.array(forKey: key) as? [Int] else { return defaultValue }
        return Set(array)
    }

    private func saveIntSet(key: String, value: Set<Int>) {
        defaults.set(Array(value), forKey: key)
    }
}

// MARK: - Migration from legacy keys

extension AppSettings {
    /// Call once at app launch to migrate any old keys to the new namespaced format.
    func migrateIfNeeded() {
        let migrated = "settings.migration.v1.complete"
        guard !defaults.bool(forKey: migrated) else { return }

        // Migrate old giveaway key
        if defaults.object(forKey: "giveawayPopupsEnabled") != nil {
            giveawayPopupsEnabled = defaults.bool(forKey: "giveawayPopupsEnabled")
            defaults.removeObject(forKey: "giveawayPopupsEnabled")
            appLog("Settings: migrated giveawayPopupsEnabled")
        }

        defaults.set(true, forKey: migrated)
        appLog("Settings: migration v1 complete")
    }

    /// Migrate youtubeVODs → youtubeShorts for users upgrading from older versions
    func migrateV2IfNeeded() {
        let migrated = "settings.migration.v2.complete"
        guard !defaults.bool(forKey: migrated) else { return }

        let oldKey = "settings.notif.youtubeVODs"
        if defaults.object(forKey: oldKey) != nil {
            youtubeShorts = defaults.bool(forKey: oldKey)
            defaults.removeObject(forKey: oldKey)
            appLog("Settings: migrated youtubeVODs → youtubeShorts")
        }

        defaults.set(true, forKey: migrated)
        appLog("Settings: migration v2 complete")
    }
}
