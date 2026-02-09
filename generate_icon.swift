import Cocoa

let emoji = "📅"
let iconsetPath = "AppIcon.iconset"
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (filename, size) in sizes {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    let fontSize = s * 0.85
    let font = NSFont.systemFont(ofSize: fontSize)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let str = emoji as NSString
    let strSize = str.size(withAttributes: attrs)
    let x = (s - strSize.width) / 2
    let y = (s - strSize.height) / 2
    str.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to generate \(filename)\n", stderr)
        continue
    }

    let path = "\(iconsetPath)/\(filename)"
    try! pngData.write(to: URL(fileURLWithPath: path))
}

print("Iconset created at \(iconsetPath)/")
