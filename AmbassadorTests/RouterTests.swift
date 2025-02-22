//
//  RouterTests.swift
//  Ambassador
//
//  Created by Fang-Pen Lin on 6/10/16.
//  Copyright © 2016 Fang-Pen Lin. All rights reserved.
//

import XCTest

import Ambassador

class RouterTests: XCTestCase {
    func testRouter() {
        let router = Router()
        router["/path/to/1"] = DataResponse() { environ -> Data in
            return Data("hello".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "404 Not found")
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/path/to/1",
        ]
        router.app(
            environ2,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 2)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 3)
        XCTAssertEqual(String(bytes: receivedData[1], encoding: String.Encoding.utf8), "hello")
        XCTAssertEqual(receivedData.last?.count, 0)
    }

    func testRegularExpressionRouting() {
        let router = Router()
        var receivedCaptures: [String]?
        let emailRoute = "/activate/email/([a-zA-Z0-9]+@[a-zA-Z0-9]+\\.[a-zA-Z0-9]+)" +
            "/code/([a-zA-Z0-9]+)"
        router[emailRoute] = DataResponse() { environ -> Data in
            receivedCaptures = environ["ambassador.router_captures"] as? [String]
            return Data("email".utf8)
        }

        var receivedStatus: [String] = []
        let startResponse = { (status: String, headers: [(String, String)]) in
            receivedStatus.append(status)
        }

        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            receivedData.append(data)
        }
        let environ: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/egg",
        ]
        router.app(
            environ,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 1)
        XCTAssertEqual(receivedStatus.last, "404 Not found")
        XCTAssertEqual(receivedData.count, 1)
        XCTAssertEqual(receivedData.last?.count, 0)

        let environ2: [String: Any] = [
            "REQUEST_METHOD": "GET",
            "SCRIPT_NAME": "",
            "PATH_INFO": "/activate/email/fang@envoy.com/code/ABCD1234",
        ]
        router.app(
            environ2,
            startResponse: startResponse,
            sendBody: sendBody
        )
        XCTAssertEqual(receivedStatus.count, 2)
        XCTAssertEqual(receivedStatus.last, "200 OK")
        XCTAssertEqual(receivedData.count, 3)
        XCTAssertEqual(String(bytes: receivedData[1], encoding: String.Encoding.utf8), "email")
        XCTAssertEqual(receivedData.last?.count, 0)
        XCTAssertEqual(receivedCaptures ?? [], ["fang@envoy.com", "ABCD1234"])
    }
    
    func testRouterWithSimilarEndpoints() {
        var receivedData: [Data] = []
        let sendBody = { (data: Data) in
            if !data.isEmpty {
                receivedData.append(data)
            }
        }
        
        let router = Router()
        
        router["foo/bar"] = DataResponse() { _ -> Data in
            return Data("hello".utf8)
        }
        router["foo/bar/ambassador/1/0\\?(?=.*param=\\d+)(?=.+&)(?=.*anotherParam=\\d+).*"] = DataResponse() { environ -> Data in//\\?(?=.*param=\\d+)(?=.+&)(?=.*anotherParam=\\d+).*
            return Data((environ["QUERY_STRING"] as? String ?? "world").utf8)
        }
        
        let environ: [String: Any] = ["REQUEST_METHOD": "GET",
                                      "SCRIPT_NAME": "",
                                      "PATH_INFO": "foo/bar"]
        
        let environ2: [String: Any] = ["REQUEST_METHOD": "GET",
                                       "SCRIPT_NAME": "",
                                       "PATH_INFO": "foo/bar/ambassador/1/0",
                                       "QUERY_STRING": "param=1&anotherParam=30"]

        router.app(environ, startResponse: { _, _ in }, sendBody: sendBody)
        XCTAssertEqual(String(bytes: receivedData.last!, encoding: String.Encoding.utf8), "hello")
        
        router.app(environ2, startResponse: { _, _ in }, sendBody: sendBody)
        XCTAssertEqual(String(bytes: receivedData.last!, encoding: String.Encoding.utf8), "param=1&anotherParam=30")
    }
}
