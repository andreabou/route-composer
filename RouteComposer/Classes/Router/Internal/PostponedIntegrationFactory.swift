//
// RouteComposer
// PostponedIntegrationFactory.swift
// https://github.com/ekazaev/route-composer
//
// Created by Eugene Kazaev in 2018-2022.
// Distributed under the MIT license.
//

import Foundation
import UIKit

struct PostponedIntegrationFactory: CustomStringConvertible {

    var factory: AnyFactory

    var contextTasks: [AnyContextTask]

    var transformer: AnyContextTransformer

    init(for factory: AnyFactory, with contextTasks: [AnyContextTask] = [], transformer: AnyContextTransformer? = nil) {
        self.factory = factory
        self.contextTasks = contextTasks
        self.transformer = transformer.flatMap { $0 } ?? EmptyAnyContextTransformer()
    }

    mutating func add(_ contextTask: AnyContextTask) {
        contextTasks.append(contextTask)
    }

    mutating func prepare(with context: AnyContext) throws {
        let context = InplaceAnyContext(context: context, transformer: transformer)
        try factory.prepare(with: context)
        contextTasks = try contextTasks.map {
            var contextTask = $0
            try contextTask.prepare(with: context)
            return contextTask
        }
    }

    func build(with context: AnyContext, in childViewControllers: inout [UIViewController]) throws {
        let context = InplaceAnyContext(context: context, transformer: transformer)
        let viewController = try factory.build(with: context)
        try contextTasks.forEach { try $0.perform(on: viewController, with: context) }
        try factory.action.perform(embedding: viewController, in: &childViewControllers)
    }

    public var description: String {
        String(describing: factory)
    }

}
