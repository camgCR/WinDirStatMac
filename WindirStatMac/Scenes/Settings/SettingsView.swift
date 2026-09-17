import SwiftUI
import DirStatCore

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Escaneo") {
                Toggle("Tratar paquetes (.app, .framework, …) como archivos", isOn: $settings.treatPackagesAsFiles)
                Picker("Medir tamaño por", selection: $settings.sizeMode) {
                    Text("Espacio en disco").tag(SizeMode.allocated)
                    Text("Tamaño lógico").tag(SizeMode.logical)
                }
                .pickerStyle(.radioGroup)
            }

            Section("Limpieza") {
                Toggle("Confirmar antes de mover a la Papelera o eliminar", isOn: $settings.confirmBeforeDelete)
            }

            Section("Treemap") {
                VStack(alignment: .leading) {
                    Slider(value: $settings.treemapMinTileArea, in: 4...100, step: 1)
                    Text("Tamaño mínimo de celda: \(Int(settings.treemapMinTileArea)) pt²")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
