import AVFoundation
import Foundation

/// Molten Merge sound effects synthesized at runtime as PCM WAV data.
/// No audio assets, no downloads, works fully offline. Merge pitch rises
/// with the tier so bigger merges sound bigger.
final class SoundManager {
    static let shared = SoundManager()

    enum Effect {
        case click
        case drop
        case merge(tier: Int)
        case combo
        case gameOver
        case resume
    }

    var enabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: MergeGame.soundEnabledKey) == nil {
                return true // default on for first launch
            }
            return UserDefaults.standard.bool(forKey: MergeGame.soundEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: MergeGame.soundEnabledKey) }
    }

    private var players: [AVAudioPlayer] = []
    private let maxPlayers = 6
    private let sampleRate: Double = 44100

    private init() {}

    func play(_ effect: Effect) {
        guard enabled else { return }
        let data: Data
        switch effect {
        case .click:
            data = Self.wav(samples: tone(freq: 880, dur: 0.06))
        case .drop:
            // Soft glassy "plip" falling in pitch.
            data = Self.wav(samples: tone(freq: 320, dur: 0.09, slideTo: 170))
        case .merge(let tier):
            // Pop that rises with the tier: sparks blip, prisms sing.
            let base = 440.0 + Double(max(0, min(tier, 5))) * 110.0
            data = Self.wav(samples: tone(freq: base, dur: 0.14, slideTo: base * 1.7))
        case .combo:
            data = Self.wav(samples: arpeggio(notes: [659.25, 830.61, 987.77], noteDur: 0.10))
        case .gameOver:
            data = Self.wav(samples: tone(freq: 330, dur: 0.50, slideTo: 110))
        case .resume:
            data = Self.wav(samples: arpeggio(notes: [523.25, 659.25, 783.99], noteDur: 0.12))
        }
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.prepareToPlay()
        player.play()
        players.append(player)
        players = players.filter { $0.isPlaying }
        if players.count > maxPlayers {
            players.removeFirst(players.count - maxPlayers)
        }
    }

    // MARK: - Synthesis

    /// Sine tone with fast attack and exponential decay.
    private func tone(freq: Double, dur: Double, slideTo: Double? = nil) -> [Float] {
        let n = Int(dur * sampleRate)
        var out = [Float](repeating: 0, count: n)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let f = slideTo.map { freq + ($0 - freq) * (t / dur) } ?? freq
            phase += 2.0 * .pi * f / sampleRate
            let env = exp(-4.0 * t / dur) * min(1.0, t / 0.008)
            out[i] = Float(sin(phase) * env * 0.5)
        }
        return out
    }

    /// Ascending note run with slight overlap between notes.
    private func arpeggio(notes: [Double], noteDur: Double, shimmer: Bool = false) -> [Float] {
        var out: [Float] = []
        let overlap = Int(noteDur * sampleRate * 0.25)
        for f in notes {
            var note = tone(freq: f, dur: noteDur * 1.6)
            if shimmer {
                let octave = tone(freq: f * 2.0, dur: noteDur * 1.6)
                for j in 0..<min(note.count, octave.count) {
                    note[j] += octave[j] * 0.25
                }
            }
            if out.isEmpty {
                out = note
            } else {
                for j in 0..<overlap {
                    out[out.count - overlap + j] += note[j] * 0.6
                }
                out += note[overlap...]
            }
        }
        return out
    }

    private static func wav(samples: [Float], sampleRate: Int = 44100) -> Data {
        var data = Data()
        func u16(_ v: Int) {
            data.append(UInt8(v & 0xFF))
            data.append(UInt8((v >> 8) & 0xFF))
        }
        func u32(_ v: Int) {
            u16(v & 0xFFFF)
            u16((v >> 16) & 0xFFFF)
        }
        data.append(contentsOf: "RIFF".utf8); u32(36 + samples.count * 2)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8); u32(16)
        u16(1); u16(1); u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16)
        data.append(contentsOf: "data".utf8); u32(samples.count * 2)
        for s in samples {
            let v = Int(max(-1.0, min(1.0, s)) * 32767.0)
            u16(v & 0xFFFF)
        }
        return data
    }
}
