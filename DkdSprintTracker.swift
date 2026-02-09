import Cocoa

// MARK: - Sprint Calculator

struct SprintInfo {
    let number: Int
    let startDate: Date       // Montag Woche 1
    let endDate: Date         // Freitag Woche 2
    let currentDay: Int       // Arbeitstag im Sprint (1-10)
    let totalDays: Int        // 10
    let isWeekend: Bool

    var weekInSprint: Int {
        return currentDay <= 5 ? 1 : 2
    }

    var progress: Double {
        return Double(currentDay) / Double(totalDays)
    }

    var remainingDays: Int {
        return totalDays - currentDay
    }
}

func firstMondayOfYear(_ year: Int) -> Date {
    let calendar = Calendar(identifier: .iso8601)
    // Erster Montag im Januar (KW2-Start, erster voller Arbeitsmontag)
    var components = DateComponents()
    components.year = year
    components.month = 1
    components.day = 1
    
    let jan1 = calendar.date(from: components)!
    let weekday = calendar.component(.weekday, from: jan1)
    
    // Tage bis zum nächsten Montag (weekday 2)
    // Wenn Jan 1 ein Montag ist → 0 Tage
    let daysToMonday = (9 - weekday) % 7
    // Falls Jan 1 selbst Montag ist, nehmen wir den
    let firstMonday = daysToMonday == 0 ? jan1 : calendar.date(byAdding: .day, value: daysToMonday, to: jan1)!
    
    return firstMonday
}

func workingDayInSprint(_ calendarDay: Int) -> (day: Int, isWeekend: Bool) {
    let week = calendarDay / 7      // 0 = Woche 1, 1 = Woche 2
    let dow = calendarDay % 7       // 0=Mo, 1=Di, ..., 4=Fr, 5=Sa, 6=So
    if dow >= 5 {
        return (day: week * 5 + 5, isWeekend: true)
    }
    return (day: week * 5 + dow + 1, isWeekend: false)
}

func calculateCurrentSprint() -> SprintInfo {
    let calendar = Calendar(identifier: .iso8601)
    let now = Date()

    let currentYear = calendar.component(.year, from: now)
    var sprintEpoch = firstMondayOfYear(currentYear)

    // Tage seit Sprint-Epoch dieses Jahres berechnen
    var daysSinceEpoch = calendar.dateComponents([.day], from: sprintEpoch, to: now).day ?? 0

    // Falls wir vor dem ersten Montag sind, vorheriges Jahr nehmen
    if daysSinceEpoch < 0 {
        sprintEpoch = firstMondayOfYear(currentYear - 1)
        daysSinceEpoch = calendar.dateComponents([.day], from: sprintEpoch, to: now).day ?? 0
    }

    // Sprint-Nummer (0-basiert, dann +1) — resettet jedes Jahr
    let sprintIndex = max(0, daysSinceEpoch / 14)
    let calendarDayInSprint = daysSinceEpoch % 14

    // Arbeitstag und Wochenend-Status berechnen
    let (workDay, isWeekend) = workingDayInSprint(calendarDayInSprint)

    // Start = Montag Woche 1, End = Freitag Woche 2
    let sprintStart = calendar.date(byAdding: .day, value: sprintIndex * 14, to: sprintEpoch)!
    let sprintEnd = calendar.date(byAdding: .day, value: 11, to: sprintStart)!

    return SprintInfo(
        number: sprintIndex + 1,
        startDate: sprintStart,
        endDate: sprintEnd,
        currentDay: workDay,
        totalDays: 10,
        isWeekend: isWeekend
    )
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM."
    return formatter.string(from: date)
}

func calendarWeek(for date: Date) -> Int {
    let calendar = Calendar(identifier: .iso8601)
    return calendar.component(.weekOfYear, from: date)
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateDisplay()
        
        // Alle 60 Minuten aktualisieren
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
        
        setupMenu()
    }
    
    func updateDisplay() {
        let sprint = calculateCurrentSprint()

        // Menüleisten-Titel
        let title: String
        if sprint.isWeekend {
            title = "🏃 Sprint \(sprint.number) · 🎉 Wochenende"
        } else {
            title = "🏃 Sprint \(sprint.number) · Tag \(sprint.currentDay)/\(sprint.totalDays)"
        }
        statusItem.button?.title = title

        // Tooltip
        let kwStart = calendarWeek(for: sprint.startDate)
        let kwEnd = calendarWeek(for: sprint.endDate)
        statusItem.button?.toolTip = "dkd Sprint \(sprint.number) (KW\(kwStart)–KW\(kwEnd))\n\(formatDate(sprint.startDate))–\(formatDate(sprint.endDate))\nNoch \(sprint.remainingDays) Arbeitstage"

        // Menü aktualisieren
        setupMenu()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        let sprint = calculateCurrentSprint()
        let kwStart = calendarWeek(for: sprint.startDate)
        let kwEnd = calendarWeek(for: sprint.endDate)
        
        // Sprint-Info Header
        let headerItem = NSMenuItem(title: "dkd Sprint \(sprint.number)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        let headerAttr = NSMutableAttributedString(string: "dkd Sprint \(sprint.number)", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 14)
        ])
        headerItem.attributedTitle = headerAttr
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Kalenderwochen
        let kwItem = NSMenuItem(title: "📅 KW \(kwStart) – KW \(kwEnd)", action: nil, keyEquivalent: "")
        kwItem.isEnabled = false
        menu.addItem(kwItem)
        
        // Zeitraum
        let dateItem = NSMenuItem(title: "📆 \(formatDate(sprint.startDate)) – \(formatDate(sprint.endDate))", action: nil, keyEquivalent: "")
        dateItem.isEnabled = false
        menu.addItem(dateItem)
        
        // Sprint-Woche
        let weekItem = NSMenuItem(title: "📊 Woche \(sprint.weekInSprint) von 2", action: nil, keyEquivalent: "")
        weekItem.isEnabled = false
        menu.addItem(weekItem)

        // Tag im Sprint
        if sprint.isWeekend {
            let weekendItem = NSMenuItem(title: "🎉 Wochenende", action: nil, keyEquivalent: "")
            weekendItem.isEnabled = false
            menu.addItem(weekendItem)
        } else {
            let dayItem = NSMenuItem(title: "⏱️ Tag \(sprint.currentDay) von \(sprint.totalDays)", action: nil, keyEquivalent: "")
            dayItem.isEnabled = false
            menu.addItem(dayItem)
        }

        // Verbleibende Arbeitstage
        let remainItem = NSMenuItem(title: "⏳ Noch \(sprint.remainingDays) Arbeitstage", action: nil, keyEquivalent: "")
        remainItem.isEnabled = false
        menu.addItem(remainItem)
        
        // Fortschrittsbalken
        let progressPercent = Int(sprint.progress * 100)
        let filledBlocks = Int(sprint.progress * 10)
        let emptyBlocks = 10 - filledBlocks
        let progressBar = String(repeating: "▓", count: filledBlocks) + String(repeating: "░", count: emptyBlocks)
        let progressItem = NSMenuItem(title: "\(progressBar) \(progressPercent)%", action: nil, keyEquivalent: "")
        progressItem.isEnabled = false
        menu.addItem(progressItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Als Menüleisten-App ohne Dock-Icon
app.setActivationPolicy(.accessory)

app.run()
