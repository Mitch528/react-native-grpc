//
//  Grpc.swift
//  react-native-grpc
//
//  Created by Mitchell Kutchuk on 11/12/22.
//

import Foundation
import GRPC
import NIO
import NIOHPACK

typealias GrpcCall = any ClientCall
typealias GrpcConnection = ([String: Any], GRPCChannel)

@objc(Grpc)
class RNGrpc: RCTEventEmitter {
    private let group = PlatformSupport.makeEventLoopGroup(loopCount: System.coreCount)

    var calls = [Int: GrpcCall]()
    var connections = [Int: GrpcConnection]()

    deinit {
        try! group.syncShutdownGracefully()
    }

    @objc
    override func constantsToExport() -> [AnyHashable: Any]! {
        [:]
    }

    @objc
    override static func requiresMainQueueSetup() -> Bool {
        false
    }

    @objc
    public func setGrpcSettings(_ clientId: NSNumber, options: NSDictionary) {
        let optsDict = options as! [String: Any]

        if let host = options["host"] as? String {
            try? self.closeConnection(id: clientId.intValue)
            if let conn = try? self.createConnection(host: host, options: optsDict) {
                self.connections[clientId.intValue] = (optsDict, conn)
            }
        }
    }

    @objc
    public func destroyClient(_ clientId: NSNumber) {
        try? self.closeConnection(id: clientId.intValue)
        self.connections.removeValue(forKey: clientId.intValue)
    }

    @objc
    public func unaryCall(_ callId: NSNumber,
                          clientId: NSNumber,
                          path: String,
                          obj: NSDictionary,
                          headers: NSDictionary,
                          resolve: @escaping RCTPromiseResolveBlock,
                          reject: @escaping RCTPromiseRejectBlock)
    {
        do {
            try self.startGrpcCallWithId(callId: callId.intValue, id: clientId.intValue, obj: obj, type: .unary, path: path, headers: headers)

            resolve(nil)
        } catch {
            reject("grpc", error.localizedDescription, error)
        }
    }

    @objc
    public func serverStreamingCall(_ callId: NSNumber,
                                    clientId: NSNumber,
                                    path: String,
                                    obj: NSDictionary,
                                    headers: NSDictionary,
                                    resolve: @escaping RCTPromiseResolveBlock,
                                    reject: @escaping RCTPromiseRejectBlock)
    {
        do {
            try self.startGrpcCallWithId(callId: callId.intValue,
                                         id: clientId.intValue, obj: obj, type: .serverStreaming, path: path, headers: headers)

            resolve(nil)
        } catch {
            reject("grpc", error.localizedDescription, error)
        }
    }

    @objc
    public func clientStreamingCall(_ callId: NSNumber,
                                    clientId: NSNumber,
                                    path: String,
                                    obj: NSDictionary,
                                    headers: NSDictionary,
                                    resolve: @escaping RCTPromiseResolveBlock,
                                    reject: @escaping RCTPromiseRejectBlock)
    {
        do {
            var call: GrpcCall? = self.calls[callId.intValue]

            if call == nil {
                call = try self.startGrpcCallWithId(callId: callId.intValue, id: clientId.intValue,
                                                    obj: obj, type: .clientStreaming, path: path, headers: headers)
            }

            guard let clientCall = call as? ClientStreamingCall<ByteBuffer, ByteBuffer> else {
                throw GrpcError.callIdTypeMismatch
            }

            guard let base64 = obj["data"] as? String, let data = Data(base64Encoded: base64) else {
                throw GrpcError.invalidData
            }

            let payload = ByteBuffer(data: data)

            clientCall.sendMessage(payload)

            resolve(true)
        } catch {
            reject("grpc", error.localizedDescription, error)
        }
    }

    @objc
    public func finishClientStreaming(_ callId: NSNumber,
                                      resolve: @escaping RCTPromiseResolveBlock,
                                      reject: @escaping RCTPromiseRejectBlock)
    {
        do {
            guard let call = self.calls[callId.intValue] else {
                throw GrpcError.invalidCallId
            }

            guard let clientCall = call as? ClientStreamingCall<ByteBuffer, ByteBuffer> else {
                throw GrpcError.callIdTypeMismatch
            }

            clientCall.sendEnd()
                .whenComplete { _ in
                    resolve(nil)
                }
        } catch {
            reject("grpc", error.localizedDescription, error)
        }
    }

    @objc
    public func cancelGrpcCall(_ callId: NSNumber,
                               resolve: @escaping RCTPromiseResolveBlock,
                               reject: @escaping RCTPromiseRejectBlock)
    {
        guard let call = self.calls[callId.intValue] else {
            resolve(false)

            return
        }

        call.cancel(promise: nil)

        resolve(true)
    }

    private func startGrpcCallWithId(callId: Int,
                                     id: Int,
                                     obj: NSDictionary,
                                     type: GRPCCallType,
                                     path: String,
                                     headers: NSDictionary) throws -> GrpcCall
    {
        guard let (_, conn) = self.connections[id] else {
            throw GrpcError.connectionFailure
        }

        guard let base64 = obj["data"] as? String, let data = Data(base64Encoded: base64) else {
            throw GrpcError.invalidData
        }

        let payload = ByteBuffer(data: data)

        let headerDict = headers.allKeys.map {
            (String(describing: $0), String(describing: headers[$0]!))
        }

        let options = try self.getCallOptionsWithHeaders(id: id, headers: HPACKHeaders(headerDict))

        var call: GrpcCall

        var headers = [String: String]()
        var trailers = [String: String]()

        func dispatchEvent(event: NSDictionary) {
            self.sendEvent(withName: "grpc-call", body: event)
        }

        func handleResponseResult(result: Result<ByteBuffer, Error>) {
            switch result {
            case .success(let response):
                let data = Data(buffer: response)
                let event: NSDictionary = [
                    "id": callId,
                    "type": "response",
                    "payload": data.base64EncodedString()
                ]

                dispatchEvent(event: event)
            case .failure(let error):
                var message = error.localizedDescription
                var code = -1

                var status: GRPCStatus?

                if let statusTransform = error as? GRPCStatusTransformable {
                    status = statusTransform.makeGRPCStatus()
                } else if let grpcStatus = error as? GRPCStatus {
                    status = grpcStatus
                }

                if let errorStatus = status {
                    message = errorStatus.message?.description ?? message
                    code = errorStatus.code.rawValue
                }

                let event: NSDictionary = [
                    "id": callId,
                    "type": "error",
                    "code": code,
                    "error": message,
                    "trailers": NSDictionary(dictionary: trailers)
                ]

                dispatchEvent(event: event)
            }
        }

        func removeCall() {
            DispatchQueue.main.async {
                self.calls.removeValue(forKey: callId)
            }
        }

        switch type {
        case .unary:
            let unaryCall: UnaryCall<ByteBuffer, ByteBuffer> = conn.makeUnaryCall(path: path, request: payload, callOptions: options)
            call = unaryCall

            unaryCall.response.whenComplete { result in
                handleResponseResult(result: result)
                removeCall()
            }
        case .clientStreaming:
            let clientStreaming: ClientStreamingCall<ByteBuffer, ByteBuffer> = conn.makeClientStreamingCall(path: path, callOptions: options)

            call = clientStreaming

            clientStreaming.response.whenComplete { result in
                handleResponseResult(result: result)
                removeCall()
            }
        case .serverStreaming:
            let serverStreaming: ServerStreamingCall<ByteBuffer, ByteBuffer> = conn.makeServerStreamingCall(path: path, request: payload, callOptions: options, interceptors: [ClientInterceptor](), handler: { response in
                let data = Data(buffer: response)
                let event: NSDictionary = [
                    "id": callId,
                    "type": "response",
                    "payload": data.base64EncodedString()
                ]

                dispatchEvent(event: event)
            })

            call = serverStreaming
        default:
            throw GrpcError.notImplemented
        }

        call.initialMetadata.whenSuccess { result in
            for data in result {
                headers[data.name] = data.value
            }

            let event: NSDictionary = [
                "id": callId,
                "type": "headers",
                "payload": NSDictionary(dictionary: headers)
            ]

            dispatchEvent(event: event)
        }

        call.trailingMetadata.whenSuccess { result in
            for data in result {
                trailers[data.name] = data.value
            }

            let event: NSDictionary = [
                "id": callId,
                "type": "trailers",
                "payload": NSDictionary(dictionary: trailers)
            ]

            dispatchEvent(event: event)
        }

        self.calls[callId] = call

        return call
    }

    private func getCallOptionsWithHeaders(id: Int, headers: HPACKHeaders) throws -> CallOptions {
        var encoding: ClientMessageEncoding = .disabled
        var timeLimit: TimeLimit = .none

        guard let (options, _) = self.connections[id] else {
            throw GrpcError.missingConnection
        }

        if let callTimeout = options["requestTimeout"] as? Int64 {
            timeLimit = .timeout(.seconds(callTimeout))
        }

        if let enabled = options["compression"] as? NSNumber, enabled.boolValue {
            let compressionAlgorithm: [CompressionAlgorithm]

            var limit = Int.max

            if let compressionLimit = options["compressionLimit"] as? NSNumber {
                limit = compressionLimit.intValue
            }

            switch options["compressionName"] as? NSString {
            case "gzip":
                compressionAlgorithm = [.gzip]
            case "deflate":
                compressionAlgorithm = [.deflate]
            case "identity":
                compressionAlgorithm = [.identity]
            default:
                compressionAlgorithm = CompressionAlgorithm.all
            }

            encoding = ClientMessageEncoding.enabled(
                .init(forRequests: compressionAlgorithm.first,
                      acceptableForResponses: compressionAlgorithm,
                      decompressionLimit: .absolute(limit))
            )
        }

        return CallOptions(customMetadata: headers, timeLimit: timeLimit, messageEncoding: encoding)
    }

    private func closeConnection(id: Int) throws {
        guard let (_, conn) = self.connections[id] else {
            throw GrpcError.missingConnection
        }

        let loop = self.group.next()
        conn.closeGracefully(deadline: .distantFuture, promise: loop.makePromise())
    }

    private func createConnection(host: String, options: [String: Any]) throws -> GRPCChannel? {
        guard let url = URLComponents(string: "https://\(host)"), let host = url.host else {
            throw GrpcError.invalidHost
        }

        let insecure = options["insecure"] as? NSNumber ?? false
        let keepaliveEnabled = options["keepalive"] as? NSNumber ?? true

        let port = url.port ?? (insecure.boolValue ? 80 : 443)

        var config = GRPCChannelPool.Configuration.with(
            target: .hostAndPort(host, port),
            transportSecurity: insecure.boolValue ? .plaintext : .tls(.makeClientDefault(compatibleWith: self.group)),
            eventLoopGroup: self.group
        )

        if let maxReceiveSize = options["responseLimit"] as? NSNumber {
            config.maximumReceiveMessageLength = maxReceiveSize.intValue
        }

        if keepaliveEnabled.boolValue {
            var keepaliveTimeout = TimeAmount.seconds(20)
            var keepaliveInterval = TimeAmount.nanoseconds(.max)

            if let interval = options["keepaliveInterval"] as? NSNumber {
                keepaliveInterval = TimeAmount.seconds(interval.int64Value)
            }

            if let timeout = options["keepaliveTimeout"] as? NSNumber {
                keepaliveTimeout = TimeAmount.seconds(timeout.int64Value)
            }

            let keepalive = ClientConnectionKeepalive(
                interval: keepaliveInterval,
                timeout: keepaliveTimeout,
                permitWithoutCalls: true
            )

            config.keepalive = keepalive
        }

        return try? GRPCChannelPool.with(configuration: config)
    }

    @objc
    override func supportedEvents() -> [String] {
        ["grpc-call"]
    }
}
