import UIKit
import Social
import MobileCoreServices
import SwiftUI
import NioKit

@objc(ShareNavigationController)
class ShareNavigationController: UIViewController {

    let store: AccountStore = AccountStore.init()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        let childView = UIHostingController(rootView: ShareContentView(parentView: self))
        addChild(childView)
        childView.view.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height)
        view.addSubview(childView.view)
        childView.didMove(toParent: self)
    }

    func didSelectPost(roomID: String) {
        let propertyList = String(kUTTypePropertyList)
        let rooms = store.rooms
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
            let itemProvider = item.attachments?.first,
            itemProvider.hasItemConformingToTypeIdentifier(propertyList) {
            itemProvider.loadItem(forTypeIdentifier: propertyList, options: nil) { (item, _) in
                guard let dictionary = item as? NSDictionary,
                    let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary,
                    let url = results["url"] as? String else {
                    return
                }
                for room in rooms where room.summary.roomId == roomID {
                    room.send(text: url)
                }
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }

    enum ShareViewControllerError: Error {
        case assertionError(description: String)
        case unsupportedMedia
        case notRegistered
        case obsoleteShare
    }

    func didSelectCancel() {
        self.dismiss(animated: true) {
            self.extensionContext!.cancelRequest(withError: ShareViewControllerError.obsoleteShare)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
