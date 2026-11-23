import Cocoa
class Field: NSView {
    var knot = Knot(), round = 1, active = false
    var fingers = [NSTouch?](repeating:nil,count:2)
    var force = 0.0, ease = 0.0
    var lastTick = ProcessInfo.processInfo.systemUptime, nextBeat = 0.0, released = 0.0, clock = 0.0
    var timer: Timer?
    var releaseBeats = 0
    var trails = [Fingerprint(), Fingerprint()]
    let reliefTimes = [0.09, 0.21, 0.39, 0.64, 1.00, 1.51, 2.16]
    let audio = RobotAudio()
    private var audioPositions = [CGPoint?](repeating:nil,count:2)
    var aspect = 1.6, feedbackReady = 0.0, foundAt = -10.0
    private var accentAt: Double?
    private var compression = 0.0, lastSnap = -10.0
    var flex = 0.0
    var load: Double { force }
    override var acceptsFirstResponder: Bool { true }
    override init(frame: NSRect) {
        super.init(frame:frame)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
        pressureConfiguration = NSPressureConfiguration(pressureBehavior:.primaryGeneric)
        let timer = Timer(timeInterval:1/60,repeats:true) { [weak self] _ in self?.step() }
        self.timer = timer
        RunLoop.main.add(timer,forMode:.common)
    }
    required init?(coder:NSCoder) { fatalError() }
    func beat(_ pattern:NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern,performanceTime:.now)
    }
    func clear(_ slot:Int) {
        audioPositions[slot] = nil
        fingers[slot] = nil; trails[slot].lift(); knot.lift(slot)
    }
    func resetContact() {
        for slot in fingers.indices { clear(slot) }
        accentAt = nil
        force = 0; knot.proximity = 0
    }
    func touches(_ e:NSEvent) {
        guard active, knot.phase != .release else { return }
        var live = Array(e.touches(matching:.touching,in:self))
        for slot in fingers.indices {
            guard let prior = fingers[slot] else { continue }
            if let index = live.firstIndex(where:{ prior.identity.isEqual($0.identity) }) {
                fingers[slot] = live.remove(at:index)
            } else { clear(slot) }
        }
        for slot in fingers.indices where fingers[slot] == nil && !live.isEmpty {
            fingers[slot] = live.removeFirst()
        }
        if fingers.allSatisfy({ $0 == nil }) { resetContact() }
    }
    override func touchesBegan(with e:NSEvent) { touches(e) }
    override func touchesMoved(with e:NSEvent) { touches(e) }
    override func touchesEnded(with e:NSEvent) { touches(e) }
    override func touchesCancelled(with e:NSEvent) { if knot.phase != .release { resetContact() } }
    private var savedPointer: CGPoint?
    func start() {
        guard !active, let window, let origin = CGEvent(source:nil)?.location,
              let primary = NSScreen.screens.first else { return }
        let viewCenter = convert(CGPoint(x:bounds.midX,y:bounds.midY),to:nil)
        let onScreen = window.convertPoint(toScreen:viewCenter)
        let anchor = CGPoint(x:onScreen.x,y:primary.frame.maxY-onScreen.y)
        guard CGWarpMouseCursorPosition(anchor) == .success else { return }
        guard CGAssociateMouseAndMouseCursorPosition(0) == .success else {
            CGWarpMouseCursorPosition(origin)
            return
        }
        savedPointer = origin
        NSCursor.hide()
        active = true
        audio.start(phase:knot.phase)
        nextBeat = 0
        needsDisplay = true
    }
    func pause() {
        guard active else { return }
        active = false
        audio.pause()
        CGAssociateMouseAndMouseCursorPosition(1)
        if let origin = savedPointer { CGWarpMouseCursorPosition(origin) }
        savedPointer = nil
        NSCursor.unhide()
        resetContact()
        needsDisplay = true
    }
    override func mouseDown(with e:NSEvent) {
        if !active { start() }
    }
    override func mouseUp(with e:NSEvent) { force = 0 }
    override func pressureChange(with e:NSEvent) {
        guard active, knot.phase != .release else { return }
        force = e.stage >= 2 ? 1 : e.stage == 1 ? Double(e.pressure) : 0
    }
    override func keyDown(with e:NSEvent) {
        if e.charactersIgnoringModifiers?.lowercased() == "m" {
            guard !e.isARepeat else { return }
            audio.muted.toggle()
            needsDisplay = true
            return
        }
        if e.keyCode == 53 { pause(); return }
        if e.keyCode == 49 && !e.isARepeat {
            if active { pause() } else { start() }
            needsDisplay = true
        } else { super.keyDown(with:e) }
    }
    func step() {
        let now = ProcessInfo.processInfo.systemUptime, dt = min(0.08,now-lastTick)
        lastTick = now
        guard window?.isKeyWindow == true else { pause(); return }
        guard active else { return }
        clock += dt
        for slot in trails.indices { trails[slot].expire(at:clock) }
        let targetEase = max(0,min(1,(knot.proximity-0.32)/0.65))
        ease += (targetEase-ease)*min(1,dt*3.4)
        let inKnot = fingers.contains { $0 != nil } && knot.phase == .rub && knot.proximity > 0.72
        flex += ((inKnot ? load : 0) - flex) * min(1,dt*12)
        var targetCompression = 0.0
        var speed = 0.0
        var audioContact = false
        var movingProximity = 0.0
        if knot.phase == .release {
            let age = clock-released
            if age >= Knot.releaseDuration {
                round += 1; knot = Knot(); resetContact(); trails = [Fingerprint(), Fingerprint()]
                nextBeat = clock; foundAt = -10
                lastSnap = -10
                audio.newRound()
            } else if releaseBeats < reliefTimes.count && age >= reliefTimes[releaseBeats] {
                beat(releaseBeats < 3 ? .generic : .alignment); releaseBeats += 1
            }
        } else if let touch = fingers.compactMap({ $0 }).first {
            aspect = touch.deviceSize.width/max(1,touch.deviceSize.height)
            let points = fingers.map { $0?.normalizedPosition }
            var nearestMovingDistance = Double.infinity
            for slot in points.indices {
                guard let p = points[slot] else { continue }
                if knot.phase == .seek { trails[slot].follow(p,time:clock) }
                let distance = hypot((p.x-knot.center.x)*aspect,p.y-knot.center.y)
                let onKnot = distance < knot.radius
                if knot.phase == .seek || onKnot {
                    audioContact = true
                    if let last = audioPositions[slot], dt > 0 {
                        let fingerSpeed = hypot((p.x-last.x)*aspect,p.y-last.y)/dt
                        speed = max(speed,fingerSpeed)
                        if fingerSpeed > 0.025 { nearestMovingDistance = min(nearestMovingDistance,distance) }
                    }
                    audioPositions[slot] = p
                } else {
                    audioPositions[slot] = nil
                }
            }
            movingProximity = max(0,1-nearestMovingDistance/0.72)
            let old = knot.phase
            let stroke = knot.update(points,aspect:aspect,force:load,dt:dt)
            let accentEligible = old == .rub && knot.phase == .rub && audioContact && speed > 0.045 && load >= Knot.requiredPressure
            if accentEligible { targetCompression = load * min(1,speed/0.65) }
            if stroke == .snap {
                lastSnap = clock
                compression *= 0.25
                audio.fiberReleased(knot.brokenCount)
            }
            if !accentEligible { accentAt = nil }
            if knot.phase == .release {
                beat(.levelChange); released = clock; releaseBeats = 0
                resetContact(); audioContact = false; audio.release()
            } else if old != knot.phase {
                beat(.levelChange); audio.found(); foundAt = clock
                feedbackReady = clock+0.07
            } else if let due = accentAt, clock >= due, stroke != .snap {
                beat(load >= 0.78 ? .levelChange : .generic)
                accentAt = nil
                feedbackReady = clock+0.037
            } else if let stroke = stroke, (clock >= feedbackReady || stroke == .snap) {
                if knot.phase == .rub { audio.stroke(stroke,force:load) }
                switch stroke {
                case .light: beat(.alignment)
                case .firm: beat(.generic)
                case .deep, .snap: beat(.levelChange)
                }
                // Let cracks stand out with a short silence. Close ridges can sound in pairs.
                switch stroke {
                case .snap: feedbackReady = clock+0.15
                case .deep: feedbackReady = clock+Double.random(in:0.035...0.060)
                case .light, .firm: feedbackReady = clock+0.045
                }
                if accentEligible {
                    // Accentuate each ridge with two taps. Pressure compresses the pair,
                    // while the distance between ridges still sets the overall rhythm.
                    let compression = (load-Knot.requiredPressure)/(1-Knot.requiredPressure)
                    let spacing = stroke == .snap ? 0.040 : 0.072-0.038*min(1,compression)
                    accentAt = clock+spacing
                    feedbackReady = clock+spacing
                }
                nextBeat = clock+0.13
            } else if knot.phase == .seek && clock >= nextBeat && clock >= feedbackReady {
                beat(knot.proximity > 0.6 ? .generic : .alignment)
                let interval = 0.082+0.64*pow(1-knot.proximity,1.15)
                nextBeat = clock+interval; feedbackReady = clock+0.035
            }
        }
        compression += (targetCompression-compression)*min(1,dt*(targetCompression > compression ? 9 : 15))
        audio.tick(phase:knot.phase,proximity:knot.proximity,force:load,speed:speed,
                   touching:audioContact,progress:knot.progress,dt:dt,searchProgress:knot.searchProgress,movingProximity:movingProximity)
        needsDisplay = true
    }
    override func draw(_ rect:NSRect) {
        drawMac(bounds:bounds, knot:knot, aspect:aspect, ease:ease, trails:trails,
                progress:knot.progress, pressure:flex, time:clock, sinceFound:clock-foundAt,
                sinceRelease:clock-released, active:active, round:round, muted:audio.muted, voiceLevel:audio.voiceLevel,compression:compression,sinceSnap:clock-lastSnap)
    }
}
class Delegate:NSObject, NSApplicationDelegate, NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) { (window.contentView as? Field)?.pause() }
    func windowWillClose(_ notification: Notification) { (window.contentView as? Field)?.pause() }
    func applicationWillTerminate(_ notification: Notification) { (window.contentView as? Field)?.pause() }
    var window:NSWindow!
    func applicationDidFinishLaunching(_ n:Notification) {
        let frame = NSRect(x:0,y:0,width:860,height:620)
        window = NSWindow(contentRect:frame,styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.delegate = self
        window.title = "Knotwork"; window.minSize = NSSize(width:540,height:480)
        let field = Field(frame:frame)
        window.contentView = field; window.center(); window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field); NSApp.activate(ignoringOtherApps:true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
