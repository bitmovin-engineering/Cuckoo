#if os(iOS) || os(tvOS) || os(macOS)
//
//  CompilerDirectivesTesting.swift
//  Cuckoo
//
//  Created by David Steinacher on 19.10.23.
//

import Foundation

protocol CompilerDirectivesTest {
    func doSomething(str: String) -> String
}
#endif
