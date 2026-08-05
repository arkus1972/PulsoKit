import SwiftUI

/// Fizyczny pad zestawu i strefy, które on obsługuje.
///
/// Moduł adresuje strefy (KICK HEAD, SNARE HEAD, SNARE RIM…), ale na
/// zestawie widać pady. Jeden pad to jedna, dwie albo trzy strefy.
struct TD17StagePad: Identifiable {
    /// Indeks strefy HEAD — służy też za identyfikator pada.
    let id: Int
    let shortName: String
    let zoneIndices: [Int]

    /// Środek pada w układzie 0…1 względem obrazu zestawu.
    let center: CGPoint

    /// Półosie elipsy, obie znormalizowane względem **szerokości** obrazu.
    /// Wspólny mianownik jest konieczny, żeby kształt nie deformował się
    /// przy zmianie proporcji pola widoku.
    let radiusX: CGFloat
    let radiusY: CGFloat

    /// Obrót elipsy w stopniach, zgodnie z ruchem wskazówek zegara.
    let angle: Double
}

enum TD17KitLayout {
    /// Proporcje grafiki zestawu (TD17KitStage w Assets).
    static let imageAspectRatio: CGFloat = 1423.0 / 1050.0

    /// Kształty dopasowane do rzeczywistych obrysów padów na renderze.
    ///
    /// Pady widziane z góry pod kątem są elipsami, nie kołami, i część
    /// z nich jest przekręcona. Wartości pochodzą z dopasowania elipsy do
    /// największej spójnej plamy pikseli każdego pada — naciąg mesh dla
    /// bębnów, czarny talerz dla blach — więc obrys pokrywa się z tym,
    /// co widać na zdjęciu.
    ///
    /// AUX nie ma na tym zestawie fizycznego pada; jego strefy są dostępne
    /// wyłącznie jako przyciski pod sceną.
    static let pads: [TD17StagePad] = [
        TD17StagePad(
            id: 11, shortName: "CRASH 1", zoneIndices: [11, 12],
            center: CGPoint(x: 0.3013, y: 0.1294),
            radiusX: 0.1033, radiusY: 0.0833, angle: 0.4
        ),
        TD17StagePad(
            id: 13, shortName: "CRASH 2", zoneIndices: [13, 14],
            center: CGPoint(x: 0.7601, y: 0.1194),
            radiusX: 0.1213, radiusY: 0.0831, angle: 4.0
        ),
        TD17StagePad(
            id: 15, shortName: "RIDE", zoneIndices: [15, 16, 17],
            center: CGPoint(x: 0.8917, y: 0.4226),
            radiusX: 0.1079, radiusY: 0.0849, angle: 2.3
        ),
        TD17StagePad(
            id: 9, shortName: "HI-HAT", zoneIndices: [9, 10],
            center: CGPoint(x: 0.2227, y: 0.4576),
            radiusX: 0.1066, radiusY: 0.0813, angle: -10.0
        ),
        TD17StagePad(
            id: 3, shortName: "TOM 1", zoneIndices: [3, 4],
            center: CGPoint(x: 0.4335, y: 0.3147),
            radiusX: 0.0745, radiusY: 0.0648, angle: -1.6
        ),
        TD17StagePad(
            id: 5, shortName: "TOM 2", zoneIndices: [5, 6],
            center: CGPoint(x: 0.6208, y: 0.3162),
            radiusX: 0.0745, radiusY: 0.0639, angle: 1.9
        ),
        TD17StagePad(
            id: 7, shortName: "TOM 3", zoneIndices: [7, 8],
            center: CGPoint(x: 0.6988, y: 0.5465),
            radiusX: 0.0744, radiusY: 0.0657, angle: 6.4
        ),
        TD17StagePad(
            id: 1, shortName: "SNARE", zoneIndices: [1, 2],
            center: CGPoint(x: 0.4246, y: 0.5680),
            radiusX: 0.0920, radiusY: 0.0809, angle: -6.5
        ),
        TD17StagePad(
            id: 0, shortName: "KICK", zoneIndices: [0],
            center: CGPoint(x: 0.5309, y: 0.4588),
            radiusX: 0.0450, radiusY: 0.0408, angle: 26.0
        )
    ]

    /// Strefy bez fizycznego pada na tym zestawie.
    static let detachedZoneIndices = [18, 19]

    static func pad(containing zoneIndex: Int) -> TD17StagePad? {
        pads.first { $0.zoneIndices.contains(zoneIndex) }
    }
}

/// Wizualny wybór strefy na renderze zestawu.
///
/// Grafika jest przezroczysta, więc pod spodem leży jasne tło — czarne
/// pady na ciemnym interfejsie byłyby nieczytelne.
struct TD17KitStage: View {
    @Binding var selectedZone: Int

    /// Opis pokazywany pod nazwą wybranego pada (np. poziom w dB).
    /// Zwrócenie pustego tekstu ukrywa wiersz.
    var detail: (Int) -> String = { _ in "" }

    /// Czy strefa jest wyciszona. Wyciszony pad jest przygaszony
    /// i przekreślony, i nie dostaje podświetlenia zaznaczenia.
    var isMuted: (Int) -> Bool = { _ in false }

    @State private var hoveredPad: Int?

    var body: some View {
        VStack(spacing: 10) {
            stage
            zoneChips
        }
    }

    private var stage: some View {
        GeometryReader { geometry in
            let frame = imageFrame(in: geometry.size)

            ZStack(alignment: .topLeading) {
                RadialGradient(
                    colors: [Color(white: 0.90), Color(white: 0.58)],
                    center: .center,
                    startRadius: 20,
                    endRadius: max(geometry.size.width, geometry.size.height)
                )

                Image("TD17KitStage")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)

                // Cztery przebiegi: wyciszenia, pola trafienia, ramki,
                // na wierzchu podpisy. Inaczej ramka sąsiada potrafiłaby
                // przykryć podpis, a podpis — przechwycić kliknięcie.
                ForEach(TD17KitLayout.pads) { pad in
                    padMute(pad, in: frame)
                }
                ForEach(TD17KitLayout.pads) { pad in
                    padHitArea(pad, in: frame)
                }
                ForEach(TD17KitLayout.pads) { pad in
                    padSelection(pad, in: frame)
                }
                ForEach(TD17KitLayout.pads) { pad in
                    padLabel(pad, in: frame)
                }
            }
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }

    /// Przygaszenie i przekreślenie wyciszonego pada.
    /// Wyszarzenie wyciszonego pada.
    ///
    /// Prawie każdy pad ma **kilka stref**: werbel to naciąg i obręcz, ride
    /// nawet trzy. Warunek „wszystkie strefy wyciszone" znaczył w praktyce,
    /// że wyciszenie widać wyłącznie na stopie — jedynym padzie z jedną
    /// strefą. Wyciszenie choćby jednej strefy jest teraz widoczne: pełna
    /// szarość, gdy milczy cały pad, przygaszona, gdy tylko jego część.
    private func padMute(_ pad: TD17StagePad, in frame: CGRect) -> some View {
        let size = padSize(pad, in: frame)
        let mutedCount = pad.zoneIndices.filter { isMuted($0) }.count
        let all = mutedCount == pad.zoneIndices.count && mutedCount > 0
        let some = mutedCount > 0 && !all

        return Group {
            if all || some {
                // Jednolita szarość spłaszcza pad niezależnie od tego, czy
                // był biały (naciąg) czy czarny (talerz) — obie skrajności
                // schodzą do tego samego martwego koloru i od razu widać,
                // że pad nie gra.
                Ellipse()
                    .fill(Color(white: 0.44).opacity(all ? 0.82 : 0.45))
                    .overlay {
                        Ellipse().stroke(
                            Color(white: 0.30).opacity(all ? 1 : 0.6),
                            lineWidth: 1.5
                        )
                    }
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(pad.angle))
            }
        }
        .allowsHitTesting(false)
        .position(center(of: pad, in: frame))
    }

    /// Pole klikalne — dokładnie w kształcie pada, bez własnej grafiki.
    ///
    /// Zaznaczenie rysuje osobny przebieg, żeby ramka mogła wyjść poza
    /// obrys bębna, a pole trafienia zostało elipsą.
    private func padHitArea(_ pad: TD17StagePad, in frame: CGRect) -> some View {
        let size = padSize(pad, in: frame)

        return Button {
            selectZone(in: pad)
        } label: {
            Ellipse()
                .fill(Color.white.opacity(0.001))
                .frame(width: size.width, height: size.height)
                .contentShape(Ellipse())
                .rotationEffect(.degrees(pad.angle))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                hoveredPad = pad.id
            } else if hoveredPad == pad.id {
                hoveredPad = nil
            }
        }
        .position(center(of: pad, in: frame))
    }

    /// Ramka zaznaczenia: cztery narożniki wokół pada.
    ///
    /// Ten sam sposób, co w edytorach perkusji — czyste `[ ]`, które
    /// wskazuje element, ale niczego nie zasłania ani nie zamazuje.
    /// Ramka jest prostokątna i nieobrócona; obrót dotyczy tylko pola
    /// trafienia, bo przekręcona ramka wygląda jak błąd.
    private func padSelection(
        _ pad: TD17StagePad,
        in frame: CGRect
    ) -> some View {
        // Wyciszony pad też musi pokazywać, że jest wybrany — inaczej klik
        // w wyciszony bęben nie dawał żadnej reakcji na scenie. Ramka jest
        // wtedy szara, więc dalej widać różnicę między „wybrany" a „grający".
        let muted = pad.zoneIndices.contains { isMuted($0) }
        let selected = isSelected(pad)
        let hovered = hoveredPad == pad.id && !selected
        let box = selectionBox(pad, in: frame)

        return Group {
            if selected || hovered {
                CornerBrackets()
                    .stroke(
                        selected
                            ? (muted ? Color(white: 0.62) : Color.cyan)
                            : Color.white.opacity(0.75),
                        style: StrokeStyle(
                            lineWidth: selected ? 2.5 : 2,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: box.width, height: box.height)
                    .shadow(
                        color: .black.opacity(0.55),
                        radius: 3,
                        x: 0,
                        y: 1
                    )
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: selected)
        .animation(.easeOut(duration: 0.12), value: hovered)
        .position(center(of: pad, in: frame))
    }

    /// Podpis pojawia się pod padem wybranym albo wskazanym kursorem.
    /// Stale widoczne podpisy przy wszystkich dziewięciu padach robiły
    /// z czytelnego zdjęcia gąszcz plakietek.
    private func padLabel(_ pad: TD17StagePad, in frame: CGRect) -> some View {
        let selected = isSelected(pad)
        let hovered = hoveredPad == pad.id && !selected
        let box = selectionBox(pad, in: frame)
        let origin = center(of: pad, in: frame)
        let detailText = detail(selectedZoneIndex(for: pad))

        return Group {
            if selected || hovered {
                VStack(spacing: 2) {
                    Text(pad.shortName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                    if selected, !detailText.isEmpty {
                        Text(detailText)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.82), in: Capsule())
            }
        }
        .allowsHitTesting(false)
        .position(x: origin.x, y: origin.y + box.height / 2 + 15)
    }

    /// Prostokąt ramki: obrys pada z niewielkim luzem, żeby narożniki
    /// nie dotykały krawędzi naciągu.
    private func selectionBox(
        _ pad: TD17StagePad,
        in frame: CGRect
    ) -> CGSize {
        let size = padSize(pad, in: frame)
        let padding = max(7, size.width * 0.07)
        return CGSize(
            width: size.width + padding * 2,
            height: size.height + padding * 2
        )
    }

    /// Wiersz stref: podstrefy wybranego pada plus pady bez reprezentacji
    /// na scenie.
    private var zoneChips: some View {
        let pad = TD17KitLayout.pad(containing: selectedZone)

        return HStack(spacing: 6) {
            if let pad {
                ForEach(pad.zoneIndices, id: \.self) { zone in
                    chip(zone)
                }
                Divider().frame(height: 18)
            }
            ForEach(TD17KitLayout.detachedZoneIndices, id: \.self) { zone in
                chip(zone)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Pastylka strefy.
    ///
    /// Wyciszenie musi być widać także tutaj: strefy AUX i obręcze nie mają
    /// własnego kształtu na zdjęciu, więc pastylka jest **jedynym** miejscem
    /// na scenie, gdzie w ogóle da się je zobaczyć.
    private func chip(_ zone: Int) -> some View {
        let selected = zone == selectedZone
        let muted = isMuted(zone)
        let name = TD17ZoneCatalog.names.indices.contains(zone)
            ? TD17ZoneCatalog.names[zone]
            : "STREFA \(zone)"

        let background: Color = selected
            ? (muted ? Color(white: 0.42) : Color.cyan)
            : Color.white.opacity(muted ? 0.04 : 0.08)
        let foreground: Color = selected
            ? (muted ? Color(white: 0.85) : Color.black)
            : (muted ? Color.secondary : Color.primary)

        return Button {
            selectedZone = zone
        } label: {
            HStack(spacing: 4) {
                if muted {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 8, weight: .bold))
                }
                Text(name)
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Geometria

    private func isSelected(_ pad: TD17StagePad) -> Bool {
        pad.zoneIndices.contains(selectedZone)
    }

    /// Obie półosie skalują się szerokością obrazu — patrz komentarz przy
    /// `TD17StagePad.radiusX`.
    private func padSize(_ pad: TD17StagePad, in frame: CGRect) -> CGSize {
        CGSize(
            width: pad.radiusX * 2 * frame.width,
            height: pad.radiusY * 2 * frame.width
        )
    }

    private func center(of pad: TD17StagePad, in frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.minX + pad.center.x * frame.width,
            y: frame.minY + pad.center.y * frame.height
        )
    }

    /// Kliknięcie w pad wybiera jego HEAD, chyba że któraś z jego stref
    /// jest już wybrana — wtedy zostaje przy niej, żeby nie gubić wyboru
    /// RIM-u przy przypadkowym kliknięciu.
    ///
    /// Wybór jest przypisywany **zawsze**, także gdy nic się nie zmienia:
    /// samo kliknięcie w pad ma przestawiać inspektor na parametry strefy,
    /// a tym zajmuje się już `KitEditor.selectedZone`.
    private func selectZone(in pad: TD17StagePad) {
        selectedZone = selectedZoneIndex(for: pad)
    }

    private func selectedZoneIndex(for pad: TD17StagePad) -> Int {
        isSelected(pad) ? selectedZone : pad.id
    }

    /// Prostokąt, w którym faktycznie leży obraz po dopasowaniu proporcji.
    /// Pozycje padów są liczone względem niego, a nie względem całego pola.
    private func imageFrame(in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }

        let aspect = TD17KitLayout.imageAspectRatio
        let fitted: CGSize = size.width / size.height > aspect
            ? CGSize(width: size.height * aspect, height: size.height)
            : CGSize(width: size.width, height: size.width / aspect)

        return CGRect(
            x: (size.width - fitted.width) / 2,
            y: (size.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }
}

/// Cztery narożniki ramki zaznaczenia — `[ ]` zamiast pełnego prostokąta.
private struct CornerBrackets: Shape {
    /// Długość ramienia narożnika jako ułamek krótszego boku.
    var armRatio: CGFloat = 0.26

    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) * armRatio
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))

        return path
    }
}
