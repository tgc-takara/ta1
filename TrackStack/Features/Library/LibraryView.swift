import SwiftUI

/// ライブラリ(本棚・トレーニングメニュー・科目)。
/// M1 では骨格のみ。各タブの実体は M2 で実装する。
struct LibraryView: View {
    @State private var selection: ActivityCategory = .reading

    var body: some View {
        NavigationStack {
            VStack {
                Picker("カテゴリ", selection: $selection) {
                    ForEach(ActivityCategory.allCases) { category in
                        Text(category.label).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ContentUnavailableView(
                    placeholderTitle,
                    systemImage: selection.symbolName,
                    description: Text("M2 で実装予定")
                )
            }
            .navigationTitle("ライブラリ")
        }
    }

    private var placeholderTitle: String {
        switch selection {
        case .reading: "本棚"
        case .training: "メニュー・種目"
        case .study: "科目・資格"
        }
    }
}
