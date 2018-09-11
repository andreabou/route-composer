//
// Created by Eugene Kazaev on 14/02/2018.
//

import Foundation
import UIKit

/// Non type safe boxing wrapper for Factory protocol
protocol AnyFactory {

    var action: AnyAction { get }

    mutating func prepare(with context: Any?) throws

    func build(with context: Any?) throws -> UIViewController

    /// Receives an array of factories whose view controllers should be merged into current container
    /// factory before it actually builds a container view controller with child view controllers inside.
    ///
    /// - Parameter factories: Array of factories to be handled by container factory.
    /// - Returns: Array of factories that are not supported by this container type. `Router` should decide how to deal with them.
    mutating func scrapeChildren(from factories: [AnyFactory]) throws -> [AnyFactory]

}

protocol AnyFactoryBox: AnyFactory {

    associatedtype FactoryType: AbstractFactory

    var action: AnyAction { get }

    static func box(for factory: FactoryType?, action: AnyAction) -> AnyFactory?

    var factory: FactoryType { get set }

    init(_ factory: FactoryType, action: AnyAction)

}

extension AnyFactoryBox where Self: AnyFactory {

    static func box(for factory: FactoryType?, action: AnyAction) -> AnyFactory? {
        if factory as? NilEntity != nil {
            return nil
        } else if let factory = factory {
            return Self(factory, action: action)
        }
        return nil
    }

    mutating func prepare(with context: Any?) throws {
        guard let typedContext = Optional<Any>.some(context as Any) as? FactoryType.Context else {
            throw RoutingError.message("\(String(describing: factory)) does not accept \(String(describing: context)) as a context.")
        }
        return try factory.prepare(with: typedContext)
    }

    mutating func scrapeChildren(from factories: [AnyFactory]) throws -> [AnyFactory] {
        return factories
    }

}

extension AnyFactory where Self: CustomStringConvertible & AnyFactoryBox {

    var description: String {
        return String(describing: factory)
    }

}

struct FactoryBox<F: Factory>: AnyFactory, AnyFactoryBox, CustomStringConvertible {

    typealias FactoryType = F

    var factory: F

    let action: AnyAction

    init(_ factory: F, action: AnyAction) {
        self.factory = factory
        self.action = action
    }

    func build(with context: Any?) throws -> UIViewController {
        guard let typedContext = Optional<Any>.some(context as Any) as? FactoryType.Context else {
            throw RoutingError.message("\(String(describing: factory)) does not accept \(String(describing: context)) as a context.")
        }
        return try factory.build(with: typedContext)
    }

}

struct ContainerFactoryBox<F: Container>: AnyFactory, AnyFactoryBox, CustomStringConvertible {

    typealias FactoryType = F

    var factory: FactoryType

    let action: AnyAction

    var children: [DelayedIntegrationFactory<FactoryType.Context>] = []

    init(_ factory: FactoryType, action: AnyAction) {
        self.factory = factory
        self.action = action
    }

    mutating func scrapeChildren(from factories: [AnyFactory]) throws -> [AnyFactory] {
        var otherFactories: [AnyFactory] = []
        self.children = factories.compactMap({ child -> DelayedIntegrationFactory<FactoryType.Context>? in
            guard child.action.embeddable else {
                otherFactories.append(child)
                return nil
            }
            return DelayedIntegrationFactory(child)
        })
        return otherFactories
    }

    func build(with context: Any?) throws -> UIViewController {
        guard let typedContext = Optional<Any>.some(context as Any) as? FactoryType.Context else {
            throw RoutingError.message("\(String(describing: factory)) does not accept \(String(describing: context)) as a context.")
        }
        return try factory.build(with: typedContext, integrating: ChildCoordinator(childFactories: children))
    }

}
