import Testing
@testable import Markout

struct AssetStoreTests {
    @Test func firstNameIsUnchanged() {
        #expect(AssetStore.uniqueName(base: "image", ext: "png", existing: []) == "image.png")
    }

    @Test func appendsCounterOnCollision() {
        let taken: Set<String> = ["image.png", "image-1.png"]
        #expect(AssetStore.uniqueName(base: "image", ext: "png", existing: taken) == "image-2.png")
    }

    @Test func sanitizesBaseName() {
        let name = AssetStore.uniqueName(base: "My Photo!", ext: "png", existing: [])
        #expect(!name.contains(" "))
        #expect(!name.contains("!"))
        #expect(name.hasSuffix(".png"))
    }

    @Test func emptyBaseFallsBackToImage() {
        #expect(AssetStore.uniqueName(base: "***", ext: "png", existing: []) == "image.png")
    }
}
