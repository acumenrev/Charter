//
//  EmailThreadRequest.swift
//  Charter
//
//  Created by Matthew Palmer on 20/02/2016.
//  Copyright © 2016 Matthew Palmer. All rights reserved.
//

import Foundation
import Freddy
import RealmSwift

protocol NetworkingSession {
    func dataTaskWithRequest(request: NSURLRequest, completionHandler: (NSData?, NSURLResponse?, NSError?) -> Void) -> NSURLSessionDataTask
}

extension NSURLSession: NetworkingSession {}

class EmailThreadNetworkDataSourceImpl: EmailThreadNetworkDataSource {
    private let session: NetworkingSession
    private let username: String
    private let password: String
    
    required init(username: String? = nil, password: String? = nil, session: NetworkingSession = NSURLSession.sharedSession()) {
        self.session = session
        
        if let username = username, password = password {
            self.username = username
            self.password = password
        } else if username == nil || password == nil {
            let dictionary = NSDictionary(contentsOfURL: NSBundle.mainBundle().URLForResource("Credentials", withExtension: "plist")!)
            self.username = dictionary!["username"] as! String
            self.password = dictionary!["password"] as! String
        } else {
            fatalError("\(__FILE__): Username and password must be provided to a request. Ensure that a Credentials.plist file exists with `username` and `password` set.")
        }
    }
    
    func getThreads(request: EmailThreadRequest, completion: [NetworkEmail] -> Void) {
        let parameters = request.URLRequestQueryParameters
    
        // TODO: Get a domain name for the default back end, and make the URL more easily changed
        let URLComponents = NSURLComponents(string: "http://162.243.241.218.xip.io:8080/charter/emails")!
        URLComponents.queryItems = parameters.map { NSURLQueryItem(name: $0, value: $1) }
        
        let URLRequest = NSMutableURLRequest(URL: URLComponents.URL!)

        // TODO: Make HTTP basic auth reusable
        if let base64 = "\(username):\(password)"
            .dataUsingEncoding(NSUTF8StringEncoding)?
            .base64EncodedStringWithOptions([]) {
            URLRequest.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        }
        
        let task = session.dataTaskWithRequest(URLRequest) { (data, response, error) -> Void in
            guard let data = data else { return completion([]) }
            guard let json = try? JSON(data: data) else { return completion([]) }
            guard let emailList = try? json.array("_embedded", "rh:doc") else { return completion([]) }
            
            let threads = emailList.map { try? NetworkEmail.createFromJSON($0) }.flatMap { $0 }
            completion(threads)
        }
        
        task.resume()
    }
}