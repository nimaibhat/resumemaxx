import SwiftUI
import PDFKit

// Native PDF preview. Gives text selection, copy, search, marquee/region zoom,
// pinch-to-zoom and smooth scroll for free - the things a terminal could not do.
struct PDFPreview: NSViewRepresentable {
    let url: URL?
    @Binding var reloadToken: Int   // bump to reload the same URL after a recompile

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(Theme.bg)
        view.pageShadowsEnabled = true
        // Marquee zoom: drag a rectangle to zoom into a region.
        view.allowsDragging = true
        load(into: view)
        context.coordinator.lastURL = url
        context.coordinator.lastToken = reloadToken
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        let urlChanged = context.coordinator.lastURL != url
        let tokenChanged = context.coordinator.lastToken != reloadToken
        if urlChanged || tokenChanged {
            // Preserve scroll position + scale across a live recompile reload.
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
