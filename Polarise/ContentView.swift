//
//  ContentView.swift
//  Polarise
//
//  Created by Nikunj Mathur on 15/11/26.
//

import SwiftUI

struct TintSwatch: Identifiable {
    let id: Int
    let name: String
    let color: Color
    
    static let all: [TintSwatch] = [
        .init(id: 0, name: "As System", color: Color(.sRGB, red: 0.08, green: 0.09, blue: 0.12, opacity: 1)),
        .init(id: 1, name: "Blue",      color: Color(.sRGB, red: 0.04, green: 0.52, blue: 1.00, opacity: 1)),
        .init(id: 2, name: "Purple",    color: Color(.sRGB, red: 0.75, green: 0.35, blue: 0.95, opacity: 1)),
        .init(id: 3, name: "Pink",      color: Color(.sRGB, red: 1.00, green: 0.22, blue: 0.37, opacity: 1)),
        .init(id: 4, name: "Red",       color: Color(.sRGB, red: 1.00, green: 0.27, blue: 0.23, opacity: 1)),
        .init(id: 5, name: "Orange",    color: Color(.sRGB, red: 1.00, green: 0.62, blue: 0.04, opacity: 1)),
        .init(id: 6, name: "Yellow",    color: Color(.sRGB, red: 1.00, green: 0.84, blue: 0.04, opacity: 1)),
        .init(id: 7, name: "Green",     color: Color(.sRGB, red: 0.19, green: 0.82, blue: 0.35, opacity: 1)),
        .init(id: 8, name: "Gray",      color: Color(.sRGB, red: 0.56, green: 0.56, blue: 0.58, opacity: 1)),
        .init(id: 9, name: "Black",     color: Color(.sRGB, red: 0.0,  green: 0.0,  blue: 0.0,  opacity: 1))

    ]
}

struct ContentView: View {
    @EnvironmentObject var overlayManager: OverlayManager
    @EnvironmentObject var settings: OverlaySettings
    @State private var showMoreSettings = false
    @State private var showTintPicker = false
    @State private var isAppWideFocusEnabled = false
    @State private var isStageManagerBlurEnabled = false
    @State private var multiScreenMode = "Per screen"
    @State private var autoHideMode = "Off"
    @AppStorage("polarise.tintSwatch") private var tintSwatchIndex = 0
    
    var onResize: () -> Void = {}
    
    var body: some View {
        glassContainer {
            VStack(spacing: 18) {
                topActionRow
                modePillCard
                slidersCard
                appGroupsCard
                
                if showMoreSettings {
                    extraSettingsCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                moreSettingsPill
            }
            .padding(14)
            .frame(width: 320)
        }
        .onChange(of: showMoreSettings) { _, _  in
            DispatchQueue.main.async {
                onResize()
            }
        }
        
        .onChange(of: showTintPicker) { _, _ in
            DispatchQueue.main.async { onResize() }
        }
    }
    
    @ViewBuilder
    private func glassContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                content()
            }
        } else {
            content()
        }
    }
    
    private var topActionRow: some View {
        HStack(spacing: 8) {
            ignoreAppPill
            powerButton
        }
    }
    
    private var ignoreAppPill: some View {
        let app = overlayManager.lastExternalApp
        let appName = app?.localizedName ?? "No active app"
        let bundleID = app?.bundleIdentifier ?? ""
        let isIgnored = !bundleID.isEmpty && settings.ignoredBundleIDs.contains(bundleID)
        
        return Button {
            guard !bundleID.isEmpty else { return }
            settings.toggleIgnored(bundleID: bundleID)
            overlayManager.repositionOverlaysBelowActiveWindow(force: true)
        } label: {
            HStack(spacing: 10) {
                if let icon = app?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    Image(systemName: "app.dashed")
                        .font(.title2)
                        .frame(width: 48, height: 48)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(isIgnored ? "Ignored" : "Ignore")
                        .font(.headline.weight(.semibold))
                    Text(appName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                Image(systemName: isIgnored ? "checkmark" : "plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(isIgnored ? .green : .primary)
            }
            .padding(.horizontal, 18)
            .frame(height: 72)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .polariseGlass(.capsule)
    }
    
    private var powerButton: some View {
        Button {
            overlayManager.isOverlayEnabled.toggle()
        } label: {
            Image(systemName: "power")
                .font(.title3.weight(.medium))
                .foregroundStyle(overlayManager.isOverlayEnabled ? .primary : .secondary)
                .frame(width: 80, height: 72)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .polariseGlass(.capsule)
    }
    
    private var modePillCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 48, height: 48)
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
            }
            
            Text("Mode")
                .font(.headline.weight(.semibold))
            
            Spacer()
            
            Menu {
                ForEach([PolarisePreset.medium, .deep]) { preset in
                    Button {
                        settings.applyPreset(preset)
                    } label: {
                        HStack {
                            Text(preset.rawValue)
                            if settings.currentPreset == preset {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(settings.currentPreset.rawValue)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
        .polariseGlass(.capsule)
    }
    
    private struct SliderIconSlot<Content: View>: View {
        @ViewBuilder var content: () -> Content
        
        var body: some View {
            content()
                .frame(width: 30, height: 30)
                .frame(width: 48)
        }
    }
    
    private var slidersCard: some View {
        VStack(spacing: 32) {
            HStack(spacing: 12) {
                SliderIconSlot {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 22, weight: .regular))
                }
                
                Text("Blur")
                    .font(.headline.weight(.semibold))
                    .frame(width: 48, alignment: .leading)
                
                Slider(value: $settings.blurRadius, in: 0...100, step: 10)
            }
            
            if showTintPicker {
                cardDivider
                tintPicker
                cardDivider
            } else {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            showTintPicker = true
                        }
                    } label: {
                        Circle()
                            .fill(AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                                center: .center))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose tint color")
                    .frame(width: 48)
                    
                    Text("Tint")
                        .font(.headline.weight(.semibold))
                        .frame(width: 48, alignment: .leading)
                    
                    Slider(value: $settings.tintOpacity, in: 0...1, step: 0.1)
                }
            }
            
            HStack(spacing: 12) {
                SliderIconSlot {
                    Image(systemName: "water.waves")
                        .font(.system(size: 22, weight: .regular))
                }
                Text("Grain")
                    .font(.headline.weight(.semibold))
                    .frame(width: 46, alignment: .leading)
                
                Slider(value: $settings.grainOpacity, in: 0...0.25, step: 0.025)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .polariseGlass(.card(cornerRadius: 28))
    }
    
    private var cardDivider: some View {
        Divider()
            .opacity(0.35)
            .padding(.horizontal, -18)
    }
    
    private var tintPicker: some View {
        let swatches = TintSwatch.all
        let selected = swatches.first { $0.id == tintSwatchIndex } ?? swatches[0]
        
        return VStack(spacing: 14) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        showTintPicker = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(selected.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 6) {
                ForEach(swatches) { swatch in
                    Button {
                        tintSwatchIndex = swatch.id
                        settings.tintColor = swatch.color
                    } label: {
                        Group {
                            if swatch.id == 0 {
                                Circle().fill(AngularGradient(
                                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                                    center: .center))
                            } else {
                                Circle().fill(swatch.color)
                            }
                        }
                        .frame(width: 20, height: 20)
                        .overlay {
                            if tintSwatchIndex == swatch.id {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                                    .padding(-4)
                            }
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var appGroupsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("App Groups")
                    .font(.headline.weight(.semibold))
                
                Spacer()
                Button {
                    // Implement App Groups
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.medium))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
            
            Text("Pair apps that stay focused together")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .polariseGlass(.card(cornerRadius: 28))
    }
    
    private var extraSettingsCard: some View {
        AdditionalSettingsCard(
            isAppWideFocusEnabled: $isAppWideFocusEnabled,
            isStageManagerBlurEnabled: $isStageManagerBlurEnabled,
            multiScreenMode: $multiScreenMode,
            autoHideMode: $autoHideMode
        )
    }
    
    private var moreSettingsPill: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                showMoreSettings.toggle()
            }
        } label: {
            Text(showMoreSettings ? "Less Settings" : "More Settings")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .polariseGlass(.capsule)
    }
}

private struct AdditionalSettingsCard: View {
    @Binding var isAppWideFocusEnabled: Bool
    @Binding var isStageManagerBlurEnabled: Bool
    @Binding var multiScreenMode: String
    @Binding var autoHideMode: String

    var body: some View {
        VStack(spacing: 0) {
            SettingsToggleRow(
                title: "App-wide focus",
                subtitle: "Show all windows of the same app",
                isOn: $isAppWideFocusEnabled
            )

            Divider()
                .opacity(0.22)

            SettingsMenuRow(
                title: "Multi-screen mode",
                subtitle: nil,
                selection: $multiScreenMode,
                options: ["Per screen", "All screens"]
            )

            Divider()
                .opacity(0.22)

            SettingsMenuRow(
                title: "Auto-hide",
                subtitle: "Permissions granted",
                selection: $autoHideMode,
                options: ["Off", "On"]
            )

            Divider()
                .opacity(0.22)

            SettingsToggleRow(
                title: "Blur Stage Manager",
                subtitle: "Cover thumbnails with the overlay",
                isOn: $isStageManagerBlurEnabled
            )
        }
        .polariseGlass(.card(cornerRadius: 28))
    }
}

private struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

private struct SettingsMenuRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selection)
                        .font(.headline.weight(.medium))
                    Image(systemName: "ellipsis")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

#Preview {
    ContentView()
}
