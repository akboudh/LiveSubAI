import AVFoundation

final class PCMConverter {
    let inputFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter

    init?(inputFormat: AVAudioFormat) {
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return nil
        }
        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        self.converter = converter
    }

    func convertToLinear16Mono16k(_ inputBuffer: AVAudioPCMBuffer) -> Data? {
        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let capacity = max(1, AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 32)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        var error: NSError?
        var didProvideInput = false
        converter.convert(to: outputBuffer, error: &error) { _, status in
            if didProvideInput {
                status.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            status.pointee = .haveData
            return inputBuffer
        }
        if error != nil {
            return nil
        }

        guard let channelData = outputBuffer.floatChannelData?[0] else {
            return nil
        }

        var data = Data(capacity: Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size)
        for frame in 0..<Int(outputBuffer.frameLength) {
            let clamped = max(-1, min(1, channelData[frame]))
            var sample = Int16(clamped * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &sample) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        return data
    }
}
