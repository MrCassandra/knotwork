import Cocoa

private func dye(_ hex: UInt32, _ opacity: Double = 1) -> NSColor {
    NSColor(srgbRed:Double(hex >> 16)/255, green:Double((hex >> 8)&255)/255,
            blue:Double(hex&255)/255, alpha:opacity)
}
private let graphite = dye(0xFCF1DC), ochre = dye(0xFFBC8D)
private func pt(_ x:Double,_ y:Double) -> CGPoint { CGPoint(x:x,y:y) }
private func rect(_ x:Double,_ y:Double,_ w:Double,_ h:Double) -> NSRect {
    NSRect(x:x,y:y,width:w,height:h)
}
private func plate(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ r:Double) -> NSBezierPath {
    NSBezierPath(roundedRect:rect(x,y,w,h),xRadius:r,yRadius:r)
}
private func fill(_ path:NSBezierPath,_ color:NSColor) { color.setFill(); path.fill() }
private func edge(_ path:NSBezierPath,_ color:NSColor,_ width:Double) {
    color.setStroke(); path.lineWidth = width; path.lineJoinStyle = .round; path.lineCapStyle = .round; path.stroke()
}
private func line(_ a:CGPoint,_ b:CGPoint,_ width:Double,_ color:NSColor) {
    let path = NSBezierPath(); path.move(to:a); path.line(to:b); edge(path,color,width)
}
private func curve(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,_ d:CGPoint,_ width:Double,_ tint:NSColor) {
    let path = NSBezierPath(); path.move(to:a); path.curve(to:d,controlPoint1:b,controlPoint2:c)
    edge(path,tint,width)
}
private func gradient(_ path:NSBezierPath,_ colors:[NSColor],_ angle:Double) {
    NSGradient(colors:colors)?.draw(in:path,angle:angle)
}
private func lettering(_ text:String,_ x:Double,_ y:Double,_ font:NSFont,_ color:NSColor,
                       spacing:Double = 0, right:Bool = false) {
    let attributes:[NSAttributedString.Key:Any] = [.font:font,.foregroundColor:color,.kern:spacing]
    let string = text as NSString
    string.draw(at:pt(x-(right ? string.size(withAttributes:attributes).width : 0),y),withAttributes:attributes)
}
private func book(_ size:Double, italic:Bool = false) -> NSFont {
    NSFont(name:italic ? "Baskerville-Italic" : "Baskerville-SemiBold",size:size)
        ?? NSFont.systemFont(ofSize:size,weight:.medium)
}
private func sans(_ size:Double) -> NSFont {
    NSFont(name:"AvenirNext-Medium",size:size) ?? NSFont.systemFont(ofSize:size,weight:.medium)
}

private func shortcut(_ key:String,_ action:String,at x:Double,width:Double) {
    let keycap = plate(x,19,width,19,4)
    fill(keycap,dye(0x2E2928,0.27)); edge(keycap,dye(0xDBCAAF,0.60),0.85)
    let font = NSFont.monospacedSystemFont(ofSize:10.5,weight:.medium)
    let keyWidth = (key as NSString).size(withAttributes:[.font:font]).width
    lettering(key,x+(width-keyWidth)/2,22,font,graphite)
    lettering(action,x+width+8,20,sans(12.5),dye(0xF1E4CC))
}

private func disc(_ x:Double,_ y:Double,_ r:Double,_ tint:NSColor) {
    fill(NSBezierPath(ovalIn:rect(x-r,y-r,2*r,2*r)),tint)
}

private let worktop = NSImage(size:NSSize(width:860,height:620),flipped:false) { bounds in
    NSGradient(colors:[dye(0x865944),dye(0x634538),dye(0x392F32)])?.draw(in:bounds,angle:-48)
    for i in 0..<125 {
        let y = Double(i)*5, drift = 7*sin(Double(i)*1.12)
        curve(pt(-10,y),pt(175,y+drift),pt(481,y-6),pt(875,y+drift),0.8,dye(0xE8B38A,0.08))
    }
    // A compact mechanical keyboard just beyond the work area.
    NSGraphicsContext.saveGraphicsState()
    let keyboard = NSAffineTransform()
    keyboard.translateX(by:296,yBy:580); keyboard.rotate(byDegrees:-4); keyboard.concat()
    fill(plate(3,-4,307,92,9),dye(0x231F21,0.55))
    gradient(plate(0,0,307,92,9),[dye(0x384249),dye(0x697070)],85)
    for row in 0..<4 {
        var x = 6.0
        let widths = row == 0 ? [23,22,22,108,23,22,22,22] : [Int](repeating:20,count:13)
        for (i,width) in widths.enumerated() {
            let y = 6+Double(row)*21, w = Double(width)
            fill(plate(x,y,w,18,3),dye(0x283239))
            let tint:UInt32 = i == 0 ? 0xBA7E65 : i > 10 ? 0x86998B : 0xBFB7A4
            fill(plate(x+1,y+3,w-2,15,2.7),dye(tint))
            if row > 0 { line(pt(x+6,y+12),pt(x+9,y+12),0.9,dye(0x485052)) }
            x += w+3
        }
    }
    NSGraphicsContext.restoreGraphicsState()

    fill(plate(89,137,682,371,31),dye(0x302B29,0.46))
    gradient(plate(87,140,682,370,31),[dye(0x35454B),dye(0x242F38)],-65)
    edge(plate(92,145,672,360,28),dye(0x8D9891,0.32),1)

    // A rosette succulent in a small clay planter.
    disc(32,440,34,dye(0x2D2425,0.45)); disc(28,446,33,dye(0xCB8867))
    disc(28,446,28,dye(0x4E4038))
    for i in 0..<15 {
        NSGraphicsContext.saveGraphicsState()
        let leaf = NSAffineTransform()
        leaf.translateX(by:28,yBy:446); leaf.rotate(byDegrees:Double(i)*137.5); leaf.concat()
        let h = 41-Double(i)*1.9, w = h*0.31
        let path = NSBezierPath()
        path.move(to:.zero); path.curve(to:pt(0,h),controlPoint1:pt(-w,5),controlPoint2:pt(-w,h*0.7))
        path.curve(to:.zero,controlPoint1:pt(w,h*0.68),controlPoint2:pt(w,5)); path.close()
        gradient(path,[dye(0x3E6559),dye(i < 8 ? 0x8DA788 : 0xB1C09C)],82)
        line(pt(0,5),pt(0,h-4),0.7,dye(0xD3D6A9,0.45))
        NSGraphicsContext.restoreGraphicsState()
    }
    // A pocket sketchbook and brass pencil, seen from above.
    NSGraphicsContext.saveGraphicsState()
    let book = NSAffineTransform()
    book.translateX(by:-31,yBy:188); book.rotate(byDegrees:9); book.concat()
    fill(plate(3,-3,98,125,5),dye(0x332F2D,0.46))
    fill(plate(0,0,98,125,5),dye(0xA96951)); fill(plate(2,4,93,120,3),dye(0xD6C7A9))
    for i in 0..<12 { line(pt(7,12+Double(i)*9),pt(89,12+Double(i)*9),0.55,dye(0xAAAD9A)) }
    for i in 0..<8 { curve(pt(7,11+Double(i)*15),pt(-3,11+Double(i)*15),pt(-4,17+Double(i)*15),pt(7,17+Double(i)*15),2,dye(0x53595A)) }
    curve(pt(29,94),pt(46,112),pt(51,75),pt(71,89),1.4,dye(0x69746B))
    line(pt(72,7),pt(61,107),4.4,dye(0xB9884C)); line(pt(61,107),pt(60,114),2.5,dye(0x514239))
    NSGraphicsContext.restoreGraphicsState()

    disc(820,319,43,dye(0x312628,0.5)); disc(817,325,43,dye(0xB48D68))
    edge(NSBezierPath(ovalIn:rect(838,322,22,21)),dye(0xD4C5A9),6)
    disc(815,328,33,dye(0xDCD1B5)); disc(815,328,28,dye(0x744C34)); disc(815,328,25,dye(0x483127))
    curve(pt(795,338),pt(801,351),pt(819,356),pt(830,346),2.1,dye(0xC59765,0.67))
    return true
}

private func drawSparks(age:Double, final:Bool, count:Int) {
    let life = final ? 0.76 : 0.46
    guard age >= 0, age < life else { return }
    let t = age/life
    for side in [-1.0,1.0] {
        for i in 0..<(final ? 12 : 7) {
            let seed = Double(i*7+count*3)
            let y = 332+38*sin(seed*1.7)
            let vx = side*(24+36*(1+sin(seed)))
            let vy = 8+72*cos(seed*2.2)
            let x = 430+side*266
            let tip = pt(x+vx*t,y+vy*t-26*t*t)
            let tail = pt(tip.x-vx*0.13*(1-t),tip.y-vy*0.13*(1-t))
            line(tail,tip,4.6*(1-t)+0.6,dye(0xBD6236,0.88*(1-t)))
            line(tail,tip,2.4*(1-t)+0.4,dye(0xFFE297,1-t))
        }
    }
}

private func smoothStep(_ t:Double) -> Double {
    let u = max(0,min(1,t))
    return u*u*(3-2*u)
}

private func drawTowel() {
    // The under-fold, rolled hem and yarn have separate highlights.
    for i in stride(from:6,through:1,by:-1) {
        fill(plate(111-Double(i)*1.3,151-Double(i)*1.4,632+Double(i)*2.6,337,36),dye(0x65452E,0.026))
    }
    fill(plate(112,154,633,342,34),dye(0x9E9275))
    gradient(plate(109,160,634,342,34),[dye(0xFBF3DA),dye(0xE8DAB9)],-87)
    for x in stride(from:138.0,through:712.0,by:7) {
        let y = 152 + 2*sin(x*0.76)
        curve(pt(x,164),pt(x+2,160),pt(x-1,154),pt(x-2,y),2.3,dye(0xB3A080))
        curve(pt(x+0.5,164),pt(x+2,160),pt(x,155),pt(x-1,y+1),1.1,dye(0xF4E8C7))
    }
    for y in [173.0,175.0,194.0,196.0] {
        line(pt(132,y),pt(716,y),1.1,dye(0xA78A6D,0.62))
    }

}

private func drawFace(_ phase:Knot.Phase,active:Bool,ease:Double,search:Double,pressure:Double,
                      time:Double,sinceFound:Double,voiceLevel:Double,releaseBlend:Double) {
    let housing = plate(353,403,155,53,14)
    fill(plate(353,401.4,155,53,14),dye(0xA3B2A2,0.64))
    gradient(housing,[dye(0x172925),dye(0x436057)],88)
    let glass = plate(358,407,145,45,10)
    gradient(glass,[dye(0x152723),dye(0x1B352E)],-85)
    let phosphor = dye(0xB8F4A8), bloom = dye(0x8BE3A0,0.15)
    let warmth = phase == .seek && active ? ease*0.45 + search*0.55 : 0
    let surprised = phase == .rub && sinceFound < 0.72
    let blinkTime = time.truncatingRemainder(dividingBy:4.3)
    let blink = active ? max(0,1-abs(blinkTime-4.08)/0.105) : 0
    let contentment = max(releaseBlend,min(0.88,pressure))
    for x in [399.0,461.0] {
        let y = 431.0+warmth*2
        let inward = x < 430 ? 1.0 : -1.0
        let sleepy = surprised ? 0 : contentment
        let h = (surprised ? 21 : 15+6*warmth)*(1-blink)*(1-0.94*sleepy)
        if h < 4.5 {
            curve(pt(x-9,y-1),pt(x-5,y+6),pt(x+5,y+6),pt(x+9,y-1),5,bloom)
            curve(pt(x-9,y-1),pt(x-5,y+6),pt(x+5,y+6),pt(x+9,y-1),2.8,phosphor)
        } else {
            let iris = NSBezierPath(ovalIn:rect(x-9,y-h/2,18,h))
            edge(iris,bloom,4)
            gradient(iris,[dye(0x9CD9AF),dye(0xE7F8BA)],83)
            let px = x+inward*1.4+sin(time*1.14)*1.2
            fill(NSBezierPath(ovalIn:rect(px-4.3,y-h*0.34,8.6,h*0.70)),dye(0x275347))
            disc(px-1.6,y+h*0.16,min(2,h*0.12)+warmth*0.8,dye(0xFDFFE3))
            if search > 0 || surprised {
                let glow = surprised ? 1 : search
                let glint = pt(x+7,y+7)
                line(pt(glint.x-3*glow,glint.y),pt(glint.x+3*glow,glint.y),1.3,dye(0xFFF3BE,glow))
                line(pt(glint.x,glint.y-4*glow),pt(glint.x,glint.y+4*glow),1.3,dye(0xFFF3BE,glow))
            }
        }
        let cheek = x-inward*11
        if releaseBlend > 0 {
            fill(NSBezierPath(ovalIn:rect(cheek-8,414,18,9)),dye(0xF9AF8E,0.32*releaseBlend))
        }
        for i in 0...2 {
            let dx = Double(i)*2.8
            line(pt(cheek+dx-3,418),pt(cheek+dx-2,420),1.4,dye(0xEDAB99,0.54+0.19*sleepy))
        }
    }
    let mouth = max(0,min(1,voiceLevel))
    if releaseBlend > 0 {
        let w = 7+6*releaseBlend
        curve(pt(430-w,421),pt(425,417-3*releaseBlend),pt(435,417-3*releaseBlend),
              pt(430+w,421),2.2,dye(0xCBF5AD,releaseBlend*(1-mouth)))
    }
    for n in -2...2 {
        let level = 1-Double(abs(n))*0.26
        let h = 2+mouth*level*(7+4*sin(time*24+Double(n)*1.5))
        let restingY = phase == .release || pressure > 0.4 ? 420.0+Double(abs(n)) : 420
        fill(plate(428+Double(n)*4,restingY-h/2,2.6,h,1.2),phosphor)
    }
    for y in stride(from:411.0,through:448.0,by:3) {
        line(pt(365,y),pt(497,y),0.6,dye(0x0B1715,0.13))
    }
}

func drawMac(bounds:NSRect,knot:Knot,aspect:Double,ease:Double,trails:[Fingerprint],progress:Double,
             pressure:Double,time:Double,sinceFound:Double,sinceRelease:Double,active:Bool,round:Int,
             muted:Bool = false, voiceLevel:Double = 0, compression:Double = 0, sinceSnap:Double = 10) {
    let phase = knot.phase
    dye(0x392F32).setFill(); bounds.fill()
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    let scale = min(bounds.width/860,bounds.height/620)
    let layout = NSAffineTransform()
    layout.translateX(by:bounds.midX-430*scale,yBy:bounds.midY-310*scale)
    layout.scale(by:scale); layout.concat()
    worktop.draw(in:rect(0,0,860,620))
    // Keep the masthead to the left of the keyboard and the round in the opposite margin.
    for sign in [-1.0,1.0] {
        curve(pt(57,562),pt(40,562+sign*17),pt(38,562-sign*12),pt(57,562),2,ochre)
        curve(pt(57,562),pt(74,562+sign*17),pt(76,562-sign*12),pt(57,562),2,ochre)
    }
    lettering("Knotwork",82,538,book(48),graphite,spacing:-1.7)
    lettering("A trackpad massage",85,526,sans(14),dye(0xF4E0C7))
    lettering("Round",758,540,sans(13),dye(0xF2DFC5),right:true)
    lettering(String(format:"%02d",round),815,533,book(34),graphite,right:true)

    drawTowel()
    if phase == .release && sinceRelease < 0.82 {
        let t = sinceRelease/0.82
        NSGraphicsContext.saveGraphicsState()
        plate(109,160,634,342,34).addClip()
        let w = 490+370*t, h = 202+240*t
        edge(NSBezierPath(ovalIn:rect(430-w/2,341-h/2,w,h)),dye(0xCCA170,0.84*(1-t)),3.6-2*t)
        NSGraphicsContext.restoreGraphicsState()
    }
    let returnToRest = smoothStep((sinceRelease-2.38)/(Knot.releaseDuration-2.38))
    let relief = phase == .release ? 1-returnToRest : 0
    let spread = relief*smoothStep((sinceRelease-0.07)/0.92)
    let inhale = relief*sin(.pi*smoothStep(sinceRelease/0.56))
    let relaxed = phase == .release ? max(ease,relief) : ease*(0.7+0.3*progress)
    let finding = phase == .rub ? max(0,1-sinceFound*2.1) : 0
    let rebound = sin(sinceSnap*25)*exp(-sinceSnap*7)*(phase == .release ? 1.65 : 1)
    let tilt = NSAffineTransform()
    NSGraphicsContext.saveGraphicsState()
    tilt.translateX(by:430,yBy:343+3*(1-relaxed)-pressure*2.6-compression*6+finding*2+rebound*11-8*spread+4*inhale)
    tilt.rotate(byDegrees:-2.8+relaxed*2.5+rebound*0.9+spread*0.3)
    tilt.scaleX(by:1+relaxed*0.014+compression*0.042-rebound*0.021+spread*0.158,yBy:1-relaxed*0.018-compression*0.065+rebound*0.052+inhale*0.075+spread*0.043+sin(time*2)*0.003)
    tilt.translateX(by:-430,yBy:-343); tilt.concat()
    for i in stride(from:5,through:1,by:-1) {
        fill(plate(157-Double(i)*1.3,204-Double(i)*1.2,548+Double(i)*2.6,267,24),dye(0x373D2A,0.055))
    }
    let chassis = plate(153,207,554,268,23)
    gradient(chassis,[dye(0x92A398),dye(0x536960),dye(0x293E36)],90)
    edge(chassis,dye(0x293B34),1.4)
    let lidRect = rect(153,215,554,263)
    let lid = NSBezierPath(roundedRect:lidRect,xRadius:22,yRadius:22)
    gradient(lid,[dye(0x4F6C65),dye(0x68867A),dye(0x9EAEA0)],58)
    if spread > 0 { fill(lid,dye(0xF9D6AB,0.12*spread)) }
    edge(lid,dye(0xCED6BE),1.4)
    NSGraphicsContext.saveGraphicsState()
    lid.addClip()
    for i in 0..<50 {
        let y = 217+Double(i)*5.2
        line(pt(154,y),pt(706,y),0.6,dye(0xCEF0DC,0.047))
    }
    drawFace(phase,active:active,ease:ease,search:knot.searchProgress,pressure:pressure,time:time,sinceFound:sinceFound,voiceLevel:voiceLevel,releaseBlend:relief)
    if phase != .seek {
        for i in knot.fibers.indices {
            let x = 430+Double(i-2)*16, lit = i < knot.brokenCount
            disc(x,390,5.6,dye(0x344A43))
            if lit {
                let flash = max(0,1-sinceSnap/0.4)*(phase == .release || i == knot.brokenCount-1 ? 1 : 0)
                disc(x,390,7+flash*5,dye(0xFFD287,0.18+flash*0.20))
                disc(x,390,4.2,dye(0xFFC977))
                disc(x-0.6,391,2.1,dye(0xFFF3C4))
            }
        }
    }
    // Small recessed speaker perforations on either side of the character display.
    for x in [315.0,522.0] {
        for row in 0..<2 {
            for col in 0..<4 {
                let cx = x+Double(col)*5.5, cy = 427+Double(row)*5.5
                fill(NSBezierPath(ovalIn:rect(cx,cy,2.2,2.2)),dye(0x314B44,0.72))
            }
        }
    }
    // The engraved fruit uses metal on metal; it stays visible under touch traces.
    let emblem = NSBezierPath()
    emblem.move(to:pt(431,312)); emblem.curve(to:pt(411,339),controlPoint1:pt(420,304),controlPoint2:pt(398,331))
    emblem.curve(to:pt(432,341),controlPoint1:pt(419,347),controlPoint2:pt(425,339))
    emblem.curve(to:pt(450,336),controlPoint1:pt(444,347),controlPoint2:pt(449,342))
    emblem.curve(to:pt(448,324),controlPoint1:pt(441,333),controlPoint2:pt(442,326))
    emblem.curve(to:pt(431,312),controlPoint1:pt(442,311),controlPoint2:pt(439,309))
    emblem.close()
    fill(emblem,dye(0x3B5850,0.72))
    curve(pt(430,344),pt(432,351),pt(435,353),pt(439,354),3.7,dye(0x3B5850,0.72))
    func surface(_ p:CGPoint)->CGPoint { pt(lidRect.minX+p.x*lidRect.width,lidRect.minY+p.y*lidRect.height) }
    if phase == .rub || (phase == .release && sinceRelease < 0.5) {
        let center = surface(knot.center)
        let rx = knot.radius*lidRect.width/aspect, ry = knot.radius*lidRect.height
        let fade = phase == .release ? max(0,1-sinceRelease*2) : min(1,sinceFound*5)
        let warmth = fade*(0.79-0.27*progress)
        if let ctx = NSGraphicsContext.current?.cgContext,
           let blush = CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),
                                  colors:[dye(0xED786A,warmth).cgColor,
                                          dye(0xE08A7A,warmth*0.48).cgColor,
                                          dye(0xDC9283,0).cgColor] as CFArray,
                                  locations:[0,0.47,1]) {
            ctx.saveGState()
            ctx.translateBy(x:center.x,y:center.y)
            ctx.scaleBy(x:rx,y:ry)
            ctx.drawRadialGradient(blush,startCenter:pt(-0.08,0.06),startRadius:0,
                                   endCenter:.zero,endRadius:1,options:[])
            ctx.restoreGState()
        }
    }
    if phase == .seek {
        for (slot,trail) in trails.enumerated() {
            let tint:UInt32 = slot == 0 ? 0xEDF5D9 : 0xFFDDAB
            for mark in trail.marks {
                let fade = max(0,1-(time-mark.time)/5)
                let a = surface(mark.from), b = surface(mark.to)
                if a != b { line(a,b,9,dye(tint,fade*0.12)); line(a,b,2.6,dye(tint,fade*0.17)) }
            }
            if let tip = trail.previous {
                let p = surface(tip)
                fill(NSBezierPath(ovalIn:rect(p.x-4,p.y-3,8,6)),dye(tint,0.61))
            }
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    curve(pt(393,211),pt(405,206),pt(453,206),pt(466,211),2.3,dye(0x263C34))
    line(pt(660,211),pt(674,211),2.2,dye(active ? 0xBEE8A3 : 0x7D9582))
    NSGraphicsContext.restoreGraphicsState()

    drawSparks(age:sinceSnap,final:phase == .release,count:knot.brokenCount)

    let paused = !active && time > 0
    let title:String, hint:String
    if paused {
        title = "Taking a break."
        hint = "Pick up where you left off."
    } else if !active {
        title = "My lid feels stiff."
        hint = "Use one or two fingers on the trackpad to find the knot."
    } else {
        switch phase {
        case .seek:
            title = "Follow the pulse."
            hint = "Where the taps quicken, trace small circles."
        case .rub:
            if sinceFound < 1.6 {
                title = "Right there."
            } else if pressure > 0.50 {
                title = "That’s the spot."
            } else {
                title = "A little more pressure."
            }
            hint = "Press firmly and rub the warm spot. Each light marks a loosened fiber."
        case .release:
            title = "Ah, much better."
            hint = "All five fibers have let go."
        }
    }
    lettering(title,44,87,book(36,italic:true),graphite,spacing:-0.4)
    lettering(hint,47,65,sans(16),dye(0xF5E9D8))
    line(pt(46,50),pt(814,50),0.65,dye(0xDBCAAF,0.56))
    if active {
        shortcut("esc","Pause & release cursor",at:46,width:30)
    } else {
        shortcut("space",paused ? "Resume" : "Begin",at:46,width:44)
    }
    shortcut("M",muted ? "Unmute" : "Mute",at:748,width:21)
}
