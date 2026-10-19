import SwiftUI

struct AccentColourView: View {
    @Environment(AccentSettings.self) private var accents
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(accents.selected.previewName).resizable().scaledToFit()
                        .frame(width: 88, height: 88).clipShape(.rect(cornerRadius: 20))
                        .accessibilityLabel("\(accents.selected.title) mosque app icon")
                    Text("\(accents.selected.title)").font(.headline)
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
            } footer: { Text("The accent colour also changes the mosque on your app icon. Each icon uses a plain light or dark background for contrast.") }

            Section("Accent colour") {
                ForEach(AppAccent.allCases) { accent in
                    Button {
                        Task { await accents.choose(accent) }
                    } label: {
                        HStack(spacing: 14) {
                            Circle().fill(accent.color).frame(width: 24, height: 24)
                                .overlay { Circle().stroke(.primary.opacity(0.15), lineWidth: 1) }.accessibilityHidden(true)
                            Text(accent.title).foregroundStyle(.primary)
                            Spacer()
                            if accents.selected == accent { Image(systemName: "checkmark").fontWeight(.semibold) }
                        }.contentShape(Rectangle())
                    }
                    .disabled(accents.isChanging)
                    .accessibilityAddTraits(accents.selected == accent ? [.isSelected] : [])
                }
            }
            if let error = accents.error { Section { Text(error).foregroundStyle(.secondary) } }
        }.navigationTitle("Accent colour").navigationBarTitleDisplayMode(.inline)
    }
}
