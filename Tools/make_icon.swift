#!/usr/bin/env swift
//
// make_icon.swift
// Generates the "Svátek dnes" app icon: a stylized white 5-petal blossom
// with a warm yellow center on a dark green gradient background.
//
// Usage: swift Tools/make_icon.swift <output.png>
//
// Output: 1024x1024 sRGB PNG, no alpha channel (opaque, full bleed).
//

import Foundation
import CoreGraphics
import ImageIO

// MARK: - Arguments

guard CommandLine.arguments.count == 2 else {
	FileHandle.standardError.write(Data("Usage: swift make_icon.swift <output.png>\n".utf8))
	exit(1)
}
let outputPath = CommandLine.arguments[1]

// MARK: - Setup

let size = 1024
let sizeF = CGFloat(size)

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
	FileHandle.standardError.write(Data("error: cannot create sRGB color space\n".utf8))
	exit(1)
}

// Opaque bitmap: alpha byte present in memory but ignored -> PNG has no alpha.
guard let ctx = CGContext(
	data: nil,
	width: size,
	height: size,
	bitsPerComponent: 8,
	bytesPerRow: 0,
	space: colorSpace,
	bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
	FileHandle.standardError.write(Data("error: cannot create bitmap context\n".utf8))
	exit(1)
}

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1.0) -> CGColor {
	let r = CGFloat((hex >> 16) & 0xFF) / 255.0
	let g = CGFloat((hex >> 8) & 0xFF) / 255.0
	let b = CGFloat(hex & 0xFF) / 255.0
	return CGColor(colorSpace: colorSpace, components: [r, g, b, alpha])!
}

// MARK: - Background: diagonal dark green gradient

let bgTop = rgb(0x17714A)		// lighter green, top left
let bgBottom = rgb(0x0B4D2C)	// darker green, bottom right
let bgGradient = CGGradient(
	colorsSpace: colorSpace,
	colors: [bgTop, bgBottom] as CFArray,
	locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(
	bgGradient,
	start: CGPoint(x: 0, y: sizeF),		// top left (CG origin is bottom left)
	end: CGPoint(x: sizeF, y: 0),		// bottom right
	options: []
)

// Subtle radial glow behind the flower so it sits in a pool of light.
let center = CGPoint(x: sizeF / 2, y: sizeF / 2)
let glowGradient = CGGradient(
	colorsSpace: colorSpace,
	colors: [rgb(0x2E8F63, 0.45), rgb(0x2E8F63, 0.0)] as CFArray,
	locations: [0.0, 1.0]
)!
ctx.drawRadialGradient(
	glowGradient,
	startCenter: center,
	startRadius: 0,
	endCenter: center,
	endRadius: 520,
	options: []
)

// MARK: - Flower geometry

// One petal, pointing up (+y), local origin at the flower center.
// Rounded tip (horizontal tangent at the apex), gently tapered base.
func makePetal() -> CGPath {
	let rInner: CGFloat = 56	// where the petal meets the center
	let rTip: CGFloat = 342		// petal apex
	let halfW: CGFloat = 124	// max half width

	let p = CGMutablePath()
	p.move(to: CGPoint(x: 0, y: rInner))
	// Right side: base -> tip, bulging outward, arriving horizontally.
	p.addCurve(
		to: CGPoint(x: 0, y: rTip),
		control1: CGPoint(x: halfW * 1.04, y: rInner + 128),
		control2: CGPoint(x: halfW * 0.62, y: rTip)
	)
	// Left side: mirror of the right side.
	p.addCurve(
		to: CGPoint(x: 0, y: rInner),
		control1: CGPoint(x: -halfW * 0.62, y: rTip),
		control2: CGPoint(x: -halfW * 1.04, y: rInner + 128)
	)
	p.closeSubpath()
	return p
}

let petal = makePetal()
let flower = CGMutablePath()
for i in 0..<5 {
	let angle = CGFloat(i) * 2.0 * .pi / 5.0
	let transform = CGAffineTransform(translationX: center.x, y: center.y)
		.rotated(by: angle)
	flower.addPath(petal, transform: transform)
}

// MARK: - Petals: soft shadow + white fill

ctx.saveGState()
ctx.setShadow(
	offset: CGSize(width: 0, height: -14),
	blur: 38,
	color: rgb(0x04220F, 0.35)
)
ctx.addPath(flower)
ctx.setFillColor(rgb(0xFBFDFA))
ctx.fillPath()
ctx.restoreGState()

// Gentle green tint at the petal bases for a hint of depth.
ctx.saveGState()
ctx.addPath(flower)
ctx.clip()
let baseTint = CGGradient(
	colorsSpace: colorSpace,
	colors: [rgb(0xD9E9DE, 0.6), rgb(0xD9E9DE, 0.0)] as CFArray,
	locations: [0.0, 1.0]
)!
ctx.drawRadialGradient(
	baseTint,
	startCenter: center,
	startRadius: 70,
	endCenter: center,
	endRadius: 210,
	options: []
)
ctx.restoreGState()

// MARK: - Warm yellow center

func fillCircle(radius: CGFloat, color: CGColor) {
	ctx.setFillColor(color)
	ctx.fillEllipse(in: CGRect(
		x: center.x - radius,
		y: center.y - radius,
		width: radius * 2,
		height: radius * 2
	))
}

fillCircle(radius: 104, color: rgb(0xE8B23C))	// deeper amber rim
fillCircle(radius: 86, color: rgb(0xF5C84B))	// warm yellow core

// MARK: - Write PNG

guard let image = ctx.makeImage() else {
	FileHandle.standardError.write(Data("error: cannot create image from context\n".utf8))
	exit(1)
}

let url = URL(fileURLWithPath: outputPath) as CFURL
guard let destination = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
	FileHandle.standardError.write(Data("error: cannot create image destination at \(outputPath)\n".utf8))
	exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
	FileHandle.standardError.write(Data("error: failed to write PNG\n".utf8))
	exit(1)
}

print("wrote \(outputPath) (\(size)x\(size), sRGB, opaque)")
