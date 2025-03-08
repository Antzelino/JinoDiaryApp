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
                    HStack {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(monthYearFormatter.string(from: currentMonth))
                            .font(.headline)
                        
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 10)
                    
                    CalendarView(selectedDate: $selectedDate, currentMonth: $currentMonth)
                        .padding(.horizontal, 10)
                }
                .frame(width: geometry.size.width * 0.4) // 40% of total width
                .background(Color.gray.opacity(0.1))
                
                // Text Editor (60% of total width)
                VStack {
                    HStack {
                        Text(formattedDateString(from: selectedDate))
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    
                    TextEditor(text: $textContent)
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

// Updated Calendar View with Dynamic Month
struct CalendarView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 5) {
            let days = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity, minHeight: 20)
                }
            }
            
            let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!
            let firstWeekday = calendar.component(.weekday, from: calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!) - 1
            let weeks = generateWeeks(firstWeekday: firstWeekday, days: daysInMonth.count)
            
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7) { index in
                        if let day = week[index] {
                            Text("\(day)")
                                .font(.caption)
                                .frame(maxWidth: .infinity, minHeight: 20)
                                .background(isSelected(day: day) ? Color.blue.opacity(0.3) : Color.clear)
                                .clipShape(Circle())
                                .onTapGesture {
                                    if let newDate = calendar.date(bySetting: .day, value: day, of: currentMonth) {
                                        selectedDate = newDate
                                    }
                                }
                        } else {
                            Text("")
                                .frame(maxWidth: .infinity, minHeight: 20)
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
        let components = calendar.dateComponents([.day], from: selectedDate)
        return components.day == day && calendar.isDate(selectedDate, equalTo: currentMonth, toGranularity: .month)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
