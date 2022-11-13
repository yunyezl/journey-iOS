//
//  Rx+stickerButtonProtocol.swift
//  Mohaeng
//
//  Created by 윤예지 on 2022/04/29.
//

import Foundation

import RxCocoa
import RxSwift

class RxFeedDetailTableViewCellDelegateProxy: DelegateProxy<FeedDetailTableViewCell, StickerButtonProtocol>, DelegateProxyType, StickerButtonProtocol {
    
    static func registerKnownImplementations() {
        self.register { button in
            RxFeedDetailTableViewCellDelegateProxy(parentObject: button,
                                                   delegateProxy: self)
        }
    }
    
    static func currentDelegate(for object: FeedDetailTableViewCell) -> StickerButtonProtocol? {
        return object.stickerDelegate
    }
    
    static func setCurrentDelegate(_ delegate: StickerButtonProtocol?, to object: FeedDetailTableViewCell) {
        object.stickerDelegate = delegate
    }
        
}

extension Reactive where Base: FeedDetailTableViewCell {
    var delegate: DelegateProxy<FeedDetailTableViewCell, StickerButtonProtocol> {
        return RxFeedDetailTableViewCellDelegateProxy.proxy(for: self.base)
    }

    var stickerButtonTap: Observable<Int> {
        return delegate
            .methodInvoked(#selector(StickerButtonProtocol.touchStickerButton))
            .map({ parameters in
                return parameters[1] as? Int ?? 0
            })
    }
}
