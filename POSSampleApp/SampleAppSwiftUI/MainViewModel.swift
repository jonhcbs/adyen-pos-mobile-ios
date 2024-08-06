//
//  MainViewModel.swift
//  SampleAppSwiftUI
//
//  See LICENSE folder for this sample’s licensing information.
//

import Foundation
import AdyenPOS
import TerminalAPIKit

class MainViewModel {
    
    /// Create an instance of PaymentService with the PaymentService(delegate:) initializer and pass the delegate object
    /// Make sure you keep a strong reference to the payment service instance so that it is retained for the duration of the transaction
    /// Also make sure your delegate is strongly referenced, because the PaymentService keeps a weak reference to the delegate
    lazy var paymentService = PaymentService(delegate: self)
    
    /// Initialize the transaction using the Adyen iOS SDK
    func initializeTransaction(
        paymentInterface: PaymentInterfaceType,
        presentationMode: TransactionPresentationMode
    ) async {
        do {
            /// Get the installationId from the payment service
            let installationId = try paymentService.installationId
            
            /// Generate a request using the installationId
            let request = generateRequest(installationId: installationId)
            
            /// Get the payment interface from the payment service
            let paymentInterface = try await paymentService.getPaymentInterface(with: paymentInterface)
            
            /// Perform the transaction using the generated request, payment interface, and view presentation mode
            let response = try await paymentService.performTransaction(
                with: Payment.Request(
                    data: Coder.encode(request)
                ),
                paymentInterface: paymentInterface,
                presentationMode: presentationMode
            )

            let str = String(decoding: response, as: UTF8.self)

            /// Use the Terminal API response
            print(str)
        }
        catch {
            print(error)
        }
    }
    
    /// Initialize the POS SDK
    @Sendable
    func initializePOSSDK() async {
        /// Set the `DeviceManagerDelegate` delegate if you want to use your own implementation of NYC1 device management
        paymentService.deviceManager.delegate = self
        
        /// To speed up initiating transactions, you can use the warm-up function
        /// This function checks for a session and any configuration changes, and prepares the proximity reader on the iPhone
        try? await paymentService.warmUp()
    }
    
    
    /// Generate a Terminal API request, in this example we are generating a PaymentRequest
    func generateRequest(installationId: String) -> Message<PaymentRequest> {
        
        let header: MessageHeader = .init(
            protocolVersion: "3.0",
            messageClass: .service,
            messageCategory: .payment,
            messageType: .request,
            serviceIdentifier: String(UUID().uuidString.prefix(6)),
            saleIdentifier: UUID().uuidString,
            poiIdentifier: installationId
        )
        
        let paymentRequest: PaymentRequest = .init(
            saleData: .init(
                saleTransactionIdentifier: .init(
                    transactionIdentifier: UUID().uuidString,
                    date: .init()
                ),
                saleToAcquirerData: "ewogICAgIm1ldGFkYXRhIjogewogICAgICAgICJlbXBsb3llZU51bWJlciI6ICIxIiwKICAgICAgICAidGVzdCI6ICIxMjMiLAogICAgICAgICJ0ZXN0MSI6ICJ0ZXN0MSIsCiAgICAgICAgInRlc3QyIjogInRlc3QyIgogICAgfQp9"
            ),
            paymentTransaction: .init(
                amounts: .init(
                    currency: "USD",
                    requestedAmount: 101
                )
            )
        )
        
        return Message(header: header, body: paymentRequest)
    }
}

struct SessionsResponse: Decodable {
    let sdkData: String
}

extension MainViewModel: PaymentServiceDelegate {
    func register(with setupToken: String) async throws -> String {
        /// Make a call to your backend to trigger a `/sessions` request, supplying the provided `setupToken`
        /// You should not call the `/sessions` endpoint from the POS app, only from your backend
        guard let url = URL(string: "https://checkout-test.adyen.com/checkout/possdk/v68/sessions") else { return "" }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("AQEmgXvdQM2NG2Yd7nqxnH12hOyUX4lYHpl5KF7hmrINRg8pw2A4qiYQwV1bDb7kfNy1WIxIIkxgBw==-8cCb3ZX9krRCTIAzJlvKwSs9F6Ydl61Ju6hmUv4qles=-i1iV$_jj9MHAI4_&XJv", forHTTPHeaderField: "X-API-Key")
        request.httpMethod = "POST"
        let parameters: [String: Any] = [
            "merchantAccount" : "ChowbusUS",
            "setupToken":setupToken,
            "store": "r10538"
        ]
        
        do {
          // convert parameters to Data and assign dictionary to httpBody of request
          request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch let error {
          print(error.localizedDescription)
          return ""
        }


        let (data, _) = try await URLSession.shared.data(for: request)
//        let mockRsp =
//"""
//{
//    "id": "df564a4b-2d1b-4555-baa7-b903476e9a22",
//    "installationId": "BFCBF842-02DF-4D7F-AAED-F6535BFB5D48.352",
//    "merchantAccount": "Lightspeed980POS",
//    "sdkData": "eyJlbnZBdHRlc3Rwb3MiOiJhdHRlc3Rwb3MtdGVzdCIsImVudkNoZWNrb3V0cG9zIjoiY2hlY2tvdXRwb3MtdGVzdCIsImVudmlyb25tZW50IjoiY2hlY2tvdXRwb3MtdGVzdCIsImV4cGlyZXNBdCI6MTcyMjQ5Njg5OCwic2Vzc2lvblRva2VuIjoiZXlKaGJHY2lPaUpRVXpJMU5pSXNJbU5ySWpvaWRHVnpkRjgzVVV4UVdWUk1SRFJDUjFoVVRFZExXbFJLVmxNeVdrMU1UVVpKTmxCVU55SjkuZXlKaVlXTnJaVzVrVUhWaWJHbGpTMlY1SWpwN0ltTnlkaUk2SWxBdE1qVTJJaXdpYTNSNUlqb2lSVU1pTENKNElqb2laR1JsV0VwR1VFMVlNbUp1Ym1oYWEzRnBPRzlZYzFOQmFGWjZaazk2Tm0xaExYaDRVVU4yY0dseWR6MGlMQ0o1SWpvaVdVWkVaVlEzTnpOaVpIVm1RMnhGYlhBd2NHeHJabG95WTB0VFNHZG5aR2hEZDNCMVozRmhTSEF6TkQwaWZTd2lZblZ1Wkd4bFNXUWlPaUpqYjIwdVlXUjVaVzR1YzJGdGNHeGxMbUZ3Y0M1emQybG1kSFZwTGxOaGJYQnNaVUZ3Y0ZOM2FXWjBWVWtpTENKbGVIQnBjbVZ6UVhRaU9qRTNNakkwT1RZNE9UZ3NJbWx1YzNSaGJHeGhkR2x2Ymtsa0lqb2lRa1pEUWtZNE5ESXRNREpFUmkwMFJEZEdMVUZCUlVRdFJqWTFNelZDUmtJMVJEUTRMak0xTWlJc0ltMWxjbU5vWVc1MFFXTmpiM1Z1ZENJNklreHBaMmgwYzNCbFpXUTVPREJRVDFNaUxDSndkV0pzYVdOTFpYa2lPbnNpWTNKMklqb2lVQzB5TlRZaUxDSnJkSGtpT2lKRlF5SXNJbmdpT2lKUVJXMURWamRYVGtWUU1EaE9kbEJmYlROVmVUQXRNV1F4YlZGT1lXMTNOMjVKZVRCbVMzQnlRbXRSSWl3aWVTSTZJbVV6ZUdsa1JHVmZUMkkzTm1oeVZWRTRXbWxaYVdGVFJFcEVVMll4YmxCT1VpMU9WSEJSY21OS2VFMGlmU3dpYzNSdmNtVWlPaUpUVkRNeVEwMUxNakl6TWpJM056Vk1ORGhITkZNMFZrUklJbjAuamEzVTlydERZWVYwRkpEa01kaUI0RkladWFCcE90U3NGbGduSlY1UlMteXczQkJHSjZxQmZSV3cyNzBuM05fSnJmYmRXRkpFeW5Dc29UQkNjSUJJeGNYdndXSnI2VFJaVHo2bGlJYUlJalpiUXRjazl0bUJxcllGUnNwOWxDVEpvMmpNZUYzeTcwQ180VGNYWDc3RFBUdklncnhUU2tvbkxvMFJ2OHZBaTdJQWIzS2tVblo3aTQ5V2lRNDNpY2VBeFliQ2xIYkNTOUVSOVdUTHZFM082WEd6djhDT21oZUxaZ1ZvZE1lMGNEdnZMa2JXTnFOeDRhTTk3a0x0d29YaWtndTMtQThWUWxrUWJlcEQzR3BmWVZxN25DQlFzc0tJU1U5ZWhoS05pOU50RFpZdXBBYkRtY2hmaTBTTVBWQkdSQmRuT2FOemZndWpQQ0JoU2lDYmlnIn0=",
//    "store": "ST32CMK22322775L48G4S4VDH"
//}
//"""
//        let mockData = mockRsp.data(using: .utf8)
        let response = try JSONDecoder().decode(SessionsResponse.self, from: data)
        return response.sdkData
    }
}
/// Conforming to protocol "DeviceManagerDelegate" is only necessary when implementing NYC1 device management from scratch, and not when using our pre-built "DeviceManagementView" component (or when using it in conjunction with your own implementation)
extension MainViewModel: DeviceManagerDelegate {
    
    func onDeviceDiscovered(device: AdyenPOS.Device, by manager: DeviceManager) { }
    
    func onDeviceDiscoveryFailed(with error: Error, by manager: DeviceManager) { }
    
    func onDeviceConnected(with error: Error?, to manager: DeviceManager) { }
    
    func onDeviceDisconnected(from manager: DeviceManager) { }
}
