import SwiftUI

/// ライブラリ(本棚・トレーニングメニュー/種目・科目)
struct LibraryView: View {
    @State private var selection: ActivityCategory = .reading

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("カテゴリ", selection: $selection) {
                    ForEach(ActivityCategory.allCases) { category in
                        Text(category.label).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

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
