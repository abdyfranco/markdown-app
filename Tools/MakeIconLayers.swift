// Generates the vector layers for Support/AppIcon.icon (Icon Composer).
//   swift Tools/MakeIconLayers.swift Support/AppIcon.icon/Assets
//
// Shapes are drawn on Icon Composer's 1024×1024 canvas. Strokes are converted
// to filled outlines so the glass renderer gets clean, solid shapes.
import AppKit

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Assets")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// MARK: Geometry (SVG space: origin top-left, y down)

let page = CGRect(x: 212, y: 150, width: 600, height: 724)
let pageRadius: CGFloat = 76
let fold: CGFloat = 168

/// The page outline, with its top-right corner cut off for the fold.
func pagePath() -> CGPath {
    let p = CGMutablePath()
    let r = pageRadius
    p.move(to: CGPoint(x: page.minX + r, y: page.minY))
    p.addLine(to: CGPoint(x: page.maxX - fold, y: page.minY))
    p.addLine(to: CGPoint(x: page.maxX, y: page.minY + fold))
    p.addArc(tangent1End: CGPoint(x: page.maxX, y: page.maxY), tangent2End: CGPoint(x: page.minX, y: page.maxY), radius: r)
    p.addArc(tangent1End: CGPoint(x: page.minX, y: page.maxY), tangent2End: CGPoint(x: page.minX, y: page.minY), radius: r)
    p.addArc(tangent1End: CGPoint(x: page.minX, y: page.minY), tangent2End: CGPoint(x: page.maxX, y: page.minY), radius: r)
    p.closeSubpath()
    return p
}

/// The folded-over corner, with a softly rounded inner corner.
func foldPath() -> CGPath {
    let p = CGMutablePath()
    let a = CGPoint(x: page.maxX - fold, y: page.minY)
    let b = CGPoint(x: page.maxX, y: page.minY + fold)
    let corner = CGPoint(x: page.maxX - fold, y: page.minY + fold)
    p.move(to: a)
    p.addArc(tangent1End: corner, tangent2End: b, radius: 34)
    p.addLine(to: b)
    p.closeSubpath()
    return p
}

/// A rounded "M" and down-arrow, drawn as strokes and outlined.
func markPaths() -> (m: CGPath, arrow: CGPath) {
    let width: CGFloat = 72
    let top: CGFloat = 372, bottom: CGFloat = 596
    let left: CGFloat = 300, right: CGFloat = 500

    let m = CGMutablePath()
    m.move(to: CGPoint(x: left, y: bottom))
    m.addLine(to: CGPoint(x: left, y: top))
    m.addLine(to: CGPoint(x: (left + right) / 2, y: top + 0.56 * (bottom - top)))
    m.addLine(to: CGPoint(x: right, y: top))
    m.addLine(to: CGPoint(x: right, y: bottom))

    let arrowX: CGFloat = 664
    let head: CGFloat = 62
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: arrowX, y: top))
    arrow.addLine(to: CGPoint(x: arrowX, y: bottom))
    arrow.move(to: CGPoint(x: arrowX - head, y: bottom - head))
    arrow.addLine(to: CGPoint(x: arrowX, y: bottom))
    arrow.addLine(to: CGPoint(x: arrowX + head, y: bottom - head))

    func outline(_ path: CGPath) -> CGPath {
        path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
            .normalized(using: .winding)
    }
    return (outline(m), outline(arrow))
}

// MARK: SVG output

func svgPathData(_ path: CGPath) -> String {
    var d = ""
    func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
    path.applyWithBlock { element in
        let p = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint: d += "M\(f(p[0].x)) \(f(p[0].y))"
        case .addLineToPoint: d += "L\(f(p[0].x)) \(f(p[0].y))"
        case .addQuadCurveToPoint: d += "Q\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y))"
        case .addCurveToPoint: d += "C\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y)) \(f(p[2].x)) \(f(p[2].y))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

func writeSVG(_ name: String, _ paths: [(CGPath, String)]) throws {
    var body = ""
    for (path, color) in paths {
        body += "  <path fill=\"\(color)\" d=\"\(svgPathData(path))\"/>\n"
    }
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    \(body)</svg>
    """
    try svg.write(to: outputDirectory.appendingPathComponent(name), atomically: true, encoding: .utf8)
    print("wrote \(name)")
}

/// Two short "text" lines under the mark.
func linesPath() -> CGPath {
    let lines = CGMutablePath()
    lines.move(to: CGPoint(x: 300, y: 712)); lines.addLine(to: CGPoint(x: 724, y: 712))
    lines.move(to: CGPoint(x: 300, y: 778)); lines.addLine(to: CGPoint(x: 590, y: 778))
    return lines.copy(strokingWithWidth: 34, lineCap: .round, lineJoin: .round, miterLimit: 10)
}

let mark = markPaths()
try writeSVG("page.svg", [(pagePath(), "#FFFFFF")])
try writeSVG("fold.svg", [(foldPath(), "#C9D8F5")])
try writeSVG("mark.svg", [(mark.m, "#1F5EEB"), (mark.arrow, "#1F5EEB")])
try writeSVG("lines.svg", [(linesPath(), "#C6D4F2")])
