//
//  Request.swift
//  Cory D. Wiles
//
//  Created by Cory D. Wiles on 9/11/14.
//  Copyright (c) 2014 Theo. All rights reserved.
//

import Foundation

typealias RequestSuccessBlock = (_ data: Data?, _ response: URLResponse) -> Void
typealias RequestErrorBlock   = (_ error: NSError, _ response: URLResponse) -> Void

let TheoNetworkErrorDomain: String  = "com.theo.network.error"
let TheoAuthorizationHeader: String = "Authorization"

public struct AllowedHTTPMethods {
  
    static var GET: String    = "GET"
    static var PUT: String    = "PUT"
    static var POST: String   = "POST"
    static var DELETE: String = "DELETE"
}

class Request {
  
    // MARK: Lazy properties

    lazy var httpSession: Session = {

        Session.SessionParams.queue = OperationQueue.main

        return Session.sharedInstance;
    }()
  
    lazy var sessionConfiguration: URLSessionConfiguration = {
        return self.httpSession.configuration.sessionConfiguration
    }()
  
    lazy var sessionHTTPAdditionalHeaders: [AnyHashable: Any]? = {
        return self.sessionConfiguration.httpAdditionalHeaders
    }()
  
    let sessionURL: URL
    
    // MARK: Private properties

    fileprivate var httpRequest: URLRequest
    
    fileprivate var userCredentials: (username: String, password: String)?

    // MARK: Constructors
    
    /// Designated initializer
    ///
    /// - parameter NSURL: url
    /// - parameter NSURLCredential?: credentials
    /// - parameter Array<String,String>?: additionalHeaders
    /// - returns: Request
    required init(url: URL, credentials: (username: String, password: String)?, additionalHeaders:[String:String]?) {

        self.sessionURL  = url
        self.httpRequest = URLRequest(url: self.sessionURL)
    
        // If the additional headers aren't nil then we have to fake a mutable 
        // copy of the sessionHTTPAdditionsalHeaders (they are immutable), add 
        // out new ones and then set the values again

        if additionalHeaders != nil {

            var newHeaders: [String:String] = [:]

            if let sessionConfigurationHeaders = self.sessionHTTPAdditionalHeaders as? [String:String] {
      
                for (origininalHeader, originalValue) in sessionConfigurationHeaders {
                    newHeaders[origininalHeader] = originalValue
                }
        
                for (header, value) in additionalHeaders! {
                    newHeaders[header] = value
                }
            }
      
            self.sessionConfiguration.httpAdditionalHeaders = newHeaders as [AnyHashable: Any]?
      
        } else {
      
           // self.sessionURL = url
        }
        
        // More than likely your instance of Neo4j will require a username/pass.
        // If the credentials param is set the the storage and protection space 
        // are set and passed to the configuration. This is set for all session
        // requests. This _might_ change in the future by utililizng the delegate
        // methods so that you can set whether or not requests should handle auth
        // at a session or task level.

        self.userCredentials = credentials
    }
  
    /// Convenience initializer
    ///
    /// The additionalHeaders property is set to nil
    ///
    /// - parameter NSURL: url
    /// - parameter NSURLCredential?: credentials
    /// - returns: Request

    convenience init(url: URL, credentials: (username: String, password: String)?) {
        self.init(url: url, credentials: credentials, additionalHeaders: nil)
    }
    
    /// Convenience initializer
    ///
    /// The additionalHeaders and credentials properties are set to nil
    ///
    /// - parameter NSURL: url
    /// - returns: Request
    
    convenience init() {
        self.init(url: URL(string: "this will fail")!, credentials: (username: String(), password: String()), additionalHeaders: nil)
    }
  
    // MARK: Public Methods

    /// Method makes a HTTP GET request
    ///
    /// - parameter RequestSuccessBlock: successBlock
    /// - parameter RequestErrorBlock: errorBlock
    /// - returns: Void
    func getResource(_ successBlock: RequestSuccessBlock?, errorBlock: RequestErrorBlock?) -> Void {

        let request: URLRequest = {
      
            let mutableRequest: NSMutableURLRequest = (self.httpRequest as NSURLRequest).mutableCopy() as! NSMutableURLRequest
      
            mutableRequest.httpMethod = AllowedHTTPMethods.GET
            
            if let userCreds = self.userCredentials {
                
                let userAuthString: String = self.basicAuthString(userCreds.username, password: userCreds.password)
                
                mutableRequest.setValue(userAuthString, forHTTPHeaderField: TheoAuthorizationHeader)
            }
      
            return mutableRequest.copy() as! URLRequest
        }()

        let task : URLSessionDataTask = self.httpSession.session.dataTask(with: request, completionHandler: {(data: Data?, response: URLResponse?, error: NSError?) -> Void in
      
            var dataResp: Data? = data
            let httpResponse: HTTPURLResponse = response as! HTTPURLResponse
            let statusCode: Int = httpResponse.statusCode
            let containsStatusCode:Bool = Request.acceptableStatusCodes().contains(statusCode)

            if !containsStatusCode {
                dataResp = nil
            }
      
            /// Process Success Block
            
            successBlock?(dataResp, httpResponse)
    
            /// Process Error Block
            
            if let errorCallBack = errorBlock {
                
                if let error = error {
                    
                    errorCallBack(error, httpResponse)
                    return
                }
                
                if !containsStatusCode {
                    
                    let localizedErrorString: String = "There was an error processing the request"
                    let errorDictionary: [String:String] = ["NSLocalizedDescriptionKey" : localizedErrorString, "TheoResponseCode" : "\(statusCode)", "TheoResponse" : response!.description]
                    let requestResponseError: NSError = {
                        return NSError(domain: TheoNetworkErrorDomain, code: NSURLErrorUnknown, userInfo: errorDictionary)
                    }()
                    
                    errorCallBack(requestResponseError, httpResponse)
                }
            }

        } as! (Data?, URLResponse?, Error?) -> Void)
    
        task.resume()
    }

    /// Method makes a HTTP POST request
    ///
    /// - parameter RequestSuccessBlock: successBlock
    /// - parameter RequestErrorBlock: errorBlock
    /// - returns: Void
    func postResource(_ postData: AnyObject, forUpdate: Bool, successBlock: RequestSuccessBlock?, errorBlock: RequestErrorBlock?) -> Void {
        
        let request: URLRequest = {

            let mutableRequest: NSMutableURLRequest = (self.httpRequest as NSURLRequest).mutableCopy() as! NSMutableURLRequest
            let transformedJSONData: Data = try! JSONSerialization.data(withJSONObject: postData, options: [])
            
            mutableRequest.httpMethod = forUpdate == true ? AllowedHTTPMethods.PUT : AllowedHTTPMethods.POST
            mutableRequest.httpBody   = transformedJSONData
            
            if let userCreds = self.userCredentials {
                
                let userAuthString: String = self.basicAuthString(userCreds.username, password: userCreds.password)
                
                mutableRequest.setValue(userAuthString, forHTTPHeaderField: TheoAuthorizationHeader)
            }
            
            return mutableRequest.copy() as! URLRequest
        }()
        
        let task : URLSessionDataTask = self.httpSession.session.dataTask(with: request, completionHandler: {(data: Data?, response: URLResponse?, error: NSError?) -> Void in
            
            var dataResp: Data? = data
            let httpResponse: HTTPURLResponse = response as! HTTPURLResponse
            let statusCode: Int = httpResponse.statusCode
            let containsStatusCode:Bool = Request.acceptableStatusCodes().contains(statusCode)
            
            if !containsStatusCode {
                dataResp = nil
            }

            /// Process Success Block
            
            successBlock?(dataResp, httpResponse)
            
            /// Process Error Block
            
            if let errorCallBack = errorBlock {
                
                if let error = error {
                    
                    errorCallBack(error, httpResponse)
                    return
                }
                
                if !containsStatusCode {
                    
                    let localizedErrorString: String = "There was an error processing the request"
                    let errorDictionary: [String:String] = ["NSLocalizedDescriptionKey" : localizedErrorString, "TheoResponseCode" : "\(statusCode)", "TheoResponse" : response!.description]
                    let requestResponseError: NSError = {
                        return NSError(domain: TheoNetworkErrorDomain, code: NSURLErrorUnknown, userInfo: errorDictionary)
                    }()
                    
                    errorCallBack(requestResponseError, httpResponse)
                }
            }
        } as! (Data?, URLResponse?, Error?) -> Void)
        
        task.resume()
    }
    
    /// Method makes a HTTP DELETE request
    ///
    /// - parameter RequestSuccessBlock: successBlock
    /// - parameter RequestErrorBlock: errorBlock
    /// - returns: Void
    func deleteResource(_ successBlock: RequestSuccessBlock?, errorBlock: RequestErrorBlock?) -> Void {
    
        let request: URLRequest = {
            
            let mutableRequest: NSMutableURLRequest = (self.httpRequest as NSURLRequest).mutableCopy() as! NSMutableURLRequest
            
            mutableRequest.httpMethod = AllowedHTTPMethods.DELETE
        
            if let userCreds = self.userCredentials {
                
                let userAuthString: String = self.basicAuthString(userCreds.username, password: userCreds.password)
                
                mutableRequest.setValue(userAuthString, forHTTPHeaderField: TheoAuthorizationHeader)
            }
            
            return mutableRequest.copy() as! URLRequest
        }()
        
        self.httpRequest = request
        
        let task : URLSessionDataTask = self.httpSession.session.dataTask(with: self.httpRequest, completionHandler: {(data: Data?, response: URLResponse?, error: NSError?) -> Void in
            
            var dataResp: Data? = data
            let httpResponse: HTTPURLResponse = response as! HTTPURLResponse
            let statusCode: Int = httpResponse.statusCode
            let containsStatusCode:Bool = Request.acceptableStatusCodes().contains(statusCode)
            
            if !containsStatusCode {
                dataResp = nil
            }

            /// Process Success Block
            
            successBlock?(dataResp, httpResponse)
            
            /// Process Error Block
            
            if let errorCallBack = errorBlock {
                
                if let error = error {
                    
                    errorCallBack(error, httpResponse)
                    return
                }
                
                if !containsStatusCode {
                    
                    let localizedErrorString: String = "There was an error processing the request"
                    let errorDictionary: [String:String] = ["NSLocalizedDescriptionKey" : localizedErrorString, "TheoResponseCode" : "\(statusCode)", "TheoResponse" : response!.description]
                    let requestResponseError: NSError = {
                        return NSError(domain: TheoNetworkErrorDomain, code: NSURLErrorUnknown, userInfo: errorDictionary)
                    }()
                    
                    errorCallBack(requestResponseError, httpResponse)
                }
            }
        } as! (Data?, URLResponse?, Error?) -> Void)
        
        task.resume()
    }
  
    /// Defines and range of acceptable HTTP response codes. 200 thru 300 inclusive
    ///
    /// - returns: NSIndexSet
    class func acceptableStatusCodes() -> IndexSet {
    
        let nsRange = NSMakeRange(200, 100)
    
        return IndexSet(integersIn: nsRange.toRange() ?? 0..<0)
    }
    
    // MARK: Private Methods
    
    /// Creates the base64 encoded string used for basic authorization
    ///
    /// - parameter String: username
    /// - parameter String: password
    /// - returns: String
    fileprivate func basicAuthString(_ username: String, password: String) -> String {
    
        let loginString = NSString(format: "%@:%@", username, password)
        let loginData: Data = loginString.data(using: String.Encoding.utf8.rawValue)!
        let base64LoginString = loginData.base64EncodedString(options: [])
        let authString = "Basic \(base64LoginString)"

        return authString
    }
}
