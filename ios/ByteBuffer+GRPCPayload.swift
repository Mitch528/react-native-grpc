//
// Created by Mitchell Kutchuk on 11/14/22.
//

import Foundation
import NIO
import GRPC

extension ByteBuffer: GRPCPayload {
    public init(serializedByteBuffer: inout ByteBuffer) {
        self = serializedByteBuffer
    }

    public func serialize(into buffer: inout ByteBuffer) {
        var copy = self
        buffer.writeBuffer(&copy)
    }
}