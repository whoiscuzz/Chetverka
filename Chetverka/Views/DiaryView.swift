import SwiftUI

struct DiaryView: View {

    @EnvironmentObject var diaryVM: DiaryViewModel
    @State private var selectedWeek = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                weekHeader

                TabView(selection: $selectedWeek) {
                    ForEach(Array(diaryVM.weeks.enumerated()), id: \.offset) { index, week in
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(week.days) { day in
                                    DayCard(day: day)
                                }
                            }
                            .padding()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Дневник")
            .onAppear {
                // Устанавливаем текущую неделю при первом появлении
                self.selectedWeek = diaryVM.findCurrentWeekIndex(in: diaryVM.weeks)
            }
            .onChange(of: diaryVM.weeks) { _, newWeeks in
                // Обновляем текущую неделю, если данные изменились (например, при загрузке)
                self.selectedWeek = diaryVM.findCurrentWeekIndex(in: newWeeks)
            }
        }
    }


    private var weekHeader: some View {
        HStack {
            Button {
                if selectedWeek > 0 {
                    selectedWeek -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(selectedWeek == 0)

            Spacer()

            if diaryVM.weeks.indices.contains(selectedWeek) {
                Text(diaryVM.weeks[selectedWeek].title)
                    .font(.headline)
            }

            Spacer()

            Button {
                if selectedWeek < diaryVM.weeks.count - 1 {
                    selectedWeek += 1
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(selectedWeek == diaryVM.weeks.count - 1)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

