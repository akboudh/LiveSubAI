import AVFoundation
import CoreAudio
import Foundation

final class AudioCaptureManager {
    private static let targetChunkByteCount = 3_200 // 100 ms of 16 kHz 16-bit mono PCM.

    private let stateQueue = DispatchQueue(label: "LiveSubAI.CoreAudioTap.State")
    private let ioQueue = DispatchQueue(label: "LiveSubAI.CoreAudioTap.IO")

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var inputFormat: AVAudioFormat?
    private var converter: PCMConverter?
    private var pendingAudio = Data()
    private var audioHandler: ((Data) -> Void)?

    func hasScreenCaptureAccess() async -> Bool {
        true
    }

    func requestScreenCaptureAccess() async -> Bool {
        true
    }

    func start(audioHandler: @escaping (Data) -> Void) async throws {
        guard #available(macOS 14.2, *) else {
            throw LiveSubAIError.systemAudioCaptureUnavailable("System audio capture requires macOS 14.2 or newer.")
        }

        try stateQueue.sync {
            self.audioHandler = audioHandler
            self.pendingAudio.removeAll(keepingCapacity: true)
            try self.startCoreAudioTap()
        }
    }

    func stop() async {
        stateQueue.sync {
            stopCoreAudioTap()
            converter = nil
            inputFormat = nil
            pendingAudio.removeAll(keepingCapacity: false)
            audioHandler = nil
        }
    }

    @available(macOS 14.2, *)
    private func startCoreAudioTap() throws {
        stopCoreAudioTap()

        let excludedProcessIDs = currentProcessAudioObjectID().map { [$0] } ?? []
        let tapDescription = CATapDescription(stereoGlobalTapButExcludeProcesses: excludedProcessIDs)
        tapDescription.name = "LiveSubAI System Audio"
        tapDescription.isPrivate = true
        tapDescription.muteBehavior = CATapMuteBehavior.unmuted

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateProcessTap(tapDescription, &newTapID), "Create system audio tap")
        tapID = newTapID

        inputFormat = try tapAudioFormat(for: newTapID)
        converter = nil

        let aggregateUID = "com.livesubai.audio.tap.\(UUID().uuidString)"
        let tapUID = tapDescription.uuid.uuidString
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "LiveSubAI System Audio",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: tapUID]
            ]
        ]

        var newAggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        try check(
            AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &newAggregateDeviceID),
            "Create private aggregate audio device"
        )
        aggregateDeviceID = newAggregateDeviceID

        var newIOProcID: AudioDeviceIOProcID?
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(
            &newIOProcID,
            newAggregateDeviceID,
            ioQueue
        ) { [weak self] _, inputData, _, _, _ in
            self?.handleInputAudio(inputData)
        }
        try check(createStatus, "Create audio input callback")
        ioProcID = newIOProcID

        try check(AudioDeviceStart(newAggregateDeviceID, newIOProcID), "Start system audio capture")
    }

    private func stopCoreAudioTap() {
        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown), let ioProcID {
            _ = AudioDeviceStop(aggregateDeviceID, ioProcID)
            _ = AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }
        ioProcID = nil

        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown) {
            _ = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }

        if tapID != AudioObjectID(kAudioObjectUnknown) {
            if #available(macOS 14.2, *) {
                _ = AudioHardwareDestroyProcessTap(tapID)
            }
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    private func handleInputAudio(_ inputData: UnsafePointer<AudioBufferList>) {
        guard let inputFormat else { return }
        let mutableInputData = UnsafeMutablePointer(mutating: inputData)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: inputFormat,
            bufferListNoCopy: mutableInputData,
            deallocator: nil
        ) else {
            return
        }

        let audioBufferList = UnsafeMutableAudioBufferListPointer(mutableInputData)
        guard let firstBuffer = audioBufferList.first else { return }
        let bytesPerFrame = max(Int(inputFormat.streamDescription.pointee.mBytesPerFrame), 1)
        buffer.frameLength = AVAudioFrameCount(Int(firstBuffer.mDataByteSize) / bytesPerFrame)
        guard buffer.frameLength > 0 else { return }

        if converter == nil || converter?.inputFormat.isEqual(inputFormat) == false {
            converter = PCMConverter(inputFormat: inputFormat)
        }
        guard let data = converter?.convertToLinear16Mono16k(buffer) else { return }
        emitChunkedAudio(data)
    }

    private func emitChunkedAudio(_ data: Data) {
        pendingAudio.append(data)

        while pendingAudio.count >= Self.targetChunkByteCount {
            let chunk = pendingAudio.prefix(Self.targetChunkByteCount)
            audioHandler?(Data(chunk))
            pendingAudio.removeFirst(Self.targetChunkByteCount)
        }
    }

    @available(macOS 14.2, *)
    private func tapAudioFormat(for tapID: AudioObjectID) throws -> AVAudioFormat {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamDescription = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(
            AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &streamDescription),
            "Read system audio format"
        )
        guard let format = withUnsafePointer(to: &streamDescription, { AVAudioFormat(streamDescription: $0) }) else {
            throw LiveSubAIError.unsupportedAudioFormat
        }
        return format
    }

    private func currentProcessAudioObjectID() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var processID = getpid()
        var objectID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            UInt32(MemoryLayout<pid_t>.size),
            &processID,
            &size,
            &objectID
        )
        return status == noErr ? objectID : nil
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            let code = fourCharacterCode(status)
            let message = code.isEmpty ? "\(operation) failed (\(status))" : "\(operation) failed (\(status), \(code))"
            throw LiveSubAIError.systemAudioCaptureUnavailable(message)
        }
    }

    private func fourCharacterCode(_ status: OSStatus) -> String {
        let value = UInt32(bitPattern: status).bigEndian
        let characters: [CChar] = [
            CChar((value >> 24) & 0xff),
            CChar((value >> 16) & 0xff),
            CChar((value >> 8) & 0xff),
            CChar(value & 0xff),
            0
        ]
        guard characters.dropLast().allSatisfy({ $0 >= 32 && $0 <= 126 }) else {
            return ""
        }
        return String(cString: characters)
    }
}
