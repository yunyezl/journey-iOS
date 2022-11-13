//
//  FeedDetailReactor.swift
//  Mohaeng
//
//  Created by 윤예지 on 2022/04/28.
//

import Foundation

import RxCocoa
import RxSwift
import ReactorKit

class FeedDetailReactor: Reactor {
    
    enum Action {
        case loadPreviousPage
        case loadCurrentPage
        case loadNextPage
    }
    
    enum Mutation {
        case setFeed([Feed], previousPage: Int?, currentPage: Int, nextPage: Int?)
        case insertFeed([Feed], previousPage: Int?, currentPage: Int, nextPage: Int?)
        case appendFeed([Feed], previousPage: Int?, currentPage: Int, nextPage: Int?)
        case setLoadingPage(Bool)
    }
                        
    struct State {
        var allFeed: [Feed]
        var previousPage: Int?
        var currentPage: Int
        var nextPage: Int?
        var isLoadingPage: Bool
    }
    
    var initialState: State
    private var stickerRepository = StickerMemoryRepository()
    
    init(feeds: [Feed], page: Int) {
        self.initialState = State(allFeed: feeds,
                                  previousPage: page == 0 ? nil : page - 1,
                                  currentPage: page,
                                  nextPage: page + 1,
                                  isLoadingPage: false)
//        print(feeds)
        for feed in feeds {
            stickerRepository.save(postId: feed.postID, emojis: feed.emoji)
            if feed.myEmoji != 0 {
                stickerRepository.saveMyEmoji(postId: feed.postID, emojiId: feed.myEmoji)
            }
        }
//        print(stickerRepository.fetchAll())
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .loadPreviousPage:
            guard !self.currentState.isLoadingPage else { return Observable.empty() }
            guard let page = self.currentState.previousPage else { return Observable.empty() }
            return Observable.concat([
                Observable.just(Mutation
                                    .setLoadingPage(true)),
                self.getFeed(currentPage: page).map {
                    Mutation.insertFeed($0.feed, previousPage: $0.previousPage, currentPage: $0.currentPage, nextPage: $0.nextPage)
                },
                Observable.just(Mutation
                                    .setLoadingPage(false))
            ])
        case .loadCurrentPage:
            let observable = getFeed(currentPage: self.currentState.currentPage)
            return observable.map {
                Mutation.setFeed($0.feed, previousPage: $0.previousPage, currentPage: $0.currentPage, nextPage: $0.nextPage)
            }
        case .loadNextPage:
            guard !self.currentState.isLoadingPage else { return Observable.empty() }
            guard let page = self.currentState.nextPage else { return Observable.empty() }
            return Observable.concat([
                Observable.just(Mutation
                                    .setLoadingPage(true)),
                self.getFeed(currentPage: page).map {
                    Mutation.appendFeed($0.feed, previousPage: $0.previousPage, currentPage: $0.currentPage, nextPage: $0.nextPage)
                },
                Observable.just(Mutation
                                    .setLoadingPage(false))
            ])
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
        case let .setFeed(feed, previousPage, currentPage, nextPage):
            var newState = state
            newState.allFeed = feed
            newState.previousPage = previousPage
            newState.currentPage = currentPage
            newState.nextPage = nextPage
            return newState
        case let .insertFeed(feed, previousPage, currentPage, nextPage):
            var newState = state
            newState.allFeed.insert(contentsOf: feed, at: 0)
            newState.previousPage = previousPage
            newState.currentPage = currentPage
            newState.nextPage = nextPage
            return newState
        case let .appendFeed(feed, previousPage, currentPage, nextPage):
            var newState = state
            newState.allFeed.append(contentsOf: feed)
            newState.previousPage = previousPage
            newState.currentPage = currentPage
            newState.nextPage = nextPage
            for feed in newState.allFeed {
                stickerRepository.save(postId: feed.postID, emojis: feed.emoji)
            }
            return newState
        case let .setLoadingPage(isLoadingPage):
            var newState = state
            newState.isLoadingPage = isLoadingPage
            return newState
        }
    }
    
    private func getFeed(currentPage: Int) -> Observable<DetailInfo> {
        let observable = Observable<DetailInfo>.create { observer -> Disposable in
            let requestReference: () = FeedAPI.shared.getFeed(page: currentPage) { response in
                switch response {
                case .success(let data):
                    if let feed = data as? FeedResponse {
                        let previousPage = currentPage == 0 ? nil : currentPage - 1
                        let nextPage = feed.feeds.isEmpty ? nil : currentPage + 1
                        observer.onNext(DetailInfo(feed: feed.feeds,
                                                   previousPage: previousPage,
                                                   currentPage: currentPage,
                                                   nextPage: nextPage))
                        observer.onCompleted()
                    }
                case .requestErr(let message):
                    print("requestErr", message)
                case .pathErr:
                    print("pathErr")
                case .serverErr:
                    print("serverErr")
                case .networkFail:
                    print("networkFail")
                }
            }
            return Disposables.create(with: { requestReference })
        }
        return observable
    }
}

struct DetailInfo {
    var feed: [Feed]
    var previousPage: Int?
    var currentPage: Int
    var nextPage: Int?
}
