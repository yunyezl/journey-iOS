//
//  FeedViewReactor.swift
//  Mohaeng
//
//  Created by 윤예지 on 2022/02/03.
//

import Foundation

import RxCocoa
import RxSwift
import ReactorKit

class FeedViewReactor: Reactor {
    
    enum WritingState: Int {
        case notYet = 0
        case done
        case impossible
    }
    
    enum Action {
        case refresh
        case loadNextPage
    }
    
    enum Mutation {
        case setFeed(FeedResponse, currentPage: Int, nextPage: Int?)
        case appendFeed(FeedResponse, currentPage: Int, nextPage: Int?)
        case setLoadingNextPage(Bool)
    }
    
    struct State {
        var writing: WritingState = .impossible
        var allFeed: [(contents: Feed, page: Int)] = []
        var nextPage: Int?
        var isLoadingNextPage: Bool = false
        var userCount: Int = 0
    }
    
    var initialState: State = State()
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .refresh:
            let observable = getFeed(page: 0)
            return observable.map { Mutation.setFeed($0, currentPage: $1, nextPage: $2) }
        case .loadNextPage:
            guard !self.currentState.isLoadingNextPage else { return Observable.empty() } // 중복 request 방지, 로딩 상태일 경우 request 하지 않음
            guard let page = self.currentState.nextPage else { return Observable.empty() } // 다음 페이지가 없을 경우(마지막 페이지인 경우) 요청하지 않음
            return Observable.concat([
                Observable.just(Mutation.setLoadingNextPage(true)),
                self.getFeed(page: page).map { Mutation.appendFeed($0, currentPage: $1, nextPage: $2) },
                Observable.just(Mutation.setLoadingNextPage(false))
            ])
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
        case let .setFeed(feedResponse, currentPage, nextPage):
            guard let hasFeed = feedResponse.hasFeed else { return State() }
            guard let userCount = feedResponse.userCount else { return State() }
            
            var newState = state
            newState.allFeed = feedResponse.feeds.map { ($0, currentPage) }
            newState.nextPage = nextPage
            newState.writing = WritingState.init(rawValue: hasFeed) ?? .impossible
            newState.userCount = userCount
            return newState
        case let .appendFeed(feedResponse, currentPage, nextPage):
            var newState = state
            newState.allFeed.append(contentsOf: feedResponse.feeds.map { ($0, currentPage) })
            newState.nextPage = nextPage
            newState.writing = WritingState.init(rawValue: feedResponse.hasFeed!) ?? .impossible
            return newState
        case let .setLoadingNextPage(isLoadingNextPage):
            var newState = state
            newState.isLoadingNextPage = isLoadingNextPage
            return newState
        }
    }
    
    private func getFeed(page: Int) -> Observable<(feed: FeedResponse,
                                                   currentPage: Int,
                                                   nextPage: Int?)> {
        let observable = Observable<(feed: FeedResponse,
                                     currentPage: Int,
                                     nextPage: Int?)>.create { observer -> Disposable in
            let requestReference: () = FeedAPI.shared.getFeed(page: page) { response in
                switch response {
                case .success(let data):
                    if let feed = data as? FeedResponse {
                        let nextPage = feed.feeds.isEmpty ? nil : page + 1
                        observer.onNext((feed, page, nextPage))
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
