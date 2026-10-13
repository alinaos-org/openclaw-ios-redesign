import Foundation
import OpenClawProtocol

// SIMPLE-UI: Sample automations for screenshot and App Review demo modes,
// which have no gateway to list them. Kept apart from files that import
// OpenClawKit so `AnyCodable` resolves to one type.

/// Stand-in automations for screenshot and App Review demo modes, built the
/// way upstream's tests build `CronJob`. Next runs are relative to now so the
/// Upcoming tab always reads "Today", "Tomorrow", or a weekday.
enum SimpleAutomationsSample {
    static var jobs: [CronJob] {
        let calendar = Calendar.current
        let now = Date()
        let tomorrowMorning = calendar.date(
            bySettingHour: 7,
            minute: 30,
            second: 0,
            of: calendar.date(byAdding: .day, value: 1, to: now) ?? now) ?? now
        let nextSunday = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 18, minute: 0, weekday: 1),
            matchingPolicy: .nextTime) ?? now
        return [
            self.job(
                id: "sample-morning-briefing",
                name: "Morning briefing",
                description: "Calendar, reminders, and weather before 8 AM.",
                nextRun: tomorrowMorning),
            self.job(
                id: "sample-flight-watch",
                name: "Watch Lisbon flight prices",
                description: "Checks fares for the May trip and tells you when they drop.",
                nextRun: now.addingTimeInterval(3 * 3600)),
            self.job(
                id: "sample-backup-check",
                name: "Weekly backup check",
                description: "Makes sure Time Machine ran this week.",
                nextRun: nextSunday),
            self.job(
                id: "sample-health-summary",
                name: "Sunday health summary",
                description: "Sleep, steps, and workouts for the week.",
                nextRun: nil,
                enabled: false),
        ]
    }

    private static func job(
        id: String,
        name: String,
        description: String,
        nextRun: Date?,
        enabled: Bool = true) -> CronJob
    {
        let created = Int(Date().timeIntervalSince1970 * 1000) - 14 * 86_400_000
        return CronJob(
            id: id,
            name: name,
            description: description,
            enabled: enabled,
            createdatms: created,
            updatedatms: created,
            schedule: AnyCodable(["kind": AnyCodable("every")]),
            sessiontarget: AnyCodable("isolated"),
            wakemode: AnyCodable("now"),
            payload: AnyCodable(["kind": AnyCodable("agentTurn")]),
            state: [:],
            nextrunatms: nextRun.map { Int($0.timeIntervalSince1970 * 1000) },
            lastrunstatus: AnyCodable("ok"))
    }
}
