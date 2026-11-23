import AVFoundation

/// The massage has a single performer. It can take a breath, form a word, or
/// leave a stroke unanswered. Physical impacts are handled by the trackpad.
struct RobotPerformance {
    enum Voice: String, CaseIterable {
        case uh = "Uh"
        case rightThere = "RightThere", yeah = "Yeah", nice = "Nice"
        case lowMm = "LowMm", softHmm = "SoftHmm", mmHmm = "MmHmm"
        case ah = "Ah", aha = "Aha", inhale = "Inhale", exhale = "SoftExhale"
        case relief = "Relief", smile = "Smile", oh = "Oh"
    }

    private var recent: [Voice] = []
    private var round = 1
    private var nextReaction = 0.0
    private var effort = 0.0
    private var tentative = 0.0
    private var askedForPressure = false
    private var spokeDuringRub = false
    private var snapWindow = 0.0

    private mutating func pick(_ pool: [Voice]) -> Voice {
        let fresh = pool.filter { !recent.contains($0) }
        let available = fresh.isEmpty ? pool.filter { $0 != recent.last } : fresh
        let chosen = available.randomElement() ?? pool[0]
        recent.append(chosen)
        if recent.count > 4 { recent.removeFirst() }
        return chosen
    }

    mutating func resetForNewRound() {
        round += 1
        effort = 0
        tentative = 0
        askedForPressure = false
        spokeDuringRub = false
        snapWindow = 0
    }

    mutating func found() -> Voice {
        nextReaction = Double.random(in: 1.65...2.55)
        return pick(round == 1 ? [.rightThere] : [.rightThere,.aha,.mmHmm,.softHmm])
    }

    mutating func recordSnap() { snapWindow = 0.24 }

    mutating func release() -> Voice {
        snapWindow = 0
        return pick(round == 1 ? [.oh] : [.oh,.relief,.exhale,.ah])
    }

    mutating func react(force: Double, speed: Double, touching: Bool, progress: Double,
                        speaking: Bool, dt: Double) -> Voice? {
        nextReaction = max(0,nextReaction-dt)
        snapWindow = max(0,snapWindow-dt)
        guard touching, speed > 0.018 else {
            tentative = 0
            return nil
        }
        guard force >= Knot.requiredPressure else {
            tentative += dt
            guard !askedForPressure, tentative > 1.1, nextReaction == 0, !speaking else { return nil }
            askedForPressure = true
            nextReaction = Double.random(in: 2.0...3.2)
            return pick([.inhale,.softHmm])
        }
        tentative = 0
        effort += dt*min(1,speed/0.18)
        guard nextReaction == 0, !speaking, effort > 0.72 else { return nil }
        effort = 0
        nextReaction = Double.random(in: 2.2...3.8)

        if progress > 0.40 && !spokeDuringRub && Int.random(in:0..<3) != 0 {
            spokeDuringRub = true
            return pick([.yeah,.nice])
        }
        if snapWindow > 0 { return pick([.ah,.aha,.smile]) }
        if force > 0.80 && speed > 0.42 { return pick([.lowMm,.exhale,.ah]) }
        if progress > 0.60 { return pick([.smile,.mmHmm,.exhale]) }
        return pick([.lowMm,.mmHmm,.softHmm])
    }
}

final class RobotAudio {
    private var players: [String: AVAudioPlayer] = [:]
    private var performance = RobotPerformance()
    private var currentVoice: AVAudioPlayer?
    private var active = false
    private var encouraged = false
    private var pendingDiscovery: RobotPerformance.Voice?
    private let keys = (0..<7).map { "Key" + String($0) }
    private var noteVoices: [String:[AVAudioPlayer]] = [:]
    private var soundingKey: AVAudioPlayer?
    private var lastKey: Int?
    private var approachArmed = true
    private var approachCooldown = 0.0
    private var probeDelay = 0.0
    private(set) var voiceLevel = 0.0
    var muted = false {
        didSet { if muted { silence() } }
    }

    init(bundle: Bundle = .main) {
        let voiceNames = Set(RobotPerformance.Voice.allCases.map(\.rawValue))
        for name in voiceNames.union(["Wake","Next"]).union(keys) {
            let folder = name == "Oh" ? nil : "Audio"
            guard let url = bundle.url(forResource:name,withExtension:"wav",subdirectory:folder),
                  let player = try? AVAudioPlayer(contentsOf:url) else { continue }
            player.enableRate = voiceNames.contains(name)
            player.isMeteringEnabled = voiceNames.contains(name)
            player.prepareToPlay()
            if keys.contains(name) {
                var voices = [player]
                for _ in 0..<3 {
                    if let extra = try? AVAudioPlayer(contentsOf:url) {
                        extra.prepareToPlay()
                        voices.append(extra)
                    }
                }
                noteVoices[name] = voices
            } else { players[name] = player }
        }
    }

    @discardableResult
    private func play(_ name: String, _ volume: Float, rate: Float = 1) -> AVAudioPlayer? {
        guard active, !muted, let player = players[name] else { return nil }
        player.currentTime = 0
        player.volume = volume
        if player.enableRate { player.rate = rate }
        return player.play() ? player : nil
    }

    private func voice(_ line: RobotPerformance.Voice) {
        currentVoice?.stop()
        let volume: Float
        switch line {
        case .uh: volume = 0.43
        case .inhale: volume = 0.39
        case .exhale, .softHmm, .lowMm: volume = 0.53
        case .oh: volume = 0.70
        default: volume = 0.61
        }
        currentVoice = play(line.rawValue,volume,rate:Float.random(in:0.95...1.04))
    }

    private func stopNotes() {
        for voices in noteVoices.values {
            for player in voices where player.isPlaying { player.stop() }
        }
    }

    private func playNote(_ name:String, volume:Float) {
        guard active, !muted, let pool = noteVoices[name],
              let player = pool.first(where:{ !$0.isPlaying }) ?? pool.max(by:{ $0.currentTime < $1.currentTime }) else { return }
        player.currentTime = 0
        player.volume = volume
        player.play()
        soundingKey = player
    }

    private func silence() {
        stopNotes()
        for player in players.values where player.isPlaying { player.stop() }
        pendingDiscovery = nil
        lastKey = nil
        soundingKey = nil
        currentVoice = nil
        voiceLevel = 0
    }

    func start(phase: Knot.Phase) {
        active = true
        probeDelay = 0.45
        if phase == .seek { play("Wake",0.19) }
    }

    func pause() {
        active = false
        silence()
    }

    func newRound() {
        silence()
        encouraged = false
        approachArmed = true
        approachCooldown = 0
        performance.resetForNewRound()
        probeDelay = 0.45
        play("Next",0.16)
    }

    func found() {
        stopNotes()
        players["Wake"]?.stop()
        players["Next"]?.stop()
        let line = performance.found()
        if currentVoice?.isPlaying == true { pendingDiscovery = line }
        else { voice(line) }
    }

    func release() {
        pendingDiscovery = nil
        voice(performance.release())
    }

    func fiberReleased(_ count:Int) {
        guard (1...5).contains(count) else { return }
        // Five upward steps of the search tuning, resolving on the upper D.
        let gain:Float = count == 5 ? 0.14 : 0.21
        playNote(keys[count],volume:gain)
    }

    func stroke(_ stroke: Knot.Stroke, force: Double) {
        if stroke == .snap && force >= Knot.requiredPressure { performance.recordSnap() }
    }

    func tick(phase: Knot.Phase, proximity: Double, force: Double, speed: Double,
              touching: Bool, progress: Double, dt: Double, searchProgress: Double = 0, movingProximity: Double = 0) {
        guard active, !muted else { return }
        if let currentVoice, currentVoice.isPlaying {
            currentVoice.updateMeters()
            let amplitude = pow(10.0,Double(currentVoice.averagePower(forChannel:0))/20)
            voiceLevel += (min(1,amplitude*4)-voiceLevel)*min(1,dt*24)
        } else { voiceLevel = 0 }

        if phase == .seek {
            approachCooldown = max(0,approachCooldown-dt)
            if !touching || proximity < 0.57 { approachArmed = true }
            if touching {
                probeDelay -= dt
                if approachArmed && approachCooldown == 0 && movingProximity >= 0.73 && currentVoice?.isPlaying != true {
                    approachArmed = false
                    approachCooldown = 2.5
                    voice(.uh)
                }
                if !encouraged && searchProgress >= 0.24 && currentVoice?.isPlaying != true {
                    encouraged = true
                    voice([RobotPerformance.Voice.yeah,.lowMm,.mmHmm].randomElement()!)
                }
                let key = min(keys.count-1,max(0,Int(proximity*Double(keys.count))))
                let interval = 0.32 + 0.53*(1-proximity)
                let changed = key != lastKey && (soundingKey?.currentTime ?? 0) >= 0.14
                if probeDelay <= 0 || changed {
                    lastKey = key
                    let gain = currentVoice?.isPlaying == true ? 0.075 : 0.15
                    playNote(keys[key],volume:Float(gain+0.035*proximity))
                    probeDelay = interval
                }
            }
        }
        if phase == .rub, let line = pendingDiscovery, currentVoice?.isPlaying != true {
            pendingDiscovery = nil
            voice(line)
        }
        if phase == .rub,
           let response = performance.react(force:force,speed:speed,touching:touching,
                                            progress:progress,speaking:currentVoice?.isPlaying == true,dt:dt) {
            voice(response)
        }
    }
}
