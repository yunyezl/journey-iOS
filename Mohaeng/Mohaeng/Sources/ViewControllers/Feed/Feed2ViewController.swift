//
//  Feed2ViewController.swift
//  Mohaeng
//
//  Created by 윤예지 on 2022/02/03.
//

import UIKit

import SnapKit
import Then
import RxSwift
import RxCocoa
import ReactorKit

class Feed2ViewController: UIViewController, View {

    // MARK: - Constant
    
    struct Text {
        static let myDrawer = "내 서랍장"
        static let donePopUpTitle = "오늘의 안부 작성 완료!"
        static let donePopUpDescription = "안부는 하루에 한 번만 작성할 수 있어.\n내일 챌린지를 인증하고 찾아와줘~"
        static let impossiblePopUpTitle = "선 챌린지, 후 안부!"
        static let impossiblePopUpDescription = "이런, 아직 오늘의 챌린지 안했지?!\n오늘의 챌린지를 인증해야 작성할 수 있어"
        static let defaultTitle = "오늘 하루는 어때?\n네 안부가 궁금해!"
    }
    
    struct Metric {
        static let screenWidth = UIScreen.main.bounds.width
        static let screenHeight = UIScreen.main.bounds.height
        static let figmaWidth: CGFloat = 375
        static let figmaHeight: CGFloat = 812
        static let headerHeight: CGFloat = (178 / figmaHeight) * screenHeight
        static let cellHeight: CGFloat = 144
        static let roundedViewPositionY: CGFloat = (20 / figmaHeight) * screenHeight
    }
    
    // MARK: - Properties
    
    var disposeBag = DisposeBag()
    
    // MARK: - UI Properties
    
    private let headerTitleLabel = UILabel().then {
        $0.font = .gmarketFont(weight: .medium, size: 18)
        $0.textColor = .Black
        $0.numberOfLines = 2
    }
    
    private let headerGraphicImageView = UIImageView().then {
        $0.image = Const.Image.feedGraphic
    }
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: Metric.screenWidth,
                                 height: Metric.screenWidth * (Metric.cellHeight / Metric.figmaWidth))
        layout.minimumLineSpacing = .zero
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.contentInset = UIEdgeInsets(top: Metric.headerHeight,
                                                   left: 0, bottom: 0, right: 0)
        return collectionView
    }()
    
    private let myDrawerButton = UIButton().then {
        $0.setTitle(Text.myDrawer, for: .normal)
        $0.titleLabel?.font = UIFont.spoqaHanSansNeo(weight: .regular, size: 13)
        $0.setTitleColor(.GreyIconGnb, for: .normal)
    }
    
    private let writingButton = UIButton().then {
        $0.setImage(Const.Image.writingImage, for: .normal)
    }
    
    private let refreshControl = UIRefreshControl()
    
    private let backgroundView = UIView()
    
    private let roundedView = UIView()
    
    // MARK: - Initialize
    
    init(reactor: FeedViewReactor) {
        super.init(nibName: nil, bundle: nil)
        self.reactor = reactor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        registerXib()
        setupConstraints()
        collectionView.refreshControl = refreshControl
    }
    
    override func viewWillAppear(_ animated: Bool) {
        initNaivgationBar()
    }
    
    override func viewDidLayoutSubviews() {
        setupBackgroundView()
    }
    
    // MARK: - Functions
    
    func bind(reactor: FeedViewReactor) {
        
        // Action (View -> Action)
        
        rx.viewDidLoad
            .map { Reactor.Action.refresh }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        collectionView.rx.contentOffset
            .withUnretained(self)
            .filter { owner, offset in
                guard self.collectionView.frame.height > 0 else { return false }
                return offset.y + owner.collectionView.frame.height >= owner.collectionView.contentSize.height - 100
            }
            .map { _ in Reactor.Action.loadNextPage }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        collectionView.rx.contentOffset
            .withUnretained(self)
            .subscribe { owner, _ in
                owner.changeHeaderViewOpacity()
            }.disposed(by: disposeBag)
        
        refreshControl.rx.controlEvent(.valueChanged)
            .map { Reactor.Action.refresh }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // State
        
        reactor.state
            .map { $0.allFeed }
            .bind(to: collectionView.rx.items(cellIdentifier: Const.Xib.Identifier.feedCollectionViewCell)) { _, feed, cell in
                guard let cell = cell as? FeedCollectionViewCell else { return }
                cell.setData(data: feed.contents)
            }
            .disposed(by: disposeBag)
                
        reactor.state
            .map { $0.userCount >= 10 ? "오늘은 \($0.userCount)개의\n안부가 남겨졌어" : Text.defaultTitle }
            .bind(to: headerTitleLabel.rx.text)
            .disposed(by: disposeBag)
        
        // View
        
        myDrawerButton.rx.tap
            .subscribe(onNext: {
                let myDrawerStoryboard = UIStoryboard(name: Const.Storyboard.Name.myDrawer, bundle: nil)
                guard let myDrawerViewController = myDrawerStoryboard.instantiateViewController(identifier: Const.ViewController.Identifier.myDrawer) as? MyDrawerViewController else { return }
                
                self.navigationController?.pushViewController(myDrawerViewController, animated: true)
            })
            .disposed(by: disposeBag)
        
        writingButton.rx.tap
            .withUnretained(self)
            .subscribe(onNext: { owner, _ in
                switch reactor.currentState.writing {
                case .done:
                    owner.presentWarningPopUp(title: Text.donePopUpTitle,
                                              description: Text.donePopUpDescription)
                case .notYet:
                    let moodStoryboard = UIStoryboard(name: Const.Storyboard.Name.mood, bundle: nil)
                    guard let moodViewController = moodStoryboard.instantiateViewController(identifier: Const.ViewController.Identifier.mood) as? MoodViewController else { return }
                    let navigationController = UINavigationController(rootViewController: moodViewController)
                    navigationController.modalPresentationStyle = .fullScreen
                    self.present(navigationController, animated: true, completion: nil)
                case .impossible:
                    owner.presentWarningPopUp(title: Text.impossiblePopUpTitle,
                                             description: Text.impossiblePopUpDescription)
                }
            })
            .disposed(by: disposeBag)
        
        collectionView.rx.itemSelected
            .map { $0.row }
            .bind {
                let feedDetailViewController = FeedDetail2ViewController(reactor: FeedDetailReactor(feeds: reactor.currentState.allFeed.map { $0.contents }, page: reactor.currentState.allFeed[$0].page), initialRow: $0)
                self.navigationController?.pushViewController(feedDetailViewController, animated: true)
            }
            .disposed(by: disposeBag)
        
        refreshControl.rx.controlEvent(.valueChanged)
            .subscribe(onNext: {
                self.refreshControl.endRefreshing()
            })
            .disposed(by: disposeBag)
    }
    
    private func initNaivgationBar() {
        self.navigationController?.isNavigationBarHidden = true
    }
    
    private func registerXib() {
        collectionView.register(UINib(nibName: Const.Xib.Name.feedCollectionViewCell,
                                      bundle: nil),
                                forCellWithReuseIdentifier: Const.Xib.Identifier.feedCollectionViewCell)
    }
    
    private func setupBackgroundView() {
        backgroundView.backgroundColor = .Yellow6
        collectionView.backgroundView = backgroundView
        
        roundedView.backgroundColor = .white
        roundedView.makeRounded(radius: 24)
        roundedView.frame = CGRect(x: 0,
                                   y: -Metric.roundedViewPositionY,
                                   width: UIScreen.main.bounds.width,
                                   height: UIScreen.main.bounds.height * 100)
        
        collectionView.insertSubview(roundedView, at: 0)
    }
    
    private func setupConstraints() {
        view.addSubviews(roundedView, collectionView,
                         myDrawerButton, writingButton,
                         headerTitleLabel, headerGraphicImageView)
        
        headerTitleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(24)
            $0.bottom.equalTo(roundedView.snp.top).offset(-18)
        }
        
        headerGraphicImageView.snp.makeConstraints {
            $0.bottom.equalTo(roundedView.snp.top).offset(10)
            $0.trailing.equalToSuperview().inset(32)
        }
        
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        myDrawerButton.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8)
            $0.trailing.equalTo(writingButton.snp.leading).offset(-8)
        }
        
        writingButton.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.trailing.equalToSuperview().inset(13)
        }
    }
    
    func changeHeaderViewOpacity() {
        let offset = collectionView.contentOffset.y
        let alphaPercent = (-200 - offset) / 30
        let headerViewAlphaPercent = (Metric.headerHeight - (offset + 232)) / Metric.headerHeight
    
        headerGraphicImageView.alpha = alphaPercent
        headerTitleLabel.alpha = alphaPercent
        backgroundView.alpha = headerViewAlphaPercent
        myDrawerButton.alpha = headerViewAlphaPercent
        writingButton.alpha = headerViewAlphaPercent
    }
    
    private func presentWarningPopUp(title: String, description: String) {
        let writingWarningPopUp = PopUpViewController()
        writingWarningPopUp.popUpUsage = .noButton
        writingWarningPopUp.modalTransitionStyle = .crossDissolve
        writingWarningPopUp.modalPresentationStyle = .overCurrentContext
        self.tabBarController?.present(writingWarningPopUp, animated: true, completion: nil)
        writingWarningPopUp.setText(title: title, description: description)
    }

}

extension Reactive where Base: UIViewController {
    var viewDidLoad: ControlEvent<Void> {
        let source = self.methodInvoked(#selector(Base.viewDidLoad)).map { _ in }
        return ControlEvent(events: source)
    }
    
    var viewWillAppear: ControlEvent<Void> {
        let source = self.methodInvoked(#selector(Base.viewWillAppear)).map { _ in }
        return ControlEvent(events: source)
    }
}
