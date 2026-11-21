//
//  ContentView.swift
//  Polarise
//
//  Created by Nikunj Mathur on 15/11/26.
//

import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var showGestureSettings = false
    @State private var showKeyboardShortcuts = false
    @State private var showTintPicker = false
    @State private var expandedAppGroups: Set<String> = []
    @State private var isStageManagerBlurEnabled = false
    @State private var multiScreenMode = "Per screen"
    @State private var autoHideMode = "Off"
    @AppStorage("polarise.tintSwatch") private var tintSwatchIndex = 0
    
    var onResize: () -> Void = {}
    
    var body: some View {
        glassContainer {
            ScrollView(.vertical) {
                VStack(spacing: 18) {
                    topActionRow
                    modePillCard
                    slidersCard
                    appGroupsCard
                    moreSettingsPill

                    if showMoreSettings {
                        if showGestureSettings {
                            gesturesPage
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.985)).combined(with: .move(edge: .top))
                                ))
                        } else {
                            gestureSettingsRow
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.985)).combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .move(edge: .top))
                                ))
                        }
                        if showKeyboardShortcuts {
                            KeyboardShortcutsCard {
                                withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
                                    showKeyboardShortcuts = false
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.985)).combined(with: .move(edge: .top))
                            ))
                        } else {
                            keyboardShortcutsRow
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.985)).combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .move(edge: .top))
                                ))
                        }
                        ignoredAppsCard
                        extraSettingsCard
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, menuBarInset + 14)
                .padding(.bottom, 28)
                .frame(width: 320)
            }
            .scrollIndicators(.automatic)
            .background(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .frame(maxHeight: maximumPanelHeight)
        }
        .animation(.spring(response: 0.58, dampingFraction: 0.84), value: showGestureSettings)
        .animation(.spring(response: 0.58, dampingFraction: 0.84), value: showKeyboardShortcuts)
        .onChange(of: showGestureSettings) { _, _ in
            DispatchQueue.main.async { onResize() }
        }
        .onChange(of: showMoreSettings) { _, _  in
            DispatchQueue.main.async {
                onResize()
            }
        }
        
        .onChange(of: showTintPicker) { _, _ in
            DispatchQueue.main.async { onResize() }
        }
        .onChange(of: expandedAppGroups) { _, _ in
            DispatchQueue.main.async { onResize() }
        }
        .onChange(of: settings.appGroups) { _, _ in
            DispatchQueue.main.async { onResize() }
        }
    }
    
    private var menuBarInset: CGFloat {
        guard let screen = NSScreen.main else { return 24 }
        return screen.frame.maxY - screen.visibleFrame.maxY
    }
    
    private var maximumPanelHeight: CGFloat {
        guard let screen = NSScreen.main else { return 800 }
        return max(360, screen.frame.maxY - screen.visibleFrame.minY - 10)
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
                        .foregroundStyle(isIgnored ? Color.white.opacity(0.82) : Color.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                Image(systemName: isIgnored ? "minus" : "plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(isIgnored ? Color.white : Color.primary)
            }
            .padding(.horizontal, 18)
            .frame(height: 72)
            .contentShape(Capsule())
            .foregroundStyle(isIgnored ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .modifier(IgnoredStatePillModifier(isIgnored: isIgnored))
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
                
                Slider(value: $settings.grainOpacity, in: 0...0.10, step: 0.01)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("App Groups").font(.headline.weight(.semibold))
                Spacer()
                Button {
                    chooseAppGroupApplication()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
            if settings.appGroups.isEmpty {
                Text("Pair apps so their windows stay sharp together.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(settings.appGroups.enumerated()), id: \.offset) { index, group in
                    let groupKey = group.sorted().joined(separator: "|")
                    VStack(spacing: 12) {
                        HStack {
                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                    if expandedAppGroups.contains(groupKey) {
                                        expandedAppGroups.remove(groupKey)
                                    } else {
                                        expandedAppGroups.insert(groupKey)
                                    }
                                }
                            } label: {
                                HStack(spacing: 0) {
                                    HStack(spacing: -18) {
                                        ForEach(Array(group.prefix(3)), id: \.self) { bundleID in
                                            appIcon(for: bundleID)
                                                .frame(width: 30, height: 30)
                                        }
                                    }
                                    Text(appGroupDisplayName(group))
                                        .font(.headline.weight(.semibold))
                                        .lineLimit(1)
                                        .padding(.leading, 12)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Spacer(minLength: 4)
                            Button {
                                chooseAppGroupApplication(addingTo: group.first)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                            Button {
                                settings.removeGroup(at: index)
                                overlayManager.repositionOverlaysBelowActiveWindow(force: true)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 34)
                            }
                            .buttonStyle(.plain)
                        }

                        if expandedAppGroups.contains(groupKey) {
                            VStack(spacing: 8) {
                                ForEach(group, id: \.self) { bundleID in
                                    HStack(spacing: 14) {
                                        appIcon(for: bundleID)
                                            .frame(width: 30, height: 30)
                                        Text(appDisplayName(for: bundleID))
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Button {
                                            settings.removeFromGroup(bundleID)
                                            expandedAppGroups.remove(groupKey)
                                            overlayManager.repositionOverlaysBelowActiveWindow(force: true)
                                        } label: {
                                            Image(systemName: "minus")
                                                .font(.system(size: 17, weight: .medium))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 30, height: 30)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
        .polariseGlass(.card(cornerRadius: 28))
    }

    @ViewBuilder
    private func appIcon(for bundleID: String) -> some View {
        if let url = applicationURL(for: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 9))
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
                .padding(7)
                .foregroundStyle(.secondary)
        }
    }

    private func appDisplayName(for bundleID: String) -> String {
        guard let url = applicationURL(for: bundleID) else { return bundleID }
        return (Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? url.deletingPathExtension().lastPathComponent
    }

    private func appGroupDisplayName(_ bundleIDs: [String]) -> String {
        let names = bundleIDs.map(appDisplayName(for:)).joined(separator: ", ")
        let maximumLength = 28
        guard names.count > maximumLength else { return names }
        return String(names.prefix(maximumLength - 3)) + "..."
    }

    private func applicationURL(for bundleID: String) -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url
        }
        guard bundleID == "com.apple.ColorMeter" else { return nil }
        let candidates = [
            URL(fileURLWithPath: "/System/Applications/Utilities/Digital Colour Meter.app"),
            URL(fileURLWithPath: "/System/Applications/Utilities/Digital Color Meter.app"),
            URL(fileURLWithPath: "/Applications/Utilities/Digital Colour Meter.app")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func selectApplications(title: String) -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.level = .statusBar

        let wasOverlayEnabled = overlayManager.isOverlayEnabled
        if wasOverlayEnabled {
            overlayManager.isOverlayEnabled = false
        }

        let appDelegate = NSApp.delegate as? AppDelegate
        appDelegate?.isSelectingApplications = true
        NSApp.activate(ignoringOtherApps: true)
        defer {
            appDelegate?.isSelectingApplications = false
            if wasOverlayEnabled {
                overlayManager.isOverlayEnabled = true
            }
        }

        guard panel.runModal() == .OK else { return nil }
        return panel.urls
    }

    private func chooseAppGroupApplication(addingTo existingGroupMember: String? = nil) {
        guard let urls = selectApplications(title: "Add Application to App Group") else { return }
        let selectedIDs = Set(urls.compactMap { Bundle(url: $0)?.bundleIdentifier })
            .filter { $0 != "com.apple.finder" && $0 != Bundle.main.bundleIdentifier }
        let bundleIDs = Array(selectedIDs)
        if let existingGroupMember,
           let group = settings.appGroups.first(where: { $0.contains(existingGroupMember) }) {
            settings.addGroup(group + bundleIDs)
        } else {
            settings.addGroup(bundleIDs)
        }
        overlayManager.repositionOverlaysBelowActiveWindow(force: true)
    }
    
    private var gestureSettingsRow: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.54)) {
                showGestureSettings = true
            }
        } label: {
            HStack(spacing: 14) {
                HStack {
                    Image(systemName: "magicmouse.fill")
                        .font(.system(size: 24, weight: .medium))
                        .frame(width: 48, height: 48)
                    Text("Gestures").font(.headline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .polariseGlass(.capsule)
    }

    private var keyboardShortcutsRow: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.54)) {
                showKeyboardShortcuts = true
            }
        } label: {
            HStack(spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "command")
                        .font(.system(size: 24, weight: .medium))
                        .frame(width: 48, height: 48)
                    Text("Keyboard Shortcuts").font(.headline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .polariseGlass(.capsule)
    }

    private var gesturesPage: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.54)) {
                        showGestureSettings = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Gestures")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                GestureToggleRow(title: "Shake gestures", isOn: $settings.shakeEnabled)
                    .padding(.vertical, 4)
                ModifierPickerRow(title: "Shake to toggle", selection: $settings.shakeModifiers)
                ModifierPickerRow(title: "Hold + Shake to peek", selection: $settings.peekModifier)
            }
            .padding(.horizontal, 14)

            Divider().opacity(0.8)

            GestureToggleRow(title: "Peek at corners", isOn: $settings.peekAtCorners)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider().opacity(0.8)

            VStack(spacing: 10) {
                HStack {
                    Text("Sensitivity")
                        .font(.headline.weight(.medium))
                    Spacer()
                }
                HStack(spacing: 10) {
                    Text("Low")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.shakeSensitivity, in: 0...1, step: 0.1)
                    Text("High")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .padding(14)
        .polariseGlass(.card(cornerRadius: 28))
    }

    private var ignoredAppsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ignored apps").font(.headline.weight(.semibold))
                Spacer()
                Button {
                    chooseIgnoredApplications()
                } label: {
                    Image(systemName: "plus").frame(width: 28, height: 28).background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
            if settings.ignoredBundleIDs.isEmpty {
                Text("Ignored apps hide the overlay when active.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(settings.ignoredBundleIDs.sorted(), id: \.self) { bundleID in
                    HStack(spacing: 9) {
                        appIcon(for: bundleID)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.15), lineWidth: 0.75))
                        Text(appDisplayName(for: bundleID))
                            .font(.subheadline).lineLimit(1)
                        Spacer()
                        Button { settings.toggleIgnored(bundleID: bundleID); overlayManager.repositionOverlaysBelowActiveWindow(force: true) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .polariseGlass(.card(cornerRadius: 28))
    }

    private func chooseIgnoredApplications() {
        guard let urls = selectApplications(title: "Add Ignored Applications") else { return }
        for bundleID in urls.compactMap({ Bundle(url: $0)?.bundleIdentifier })
            where bundleID != Bundle.main.bundleIdentifier {
            settings.addIgnored(bundleID: bundleID)
        }
        overlayManager.repositionOverlaysBelowActiveWindow(force: true)
    }

    private var extraSettingsCard: some View {
        AdditionalSettingsCard(
            settings: settings,
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
    @ObservedObject var settings: OverlaySettings
    @Binding var isStageManagerBlurEnabled: Bool
    @Binding var multiScreenMode: String
    @Binding var autoHideMode: String

    var body: some View {
        VStack(spacing: 0) {
            SettingsToggleRow(
                title: "App-wide focus",
                subtitle: "Show all windows of the same app",
                isOn: $settings.appWideFocus
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
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 2)

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
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 2)

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

private struct GestureToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
        }
        .frame(minHeight: 28)
    }
}

private struct ModifierPickerRow: View {
    let title: String
    @Binding var selection: NSEvent.ModifierFlags

    private let choices: [(String, NSEvent.ModifierFlags)] = [
        ("No modifier", []),
        ("Shift", .shift),
        ("Control", .control),
        ("Option", .option),
        ("Command", .command)
    ]

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Menu {
                ForEach(choices.indices, id: \.self) { index in
                    let choice = choices[index]
                    Button {
                        selection = choice.1
                    } label: {
                        if selection == choice.1 {
                            Label(choice.0, systemImage: "checkmark")
                        } else {
                            Text(choice.0)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selectedTitle)
                }
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .frame(minHeight: 42)
    }

    private var selectedTitle: String {
        choices.first(where: { selection == $0.1 })?.0 ?? "Custom"
    }
}

private struct KeyboardShortcutsCard: View {
    let onBack: () -> Void
    @State private var recordingHotkey: PolariseHotkey?
    @State private var refreshID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Shortcuts")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(PolariseHotkey.allCases, id: \.rawValue) { hotkey in
                let manager = HotkeyManager.shared
                let binding = manager.loadBinding(for: hotkey) ?? manager.defaultBinding(for: hotkey)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        Text(hotkey.title)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Button {
                            recordingHotkey = hotkey
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 30)
                        }
                        .buttonStyle(.plain)
                        Button {
                            manager.removeBinding(for: hotkey)
                            refreshID = UUID()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 30)
                        }
                        .buttonStyle(.plain)
                    }
                    if recordingHotkey == hotkey {
                        Text("• Recording…")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.blue)
                    } else {
                        HStack(spacing: 8) {
                            ForEach(Array(shortcutTokens(binding).enumerated()), id: \.offset) { _, token in
                                Text(token)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .frame(width: 28, height: 28)
                                    .background(.white.opacity(0.10), in: Circle())
                            }
                        }
                    }
                    if recordingHotkey == hotkey {
                        HotkeyCaptureField(isRecording: true) { binding in
                            manager.saveBinding(binding, for: hotkey)
                            manager.register(hotkey, binding: binding)
                            recordingHotkey = nil
                            refreshID = UUID()
                        }
                        .frame(height: 1)
                        .opacity(0.01)
                    }
                }
                if hotkey.rawValue != PolariseHotkey.allCases.last?.rawValue {
                    Spacer(minLength: 0)
                }
            }
        }
        .id(refreshID)
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .polariseGlass(.card(cornerRadius: 34))
    }

    private func shortcutTokens(_ binding: HotkeyBinding?) -> [String] {
        guard let binding else { return [] }
        let flags = binding.modifiers
        var tokens: [String] = []
        if flags & UInt32(controlKey) != 0 { tokens.append("⌃") }
        if flags & UInt32(optionKey) != 0 { tokens.append("⌥") }
        if flags & UInt32(shiftKey) != 0 { tokens.append("⇧") }
        if flags & UInt32(cmdKey) != 0 { tokens.append("⌘") }
        tokens.append(binding.keyLabel ?? "Key \(binding.keyCode)")
        return tokens
    }
}

private struct HotkeyCaptureField: NSViewRepresentable {
    let isRecording: Bool
    let onCapture: (HotkeyBinding) -> Void

    func makeNSView(context: Context) -> HotkeyCaptureNSView {
        let view = HotkeyCaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: HotkeyCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
        }
    }
}

private final class HotkeyCaptureNSView: NSView {
    var isRecording = false { didSet { needsDisplay = true } }
    var onCapture: ((HotkeyBinding) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let title = isRecording ? "Type a shortcut with ⌘, ⌥, ⌃, or ⇧" : ""
        title.draw(in: bounds.insetBy(dx: 8, dy: 5), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        let modifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let selected = event.modifierFlags.intersection(modifiers)
        guard !selected.isEmpty, let keyLabel = event.charactersIgnoringModifiers?.uppercased(), !keyLabel.isEmpty else {
            NSSound.beep()
            return
        }
        let binding = HotkeyBinding(
            keyCode: UInt32(event.keyCode),
            modifiers: HotkeyManager.shared.carbonModifiers(from: selected),
            keyLabel: keyLabel
        )
        onCapture?(binding)
    }
}

private extension PolariseHotkey {
    var title: String {
        switch self {
        case .toggleOverlay: "Toggle Polarise"
        case .switchMode: "Switch Mode"
        case .ignoreCurrentApp: "Ignore App"
        case .toggleControls: "Toggle Controls"
        }
    }
}

private struct IgnoredStatePillModifier: ViewModifier {
    let isIgnored: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isIgnored {
            content
                .background {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.03, green: 0.43, blue: 0.96), Color(red: 0.02, green: 0.30, blue: 0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Color.cyan.opacity(0.85), lineWidth: 1)
                }
                .shadow(color: .blue.opacity(0.35), radius: 10, y: 3)
        } else {
            content.polariseGlass(.capsule)
        }
    }
}

#Preview {
    ContentView()
}
