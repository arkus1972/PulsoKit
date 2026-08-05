import SwiftUI

@main
struct PulsoKitApp: App {
    // Modele żyją na poziomie aplikacji: przeżywają zamknięcie i ponowne
    // otwarcie okna, a stan MIDI i lista niewysłanych zmian nie mają prawa
    // wtedy zniknąć.
    @StateObject private var midi = MIDIManager()
    @StateObject private var td0 = TD0EditorModel()
    @StateObject private var kitEditor = KitEditor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(midi)
                .environmentObject(td0)
                .environmentObject(kitEditor)
        }
        // Musi być >= minimum wymuszanego przez ContentView, inaczej wielkość
        // domyślna jest nieosiągalna.
        .defaultSize(width: 1240, height: 860)
    }
}
