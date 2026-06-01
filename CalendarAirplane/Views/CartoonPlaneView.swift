import SwiftUI

/// Flyover plane from `Assets.xcassets` → `FlyoverPlane` (transparent PNG).
struct FlyoverPlaneView: View {
    var body: some View {
        Image("FlyoverPlane")
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fit)
            .frame(width: 88, height: 58)
            .background(Color.clear)
            .shadow(color: FlyoverPalette.planeWing.opacity(0.2), radius: 4, y: 2)
    }
}
