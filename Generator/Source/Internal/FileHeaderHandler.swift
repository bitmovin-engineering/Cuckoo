import Foundation
import FileKit

public struct FileHeaderHandler {

    public static func getHeader(of file: FileRepresentation, includeTimestamp: Bool) -> String {
        let path: String
        if let absolutePath = file.sourceFile.path {
            path = getRelativePath(from: absolutePath)
        } else {
            path = "unknown"
        }
        let generationInfo = "// MARK: - Mocks generated from file: \(path)" + (includeTimestamp ? " at \(Date())\n" : "")
        let header = getHeader(of: file)
        return generationInfo + "\n" + header + "\n"
    }

    public static func getImports(
        of file: FileRepresentation,
        testableFrameworks: [String],
        spiImports: [String]
    ) -> String {
        var imports = Array(Set(file.declarations.only(Import.self).map { "import \($0.importee)\n" })).sorted().joined(separator: "")
        if imports.isEmpty == false {
            imports = "\n\(imports)"
        }
        return "import Cuckoo\n"
            + getConfiguredImports(testableFrameworks: testableFrameworks, spiImports: spiImports)
            + imports
    }

    private static func getRelativePath(from absolutePath: String) -> String {
        let path = Path(absolutePath)
        let base = path.commonAncestor(Path.current)
        let components = path.components.suffix(from: base.components.endIndex)
        let result = components.map { $0.rawValue }.joined(separator: Path.separator)
        let difference = Path.current.components.endIndex - base.components.endIndex
        return (0..<difference).reduce(result) { acc, _ in ".." + Path.separator + acc }
    }

    private static func getHeader(of file: FileRepresentation) -> String {
        let possibleHeaderEnd = getPossibleHeaderEnd(current: file.sourceFile.contents.unicodeScalars.count, declarations: file.declarations)
        let possibleHeader = String(file.sourceFile.contents.utf8.prefix(possibleHeaderEnd)) ?? ""
        let singleLine = getPrefixToLastSingleLineComment(text: possibleHeader)
        let multiLine = getPrefixToLastMultiLineComment(text: possibleHeader)
        return singleLine.count > multiLine.count ? singleLine : multiLine
    }

    private static func getPossibleHeaderEnd(current: Int, declarations: [Token]) -> Int {
        return declarations.reduce(current) { minimum, declaration in
            let declarationMinimum: Int
            switch declaration {
            case let containerToken as ContainerToken:
                declarationMinimum = containerToken.range.lowerBound
            case let method as Method:
                declarationMinimum = method.range.lowerBound
            case let importToken as Import:
                declarationMinimum = importToken.range.lowerBound
            default:
                declarationMinimum = minimum
            }
            return min(declarationMinimum, minimum)
        }
    }

    private static func getPrefixToLastSingleLineComment(text: String) -> String {
        if let range = text.range(of: "//", options: .backwards) {
            let lastLine = text.lineRange(for: range)
            return String(text[..<lastLine.upperBound])
        } else {
            return ""
        }
    }

    private static func getPrefixToLastMultiLineComment(text: String) -> String {
        if let range = text.range(of: "*/", options: .backwards) {
            return String(text[..<range.upperBound]) + "\n"
        } else {
            return ""
        }
    }

    private static func getConfiguredImports(
        testableFrameworks: [String],
        spiImports: [String]
    ) -> String {
        func replaceIllegalCharacters(_ char: UnicodeScalar) -> Character {
            if CharacterSet.letters.contains(UnicodeScalar(char.value)!) || CharacterSet.decimalDigits.contains(UnicodeScalar(char.value)!) {
                return Character(char)
            } else {
                return "_"
            }
        }

        let spiImportsByModule = Dictionary(grouping: spiImports.compactMap(resolveSPIImport)) { $0.module }
        let testableModules = Set(testableFrameworks)
        let spiOnlyModules = spiImportsByModule.keys
            .filter { !testableModules.contains($0) }
            .sorted()

        return (testableFrameworks + spiOnlyModules).map { module in
            let spiAttributes = spiImportsByModule[module, default: []]
                .map { String($0.spi.unicodeScalars.map(replaceIllegalCharacters)) }
                .map { "@_spi(\($0))" }
            let testableAttribute = testableModules.contains(module) ? ["@testable"] : []
            let importAttributes = (spiAttributes + testableAttribute).joined(separator: " ")
            let moduleName = String(module.unicodeScalars.map(replaceIllegalCharacters))
            return "\(importAttributes) import \(moduleName)\n"
        }.joined(separator: "")
    }

    private static func resolveSPIImport(_ spiImport: String) -> (module: String, spi: String)? {
        let components = spiImport.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard components.count == 2 else { return nil }

        let module = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let spi = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !module.isEmpty, !spi.isEmpty else { return nil }

        return (module: module, spi: spi)
    }
}
