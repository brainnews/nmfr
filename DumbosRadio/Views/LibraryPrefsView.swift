import SwiftUI
import AppKit

struct LibraryPrefsView: View {
    @EnvironmentObject var persistence: PersistenceManager

    @State private var showImportOptions  = false
    @State private var showImportError    = false
    @State private var showImportResult   = false
    @State private var showRemoveAll      = false
    @State private var pendingImport: LibraryExportData? = nil
    @State private var importErrorMsg     = ""
    @State private var importResultMsg    = ""

    var body: some View {
        Form {
            Section("Export / Import") {
                HStack(alignment: .firstTextBaseline) {
                    Button("Export…") { exportLibrary() }
                    Text("Save your \(persistence.stations.count) station\(persistence.stations.count == 1 ? "" : "s") and presets to a .nmfr file.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline) {
                    Button("Import…") { importLibrary() }
                    Text("Load stations from a .nmfr file. You can merge or replace.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Remove All Stations…", role: .destructive) {
                    showRemoveAll = true
                }
                .disabled(persistence.stations.isEmpty)
            }
        }
        .formStyle(.grouped)
        // Import: merge vs replace
        .alert("Import: Add or Replace?", isPresented: $showImportOptions, presenting: pendingImport) { data in
            Button("Merge — Add New") { doImport(data: data, replace: false) }
            Button("Replace All", role: .destructive) { doImport(data: data, replace: true) }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: { data in
            let n = data.stations.count
            Text("The file contains \(n) station\(n == 1 ? "" : "s").\n\nMerge adds new stations without removing existing ones. Replace All wipes your current library and loads the file.")
        }
        // Import parse error
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMsg)
        }
        // Import success
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMsg)
        }
        // Remove all confirmation
        .alert("Remove All Stations?", isPresented: $showRemoveAll) {
            Button("Remove All", role: .destructive) { persistence.removeAllStations() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all \(persistence.stations.count) saved station\(persistence.stations.count == 1 ? "" : "s") and clear all presets. This cannot be undone.")
        }
    }

    // MARK: - Export

    private func exportLibrary() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "NMFR Stations.nmfr"
        panel.title = "Export Station Library"
        panel.message = "Choose where to save your station library."
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let data = LibraryExportData(
            version: 1,
            stations: persistence.stations,
            presets: persistence.presets
        )
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url)
        } catch {
            importErrorMsg = "Export failed: \(error.localizedDescription)"
            showImportError = true
        }
    }

    // MARK: - Import

    private func importLibrary() {
        let panel = NSOpenPanel()
        panel.title = "Import Station Library"
        panel.message = "Select a .nmfr station library file."
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let raw = try Data(contentsOf: url)
            pendingImport = try JSONDecoder().decode(LibraryExportData.self, from: raw)
            showImportOptions = true
        } catch {
            importErrorMsg = "Could not read the file. Make sure it's a valid NMFR export (.nmfr)."
            showImportError = true
        }
    }

    private func doImport(data: LibraryExportData, replace: Bool) {
        let added = persistence.importLibrary(data: data, replace: replace)
        pendingImport = nil
        if replace {
            importResultMsg = "Library replaced with \(data.stations.count) station\(data.stations.count == 1 ? "" : "s")."
        } else {
            let skipped = data.stations.count - added
            importResultMsg = "Added \(added) new station\(added == 1 ? "" : "s")."
                + (skipped > 0 ? " \(skipped) already in library." : "")
        }
        showImportResult = true
    }
}
