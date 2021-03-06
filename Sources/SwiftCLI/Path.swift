//
//  Path.swift
//  SwiftCLI
//
//  Created by Jake Heiser on 3/22/18.
//

public struct CommandGroupPath {
    
    public let groups: [CommandGroup]
    
    public var cli: CLI {
        return groups.first! as! CLI
    }
    
    public var bottom: CommandGroup {
        return groups.last!
    }
    
    public init(cli: CLI, groups: [CommandGroup] = []) {
        self.init(groups: [cli] + groups)
    }
    
    private init(groups: [CommandGroup]) {
        self.groups = groups
    }
    
    public func appending(_ group: CommandGroup) -> CommandGroupPath {
        return CommandGroupPath(groups: groups + [group])
    }
    
    public func appending(_ command: Command) -> CommandPath {
        return CommandPath(groupPath: self, command: command)
    }
    
    public func joined(separator: String = " ") -> String {
        return groups.map({ $0.name }).joined(separator: separator)
    }
    
}

public struct CommandPath {
    
    public let groupPath: CommandGroupPath
    
    public let command: Command
    
    public var groups: [CommandGroup] {
        return groupPath.groups
    }
    
    public var options: [Option] {
        let shared = groupPath.groups.map({ $0.sharedOptions }).joined()
        return command.options + shared
    }
    
    var usage: String {
        var message = joined()
        
        if !command.parameters.isEmpty {
            let signature = command.parameters.map({ $0.1.signature(for: $0.0) }).joined(separator: " ")
            message += " \(signature)"
        }
        
        if !options.isEmpty {
            message += " [options]"
        }
        
        return message
    }
    
    fileprivate init(groupPath: CommandGroupPath, command: Command) {
        self.groupPath = groupPath
        self.command = command
    }
    
    public func joined(separator: String = " ") -> String {
        return groupPath.joined(separator: separator) + separator + command.name
    }
    
}
