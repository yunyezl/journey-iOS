//
//  FeedDetail2ViewController.swift
//  Mohaeng
//
//  Created by 윤예지 on 2022/04/28.
//

import UIKit

import ReactorKit
import RxCocoa

class FeedDetail2ViewController: BaseFeedDetailViewController, View {

    var disposeBag = DisposeBag()
    
    init(reactor: FeedDetailReactor, initialRow: Int) {
        super.init(nibName: nil, bundle: nil)
        self.reactor = reactor
        scrollToSelectedItem(row: initialRow)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setNavigationTitle()
    }
    
    override func viewDidLayoutSubviews() {
        tableView.endUpdates()
    }
    
    func bind(reactor: FeedDetailReactor) {
        registerCell()
        
        reactor.state
            .map { $0.allFeed }
            .bind(to: tableView.rx.items(cellIdentifier: Const.Xib.Identifier.feedDetailTableViewCell)) { _, feed, cell in
                guard let cell = cell as? FeedDetailTableViewCell else { return }
                cell.setData(feed: feed, viewController: .community)
                cell.selectionStyle = .none
                cell.disposeBag = DisposeBag()
                cell.rx.stickerButtonTap
                    .subscribe(onNext: { [weak self] postId in
                        guard let self = self else { return }
                        self.presentStickerViewController(with: postId)
                    })
                    .disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
        
        tableView.rx.contentOffset
            .withUnretained(self)
            .filter { owner, offset in
                guard self.tableView.frame.height > 0 else { return false }
                return offset.y + owner.tableView.frame.height >= owner.tableView.contentSize.height - 100
            }
            .map { _ in Reactor.Action.loadNextPage }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
    
    }
    
    private func setNavigationTitle() {
        navigationItem.title = "피드 둘러보기"
    }
    
    private func scrollToSelectedItem(row: Int) {
        tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .top, animated: false)
    }
    
    private func presentStickerViewController(with postId: Int) {
        let storyboard = UIStoryboard(name: Const.Storyboard.Name.sticker, bundle: nil)
        guard let stickerViewController = storyboard.instantiateViewController(identifier: Const.ViewController.Identifier.sticker) as? StickerViewController else { return }
        stickerViewController.modalPresentationStyle = .overCurrentContext
        stickerViewController.modalTransitionStyle = .crossDissolve
        stickerViewController.postId = postId
        self.tabBarController?.present(stickerViewController, animated: false, completion: nil)
    }
    
}
