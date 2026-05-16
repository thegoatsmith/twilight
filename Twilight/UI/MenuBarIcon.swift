import SwiftUI

struct MenuBarIcon: View {
    let appearance: Appearance

    var body: some View {
        Image(systemName: appearance == .dark ? "moon.stars" : "sun.max")
    }
}
