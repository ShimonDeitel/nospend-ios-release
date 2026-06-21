import SwiftUI

/// Day editor. Set a day to no-spend, or log a slip with its cost (and an optional short note).
/// Re-opening an already-logged day pre-fills the existing values.
struct LogSlipView: View {
    let date: Date
    var onSave: () -> Void

    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var status: DayStatus = .noSpend
    @State private var costText: String = ""
    @State private var note: String = ""
    @State private var existing = false

    @FocusState private var costFocused: Bool

    private var cost: Double { Double(costText.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Status", selection: $status) {
                        Text("No-spend").tag(DayStatus.noSpend)
                        Text("Slip").tag(DayStatus.slip)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("status-picker")
                } header: {
                    Text(date.formatted(date: .complete, time: .omitted))
                }

                if status == .slip {
                    Section("What did it cost?") {
                        HStack {
                            Text(appModel.currencySymbol).foregroundStyle(.secondary)
                            TextField("0", text: $costText)
                                .keyboardType(.decimalPad)
                                .focused($costFocused)
                                .accessibilityIdentifier("slip-cost")
                        }
                        TextField("Note (optional), e.g. coffee", text: $note)
                            .accessibilityIdentifier("slip-note")
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Text(status == .noSpend ? "Save no-spend day" : "Save slip")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("save-day")

                    if existing {
                        Button("Clear this day", role: .destructive) {
                            appModel.clearLog(date: date)
                            Haptics.soft()
                            onSave(); dismiss()
                        }
                    }
                } footer: {
                    Text(status == .noSpend
                         ? "A no-spend day turns this square green."
                         : "A slip turns this square red and counts toward your spending stats.")
                }
            }
            .navigationTitle("Log day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .tint(Color.nsAccent)
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let log = appModel.dayLog(for: date) {
            existing = true
            status = log.status
            note = log.note
            costText = log.slipCost > 0 ? trimmed(log.slipCost) : ""
        }
    }

    private func save() {
        if status == .slip {
            appModel.log(date: date, status: .slip, slipCost: cost, note: note)
            Haptics.warning()
        } else {
            appModel.log(date: date, status: .noSpend)
            Haptics.success()
        }
        onSave(); dismiss()
    }

    private func trimmed(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
    }
}
