SwiftCLI
========

A powerful framework that can be used to develop a CLI, from the simplest to the most complex, in Swift.

```swift
//
//  main.swift
//  Example
//
//  Created by Jake Heiser on 7/31/14.
//  Copyright (c) 2014 jakeheis. All rights reserved.
//

import Foundation

CLI.setup(name: "greeter")
CLI.registerChainableCommand(commandName: "greet")
    .withExecutionBlock {(arguments) in
        print("Hey there!")
    }
CLI.go()
```
```bash
~ > greeter greet
Hey there!
```

## Upgrading from SwiftCLI 1.0?

Check out the [migration guide](MIGRATION.md)!

## Contents
* [Creating a CLI](#creating-a-cli)
* [Commands](#commands)
* [Parameters](#parameters)
* [Options](#options)
* [Routing commands](#routing-commands)
* [Special Commands](#special-commands)
* [Input](#input)
* [Running your CLI](#running-your-cli)
* [Installation](#swiftcli-installation)
* [Example](#example)

## Creating a CLI
### Setup
In the call to ```CLI.setup()```, a ```name``` must be passed, and a ```version``` and a ```description``` are both optional.
```swift 
CLI.setup(name: "greeter", version: "1.0", description: "Greeter - your own personal greeter")
```
### Registering commands
```swift
CLI.registerCommand(myCommand)
CLI.registerCommands([myCommand, myOtherCommand])
```
### Calling go
In any production app, ```go()``` should be used. This method uses the arguments passed to it on launch.
```swift
CLI.go()
```
When you are creating and debugging your app, ```debugGoWithArgumentString()``` is the better choice. Xcode does make it possible to pass arguments to a command line app on launch by editing the app's scheme, but this can be a pain. ```debugGoWithArgumentString()``` makes it easier to pass an argument string to your app during development.
```swift
CLI.debugGoWithArgumentString("greeter greet")
```

## Commands
There are three ways to create a command. You should decide which way to create your command based on how complex the command will be. In order to highlight the differences between the different command creation methods, the same command "greet" will be implemented each way.

### Implement CommandType
This is usually the best choice for a command. Any command that involves a non-trivial amount of execution or option-handling code should be created with this method. A command subclass provides a structured way to develop a complex command, keeping it organized and easy to read.
```swift
class GreetCommand: CommandType {
    
    let commandName = "greet"
    let commandShortDescription = "Greets the given person"
    let commandSignature = "<person>"
    
    func execute(arguments: CommandArguments) throws  {
        let person = arguments.requiredArgument("person")
        print("Hey there, \(person)!")
    }
    
}
```
### Create a ChainableCommand
This is the most lightweight option. You should only create this kind of command if the command is very simple and doesn't involve a lot of execution or option-handling code. It has all the same capabilities as a subclass of Command does, but it can quickly become bloated and hard to understand if there is a large amount of code involved.
```swift
let greetCommand = ChainableCommand(commandName: "greet")
    .withShortDescription("Greets the given person")
    .withSignature("<person>")
    .withExecutionBlock {(arguments) in
        let person = arguments.requiredArgument("person")
        print("Hey there, \(person)!")
    }
```
```CLI``` also offers a shortcut method to register a ChainableCommand:
```swift
CLI.registerChainableCommand(commandName: "greet")
    .with...
```
### Create a LightweightCommand
This type of command is very similar to ChainableCommand. In fact, all ChainableCommand does is provide an alternative interface to its superclass, LightweightCommand. As with ChainableCommands, this type of command should only be used when the command is relatively simple.
```swift
let greetCommand = LightweightCommand(commandName: "greet")
greetCommand.commandShortDescription = "Greets the given person"
greetCommand.commandSignature = "<person>"
greetCommand.executionBlock = {(arguments) in
    let person = arguments.requiredArgument("person")
    print("Hey there, \(person)!")
}
```


## Parameters
Each command must have a command signature describing its expected/permitted arguments. The command signature is used to map the array of user-passed arguments into a keyed dictionary. When a command is being executed, it is passed this dictionary of arguments, with the command signature segments used as keys and the user-passed arguments as values.

For example, a signature of ```<person> <greeting>``` and a call of ```greeter greet Jack Hello``` would result in the arguments dictionary ```["greeting": "Hello", "person": "Jack"]```.

To set a command's signature:
- **Implement CommandType**: ```var commandSignature: String { get }```
- **ChainableCommand**: ```.withSignature("")```
- **LightweightCommand**: ```cmd.commandSignature = ""```

### Required parameters

Required parameters are surrounded by a less-than and a greater-than sign: ```<requiredParameter>``` If the command is not passed enough arguments to satisfy all required parameters, it will fail.

```bash
~ > # Greet command with a signature of "<person> <greeting>"
~ > greeter greet Jack
Expected 2 arguments, but got 1.
~ > greeter greet Jack Hello
Hello, Jack!
```

### Optional parameters

Optional parameters are surrounded by a less-than and a greater-than sign, and a set of brackets: ```[<optionalParameter>]``` Optional parameters must come after all required parameters.
```bash
~ > # Greet command with a signature of "<person> [<greeting>]"
~ > greeter greet Jack
Hey there, Jack!
~ > greeter greet Jack Hello
Hello, Jack!
``` 

### Collection operator

The collection operator is an ellipses placed at the end of a command signature to signify that the last parameter can take an indefinite number of arguments. It must come at the very end of a command signature, after all required parameters and optional parameters.

```bash
~ > # Greet command with a signature of "<person> ..."
~ > greeter greet Jack
Hey there, Jack!
~ > greeter greet Jack Jill
Hey there, Jack and Jill!
~ > greeter greet Jack Jill Hill
Hey there, Jack, Jill, and Hill!
``` 

The collection operator results in all the last arguments being grouped into an array and passed to the parameter immediately before it (required or optional).

With one argument: ```greeter greet Jack``` -> ```["person": ["Jack"]]```

With multiple arguments: ```greeter greet Jack Jill Hill``` -> ```["person": ["Jack", "Jill", "Hill"]]```

### Accessing arguments

During execution, a command has access to an instance of ```CommandArguments``` that contains the passed arguments which have been keyed using the command signature. Arguments can be accessed with subscripts or the typesafe shortcuts ```CommandArguments``` includes:
```swift
func execute(arguments: CommandArguments) throws  {
    // Given command signature --- <name>
    let name = arguments.requiredArgument("name") // of type String
    
    // Given command signature --- [<name>]
    let name = arguments.optionalArgument("name") // of type String?
    
    // Given command signature --- <names> ...
    let names = arguments.requiredCollectedArgument("names") // of type [String]
    
    // Given command signature --- [<names>] ...
    let names = arguments.optionalCollectedArgument("names") // of type [String]?
}
```

## Options
Commands have support for two types of options: flag options and keyed options. Both types of options can either be denoted by a dash followed by a single letter ```git commit -a``` or two dashes followed by the option name ```git commit --ammend```. Single letter options can be cascaded into a single dash followed by all the desired options: ```git commit -am``` == ```git commit -a -m```.

`ChainableCommand` and ``LightweightCommand` have built in support for option handling, but if you want your custom command class to have this capability, you must implement `OptionCommandType` instead of `CommandType`.

### Flag options
Flag options are simple options that act as boolean switches. For example, if you were to implement "git commit", "-a" would be a flag option.

To configure a command for flag options:
- **Implement OptionCommandType**: 
```swift
func setupOptions(options: Options) {
    options.onFlags([], usage: "") {(flag) in
        
    }
}
```
- **ChainableCommand**: 
```swift
.withOptionsSetup ({(options) in
    options.onFlags([], usage: "") {(flag) in
    
    }
})
```
- **LightweightCommand**: 
```swift
cmd.optionsSetupBlock = {(options) in
    options.onFlags([], usage: "") {(flag) in
        
    }
}
```

The ```GreetCommand``` could be modified to take a "loudly" flag:
```swift
class GreetCommand: OptionCommandType {
    
    private var loudly = false
    
    ...

    func setupOptions(options: Options) {
        options.onFlags(["-l", "--loudly"], usage: "Makes the the greeting be said loudly") {(flag) in
            self.loudly = true
        }
    }
    
    ...
}
```

### Keyed options
Keyed options are options that have an associated value. Using "git commit" as an example again, "-m" would be a keyed option, as it has an associated value - the commit message.

To configure a command for keyed options:
- **Implement OptionCommandType**: 
```
func setupOptions(options: Options) {
    options.onKeys([], usage: "", valueSignature: "") {(key, value) in
    
    }
}
```
- **ChainableCommand**:
```swift
.withOptionsSetup ({(options) in
    options.onKeys([], usage: "", valueSignature: "") {(key, value) in
    
    }
})
```
- **LightweightCommand**: 
```swift
cmd.optionsSetupBlock = {(options) in
    options.onKeys([], usage: "", valueSignature: "") {(key, value) in
    
    }
}
```

The ```GreetCommand``` could be modified to take a "number of times" option:
```swift
class GreetCommand: OptionCommandType {
    
    private var numberOfTimes = 1
    
    ...
    
    func setupOptions(options: Options) {
        options.onKeys(["-n", "--number-of-times"], usage: "Makes the greeter greet a certain number of times", valueSignature: "times") {(key, value) in
            if let times = Int(value) {
                self.numberOfTimes = times
            }
        }
    }
    
    ...
}
```

### Unrecognized options
By default, if a command is passed any options it does not handle through ```onFlag(s)``` or ```onKey(s)```, or their respective equivalents in ```ChainableCommand``` and ```LightweightCommand```, the command will fail. This behavior can be changed to allow unrecognized options:
- **Implement OptionCommandType**: ```var failOnUnrecognizedOptions: Bool { return false }```
- **ChainableCommand**: ```.withFailOnUnrecognizedOptions(false)```
- **LightweightCommand**: ```cmd.failOnUnrecognizedOptions = false```

### Usage of options
As seen in the above examples, ```onFlags``` and ```onKeys``` both take a ```usage``` parameter. A concise description of what the option does should be included here. This allows the command's ```usageStatement()``` to be computed.

A command's ```usageStatement()``` is shown in two situations: 
- The user passed an option that the command does not support -- ```greeter greet -z```
- The command's help was invoked -- ```greeter greet -h```
```bash
~ > greeter greet -h
Usage: greeter greet <person> [options]

-l, --loudly                             Makes the the greeting be said loudly
-n, --number-of-times <times>            Makes the greeter greet a certain number of times
-h, --help                               Show help information for this command
```

The ```valueSignature``` argument in the ```onKeys``` family of methods is displayed like a parameter following the key: ```--my-key <valueSignature>```.

## Routing commands
Command routing is done by an object implementing `RouterType`, which is just one simple method:
```swift
func route(commands: [CommandType], arguments: RawArguments) throws -> CommandType
```
SwiftCLI supplies a default implementation of `RouterType` with `DefaultRouter`. `DefaultRouter` finds commands based on the first passed argument. So, `greeter greet` would search for commmands with the `commandName` of "greet" and `greeter -g` would search for commands with the `commandShortcut` of "-g". 

If a command is not found, `DefaultRouter` falls back to its `defaultCommand`. The `defaultCommand` is usually the help command:
```bash
~ > greeter
Greeter - your own personal greeter

Available commands: 
- greet                Greets the given person
- help                 Prints this help information
```
A custom default command can be specified by calling ```CLI.router = DefaultRouter(defaultCommand: customDefault)```.

## Special commands
```CLI``` has two special commands: ```helpCommand``` and ```versionCommand```.

### Help Command
The ```HelpCommand``` can be invoked with ```myapp help``` or ```myapp -h```. The ```HelpCommand``` first prints the app description (if any was given during ```CLI.setup()```). It then iterates through all available commands, printing their name and their short description.

```bash
~ > greeter help
Greeter - your own personal greeter

Available commands: 
- greet                Greets the given person
- help                 Prints this help information
```

A custom ```HelpCommand``` can be used by calling ```CLI.helpCommand = customHelp```.

### Version Command
The ```VersionCommand``` can be invoked with ```myapp version``` or ```myapp -v```. The VersionCommand prints the version of the app given during ```CLI.setup()```. 

```bash
~ > greeter -v
Version: 1.0
```

A custom ```VersionCommand``` can be used by calling ```CLI.versionComand = customVersion```.

## Input

The `Input` class wraps the handling of input from stdin. Several methods are available:

```swift
// Simple input:
public class func awaitInput(message message: String?) throws -> String {}
public class func awaitInt(message message: String?) throws -> Int {}
public class func awaitYesNoInput(message message: String = "Confirm?") throws -> Bool {}

// Complex input (if the simple input methods are not sufficient):
public class func awaitInputWithValidation(message message: String?, validation: (input: String) -> Bool) throws -> String {}
public class func awaitInputWithConversion<T>(message message: String?, conversion: (input: String) -> T?) throws -> T {}
```

Additionally, the `Input` class makes data piped to the CLI (`echo "piped string" | myCLI command"`) easily available:
```swift
if let pipedData = Input.pipedData {
    print("Something was piped! " + pipedData)
}
```

See the `RecipeCommand` in the example project for a demonstration of all this input functionality.

## Running your CLI

### Within Xcode
There are two methods to pass in arguments to your CLI within Xcode, explained below. After the arguments are set up using one of these methods, you just need to Build and Run, and your app will execute and print its ouput in Xcode's Console.

##### CLI ```debugGoWithArgumentString()```
As discussed before, this is the easiest way to pass arguments to the CLI. Just replace the ```CLI.go()``` call with ```CLI.debugGoWithArgumentString("")```. This is only appropriate for development, as when this method is called, the CLI disregards any arguments passed in on launch.

##### Xcode Scheme
This is not recommended, as the above option is simpler, but it is included for completions's sake. First click on your app's scheme, then "Edit Scheme...". Go to the "Run" section, then the "Arguments" tab. You can then add arguments where it says "Arguments Passed On Launch".

Make sure to use ```CLI.go()``` with this method, **not** ```CLI.debugGoWithArgumentString("")```.

### In Terminal
To actually make your CLI accessible and executable outside of Xcode, you need to add a symbolic link somewhere in your $PATH to the exectuable product Xcode outputs. The easiest way to do this is to click on your project in Xcode, then your executable target, then Build Phases. Add a new Run Script with this command:
```sh
lowercase_name=`echo $PRODUCT_NAME | tr '[A-Z]' '[a-z]'`
new_path=/usr/local/bin/$lowercase_name

if [ ! -f $new_path ]; then ln -s "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME" "$new_path";fi
```
If you would rather have the symbolic link be placed in a different directory on your $PATH, change ```/usr/local/bin``` to your directory of choice. Also, if you would like the app to be executed with a different name then the product name, change the ```lowercase_name``` on the first line to your custom name.

You then need to Build your app once inside of Xcode. From then on, you should be able to access your CLI in your terminal.

Again, be sure to use ```CLI.go()``` with this method, not ```CLI.debugGoWithArgumentString("")```.

## SwiftCLI Installation
### With Swift Package Manager
Add SwiftCLI as a dependency to your project:
```swift
dependencies: [
    .Package(url: "https://github.com/jakeheis/SwiftCLI", majorVersion: 1, minor: 2)
]
```
### With Xcode
In your project directory, run:
```bash
git submodule add https://github.com/jakeheis/SwiftCLI.git
git submodule update --init
```
Then drag the SwiftCLI/SwiftCLI folder into your Xcode project:

![alt tag](https://github.com/jakeheis/SwiftCLI/blob/master/Support/DragScreenshot.png)

![alt tag](https://github.com/jakeheis/SwiftCLI/blob/master/Support/AddFiles.png)

## Example
An example of a CLI developed with SwfitCLI can be found at https://github.com/jakeheis/Baker.
