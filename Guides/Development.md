# Swift Driver Development Guide

## Index
* [Things to Install](#things-to-install)
* [The Code](#the-code)
* [Building](#building)
* [Running Tests](#running-tests)
* [Writing and Generating Documentation](#writing-and-generating-documentation)
* [Linting and Style](#linting-and-style)
* [Workflow](#workflow)
* [Code Review](#code-review)
* [Resources](#resources)

## Things to install
* [swiftenv](https://swiftenv.fuller.li/en/latest/installation.html): a command-line tool that allows easy installation of and switching between versions of Swift.
* [Jazzy](https://github.com/realm/jazzy#installation): the tool we use to generate documentation.
* [SwiftFormat](https://github.com/nicklockwood/SwiftFormat#how-do-i-install-it): the Swift formatter we use.
* [SwiftLint](https://github.com/realm/SwiftLint#using-homebrew): the Swift linter we use.
* [Sourcery](https://github.com/krzysztofzablocki/Sourcery/#installation): the tool we use for code generation.

## The code
You should clone:
- [The driver repository](https://github.com/mongodb/mongo-swift-driver)
- [The BSON library repository](https://github.com/mongodb/swift-bson)
- [The MongoDB Driver specifications](https://github.com/mongodb/specifications)

## Building
### From the Command line
Run `swift build` or simply `make` in the project's root directory.

If you add symbols you may need to run `make exports` which will generate [Sources/MongoSwiftSync/Exports.swift](Sources/MongoSwiftSync/Exports.swift). This makes symbols declared in `MongoSwift` available to importers of `MongoSwiftSync`.

### In Xcode
From the driver root directory, you can run `xed .` to open the project in xcode and be able to build and run there. 

## Running Tests
**NOTE**: Several of the tests require a mongod instance to be running on the default host/port, `localhost:27017`. You can start this by running `mongod --setParameter enableTestCommands=1`. The `enableTestCommands` parameter is required to use some test-only commands built into MongoDB that we utilize in our tests, e.g. `failCommand`.

You can run tests from Xcode as usual. If you prefer to test from the command line, keep reading.

### From the Command Line
We recommend installing the ruby gem `xcpretty` and running tests by executing `make test-pretty`, as this provides output in a much more readable format. (Works on MacOS only.)

Alternatively, you can just run the tests with `swift test`, or `make test`.

To filter tests by regular expression:
- If you are using `swift test`, provide the `--filter` argument: for example, `swift test --filter=MongoClientTests`.
- If you are using `make test` or `make test-pretty`, provide the `FILTER` environment variable: for example, `make test-pretty FILTER=MongoCollectionTests`.

### Diagnosing Backtraces on Linux

[SWIFT-755](https://bugs.swift.org/browse/SR-755) documents an outstanding problem on Linux where backtraces do not contain debug symbols. As discussed in [this Stack Overflow thread](https://stackoverflow.com/a/44956167/162228), a [`symbolicate-linux-fatal`](https://github.com/apple/swift/blob/main/utils/symbolicate-linux-fatal) script may be used to add symbols to an existing backtrace. Consider the following:

```
$ swift test --filter CrashingTest &> crash.log
$ symbolicate-linux-fatal /path/to/MongoSwiftPackageTests.xctest crash.log
```

This will require you to manually provide the path to the compiled test binary (e.g. `.build/x86_64-unknown-linux/debug/MongoSwiftPackageTests.xctest`).

## Writing and Generating Documentation
We document new code as we write it. We use C-style documentation blocks (`/** ... */`) for documentation longer than 3 lines, and triple-slash (`///`) for shorter documentation.
Comments that are _not_ documentation should use two slashes (`//`).

Documentation comments should generally be complete sentences and should end with periods.

Our documentation site is automatically generated from the source code using [Jazzy](https://github.com/realm/jazzy#installation). We regenerate it via our release script each time we release a new version of the driver.

If you'd like to preview how new documentation you've written will look when published, you can regenerate it by running `./etc/generate-docs.sh` and then inspecting the generated HTML files in `/docs`.

## Linting and Style
We use [SwiftLint](https://github.com/realm/SwiftLint#using-homebrew) for linting. You can see our configuration in the `.swiftlint.yml` file in the project's root directory.  Run `swiftlint` in the root directory to lint all of our files. Running `swiftlint --fix` will correct some types of violations.

We use [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) for formatting the code. You can see our configuration in the `.swiftformat` file in the project's root directory. Our linter config contains a superset of the rules that our formatter does, so some manual tweaking may be necessary to satisfy both once the formatter is run (e.g. line length enforcement). Most of the time, the formatter should put the code into a format that passes the linter. You can run the formatter on all of the files by running `swiftformat .` from the root directory.

To pass all the formatting stages of our testing matrix, both `swiftlint --strict` and `swiftformat --lint .` must finish successfully.

`make lint-and-format` runs `swiftlint --fix`, `swiftlint --strict` and `swiftformat --lint .`.

For style guidance, look at Swift's [API design guidelines](https://swift.org/documentation/api-design-guidelines/) and Google's [Swift Style Guide](https://google.github.io/swift/).

## Editor Setup

If you have a setup for developing the driver in an editor other than the ones listed, or have found any useful tools/plugins for the listed editors, please open a pull request to add information!

### Sublime Text
* For syntax highlighting, install [Decent Swift Syntax](https://packagecontrol.io/packages/Decent%20Swift%20Syntax) via Package Control.
* For linting integration with SwiftLint, install [SublimeLinter](https://packagecontrol.io/packages/SublimeLinter) and [SublimeLinter-contrib-swiftlint](https://packagecontrol.io/packages/SublimeLinter-contrib-swiftlint) via Package Control.

### Vim/Neovim
* You can get linting support by using [`ale`](https://github.com/w0rp/ale) by `w0rp`. This will show symbols in the gutter for warnings/errors and show linter messages in the status.
* [swift.vim](https://github.com/Utagai/swift.vim): A fork of Keith Smiley's `swift.vim` with fixed indenting rules. This adds proper indenting and syntax for Swift to Vim. This fork also provides a match rule for column width highlighting.
  * Please read the [NOTICE](https://github.com/Utagai/swift.vim#notice) for proper credits.

### VSCode

* You can get formatting support by searching and installing `vknabel.vscode-swiftformat`
  * You need to add the setting `"swiftformat.enable": true` to either your project or global settings
  * You can add the `"editor.formatOnSave": true` setting to get format on save
* You can get autocomplete and compile checking by searching and installing `vknabel.vscode-swift-development-environment`
  * It should work out of the box but if you run in to issues start with explicitly specifying the language server settings:

```json
"swift.languageServerPath": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp",
"sde.languageServerMode": "sourcekit-lsp",
"sourcekit-lsp.toolchainPath": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain",
```

* If its working and you run into an issue hit Cmd+Shift+P / Cmd+Shift+P and type "reload" to get and run the 'Developer: Reload Window'

## Workflow
1. Create a feature branch, named by the corresponding JIRA ticket if exists, along with a short descriptor of the work: for example, `SWIFT-30/writeconcern`.
1. Do your work on the branch.
1. Ensure your code passes both the linter and the formatter.
1. Make sure your code builds and passes all tests on [Evergreen](https://evergreen.mongodb.com/waterfall/mongo-swift-driver). Our Evergreen matrix tests a variety of MongoDB configurations, operating systems, and Swift language versions, and provides a way to more robustly test the driver. If you work at MongoDB, a new Evergreen build is automatically triggered for every commit to `main` and for every pull request. If you do not work at MongoDB, ask a maintainer to trigger a test run on evergreen for you.
1. Open a pull request on the repository. Make sure you have rebased your branch onto the latest commits on `main`.
1. Go through code review to get the team's approval on your changes. (See the next section on [Code Review](#code-review) for more details on this process.) Once you get the required approvals and your code passes all tests:
1. Rebase on `main` again if needed.
1. Rerun tests.
1. Squash all commits into a single, descriptive commit method, formatted as: `TICKET-NUMBER: Description of changes`. For example, `SWIFT-30: Implement WriteConcern type`.
1. Merge it, or if you don't have permissions, ask someone to merge it for you.

## Code Review

### Giving a review
When giving a review, please batch your comments together to cut down on the number of emails sent to others involved in the pull request. You can do this by going to the "Files Changed" tab. When you post your first comment, press "Start a review". When you're done commenting, click "Finish your review" (top right).
Please feel free to leave reviews on your own code when you open a pull request in order add additional context, point out an aspect of the design you're unsure of, etc.

### Responding to a review
You can use the same batching approach as above to respond to review comments. Once you've posted your responses and pushed new commits addressing the comments, re-request reviews from your reviewers by clicking the arrow circle icons next to their names on the list of reviewers.

**Note**: GitHub allows marking comment threads on pull requests as "resolved", which hides them from view. Always allow the _original commenter_ to resolve a conversation. This allows them to verify that your changes match what they requested before the conversation is hidden.

## Resources

### Swift
* [Swift Language Guide](https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html)
* [Swift Standard Library docs](https://developer.apple.com/documentation/swift)
* [Swift by Sundell](https://www.swiftbysundell.com/)
* [Swift Forums](https://forums.swift.org/)
* Some talks by Kaitlin:
    - [A Swift Introduction to Swift](https://www.youtube.com/watch?v=CcCTM1PN1N4)
    - [Encoding and Decoding in Swift](https://www.youtube.com/watch?v=9GZ8Hiq-Nbc)
    - [Maintaining a Library in a Swiftly Moving Ecosystem](https://www.youtube.com/watch?v=9-fdbG9jNt4)

### MongoDB and Drivers
* [MongoSwift docs](https://mongodb.github.io/mongo-swift-driver/)
* [BSON docs](https://mongodb.github.io/swift-bson)
* [libmongoc docs](http://mongoc.org/libmongoc/current/index.html)
* [libbson docs](http://mongoc.org/libbson/current/index.html)
* [MongoDB docs](https://docs.mongodb.com/)
* [Driver specifications](https://github.com/mongodb/specifications)
