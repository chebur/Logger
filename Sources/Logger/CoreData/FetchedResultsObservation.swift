//
//  FetchedResultsObservation.swift
//  Logging
//
//  Created by Dmitry Nesterenko on 20.08.2020.
//

import Foundation
import CoreData

public class FetchedResultsObservation {
    private var handler: NSFetchedResultsControllerDelegate?
    private var frc: NSFetchedResultsController<NSFetchRequestResult>?
    
    var fetchedObjects: [NSFetchRequestResult]? {
        return frc?.fetchedObjects
    }
    
    deinit {
        invalidate()
    }
    
    init<T: NSFetchRequestResult>(frc: NSFetchedResultsController<T>, handler: NSFetchedResultsControllerDelegate) {
        self.frc = frc as? NSFetchedResultsController<NSFetchRequestResult>
        self.handler = handler
    }
    
    /// `invalidate()` will be called automatically when an `FetchedResultsObservation` is deinited
    public func invalidate() {
        handler = nil
        frc = nil
    }
}
