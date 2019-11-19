/*
 Copyright 2017 Avery Pierce
 
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




/**
 Captures the result of an API call and it's associated success data.
 
 # Examples:
 
 Use a switch statement to handle both a success and an error:
 
     mxRestClient.publicRooms { response in
         switch response {
         case .success(let rooms):
             // Do something useful with these rooms
             break
         
         case .failure(let error):
             // Handle the error in some way
             break
         }
     }
 
 Silently ignore the failure case:
 
     mxRestClient.publicRooms { response in
         guard let rooms = response.value else { return }
         // Do something useful with these rooms
     }
 
 */
public enum MXResponse<T> {
    case success(T)
    case failure(Error)
    
    /// Indicates whether the API call was successful
    public var isSuccess: Bool {
        switch self {
        case .success:  return true
        default:        return false
        }
    }
    
    /// The response's success value, if applicable
    public var value: T? {
        switch self {
        case .success(let value): return value
        default: return nil
        }
    }
    
    /// Indicates whether the API call failed
    public var isFailure: Bool {
        return !isSuccess
    }
    
    /// The response's error value, if applicable
    public var error: Error? {
        switch self {
        case .failure(let error): return error
        default: return nil
        }
    }
}



/**
 Represents an error that was unexpectedly nil.
 
 This struct only exists to fill in the gaps formed by optionals that
 were created by ObjC headers that don't specify nullibility. Under
 normal controlled circumstances, this should probably never be used.
 */
internal struct _MXUnknownError : Error {
    var localizedDescription: String {
        return "error object was unexpectedly nil"
    }
}


private extension MXResponse {
    
    /**
     Take the value from an optional, if it's available.
     Otherwise, return a failure with _MXUnknownError
     
     - parameter value: to be captured in a `.success` case, if it's not `nil` and the type is correct.
     
     - returns: `.success(value)` if the value is not `nil`, otherwise `.failure(_MXUnkownError())`
     */
    static func fromOptional(value: Any?) -> MXResponse<T> {
        if let value = value as? T {
            return .success(value)
        } else {
            return .failure(_MXUnknownError())
        }
    }
    
    /**
     Take the error from an optional, if it's available.
     Otherwise, return a failure with _MXUnknownError
     
     - parameter error: to be captured in a `.failure` case, if it's not `nil`.
     
     - returns: `.failure(error)` if the value is not `nil`, otherwise `.failure(_MXUnkownError())`
     */
    static func fromOptional(error: Error?) -> MXResponse<T> {
        return .failure(error ?? _MXUnknownError())
    }
}




/**
 Return a closure that accepts any object, converts it to a MXResponse value, and then
 executes the provided completion block
 
 The `transform` parameter is helpful in cases where `T` and `U` are different types,
 for instance when `U` is an enum, and `T` is it's identifier as a String.
 
 - parameters:
 - transform: A block that takes the output from the API and transforms it to the expected
 type. The default block returns the input as-is.
 - input: The value taken directly from the API call.
 - completion: A block that gets called with the manufactured `MXResponse` variable.
 - response: The API response wrapped in a `MXResponse` enum.
 
 - returns: a block that accepts an optional value from the API, wraps it in an `MXResponse`, and then passes it to `completion`
 
 
 ## Usage Example:
 
 ```
 func guestAccess(forRoom roomId: String, completion: @escaping (_ response: MXResponse<MXRoomGuestAccess>) -> Void) -> MXHTTPOperation? {
 return __guestAccess(ofRoom: roomId, success: success(transform: MXRoomGuestAccess.init, completion), failure: error(completion))
 }
 ```
 
 1. The `success:` block of the `__guestAccess` function passes in a `String?` type from the API.
 2. That value gets fed into the `transform:` block – in this case, an initializer for `MXRoomGuestAccess`.
 3. The `MXRoomGuestAccess` value returned from the  `transform:` block is wrapped in a `MXResponse` enum.
 4. The newly created `MXResponse` is passed to the completion block.
 
 */
internal func currySuccess<T, U>(transform: @escaping (_ input: T) -> U? = { return $0 as? U },
                          _ completion: @escaping (_ response: MXResponse<U>) -> Void) -> (T) -> Void {
    return { completion(.fromOptional(value: transform($0))) }
}

/// Special case of currySuccess for Objective-C functions whose competion handlers take no arguments
internal func currySuccess(_ completion: @escaping (_ response: MXResponse<Void>) -> Void) -> () -> Void {
    return { completion(MXResponse.success(Void())) }
}

/// Return a closure that accepts any error, converts it to a MXResponse value, and then executes the provded completion block
internal func curryFailure<T>(_ completion: @escaping (MXResponse<T>) -> Void) -> (Error?) -> Void {
    return { completion(.fromOptional(error: $0)) }
}







/**
 Reports ongoing progress of a process, and encapsulates relevant
 data when the operation succeeds or fails.
 
 # Examples:
 
 Use a switch statement to handle each case:
 
     mxRestClient.uploadContent( ... ) { progress in
         switch progress {
         case .progress(let progress):
             // Update progress bar
             break
        
         case .success(let contentUrl):
             // Do something with the url
             break
 
         case .failure(let error):
             // Handle the error
             break
         }
     }
 
 Ignore progress updates. Wait until operation is complete.
 
     mxRestClient.uploadContent( ... ) { progress in
         guard progress.isComplete else { return }
 
         if let url = progress.value {
            // Do something with the url
         } else {
            // Handle the error
         }
     }
 */
public enum MXProgress<T> {
    case progress(Progress)
    case success(T)
    case failure(Error)
    
    /// Indicates whether the call is complete.
    public var isComplete: Bool {
        switch self {
        case .success, .failure: return true
        default: return false
        }
    }
    
    /// The current progress. If the process is already complete, this will return nil.
    public var progress: Progress? {
        switch self {
        case .progress(let progress): return progress
        default: return nil
        }
    }
    
    /// Indicates whether the API call was successful.
    /// Returns false if the process is still incomplete.
    public var isSuccess: Bool {
        switch self {
        case .success:   return true
        default:        return false
        }
    }
    
    /// The response's success value, if applicable
    public var value: T? {
        switch self {
        case .success(let value): return value
        default: return nil
        }
    }
    
    /// Indicates whether the API call failed.
    /// Returns false if the process is still incomplete.
    public var isFailure: Bool {
        switch self {
        case .failure:  return true
        default:        return false
        }
    }
    
    /// The response's error value, if applicable
    public var error: Error? {
        switch self {
        case .failure(let error): return error
        default: return nil
        }
    }
}






