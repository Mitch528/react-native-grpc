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

@objc(Grpc)
class RNGrpc: RCTEventEmitter {
    private let group: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    var grpcInsecure = false
    var grpcHost: String?
    var grpcResponseSizeLimit: Int?
    var grpcCompression: Bool?
    var grpcCompressorName: String?
    var calls = [Int: GrpcCall]()

    deinit {
        try! group.syncShutdownGracefully()
    }

    @objc
    public func setInsecure(_ insecure: NSNumber) {
        self.grpcInsecure = insecure.boolValue
    }

    @objc
    public func setHost(_ host: String) {
        self.grpcHost = host
    }

    @objc
    public func setCompression(_ enabled: NSNumber, compressorName: String) {
        self.grpcCompression = enabled.boolValue
        self.grpcCompressorName = compressorName
    }

    @objc
    public func setResponseSizeLimit(_ responseSizeLimit: NSNumber) {
        self.grpcResponseSizeLimit = responseSizeLimit.intValue
    }

    @objc
    public func getResponseSizeLimit(_ resolve: @escaping RCTPromiseResolveBlock,
                                     reject: @escaping RCTPromiseRejectBlock) {
        resolve(self.grpcResponseSizeLimit)
    }

    @objc
    public func getIsInsecure(_ resolve: @escaping RCTPromiseResolveBlock,
                              reject: @escaping RCTPromiseRejectBlock) {
        resolve(self.grpcInsecure)
    }

    @objc
    public func getHost(_ resolve: @escaping RCTPromiseResolveBlock,
                        reject: @escaping RCTPromiseRejectBlock) {
        resolve(self.grpcHost)
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
    public func unaryCall(_ callId: NSNumber,
                          path: String,
                          obj: NSDictionary,
                          headers: NSDictionary,
                          resolve: @escaping RCTPromiseResolveBlock,
                          reject: @escaping RCTPromiseRejectBlock) {
        do {
            try self.startGrpcCallWithId(callId: callId.intValue, obj: obj, type: .unary, path: path, headers: headers)

            resolve(nil)
        } catch {
            reject("grpc", error.localizedDescription, error)
        }
    }

    @objc
    public func serverStreamingCall(_ callId: NSNumber,
                                    path: String,
                                    obj: NSDictionary,
                                    headers: NSDictionary,
                                    resolve: @escaping RCTPromiseResolveBlock,
                                    reject: @escaping RCTPromiseRejectBlock) {
        do {
            try self.startGrpcCallWithId(callId: callId.intValue, obj: obj, type: .serverStreaming, path: path, headers: headers)

            resolve(nil)
        } catch {
            reject("grpc", error.localizedDescription, error)
        }
    }

    @objc
    public func clientStreamingCall(_ callId: NSNumber,
                                    path: String,
                                    obj: NSDictionary,
                                    headers: NSDictionary,
                                    resolve: @escaping RCTPromiseResolveBlock,
                                    reject: @escaping RCTPromiseRejectBlock) {
        do {
            var call: GrpcCall? = self.calls[callId.intValue]

            if call == nil {
                call = try self.startGrpcCallWithId(callId: callId.intValue, obj: obj, type: .clientStreaming, path: path, headers: headers)
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
                                      reject: @escaping RCTPromiseRejectBlock) {
        do {
            guard let call = self.calls[callId.intValue] else {
                throw GrpcError.invalidCallId
            }

            guard let clientCall = call as? ClientStreamingCall<ByteBuffer, ByteBuffer> else {
                throw GrpcError.callIdTypeMismatch
            }

            clientCall.sendEnd()
                    .whenComplete({ result in
                        resolve(nil)
                    })
        } catch {
            reject("grpc", error.localizedDescription, error)
        }
    }

    @objc
    public func cancelGrpcCall(_ callId: NSNumber,
                               resolve: @escaping RCTPromiseResolveBlock,
                               reject: @escaping RCTPromiseRejectBlock) {
        guard let call = self.calls[callId.intValue] else {
            resolve(false)

            return
        }

        call.cancel(promise: nil)

        resolve(true)
    }


    private func startGrpcCallWithId(callId: Int,
                                     obj: NSDictionary,
                                     type: GRPCCallType,
                                     path: String,
                                     headers: NSDictionary) throws -> GrpcCall {
        guard let conn = try createConnection() else {
            throw GrpcError.connectionFailure
        }

        guard let base64 = obj["data"] as? String, let data = Data(base64Encoded: base64) else {
            throw GrpcError.invalidData
        }

        let payload = ByteBuffer(data: data)

        let headerDict = headers.allKeys.map {
            (String(describing: $0), String(describing: headers[$0]!))
        }

        let options = self.getCallOptionsWithHeaders(headers: HPACKHeaders(headerDict))

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
                let event: NSDictionary = [
                    "id": callId,
                    "type": "error",
                    "code": (error as? any GRPCErrorProtocol)?.makeGRPCStatus().code.rawValue,
                    "error": error.localizedDescription,
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

            clientStreaming.response.whenComplete({ result in
                handleResponseResult(result: result)
                removeCall()
            })
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

        calls[callId] = call

        return call
    }

    private func getCallOptionsWithHeaders(headers: HPACKHeaders) -> CallOptions {
        var encoding: ClientMessageEncoding = .disabled

        if let enabled = self.grpcCompression, enabled {
            let compressionAlgorithm: [CompressionAlgorithm]

            switch self.grpcCompressorName {
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
                            decompressionLimit: .ratio(20)
                    )
            )
        }

        return CallOptions(customMetadata: headers, messageEncoding: encoding)
    }

    private func createConnection() throws -> GRPCChannel? {
        guard let host = self.grpcHost else {
            throw GrpcError.invalidHost
        }

        guard let url = URLComponents(string: "https://\(host)"), let host = url.host else {
            throw GrpcError.invalidHost
        }

        let port = url.port ?? (self.grpcInsecure ? 80 : 443)

        var config = GRPCChannelPool.Configuration.with(
                target: .hostAndPort(host, port),
                transportSecurity: self.grpcInsecure ? .plaintext : .tls(.makeClientConfigurationBackedByNIOSSL()),
                eventLoopGroup: self.group
        )

        if let maxReceiveSize = self.grpcResponseSizeLimit {
            config.maximumReceiveMessageLength = maxReceiveSize
        }

        return try? GRPCChannelPool.with(configuration: config)
    }


    @objc
    override func supportedEvents() -> [String] {
        ["grpc-call"]
    }
}
