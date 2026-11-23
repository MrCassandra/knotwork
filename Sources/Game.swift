import Cocoa

struct Fiber {
    let offset: Double
    let bend = Double.random(in: 0.004...0.014)
    let wave = Double.random(in: 0...2 * .pi)
    var broken = false
    var tension = 1.0
    var sides = [0,0]
    func distance(_ normal: Double, _ along: Double) -> Double {
        normal - offset - bend * sin(12 * along + wave)
    }
}

struct Knot {
    enum Phase { case seek, rub, release }
    enum Stroke: Int { case light, firm, deep, snap }
    var center = CGPoint(x: Double.random(in: 0.27...0.73), y: Double.random(in: 0.27...0.73))
    let angle = Double.random(in: 0...2 * .pi)
    var fibers = (-2...2).map { Fiber(offset: Double($0)*0.033 + Double.random(in: -0.006...0.006)) }
    struct Grain {
        let angle: Double
        let offset: Double
        let coarse: Bool
        var sides = [0,0]
    }
    // Each cluster leaves a smooth interval before the next patch of grain.
    var grains: [Grain] = (0..<6).flatMap { _ -> [Grain] in
        let direction = Double.random(in: 0...2 * .pi)
        let start = Double.random(in: -0.14...0.10)
        let gap = Double.random(in: 0.014...0.037)
        return [Grain(angle:direction, offset:start, coarse:true),
                Grain(angle:direction, offset:start+gap, coarse:Bool.random())]
    }
    var phase = Phase.seek
    static let releaseDuration = 3.5
    static let requiredPressure = 0.55
    let radius = 0.20, workGoal = 7.2
    private var entry = [CGPoint?](repeating:nil,count:2)
    private var searchTravel = [0.0, 0.0]
    private var searchMotionTime = [0.0, 0.0]
    private var confirmation = [0.0, 0.0]
    var searchProgress: Double { max(confirmation[0],confirmation[1]) }
    var proximity = 0.0, worked = 0.0
    private var last = [CGPoint?](repeating:nil,count:2)
    var brokenCount: Int { fibers.filter { $0.broken }.count }
    private var lastBreakWork = -1.0
    var progress: Double {
        let softness = 1 - fibers.reduce(0) { $0 + $1.tension } / Double(fibers.count)
        return min(softness, worked/workGoal)
    }
    mutating func lift(_ slot:Int) {
        confirmation[slot] = 0
        entry[slot] = nil
        searchTravel[slot] = 0
        searchMotionTime[slot] = 0
        last[slot] = nil
        for i in fibers.indices { fibers[i].sides[slot] = 0 }
        for i in grains.indices { grains[i].sides[slot] = 0 }
    }
    // One update per frame. Two moving fingers can reach different fibers,
    // but the time spent rubbing is counted only once.
    mutating func update(_ points:[CGPoint?], aspect:Double, force:Double, dt:Double) -> Stroke? {
        guard phase != .release else { return nil }
        var nearest = Double.infinity, fastest = 0.0
        var stroke: Stroke?
        var discovered = false
        for slot in 0..<2 {
            guard let p = points[slot] else { continue }
            let x = (p.x-center.x)*aspect, y = p.y-center.y, d = hypot(x,y)
            nearest = min(nearest,d)
            if phase == .seek {
                if d <= (entry[slot] == nil ? 0.107 : 0.13) {
                    if let origin = entry[slot], let previous = last[slot] {
                        let travel = hypot((p.x-previous.x)*aspect,p.y-previous.y)
                        searchTravel[slot] += travel
                        searchMotionTime[slot] += min(dt,travel/0.12)
                        let straightLine = hypot((p.x-origin.x)*aspect,p.y-origin.y)
                        let retraced = max(0,searchTravel[slot]-straightLine)
                        confirmation[slot] = min(1,retraced/0.115,searchMotionTime[slot]/0.34)
                        if confirmation[slot] >= 1 {
                            discovered = true
                        }
                    } else {
                        entry[slot] = p
                        stroke = .firm
                    }
                    last[slot] = p
                } else if entry[slot] != nil { lift(slot) }
                continue
            }
            guard d < radius, force >= Self.requiredPressure else { if last[slot] != nil { lift(slot) }; continue }
            let previous = last[slot]
            last[slot] = p
            let travel = previous.map { hypot((p.x-$0.x)*aspect,p.y-$0.y) } ?? 0
            fastest = max(fastest,travel)
            var accent: Stroke?
            let normal = x*cos(angle) + y*sin(angle), along = y*cos(angle)-x*sin(angle)
            for i in fibers.indices where fibers[i].tension > 0 {
                let distance = fibers[i].distance(normal,along)
                guard abs(distance) > 0.005 else { continue }
                let side = distance > 0 ? 1 : -1, old = fibers[i].sides[slot]
                fibers[i].sides[slot] = side
                guard old != 0, old != side else { continue }
                fibers[i].tension = max(0,fibers[i].tension-(0.065+0.045*min(1,force))/0.90)
                accent = .deep
            }
            // More of the grain field becomes perceptible as the knot softens.
            let count = 4 + 2*Int(Double((grains.count-4)/2)*progress)
            for i in 0..<count {
                let g = grains[i]
                let distance = x*cos(g.angle)+y*sin(g.angle)-g.offset
                guard abs(distance) > 0.004 else { continue }
                let side = distance > 0 ? 1 : -1
                grains[i].sides[slot] = side
                if g.sides[slot] != 0, g.sides[slot] != side, accent == nil {
                    accent = g.coarse && force > 0.68 ? .deep : .firm
                }
            }
            if travel > 0, let accent, accent.rawValue > (stroke?.rawValue ?? -1) {
                stroke = accent
            }
        }
        proximity = max(0,1-nearest/0.72)
        if phase == .seek {
            if discovered {
                phase = .rub
                for slot in last.indices { lift(slot) }
            }
        } else {
            worked += min(dt,fastest/0.16)
            // A softened fiber lets go under continued rubbing. Space the five
            // releases across the existing work budget so the last one ends the round.
            let threshold = workGoal * (Double(brokenCount+1)/Double(fibers.count))
            if fastest > 0, worked >= threshold,
               worked-lastBreakWork >= 0.24,
               let i = fibers.firstIndex(where:{ !$0.broken && $0.tension == 0 }) {
                fibers[i].broken = true
                lastBreakWork = worked
                stroke = .snap
                if brokenCount == fibers.count { phase = .release }
            }
        }
        return stroke
    }
}

struct Fingerprint {
    struct Mark {
        let from: CGPoint
        let to: CGPoint
        let time: Double
    }
    var marks: [Mark] = []
    private(set) var previous: CGPoint?
    mutating func lift() { previous = nil }
    mutating func follow(_ point:CGPoint, time:Double) {
        let start = previous ?? point
        if previous != nil && hypot(point.x-start.x,point.y-start.y) < 0.002 { return }
        marks.append(Mark(from:start,to:point,time:time))
        if marks.count > 420 { marks.removeFirst() }
        previous = point
    }
    mutating func expire(at time:Double) { marks.removeAll { time-$0.time > 5 } }
}
