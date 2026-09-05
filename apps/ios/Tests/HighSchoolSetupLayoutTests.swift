import CoreGraphics
import SwiftUI
import UIKit
import XCTest
@testable import BaseballIOS

/// 선수 만들기 제목이 머리·화면 왼쪽으로 잘리지 않는지.
///
/// 소스 계약은 리팩터를 잡고, ImageRenderer는 한글 획이 실제로 잘렸는지를 잡는다.
/// 1.0.2 리뷰 "글씨가 화면 밖으로", 페르소나 05-setup-repertoire 제목 윗획 잘림.
final class HighSchoolSetupLayoutTests: XCTestCase {
    func testSetupStepTransitionIsClippedToScrollArea() throws {
        let source = try IOSSourceScan.read(
            "apps/ios/Sources/Features/HighSchool/HighSchoolSetupView.swift"
        )
        XCTAssertTrue(
            source.contains(".clipped()"),
            "단계 전환이 머리 밖으로 밀리면 새 제목이 잘린다."
        )
        XCTAssertTrue(source.contains("setup-step-\\(step)"))
        let transitionRange = try XCTUnwrap(source.range(of: "insertion: .move(edge: .trailing)"))
        let switchRange = try XCTUnwrap(source.range(of: "switch step {"))
        XCTAssertLessThan(
            switchRange.lowerBound,
            transitionRange.lowerBound,
            "밀어내기 전환은 단계 콘텐츠가 아니라 스크롤 영역 전체에 걸어야 한다."
        )
        let innerID = source.range(of: ".id(step)")
        XCTAssertNil(innerID, "스크롤 안 콘텐츠에 다시 id를 붙이면 제목이 머리 밑으로 들어간다.")
    }

    func testSetupQuestionsUseUnclippedTitleStyle() throws {
        let files = try IOSSourceScan.readAll([
            "apps/ios/Sources/Features/HighSchool/HighSchoolSetupView.swift",
            "apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+NameStep.swift",
            "apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+RegionStep.swift",
            "apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+StyleStep.swift",
            "apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+RepertoireStep.swift",
            "apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+HandicapStep.swift",
        ])
        XCTAssertTrue(files.contains("func setupQuestionStyle()"))
        XCTAssertTrue(files.contains("BaseballMetrics.titleAscentClearance"))
        XCTAssertTrue(files.contains("hs.setup.question"))
        XCTAssertGreaterThanOrEqual(
            files.components(separatedBy: ".setupQuestionStyle()").count - 1,
            5,
            "이름·지역·유형·구종·핸디캡 제목이 같은 여백 계약을 써야 한다."
        )
    }

    func testKeyArtHeaderDoesNotClipDisplayTitle() throws {
        let source = try IOSSourceScan.typeBody(
            "KeyArtHeader",
            in: "apps/ios/Sources/Presentation/DesignSystem.swift"
        )
        XCTAssertTrue(source.contains("BaseballMetrics.titleLeadingClearance"))
        XCTAssertTrue(source.contains("BaseballMetrics.titleAscentClearance"))
        XCTAssertFalse(
            source.contains(".clipped()\n        .accessibilityElement"),
            "키아트 바깥 clipped는 largeTitle 한글 획을 자른다. 그림만 자른다."
        )
    }

    func testTitleClearanceConstantsStayPositive() {
        XCTAssertGreaterThanOrEqual(BaseballMetrics.titleAscentClearance, 4)
        XCTAssertGreaterThanOrEqual(BaseballMetrics.titleLeadingClearance, 6)
    }

    @MainActor
    func testHangulQuestionTitleInkClearsClipEdges() throws {
        let view = Text("어떤 구종으로 시작할까요?")
            .setupQuestionStyle()
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
            .frame(width: 390, alignment: .topLeading)
            .clipped()
        let image = try render(view, width: 390, height: 120, scale: 3)
        let insets = inkInsets(of: image)
        let scale = 3
        XCTAssertGreaterThan(
            insets.top,
            0,
            "한글 윗획이 클립 상단에 붙어 잘렸다. top=\(insets.top)"
        )
        XCTAssertGreaterThanOrEqual(
            insets.top,
            Int(BaseballMetrics.titleAscentClearance * CGFloat(scale)) - scale,
            "제목 윗여백이 줄면 한글이 다시 잘린다. top=\(insets.top)"
        )
        XCTAssertGreaterThan(insets.bottom, 4)
        XCTAssertGreaterThan(insets.right, 4)
    }

    @MainActor
    func testSetupChromeKeepsQuestionBelowHeaderBand() throws {
        let headerHeight: CGFloat = 72
        let view = VStack(spacing: 0) {
            Color(white: 0.25).frame(height: headerHeight)
            ZStack {
                Text("어떤 구종으로 시작할까요?")
                    .setupQuestionStyle()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(BaseballMetrics.gutter)
            }
            .clipped()
        }
        .frame(width: 390, height: 280, alignment: .top)
        .background(Color.black)

        let scale: CGFloat = 3
        let image = try render(view, width: 390, height: 280, scale: scale)
        let headerBottom = Int(headerHeight * scale)
        let samples = inkSamples(of: image)
        let inkInHeader = samples.contains { $0.y < headerBottom - 2 && $0.isInk }
        XCTAssertFalse(
            inkInHeader,
            "단계 제목이 머리 띠 안으로 올라와 윗획이 잘린다."
        )
        let firstInkBelowHeader = samples.first { $0.y >= headerBottom && $0.isInk }
        XCTAssertNotNil(firstInkBelowHeader, "머리 아래에서 제목 잉크를 찾지 못했다.")
        if let first = firstInkBelowHeader {
            XCTAssertGreaterThanOrEqual(
                first.x,
                Int(BaseballMetrics.gutter * scale) - Int(scale),
                "제목이 화면 왼쪽으로 밀려 잘렸다. x=\(first.x)"
            )
        }
    }

    @MainActor
    private func render(_ view: some View, width: CGFloat, height: CGFloat, scale: CGFloat) throws -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.scale = scale
        return try XCTUnwrap(renderer.uiImage, "제목 렌더가 비었습니다.")
    }

    private struct InkPoint {
        let x: Int
        let y: Int
        let isInk: Bool
    }

    private func inkInsets(of image: UIImage, threshold: UInt8 = 24) -> (top: Int, left: Int, bottom: Int, right: Int) {
        let samples = inkSamples(of: image, threshold: threshold).filter(\.isInk)
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        let top = samples.map(\.y).min() ?? height
        let left = samples.map(\.x).min() ?? width
        let bottom = height - 1 - (samples.map(\.y).max() ?? 0)
        let right = width - 1 - (samples.map(\.x).max() ?? 0)
        return (top, left, bottom, right)
    }

    private func inkSamples(of image: UIImage, threshold: UInt8 = 24) -> [InkPoint] {
        guard let cgImage = image.cgImage else { return [] }
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var samples: [InkPoint] = []
        samples.reserveCapacity(width * height / 16)
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let i = (y * width + x) * 4
                let ink = bytes[i + 3] > threshold
                    && (bytes[i] > 180 || bytes[i + 1] > 180 || bytes[i + 2] > 180)
                if ink || (x % 8 == 0 && y % 8 == 0) {
                    samples.append(InkPoint(x: x, y: y, isInk: ink))
                }
            }
        }
        return samples
    }
}
