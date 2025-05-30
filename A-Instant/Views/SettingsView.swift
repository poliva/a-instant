import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var activeTab = 0
    @State private var selectedShortcut: Shortcut?
    @State private var showingShortcutCreation = false
    @State private var showingPromptEditor = false
    @State private var editingPrompt: SavedPrompt?
    @State private var promptToDelete: SavedPrompt?
    @State private var showingDeleteConfirmation = false
    @State private var newPromptName = ""
    @State private var newPromptText = ""
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var importErrorMessage = ""
    @State private var showingImportError = false
    
    // Create document directly here since it couldn't be found in scope
    class SavedPromptsDocument: FileDocument {
        static var readableContentTypes: [UTType] { [.json] }
        static var writableContentTypes: [UTType] { [.json] }
        
        var prompts: [SavedPrompt]
        
        init(prompts: [SavedPrompt]) {
            self.prompts = prompts
        }
        
        required init(configuration: ReadConfiguration) throws {
            guard let data = configuration.file.regularFileContents,
                  let prompts = try? JSONDecoder().decode([SavedPrompt].self, from: data)
            else {
                throw CocoaError(.fileReadCorruptFile)
            }
            self.prompts = prompts
        }
        
        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            let data = try JSONEncoder().encode(prompts)
            return FileWrapper(regularFileWithContents: data)
        }
    }
    
    var body: some View {
        TabView(selection: $activeTab) {
            generalSettingsView
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)
            
            apiSettingsView
                .tabItem {
                    Label("API", systemImage: "network")
                }
                .tag(1)
            
            savedPromptsView
                .tabItem {
                    Label("Saved Prompts", systemImage: "keyboard")
                }
                .tag(2)
            
            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .frame(width: 600, height: 580)
        .padding()
        .onDisappear {
            viewModel.saveSettings()
        }
    }
    
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.title)
                .bold()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("A-Instant Trigger Key")
                    .font(.headline)
                
                Picker("Trigger Key", selection: $viewModel.selectedTriggerKey) {
                    ForEach(TriggerKey.allCases) { key in
                        Text(key.rawValue).tag(key)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()
                
                Text("Double-tap this key to activate A-Instant after selecting text")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Application Options")
                    .font(.headline)
                
                Toggle("Check for updates automatically", isOn: $viewModel.enableAutomaticUpdates)
                    .padding(.top, 4)
                
                Text("A-Instant will periodically check for new versions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle("Enable debug logging", isOn: $viewModel.enableDebugLogging)
                    .padding(.top, 8)
                
                Text("Logs detailed information for troubleshooting")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle("Non-destructive processing mode", isOn: $viewModel.nonDestructiveMode)
                    .padding(.top, 8)
                
                Text("Preserve selected text and show AI responses in a separate area")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Startup Options")
                    .font(.headline)
                
                Toggle("Launch A-Instant when you log in", isOn: $viewModel.autoLaunchOnStartup)
                    .padding(.top, 4)
                
                if #available(macOS 13.0, *) {
                    Text("A-Instant will automatically start when you log in to your Mac")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Auto-launch requires macOS 13 or later")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var apiSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("API Settings")
                .font(.title)
                .bold()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Preferred AI Provider")
                    .font(.headline)
                
                Picker("AI Provider", selection: $viewModel.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()
                .onChange(of: viewModel.selectedProvider) { oldValue, newValue in
                    viewModel.refreshModelList()
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Preferred Model")
                        .font(.headline)
                    
                    if viewModel.isLoadingModels {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.leading, 5)
                    }
                    
                    Button(action: {
                        viewModel.saveSettings()
                        viewModel.refreshModelList()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if let error = viewModel.modelLoadError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                } else {
                    Picker("Model", selection: Binding(
                        get: { viewModel.currentModel },
                        set: { viewModel.setCurrentModel($0) }
                    )) {
                        if viewModel.displayModels.isEmpty {
                            Text("No available models").tag("")
                        } else {
                            ForEach(viewModel.displayModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .labelsHidden()
                    
                    Text("Select your preferred model from the provider")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .padding(.vertical, 10)
            
            if viewModel.selectedProvider != .ollama && viewModel.selectedProvider != .genericOpenAI {
                Text("API Key")
                    .font(.headline)

                SecureField("Enter API Key", text: apiKeyBinding())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 10)
                
                Text("Enter your API key for \(viewModel.selectedProvider.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    if let url = apiKeyManagementURL() {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 2) {
                        Text("Get API Key")
                            .font(.caption)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
                
            } else if viewModel.selectedProvider == .ollama {
                Text("Ollama Endpoint")
                    .font(.headline)
                
                TextField("Endpoint URL", text: $viewModel.ollamaEndpoint)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 10)
                
                Text("Enter your Ollama server endpoint (default: http://localhost:11434)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    if let url = apiKeyManagementURL() {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 2) {
                        Text("Download Ollama")
                            .font(.caption)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
            } else if viewModel.selectedProvider == .genericOpenAI {
                VStack(alignment: .leading, spacing: 10) {
                    Text("API Key")
                        .font(.headline)
                    
                    SecureField("Enter API Key", text: $viewModel.genericOpenAIKey)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 10)
                    
                    Text("API Endpoint")
                        .font(.headline)
                        .padding(.top, 10)
                    
                    TextField("API Endpoint URL", text: $viewModel.genericOpenAIEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 10)
                    
                    Text("The base URL of the OpenAI-compatible API")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var savedPromptsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Saved Prompts")
                .font(.title)
                .bold()
            
            Divider()
            
            TextField("Search prompts...", text: $viewModel.promptSearchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, 10)
            
            if viewModel.savedPrompts.isEmpty {
                VStack {
                    Text("No saved prompts yet")
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.filteredSavedPrompts) { prompt in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(prompt.name)
                                    .font(.headline)
                                
                                Text(prompt.promptText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                editingPrompt = prompt
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                promptToDelete = prompt
                                showingDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { indices, destination in
                        viewModel.savedPrompts.move(fromOffsets: indices, toOffset: destination)
                        viewModel.saveSettings()
                    }
                    .onDelete { indexSet in
                        viewModel.savedPrompts.remove(atOffsets: indexSet)
                        viewModel.saveSettings()
                    }
                }
                .listStyle(PlainListStyle())
                .confirmationDialog(
                    "Are you sure you want to delete this prompt?",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        if let prompt = promptToDelete, 
                           let index = viewModel.savedPrompts.firstIndex(where: { $0.id == prompt.id }) {
                            viewModel.savedPrompts.remove(at: index)
                            viewModel.saveSettings()
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        promptToDelete = nil
                    }
                }
            }
            
            HStack {
                Spacer()
                
                Button(action: {
                    exportPrompts()
                }) {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                        Text("Export Prompts")
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.vertical, 8)
                .padding(.trailing, 8)
                
                Button(action: {
                    importPrompts()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Import Prompts")
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.vertical, 8)
                .padding(.trailing, 8)
                
                Button(action: {
                    showingPromptEditor = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add New Prompt")
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.vertical, 8)
            }
        }
        .padding()
        .sheet(item: $editingPrompt) { prompt in
            promptEditorView(for: prompt)
        }
        .sheet(isPresented: $showingPromptEditor, onDismiss: {
            editingPrompt = nil
        }) {
            promptEditorView(for: nil)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: SavedPromptsDocument(prompts: viewModel.savedPrompts),
            contentType: .json,
            defaultFilename: "a-instant-prompts"
        ) { result in
            if case .success = result {
                // Successfully exported
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }
                loadPrompts(from: selectedURL)
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }
    
    private func promptEditorView(for prompt: SavedPrompt?) -> some View {
        VStack(spacing: 20) {
            Text(prompt == nil ? "Add New Prompt" : "Edit Prompt")
                .font(.headline)
                .onAppear {
                    if let prompt = prompt {
                        newPromptName = prompt.name
                        newPromptText = prompt.promptText
                    } else {
                        newPromptName = ""
                        newPromptText = ""
                    }
                }
            
            VStack(alignment: .leading) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Prompt Name", text: $newPromptName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading) {
                Text("Prompt Text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $newPromptText)
                    .font(.body)
                    .frame(height: 150)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            
            HStack {
                Button("Cancel") {
                    if prompt != nil {
                        editingPrompt = nil
                    } else {
                        showingPromptEditor = false
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()
                
                Button(prompt == nil ? "Create" : "Update") {
                    if let editPrompt = prompt {
                        // Update existing prompt
                        if let index = viewModel.savedPrompts.firstIndex(where: { $0.id == editPrompt.id }) {
                            viewModel.savedPrompts[index].name = newPromptName
                            viewModel.savedPrompts[index].promptText = newPromptText
                        }
                    } else {
                        // Create new prompt
                        let newPrompt = SavedPrompt(
                            name: newPromptName,
                            promptText: newPromptText
                        )
                        
                        viewModel.savedPrompts.append(newPrompt)
                    }
                    
                    viewModel.saveSettings()
                    
                    if prompt != nil {
                        editingPrompt = nil
                    } else {
                        showingPromptEditor = false
                    }
                }
                .disabled(newPromptName.isEmpty || newPromptText.isEmpty)
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private var aboutView: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.cursor")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            Text("A-Instant")
                .font(.largeTitle)
                .bold()
            
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .foregroundColor(.secondary)
            
            Divider()
                .padding()
            
            Text("Universal AI-powered text assistant for macOS")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("© 2025 Pau Oliva Fora")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 30)
            
            Spacer()
        }
        .padding()
    }
    
    private func apiKeyBinding() -> Binding<String> {
        switch viewModel.selectedProvider {
        case .openAI:
            return $viewModel.openAIKey
        case .anthropic:
            return $viewModel.anthropicKey
        case .google:
            return $viewModel.googleKey
        case .groq:
            return $viewModel.groqKey
        case .deepSeek:
            return $viewModel.deepSeekKey
        case .mistral:
            return $viewModel.mistralKey
        case .ollama:
            return .constant("")
        case .xAI:
            return $viewModel.xAIKey
        case .genericOpenAI:
            return $viewModel.genericOpenAIKey
        }
    }
    
    private func apiKeyManagementURL() -> URL? {
        switch viewModel.selectedProvider {
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")
        case .google:
            return URL(string: "https://aistudio.google.com/app/apikey")
        case .groq:
            return URL(string: "https://console.groq.com/keys")
        case .deepSeek:
            return URL(string: "https://platform.deepseek.com/api-keys")
        case .mistral:
            return URL(string: "https://console.mistral.ai/api-keys")
        case .ollama:
            return URL(string: "https://ollama.com/download")
        case .xAI:
            return URL(string: "https://platform.x.ai/settings/api-keys")
        case .genericOpenAI:
            return URL(string: "https://openrouter.ai/keys")
        }
    }
    
    private func exportPrompts() {
        showingExporter = true
    }
    
    private func importPrompts() {
        showingImporter = true
    }
    
    private func loadPrompts(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            importErrorMessage = "Failed to access the file"
            showingImportError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let importedPrompts = try decoder.decode([SavedPrompt].self, from: data)
            
            // Filter out prompts that already exist (by name)
            let existingPromptNames = Set(viewModel.savedPrompts.map { $0.name })
            let newPrompts = importedPrompts.filter { !existingPromptNames.contains($0.name) }
            
            if newPrompts.isEmpty {
                importErrorMessage = "All imported prompts already exist in your collection"
                showingImportError = true
                return
            }
            
            // Add only new prompts to existing ones
            viewModel.savedPrompts.append(contentsOf: newPrompts)
            viewModel.saveSettings()
        } catch {
            importErrorMessage = "Failed to import prompts: \(error.localizedDescription)"
            showingImportError = true
        }
    }
} 