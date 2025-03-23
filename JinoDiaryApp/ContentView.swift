import SwiftUI

// Dedicated struct for date formatting utilities
struct DateUtils {
    static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, dd MMMM yyyy"
        return formatter
    }()
    
    static let dayMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter
    }()
    
    static func monthYearString(from date: Date) -> String {
        return monthYearFormatter.string(from: date)
    }
    
    static func dateKey(from date: Date) -> String {
        return dateKeyFormatter.string(from: date)
    }
    
    static func formattedDateString(from date: Date) -> String {
        return fullDateFormatter.string(from: date)
    }
    
    static func dayMonthYearString(from date: Date) -> String {
        return dayMonthYearFormatter.string(from: date)
    }
}

struct ArrowButton: View {
    let direction: ArrowDirection
    let action: () -> Void
    let buttonColor: Color = Color.init(cgColor: CGColor(red: 190/255, green: 190/255, blue: 190/255, alpha: 1))
    
    enum ArrowDirection {
        case left
        case right
        
        var systemImageName: String {
            switch self {
            case .left: return "chevron.left"
            case .right: return "chevron.right"
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: direction.systemImageName)
                .font(.system(size: 15))
                .fontWeight(.heavy)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 5)
                    .fill(buttonColor)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 2, y: 2))
        }
        .buttonStyle(.plain)
    }
}

struct ContentView: View {
    @State private var textContent: String = ""
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var dateTextMap: [String: String] = [:] // Dictionary to store text per date
    let calendar: Calendar = Calendar.current
    let disableFormattingButtons: Bool = true
    let spacingBetweenButtonAndCalendarView: CGFloat = 15.0
    let todayButtonColor: Color = Color.init(cgColor: CGColor(red: 200/255, green: 220/255, blue: 255/255, alpha: 1))
    
    // Spacing and layout constants
    let topLevelSpacing: CGFloat = 20
    let topLevelHorizontalPadding: CGFloat = 20
    let topLevelVerticalPadding: CGFloat = 15
    let horizontalEmptySpace: CGFloat // How much of the width is spacing or padding, rather than some kind of content
    init() {
        horizontalEmptySpace = 1 * topLevelSpacing + 2 * topLevelHorizontalPadding
    }
    
    // Golden ratio proportions
    let goldenRatio: CGFloat = 0.6180339887 // 1/phi for the right side
    var leftSideRatio: CGFloat { 1 - goldenRatio } // Remaining for the left side
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: topLevelSpacing) {
                // Calendar View (left side, 1 - goldenRatio)
                VStack(spacing: spacingBetweenButtonAndCalendarView) {
                    // Go To Today Button above the grey calendar box
                    Button(action: { goToToday() }) {
                        Text("Go to Today")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 40)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .background(RoundedRectangle(cornerRadius: 5)
                                .fill(todayButtonColor)
                                .shadow(color: .black.opacity(0.35), radius: 3, x: 2, y: 2)) // Shadow on the button
                            .foregroundColor(.blue.opacity(0.7)) // Text color
                    }
                    .help(Text(DateUtils.dayMonthYearString(from: selectedDate))) // Hover tooltip shows today's date
                    .buttonStyle(.plain)
                    
                    // Navigation and Calendar in the grey box
                    VStack {
                        HStack {
                            ArrowButton(direction: .left, action: { changeMonth(by: -1) })
                            
                            Spacer()
                            
                            Text(DateUtils.monthYearString(from: currentMonth)).font(.system(size: 20))
                            
                            Spacer()
                            
                            ArrowButton(direction: .right, action: { changeMonth(by: 1) })
                        }
                        .padding(10)
                        
                        CalendarView(selectedDate: $selectedDate,
                                     currentMonth: $currentMonth,
                                     dateTextMap: $dateTextMap,
                                     textContent: $textContent,
                                     availableWidth: (geometry.size.width - horizontalEmptySpace) * leftSideRatio)
                        .padding(.bottom, 10)
                    }
                    .background(Color.init(cgColor: CGColor(gray: 220/255, alpha: 1)))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(width: (geometry.size.width - horizontalEmptySpace) * leftSideRatio)
                .padding(.bottom, spacingBetweenButtonAndCalendarView) // This helps bring it slightly higher which look I prefer
                
                // Text Editor (right side, goldenRatio)
                VStack {
                    HStack {
                        Text(DateUtils.formattedDateString(from: selectedDate))
                            .font(.title3)
                        Spacer()
                    }

                    ZStack {
                        TextEditor(text: $textContent)
                            .font(.system(size: 18))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .onChange(of: textContent) {
                                saveTextForDate()
                            }
                            .lineSpacing(10)
                            .background(Color.white)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack {
                        Button(action: { toggleBold() }) {
                            Text("B")
                                .frame(width: 30, height: 30)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .disabled(disableFormattingButtons)
                        
                        Button(action: { toggleItalic() }) {
                            Text("𝐼")
                                .frame(width: 30, height: 30)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .disabled(disableFormattingButtons)
                        
                        Button(action: { addBulletPoint() }) {
                            Text("•")
                                .frame(width: 30, height: 30)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .disabled(disableFormattingButtons)
                        
                        Button(action: { addNumberedList() }) {
                            Text("1.")
                                .frame(width: 30, height: 30)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .disabled(disableFormattingButtons)
                        
                        Spacer()
                        
                        Text("\(textContent.count)")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .padding(.top, 5)
                }
                .frame(width: (geometry.size.width - horizontalEmptySpace) * goldenRatio)
            }
            .padding(.horizontal, topLevelHorizontalPadding)
            .padding(.vertical, topLevelVerticalPadding)
        }
        .frame(minWidth: 1200, minHeight: 650)
        .onAppear {
            loadSavedData()
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
            // Select the first day of the new month
            if let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) {
                selectedDate = firstDayOfMonth
                updateTextContent()
            }
        }
    }
    
    private func goToToday() {
        let today = Date()
        currentMonth = today
        selectedDate = today
        updateTextContent()
    }
    
    private func updateTextContent() {
        let dateKey = DateUtils.dateKey(from: selectedDate)
        textContent = dateTextMap[dateKey] ?? ""
    }
    
    private func saveTextForDate() {
        let dateKey = DateUtils.dateKey(from: selectedDate)
        if textContent.isEmpty {
            dateTextMap.removeValue(forKey: dateKey) // Remove entry if text is empty
        } else {
            dateTextMap[dateKey] = textContent
        }
        saveToUserDefaults()
    }
    
    private func dateKeyForDate(_ date: Date) -> String {
        return DateUtils.dateKey(from: date)
    }
    
    // Persistence with Error Handling
    private func saveToUserDefaults() {
        do {
            let encodedData = try JSONEncoder().encode(dateTextMap)
            UserDefaults.standard.set(encodedData, forKey: "dateTextMap")
        } catch {
            print("Error saving to UserDefaults: \(error.localizedDescription)")
            // Fallback: Clear the map to prevent corruption
            dateTextMap = [:]
        }
    }
    
    private func loadSavedData() {
        if let data = UserDefaults.standard.data(forKey: "dateTextMap") {
            do {
                let savedMap = try JSONDecoder().decode([String: String].self, from: data)
                dateTextMap = savedMap
                updateTextContent()
            } catch {
                print("Error loading from UserDefaults: \(error.localizedDescription)")
                // Fallback: Use empty map as default
                dateTextMap = [:]
                updateTextContent()
            }
        } else {
            // No data found, initialize with empty map
            dateTextMap = [:]
            updateTextContent()
        }
    }
    
    // Formatting Functions
    private func toggleBold() {
        if textContent.contains("**") {
            textContent = textContent.replacingOccurrences(of: "**", with: "")
        } else {
            textContent = "**" + textContent + "**"
        }
    }
    
    private func toggleItalic() {
        if textContent.contains("_") {
            textContent = textContent.replacingOccurrences(of: "_", with: "")
        } else {
            textContent = "_" + textContent + "_"
        }
    }
    
    private func addBulletPoint() {
        textContent += "\n• "
    }
    
    private func addNumberedList() {
        let lines = textContent.split(separator: "\n")
        var newText = ""
        for (index, line) in lines.enumerated() {
            newText += "\(index + 1). \(line)\n"
        }
        textContent = newText
    }
}

struct CalendarView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    @Binding var dateTextMap: [String: String]
    @Binding var textContent: String
    let availableWidth: CGFloat
    let calendar = Calendar.current
    
    @State private var hoveredDay: Int? = nil // Track the hovered day
    @State private var calendarGridDensity: CGFloat = 90 // I find the value 90 makes the grid as dense as I like
    
    var body: some View {
        VStack(spacing: 5) {
            let cellWidth = (availableWidth - calendarGridDensity) / 7
            let circleSize = cellWidth * 0.75
    
            HStack(spacing: 0) {
                let days = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                let weekend = days[5...6]
                let weekendColor: Color = Color(red: 230/255, green: 70/255, blue: 70/255)
                
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(weekend.contains(day) ? weekendColor : Color.black)
                        .frame(width: cellWidth, height: cellWidth, alignment: .center)
                }
            }
            
            let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!
            let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
            let firstWeekday = (calendar.component(.weekday, from: firstDayOfMonth) - 2 + 7) % 7 // Adjusted for Monday start
            let weeks = generateWeeks(firstWeekday: firstWeekday, days: daysInMonth.count)
            
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7) { index in
                        if let day = week[index] {
                            ZStack {
                                // Hover highlight
                                if hoveredDay == day {
                                    Circle()
                                        .fill(Color.gray.opacity(0.1)) // Subtle grey hover highlight
                                        .frame(width: circleSize)
                                }
                                
                                // Filled highlight for selected day
                                Circle()
                                    .fill(isSelected(day: day) ? Color.gray.opacity(0.2) : Color.clear)
                                    .frame(width: circleSize)
                                
                                // Stroke highlight for today
                                if isToday(day: day) {
                                    Circle()
                                        .stroke(Color.blue.opacity(0.5), lineWidth: 3) // Light blue stroke, 3px thick
                                        .frame(width: circleSize)
                                }
                                
                                // Day number
                                Text("\(day)")
                                    .font(.system(size: 15))
                                    .foregroundColor(hasContent(day: day) ? .blue : .black) // Blue if has content, black if not
                                    .bold(hasContent(day: day)) // Bold if has content
                            }
                            .frame(width: cellWidth, height: cellWidth)
                            .contentShape(Rectangle()) // Hitbox is now a square matching the cell
                            .onTapGesture {
                                var components = calendar.dateComponents([.year, .month], from: currentMonth)
                                components.day = day
                                if let newDate = calendar.date(from: components) {
                                    selectedDate = newDate
                                    updateTextContent()
                                }
                            }
                            .onHover { isHovering in
                                hoveredDay = isHovering ? day : nil
                            }
                        } else {
                            Text("")
                                .frame(width: cellWidth, height: cellWidth)
                        }
                    }
                }
            }
        }
    }
    
    private func generateWeeks(firstWeekday: Int, days: Int) -> [[Int?]] {
        var weeks: [[Int?]] = []
        var currentWeek: [Int?] = Array(repeating: nil, count: 7)
        var dayCount = 1
        
        for i in 0..<42 { // Max 6 weeks (42 days)
            let dayIndex = i % 7
            
            if i >= firstWeekday && dayCount <= days {
                currentWeek[dayIndex] = dayCount
                dayCount += 1
            }
            
            if dayIndex == 6 || i == 41 {
                weeks.append(currentWeek)
                currentWeek = Array(repeating: nil, count: 7)
            }
        }
        
        return weeks
    }
    
    private func isSelected(day: Int) -> Bool {
        let selectedComponents = calendar.dateComponents([.day, .month, .year], from: selectedDate)
        let currentMonthComponents = calendar.dateComponents([.month, .year], from: currentMonth)
        
        return selectedComponents.day == day &&
               selectedComponents.month == currentMonthComponents.month &&
               selectedComponents.year == currentMonthComponents.year
    }
    
    private func isToday(day: Int) -> Bool {
        let today = Date()
        let todayComponents = calendar.dateComponents([.day, .month, .year], from: today)
        let currentMonthComponents = calendar.dateComponents([.month, .year], from: currentMonth)
        
        return todayComponents.day == day &&
               todayComponents.month == currentMonthComponents.month &&
               todayComponents.year == currentMonthComponents.year
    }
    
    private func hasContent(day: Int) -> Bool {
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        if let date = calendar.date(from: components) {
            let dateKey = DateUtils.dateKey(from: date)
            if let content = dateTextMap[dateKey], !content.isEmpty {
                return true
            }
        }
        return false
    }
    
    private func updateTextContent() {
        let dateKey = DateUtils.dateKey(from: selectedDate)
        textContent = dateTextMap[dateKey] ?? ""
    }
    
    private func dateKeyForDate(_ date: Date) -> String {
        return DateUtils.dateKey(from: date)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewLayout(.device)
    }
}
