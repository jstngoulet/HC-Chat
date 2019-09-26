//
//  MessageModel.swift
//  RxSBChat
//
//  Created by Tizzle Goulet on 5/29/19.
//  Copyright © 2019 HyreCar. All rights reserved.
//

import Foundation
import SendBirdSDK
import CoreData

/// The model for the messages that are sent through sendbird.
/// This class can also be used other places as it pertains to any cahced model that may exist for a message.
open class MessageModel: RxSBModel {

    /// The image URL string that represents the user that sent the message
    open var shownImageURLString: String {
        set { currentMessageManagedObject?.setValue(newValue, forKey: CoreDataKeys.shownImageURLString.rawValue) }
        get { return currentMessageManagedObject?.value(forKey: CoreDataKeys.shownImageURLString.rawValue) as? String ?? "https://cdn1.iconfinder.com/data/icons/materia-human/24/013_003_account_profile_circle-512.png" }
    }

    /// The Shown user name, of whom sent the message
    open var shownUserName: String {
        set { currentMessageManagedObject?.setValue(newValue, forKey: CoreDataKeys.shownUserName.rawValue) }
        get { return currentMessageManagedObject?.value(forKey: CoreDataKeys.shownUserName.rawValue) as? String ?? "" }
    }

    /// The date the message was sent
    open var messageDate: Date {
        set { currentMessageManagedObject?.setValue(newValue, forKey: CoreDataKeys.messageDate.rawValue) }
        get { return currentMessageManagedObject?.value(forKey: CoreDataKeys.messageDate.rawValue) as? Date ?? Date.distantPast }
    }

    /// The message text that should be displayed
    open var messageText: String {
        set { currentMessageManagedObject?.setValue(newValue, forKey: CoreDataKeys.messageText.rawValue) }
        get { return currentMessageManagedObject?.value(forKey: CoreDataKeys.messageText.rawValue) as? String ?? "No Message Was Found" }
    }

    /// Whether or not the current message has been read
    open var isRead: Bool {
        set { currentMessageManagedObject?.setValue(newValue, forKey: CoreDataKeys.isRead.rawValue) }
        get { return currentMessageManagedObject?.value(forKey: CoreDataKeys.isRead.rawValue) as? Bool ?? false }
    }

    /// The patent channel's ID
    open var channelURL: String {
        set { currentMessageManagedObject?.setValue(newValue, forKey: CoreDataKeys.channelID.rawValue) }
        get { return currentMessageManagedObject?.value(forKey: ChannelModel.CoreDataKeys.channelID.rawValue) as? String ?? "" }
    }

    /// The message ID, used to find the message and to perform additional actions
    open var messageID: String {
        set { currentMessageManagedObject?.setValue(newValue, forKey: CoreDataKeys.messageID.rawValue) }
        get { return currentMessageManagedObject?.value(forKey: CoreDataKeys.messageID.rawValue) as? String ?? "" }
    }

    /// A boolean that shows if the user ID of the message was the same as the current user. This value is stored.
    open var wasSentByCurrentUser: Bool {
        set { currentMessageManagedObject?.setValue(newValue, forKey: CoreDataKeys.wasSentByCurrentUser.rawValue) }
        get { return currentMessageManagedObject?.value(forKey: CoreDataKeys.wasSentByCurrentUser.rawValue) as? Bool ?? false }
    }

    /// The User ID of whom sent the message
    open var sentByUserID: String {
        set { currentMessageManagedObject?.setValue(newValue, forKey: CoreDataKeys.sentByUserID.rawValue) }
        get { return currentMessageManagedObject?.value(forKey: CoreDataKeys.sentByUserID.rawValue) as? String ?? "" }
    }
    
    /// The Current CoreData Context
    private var _CONTEXT: NSManagedObjectContext {
        return RxSBModel.instance.persistentContainer.viewContext
    }
    
    //  Create the current model
    private var currentMessageManagedObject: NSManagedObject?
    
    enum CoreDataKeys: String {
        case shownImageURLString
        case shownUserName
        case messageDate
        case messageText
        case isRead
        case channelID
        case messageID
        case wasSentByCurrentUser
        case sentByUserID
    }
    
    /// Loads a message from coreData using the ID
    ///
    /// - Parameter id: The ID of the message we are trying to retrieve
    convenience init(withID newMessageID: String) {
        self.init()
        self.loadMessage(withID: newMessageID)
    }
    
    /// Creates a new message from an SBDBase Message and stores it in CoreData
    ///
    /// - Parameter message: The message we are loading
    convenience init(withSBDMessage message: SBDBaseMessage?) {
        self.init()
        guard let messageFound = message else { return }
        self.loadMessage(withID: "\(messageFound.messageId)")
        self.channelURL = messageFound.channelUrl ?? ""
        self.messageDate = Date(timeIntervalSince1970: Double(messageFound.createdAt)/1000)
        
        if let textMessage = messageFound as? SBDUserMessage {
            map(textMessage: textMessage)
        } else if let fileMessage = messageFound as? SBDFileMessage {
            map(dataMessage: fileMessage)
        } else if let adminMessage = messageFound as? SBDAdminMessage {
            map(adminMessage: adminMessage)
        }
        do {
            if _CONTEXT.hasChanges {
                try _CONTEXT.save()
            }
        } catch {
            debugPrint("Error when saving the context in message: \(error)")
        }
    }
    
    /// Maps a user message from the Sendbird type to our local type
    ///
    /// - Parameter textMessage: The User Message from Sendbird that we are mapping
    private func map(textMessage: SBDUserMessage) {
        messageText = textMessage.message ?? "No Message Found"
        shownUserName = textMessage.sender?.nickname ?? "Another User"
        shownImageURLString = textMessage.sender?.profileUrl ?? shownImageURLString
        wasSentByCurrentUser = textMessage.sender?.userId == SBDMain.getCurrentUser()?.userId
        sentByUserID = textMessage.sender?.userId ?? ""
    }
    
    /// Maps the admin message to our message type.
    ///
    /// - Parameter adminMessage: The Admin message shown
    private func map(adminMessage: SBDAdminMessage) {
        messageText = adminMessage.message ?? "No Message Found"
    }
    
    /// Maps the Sendbird file message type to our local type
    /// - Note: File types are not yet supported. Currently just maps a text showing that
    ///
    /// - Parameter dataMessage: The message we are mapping
    private func map(dataMessage: SBDFileMessage) {
        wasSentByCurrentUser = dataMessage.sender?.userId == SBDMain.getCurrentUser()?.userId
        shownImageURLString = dataMessage.sender?.profileUrl ?? shownImageURLString
        shownUserName = dataMessage.sender?.nickname ?? "Another User"
        messageText = "File messages are not yet supported"
    }
    
    /// Creates a sample message, to be used in testing
    ///
    /// - Parameters:
    ///   - name:           The Name of the user that sent the message
    ///   - messageDate:    The date the message was sent
    ///   - messageText:    The text the mesage displays
    ///   - userIsSender:   Whether the user sent it or not
    convenience init(withName name: String, messageDate: Date, messageText: String, userIsSender: Bool) {
        self.init()
        self.loadMessage(withID: UUID().uuidString)
        self.shownUserName = name
        self.messageDate = messageDate
        self.messageText = messageText
        self.wasSentByCurrentUser = userIsSender
    }
    
}

// MARK: - Core Data Controller
extension MessageModel {

    /// Deletes the current message from the cache
    func delete() {
        guard let messageFound = currentMessageManagedObject
            else { return }
        _CONTEXT.delete(messageFound)
    }
    
    /// Creates a new message in our Coredata instance. Should only be called if the message was not found in the DB already
    ///
    /// - Parameter id: The ID of the mesage to create
    /// - Returns:      The ManagedObject of the stored instance
    private func createMessage(withID messageID: String) -> NSManagedObject? {
        guard let newMessageEntity = NSEntityDescription
            .entity(
                forEntityName: "MessageScheme",
                in: _CONTEXT
            ) else { return nil }
        let message = NSManagedObject(entity: newMessageEntity, insertInto: _CONTEXT)
        message.setValue(messageID, forKey: CoreDataKeys.messageID.rawValue)
        
        if _CONTEXT.hasChanges {
            do {
                try _CONTEXT.save()
            } catch {
                return nil
            }
            return message
        } else { return nil }
    }

    /// Loads a message with a specified ID into memory
    ///
    /// - Parameter messageIDToSearch: The MessageID to search the DB for 
    private func loadMessage(withID messageIDToSearch: String) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "MessageScheme")
        request.predicate = NSPredicate(format: "\(CoreDataKeys.messageID.rawValue) = %@", messageIDToSearch)
        request.returnsObjectsAsFaults = false

        do {
            let messageResults = try _CONTEXT.fetch(request)
            if messageResults.isEmpty {
                //  No Results yet, create a new message
                currentMessageManagedObject = createMessage(withID: messageIDToSearch)
            } else if messageResults.count > 1 {
                //  Delete all the messages, then create
                for messageObject in messageResults {
                    if let messageToDelete = messageObject as? NSManagedObject {
                        _CONTEXT.delete(messageToDelete)
                    }
                }
                currentMessageManagedObject = createMessage(withID: messageIDToSearch)
            } else {
                //  We have our message at index 0
                currentMessageManagedObject = messageResults[0] as? NSManagedObject
            }
        } catch {
            debugPrint("Error found loading Message: \(error)")
        }
    }
}
