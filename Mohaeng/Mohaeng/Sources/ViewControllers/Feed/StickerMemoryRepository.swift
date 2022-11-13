//
//  StickerMemoryRepository.swift
//  Mohaeng
//
//  Created by 윤예지 on 2022/04/29.
//

import Foundation

final class StickerMemoryRepository {
    
    private static var store: [Int: [Int: Int]] = [:] // postId의 이모지 정보 저장 [postId: [emojiId: count]]
    private static var selectedEmoji: [Int: Int] = [:] // postId에 이모지를 붙였었는지에 대한 여부를 저장 [postId: emojiId]
    
    func save(postId: Int, emojis: [Emoji]) {
        for emoji in emojis {
            if StickerMemoryRepository.store[postId] != nil {
                StickerMemoryRepository.store[postId]![emoji.id] = emoji.count
            } else {
                StickerMemoryRepository.store[postId] = [emoji.id: emoji.count]
            }
        }
    }
    
    func clickEmoji(postId: Int, emojiId: Int) {
        if StickerMemoryRepository.selectedEmoji[postId] == nil {
            if StickerMemoryRepository.store[postId]![emojiId] != nil {
                StickerMemoryRepository.store[postId]![emojiId]! += 1
            } else {
                StickerMemoryRepository.store[postId]![emojiId] = 1
            }
            StickerMemoryRepository.selectedEmoji[postId] = emojiId
        } else {
            let selectedEmoji = StickerMemoryRepository.selectedEmoji[postId]!
            if emojiId != selectedEmoji {
                if StickerMemoryRepository.store[postId]![emojiId] != nil {
                    StickerMemoryRepository.store[postId]![emojiId]! += 1
                } else {
                    StickerMemoryRepository.store[postId]![emojiId] = 1
                }
                
                StickerMemoryRepository.store[postId]![selectedEmoji]! -= 1
                if StickerMemoryRepository.store[postId]![selectedEmoji]! == 0 {
                    StickerMemoryRepository.store.removeValue(forKey: postId)
                }
                
                StickerMemoryRepository.selectedEmoji[postId] = emojiId
            }
        }
    }
    
    func fetchAll() -> [Int: [Int: Int]] {
        return StickerMemoryRepository.store
    }
    
    func fetchEmojis(by postId: Int) -> [Int: Int] {
        return StickerMemoryRepository.store[postId] ?? [:]
    }
    
    func saveMyEmoji(postId: Int, emojiId: Int) {
        StickerMemoryRepository.selectedEmoji[postId] = emojiId
    }
    
    func clear() {
        StickerMemoryRepository.store.removeAll()
    }
    
}
