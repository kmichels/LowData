import Foundation

@objc protocol LowDataHelperProtocol {
    func applyBlockingRules(_ rules: [[String: Any]], reply: @escaping (Bool, String?) -> Void)
    func removeAllBlockingRules(reply: @escaping (Bool, String?) -> Void)
    func getHelperVersion(reply: @escaping (String) -> Void)
}