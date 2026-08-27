import ArgumentParser
import Testing
@testable import scipio

@Suite
struct BuildOptionGroupTests {
    @Test
    func stripStaticLibDWARFSymbolsFlagIsParsable() throws {
        let options = try BuildOptionGroup.parse(["--strip-static-lib-dwarf-symbols"])
        #expect(options.shouldStripDWARFSymbols)
    }

    @Test
    func noStripStaticLibDWARFSymbolsFlagIsParsable() throws {
        let options = try BuildOptionGroup.parse(["--no-strip-static-lib-dwarf-symbols"])
        #expect(options.shouldStripDWARFSymbols == false)
    }

    /// Ensures no option name carries a redundant dash prefix.
    @Test
    func optionNamesHaveNoRedundantDashPrefix() {
        #expect(!BuildOptionGroup.helpMessage().contains("----"))
    }
}
