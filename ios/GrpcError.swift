//
// Created by Mitchell Kutchuk on 11/14/22.
//

import Foundation

enum GrpcError: String, Error {
    case invalidHost = "Host is invalid"
    case invalidHeader = "Header value is invalid"
    case invalidData = "Data is invalid"
    case invalidCallId = "Call id is invalid"
    case missingConnection = "Connection not found"
    case callIdTypeMismatch = "Call with id did not match call type"
    case connectionFailure = "Connection failure"
    case notImplemented = "Not implemented"
}
