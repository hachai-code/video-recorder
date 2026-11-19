import Testing
import CoreGraphics
@testable import Recorder

@Test func bubbleSitsInRequestedCorner() {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 500)
    #expect(bubbleRect(side: 100, corner: .bottomLeft, in: bounds, margin: 10) == CGRect(x: 10, y: 10, width: 100, height: 100))
    #expect(bubbleRect(side: 100, corner: .topRight, in: bounds, margin: 10) == CGRect(x: 890, y: 390, width: 100, height: 100))
}

@Test func videoSizeIsEvenAndCappedAt4K() {
    #expect(fittedVideoSize(CGSize(width: 1281, height: 721)) == CGSize(width: 1280, height: 720))
    #expect(fittedVideoSize(CGSize(width: 5120, height: 2880)) == CGSize(width: 3840, height: 2160))
}
