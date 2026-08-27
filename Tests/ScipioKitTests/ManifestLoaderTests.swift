import Foundation
import Testing
@testable @_spi(Internals) import ScipioKit

struct ManifestLoaderTests {
    // A minimal dump-package payload whose top-level `traits` is the SwiftPM 6.1
    // object form, decoded via PackageManifestKit's TraitDescription model.
    private static let manifestWithObjectFormTraits = """
    {
      "name": "MyFramework",
      "toolsVersion": { "_version": "6.1.0" },
      "dependencies": [],
      "products": [],
      "targets": [],
      "packageKind": { "root": ["/tmp/MyFramework"] },
      "traits": [
        { "name": "default", "enabledTraits": ["Foo"] },
        { "name": "Foo", "description": "bar", "enabledTraits": [] }
      ]
    }
    """

    // Same manifest without a `traits` key.
    private static let manifestWithoutTraits = """
    {
      "name": "MyFramework",
      "toolsVersion": { "_version": "6.1.0" },
      "dependencies": [],
      "products": [],
      "targets": [],
      "packageKind": { "root": ["/tmp/MyFramework"] }
    }
    """

    @Test
    func decodesManifestDeclaringObjectFormTraits() async throws {
        let executor = StubbableExecutor { arguments in
            StubbableExecutorResult(arguments: arguments, success: Self.manifestWithObjectFormTraits)
        }
        let loader = ManifestLoader(executor: executor)

        let manifest = try await loader.loadManifest(for: URL(filePath: "/tmp/MyFramework"))

        #expect(manifest.name == "MyFramework")
        let traits = try #require(manifest.traits)
        #expect(traits.map(\.name) == ["default", "Foo"])
        #expect(traits[0].enabledTraits == ["Foo"])
        #expect(traits[1].description == "bar")
    }

    @Test
    func decodesManifestWithoutTraits() async throws {
        let executor = StubbableExecutor { arguments in
            StubbableExecutorResult(arguments: arguments, success: Self.manifestWithoutTraits)
        }
        let loader = ManifestLoader(executor: executor)

        let manifest = try await loader.loadManifest(for: URL(filePath: "/tmp/MyFramework"))

        #expect(manifest.name == "MyFramework")
    }

    @Test
    func reportsWhichManifestFieldFailedToDecode() async throws {
        // `products` is required, so omitting it fails the decode. The reported message has to name
        // the field: `DecodingError.localizedDescription` alone only says the data "isn't in the
        // correct format", which leaves nothing to act on.
        let manifestMissingProducts = """
        {
          "name": "MyFramework",
          "toolsVersion": { "_version": "6.1.0" },
          "dependencies": [],
          "targets": [],
          "packageKind": { "root": ["/tmp/MyFramework"] }
        }
        """
        let executor = StubbableExecutor { arguments in
            StubbableExecutorResult(arguments: arguments, success: manifestMissingProducts)
        }
        let loader = ManifestLoader(executor: executor)

        await #expect {
            try await loader.loadManifest(for: URL(filePath: "/tmp/MyFramework"))
        } throws: { error in
            let description = error.localizedDescription
            return description.contains("/tmp/MyFramework")
                && description.contains("products")
        }
    }
}
