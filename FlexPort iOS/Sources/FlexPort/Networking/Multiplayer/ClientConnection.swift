import Foundation
import Network

/// Manages individual client connections on the server
@available(iOS 14.0, *)
class ClientConnection {
    let id: UUID
    private let connection: NWConnection
    weak var delegate: ClientConnectionDelegate?
    
    // Connection state
    private(set) var isConnected = false
    private(set) var playerName: String?
    private(set) var currentRoom: String?
    
    // Performance metrics
    private(set) var averageLatency: TimeInterval = 0
    private var latencyMeasurements: [TimeInterval] = []
    private(set) var lastAcknowledgedState: Date = Date()
    
    // Message handling
    private let messageQueue = DispatchQueue(label: "client.message", qos: .userInteractive)
    private var messageBuffer = Data()
    
    init(id: UUID, connection: NWConnection, delegate: ClientConnectionDelegate? = nil) {
        self.id = id
        self.connection = connection
        self.delegate = delegate
    }
    
    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleStateUpdate(state)
        }
        
        connection.start(queue: messageQueue)
        receiveMessage()
    }
    
    func disconnect() {
        isConnected = false
        connection.cancel()
        delegate?.clientDidDisconnect(self)
    }
    
    func send(_ data: Data) {
        guard isConnected else { return }
        
        // Create WebSocket frame
        let frame = createWebSocketFrame(data: data)
        
        connection.send(content: frame, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("Send error: \(error)")
                self?.disconnect()
            }
        })
    }
    
    private func handleStateUpdate(_ state: NWConnection.State) {
        switch state {
        case .ready:
            isConnected = true
            delegate?.clientDidConnect(self)
            startLatencyMeasurement()
            
        case .failed(let error), .waiting(let error):
            print("Connection error: \(error)")
            disconnect()
            
        case .cancelled:
            isConnected = false
            delegate?.clientDidDisconnect(self)
            
        default:
            break
        }
    }
    
    private func receiveMessage() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Receive error: \(error)")
                self.disconnect()
                return
            }
            
            if let data = data, !data.isEmpty {
                self.messageBuffer.append(data)
                self.processMessageBuffer()
            }
            
            if isComplete {
                self.disconnect()
            } else if self.isConnected {
                self.receiveMessage()
            }
        }
    }
    
    private func processMessageBuffer() {
        // Parse WebSocket frames
        while let frame = parseWebSocketFrame(from: &messageBuffer) {
            switch frame.opcode {
            case .text, .binary:
                delegate?.client(self, didReceiveMessage: frame.payload)
                
            case .ping:
                // Send pong
                let pongFrame = WebSocketFrame(opcode: .pong, payload: frame.payload)
                send(pongFrame.encode())
                
            case .pong:
                // Handle pong for latency measurement
                handlePong()
                
            case .close:
                disconnect()
                
            default:
                break
            }
        }
    }
    
    private func createWebSocketFrame(data: Data) -> Data {
        let frame = WebSocketFrame(opcode: .binary, payload: data)
        return frame.encode()
    }
    
    private func parseWebSocketFrame(from buffer: inout Data) -> WebSocketFrame? {
        guard buffer.count >= 2 else { return nil }
        
        let firstByte = buffer[0]
        let secondByte = buffer[1]
        
        let fin = (firstByte & 0x80) != 0
        let opcode = WebSocketOpcode(rawValue: firstByte & 0x0F) ?? .continuation
        let masked = (secondByte & 0x80) != 0
        var payloadLength = Int(secondByte & 0x7F)
        
        var offset = 2
        
        // Extended payload length
        if payloadLength == 126 {
            guard buffer.count >= offset + 2 else { return nil }
            payloadLength = Int(buffer[offset]) << 8 | Int(buffer[offset + 1])
            offset += 2
        } else if payloadLength == 127 {
            guard buffer.count >= offset + 8 else { return nil }
            payloadLength = 0
            for i in 0..<8 {
                payloadLength = payloadLength << 8 | Int(buffer[offset + i])
            }
            offset += 8
        }
        
        // Masking key
        var maskingKey: [UInt8]?
        if masked {
            guard buffer.count >= offset + 4 else { return nil }
            maskingKey = Array(buffer[offset..<offset + 4])
            offset += 4
        }
        
        // Payload
        guard buffer.count >= offset + payloadLength else { return nil }
        var payload = Data(buffer[offset..<offset + payloadLength])
        
        // Unmask payload if needed
        if let maskingKey = maskingKey {
            for i in 0..<payload.count {
                payload[i] ^= maskingKey[i % 4]
            }
        }
        
        // Remove processed data from buffer
        buffer.removeFirst(offset + payloadLength)
        
        guard fin else {
            // Handle fragmented frames if needed
            return nil
        }
        
        return WebSocketFrame(opcode: opcode, payload: payload)
    }
    
    // MARK: - Latency Measurement
    
    private func startLatencyMeasurement() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        let pingData = Date().timeIntervalSince1970.bitPattern.data
        let frame = WebSocketFrame(opcode: .ping, payload: pingData)
        send(frame.encode())
    }
    
    private func handlePong() {
        if let timestamp = latencyMeasurements.last {
            let latency = Date().timeIntervalSince1970 - timestamp
            updateLatencyMetrics(latency)
        }
    }
    
    private func updateLatencyMetrics(_ latency: TimeInterval) {
        latencyMeasurements.append(latency)
        
        // Keep only last 10 measurements
        if latencyMeasurements.count > 10 {
            latencyMeasurements.removeFirst()
        }
        
        // Calculate average
        averageLatency = latencyMeasurements.reduce(0, +) / Double(latencyMeasurements.count)
    }
}

// MARK: - WebSocket Frame

struct WebSocketFrame {
    let opcode: WebSocketOpcode
    let payload: Data
    
    func encode() -> Data {
        var frame = Data()
        
        // First byte: FIN (1) + RSV (000) + Opcode
        frame.append(0x80 | opcode.rawValue)
        
        // Payload length
        let payloadLength = payload.count
        if payloadLength < 126 {
            frame.append(UInt8(payloadLength))
        } else if payloadLength <= 65535 {
            frame.append(126)
            frame.append(UInt8((payloadLength >> 8) & 0xFF))
            frame.append(UInt8(payloadLength & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((payloadLength >> (i * 8)) & 0xFF))
            }
        }
        
        // Payload (no masking for server)
        frame.append(payload)
        
        return frame
    }
}

enum WebSocketOpcode: UInt8 {
    case continuation = 0x0
    case text = 0x1
    case binary = 0x2
    case close = 0x8
    case ping = 0x9
    case pong = 0xA
}

// MARK: - Delegate Protocol

protocol ClientConnectionDelegate: AnyObject {
    func clientDidConnect(_ client: ClientConnection)
    func clientDidDisconnect(_ client: ClientConnection)
    func client(_ client: ClientConnection, didReceiveMessage message: Data)
}

// MARK: - Extensions

extension Double {
    var bitPattern: UInt64 {
        return self.bitPattern
    }
}

extension UInt64 {
    var data: Data {
        var value = self
        return Data(bytes: &value, count: MemoryLayout<UInt64>.size)
    }
}