import SwiftUI

struct ChannelEditorView: View {
    @State private var channel: K5Channel
    let onSave: (K5Channel) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    // Предустановленные CTCSS частоты
    private let ctcssFrequencies: [Double] = [
        67.0, 71.9, 74.4, 77.0, 79.7, 82.5, 85.4, 88.5, 91.5, 94.8,
        97.4, 100.0, 103.5, 107.2, 110.9, 114.8, 118.8, 123.0, 127.3, 131.8,
        136.5, 141.3, 146.2, 151.4, 156.7, 162.2, 167.9, 173.8, 179.9, 186.2,
        192.8, 203.5, 210.7, 218.1, 225.7, 233.6, 241.8, 250.3
    ]
    
    // Предустановленные DCS коды
    private let dcsCodes: [Int] = [
        23, 25, 26, 31, 32, 36, 43, 47, 51, 53, 54, 65, 71, 72, 73, 74,
        114, 115, 116, 122, 125, 131, 132, 134, 143, 145, 152, 155, 156, 162,
        165, 172, 174, 205, 212, 223, 225, 226, 243, 244, 245, 246, 251, 252,
        255, 261, 263, 265, 266, 271, 274, 306, 311, 315, 325, 331, 332, 343,
        346, 351, 356, 364, 365, 371, 411, 412, 413, 423, 431, 432, 445, 446,
        452, 454, 455, 462, 464, 465, 466, 503, 506, 516, 523, 526, 532, 546,
        565, 606, 612, 624, 627, 631, 632, 654, 662, 664, 703, 712, 723, 731,
        732, 734, 743, 754
    ]
    
    init(channel: K5Channel, onSave: @escaping (K5Channel) -> Void) {
        self._channel = State(initialValue: channel)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Основные параметры")) {
                    HStack {
                        Text("Номер канала:")
                        Spacer()
                        Text("\(channel.index + 1)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Название:")
                        TextField("Название канала", text: $channel.name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    HStack {
                        Text("Частота (MHz):")
                        TextField("000.000", value: $channel.frequency, format: .number.precision(.fractionLength(5)))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section(header: Text("Настройки передачи")) {
                    Picker("Мощность передачи", selection: $channel.txPower) {
                        Text("Низкая").tag(0)
                        Text("Средняя").tag(1)
                        Text("Высокая").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Picker("Полоса пропускания", selection: $channel.bandwidth) {
                        Text("Узкая (12.5 kHz)").tag(K5Bandwidth.narrow)
                        Text("Широкая (25 kHz)").tag(K5Bandwidth.wide)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Toggle("Скремблер", isOn: $channel.scrambler)
                }
                
                Section(header: Text("Тоны CTCSS/DCS")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RX тон (прием)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TonePickerView(
                            tone: $channel.rxTone,
                            ctcssFrequencies: ctcssFrequencies,
                            dcsCodes: dcsCodes
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TX тон (передача)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TonePickerView(
                            tone: $channel.txTone,
                            ctcssFrequencies: ctcssFrequencies,
                            dcsCodes: dcsCodes
                        )
                    }
                }
                
                Section(header: Text("Валидация")) {
                    let errors = K5Utilities.validateChannel(channel)
                    if errors.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Канал корректен")
                                .foregroundColor(.green)
                        }
                    } else {
                        ForEach(errors, id: \.self) { error in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Редактор канала")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(channel)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(!K5Utilities.validateChannel(channel).isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}

struct TonePickerView: View {
    @Binding var tone: K5Tone
    let ctcssFrequencies: [Double]
    let dcsCodes: [Int]
    
    @State private var toneType: ToneType = .none
    @State private var ctcssFrequency: Double = 88.5
    @State private var dcsCode: Int = 23
    
    private enum ToneType: String, CaseIterable {
        case none = "Нет"
        case ctcss = "CTCSS"
        case dcs = "DCS"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Тип тона", selection: $toneType) {
                ForEach(ToneType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: toneType) {
                updateTone()
            }
            
            switch toneType {
            case .none:
                EmptyView()
                
            case .ctcss:
                Picker("Частота CTCSS", selection: $ctcssFrequency) {
                    ForEach(ctcssFrequencies, id: \.self) { freq in
                        Text(String(format: "%.1f Hz", freq)).tag(freq)
                    }
                }
                .onChange(of: ctcssFrequency) {
                    updateTone()
                }
                
            case .dcs:
                Picker("Код DCS", selection: $dcsCode) {
                    ForEach(dcsCodes, id: \.self) { code in
                        Text(String(format: "%03d", code)).tag(code)
                    }
                }
                .onChange(of: dcsCode) {
                    updateTone()
                }
            }
        }
        .onAppear {
            initializeFromTone()
        }
    }
    
    private func initializeFromTone() {
        switch tone {
        case .none:
            toneType = .none
        case .ctcss(let freq):
            toneType = .ctcss
            ctcssFrequency = freq
        case .dcs(let code):
            toneType = .dcs
            dcsCode = code
        }
    }
    
    private func updateTone() {
        switch toneType {
        case .none:
            tone = .none
        case .ctcss:
            tone = .ctcss(ctcssFrequency)
        case .dcs:
            tone = .dcs(dcsCode)
        }
    }
}

struct ChannelRowView: View {
    let channel: K5Channel
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(channel.index + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .leading)
                    
                    Text(channel.name.isEmpty ? "Без названия" : channel.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(String(format: "%.5f MHz", channel.frequency))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(powerText(channel.txPower))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(channel.bandwidth == .wide ? "25kHz" : "12.5kHz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if channel.scrambler {
                        Text("SCR")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if case .ctcss(let freq) = channel.rxTone {
                    Text("RX: CTCSS \(String(format: "%.1f", freq))")
                        .font(.caption2)
                        .foregroundColor(.blue)
                } else if case .dcs(let code) = channel.rxTone {
                    Text("RX: DCS \(String(format: "%03d", code))")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            HStack {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
    
    private func powerText(_ power: Int) -> String {
        switch power {
        case 0: return "Low"
        case 1: return "Mid"
        case 2: return "High"
        default: return "?"
        }
    }
}

#Preview {
    ChannelEditorView(channel: K5Channel()) { _ in }
}