import Foundation
import PackageManifestKit
import ScipioKitCore

/// Loads the `Manifest` of a Swift package
struct ManifestLoader: @unchecked Sendable {
    private let executor: any Executor
    private let jsonDecoder = JSONDecoder()

    init(executor: some Executor) {
        self.executor = executor
    }

    /// Loads the manifest for a package at a local path.
    /// - Parameter packagePath: The file path of the package.
    /// - Returns: A decoded `Manifest` object.
    func loadManifest(for packagePath: URL) async throws -> Manifest {
        try await loadManifest(path: packagePath.path(percentEncoded: false))
    }

    /// Loads the manifest for a dependency package.
    /// - Parameter dependencyPackage: A package from the dependencies.
    /// - Returns: A decoded `Manifest` object.
    @_disfavoredOverload
    func loadManifest(for dependencyPackage: DependencyPackage) async throws -> Manifest {
        try await loadManifest(path: dependencyPackage.path)
    }

    private func loadManifest(path: String) async throws -> Manifest {
        let commands = [
            "/usr/bin/xcrun",
            "swift",
            "package",
            "dump-package",
            "--package-path",
            path,
        ]

        let manifestData = try await executor.execute(commands)
            .unwrapOutput()
            .data(using: .utf8)

        guard let manifestData else {
            throw Error.utf8EncodingFailed
        }

        do {
            return try jsonDecoder.decode(Manifest.self, from: manifestData)
        } catch let decodingError as DecodingError {
            throw Error.manifestDecodingFailed(path: path, decodingError: decodingError)
        }
    }

    enum Error: LocalizedError {
        case utf8EncodingFailed
        case manifestDecodingFailed(path: String, decodingError: DecodingError)

        var errorDescription: String? {
            switch self {
            case .utf8EncodingFailed:
                "Failed to convert the command output string to UTF-8 encoded data"
            case .manifestDecodingFailed(let path, let decodingError):
                [
                    "Could not read the manifest of \((path as NSString).standardizingPath).",
                    decodingError.detailedDescription,
                    """
                    This usually means the package declares something a newer SwiftPM emits \
                    that this build of Scipio does not understand yet. \
                    Updating Scipio normally resolves it.
                    """,
                ].joined(separator: "\n")
            }
        }
    }
}

extension DecodingError {
    /// `DecodingError.localizedDescription` collapses to "The data couldn't be read because it
    /// isn't in the correct format", which says nothing about what actually failed. This keeps the
    /// coding path and the underlying reason so the offending manifest field is identifiable.
    var detailedDescription: String {
        func describe(_ context: Context, _ reason: String) -> String {
            let codingPath = context.codingPath
                .map { $0.intValue.map { index in "[\(index)]" } ?? ".\($0.stringValue)" }
                .joined()
                .drop { $0 == "." }

            let location = codingPath.isEmpty ? "the manifest root" : String(codingPath)
            return "\(reason) at \(location): \(context.debugDescription)"
        }

        return switch self {
        case .typeMismatch(let type, let context):
            describe(context, "Unexpected value for \(type)")
        case .valueNotFound(let type, let context):
            describe(context, "Missing value of \(type)")
        case .keyNotFound(let key, let context):
            describe(context, "Missing key '\(key.stringValue)'")
        case .dataCorrupted(let context):
            describe(context, "Corrupted data")
        @unknown default:
            localizedDescription
        }
    }
}
