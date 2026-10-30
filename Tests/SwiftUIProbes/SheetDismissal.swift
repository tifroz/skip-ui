// Copyright 2026 Skip
// SPDX-License-Identifier: MPL-2.0
// Standalone native SwiftUI reference app. See ../SheetDismissal.md.
import SwiftUI
import UIKit

@main struct ProbeApp: App {
    var body: some Scene { WindowGroup { ProbeView() } }
}

/// Samples rendered sheet geometry rather than SwiftUI's final layout values.
@MainActor final class Measurements: NSObject {
    static let shared = Measurements()
    weak var window: UIWindow?
    var rows: [[String: Any]] = []
    var mode = "idle"
    var start: CFTimeInterval = 0
    var link: CADisplayLink?
    /// Starts the display-link timeline immediately before the binding changes.
    func begin(_ mode: String) {
        self.mode = mode
        start = CACurrentMediaTime()
        rows.append(["mode": mode, "event": "requested", "time": 0])
        link?.invalidate()
        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
        tick()
    }
    /// Converts the presented layer's animated frame into window coordinates.
    @objc func tick() {
        guard let window else { return }
        let view = window.rootViewController?.presentedViewController?.view
        var row: [String: Any] = ["mode": mode, "event": "frame", "time": CACurrentMediaTime() - start]
        if let view, let layer = view.layer.presentation() {
            let target = window.layer.presentation() ?? window.layer
            let frame = layer.convert(layer.bounds, to: target)
            row["y"] = frame.minY; row["height"] = frame.height
        }
        rows.append(row)
    }
    func finished() {
        rows.append(["mode": mode, "event": "onDismiss", "time": CACurrentMediaTime() - start])
    }
    /// Writes cumulative measurements to the app's Documents directory after each case.
    func save() {
        link?.invalidate(); link = nil
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("measurements.json")
        try! JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]).write(to: url)
    }
}

struct WindowProbe: UIViewRepresentable {
    class Marker: UIView {
        override func didMoveToWindow() { Measurements.shared.window = window }
    }
    func makeUIView(context: Context) -> Marker { Marker() }
    func updateUIView(_ uiView: Marker, context: Context) {}
}

struct ProbeView: View {
    @State private var presented = false
    @State private var mode = "Preparing"
    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            Text(mode).font(.title).foregroundStyle(.white)
            WindowProbe().frame(width: 1, height: 1)
        }
        .sheet(isPresented: $presented, onDismiss: { Measurements.shared.finished() }) {
            ZStack { Color.red.ignoresSafeArea(); Text(mode).font(.title).foregroundStyle(.white) }
                .presentationDetents([.large])
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            for name in ["ordinary", "easeInOut-0.1", "easeInOut-2.0", "disabled"] {
                mode = name
                presented = true
                try? await Task.sleep(for: .seconds(2))
                Measurements.shared.begin(name)
                switch name {
                case "easeInOut-0.1": withAnimation(.easeInOut(duration: 0.1)) { presented = false }
                case "easeInOut-2.0": withAnimation(.easeInOut(duration: 2.0)) { presented = false }
                case "disabled":
                    var transaction = Transaction(); transaction.disablesAnimations = true
                    withTransaction(transaction) { presented = false }
                default: presented = false
                }
                try? await Task.sleep(for: .seconds(3))
                Measurements.shared.save()
            }
            mode = "Finished"
        }
    }
}
