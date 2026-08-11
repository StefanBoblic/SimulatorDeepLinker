//
//  ClipboardService.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import AppKit

protocol ClipboardReading {
    func string() -> String?
}

struct SystemClipboardService: ClipboardReading {
    func string() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
