import Foundation
import ScipioKitCore

struct BinaryExtractor {
    var descriptionPackage: DescriptionPackage
    var outputDirectory: URL
    var fileSystem: any FileSystem

    @discardableResult
    func extract(of binaryTarget: ResolvedModule, overwrite: Bool) throws -> URL {
        guard case let .binary(binaryLocation) = binaryTarget.resolvedModuleType else {
            preconditionFailure(
                """
                \(#function) must be called with a binary target.
                target name: \(binaryTarget.c99name), actual module type: \(binaryTarget.resolvedModuleType)
                """
            )
        }

        let artifactURL = binaryLocation.artifactURL(rootPackageDirectory: descriptionPackage.packageDirectory)

        // The destination is deleted before the copy when `overwrite` is set, so it has to be an
        // XCFramework and nothing else. A binary target that resolves to some other directory --
        // a source root, say -- would otherwise take that directory's contents down with it, and
        // the output directory is frequently the package directory itself.
        guard artifactURL.pathExtension == "xcframework" else {
            throw Error.artifactIsNotAnXCFramework(targetName: binaryTarget.name, artifactURL: artifactURL)
        }

        let frameworkName = "\(binaryTarget.c99name).xcframework"
        let fileName = artifactURL.lastPathComponent
        let destinationPath = outputDirectory.appendingPathComponent(fileName)
        if fileSystem.exists(destinationPath) && overwrite {
            logger.info("🗑️ Delete \(frameworkName)", metadata: .color(.red))
            try fileSystem.removeFileTree(destinationPath)
        }
        try fileSystem.copy(
            from: artifactURL,
            to: destinationPath
        )

        return destinationPath
    }

    enum Error: LocalizedError {
        case artifactIsNotAnXCFramework(targetName: String, artifactURL: URL)

        var errorDescription: String? {
            switch self {
            case .artifactIsNotAnXCFramework(let targetName, let artifactURL):
                """
                The binary target \(targetName) resolved to \
                \(artifactURL.path(percentEncoded: false)), which is not an XCFramework.
                """
            }
        }
    }
}
