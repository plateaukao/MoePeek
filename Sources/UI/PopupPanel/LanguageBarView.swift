import Defaults
import SwiftUI

/// Language selection bar with target language picker.
struct LanguageBarView: View {
    @Binding var targetLanguage: String
    @Default(.popupFontSize) private var fontSize

    private var pickerControlSize: ControlSize {
        if fontSize <= 12 { .small }
        else if fontSize <= 16 { .regular }
        else { .large }
    }

    var body: some View {
        Picker("", selection: $targetLanguage) {
            ForEach(SupportedLanguages.all, id: \.code) { code, name in
                Text(name).tag(code)
            }
        }
        .labelsHidden()
        .controlSize(pickerControlSize)
        .fixedSize()
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background { InteractiveMarker() }
    }
}
