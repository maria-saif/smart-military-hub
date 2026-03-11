import SwiftUI

struct CommanderTrainingView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: 0x1A2332), Color(hex: 0x0E1116)]),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("إدارة التدريب")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 30)
                    
                    VStack(spacing: 20) {
                        NavigationLink(destination: ScheduleManagementView()) {
                            CustomButton(
                                title: "إدارة الجدول والتدريب",
                                icon: "calendar.badge.clock",
                                color: Color.green
                            )
                        }
                        
                        NavigationLink(destination: TrainingResultsView()) {
                            CustomButton(
                                title: "عرض نتائج التدريب",
                                icon: "chart.bar.fill",
                                color: Color.blue
                            )
                        }
                        
                        NavigationLink(destination: SoldierEvaluationView()) {
                            CustomButton(
                                title: "تقييم الجنود",
                                icon: "star.circle.fill",
                                color: Color.green
                            )
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 30)
                }
            }
        }
        .navigationTitle("إدارة التدريب")
    }
}

struct CustomButton: View {
    var title: String
    var icon: String
    var color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color)
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

struct CommanderTrainingView_Previews: PreviewProvider {
    static var previews: some View {
        CommanderTrainingView()
    }
}
