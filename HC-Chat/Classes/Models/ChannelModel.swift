//
//  ChannelModel.swift
//  RxSBChat
//
//  Created by Tizzle Goulet on 5/29/19.
//  Copyright © 2019 HyreCar. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import SendBirdSDK
import CoreData

open class ChannelModel: RxSBModel {
    
    open var channelID: String {
        get { return currentChannelManagedObject?.value(forKey: CoreDataKeys.channelID.rawValue) as? String ?? "" }
        set { currentChannelManagedObject?.setValue(newValue, forKey: CoreDataKeys.channelID.rawValue) }
    }
    open var channelMessages: BehaviorRelay<[MessageModel]> = BehaviorRelay(value: [])
    open var lastMessage: BehaviorRelay<MessageModel?> = BehaviorRelay(value: nil)
    open var channelName: String {
        get { return currentChannelManagedObject?.value(forKey: CoreDataKeys.channelName.rawValue) as? String ?? "Unknown Channel" }
        set { currentChannelManagedObject?.setValue(newValue, forKey: CoreDataKeys.channelName.rawValue)}
    }
    open var userIDs: [String] = []
    open var unreadCount: Int = 0
    open var channelImageURLString: String {
        get { return currentChannelManagedObject?.value(forKey: CoreDataKeys.channelImageURLString.rawValue) as? String ?? "" }
        set { currentChannelManagedObject?.setValue(newValue, forKey: CoreDataKeys.channelImageURLString.rawValue)}
    }
    private var lastMessageID: String {
        get { return currentChannelManagedObject?.value(forKey: CoreDataKeys.lastMessageID.rawValue) as? String ?? "" }
        set { currentChannelManagedObject?.setValue(newValue, forKey: CoreDataKeys.lastMessageID.rawValue) }
    }
    
    /// The Current CoreData Context
    private var _CONTEXT: NSManagedObjectContext {
        return RxSBModel.instance.persistentContainer.viewContext
    }
    
    //  Create the current model
    private var currentChannelManagedObject: NSManagedObject?
    private var disposeBag = DisposeBag()
    
    enum CoreDataKeys: String {
        case channelID
        case lastMessageID
        case channelName
        case channelImageURLString
    }

    /// The other members in this channel. Only available on group channels, empty otherwise
    open var otherMembers: [SBDMember] = [] {
        didSet {
            if otherMembers.isEmpty { return }
            self.channelName = self.displayName
            self.channelImageURLString = otherMembers.first?.profileUrl ?? "https://i.stack.imgur.com/FIEyV.jpg?s=32&g=1"
        }
    }
    /// The display name for the channel.
    /// • If there are no members, we load the channel name from memory
    /// • If there is one member, we get the nickname of that member
    ///     • If the nickname is not found, they are guest
    /// • If there is more than one member, we create a list of all members in the channel
    open var displayName: String {
        return (otherMembers.isEmpty
            ? channelName
            : otherMembers.count == 1
            ? otherMembers.first?.nickname ?? "Guest"
            : otherMembers.compactMap({ return $0.nickname?.capitalized }).description
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "[", with: "")
        ).capitalized
    }
    
    /// Creates a local model of the channel in the cache and maps it
    ///
    /// - Parameter sbChannel: The Sendbird Channel we are creating our local model from
    convenience init(withSendbirdChannel sbChannel: SBDBaseChannel) {
        self.init()
        self.loadChannel(withID: sbChannel.channelUrl)
        if let groupChannel = sbChannel as? SBDGroupChannel {
            map(groupChannel: groupChannel)
        } else if let openChannel = sbChannel as? SBDOpenChannel {
            map(openChannel: openChannel)
        }
        listenForLastMessage()

        do {
            if _CONTEXT.hasChanges {
                try _CONTEXT.save()
            }
        } catch {
            debugPrint("Error when saving the context in message: \(error)")
        }
    }

    /// Loads a channel from URL/ID. Useful if loading a channel from a message, for example
    ///
    /// - Parameter id: The ID of the channel we are loading
    convenience init(withChannelURL channelURL: String) {
        self.init()
        self.loadChannel(withID: channelURL)
        listenForLastMessage()
    }
    
    /// Listen for when teh lat message on this object changes, and update the last Message ID so we may load it later
    private func listenForLastMessage() {
        lastMessage.asDriver().asObservable().subscribe(onNext: { (lastMessage) in
            guard let lastMessageFound = lastMessage,
                !lastMessageFound.messageText.isEmpty
                else {
                //  No last message found, look for one
                return
            }
            self.lastMessageID = lastMessageFound.messageID
        }).disposed(by: disposeBag)
    }
    
    /// Maps the group channel to our local instance
    ///
    /// - Parameter groupChannel: The GroupChannel, of Sendbird Type
    private func map(groupChannel: SBDGroupChannel) {
        self.channelID = groupChannel.channelUrl
        self.channelName = groupChannel.name
        
        if let members = groupChannel.members as? [SBDMember] {
            self.userIDs = members.compactMap({ $0.userId })
            self.otherMembers = members.filter({ return $0.userId != SBDMain.getCurrentUser()?.userId })
        }
        self.unreadCount = Int(groupChannel.unreadMessageCount)
        self.lastMessage.accept( MessageModel(withSBDMessage: groupChannel.lastMessage))
    }
    
    /// Maps the open channel to our local mpdel
    ///
    /// - Parameter openChannel: The Open Channel type from Sendbird
    private func map(openChannel: SBDOpenChannel) {
        self.channelID = openChannel.coverUrl ?? "-1"
        self.channelName = openChannel.name
    }
}

// MARK: - Core Data Controller
extension ChannelModel {

    /// Deletes the current channel from the cache
    func delete() {
        guard let channelFound = currentChannelManagedObject
            else { return }
        _CONTEXT.delete(channelFound)

        //  Now, delete all the messages in the current channel
        for msg in self.channelMessages.value {
            msg.delete()
        }
    }
    
    /// Creates a channel in CoreData with the provided URL/ID and sets the current managed object to it
    ///
    /// - Parameter id: The ID of the channel to be created
    /// - Returns: The newly created channel, if surccessful
    private func createChannel(withID channelID: String) -> NSManagedObject? {
        guard let newChannelEntity = NSEntityDescription
            .entity(
                forEntityName: "ConversationScheme",
                in: _CONTEXT
            ) else { return nil }
        let channel = NSManagedObject(entity: newChannelEntity, insertInto: _CONTEXT)
        channel.setValue(channelID, forKey: CoreDataKeys.channelID.rawValue)

        if _CONTEXT.hasChanges {
            do {
                try _CONTEXT.save()
            } catch {
                return nil
            }
            return channel
        } else { return nil }
    }

    /// Loads a channel given the URL/ID to load. Called from init
    ///
    /// - Parameter channelIDToSearch: The ChannelID we need to search CoreData for
    private func loadChannel(withID channelIDToSearch: String) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ConversationScheme")
        request.predicate = NSPredicate(format: "\(CoreDataKeys.channelID.rawValue) = %@", channelIDToSearch)
        request.returnsObjectsAsFaults = false

        do {
            let channelResults = try _CONTEXT.fetch(request)
            if channelResults.isEmpty {
                //  No Results yet, create a new message
                currentChannelManagedObject = createChannel(withID: channelIDToSearch)
            } else if channelResults.count > 1 {
                //  Delete all the messages, then create
                for messageObject in channelResults {
                    if let messageToDelete = messageObject as? NSManagedObject {
                        _CONTEXT.delete(messageToDelete)
                    }
                }
                currentChannelManagedObject = createChannel(withID: channelIDToSearch)
            } else {
                //  We have our message at index 0
                currentChannelManagedObject = channelResults[0] as? NSManagedObject
            }
        } catch {
            debugPrint("Error found loading Message: \(error)")
        }
        self.loadChannelMessages()
    }

    /// Loads the current channels messages from the cache
    private func loadChannelMessages() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "MessageScheme")
        request.predicate = NSPredicate(format: "\(MessageModel.CoreDataKeys.channelID.rawValue) = %@", channelID)
        request.returnsObjectsAsFaults = false

        do {
            let messageResults = try _CONTEXT.fetch(request)
            if messageResults.isEmpty { return }
            let mappedMessages = messageResults.compactMap { (result) -> MessageModel? in
                guard let messageObject = result as? NSManagedObject,
                    let messageID = messageObject.value(forKey: MessageModel.CoreDataKeys.messageID.rawValue) as? String
                    else { return nil }
                return MessageModel(withID: messageID)
            }.sorted(by: { $0.messageDate < $1.messageDate })
            lastMessage.accept(mappedMessages.last)
            channelMessages.accept(mappedMessages)
        } catch {
            print("Could not fetch local channel messages")
        }
    }

    /// Loads all of the channels from the cache
    ///
    /// - Returns: An array of channels, that are already mapped from the cache
    class func loadAllChannels() -> [ChannelModel] {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ConversationScheme")
        request.returnsDistinctResults = false

        do {
            let channelResults = try RxSBModel.instance.persistentContainer.viewContext.fetch(request)
            if channelResults.isEmpty { return [] }
            return channelResults.compactMap({ (result) -> ChannelModel? in
                guard let resultManagedObject = result as? NSManagedObject,
                    let foundObjectID = resultManagedObject.value(forKey: CoreDataKeys.channelID.rawValue) as? String
                    else {
                        return nil
                }
                return ChannelModel(withChannelURL: foundObjectID)
            }).sorted(by: { (channel1, channel2) -> Bool in
                guard let channel1Date = channel1.lastMessage.value?.messageDate,
                    let channel2Date = channel2.lastMessage.value?.messageDate
                    else { return false }
                return channel1Date > channel2Date
            })
        } catch {
            print("Could not fetch all channels: \(error)")
            return []
        }
    }
    
}
