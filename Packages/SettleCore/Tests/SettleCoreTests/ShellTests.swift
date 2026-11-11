import Testing
@testable import SettleCore

@Test func shellReturnsOutput() throws {
    let output = try Shell.run("/bin/echo", ["hello"])
    #expect(output == "hello\n")
}
