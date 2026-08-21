import SwiftUI

/// ライブラリ(本棚・トレーニングメニュー/種目・科目)
struct LibraryView: View {
    @State private var selection: ActivityCategory = EnabledCategories.load().first ?? .reading
    @State private var categories: [ActivityCategory] = EnabledCategories.load()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("カテゴリ", selection: $selection) {
                    ForEach(categories) { category in
                        Text(category.label).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onAppear {
                    categories = EnabledCategories.load()
                    // 選択中のカテゴリを設定で非表示にした場合は先頭に戻す
                    if !categories.contains(selection), let first = categories.first {
                        selection = first
                    }
                }

                switch selection {
                case .reading:
                    BookshelfView()
                case .training:
                    TrainingLibraryView()
                case .study:
                    SubjectListView()
                }
            }
            .background(Theme.paper)
            .navigationTitle("ライブラリ")
        }
    }
}
