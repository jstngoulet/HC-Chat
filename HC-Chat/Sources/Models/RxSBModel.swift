//
//  RxSBModel.swift
//  RxSBChat
//
//  Created by Tizzle Goulet on 6/3/19.
//  Copyright © 2019 HyreCar. All rights reserved.
//

import Foundation
import CoreData

open class RxSBModel: NSObject {
    
    static var instance: RxSBModel = RxSBModel()
    
    // MARK: - Core Data stack
    
    fileprivate lazy var managedObjectModel: NSManagedObjectModel? = {
        
        // the moc's model should be accessible via apps in this workspace
        // or through the module that cocoapods will create as part of the file's
        // resource bundle, as such, we need to look in two different places
        // to use the correct bundle at run time
        var rawBundle: Bundle? {
            
            if let bundle = Bundle(identifier: "com.hyrecar.ios.pod.RxSBChat") {
                return bundle
            }
            
            if let podBundleURL = Bundle(for: RxSBModel.self).url(forResource: "RxSBChat", withExtension: "bundle"),
                let frameworkBundle = Bundle(url: podBundleURL) {
                print("Found Framework Bundle :\(podBundleURL.absoluteString)")
                return frameworkBundle
            }
            
//            print("Frameworks: \(Bundle.allFrameworks.compactMap({ $0.bundleURL }))\n\nBundles: \(Bundle.allBundles.compactMap({ $0.bundleURL}))")

            guard
                let resourceBundleURL = Bundle(for: type(of: self)).url(forResource: "RxSBChat", withExtension: "bundle"),
                let realBundle = Bundle(url: resourceBundleURL) else {
                    return nil
            }
            
            return realBundle
        }
        
        guard let bundle: Bundle = rawBundle else {
            return nil
        }
        
        guard let modelURL = bundle.url(forResource: "RxSBChatModels", withExtension: "momd"),
            let mom = NSManagedObjectModel(contentsOf: modelURL)
            else { print("Could not get local model"); return nil }
        
        return mom
    }()
    
    lazy var persistentContainer: NSPersistentContainer = {
        guard let objectModelFound = managedObjectModel else {
            //  No model found, look in App Delegate
            return chatPersistentContainer
        }
        let container = NSPersistentContainer(name: "main", managedObjectModel: objectModelFound)
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let errorFound = error {
                print("Error found on container load: \(errorFound)")
                return
            }
            print("Store Description: \(storeDescription)")
        })
        return container
    }()
    
    lazy var chatPersistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "RxSBChatModels")
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}
