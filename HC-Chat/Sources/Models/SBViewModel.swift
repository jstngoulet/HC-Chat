//
//  SBViewModel.swift
//  RxSBChat
//
//  Created by Tizzle Goulet on 5/29/19.
//  Copyright © 2019 HyreCar. All rights reserved.
//

import Foundation
import SendBirdSDK
import RxCocoa
import RxSwift

typealias ChannelsCompletion = (([ChannelModel]?, [MessageModel]?) -> Void)?

open class SBViewModel: RxSBModel {

    enum SBViewModelError: Error {
        case noMessages
        case queryNotCreated
        case noMessageSent
        case noChannelsFound
        case newChannelCreatedNotFound
        case notConnected
    }
    
    /// Teh Sendbird API Key to use in this application
    public static var SBDAPIKey: String? {
        didSet {
            guard let appID = SBViewModel.SBDAPIKey else { return }
            SBDMain.initWithApplicationId(appID)
        }
    }
    /// Determines if the user is currently connected to Sendbird
    public static var isLoggedIn: BehaviorRelay<Bool> = BehaviorRelay(value: false)

    /// The current user, nil if not signed in
    public static var currentUser: SBDUser? { return SBDMain.getCurrentUser() }

    /// The current channels, in our local models, loaded
    /// • Before the application gets the users messages from sendbird, we load the messages from the cache
    ///     all new messages override the old messages in place.
    /// • When the user is is signed in, the latest channels are gathered, and merged with our cache
    public static var currentChannels: BehaviorRelay<[ChannelModel]> = BehaviorRelay(value: [])

    /// The current unread messages, max of one per channel
    public static var currentMessages: BehaviorRelay<[MessageModel]> = BehaviorRelay(value: [])

    /// The local channel query, cached for pagination
    fileprivate static let channelQuery = SBDGroupChannel.createMyGroupChannelListQuery()

    /// A local sington, used for setting the channel listener delegate to self
    fileprivate static var shared = SBViewModel()

    /// The current SBDChannels, so we may create the messages query when needed
    fileprivate static var SBDChannels: [SBDBaseChannel] = []
    
    /// Connects the user ID to the SendBird Chat. Disconnects if the user is already connected
    ///
    /// - Parameter userID: The UserID that is signed in
    public class func connect(userID: String) {
        guard SBDMain.getCurrentUser() != nil else {
            //  Connect the user
            SBDMain.connect(withUserId: userID) { (_, err) in
                if let foundError = err {
                    print("Err: \(foundError.debugDescription)")
                    return
                }
                SBViewModel.isLoggedIn.accept(true)

                //  Start Listening for messages
                SBDMain.add(SBViewModel.shared as SBDChannelDelegate, identifier: "com.hyrecar.ios.rxsbchat.channel.delegate")
            }
            return
        }
        //  Disconnect the user, then recursively call this function to sign back in
        disconnect(userIDToReconnect: userID)
    }
    
    /// Disconnect the current user from Sendbird
    public class func disconnect(userIDToReconnect: String? = nil) {
        SBDMain.disconnect {
            SBViewModel.isLoggedIn.accept(false)
            SBDMain.removeChannelDelegate(forIdentifier: "com.hyrecar.ios.rxsbchat.channel.delegate")

            //  We should delete all the cached channels and messages here
            for channel in SBViewModel.currentChannels.value {
                channel.delete()
            }

            if let userID = userIDToReconnect {
                connect(userID: userID)
            }
        }
    }
    
    private class func addNew(sbChannel: SBDBaseChannel) {
        SBDChannels.append(sbChannel)
    }
    
    /// Gets the group channels for the current user, if the user is signed in, and updates the provided relay
    ///
    /// - Parameters:
    ///   - channels:       The Channels found, converted to the local model
    ///   - includeEmpty:   Whether the request should include empty channels
    public class func getGroup(includeEmpty: Bool = false) {
        guard let qry = SBViewModel.channelQuery else { return }
        qry.includeEmptyChannel = includeEmpty
        qry.order = .latestLastMessage
        qry.includeMemberList = true
        if !qry.hasNext { return }
        qry.loadNextPage { (channelsReturned, error) in
            if let errorFound = error {
                print("Error: \(errorFound)")
                return
            }
            guard let foundChannels = channelsReturned else { return }
            SBDChannels.append(contentsOf: foundChannels)
            let foundChannelsConverted = foundChannels.compactMap({ ChannelModel(withSendbirdChannel: $0) })
            
//              Now that we have the channels, we need to loop through them.
//              If the unread count is not 0, we need to add the messages to the messages array
            var messagesFound: [MessageModel] = []

            for (channel) in foundChannelsConverted {
                if channel.unreadCount > 0,
                    let lastMessage = channel.lastMessage.value {
                    messagesFound.append(lastMessage)
                }
            }

            currentChannels.accept(foundChannelsConverted)
            currentMessages.accept(messagesFound)
        }
    }
    
    /// Gets the messages in the current channel
    ///
    /// - Parameters:
    ///   - channel: The channel that we are searching the messages for
    ///   - completion: The completion block, containing the found messages, converted to our local model
    public class func getMessages(forChannel channel: ChannelModel, then completion: ((Result<[MessageModel], Error>) -> Void)?) {
        guard let sbChannel = SBDChannels.first(where: { (sbChannelWatch) -> Bool in
            return sbChannelWatch.channelUrl == channel.channelID
        }), let messageQuery = sbChannel.createPreviousMessageListQuery()
            else {
                completion?(.failure(SBViewModelError.queryNotCreated))
                return
        }
        messageQuery.limit = 100
        messageQuery.load { (messages, error) in
            if let errorFound = error {
                completion?(.failure(errorFound))
                return
            }
            guard let messagesFound = messages
                else {
                    completion?(.failure(SBViewModelError.noMessages))
                    return
            }
            completion?(.success(messagesFound.compactMap({ return MessageModel(withSBDMessage: $0) })))
        }
    }
    
    /// Sends a message in the channel with the provided text
    ///
    /// - Parameters:
    ///   - textMessage:    The Text message we are sending
    ///   - inChannel:      The Channel we are sending the message to
    public class func send(textMessage: String, inChannel channel: ChannelModel, then completion: ((Result<MessageModel, Error>) -> Void)?) {
        
        guard let sbChannel = SBDChannels.first(where: { (sbChannelWatch) -> Bool in
            return sbChannelWatch.channelUrl == channel.channelID
        }) else {
            completion?(.failure(SBViewModelError.noChannelsFound))
            return
        }
        
        sbChannel.sendUserMessage(textMessage) { (userMessageSent, error) in
            if let errorFound = error {
                //  Add a message to the beginning, informing the user it did not send
                completion?(.failure(errorFound))
                return
            }
            guard let messageSent = userMessageSent else {
                completion?(.failure(SBViewModelError.noMessageSent))
                return
            }

            //  Return with the new message, if available
            completion?(.success(MessageModel(withSBDMessage: messageSent)))
        }
    }
    
    /// Creates a channel with a single user id, then returns the channel if successful
    ///
    /// - Parameters:
    ///   - userID:         User ID to start the channel with
    ///   - completion:     The action to perform when the channel is created. Returns channel if available
    public class func createChannelWith(userID: String, then completion: @escaping ((Result<ChannelModel, Error>) -> Void)) {
        
        //  We need to first determine if there is already a channel that exists.
        //  If there is, we just need to return it
        if let channelFound = currentChannels.value.first(where: { $0.userIDs.contains(userID) }) {
            //  Channel found, return it
            completion(.success(channelFound))
            return
        }

        guard let user = currentUser
            else {
                completion(.failure(SBViewModelError.notConnected))
                return
        }
        
        //  Else, no channel found, so we need to create one
        let channelParams = SBDGroupChannelParams()
        
        //  Add the current user owner ID and the other user ID
        channelParams.addUserIds(
            [
                user.userId,
                userID
            ]
        )
        
        //  Set the channel name
        channelParams.name = user.userId + " ~> " + userID
        channelParams.isDistinct = true
        
        //  Now, create the new channel
        SBDGroupChannel.createChannel(with: channelParams) { (createdChannel, error) in
            if let errorFound = error {
                completion(.failure(errorFound))
                return
            }
            
            guard let foundChannel = createdChannel else {
                completion(.failure(SBViewModelError.newChannelCreatedNotFound))
                return
            }
            
            //  Report to analytics
            let localChannel = ChannelModel(withSendbirdChannel: foundChannel)
            addNew(sbChannel: foundChannel)
            
            //  Return the new channel
            completion(.success(localChannel))
        }
    }
}

// MARK: - Delegate listening for hte channel events
extension SBViewModel: SBDChannelDelegate {

    /// When a new message is recieved, update the cache an insert the message in the correct channel
    ///
    /// - Parameters:
    ///   - sender: The channel that the message should be mapped to
    ///   - message: The message that we are mapping
    public func channel(_ sender: SBDBaseChannel, didReceive message: SBDBaseMessage) {
        let newMessage = MessageModel(withSBDMessage: message)
        var currentChannels = SBViewModel.currentChannels.value
        var currentMessages = SBViewModel.currentMessages.value

        if let localChannelFoundIndex = SBViewModel.currentChannels.value
            .lastIndex(where: { sender.channelUrl == $0.channelID }) {
            //  Save the message in the current channel as the last message
            let currentChannel = currentChannels[localChannelFoundIndex]
            var currentChannelMessages = currentChannel.channelMessages.value
            currentChannels[localChannelFoundIndex].lastMessage.accept(newMessage)
            //  Already contains a message from the channel, a user just sent another message
            //  In this case, we need to remove the one found, and add another one at the current index
            if let currentIndex = currentMessages.firstIndex(where: { $0.channelURL == sender.channelUrl }) {
                //  Exists
                currentMessages.remove(at: currentIndex)
                currentMessages.insert(newMessage, at: 0)
            } else {
                //  Does not exist, insert in front
                currentMessages.insert(newMessage, at: 0)
            }
            currentChannelMessages.append(newMessage)
            currentChannels[localChannelFoundIndex].channelMessages.accept(currentChannelMessages)
            
            //  Since we found the local channel, we can increment the unread count to match what is stated in the sender
            if let groupChannel = sender as? SBDGroupChannel {
                currentChannel.unreadCount += Int(groupChannel.unreadMessageCount)
            }
        } else {
            //  Add the channel to the list
            currentChannels.append(ChannelModel(withSendbirdChannel: sender))
            currentMessages.append(MessageModel(withSBDMessage: message))
        }

        //  Ensure the channels and messages are updated
        SBViewModel.currentMessages.accept(currentMessages)
        SBViewModel.currentChannels.accept(currentChannels)
    }

}
