import SwiftUI

struct AirplaneBannerView: View {
    let meetingTitle: String
    let timeRange: String?
    let onComplete: () -> Void

    @AppStorage("flyoverDurationSeconds") private var flyoverDurationSeconds = 20.0
    @State private var offsetX: CGFloat = 0

    private var duration: Double {
        min(max(flyoverDurationSeconds, 8), 60)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.clear

                HStack(alignment: .center, spacing: 0) {
                    MeetingBanner(title: meetingTitle, timeRange: timeRange)

                    TowLine()

                    FlyoverPlaneView()
                }
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: offsetX)
            }
            .onAppear {
                offsetX = -geo.size.width
                withAnimation(.linear(duration: duration)) {
                    offsetX = geo.size.width
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
                    onComplete()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Banner (straight rectangle, reference style)

private struct MeetingBanner: View {
    let title: String
    let timeRange: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let timeRange, !timeRange.isEmpty {
                Text(timeRange)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .frame(minWidth: 260, maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(FlyoverPalette.banner)
        )
    }
}

private struct TowLine: View {
    var body: some View {
        Rectangle()
            .fill(FlyoverPalette.banner)
            .frame(width: 22, height: 4)
    }
}

enum FlyoverPalette {
    /// Light pink banner / fuselage / tow line (reference)
    static let banner = Color(red: 0.97, green: 0.72, blue: 0.8)
    static let planeBody = Color(red: 0.98, green: 0.78, blue: 0.84)
    /// Darker magenta wings & tail
    static let planeWing = Color(red: 0.82, green: 0.28, blue: 0.52)
}

#Preview {
    AirplaneBannerView(meetingTitle: "Team sync", timeRange: "10:00 AM – 10:30 AM") {}
        .frame(width: 900, height: 120)
        .background(Color.gray.opacity(0.15))
}
