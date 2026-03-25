import AVFoundation
import UIKit
import SwiftUI

@MainActor
final class SensoryManager: ObservableObject {
    static let shared = SensoryManager()

    private var audioEngine: AVAudioEngine?
    private var pinkNoiseNode: AVAudioSourceNode?
    private var chimePlayer: AVAudioPlayerNode?
    private var typingTimer: Timer?

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGen = UINotificationFeedbackGenerator()
    private let selectionGen = UISelectionFeedbackGenerator()

    @Published var isAmbientPlaying = false

    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        notificationGen.prepare()
        selectionGen.prepare()
    }

    // MARK: - Haptics

    func lightTap() {
        impactLight.impactOccurred()
    }

    func mediumTap() {
        impactMedium.impactOccurred()
    }

    func heavyTap() {
        impactHeavy.impactOccurred()
    }

    func success() {
        notificationGen.notificationOccurred(.success)
    }

    func warning() {
        notificationGen.notificationOccurred(.warning)
    }

    func selection() {
        selectionGen.selectionChanged()
    }

    /// Double-pulse haptic for high-priority bio-alerts
    func alertPulse() {
        impactHeavy.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.impactHeavy.impactOccurred(intensity: 1.0)
        }
    }

    // MARK: - Zen Chime (synthesized on splash)

    func playZenChime() {
        guard !isSilentMode else { return }
        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let sampleRate = mainMixer.outputFormat(forBus: 0).sampleRate
        let duration: Double = 1.2
        let totalFrames = Int(sampleRate * duration)
        var currentFrame = 0
        let frequencies: [(hz: Double, amp: Float, decay: Double)] = [
            (523.25, 0.20, 2.5),   // C5
            (659.25, 0.15, 2.8),   // E5
            (783.99, 0.10, 3.0),   // G5
        ]

        let sourceNode = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            for frame in 0..<Int(frameCount) {
                let t = Double(currentFrame + frame) / sampleRate
                var sample: Float = 0
                for f in frequencies {
                    let envelope = Float(exp(-t * f.decay))
                    sample += f.amp * envelope * Float(sin(2.0 * .pi * f.hz * t))
                }
                for buffer in ablPointer {
                    guard let ptr = buffer.mData else { continue }
                    ptr.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            currentFrame += Int(frameCount)
            return noErr
        }

        engine.attach(sourceNode)
        let format = mainMixer.outputFormat(forBus: 0)
        engine.connect(sourceNode, to: mainMixer, format: format)

        do {
            try configureAudioSession(ambient: true)
            try engine.start()
            self.audioEngine = engine
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.3) { [weak self] in
                engine.stop(); self?.audioEngine = nil
            }
        } catch {}
    }

    // MARK: - Pink Noise (Sleep Sanctuary ambient)

    func startPinkNoise() {
        guard !isSilentMode, !isAmbientPlaying else { return }
        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let sampleRate = mainMixer.outputFormat(forBus: 0).sampleRate

        var b0: Double = 0, b1: Double = 0, b2: Double = 0
        var b3: Double = 0, b4: Double = 0, b5: Double = 0, b6: Double = 0

        let sourceNode = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            for frame in 0..<Int(frameCount) {
                let white = Double.random(in: -1...1)
                b0 = 0.99886 * b0 + white * 0.0555179
                b1 = 0.99332 * b1 + white * 0.0750759
                b2 = 0.96900 * b2 + white * 0.1538520
                b3 = 0.86650 * b3 + white * 0.3104856
                b4 = 0.55000 * b4 + white * 0.5329522
                b5 = -0.7616 * b5 - white * 0.0168980
                let pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
                b6 = white * 0.115926
                let sample = Float(pink * 0.06)
                for buffer in ablPointer {
                    guard let ptr = buffer.mData else { continue }
                    ptr.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(sourceNode)
        let format = mainMixer.outputFormat(forBus: 0)
        engine.connect(sourceNode, to: mainMixer, format: format)

        do {
            try configureAudioSession(ambient: true)
            try engine.start()
            self.audioEngine = engine
            self.pinkNoiseNode = sourceNode
            isAmbientPlaying = true
        } catch {}
    }

    func stopPinkNoise() {
        audioEngine?.stop()
        audioEngine = nil
        pinkNoiseNode = nil
        isAmbientPlaying = false
    }

    // MARK: - AI Typing Sound

    func startTypingSound() {
        guard !isSilentMode else { return }
        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let sampleRate = mainMixer.outputFormat(forBus: 0).sampleRate
        var currentFrame = 0
        let clickIntervalFrames = Int(sampleRate * 0.08)

        let sourceNode = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            for frame in 0..<Int(frameCount) {
                let pos = (currentFrame + frame) % clickIntervalFrames
                var sample: Float = 0
                if pos < 60 {
                    let t = Double(pos) / sampleRate
                    let envelope = Float(exp(-t * 120))
                    sample = 0.03 * envelope * Float(sin(2.0 * .pi * 900 * t))
                }
                for buffer in ablPointer {
                    guard let ptr = buffer.mData else { continue }
                    ptr.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            currentFrame += Int(frameCount)
            return noErr
        }

        engine.attach(sourceNode)
        let format = mainMixer.outputFormat(forBus: 0)
        engine.connect(sourceNode, to: mainMixer, format: format)

        do {
            try configureAudioSession(ambient: true)
            try engine.start()
            self.audioEngine = engine
        } catch {}
    }

    func stopTypingSound() {
        audioEngine?.stop()
        audioEngine = nil
    }

    // MARK: - Silent Mode

    private var isSilentMode: Bool {
        !AVAudioSession.sharedInstance().isOtherAudioPlaying &&
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
    }

    private func configureAudioSession(ambient: Bool) throws {
        try AVAudioSession.sharedInstance().setCategory(
            ambient ? .ambient : .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try AVAudioSession.sharedInstance().setActive(true)
    }
}

// MARK: - View Extension for Haptics

extension View {
    func onTapHaptic(_ style: SensoryManager.HapticStyle = .light, action: @escaping () -> Void) -> some View {
        self.simultaneousGesture(TapGesture().onEnded {
            Task { @MainActor in
                switch style {
                case .light: SensoryManager.shared.lightTap()
                case .medium: SensoryManager.shared.mediumTap()
                case .heavy: SensoryManager.shared.heavyTap()
                case .success: SensoryManager.shared.success()
                case .warning: SensoryManager.shared.warning()
                case .alertPulse: SensoryManager.shared.alertPulse()
                }
                action()
            }
        })
    }
}

extension SensoryManager {
    enum HapticStyle { case light, medium, heavy, success, warning, alertPulse }
}
