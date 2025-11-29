import SwiftUI
#if os(macOS)
import AppKit
#endif

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

struct FormattingState {
    var isBold: Bool = false
    var isItalic: Bool = false
}

let monthNavigationHStackPadding: CGFloat = 10
let monthNavigationButtonSize: CGFloat = 30

struct ContentView: View {
    @State private var attributedText: NSAttributedString = NSAttributedString(string: "")
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var dateTextMap: [String: Data] = [:] // Dictionary storing RTF data per date
    @StateObject private var textEditorController = RichTextEditorController()
    @State private var formattingState = FormattingState()
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

                    ZStack(alignment: .topLeading) {
                        if attributedText.string.isEmpty {
                            Text("Start writing...")
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 22)
                                .allowsHitTesting(false)
                        }
                        RichTextEditor(text: $attributedText,
                                       controller: textEditorController,
                                       onTextChange: { _ in saveTextForDate() },
                                       onFormattingStateChange: { state in
                                           DispatchQueue.main.async {
                                               formattingState = state
                                           }
                                       })
                            .frame(minHeight: 420)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack {
                        TextFormattingButton(buttonAction: { toggleBold() },
                                             formattingOption: .bold,
                                             isActive: formattingState.isBold)
                        
                        TextFormattingButton(buttonAction: { toggleItalic() },
                                             formattingOption: .italic,
                                             isActive: formattingState.isItalic)
                        
                        TextFormattingButton(buttonAction: { addBulletPoint() },
                                             formattingOption: .bulletList)
                        
                        TextFormattingButton(buttonAction: { addNumberedList() },
                                             formattingOption: .numberedList)
                        
                        Spacer()
                        
                        Text("\(attributedText.string.count)")
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
        .onChangeCompat(of: selectedDate) {
            updateTextContent()
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
        if let data = dateTextMap[dateKey], let attributed = attributedString(from: data) {
            attributedText = attributed
        } else {
            attributedText = NSAttributedString(string: "")
        }
    }
    
    private func saveTextForDate() {
        let dateKey = DateUtils.dateKey(from: selectedDate)
        let trimmed = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            dateTextMap.removeValue(forKey: dateKey)
        } else if let data = rtfData(from: attributedText) {
            dateTextMap[dateKey] = data
        }
        saveToUserDefaults()
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
            if let savedMap = try? JSONDecoder().decode([String: Data].self, from: data) {
                dateTextMap = savedMap
                updateTextContent()
            } else if let legacyMap = try? JSONDecoder().decode([String: String].self, from: data) {
                dateTextMap = legacyMap.reduce(into: [:]) { result, entry in
                    let attributed = NSAttributedString(string: entry.value)
                    if let rtf = rtfData(from: attributed) {
                        result[entry.key] = rtf
                    }
                }
                updateTextContent()
            } else {
                print("Error loading from UserDefaults: Unsupported data format")
                dateTextMap = [:]
                updateTextContent()
            }
        } else {
            // No data found, initialize with empty map
            dateTextMap = [:]
            updateTextContent()
        }
    }

    private func rtfData(from attributedString: NSAttributedString) -> Data? {
        let range = NSRange(location: 0, length: attributedString.length)
        return try? attributedString.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }
    
    private func attributedString(from data: Data) -> NSAttributedString? {
        try? NSAttributedString(data: data,
                                options: [.documentType: NSAttributedString.DocumentType.rtf],
                                documentAttributes: nil)
    }
    
    // Formatting Functions
    private func toggleBold() {
        textEditorController.toggleBold()
    }
    
    private func toggleItalic() {
        textEditorController.toggleItalic()
    }
    
    private func addBulletPoint() {
        textEditorController.insertBullet()
    }
    
    private func addNumberedList() {
        textEditorController.insertNumberedList()
    }
}

#if os(macOS)
final class FormattingTextView: NSTextView {
    var onBoldCommand: (() -> Void)?
    var onItalicCommand: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "b":
                onBoldCommand?()
                return
            case "i":
                onItalicCommand?()
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }
}

/// Wraps NSTextView so we can edit attributed text with custom formatting controls.
struct RichTextEditor: NSViewRepresentable {
    @Binding var text: NSAttributedString
    let controller: RichTextEditorController
    let onTextChange: (NSAttributedString) -> Void
    let onFormattingStateChange: (FormattingState) -> Void
    private let defaultFont = NSFont.systemFont(ofSize: 18)
    private let paragraphSpacing: CGFloat = 6

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = FormattingTextView()
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesInspectorBar = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.font = defaultFont
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 15, height: 18)
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                       height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.backgroundColor = .white
        textView.textStorage?.setAttributedString(text)
        textView.typingAttributes = defaultTypingAttributes()
        textView.onBoldCommand = { [weak controller] in
            controller?.toggleBold()
        }
        textView.onItalicCommand = { [weak controller] in
            controller?.toggleItalic()
        }

        controller.textView = textView
        let state = formattingState(for: textView)
        DispatchQueue.main.async {
            onFormattingStateChange(state)
        }

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        controller.textView = textView
        guard !context.coordinator.isUpdatingFromUser else { return }

        let currentText = textView.attributedString()
        if currentText.isEqual(to: text) {
            let state = formattingState(for: textView)
            DispatchQueue.main.async {
                onFormattingStateChange(state)
            }
            return
        }
        context.coordinator.isUpdatingFromParent = true
        textView.textStorage?.setAttributedString(text)
        textView.typingAttributes = defaultTypingAttributes()
        context.coordinator.isUpdatingFromParent = false
        let state = formattingState(for: textView)
        DispatchQueue.main.async {
            onFormattingStateChange(state)
        }
    }

    private func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = paragraphSpacing
        return [
            .font: defaultFont,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func formattingState(for textView: NSTextView) -> FormattingState {
        let fontManager = NSFontManager.shared
        let selectedRange = textView.selectedRange()
        if selectedRange.length == 0 {
            let font = (textView.typingAttributes[.font] as? NSFont) ?? textView.font ?? defaultFont
            let traits = fontManager.traits(of: font)
            return FormattingState(isBold: traits.contains(.boldFontMask),
                                   isItalic: traits.contains(.italicFontMask))
        }
        var boldValue: Bool?
        var italicValue: Bool?
        var boldMixed = false
        var italicMixed = false
        textView.textStorage?.enumerateAttribute(.font, in: selectedRange, options: []) { value, _, stop in
            let baseFont = (value as? NSFont) ?? textView.font ?? defaultFont
            let traits = fontManager.traits(of: baseFont)
            let isBold = traits.contains(.boldFontMask)
            let isItalic = traits.contains(.italicFontMask)
            if let existing = boldValue {
                if existing != isBold { boldMixed = true }
            } else {
                boldValue = isBold
            }
            if let existingItalic = italicValue {
                if existingItalic != isItalic { italicMixed = true }
            } else {
                italicValue = isItalic
            }
            if boldMixed && italicMixed {
                stop.pointee = true
            }
        }
        let bold = boldMixed ? false : (boldValue ?? false)
        let italic = italicMixed ? false : (italicValue ?? false)
        return FormattingState(isBold: bold, isItalic: italic)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var isUpdatingFromParent = false
        var isUpdatingFromUser = false

        init(parent: RichTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if isUpdatingFromParent { return }
            parent.controller.textView = textView
            let value = textView.attributedString()
            isUpdatingFromUser = true
            parent.text = value
            parent.onTextChange(value)
            DispatchQueue.main.async { self.isUpdatingFromUser = false }
            let parent = parent
            DispatchQueue.main.async {
                parent.onFormattingStateChange(parent.formattingState(for: textView))
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.controller.textView = textView
            let parent = parent
            DispatchQueue.main.async {
                parent.onFormattingStateChange(parent.formattingState(for: textView))
            }
        }
    }
}

/// Controls formatting commands sent from SwiftUI buttons to the underlying NSTextView.
final class RichTextEditorController: ObservableObject {
    weak var textView: NSTextView?

    func toggleBold() {
        applyFontTrait(.boldFontMask)
    }

    func toggleItalic() {
        applyFontTrait(.italicFontMask)
    }

    func insertBullet() {
        applyListPrefix("• ")
    }

    func insertNumberedList() {
        guard let textView else { return }
        guard let textStorage = textView.textStorage else { return }
        let nsString = textStorage.string as NSString
        let selectedRange = textView.selectedRange()
        let paragraphRange = nsString.paragraphRange(for: selectedRange)
        var lineIndex = 1
        var offset = 0

        nsString.enumerateSubstrings(in: paragraphRange, options: .byParagraphs) { _, range, _, _ in
            let insertionIndex = range.location + offset
            let prefix = "\(lineIndex). "
            let attributedPrefix = self.attributedPrefixString(prefix)
            textStorage.insert(attributedPrefix, at: insertionIndex)
            offset += prefix.count
            lineIndex += 1
        }

        let updatedRange = NSRange(location: paragraphRange.location, length: paragraphRange.length + offset)
        textView.setSelectedRange(updatedRange)
    }

    private func applyListPrefix(_ prefix: String) {
        guard let textView else { return }
        guard let textStorage = textView.textStorage else { return }
        let nsString = textStorage.string as NSString
        let selectedRange = textView.selectedRange()
        let paragraphRange = nsString.paragraphRange(for: selectedRange)
        var offset = 0

        nsString.enumerateSubstrings(in: paragraphRange, options: .byParagraphs) { _, range, _, _ in
            let insertionIndex = range.location + offset
            let attributedPrefix = self.attributedPrefixString(prefix)
            textStorage.insert(attributedPrefix, at: insertionIndex)
            offset += prefix.count
        }

        let updatedRange = NSRange(location: paragraphRange.location, length: paragraphRange.length + offset)
        textView.setSelectedRange(updatedRange)
    }

    private func applyFontTrait(_ trait: NSFontTraitMask) {
        guard let textView else { return }
        let fontManager = NSFontManager.shared
        let selections = textView.selectedRanges.compactMap { $0.rangeValue }

        if selections.isEmpty {
            updateTypingAttributes(for: textView, trait: trait, fontManager: fontManager)
            return
        }

        for range in selections {
            if range.length == 0 {
                updateTypingAttributes(for: textView, trait: trait, fontManager: fontManager)
                continue
            }
            textView.textStorage?.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let font = (value as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 18)
                let updatedFont = toggledFont(from: font, trait: trait, fontManager: fontManager)
                textView.textStorage?.addAttribute(.font, value: updatedFont, range: subrange)
            }
        }
        textView.didChangeText()
    }

    private func updateTypingAttributes(for textView: NSTextView,
                                        trait: NSFontTraitMask,
                                        fontManager: NSFontManager) {
        var attributes = textView.typingAttributes
        let baseFont = (attributes[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 18)
        attributes[.font] = toggledFont(from: baseFont, trait: trait, fontManager: fontManager)
        textView.typingAttributes = attributes
    }

    private func toggledFont(from font: NSFont,
                             trait: NSFontTraitMask,
                             fontManager: NSFontManager) -> NSFont {
        let hasTrait = fontManager.traits(of: font).contains(trait)
        if hasTrait {
            return fontManager.convert(font, toNotHaveTrait: trait)
        } else {
            return fontManager.convert(font, toHaveTrait: trait)
        }
    }

    private func attributedPrefixString(_ string: String) -> NSAttributedString {
        let attributes = textView?.typingAttributes ?? [:]
        return NSAttributedString(string: string, attributes: attributes)
    }
}
#else
/// Minimal fallback so the view still compiles on non-macOS platforms.
struct RichTextEditor: View {
    @Binding var text: NSAttributedString
    let controller: RichTextEditorController
    let onTextChange: (NSAttributedString) -> Void
    let onFormattingStateChange: (FormattingState) -> Void

    var body: some View {
        _ = controller
        TextEditor(text: Binding(
            get: { text.string },
            set: { newValue in
                text = NSAttributedString(string: newValue)
                onTextChange(text)
                onFormattingStateChange(FormattingState())
            }
        ))
        .onAppear {
            onFormattingStateChange(FormattingState())
        }
    }
}

final class RichTextEditorController: ObservableObject {
    func toggleBold() {}
    func toggleItalic() {}
    func insertBullet() {}
    func insertNumberedList() {}
}
#endif

struct CalendarGrid: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    @Binding var dateTextMap: [String: Data]
    let availableWidth: CGFloat
    let calendar = Calendar.current
    
    @State private var hoveredDay: Int? = nil // Track the hovered day
    @State private var calendarGridDensity: CGFloat = 80 // I find the value 80 makes the grid as dense as I like
    
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
            return dateTextMap[dateKey] != nil
        }
        return false
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

// Buttons for formatting text content
struct TextFormattingButton: View {
    let buttonAction: () -> Void
    let formattingOption: TextFormat
    let isActive: Bool

    init(buttonAction: @escaping () -> Void,
         formattingOption: TextFormat,
         isActive: Bool = false) {
        self.buttonAction = buttonAction
        self.formattingOption = formattingOption
        self.isActive = isActive
    }
    
    private let fontSize: CGFloat = 18
    private let frameSize: CGFloat = 30
    private let buttonColor: Color = Color.init(cgColor: CGColor(gray: 215/255, alpha: 1))
    private let activeButtonColor: Color = Color(red: 70/255, green: 105/255, blue: 175/255)
    private let inactiveShadowColor: Color = Color.black.opacity(0.3)
    private let activeShadowColor: Color = Color(red: 15/255, green: 30/255, blue: 75/255).opacity(0.6)
    private let inactiveIconColor: Color = .black
    private let activeIconColor: Color = Color(red: 225/255, green: 238/255, blue: 255/255)
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
                    .fill(isActive ? activeButtonColor : buttonColor)
                    .shadow(color: isActive ? activeShadowColor : inactiveShadowColor, radius: 2, x: 2, y: 2))
                .foregroundStyle(isActive ? activeIconColor : inactiveIconColor)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    @ViewBuilder
    fileprivate func onChangeCompat<Value: Equatable>(of value: Value,
                                                      _ action: @escaping () -> Void) -> some View {
        if #available(macOS 14.0, *) {
            self.onChange(of: value, initial: false) { _, _ in
                action()
            }
        } else {
            self.onChange(of: value) { _ in
                action()
            }
        }
    }
}

// For the Preview Canvas within XCode
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
