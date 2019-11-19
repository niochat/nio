/*
 Copyright 2019 The Matrix.org Foundation C.I.C

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

public extension MX3PidAddManager {

    // MARK: - Setup
    @nonobjc convenience init(session: MXSession) {
        self.init(__matrixSession: session)
    }

    @nonobjc func cancel(session: MX3PidAddSession) {
        __cancel3PidAddSession(session)
    }

    // MARK: - Email
    @nonobjc @discardableResult func startAddEmailSession(_ email: String, nextLink: String?, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MX3PidAddSession {
        return __startAddEmailSession(withEmail: email, nextLink: nextLink, success: currySuccess(completion), failure: curryFailure(completion))
    }
    
    @nonobjc func tryFinaliseAddEmailSession(_ session: MX3PidAddSession, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> Void {
        return __tryFinaliseAddEmailSession(session, success: currySuccess(completion), failure: curryFailure(completion))
    }

    @nonobjc func tryFinaliseAddEmailSession(_ session: MX3PidAddSession, password: String?, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> Void {
        return __tryFinaliseAddEmailSession(session, withPassword: password, success: currySuccess(completion), failure: curryFailure(completion))
    }

    @nonobjc func tryFinaliseAddEmailSession(_ session: MX3PidAddSession, authParams: [String: Any]?, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> Void {
        return __tryFinaliseAddEmailSession(session, authParams: authParams, success: currySuccess(completion), failure: curryFailure(completion))
    }

    // MARK: - Add MSISDN
    @nonobjc @discardableResult func startAddPhoneNumberSession(_ phoneNumber: String, countryCode: String?, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> MX3PidAddSession {
        return __startAddPhoneNumberSession(withPhoneNumber: phoneNumber, countryCode: countryCode, success: currySuccess(completion), failure: curryFailure(completion))
    }

    @nonobjc func finaliseAddPhoneNumberSession(_ session: MX3PidAddSession, token: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> Void {
        return __finaliseAddPhoneNumber(session, withToken: token, success: currySuccess(completion), failure: curryFailure(completion))
    }

    @nonobjc func finaliseAddPhoneNumberSession(_ session: MX3PidAddSession, token: String, password: String?, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> Void {
        return __finaliseAddPhoneNumber(session, withToken: token, password: password, success: currySuccess(completion), failure: curryFailure(completion))
    }

    @nonobjc func finaliseAddPhoneNumberSession(_ session: MX3PidAddSession, token: String, authParams: [String: Any]?, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> Void {
        return __finaliseAddPhoneNumber(session, withToken: token, authParams: authParams, success: currySuccess(completion), failure: curryFailure(completion))
    }


    // MARK: - Bind Email
    @nonobjc @discardableResult func startIdentityServerSession(withEmail email: String, bind: Bool, completion: @escaping (_ response: MXResponse<Bool>) -> Void) -> MX3PidAddSession {
        return __startIdentityServerEmailSession(withEmail: email, bind: bind, success: currySuccess(completion), failure: curryFailure(completion))
    }

    @nonobjc func tryFinaliseIdentityServerEmailSession(_ session: MX3PidAddSession, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> Void {
        return __tryFinaliseIdentityServerEmailSession(session, success: currySuccess(completion), failure: curryFailure(completion))
    }

    // MARK: - Bind phone number
    @nonobjc @discardableResult func startIdentityServerSession(withPhoneNumber phoneNumber: String, countryCode: String?, bind: Bool, completion: @escaping (_ response: MXResponse<Bool>) -> Void) -> MX3PidAddSession {
        return __startIdentityServerPhoneNumberSession(withPhoneNumber: phoneNumber, countryCode: countryCode, bind: bind, success: currySuccess(completion), failure: curryFailure(completion))
    }

    @nonobjc func finaliseIdentityServerPhoneNumberSession(_ session: MX3PidAddSession, token: String, completion: @escaping (_ response: MXResponse<Void>) -> Void) -> Void {
        return __finaliseIdentityServerPhoneNumber(session, withToken: token, success: currySuccess(completion), failure: curryFailure(completion))
    }
}
