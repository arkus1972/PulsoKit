import AppKit
import Combine
import CryptoKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class TD0EditorModel: ObservableObject {
    @Published private(set) var fileName: String?
    @Published var kitName = ""
    @Published var kitDescription = ""
    @Published private(set) var formatVersion: String?
    @Published private(set) var hasUserSamples = false
    @Published private(set) var validationMessage = "No file loaded"
    @Published private(set) var isValid = false
    @Published var kitVolume = 0
    @Published var pedalHHVolume = 0
    @Published var xStickVolume = 0
    @Published var crossStickEnabled = false
    @Published var hiHatBalance = 0
    @Published var midiNotes: [Int] = Array(repeating: 0, count: 24)
    @Published private(set) var zones: [TD0ZoneDraft] = []
    @Published private(set) var supportsExpandedEffects = false
    @Published var ambienceEnabled = false
    @Published var ambienceType = 0
    @Published var ambienceSize = 0
    @Published var ambienceShape = 0
    @Published var ambienceWall = 0
    @Published var ambienceMic = 0
    @Published var ambienceLevel = 0
    @Published var reverbEnabled = false
    @Published var reverbParameters: [Int] = Array(repeating: 0, count: 9)
    @Published var reverbLevel = 0
    @Published var compressorEnabled = false
    @Published var compressorType = 0
    @Published var compressorMixBalance = 0
    @Published var mfxType = 0
    @Published var mfxEnabled = false
    @Published var mfxLevel = 0
    @Published var mfxParameters: [Int] = Array(repeating: 0, count: 32)

    private var sourceData: Data?
    private var coreSize = 0
    private var isV2 = false

    private static let maximumFileSize = 64 * 1024 * 1024
    private static let coreSignature = Data("TD-17\u{0}KT".utf8)
    private static let sampleSignature = Data("TD-17\u{0}USUsrSmplPrm".utf8)

    func open() {
        let panel = NSOpenPanel()
        panel.title = "Open a TD-17 kit"
        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let values = try url.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey]
            )
            guard values.isRegularFile == true else {
                throw TD0Error.invalid("The selected item is not a regular file")
            }
            guard let size = values.fileSize, size <= Self.maximumFileSize else {
                throw TD0Error.invalid("The file exceeds the safe 64 MiB limit")
            }

            // Bez mapowania pamięciowego. Plik i tak jest ograniczony do
            // 64 MiB, więc mapowanie niczego nie oszczędza, a trzymamy te dane
            // przez całe życie okna: gdyby ktoś w międzyczasie obciął plik
            // albo wypiął pendrive'a, sięgnięcie po stronę pamięci kończy się
            // sygnałem SIGBUS, którego w Swifcie nie da się przechwycić —
            // program po prostu ginie, bez komunikatu.
            let data = try Data(contentsOf: url)
            try load(data, named: url.lastPathComponent)
        } catch {
            clear(with: "File rejected: \(error.localizedDescription)")
        }
    }

    func exportCopy() {
        guard var data = sourceData, isValid else { return }

        let panel = NSSavePanel()
        panel.title = "Export a safe TD-17 copy"
        panel.nameFieldStringValue = nextSuggestedBaseName()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "TD0") ?? .data
        ]
        panel.allowsOtherFileTypes = false
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        let url = normalizedTD0URL(selectedURL)

        do {
            writeEditedValues(to: &data)
            let bodyRange = 0..<(coreSize - 16)
            let digest = Data(Insecure.MD5.hash(data: data[bodyRange]))
            data.replaceSubrange((coreSize - 16)..<coreSize, with: digest)
            try data.write(to: url, options: [.atomic])

            let saved = try Data(contentsOf: url)
            guard saved == data else {
                throw TD0Error.invalid("Verification of the saved copy failed")
            }
            // Pełna ścieżka zostaje na ekranie, gdzie się przydaje („gdzie
            // trafił mój plik?"), ale nie w oknie, które ludzie fotografują
            // i wysyłają — tam widniałaby nazwa konta w systemie.
            validationMessage = "Saved and verified:\n\(url.path)"
            showExportResult(
                title: "TD0 file saved",
                message: "The copy was written and verified:\n\n\(url.lastPathComponent)"
            )
        } catch {
            validationMessage = "Export error: \(error.localizedDescription)"
            showExportResult(
                title: "Could not save the file",
                message: "\(error.localizedDescription)\n\nFile: \(url.lastPathComponent)"
            )
        }
    }

    private func load(_ data: Data, named name: String) throws {
        guard data.count >= 36, data.prefix(8) == Self.coreSignature else {
            throw TD0Error.invalid("Invalid TD-17 signature")
        }

        let version = ascii(data, offset: 0x14, length: 16)
        let detectedCoreSize = version.hasPrefix("2.") ? 2748 : 2680
        guard data.count >= detectedCoreSize else {
            throw TD0Error.invalid("The file core is truncated")
        }

        let body = data[0..<(detectedCoreSize - 16)]
        let storedDigest = data[(detectedCoreSize - 16)..<detectedCoreSize]
        let calculatedDigest = Data(Insecure.MD5.hash(data: body))
        guard storedDigest.elementsEqual(calculatedDigest) else {
            throw TD0Error.invalid("Invalid core MD5")
        }

        if data.count > detectedCoreSize {
            guard data.count >= detectedCoreSize + Self.sampleSignature.count,
                  data[detectedCoreSize..<(detectedCoreSize + Self.sampleSignature.count)]
                    .elementsEqual(Self.sampleSignature)
            else {
                throw TD0Error.invalid("Unknown data section after the core")
            }
        }

        let detectedV2 = version.hasPrefix("2.")
        let nameOffset = detectedV2 ? 0x50 : 0x30
        let commonOffset = detectedV2 ? 0x6C : 0x4C
        let midiOffset = detectedV2 ? 0x78 : 0x58
        let mixerOffset = detectedV2 ? 0x124 : 0xE0
        let mainOffset = detectedV2 ? 0x2B4 : 0x270
        let subOffset = detectedV2 ? 0x354 : 0x310
        let mainVEditOffset = detectedV2 ? 0x3FC : 0x3B8
        let subVEditOffset = detectedV2 ? 0x71C : 0x6D8

        let parsedZones = try (0..<20).map { index in
            let mixer = mixerOffset + index * 20
            let main = mainOffset + index * 8
            let sub = subOffset + index * 8
            let mainVEdit = mainVEditOffset + index * 40
            let subVEdit = subVEditOffset + index * 40
            let pan = Int(Int8(bitPattern: data[mixer]))
            guard (-64...64).contains(pan) else {
                throw TD0Error.invalid("Invalid pan for zone \(index + 1)")
            }

            // Suma MD5 w pliku TD0 mówi tylko tyle, że plik nie zepsuł się po
            // drodze — nie mówi, kto go zrobił. Policzyć ją na spreparowanym
            // pliku umie każdy. Bez sprawdzenia zakresów program pokazywałby
            // więc zieloną plakietkę „MD5 OK" nad wartościami, których moduł
            // nigdy by nie wystawił — a stąd już prosta droga przez „Save
            // a copy" do wgrania tego komuś do TD-17.
            let layerType = Int(data[mixer + 2])
            let mainLevel = readInt16(data, at: main + 2)
            let subLevel = readInt16(data, at: sub + 2)
            guard (0...3).contains(layerType) else {
                throw TD0Error.invalid("Invalid layer type in zone \(index + 1)")
            }
            guard (-601...60).contains(mainLevel),
                  (-601...60).contains(subLevel)
            else {
                throw TD0Error.invalid("Level out of range in zone \(index + 1)")
            }
            let sends = [
                readInt16(data, at: mixer + 12),
                readInt16(data, at: mixer + 14),
                readInt16(data, at: mixer + 16),
            ]
            // Zakres taki sam jak przy zapisie pliku (patrz
            // `writeEditedValues`). Węższy — choćby zgodny z mapą SysEx —
            // sprawiał, że program odrzucał **własny** plik: suwaki wysyłek
            // w edytorze TD0 sięgają +6 dB, więc wystarczyło podnieść wysyłkę,
            // zapisać kopię i otworzyć ją z powrotem. Twarde granice tak czy
            // owak pilnuje ścieżka zapisu do modułu; tutaj chodzi o odsianie
            // wartości, których w tym polu nie może być nigdy.
            guard sends.allSatisfy({ (-601...60).contains($0) }) else {
                throw TD0Error.invalid("Send level out of range in zone \(index + 1)")
            }
            let gains = [
                Int(Int8(bitPattern: data[mixer + 6])),
                Int(Int8(bitPattern: data[mixer + 9])),
                Int(Int8(bitPattern: data[mixer + 11])),
            ]
            // Jak wyżej: zakres zgodny z tym, co zapisuje `writeEditedValues`.
            // Pola wzmocnienia EQ w edytorze TD0 przyjmują całe -64…63,
            // a walidacja zawężona do zakresu modułu odrzucała plik zapisany
            // chwilę wcześniej przez ten sam program.
            guard gains.allSatisfy({ (-64...63).contains($0) }) else {
                throw TD0Error.invalid("EQ gain out of range in zone \(index + 1)")
            }

            return TD0ZoneDraft(
                index: index,
                name: Self.zoneNames[index],
                pan: pan,
                subEnabled: data[mixer + 1] != 0,
                layerType: Int(data[mixer + 2]),
                fadePoint: Int(data[mixer + 3]),
                eqEnabled: data[mixer + 4] != 0,
                eqLowFrequency: Int(data[mixer + 5]),
                eqLowGain: Int(Int8(bitPattern: data[mixer + 6])),
                eqMidFrequency: Int(data[mixer + 7]),
                eqMidQ: Int(data[mixer + 8]),
                eqMidGain: Int(Int8(bitPattern: data[mixer + 9])),
                eqHighFrequency: Int(data[mixer + 10]),
                eqHighGain: Int(Int8(bitPattern: data[mixer + 11])),
                ambienceSend: readInt16(data, at: mixer + 12),
                mfxSend: readInt16(data, at: mixer + 14),
                reverbSend: readInt16(data, at: mixer + 16),
                mainInstrument: readUInt16(data, at: main),
                mainLevel: readInt16(data, at: main + 2),
                subInstrument: readUInt16(data, at: sub),
                subLevel: readInt16(data, at: sub + 2),
                mainVEdit: (0..<3).map { readInt16(data, at: mainVEdit + $0 * 2) },
                subVEdit: (0..<3).map { readInt16(data, at: subVEdit + $0 * 2) }
            )
        }

        sourceData = data
        coreSize = detectedCoreSize
        isV2 = detectedV2
        fileName = name
        kitName = ascii(data, offset: nameOffset, length: 12)
        kitDescription = ascii(data, offset: nameOffset + 12, length: 16)
        kitVolume = readInt16(data, at: commonOffset)
        pedalHHVolume = readInt16(data, at: commonOffset + 2)
        xStickVolume = readInt16(data, at: commonOffset + 4)
        crossStickEnabled = readUInt16(data, at: commonOffset + 6) != 0
        hiHatBalance = readInt16(data, at: commonOffset + 8)
        // 128 to „nuta wyłączona", więc górna granica jest o jeden wyższa niż
        // najwyższa nuta MIDI.
        let parsedNotes = (0..<24).map { readUInt16(data, at: midiOffset + $0 * 2) }
        guard parsedNotes.allSatisfy({ (0...128).contains($0) }) else {
            throw TD0Error.invalid("Invalid MIDI note assignment in the file")
        }
        midiNotes = parsedNotes
        zones = parsedZones
        supportsExpandedEffects = detectedV2
        if detectedV2 {
            ambienceEnabled = data[0xAC] != 0
            ambienceType = Int(data[0xAD])
            ambienceSize = Int(data[0xAE])
            ambienceShape = Int(data[0xAF])
            ambienceWall = Int(data[0xB0])
            ambienceMic = Int(data[0xB1])
            ambienceLevel = readInt16(data, at: 0xB2)
            reverbEnabled = data[0xB8] != 0
            reverbParameters = (0..<9).map { Int(data[0xB9 + $0]) }
            reverbLevel = readInt16(data, at: 0xC2)
            compressorEnabled = data[0xC8] != 0
            compressorType = Int(data[0xC9])
            compressorMixBalance = Int(data[0xD8])
            mfxType = readUInt16(data, at: 0xDC)
            mfxEnabled = readUInt16(data, at: 0xDE) != 0
            mfxLevel = readInt16(data, at: 0xE0)
            mfxParameters = (0..<32).map { readInt16(data, at: 0xE4 + $0 * 2) }
        } else {
            mfxType = Int(data[0x98])
            mfxEnabled = data[0x99] != 0
            mfxLevel = readInt16(data, at: 0x9A)
            mfxParameters = (0..<32).map { readInt16(data, at: 0xA0 + $0 * 2) }
        }
        formatVersion = version
        hasUserSamples = data.count > detectedCoreSize
        isValid = true
        validationMessage = "File poprawny — MD5 zweryfikowane"
    }

    private func clear(with message: String) {
        sourceData = nil
        fileName = nil
        kitName = ""
        kitDescription = ""
        formatVersion = nil
        hasUserSamples = false
        kitVolume = 0
        pedalHHVolume = 0
        xStickVolume = 0
        crossStickEnabled = false
        hiHatBalance = 0
        midiNotes = Array(repeating: 0, count: 24)
        zones = []
        supportsExpandedEffects = false
        ambienceEnabled = false
        ambienceType = 0
        ambienceSize = 0
        ambienceShape = 0
        ambienceWall = 0
        ambienceMic = 0
        ambienceLevel = 0
        reverbEnabled = false
        reverbParameters = Array(repeating: 0, count: 9)
        reverbLevel = 0
        compressorEnabled = false
        compressorType = 0
        compressorMixBalance = 0
        mfxType = 0
        mfxEnabled = false
        mfxLevel = 0
        mfxParameters = Array(repeating: 0, count: 32)
        coreSize = 0
        isV2 = false
        isValid = false
        validationMessage = message
    }

    private func ascii(_ data: Data, offset: Int, length: Int) -> String {
        guard offset >= 0, length >= 0, offset + length <= data.count else {
            return ""
        }
        return String(data: data[offset..<(offset + length)], encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
            ?? ""
    }

    private func writeEditedValues(to data: inout Data) {
        let nameOffset = isV2 ? 0x50 : 0x30
        let commonOffset = isV2 ? 0x6C : 0x4C
        let midiOffset = isV2 ? 0x78 : 0x58
        let mixerOffset = isV2 ? 0x124 : 0xE0
        let mainOffset = isV2 ? 0x2B4 : 0x270
        let subOffset = isV2 ? 0x354 : 0x310
        let mainVEditOffset = isV2 ? 0x3FC : 0x3B8
        let subVEditOffset = isV2 ? 0x71C : 0x6D8

        writeASCII(kitName, to: &data, at: 0x08, length: 12)
        writeASCII(kitName, to: &data, at: nameOffset, length: 12)
        writeASCII(kitDescription, to: &data, at: nameOffset + 12, length: 16)
        writeInt16(clamp(kitVolume, -601...60), to: &data, at: commonOffset)
        writeInt16(clamp(pedalHHVolume, -601...60), to: &data, at: commonOffset + 2)
        writeInt16(clamp(xStickVolume, -601...60), to: &data, at: commonOffset + 4)
        writeUInt16(crossStickEnabled ? 1 : 0, to: &data, at: commonOffset + 6)
        // Balans hi-hat: w mapie SysEx modułu jest to bajt ze znakiem o zakresie
        // -64…63, ale w pliku TD0 pole ma 16 bitów i nie ma potwierdzenia, że
        // obowiązuje tu ta sama skala. Poprzedni clamp do -100…100 był trzecim,
        // niezależnym zakresem i obcinał wartości wczytane z pliku, których
        // użytkownik w ogóle nie dotknął. Edytor jest teraz ograniczony do
        // zakresu modułu (-64…63), a zapis pliku przepisuje wartość bez straty.
        // DO POTWIERDZENIA NA SPRZĘCIE: rzeczywista skala tego pola w TD0.
        writeInt16(
            clamp(hiHatBalance, -32768...32767),
            to: &data,
            at: commonOffset + 8
        )

        // 128 to prawidłowe przypisanie oznaczające OFF — patrz
        // TD17MIDINoteInfo.noteText w MIDIManager. Poprzedni clamp do 0…127
        // po cichu zamieniał każdy wyłączony pad na notę 127.
        for index in 0..<min(24, midiNotes.count) {
            writeUInt16(
                clamp(midiNotes[index], 0...128),
                to: &data,
                at: midiOffset + index * 2
            )
        }

        for zone in zones where (0..<20).contains(zone.index) {
            let mixer = mixerOffset + zone.index * 20
            let main = mainOffset + zone.index * 8
            let sub = subOffset + zone.index * 8
            let mainVEdit = mainVEditOffset + zone.index * 40
            let subVEdit = subVEditOffset + zone.index * 40
            data[mixer] = UInt8(bitPattern: Int8(clamp(zone.pan, -64...64)))
            data[mixer + 1] = zone.subEnabled ? 1 : 0
            // 0…3, tak samo jak przy wczytywaniu — inaczej zapis mógłby
            // wyprodukować plik, którego program sam nie otworzy.
            data[mixer + 2] = UInt8(clamp(zone.layerType, 0...3))
            data[mixer + 3] = UInt8(clamp(zone.fadePoint, 0...127))
            data[mixer + 4] = zone.eqEnabled ? 1 : 0
            data[mixer + 5] = UInt8(clamp(zone.eqLowFrequency, 0...127))
            data[mixer + 6] = UInt8(bitPattern: Int8(clamp(zone.eqLowGain, -64...63)))
            data[mixer + 7] = UInt8(clamp(zone.eqMidFrequency, 0...127))
            data[mixer + 8] = UInt8(clamp(zone.eqMidQ, 0...127))
            data[mixer + 9] = UInt8(bitPattern: Int8(clamp(zone.eqMidGain, -64...63)))
            data[mixer + 10] = UInt8(clamp(zone.eqHighFrequency, 0...127))
            data[mixer + 11] = UInt8(bitPattern: Int8(clamp(zone.eqHighGain, -64...63)))
            writeInt16(clamp(zone.ambienceSend, -601...60), to: &data, at: mixer + 12)
            writeInt16(clamp(zone.mfxSend, -601...60), to: &data, at: mixer + 14)
            writeInt16(clamp(zone.reverbSend, -601...60), to: &data, at: mixer + 16)
            writeUInt16(clamp(zone.mainInstrument, 0...65535), to: &data, at: main)
            writeInt16(clamp(zone.mainLevel, -601...60), to: &data, at: main + 2)
            writeUInt16(clamp(zone.subInstrument, 0...65535), to: &data, at: sub)
            writeInt16(clamp(zone.subLevel, -601...60), to: &data, at: sub + 2)
            for parameter in 0..<3 {
                writeInt16(
                    clamp(zone.mainVEdit[parameter], -32768...32767),
                    to: &data,
                    at: mainVEdit + parameter * 2
                )
                writeInt16(
                    clamp(zone.subVEdit[parameter], -32768...32767),
                    to: &data,
                    at: subVEdit + parameter * 2
                )
            }
        }

        if isV2 {
            data[0xAC] = ambienceEnabled ? 1 : 0
            data[0xAD] = UInt8(clamp(ambienceType, 0...127))
            data[0xAE] = UInt8(clamp(ambienceSize, 0...127))
            data[0xAF] = UInt8(clamp(ambienceShape, 0...127))
            data[0xB0] = UInt8(clamp(ambienceWall, 0...127))
            data[0xB1] = UInt8(clamp(ambienceMic, 0...127))
            writeInt16(clamp(ambienceLevel, -601...60), to: &data, at: 0xB2)
            data[0xB8] = reverbEnabled ? 1 : 0
            for index in 0..<min(9, reverbParameters.count) {
                data[0xB9 + index] = UInt8(clamp(reverbParameters[index], 0...127))
            }
            writeInt16(clamp(reverbLevel, -601...60), to: &data, at: 0xC2)
            data[0xC8] = compressorEnabled ? 1 : 0
            data[0xC9] = UInt8(clamp(compressorType, 0...127))
            data[0xD8] = UInt8(clamp(compressorMixBalance, 0...127))
            writeUInt16(clamp(mfxType, 0...65535), to: &data, at: 0xDC)
            writeUInt16(mfxEnabled ? 1 : 0, to: &data, at: 0xDE)
            writeInt16(clamp(mfxLevel, -32768...32767), to: &data, at: 0xE0)
            for index in 0..<min(32, mfxParameters.count) {
                writeInt16(
                    clamp(mfxParameters[index], -32768...32767),
                    to: &data,
                    at: 0xE4 + index * 2
                )
            }
        } else {
            data[0x98] = UInt8(clamp(mfxType, 0...255))
            data[0x99] = mfxEnabled ? 1 : 0
            writeInt16(clamp(mfxLevel, -32768...32767), to: &data, at: 0x9A)
            for index in 0..<min(32, mfxParameters.count) {
                writeInt16(
                    clamp(mfxParameters[index], -32768...32767),
                    to: &data,
                    at: 0xA0 + index * 2
                )
            }
        }
    }

    private func readUInt16(_ data: Data, at offset: Int) -> Int {
        Int(data[offset]) | (Int(data[offset + 1]) << 8)
    }

    private func readInt16(_ data: Data, at offset: Int) -> Int {
        Int(Int16(bitPattern: UInt16(readUInt16(data, at: offset))))
    }

    private func writeUInt16(_ value: Int, to data: inout Data, at offset: Int) {
        let raw = UInt16(value)
        data[offset] = UInt8(raw & 0xFF)
        data[offset + 1] = UInt8(raw >> 8)
    }

    private func writeInt16(_ value: Int, to data: inout Data, at offset: Int) {
        writeUInt16(Int(UInt16(bitPattern: Int16(value))), to: &data, at: offset)
    }

    private func writeASCII(_ value: String, to data: inout Data, at offset: Int, length: Int) {
        let safe = value.unicodeScalars
            .filter { $0.value >= 0x20 && $0.value <= 0x7E }
            .prefix(length)
            .map { UInt8($0.value) }
        let padded = safe + Array(repeating: UInt8(ascii: " "), count: length - safe.count)
        data.replaceSubrange(offset..<(offset + length), with: padded)
    }

    private func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func nextSuggestedBaseName() -> String {
        guard let fileName,
              let match = fileName.range(
                of: #"[0-9]{3}"#,
                options: .regularExpression
              ),
              let number = Int(fileName[match])
        else {
            return "KIT-001"
        }
        return String(format: "KIT-%03d", min(number + 1, 999))
    }

    /// Doprowadza nazwę do postaci `COŚ.TD0`, ale **nigdy** kosztem pliku,
    /// o który okno zapisu nie zapytało.
    ///
    /// Okno zapisu pyta o nadpisanie tylko tej ścieżki, którą pokazało
    /// użytkownikowi. Każda inna, wyliczona już po jego kliknięciu, poszłaby
    /// na dysk bez pytania — a `.atomic` nadpisuje bez mrugnięcia okiem. Dwa
    /// konkretne przypadki: nazwa „.TD0" zostawiała pustą podstawę i wskazanie
    /// przestawało być plikiem w wybranym katalogu, a na dysku wrażliwym na
    /// wielkość liter „kit.td0" po cichu kasowało istniejące „kit.TD0".
    private func normalizedTD0URL(_ selectedURL: URL) -> URL {
        var baseName = selectedURL.deletingPathExtension().lastPathComponent
        while baseName.lowercased().hasSuffix(".td0") {
            baseName = String(baseName.dropLast(4))
        }
        guard !baseName.isEmpty else { return selectedURL }
        let candidate = selectedURL
            .deletingLastPathComponent()
            .appendingPathComponent(baseName)
            .appendingPathExtension("TD0")
        guard candidate == selectedURL
            || !FileManager.default.fileExists(atPath: candidate.path)
        else { return selectedURL }
        return candidate
    }

    private func showExportResult(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title == "TD0 file saved" ? .informational : .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static let zoneNames = TD17ZoneCatalog.names
}

@MainActor
final class TD0ZoneDraft: ObservableObject, Identifiable {
    let id: Int
    let index: Int
    let name: String
    @Published var pan: Int
    @Published var subEnabled: Bool
    @Published var layerType: Int
    @Published var fadePoint: Int
    @Published var eqEnabled: Bool
    @Published var eqLowFrequency: Int
    @Published var eqLowGain: Int
    @Published var eqMidFrequency: Int
    @Published var eqMidQ: Int
    @Published var eqMidGain: Int
    @Published var eqHighFrequency: Int
    @Published var eqHighGain: Int
    @Published var ambienceSend: Int
    @Published var mfxSend: Int
    @Published var reverbSend: Int
    @Published var mainInstrument: Int
    @Published var mainLevel: Int
    @Published var subInstrument: Int
    @Published var subLevel: Int
    @Published var mainVEdit: [Int]
    @Published var subVEdit: [Int]

    init(
        index: Int, name: String, pan: Int, subEnabled: Bool,
        layerType: Int, fadePoint: Int, eqEnabled: Bool,
        eqLowFrequency: Int, eqLowGain: Int, eqMidFrequency: Int,
        eqMidQ: Int, eqMidGain: Int, eqHighFrequency: Int,
        eqHighGain: Int, ambienceSend: Int, mfxSend: Int,
        reverbSend: Int, mainInstrument: Int, mainLevel: Int,
        subInstrument: Int, subLevel: Int, mainVEdit: [Int],
        subVEdit: [Int]
    ) {
        id = index
        self.index = index
        self.name = name
        self.pan = pan
        self.subEnabled = subEnabled
        self.layerType = layerType
        self.fadePoint = fadePoint
        self.eqEnabled = eqEnabled
        self.eqLowFrequency = eqLowFrequency
        self.eqLowGain = eqLowGain
        self.eqMidFrequency = eqMidFrequency
        self.eqMidQ = eqMidQ
        self.eqMidGain = eqMidGain
        self.eqHighFrequency = eqHighFrequency
        self.eqHighGain = eqHighGain
        self.ambienceSend = ambienceSend
        self.mfxSend = mfxSend
        self.reverbSend = reverbSend
        self.mainInstrument = mainInstrument
        self.mainLevel = mainLevel
        self.subInstrument = subInstrument
        self.subLevel = subLevel
        self.mainVEdit = mainVEdit
        self.subVEdit = subVEdit
    }
}

private enum TD0Error: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message): message
        }
    }
}
