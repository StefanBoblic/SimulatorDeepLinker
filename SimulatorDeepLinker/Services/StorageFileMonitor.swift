//
//  StorageFileMonitor.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Darwin
import Foundation

final class StorageFileMonitor {
    private var source: DispatchSourceFileSystemObject?

    func start(fileURL: URL, onChange: @escaping @Sendable () -> Void) {
        stop()

        let directoryURL = fileURL.deletingLastPathComponent()
        let descriptor = open(directoryURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler(handler: onChange)
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()

        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
