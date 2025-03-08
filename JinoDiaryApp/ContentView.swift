import SwiftUI

struct ContentView: View {
    @State private var textContent: String = ""
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    let calendar = Calendar.current
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Calendar View (40% of total width)
                VStack {
                    // Today Button above the grey box
                    Button(action: { goToToday() }) {
                        Text("Today")
                            .font(.system(size: 20)) // Increased from ~17 (.headline) to 20
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 10)
                    
                    // Navigation and Calendar in the grey box
                    VStack {
                        HStack {
                            Button(action: { changeMonth(by: -1) }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20)) // Match font size for consistency
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text("Navigate")
                                .font(.system(size: 20)) // Increased from ~17 (.headline) to 20
                            
                            Button(action: { changeMonth(by: 1) }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 20)) // Match font size for consistency
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 10)
                        
                        Text(monthYearFormatter.string(from: currentMonth))
                            .font(.system(size: 20)) // Increased from ~17 (.headline) to 20
                            .padding(.bottom, 5)
                        
                        CalendarView(selectedDate: $selectedDate, currentMonth: $currentMonth, availableWidth: geometry.size.width * 0.4)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                    }
                    .background(Color.gray.opacity(0.1))
                }
                .frame(width: geometry.size.width * 0.4) // 40% of total width
                
                // Text Editor (60% of total width)
                VStack {
                    HStack {
                        Text(formattedDateString(from: selectedDate))
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    
                    TextEditor(text: $textContent)
                        .font(.system(size: 18)) // Unchanged (previously set to 18)
                        .frame(minHeight: 400)
                        .padding()
                    
                    HStack {
                        Button(action: { toggleBold() }) {
                            Text("B")
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { toggleItalic() }) {
                            Text("I")
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { addBulletPoint() }) {
                            Text("•")
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { addNumberedList() }) {
                            Text("1.")
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        Text("\(textContent.count)")
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
                .frame(width: geometry.size.width * 0.6) // 60% of total width
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
            // Ensure selectedDate stays within the new month if possible
            let components = calendar.dateComponents([.year, .month], from: currentMonth)
            if let firstDayOfMonth = calendar.date(from: components) {
                let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!
                let day = min(calendar.component(.day, from: selectedDate), range.count)
                if let newSelectedDate = calendar.date(bySetting: .day, value: day, of: currentMonth) {
                    selectedDate = newSelectedDate
                }
            }
        }
    }
    
    private func goToToday() {
        let today = Date()
        currentMonth = today
        selectedDate = today
    }
    
    private func formattedDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, dd MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
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

// Updated Calendar View with Dynamic Month and Fixed Alignment
struct CalendarView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let availableWidth: CGFloat // Pass the available width (40% of total window width)
    let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 5) {
            let days = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            let cellWidth = (availableWidth - 20) / 7 // Subtract padding (10 on each side), divide by 7 columns
            
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 15)) // Increased from ~12 (.caption) to 15
                        .frame(width: cellWidth, height: cellWidth)
                        .multilineTextAlignment(.center)
                }
            }
            
            let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!
            let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
            let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1 // 0 (Sunday) to 6 (Saturday)
            let weeks = generateWeeks(firstWeekday: firstWeekday, days: daysInMonth.count)
            
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7) { index in
                        if let day = week[index] {
                            ZStack {
                                Circle()
                                    .fill(isSelected(day: day) ? Color.blue.opacity(0.3) : Color.clear)
                                    .frame(width: cellWidth * 0.8, height: cellWidth * 0.8)
                                
                                Text("\(day)")
                                    .font(.system(size: 15)) // Increased from ~12 (.caption) to 15
                                    .foregroundColor(.black)
                            }
                            .frame(width: cellWidth, height: cellWidth)
                            .contentShape(Circle())
                            .onTapGesture {
                                var components = calendar.dateComponents([.year, .month], from: currentMonth)
                                components.day = day
                                if let newDate = calendar.date(from: components) {
                                    selectedDate = newDate
                                }
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
            let weekIndex = i / 7
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
