import Foundation
precondition(MobileSessionContract.usesGoAPI(URL(string: "https://api.burkeblack.tv/app/dashboard"), enabled: true))
precondition(!MobileSessionContract.usesGoAPI(URL(string: "https://api.burkeblack.tv/app/dashboard"), enabled: false))
for raw in ["http://api.burkeblack.tv/app/dashboard", "https://api.burkeblack.tv:444/app/dashboard", "https://example.test/app/dashboard", "https://api.twitch.tv/helix/users", "https://api.burkeblack.tv/other"] {
    precondition(!MobileSessionContract.usesGoAPI(URL(string: raw), enabled: true))
}
let nonce = try MobileSessionContract.nonce()
let secondNonce = try MobileSessionContract.nonce()
precondition(nonce.count == 64 && nonce != secondNonce)
let started = Date(timeIntervalSince1970: 1800000000)
let url = URL(string: "burkeblackapp://auth?state=\(nonce)&token=fixture&user_id=100&username=Fixture")!
let values = try MobileSessionContract.callback(url, nonce: nonce, started: started, now: started.addingTimeInterval(1))
precondition(values["token"] == "fixture")
for bad in ["burkeblackapp://auth?state=bad", "burkeblackapp://other?state=\(nonce)", "burkeblackapp://auth?state=\(nonce)&state=\(nonce)", "burkeblackapp://auth?state=\(nonce)#fragment", "https://auth?state=\(nonce)"] {
    do { _ = try MobileSessionContract.callback(URL(string: bad)!, nonce: nonce, started: started, now: started); fatalError("Invalid callback accepted") }
    catch MobileSessionContract.ContractError.invalidState {}
}
for date in [started.addingTimeInterval(-1), started.addingTimeInterval(600)] {
    do { _ = try MobileSessionContract.callback(url, nonce: nonce, started: started, now: date); fatalError("Expired callback accepted") }
    catch MobileSessionContract.ContractError.invalidState {}
}
print("Mobile session state contracts passed")
