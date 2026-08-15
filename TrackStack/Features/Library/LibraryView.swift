import SwiftUI

/// ライブラリ(本棚・トレーニングメニュー/種目・科目・記事クリップ・ポッドキャスト番組)
struct LibraryView: View {
    @State private var selection: ActivityCategory = .reading

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // カテゴリが5つあり segmented では文字が潰れるため、横スクロールのチップで選ぶ
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ActivityCategory.allCases) { category in
                            categoryChip(category)
                        }
                    }
                    .padding(.horizontal)
                }

                switch selection {
                case .reading:
                    BookshelfView()
                case .training:
                    TrainingLibraryView()
                case .study:
                    SubjectListView()
                case .newspaper:
                    ArticleClipListView()
                case .podcast:
                    PodcastShowListView()
                }
            }
            .background(Theme.paper)
            .navigationTitle("ライブラリ")
        }
    }

    private func categoryChip(_ category: ActivityCategory) -> some View {
        let isSelected = selection == category
        return Button {
            selection = category
        } label: {
            Label(category.label, systemImage: category.symbolName)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(
                    Capsule().fill(isSelected ? category.color.opacity(0.18) : Theme.surface)
                )
                .overlay(
                    Capsule().stroke(isSelected ? category.color : Theme.rule, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? category.color : Theme.inkSecondary)
        }
        .buttonStyle(.plain)
    }
}
