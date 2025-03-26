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

let monthNavigationHStackPadding: CGFloat = 10
let monthNavigationButtonSize: CGFloat = 30

struct ContentView: View {
    @State private var textContent: String = ""
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var dateTextMap: [String: String] = [:] // Dictionary to store text per date
    let calendar: Calendar = Calendar.current
    let spacingBetweenTodayButtonAndCalendar: CGFloat = 15
    let todayButtonColor: Color = Color.init(red: 200/255, green: 220/255, blue: 255/255)
    let calendarViewBackgroundColor: Color = Color.init(cgColor: CGColor(gray: 220/255, alpha: 1))
    
    // Spacing and layout constants
    let topLevelSpacing: CGFloat = 20
    let topLevelHorizontalPadding: CGFloat = 20
    let topLevelVerticalPadding: CGFloat = 15
    let horizontalEmptySpace: CGFloat // Amount of width that's spacing or padding
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
                VStack(spacing: spacingBetweenTodayButtonAndCalendar) {
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
                    
                    // Month-navigation and CalendarGrid in the grey box
                    VStack (spacing: 0) {
                        HStack {
                            MonthNavigationButton(buttonAction: { changeMonth(by: -1) },
                                                  arrowDirection: .left)
                            
                            Spacer()
                            
                            Text(DateUtils.monthYearString(from: currentMonth))
                                .font(.system(size: 20))
                            
                            Spacer()
                            
                            MonthNavigationButton(buttonAction: { changeMonth(by: 1) },
                                                  arrowDirection: .right)
                        }
                        .padding(monthNavigationHStackPadding)
                        
                        CalendarGrid(selectedDate: $selectedDate,
                                     currentMonth: $currentMonth,
                                     dateTextMap: $dateTextMap,
                                     textContent: $textContent,
                                     availableWidth: (geometry.size.width - horizontalEmptySpace) * leftSideRatio)
                    }
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(calendarViewBackgroundColor))
                }
                .frame(width: (geometry.size.width - horizontalEmptySpace) * leftSideRatio)
                .padding(.bottom, spacingBetweenTodayButtonAndCalendar) // This helps bring it slightly higher which is a look I prefer
                
                // Text Editor (right side, goldenRatio)
                VStack (spacing: 7) {
                    HStack {
                        Text(DateUtils.formattedDateString(from: selectedDate))
                            .font(.title3)
                        
                        Spacer()
                    }

                    ZStack {
                        if self.textContent.isEmpty { // Hacky way for placeholder text
                            TextEditor(text: .constant("Start writing..."))
                                .font(.system(size: 18))
                                .foregroundStyle(.gray)
                                .disabled(true)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 18)
                                .background(.white)
                        }
                        TextEditor(text: $textContent)
                            .font(.system(size: 18))
                            .lineSpacing(10)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .opacity(self.textContent.isEmpty ? 0.25 : 1) // Hacky way for placeholder text
                            .background(self.textContent.isEmpty ? .clear : .white) // Hacky way for placeholder text
                            .onChange(of: textContent) {
                                saveTextForDate()
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack {
                        TextFormattingButton(buttonAction: { toggleBold() },
                                             formattingOption: .bold)
                        
                        TextFormattingButton(buttonAction: { toggleItalic() },
                                             formattingOption: .italic)
                        
                        TextFormattingButton(buttonAction: { addBulletPoint() },
                                             formattingOption: .bulletList)
                        
                        TextFormattingButton(buttonAction: { addNumberedList() },
                                             formattingOption: .numberedList)
                        
                        Spacer()
                        
                        Text("\(textContent.count)")
                            .foregroundColor(.gray)
                    }
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
        // TODO: Correct implementation of toggleBold()
//        if textContent.contains("**") {
//            textContent = textContent.replacingOccurrences(of: "**", with: "")
//        } else {
//            textContent = "**" + textContent + "**"
//        }
    }
    
    private func toggleItalic() {
        // TODO: Correct implementation of toggleItalic()
//        if textContent.contains("_") {
//            textContent = textContent.replacingOccurrences(of: "_", with: "")
//        } else {
//            textContent = "_" + textContent + "_"
//        }
    }
    
    private func addBulletPoint() {
        // TODO: Correct implementation of addBulletPoint()
//        textContent += "\n• "
    }
    
    private func addNumberedList() {
        // TODO: Correct implementation of addNumberedList()
//        let lines = textContent.split(separator: "\n")
//        var newText = ""
//        for (index, line) in lines.enumerated() {
//            newText += "\(index + 1). \(line)\n"
//        }
//        textContent = newText
    }
}

struct CalendarGrid: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    @Binding var dateTextMap: [String: String]
    @Binding var textContent: String
    let availableWidth: CGFloat
    let calendar = Calendar.current
    
    @State private var hoveredDay: Int? = nil // Track the hovered day
    @State private var calendarGridDensity: CGFloat = 80 // I find the value 90 makes the grid as dense as I like
    
    var body: some View {
        VStack(spacing: 0) {
            let cellWidth = (availableWidth - calendarGridDensity) / 7
            let circleSize = cellWidth * 0.75
    
            HStack(spacing: 0) {
                let weekend = ["Sa", "Su"]
                let weekendColor: Color = Color(red: 230/255, green: 70/255, blue: 70/255)
                let days = ["Mo", "Tu", "We", "Th", "Fr"] + weekend
                let dayFont: Font = Font.system(size: 15, weight: .semibold)
                
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(dayFont)
                        .foregroundStyle(weekend.contains(day) ? weekendColor : Color.black)
                        .frame(width: cellWidth, height: cellWidth, alignment: .center)
                }
            }.padding(.bottom, 5)
            
            let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!
            let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
            let firstWeekday = (calendar.component(.weekday, from: firstDayOfMonth) + 5) % 7 // From Sunday=1, Monday=2... to Monday=0,... Sunday=6
            let weeks = generateWeeks(firstWeekday: firstWeekday, days: daysInMonth.count)
            
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7) { index in
                        if let day = week[index] {
                            ZStack {
                                // Hover highlight
                                if hoveredDay == day {
                                    Circle()
                                        .fill(Color.gray.opacity(0.1)) // Subtle gray hover highlight
                                        .frame(width: circleSize)
                                }
                                
                                // Filled slight gray highlight for selected day
                                Circle()
                                    .fill(isSelected(day: day) ? Color.gray.opacity(0.2) : Color.clear)
                                    .frame(width: circleSize)
                                
                                // Stroke blue highlight for today
                                if isToday(day: day) {
                                    Circle()
                                        .stroke(Color.blue.opacity(0.5), lineWidth: 3) // Light blue stroke, 3px thick
                                        .frame(width: circleSize)
                                }
                                
                                // Day number
                                Text("\(day)")
                                    .font(.system(
                                        size: 15,
                                        weight: hasContent(day: day) ? .bold : .regular)) // Bold if has content, regular if not
                                    .foregroundColor(hasContent(day: day) ? .blue : .black) // Blue if has content, black if not
                            }
                            .frame(width: cellWidth, height: cellWidth)
                            .contentShape(Rectangle()) // Set hitbox to square matching the cell, even though hover highlight is a smaller circle. I think it looks nicer
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
        .padding(.vertical, 10) // I just like how it looks, having this little space on the bottom
        .padding(.horizontal, monthNavigationButtonSize + monthNavigationHStackPadding) // I like how this perfectly lines up the grid to be between the navigation buttons, below them
    }
    
    private func generateWeeks(firstWeekday: Int, days: Int) -> [[Int?]] {
        var weeks: [[Int?]] = []
        var currentWeek: [Int?] = Array(repeating: nil, count: 7)
        var dayCount = 1
        
        for i in 0..<42 { // Grid of 6x7, max 6 weeks (42 days)
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

// Buttons for navigating previous/next month
struct MonthNavigationButton: View {
    let buttonAction: () -> Void
    let arrowDirection: ArrowDirection
    
    private let buttonColor: Color = Color.init(cgColor: CGColor(gray: 190/255, alpha: 1))
    private let fontSize: CGFloat = 15
    private let fontWeight: Font.Weight = .heavy
    private let frameSize: CGFloat = monthNavigationButtonSize
    private let buttonShape: RoundedRectangle = RoundedRectangle(cornerRadius: 5)
    private let shadowColor: Color = Color.black.opacity(0.3)
    private let textColor: Color = Color.black
    
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
        Button(action: { buttonAction() }) {
            Image(systemName: arrowDirection.systemImageName)
                .font(.system(size: fontSize))
                .fontWeight(fontWeight)
                .frame(width: frameSize, height: frameSize)
                .background(buttonShape
                    .fill(buttonColor)
                    .shadow(color: shadowColor, radius: 2, x: 2, y: 2))
                .foregroundColor(textColor)
        }
        .buttonStyle(.plain)
    }
}

// Buttons for formatting the text in TextEditor
struct TextFormattingButton: View {
    let buttonAction: () -> Void
    let formattingOption: TextFormat
    
    private let fontSize: CGFloat = 18
    private let frameSize: CGFloat = 30
    private let buttonColor: Color = Color.init(cgColor: CGColor(gray: 215/255, alpha: 1))
    private let buttonShape: RoundedRectangle = RoundedRectangle(cornerRadius: 5)
    
    enum TextFormat {
        case bold
        case italic
        case bulletList
        case numberedList
        
        var systemImageName: String {
            switch self {
            case .bold: return "bold"
            case .italic: return "italic"
            case .bulletList: return "list.bullet"
            case .numberedList: return "list.number"
            }
        }
    }
    
    var body: some View {
        Button(action: { buttonAction() }) {
            Image(systemName: formattingOption.systemImageName)
                .font(.system(size: fontSize))
                .frame(width: frameSize, height: frameSize)
                .background(buttonShape
                    .fill(buttonColor)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 2, y: 2))
                .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
        .disabled(true)
    }
}

// For the Preview Canvas within XCode
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
