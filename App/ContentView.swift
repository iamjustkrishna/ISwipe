import SwiftUI

struct ContentView: View {
    @State private var textInput = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "keyboard")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.orange)
                    .padding(.top, 40)
                
                Text("IndicSwipe Keyboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("To use IndicSwipe, go to Settings > General > Keyboard > Keyboards > Add New Keyboard... and select IndicSwipe. Ensure 'Allow Full Access' is enabled for haptics and telemetry.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 30)
                
                TextField("Test your keyboard here...", text: $textInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .frame(height: 100, alignment: .top)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
