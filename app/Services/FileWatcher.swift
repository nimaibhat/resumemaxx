import Foundation

// Watches a single file for changes. Re-arms on rename/delete because many
// editors save by writing a temp file and renaming over the original.
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let url: URL
    private let onChange: () -> Void

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    private func start() {
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue.global(qos: .userInitiated)
        )
        s.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = s.data
            self.onChange()
            if flags.contains(.rename) || flags.contains(.delete) {
                self.restart()
            }
        }
        s.setCancelHandler { [fd] in if fd >= 0 { close(fd) } }
        source = s
        s.resume()
    }

    private func restart() {
        stop()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.start()
        }
    }

    func stop() {
        source?.cancel()
        source = nil
        fd = -1
    }

    deinit { stop() }
}
