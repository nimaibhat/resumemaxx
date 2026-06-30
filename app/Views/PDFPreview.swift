import SwiftUI
import PDFKit

// Lets the toolbar drive zoom on the underlying PDFView.
@MainActor
final class PDFController: ObservableObject {
    weak var view: PDFView?
    func zoomIn() { view?.zoomIn(nil) }
    func zoomOut() { view?.zoomOut(nil) }
    func fit() {
        guard let v = view else { return }
        v.autoScales = true
        v.scaleFactor = v.scaleFactorForSizeToFit
    }
    func actualSize() {
        guard let v = view else { return }
        v.autoScales = false
        v.scaleFactor = 1
    }
    var percent: Int {
        guard let v = view else { return 100 }
        return Int((v.scaleFactor / max(0.0001, v.scaleFactorForSizeToFit)) * 100)
    }
}

// Native PDF preview: text selection, copy, search, marquee/region zoom, pinch
// magnification and smooth scroll all come from PDFKit.
struct PDFPreview: NSViewRepresentable {
    let url: URL?
    @Binding var reloadToken: Int
    var controller: PDFController?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(Theme.bg)
        view.pageShadowsEnabled = true
        view.allowsDragging = true        // drag a rectangle to region-zoom
        view.maxScaleFactor = 6
        view.minScaleFactor = 0.2
        controller?.view = view
        load(into: view)
        context.coordinator.lastURL = url
        context.coordinator.lastToken = reloadToken
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        controller?.view = view
        let urlChanged = context.coordinator.lastURL != url
        let tokenChanged = context.coordinator.lastToken != reloadToken
        if urlChanged || tokenChanged {
            let prevScale = view.scaleFactor
            let prevPoint = view.documentView?.visibleRect.origin
            load(into: view)
            if !urlChanged, let p = prevPoint {
                view.scaleFactor = prevScale
                view.documentView?.scroll(p)
            }
            context.coordinator.lastURL = url
            context.coordinator.lastToken = reloadToken
        }
    }

    private func load(into view: PDFView) {
        guard let url, let doc = PDFDocument(url: url) else {
            view.document = nil
            return
        }
        view.document = doc
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {
        var lastURL: URL?
        var lastToken: Int = -1
    }
}
