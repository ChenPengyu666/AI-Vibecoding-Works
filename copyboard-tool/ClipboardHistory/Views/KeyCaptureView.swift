import AppKit
import SwiftUI

// MARK: - 快捷键捕获 NSViewRepresentable

/// 用于 KeyCaptureSheet 的 NSEvent 捕获
struct KeyCaptureViewRep: NSViewRepresentable {
    let onCapture: (NSEvent.ModifierFlags, UInt16, String) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {}

    func makeCoordinator() -> KeyCaptureCoordinator {
        KeyCaptureCoordinator(onCapture: onCapture, onCancel: onCancel)
    }
}

class KeyCaptureCoordinator: NSObject, KeyCaptureViewDelegate {
    let onCapture: (NSEvent.ModifierFlags, UInt16, String) -> Void
    let onCancel: () -> Void

    init(onCapture: @escaping (NSEvent.ModifierFlags, UInt16, String) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
    }

    func view(_ v: KeyCaptureView, didCapture modFlags: NSEvent.ModifierFlags, keyCode: UInt16, char: String) {
        onCapture(modFlags, keyCode, char)
    }

    func viewDidCancel(_ v: KeyCaptureView) {
        onCancel()
    }
}

protocol KeyCaptureViewDelegate: AnyObject {
    func view(_ v: KeyCaptureView, didCapture modFlags: NSEvent.ModifierFlags, keyCode: UInt16, char: String)
    func viewDidCancel(_ v: KeyCaptureView)
}

class KeyCaptureView: NSView {
    weak var delegate: KeyCaptureViewDelegate?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            delegate?.viewDidCancel(self)
            return
        }
        let char = event.characters?.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
        delegate?.view(self, didCapture: event.modifierFlags, keyCode: event.keyCode, char: char)
    }

    override func flagsChanged(with event: NSEvent) {
        // 纯修饰键忽略
    }
}
