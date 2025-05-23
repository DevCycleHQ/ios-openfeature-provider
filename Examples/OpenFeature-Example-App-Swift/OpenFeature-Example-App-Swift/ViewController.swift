//
//  ViewController.swift
//  DevCycle-Example-App
//
//

import DevCycle
import OpenFeature
import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var titleHeader: UILabel!
    @IBOutlet weak var loginButton: UIButton!

    var loggedIn: Bool = false
    var titleHeaderVar: String?
    var loginCtaVar: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let ofClient = OpenFeatureAPI.shared.getClient()

        self.loginCtaVar = ofClient.getStringValue(key: "login-cta-copy", defaultValue: "Log")
        self.titleHeaderVar = ofClient.getStringValue(
            key: "title-header-copy", defaultValue: "DevCycle iOS Example App")
        self.setTitleHeader()
        self.setLoginButtonTitle(false)
    }

    func setTitleHeader() {
        self.titleHeader.text = titleHeaderVar
    }

    func setLoginButtonTitle(_ bool: Bool) {
        self.loggedIn = bool
        self.loginButton.setTitle(
            "\(self.loginCtaVar ?? "") \(self.loggedIn ? "out" : "in")", for: .normal)
    }

    @IBAction func loginButtonPressed(_ sender: Any) {
        let ofClient = OpenFeatureAPI.shared.getClient()

        if self.loggedIn {
            Task {
                await OpenFeatureAPI.shared.setEvaluationContextAndWait(
                    evaluationContext: MutableContext(attributes: [:]))

                DispatchQueue.main.async {
                    self.setLoginButtonTitle(false)
                    print("Reset User!")
                }
            }
        } else {
            Task {
                let context = MutableContext(
                    targetingKey: "my-user1",
                    structure: MutableStructure(attributes: [
                        "email": .string("my-email@email.com"),
                        "country": .string("CA"),
                        "name": .string("Ash Ketchum"),
                        "language": .string("EN"),
                        "customData": .structure(["customkey": .string("customValue")]),
                        "privateCustomData": .structure([
                            "customkey2": .string("customValue2")
                        ]),
                    ])
                )
                await OpenFeatureAPI.shared.setEvaluationContextAndWait(evaluationContext: context)

                DispatchQueue.main.async {
                    self.setLoginButtonTitle(true)
                    print("Logged in as User: \(context.getTargetingKey())")

                    let variable = ofClient.getDoubleValue(key: "num_key", defaultValue: 0)
                    let variable2 = ofClient.getDoubleValue(
                        key: "num_key_defaulted", defaultValue: 0)

                    print("Num_key is: \(variable)")
                    print("Num_key_defaulted is: \(variable2)")
                }
            }
        }
    }

    @IBAction func track(_ sender: Any) {
        let dvcProvider = OpenFeatureManager.shared.provider
        let client = dvcProvider?.devcycleClient

        let event = try! DevCycleEvent.builder()
            .type("my_event")
            .target("my_target")
            .value(3)
            .metaData(["key": "value"])
            .clientDate(Date())
            .build()
        client?.track(event)
        print("Tracked event to DevCycle")
    }

    @IBAction func logAllFeatures(_ sender: Any) {
        let dvcProvider = OpenFeatureManager.shared.provider
        let client = dvcProvider?.devcycleClient
        print("All Features: \(String(describing: client?.allFeatures()))")
        print("All Variables: \(String(describing: client?.allVariables()))")
    }
}
