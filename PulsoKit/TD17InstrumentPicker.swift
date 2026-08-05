import SwiftUI

/// Wybór instrumentu z katalogu TD-17.
///
/// Katalog ma 311 pozycji. Płaski `Picker` budował 311 widoków `Text`
/// z formatowaniem tekstu **przy każdym przeliczeniu widoku** — a przy
/// kilkunastu strefach naraz to były tysiące widoków na jedno wejście
/// w zakładkę. To była główna przyczyna zacinania się przy przełączaniu
/// między zakładkami.
///
/// Menu buduje zawartość dopiero po otwarciu, a podział na rodziny
/// instrumentów robi z 311 pozycji kilkanaście krótkich list.
struct TD17InstrumentPicker: View {
    @Binding var selection: Int

    /// Szerokość etykiety. Zakładki mają różne siatki.
    var width: CGFloat = 170

    var body: some View {
        Menu {
            ForEach(TD17InstrumentIndex.groups, id: \.name) { group in
                Menu(group.name) {
                    ForEach(group.ids, id: \.self) { id in
                        Button(TD17InstrumentIndex.label(for: id)) {
                            selection = id
                        }
                    }
                }
            }
        } label: {
            Text(TD17InstrumentIndex.label(for: selection))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: width)
    }
}

enum TD17InstrumentIndex {
    struct Group {
        let name: String
        let ids: [Int]
    }

    /// Rodziny instrumentów w kolejności występowania w katalogu.
    static let groups: [Group] = {
        var order: [String] = []
        var byGroup: [String: [Int]] = [:]

        for (id, instrument) in TD17InstrumentCatalog.instruments.enumerated() {
            if byGroup[instrument.group] == nil {
                order.append(instrument.group)
                byGroup[instrument.group] = []
            }
            byGroup[instrument.group]?.append(id)
        }

        return order.map { Group(name: $0, ids: byGroup[$0] ?? []) }
    }()

    static func label(for id: Int) -> String {
        guard TD17InstrumentCatalog.instruments.indices.contains(id) else {
            return "nieznany (\(id))"
        }
        return "\(TD17InstrumentCatalog.instruments[id].name) (#\(id))"
    }
}
