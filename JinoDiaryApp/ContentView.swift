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
    var isBulleted: Bool = false
}

let monthNavigationHStackPadding: CGFloat = 10
let monthNavigationButtonSize: CGFloat = 30
let activeFormattingButtonColor = Color(red: 126/255, green: 130/255, blue: 130/255, opacity: 1.0)
let inactiveFormattingButtonColor = Color(red: 0, green: 0, blue: 0, opacity: 0.0)
let appBackgroundColor = Color(red: 235/255, green: 236/255, blue: 239/255)
let calendarBackgroundColor = Color(red: 220/255, green: 220/255, blue: 220/255)
let todayButtonColor = Color(red: 200/255, green: 220/255, blue: 255/255)

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var attributedText: NSAttributedString = NSAttributedString(string: "")
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var datesWithContent: Set<String> = []
    @State private var pendingSave: DispatchWorkItem? = nil
    @StateObject private var textEditorController = RichTextEditorController()
    @State private var formattingState = FormattingState()
    let calendar: Calendar = Calendar.current
    private let storage: DiaryStorage = SQLiteStorageService.shared
    let spacingBetweenTodayButtonAndCalendar: CGFloat = 15
    
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
                                     datesWithContent: $datesWithContent,
                                     availableWidth: (geometry.size.width - horizontalEmptySpace) * leftSideRatio,
                                     onBeforeDayChange: { saveImmediately() },
                                     onDaySelection: { textEditorController.focusEditor() })
                    }
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(calendarBackgroundColor))
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
                                       onTextChange: { newText in
                                           updateContentIndicator(for: newText)
                                           scheduleSave()
                                       },
                                       onFormattingStateChange: { state in
                                           DispatchQueue.main.async {
                                               formattingState = state
                                           }
                                       },
                                       onNavigateDay: { changeDay(by: $0) },
                                       onNavigateMonth: { changeMonthKeepingDay(by: $0) },
                                       onGoToToday: { goToToday() },
                                       onNavigateToDayWithContent: { navigateToDayWithContent(direction: $0) })
                            .frame(minHeight: 420)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack {
                        TextFormattingButton(buttonAction: { toggleBold() },
                                             formattingOption: .bold,
                                             isActive: formattingState.isBold,
                                             activeColor: activeFormattingButtonColor,
                                             inactiveColor: inactiveFormattingButtonColor)
                        
                        TextFormattingButton(buttonAction: { toggleItalic() },
                                             formattingOption: .italic,
                                             isActive: formattingState.isItalic,
                                             activeColor: activeFormattingButtonColor,
                                             inactiveColor: inactiveFormattingButtonColor)
                        
                        TextFormattingButton(buttonAction: { toggleBulletedList() },
                                             formattingOption: .bulletList,
                                             isActive: formattingState.isBulleted,
                                             activeColor: activeFormattingButtonColor,
                                             inactiveColor: inactiveFormattingButtonColor)
                        
                        Spacer()
                        
                        Text("\(attributedText.string.count)")
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: (geometry.size.width - horizontalEmptySpace) * goldenRatio)
            }
            .padding(.horizontal, topLevelHorizontalPadding)
            .padding(.top, topLevelVerticalPadding + 24)
            .padding(.bottom, topLevelVerticalPadding)
        }
        .frame(minWidth: 1200, minHeight: 650)
        .background(appBackgroundColor)
        .ignoresSafeArea()
        .onAppear {
            loadFromStorage()
            textEditorController.focusEditor()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase != .active {
                saveImmediately()
                storage.performBackup(retaining: 3)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            saveImmediately()
            storage.performBackup(retaining: 3)
        }
        .onChangeCompat(of: selectedDate) {
            updateTextContent()
        }
    }
    
    private func changeMonth(by value: Int) {
        saveImmediately()
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
            // Select the first day of the new month
            if let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) {
                selectedDate = firstDayOfMonth
                updateTextContent()
                textEditorController.focusEditor()
            }
        }
    }

    private func changeMonthKeepingDay(by value: Int) {
        saveImmediately()
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
            currentMonth = newDate
            updateTextContent()
            textEditorController.focusEditor()
        }
    }

    private func changeDay(by value: Int) {
        saveImmediately()
        if let newDate = calendar.date(byAdding: .day, value: value, to: selectedDate) {
            selectedDate = newDate
            currentMonth = newDate
            updateTextContent()
            textEditorController.focusEditor()
        }
    }
    
    private func goToToday() {
        saveImmediately()
        let today = Date()
        currentMonth = today
        selectedDate = today
        updateTextContent()
        textEditorController.focusEditor()
    }
    
    private func dateHasContent(_ date: Date) -> Bool {
        let key = DateUtils.dateKey(from: date)
        return datesWithContent.contains(key)
    }
    
    private func navigateToDayWithContent(direction: Int) {
        saveImmediately()
        var searchDate = selectedDate
        let maxDays = 365 // Prevent infinite loops; search up to 1 year ahead/back
        
        for _ in 0..<maxDays {
            if let newDate = calendar.date(byAdding: .day, value: direction, to: searchDate) {
                if dateHasContent(newDate) {
                    selectedDate = newDate
                    currentMonth = newDate
                    updateTextContent()
                    textEditorController.focusEditor()
                    return
                }
                searchDate = newDate
            } else {
                return
            }
        }
    }
    
    private func updateTextContent() {
        let dateKey = DateUtils.dateKey(from: selectedDate)
        if let data = storage.loadEntry(for: dateKey), let attributed = attributedString(from: data) {
            attributedText = attributed
        } else {
            attributedText = NSAttributedString(string: "")
        }
        textEditorController.focusEditor()
    }
    
#if os(macOS)
    private func refreshTextFromEditor() {
        if let textView = textEditorController.textView {
            attributedText = textView.attributedString()
        }
    }
#else
    private func refreshTextFromEditor() {}
#endif

    private func updateContentIndicator(for text: NSAttributedString) {
        let key = DateUtils.dateKey(from: selectedDate)
        let trimmed = text.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            datesWithContent.remove(key)
        } else {
            datesWithContent.insert(key)
        }
    }
    
    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [self] in saveImmediately() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func saveImmediately() {
        refreshTextFromEditor()
        pendingSave?.cancel()
        pendingSave = nil
        let dateKey = DateUtils.dateKey(from: selectedDate)
        let trimmed = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            storage.saveEntry(nil, for: dateKey)
            datesWithContent.remove(dateKey)
        } else if let data = rtfData(from: attributedText) {
            storage.saveEntry(data, for: dateKey)
            datesWithContent.insert(dateKey)
        }
    }

    private func loadFromStorage() {
        datesWithContent = storage.allDateKeys()
        updateTextContent()
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
    
    private func toggleBulletedList() {
        textEditorController.toggleBulletedList()
    }
    
}

#if os(macOS)
final class FormattingTextView: NSTextView {
    var onBoldCommand: (() -> Void)?
    var onItalicCommand: (() -> Void)?
    var onIndentCommand: (() -> Bool)?
    var onOutdentCommand: (() -> Bool)?
    var onNewlineCommand: (() -> Bool)?
    var onPreviousDay: (() -> Void)?
    var onNextDay: (() -> Void)?
    var onPreviousMonth: (() -> Void)?
    var onNextMonth: (() -> Void)?
    var onGoToToday: (() -> Void)?
    var onPreviousDayWithContent: (() -> Void)?
    var onNextDayWithContent: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), let key = event.charactersIgnoringModifiers {
            switch key {
            case "b", "B":
                onBoldCommand?()
                return
            case "i", "I":
                onItalicCommand?()
                return
            case "[", "{":
                if event.modifierFlags.contains(.option) {
                    onPreviousDayWithContent?()
                } else if event.modifierFlags.contains(.shift) {
                    onPreviousMonth?()
                } else {
                    onPreviousDay?()
                }
                return
            case "]", "}":
                if event.modifierFlags.contains(.option) {
                    onNextDayWithContent?()
                } else if event.modifierFlags.contains(.shift) {
                    onNextMonth?()
                } else {
                    onNextDay?()
                }
                return
            case "t", "T":
                onGoToToday?()
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }

    override func insertTab(_ sender: Any?) {
        if onIndentCommand?() == true {
            return
        }
        super.insertTab(sender)
    }

    override func insertBacktab(_ sender: Any?) {
        if onOutdentCommand?() == true {
            return
        }
        super.insertBacktab(sender)
    }

    override func insertNewline(_ sender: Any?) {
        if onNewlineCommand?() == true {
            return
        }
        super.insertNewline(sender)
    }
}

/// Wraps NSTextView so we can edit attributed text with custom formatting controls.
struct RichTextEditor: NSViewRepresentable {
    @Binding var text: NSAttributedString
    let controller: RichTextEditorController
    let onTextChange: (NSAttributedString) -> Void
    let onFormattingStateChange: (FormattingState) -> Void
    let onNavigateDay: (Int) -> Void
    let onNavigateMonth: (Int) -> Void
    let onGoToToday: () -> Void
    let onNavigateToDayWithContent: (Int) -> Void
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
        controller.refreshBulletStyling()
        textView.typingAttributes = defaultTypingAttributes()
        textView.onBoldCommand = { [weak controller] in
            controller?.toggleBold()
        }
        textView.onItalicCommand = { [weak controller] in
            controller?.toggleItalic()
        }
        textView.onIndentCommand = { [weak controller] in
            return controller?.indentSelection() ?? false
        }
        textView.onOutdentCommand = { [weak controller] in
            return controller?.outdentSelection() ?? false
        }
        textView.onNewlineCommand = { [weak controller] in
            return controller?.handleNewline() ?? false
        }
        textView.onPreviousDay = { onNavigateDay(-1) }
        textView.onNextDay = { onNavigateDay(1) }
        textView.onPreviousMonth = { onNavigateMonth(-1) }
        textView.onNextMonth = { onNavigateMonth(1) }
        textView.onGoToToday = { onGoToToday() }
        textView.onPreviousDayWithContent = { onNavigateToDayWithContent(-1) }
        textView.onNextDayWithContent = { onNavigateToDayWithContent(1) }

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
        controller.refreshBulletStyling()
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
        let fontState: (Bool, Bool)
        let string = textView.string as NSString
        if selectedRange.length == 0 {
            let font = (textView.typingAttributes[.font] as? NSFont) ?? textView.font ?? defaultFont
            let traits = fontManager.traits(of: font)
            let caretBeforeBullet = selectedRange.location < string.length &&
                ListFormatting.isBulletMarker(at: selectedRange.location, in: string)
            let caretAfterBullet = selectedRange.location > 0 &&
                ListFormatting.isBulletMarker(at: selectedRange.location - 1, in: string)
            if caretBeforeBullet {
                fontState = (false, false)
            } else if caretAfterBullet {
                fontState = (false, false)
            } else {
                fontState = (traits.contains(.boldFontMask), traits.contains(.italicFontMask))
            }
        } else {
            var boldValue: Bool?
            var italicValue: Bool?
            var boldMixed = false
            var italicMixed = false
            let storage = textView.textStorage
            string.enumerateSubstrings(in: selectedRange, options: .byComposedCharacterSequences) { _, substringRange, _, stop in
                if ListFormatting.isBulletMarker(at: substringRange.location, in: string) {
                    return
                }
                let baseFont = (storage?.attribute(.font, at: substringRange.location, effectiveRange: nil) as? NSFont) ?? textView.font ?? defaultFont
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
            fontState = (bold, italic)
        }
        let isBulleted = isSelectionBulleted(textView: textView, selection: selectedRange)
        return FormattingState(isBold: fontState.0,
                               isItalic: fontState.1,
                               isBulleted: isBulleted)
    }


    private func isSelectionBulleted(textView: NSTextView,
                                     selection: NSRange) -> Bool {
        guard let textStorage = textView.textStorage else {
            return false
        }
        let string = textStorage.string as NSString
        if string.length == 0 {
            return false
        }
        let clampedLocation = min(selection.location, string.length)
        let targetRange = string.paragraphRange(for: NSRange(location: clampedLocation, length: selection.length))
        if targetRange.length == 0 {
            return false
        }
        var allBulleted = true
        var anyBulleted = false
        string.enumerateSubstrings(in: targetRange, options: .byParagraphs) { _, subrange, _, _ in
            let hasBullet = ListFormatting.hasBullet(in: string, paragraphRange: subrange)
            allBulleted = allBulleted && hasBullet
            anyBulleted = anyBulleted || hasBullet
        }
        return allBulleted && anyBulleted
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
            parent.controller.ensureNeutralTypingAttributesIfNeeded(for: textView)
            let parent = parent
            DispatchQueue.main.async {
                parent.onFormattingStateChange(parent.formattingState(for: textView))
            }
        }

        func textView(_ textView: NSTextView,
                       shouldChangeTextIn affectedRange: NSRange,
                       replacementString: String?) -> Bool {
            parent.controller.textView = textView
            return parent.controller.shouldAllowChange(in: affectedRange,
                                                       replacementString: replacementString,
                                                       textView: textView)
        }
    }
}

private struct ListFormatting {
    static let bulletCharacter = "・"
    static let bulletInsertionString = bulletCharacter
    private static let bulletScalar: unichar = 0x30FB
    private static let legacyBulletScalar: unichar = 0x2022

    struct PrefixMatch {
        let indentLength: Int
        let markerLength: Int
        let trailingWhitespaceLength: Int

        var markerStartOffset: Int { indentLength }
        var markerRange: NSRange { NSRange(location: indentLength, length: markerLength) }
        var removalRange: NSRange {
            NSRange(location: indentLength, length: markerLength + trailingWhitespaceLength)
        }
    }

    static func bulletMatch(in text: NSString, paragraphRange: NSRange) -> PrefixMatch? {
        guard paragraphRange.length > 0 else { return nil }
        let indent = indentLength(in: text, paragraphRange: paragraphRange)
        guard indent < paragraphRange.length else { return nil }
        let bulletLocation = paragraphRange.location + indent
        guard bulletLocation < text.length else { return nil }
        let character = text.character(at: bulletLocation)
        if character == bulletScalar {
            return PrefixMatch(indentLength: indent,
                               markerLength: bulletInsertionString.utf16.count,
                               trailingWhitespaceLength: 0)
        } else if character == legacyBulletScalar {
            var trailingWhitespace = 0
            let nextIndex = bulletLocation + 1
            if nextIndex < paragraphRange.location + paragraphRange.length {
                let nextChar = text.character(at: nextIndex)
                if nextChar == 9 || nextChar == 32 {
                    trailingWhitespace = 1
                }
            }
            return PrefixMatch(indentLength: indent,
                               markerLength: 1,
                               trailingWhitespaceLength: trailingWhitespace)
        }
        return nil
    }

    static func hasBullet(in text: NSString, paragraphRange: NSRange) -> Bool {
        bulletMatch(in: text, paragraphRange: paragraphRange) != nil
    }

    static func bulletMarkerRange(in text: NSString, paragraphRange: NSRange) -> NSRange? {
        guard let match = bulletMatch(in: text, paragraphRange: paragraphRange) else { return nil }
        return NSRange(location: paragraphRange.location + match.markerStartOffset,
                       length: match.markerLength)
    }

    static func bulletRemovalRange(in text: NSString, paragraphRange: NSRange) -> NSRange? {
        guard let match = bulletMatch(in: text, paragraphRange: paragraphRange) else { return nil }
        return NSRange(location: paragraphRange.location + match.markerStartOffset,
                       length: match.markerLength + match.trailingWhitespaceLength)
    }


    static func indentRange(in text: NSString, paragraphRange: NSRange) -> NSRange {
        let length = indentLength(in: text, paragraphRange: paragraphRange)
        return NSRange(location: paragraphRange.location, length: length)
    }

    private static func indentLength(in text: NSString, paragraphRange: NSRange) -> Int {
        guard paragraphRange.length > 0 else { return 0 }
        var offset = 0
        while offset < paragraphRange.length {
            let char = text.character(at: paragraphRange.location + offset)
            if char == 9 || char == 32 { // tab or space
                offset += 1
            } else {
                break
            }
        }
        return offset
    }

    static func isBulletMarker(at location: Int, in text: NSString) -> Bool {
        guard location >= 0, location < text.length else { return false }
        let char = text.character(at: location)
        guard char == bulletScalar || char == legacyBulletScalar else { return false }
        var index = location - 1
        while index >= 0 {
            let previous = text.character(at: index)
            if previous == 10 || previous == 13 { // newline
                break
            }
            if previous != 9 && previous != 32 { // non-whitespace before bullet
                return false
            }
            index -= 1
        }
        return true
    }

    @discardableResult
    static func normalizeBullet(in textStorage: NSTextStorage,
                                paragraphRange: NSRange) -> PrefixMatch? {
        func currentMatch() -> PrefixMatch? {
            let updatedString = textStorage.string as NSString
            return bulletMatch(in: updatedString, paragraphRange: paragraphRange)
        }

        guard let match = currentMatch() else { return nil }
        var updatedString = textStorage.string as NSString
        let markerLocation = paragraphRange.location + match.markerStartOffset
        if markerLocation >= updatedString.length {
            return nil
        }
        let currentChar = updatedString.character(at: markerLocation)
        if currentChar != bulletScalar {
            textStorage.replaceCharacters(in: NSRange(location: markerLocation, length: match.markerLength),
                                          with: bulletInsertionString)
        }
        if match.trailingWhitespaceLength > 0 {
            let trailingLocation = markerLocation + match.markerLength
            let safeLength = min(match.trailingWhitespaceLength,
                                 max(0, textStorage.length - trailingLocation))
            if safeLength > 0 {
                textStorage.deleteCharacters(in: NSRange(location: trailingLocation, length: safeLength))
            }
        }
        updatedString = textStorage.string as NSString
        return bulletMatch(in: updatedString, paragraphRange: paragraphRange)
    }
}

/// Controls formatting commands sent from SwiftUI buttons to the underlying NSTextView.
final class RichTextEditorController: ObservableObject {
    weak var textView: NSTextView? {
        didSet { applyPendingFocusIfNeeded() }
    }
    private var pendingFocusRequest = false

    func toggleBold() {
        applyFontTrait(.boldFontMask)
    }

    func toggleItalic() {
        applyFontTrait(.italicFontMask)
    }

    func toggleBulletedList() {
        guard let textView, let textStorage = textView.textStorage else { return }
        let selection = textView.selectedRange()
        let string = textStorage.string as NSString
        if string.length == 0 {
            insertBulletAtCursor(at: selection.location)
            return
        }
        let clampedLocation = min(selection.location, string.length)
        let safeLength = min(selection.length, max(0, string.length - clampedLocation))
        let baseRange = NSRange(location: clampedLocation, length: safeLength)
        let selectionRange = string.paragraphRange(for: baseRange)
        let paragraphRanges = paragraphRanges(in: selectionRange, baseString: string)
        if paragraphRanges.isEmpty {
            insertBulletAtCursor(at: selection.location)
            return
        }
        let shouldRemove = paragraphRanges.allSatisfy { ListFormatting.hasBullet(in: string, paragraphRange: $0) }
        var offset = 0
        var cursorDelta = 0
        for range in paragraphRanges {
            let adjustedRange = NSRange(location: range.location + offset,
                                        length: range.length)
            if shouldRemove {
                let removed = removeBullet(in: adjustedRange, textStorage: textStorage)
                offset -= removed
                if range.location <= selection.location {
                    cursorDelta -= removed
                }
            } else {
                let removedExisting = removeBullet(in: adjustedRange, textStorage: textStorage)
                offset -= removedExisting
                if range.location <= selection.location {
                    cursorDelta -= removedExisting
                }
                let inserted = insertBullet(in: adjustedRange, textView: textView)
                offset += inserted
                if range.location <= selection.location {
                    cursorDelta += inserted
                }
            }
        }
        let newSelection: NSRange
        if selection.length == 0 {
            newSelection = NSRange(location: max(0, selection.location + cursorDelta), length: 0)
        } else {
            newSelection = NSRange(location: selectionRange.location,
                                   length: selectionRange.length + offset)
        }
        textView.setSelectedRange(newSelection)
        normalizeTypingAttributesAfterListPrefix()
        textView.didChangeText()
    }

    func refreshBulletStyling() {
        guard let textView else { return }
        enforceBulletStyle(in: textView)
    }

    private func applyFontTrait(_ trait: NSFontTraitMask) {
        guard let textView else { return }
        let fontManager = NSFontManager.shared
        let selections = textView.selectedRanges.compactMap { $0.rangeValue }

        if selections.isEmpty {
            updateTypingAttributes(for: textView, trait: trait, fontManager: fontManager)
            return
        }

        let string = textView.string as NSString
        for range in selections {
            if range.length == 0 {
                updateTypingAttributes(for: textView, trait: trait, fontManager: fontManager)
                continue
            }
            applyTrait(trait,
                       to: range,
                       textView: textView,
                       fontManager: fontManager,
                       string: string)
        }
        enforceBulletStyle(in: textView)
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

    private func paragraphRanges(in range: NSRange,
                                  baseString: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        baseString.enumerateSubstrings(in: range, options: .byParagraphs) { _, subrange, _, _ in
            ranges.append(subrange)
        }
        return ranges
    }

    private func insertBulletAtCursor(at location: Int) {
        guard let textView, let textStorage = textView.textStorage else { return }
        let string = textStorage.string as NSString
        let safeLocation = min(location, string.length)
        let paragraphRange = string.paragraphRange(for: NSRange(location: safeLocation, length: 0))
        _ = insertBullet(in: paragraphRange, textView: textView)
        let updatedString = textStorage.string as NSString
        if let markerRange = ListFormatting.bulletMarkerRange(in: updatedString, paragraphRange: paragraphRange) {
            textView.setSelectedRange(NSRange(location: markerRange.location + markerRange.length, length: 0))
        } else {
            textView.setSelectedRange(NSRange(location: min(safeLocation + ListFormatting.bulletInsertionString.utf16.count, textStorage.length), length: 0))
        }
        normalizeTypingAttributesAfterListPrefix()
        textView.didChangeText()
    }

    @discardableResult
    private func insertBullet(in paragraphRange: NSRange, textView: NSTextView) -> Int {
        guard let textStorage = textView.textStorage else { return 0 }
        let string = textStorage.string as NSString
        let indent = ListFormatting.indentRange(in: string, paragraphRange: paragraphRange)
        let insertionLocation = min(paragraphRange.location + indent.length, textStorage.length)
        return insertBulletDirectly(at: insertionLocation, textView: textView)
    }

    @discardableResult
    private func insertBulletDirectly(at location: Int, textView: NSTextView) -> Int {
        guard let textStorage = textView.textStorage else { return 0 }
        let safeLocation = min(location, textStorage.length)
        var attributes = attributesForInsertion(at: safeLocation, textView: textView)
        let baseFont = (attributes[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 18)
        let fontManager = NSFontManager.shared
        let nonItalic = fontManager.convert(baseFont, toNotHaveTrait: .italicFontMask)
        let boldFont = fontManager.convert(nonItalic, toHaveTrait: .boldFontMask)
        attributes[.font] = boldFont
        let attributedPrefix = NSAttributedString(string: ListFormatting.bulletInsertionString,
                                                  attributes: attributes)
        textStorage.insert(attributedPrefix, at: safeLocation)
        return ListFormatting.bulletInsertionString.utf16.count
    }

    @discardableResult
    private func removeBullet(in range: NSRange, textStorage: NSTextStorage) -> Int {
        let currentString = textStorage.string as NSString
        guard range.location <= currentString.length else { return 0 }
        let cappedEnd = min(range.location + range.length, currentString.length)
        let paragraphRange = NSRange(location: range.location, length: max(0, cappedEnd - range.location))
        guard let removalRange = ListFormatting.bulletRemovalRange(in: currentString, paragraphRange: paragraphRange) else { return 0 }
        let safeLength = min(removalRange.length, textStorage.length - removalRange.location)
        if safeLength <= 0 { return 0 }
        textStorage.deleteCharacters(in: NSRange(location: removalRange.location, length: safeLength))
        return safeLength
    }

    private func attributesForInsertion(at location: Int, textView: NSTextView) -> [NSAttributedString.Key: Any] {
        guard let textStorage = textView.textStorage else { return textView.typingAttributes }
        if location < textStorage.length {
            return textStorage.attributes(at: location, effectiveRange: nil)
        }
        return textView.typingAttributes
    }

    private func neutralAttributesForListInsertion(at location: Int,
                                                   textView: NSTextView) -> [NSAttributedString.Key: Any] {
        var attributes = attributesForInsertion(at: location, textView: textView)
        let baseFont = (attributes[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 18)
        let fontManager = NSFontManager.shared
        let nonBold = fontManager.convert(baseFont, toNotHaveTrait: .boldFontMask)
        let neutralFont = fontManager.convert(nonBold, toNotHaveTrait: .italicFontMask)
        attributes[.font] = neutralFont
        return attributes
    }

    func shouldAllowChange(in affectedRange: NSRange,
                           replacementString: String?,
                           textView: NSTextView) -> Bool {
        guard let textStorage = textView.textStorage else { return true }
        if affectedRange.location > textStorage.length { return false }
        guard textStorage.length > 0 else { return true }
        if handleAsteriskShortcut(in: affectedRange,
                                  replacementString: replacementString,
                                  textView: textView) {
            return false
        }
        let string = textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: affectedRange)
        if affectedRange.length == 0,
           ListFormatting.isBulletMarker(at: affectedRange.location, in: string) {
            return false
        }
        let replacement = replacementString ?? ""
        handleBulletDeletionIfNeeded(in: affectedRange,
                                     replacementString: replacementString,
                                     paragraphRange: paragraphRange,
                                     string: string)
        guard let markerRange = ListFormatting.bulletMarkerRange(in: string, paragraphRange: paragraphRange) else {
            return true
        }
        let guardLength = markerRange.location - paragraphRange.location
        if guardLength <= 0 { return true }
        let guardRange = NSRange(location: paragraphRange.location, length: guardLength)
        let intersectsGuard: Bool
        if affectedRange.length == 0 {
            intersectsGuard = NSLocationInRange(affectedRange.location, guardRange)
        } else {
            intersectsGuard = NSIntersectionRange(affectedRange, guardRange).length > 0
        }
        guard intersectsGuard else { return true }
        if replacement.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.normalizeTypingAttributesAfterListPrefix()
            }
            return true
        }
        let allowedTabs = CharacterSet(charactersIn: "\t")
        let isOnlyTabs = replacement.unicodeScalars.allSatisfy { allowedTabs.contains($0) }
        return isOnlyTabs
    }

    private func handleAsteriskShortcut(in affectedRange: NSRange,
                                        replacementString: String?,
                                        textView: NSTextView) -> Bool {
        guard replacementString == " ",
              affectedRange.length == 0,
              affectedRange.location > 0,
              let textStorage = textView.textStorage else { return false }
        let string = textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: NSRange(location: affectedRange.location - 1, length: 0))
        guard affectedRange.location - paragraphRange.location == 1 else { return false }
        guard string.character(at: paragraphRange.location) == 42 else { return false } // '*'
        textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: 1))
        textView.setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
        insertBulletAtCursor(at: paragraphRange.location)
        return true
    }

    private func handleBulletDeletionIfNeeded(in affectedRange: NSRange,
                                              replacementString: String?,
                                              paragraphRange: NSRange,
                                              string: NSString) {
        guard (replacementString ?? "").isEmpty else { return }
        var removedBullet = false
        string.enumerateSubstrings(in: paragraphRange, options: .byParagraphs) { _, subrange, _, stop in
            guard let markerRange = ListFormatting.bulletMarkerRange(in: string, paragraphRange: subrange) else { return }
            if NSIntersectionRange(markerRange, affectedRange).length > 0 {
                removedBullet = true
                stop.pointee = true
            }
        }
        guard removedBullet else { return }
        DispatchQueue.main.async { [weak self] in
            self?.normalizeTypingAttributesAfterListPrefix()
        }
    }

    @discardableResult
    func indentSelection() -> Bool {
        guard let textView, let textStorage = textView.textStorage else { return false }
        let string = textStorage.string as NSString
        if string.length == 0 { return false }
        let selection = textView.selectedRange()
        let clampedLocation = min(selection.location, string.length)
        let safeLength = min(selection.length, max(0, string.length - clampedLocation))
        let baseRange = string.paragraphRange(for: NSRange(location: clampedLocation, length: safeLength))
        var paragraphs = paragraphRanges(in: baseRange, baseString: string)
        if paragraphs.isEmpty {
            paragraphs = [baseRange]
        }
        var offset = 0
        var cursorDelta = 0
        var modified = false
        for range in paragraphs {
            let adjustedRange = NSRange(location: range.location + offset,
                                        length: range.length)
            let currentString = textStorage.string as NSString
            let hasList = ListFormatting.hasBullet(in: currentString, paragraphRange: adjustedRange)
            if !hasList { continue }
            let attributes = neutralAttributesForListInsertion(at: adjustedRange.location, textView: textView)
            textStorage.insert(NSAttributedString(string: "\t", attributes: attributes), at: adjustedRange.location)
            offset += 1
            if range.location <= selection.location {
                cursorDelta += 1
            }
            modified = true
        }
        guard modified else { return false }
        let newSelection: NSRange
        if selection.length == 0 {
            newSelection = NSRange(location: selection.location + cursorDelta, length: 0)
        } else {
            newSelection = NSRange(location: baseRange.location, length: baseRange.length + offset)
        }
        textView.setSelectedRange(newSelection)
        normalizeTypingAttributesAfterListPrefix()
        textView.didChangeText()
        return true
    }

    @discardableResult
    func outdentSelection() -> Bool {
        guard let textView, let textStorage = textView.textStorage else { return false }
        let string = textStorage.string as NSString
        if string.length == 0 { return false }
        let selection = textView.selectedRange()
        let clampedLocation = min(selection.location, string.length)
        let safeLength = min(selection.length, max(0, string.length - clampedLocation))
        let baseRange = string.paragraphRange(for: NSRange(location: clampedLocation, length: safeLength))
        var paragraphs = paragraphRanges(in: baseRange, baseString: string)
        if paragraphs.isEmpty {
            paragraphs = [baseRange]
        }
        var offset = 0
        var cursorDelta = 0
        var modified = false
        for range in paragraphs {
            let adjustedRange = NSRange(location: range.location + offset,
                                        length: range.length)
            let currentString = textStorage.string as NSString
            let hasList = ListFormatting.hasBullet(in: currentString, paragraphRange: adjustedRange)
            if !hasList { continue }
            let removed = removeIndent(in: adjustedRange, textStorage: textStorage)
            if removed > 0 {
                offset -= removed
                if range.location <= selection.location {
                    cursorDelta -= removed
                }
                modified = true
            }
        }
        guard modified else { return false }
        let newSelection: NSRange
        if selection.length == 0 {
            newSelection = NSRange(location: max(0, selection.location + cursorDelta), length: 0)
        } else {
            newSelection = NSRange(location: baseRange.location,
                                   length: max(0, baseRange.length + offset))
        }
        textView.setSelectedRange(newSelection)
        normalizeTypingAttributesAfterListPrefix()
        textView.didChangeText()
        return true
    }

    func handleNewline() -> Bool {
        guard let textView, let textStorage = textView.textStorage else { return false }
        let selection = textView.selectedRange()
        if selection.length > 0 { return false }
        let string = textStorage.string as NSString
        if string.length == 0 { return false }
        let clampedLocation = min(selection.location, string.length)
        let paragraphRange = string.paragraphRange(for: NSRange(location: clampedLocation, length: 0))
        if let match = ListFormatting.bulletMatch(in: string, paragraphRange: paragraphRange) {
            if bulletLineIsEmpty(match: match, paragraphRange: paragraphRange, string: string) {
                clearEmptyBulletLine(match: match,
                                     paragraphRange: paragraphRange,
                                     textView: textView,
                                     textStorage: textStorage)
            } else {
                insertBulletNewline(match: match,
                                    paragraphRange: paragraphRange,
                                    caretLocation: selection.location,
                                    textView: textView,
                                    textStorage: textStorage)
            }
            textView.didChangeText()
            return true
        }
        return false
    }

    private func removeIndent(in paragraphRange: NSRange, textStorage: NSTextStorage) -> Int {
        let string = textStorage.string as NSString
        guard paragraphRange.length > 0, paragraphRange.location < string.length else { return 0 }
        var removed = 0
        while paragraphRange.location + removed < string.length {
            let character = string.character(at: paragraphRange.location + removed)
            if character == 9 || character == 32 {
                removed += 1
            } else {
                break
            }
        }
        if removed > 0 {
            let safeRemoval = min(removed, textStorage.length - paragraphRange.location)
            textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: safeRemoval))
            return safeRemoval
        }
        return 0
    }

    private func bulletLineIsEmpty(match: ListFormatting.PrefixMatch,
                                   paragraphRange: NSRange,
                                   string: NSString) -> Bool {
        let contentStart = paragraphRange.location + match.markerStartOffset + match.markerLength
        let end = paragraphRange.location + paragraphRange.length
        if contentStart >= end { return true }
        let range = NSRange(location: contentStart, length: end - contentStart)
        let content = string.substring(with: range)
        return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }


    private func insertBulletNewline(match: ListFormatting.PrefixMatch,
                                     paragraphRange: NSRange,
                                     caretLocation: Int,
                                     textView: NSTextView,
                                     textStorage: NSTextStorage) {
        let originalString = textStorage.string as NSString
        let indentRange = NSRange(location: paragraphRange.location, length: match.indentLength)
        let indentString = indentRange.length > 0 ? originalString.substring(with: indentRange) : ""
        let attributes = attributesForInsertion(at: caretLocation, textView: textView)
        textStorage.insert(NSAttributedString(string: "\n", attributes: attributes), at: caretLocation)
        var insertionPoint = caretLocation + 1
        if !indentString.isEmpty {
            let indentAttributes = neutralAttributesForListInsertion(at: insertionPoint, textView: textView)
            textStorage.insert(NSAttributedString(string: indentString, attributes: indentAttributes), at: insertionPoint)
            insertionPoint += indentString.utf16.count
        }
        let bulletLength = insertBulletDirectly(at: insertionPoint, textView: textView)
        let refreshedString = textStorage.string as NSString
        let caretParagraphRange = refreshedString.paragraphRange(for: NSRange(location: insertionPoint, length: max(1, bulletLength)))
        if let markerRange = ListFormatting.bulletMarkerRange(in: refreshedString, paragraphRange: caretParagraphRange) {
            textView.setSelectedRange(NSRange(location: markerRange.location + markerRange.length, length: 0))
        } else {
            textView.setSelectedRange(NSRange(location: min(insertionPoint + bulletLength, textStorage.length), length: 0))
        }
        normalizeTypingAttributesAfterListPrefix()
    }


    private func clearEmptyBulletLine(match: ListFormatting.PrefixMatch,
                                      paragraphRange: NSRange,
                                      textView: NSTextView,
                                      textStorage: NSTextStorage) {
        let removalLength = min(match.indentLength + match.markerLength + match.trailingWhitespaceLength,
                                textStorage.length - paragraphRange.location)
        if removalLength > 0 {
            textStorage.deleteCharacters(in: NSRange(location: paragraphRange.location, length: removalLength))
        }
        textView.setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
        normalizeTypingAttributesAfterListPrefix()
    }


    private func applyTrait(_ trait: NSFontTraitMask,
                            to range: NSRange,
                            textView: NSTextView,
                            fontManager: NSFontManager,
                            string: NSString) {
        guard let textStorage = textView.textStorage else { return }
        let sanitizedRanges = rangesExcludingBullets(in: range, string: string)
        for sanitizedRange in sanitizedRanges where sanitizedRange.length > 0 {
            textStorage.enumerateAttribute(.font, in: sanitizedRange, options: []) { value, subrange, _ in
                let font = (value as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 18)
                let updatedFont = toggledFont(from: font, trait: trait, fontManager: fontManager)
                textStorage.addAttribute(.font, value: updatedFont, range: subrange)
            }
        }
    }

    private func rangesExcludingBullets(in range: NSRange, string: NSString) -> [NSRange] {
        var segments: [NSRange] = []
        let end = range.location + range.length
        var index = range.location
        var currentStart: Int?
        while index < end {
            if ListFormatting.isBulletMarker(at: index, in: string) {
                if let start = currentStart {
                    segments.append(NSRange(location: start, length: index - start))
                    currentStart = nil
                }
                index += 1
                continue
            }
            if currentStart == nil {
                currentStart = index
            }
            index += 1
        }
        if let start = currentStart {
            segments.append(NSRange(location: start, length: index - start))
        }
        return segments
    }

    private func enforceBulletStyle(in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        var location = 0
        while location < textStorage.length {
            let currentString = textStorage.string as NSString
            let paragraphRange = currentString.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphRange.length > 0 else {
                location += 1
                continue
            }
            if let match = ListFormatting.normalizeBullet(in: textStorage, paragraphRange: paragraphRange) {
                let markerRange = NSRange(location: paragraphRange.location + match.markerStartOffset,
                                          length: match.markerLength)
                var attributes = textStorage.attributes(at: markerRange.location, effectiveRange: nil)
                let baseFont = (attributes[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 18)
                let nonItalic = NSFontManager.shared.convert(baseFont, toNotHaveTrait: .italicFontMask)
                let boldFont = NSFontManager.shared.convert(nonItalic, toHaveTrait: .boldFontMask)
                attributes[.font] = boldFont
                textStorage.setAttributes(attributes, range: markerRange)
                normalizeTypingAttributesAfterListPrefix()
            }
            let updatedString = textStorage.string as NSString
            let updatedRange = updatedString.paragraphRange(for: NSRange(location: paragraphRange.location, length: 0))
            location = updatedRange.location + updatedRange.length
        }
    }

    private func normalizeTypingAttributesAfterListPrefix() {
        guard let textView else { return }
        var attributes = textView.typingAttributes
        let baseFont = (attributes[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 18)
        let fontManager = NSFontManager.shared
        let nonBold = fontManager.convert(baseFont, toNotHaveTrait: .boldFontMask)
        let neutralFont = fontManager.convert(nonBold, toNotHaveTrait: .italicFontMask)
        attributes[.font] = neutralFont
        textView.typingAttributes = attributes
    }

    func ensureNeutralTypingAttributesIfNeeded(for textView: NSTextView) {
        guard textView.selectedRange.length == 0 else { return }
        guard let textStorage = textView.textStorage else { return }
        let location = textView.selectedRange.location
        let string = textStorage.string as NSString
        guard string.length > 0 else { return }
        if location > 0 && location <= string.length,
           ListFormatting.isBulletMarker(at: location - 1, in: string) {
            var attributes = textView.typingAttributes
            let baseFont = (attributes[.font] as? NSFont) ?? textView.font ?? NSFont.systemFont(ofSize: 18)
            let fontManager = NSFontManager.shared
            let nonBold = fontManager.convert(baseFont, toNotHaveTrait: .boldFontMask)
            let neutralFont = fontManager.convert(nonBold, toNotHaveTrait: .italicFontMask)
            attributes[.font] = neutralFont
            textView.typingAttributes = attributes
        }
    }

    func focusEditor() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let textView = self.textView, let window = textView.window {
                window.makeFirstResponder(textView)
            } else {
                self.pendingFocusRequest = true
            }
        }
    }

    private func applyPendingFocusIfNeeded() {
        guard pendingFocusRequest, let textView else { return }
        pendingFocusRequest = false
        DispatchQueue.main.async { [weak textView] in
            textView?.window?.makeFirstResponder(textView)
        }
    }

}
#else
/// Minimal fallback so the view still compiles on non-macOS platforms.
struct RichTextEditor: View {
    @Binding var text: NSAttributedString
    let controller: RichTextEditorController
    let onTextChange: (NSAttributedString) -> Void
    let onFormattingStateChange: (FormattingState) -> Void
    let onNavigateDay: (Int) -> Void
    let onNavigateMonth: (Int) -> Void
    let onGoToToday: () -> Void

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
    func toggleBulletedList() {}
}
#endif

struct CalendarGrid: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    @Binding var datesWithContent: Set<String>
    let availableWidth: CGFloat
    let onBeforeDayChange: (() -> Void)?
    let onDaySelection: (() -> Void)?
    let calendar = Calendar.current
    
    @State private var hoveredDay: Int? = nil // Track the hovered day
    @State private var calendarGridDensity: CGFloat = 80 // I find the value 80 makes the grid as dense as I like

    init(selectedDate: Binding<Date>,
         currentMonth: Binding<Date>,
         datesWithContent: Binding<Set<String>>,
         availableWidth: CGFloat,
         onBeforeDayChange: (() -> Void)? = nil,
         onDaySelection: (() -> Void)? = nil) {
        _selectedDate = selectedDate
        _currentMonth = currentMonth
        _datesWithContent = datesWithContent
        self.availableWidth = availableWidth
        self.onBeforeDayChange = onBeforeDayChange
        self.onDaySelection = onDaySelection
    }
    
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
                                    onBeforeDayChange?()
                                    selectedDate = newDate
                                    onDaySelection?()
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
            return datesWithContent.contains(dateKey)
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
    let activeColor: Color
    let inactiveColor: Color

    init(buttonAction: @escaping () -> Void,
         formattingOption: TextFormat,
         isActive: Bool = false,
         activeColor: Color,
         inactiveColor: Color) {
        self.buttonAction = buttonAction
        self.formattingOption = formattingOption
        self.isActive = isActive
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }
    
    private let fontSize: CGFloat = 18
    private let frameSize: CGFloat = 30
    private let inactiveShadowColor: Color = Color.black.opacity(0.3)
    private let activeShadowColor: Color = Color(red: 60/255, green: 90/255, blue: 140/255).opacity(0.35)
    private let inactiveIconColor: Color = .black
    private let activeIconColor: Color = Color(red: 225/255, green: 238/255, blue: 255/255)
    private let buttonShape: RoundedRectangle = RoundedRectangle(cornerRadius: 5)
    
    enum TextFormat {
        case bold
        case italic
        case bulletList
        
        var systemImageName: String {
            switch self {
            case .bold: return "bold"
            case .italic: return "italic"
            case .bulletList: return "list.bullet"
            }
        }
    }
    
    var body: some View {
        Button(action: { buttonAction() }) {
            Image(systemName: formattingOption.systemImageName)
                .font(.system(size: fontSize))
                .frame(width: frameSize, height: frameSize)
                .background(buttonShape
                    .fill(isActive ? activeColor : inactiveColor)
                    .shadow(color: isActive ? activeShadowColor : inactiveShadowColor, radius: 2, x: 2, y: 2))
                .foregroundStyle(isActive ? activeIconColor : inactiveIconColor)
                .contentShape(Rectangle())
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

