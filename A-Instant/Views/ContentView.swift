import SwiftUI

@available(macOS 14.0, *)
struct ContentView: View {
    @StateObject private var promptViewModel = PromptViewModel(selectedText: "", originalApplication: nil)
    
    var body: some View {
        TabView {
            PromptView(viewModel: promptViewModel)
                .tabItem {
                    Label("Prompt", systemImage: "text.bubble")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

@available(macOS 14.0, *)
#Preview {
    ContentView()
} 