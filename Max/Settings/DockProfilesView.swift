import SwiftUI

/// Saved Dock arrangements, spacers, and the backup of the original Dock. Rearranging happens in the Dock itself.
struct ProfilesPane: View {
    @Bindable var profiles: DockProfiles

    var body: some View {
        Form {
            Section {
                if profiles.names.isEmpty {
                    Text("No profiles yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(profiles.names, id: \.self) { name in
                    HStack(spacing: 10) {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundStyle(MaxTheme.accent)
                        Text(name)
                        Spacer()
                        Button("Use") { profiles.apply(name) }
                        Menu {
                            Button("Rename…") {
                                profiles.draftName = name
                                profiles.renaming = name
                            }
                            Button("Delete…", role: .destructive) { profiles.deleting = name }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }
                }
                Button("Save Current Dock as Profile…") { profiles.isNaming = true }
            } header: {
                Text("Profiles")
            } footer: {
                Text("A profile keeps the Dock's apps, folders, and spacers in order, like one for work and one for home. Using one restarts the Dock; they're also in the menu bar.")
            }

            Section {
                LabeledContent("Add to the Dock") {
                    HStack {
                        Button("Spacer") { profiles.addSpacer(small: false) }
                        Button("Small Spacer") { profiles.addSpacer(small: true) }
                    }
                }
            } header: {
                Text("Spacers")
            } footer: {
                Text("Adds a gap at the end of the Dock's apps; drag it into place there. Drag a spacer off the Dock to remove it.")
            }

            Section {
                LabeledContent("Original Dock") {
                    Button("Restore…") { profiles.isConfirmingRestore = true }
                        .disabled(!profiles.hasBackup)
                }
            } header: {
                Text("Backup")
            } footer: {
                Text(profiles.hasBackup
                     ? "Max saved your Dock before it first changed it."
                     : "Max saves your Dock the first time it changes it.")
            }
        }
        .themedForm()
        .alert("Save Dock Profile", isPresented: $profiles.isNaming) {
            TextField("Name", text: $profiles.draftName)
            Button("Save") { profiles.saveCurrentDock(as: profiles.draftName) }
            Button("Cancel", role: .cancel) { profiles.draftName = "" }
        } message: {
            Text("Saves the Dock as it is now.")
        }
        .alert("Rename Profile", isPresented: Binding(
            get: { profiles.renaming != nil },
            set: { if !$0 { profiles.renaming = nil } }
        )) {
            TextField("Name", text: $profiles.draftName)
            Button("Rename") {
                if let name = profiles.renaming { profiles.rename(name, to: profiles.draftName) }
            }
            Button("Cancel", role: .cancel) { profiles.draftName = "" }
        }
        .alert("Delete \u{201C}\(profiles.deleting ?? "")\u{201D}?", isPresented: Binding(
            get: { profiles.deleting != nil },
            set: { if !$0 { profiles.deleting = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let name = profiles.deleting { profiles.delete(name) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Dock itself doesn't change.")
        }
        .alert("Restore Your Original Dock?", isPresented: $profiles.isConfirmingRestore) {
            Button("Restore", role: .destructive) { profiles.restoreBackup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Puts back the Dock's apps, folders, and spacers from before Max first changed them, and restarts the Dock.")
        }
    }
}
