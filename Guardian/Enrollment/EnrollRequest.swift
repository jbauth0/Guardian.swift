// EnrollRequest.swift
//
// Copyright (c) 2016 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

/**
 A request to create a Guardian `Enrollment`
 
 - seealso: Guardian.enroll
 - seealso: Guardian.Enrollment
 */
public class EnrollRequest: Requestable {

    typealias T = EnrolledDevice

    private let api: API
    private let enrollmentTicket: String?
    private let enrollmentUri: String?
    private let notificationToken: String
    private let verificationKey: VerificationKey
    private let signingKey: SigningKey
    private var request: GuardianRequest<Device, Enrollment>

    init(api: API, enrollmentTicket: String? = nil, enrollmentUri: String? = nil, notificationToken: String, verificationKey: VerificationKey, signingKey: SigningKey) {
        self.api = api
        self.enrollmentTicket = enrollmentTicket
        self.enrollmentUri = enrollmentUri
        self.notificationToken = notificationToken
        self.verificationKey = verificationKey
        self.signingKey = signingKey
        let ticket: String
        if let enrollmentTicket = enrollmentTicket {
            ticket = enrollmentTicket
        } else if let enrollmentUri = enrollmentUri, let parameters = parameters(fromUri: enrollmentUri), let enrollmentTxId = parameters["enrollment_tx_id"] {
            ticket = enrollmentTxId
        } else {
            let url = self.api.baseUrl.appendingPathComponent("api/enroll")
            self.request = GuardianRequest(method: .post, url: url, error: GuardianError.invalidEnrollmentUri)
            return
        }

        self.request = api.enroll(withTicket: ticket, identifier: EnrolledDevice.vendorIdentifier, name: EnrolledDevice.deviceName, notificationToken: notificationToken, verificationKey: self.verificationKey)
    }

    /// Registers hooks to be called on specific events:
    ///  * on request being sent
    ///  * on response recieved (successful or not)
    ///  * on network error
    ///
    /// - Parameters:
    ///   - request: closure called with request information
    ///   - response: closure called with response and data
    ///   - error: closure called with network error
    /// - Returns: itself for chaining
    public func on(request: RequestHook? = nil, response: ResponseHook? = nil, error: ErrorHook? = nil) -> EnrollRequest {
        return self
    }

    public var description: String {
        return self.request.description
    }

    public var debugDescription: String {
        return self.request.debugDescription
    }

    /**
     Executes the request in a background thread

     - parameter callback: the termination callback, where the result is
     received
     */
    public func start(callback: @escaping (Result<EnrolledDevice>) -> ()) {
        self.request.start { result in
                switch result {
                case .failure(let cause):
                    callback(.failure(cause: cause))
                case .success(let payload):
                    let enrollment = EnrolledDevice(id: payload.identifier, userId: payload.userId, deviceToken: payload.token, notificationToken: self.notificationToken, signingKey: self.signingKey, totp: payload.totp)
                    callback(.success(payload: enrollment))
                }
        }
    }
}

func parameters(fromUri uri: String) -> [String: String]? {
    guard let components = URLComponents(string: uri), let otp = components.host?.lowercased()
        , components.scheme == "otpauth" && otp == "totp" else {
            return nil
    }
    guard let parameters = components.queryItems?.asDictionary() else {
        return nil
    }
    return parameters
}

private extension Collection where Iterator.Element == URLQueryItem {

    func asDictionary() -> [String: String] {
        return self.reduce([:], { (dict, item) in
            var values = dict
            if let value = item.value {
                values[item.name] = value
            }
            return values
        })
    }
}
