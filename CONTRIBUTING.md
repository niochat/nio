# Contributing to Nio

First off, thanks for taking the time to contribute! 😍🥳
There are several ways you can leave your mark, we're extremely glad to have you!

## Feedback

At the current time, Nio is not yet ready for an actual release on the App Store. Many essential features are [still 
missing](https://github.com/niochat/nio/issues?q=is%3Aopen+is%3Aissue+label%3Aessential). Current builds are distributed via
[TestFlight](https://testflight.apple.com/join/KlXr3kKz). We heavily rely on people installing these builds and telling us
if other things are not yet working as expected or if there are bugs in the existing features.

Should you come across anything in that regard, be it as simple as a typo in the app's description, behavior that doesn't feel
correct, a crash of the application or *anything* else, please reach out. Either by [opening an 
issue](https://github.com/niochat/nio/issues/new) directly on GitHub, sending a message in our Matrix room 
[#niochat:matrix.org](https://matrix.to/#/#niochat:matrix.org) or via mail to 
[team@nio.chat](mailto:team@nio.chat). 

Please also feel free to comment on existing issues and pull requests. A new opinion, viewpoint or even just an upvote is 
always good to have.

We know we're still far away from the goal, but Nio is aiming to be as inclusive as possible and while trying to do our best,
we also rely on people like you telling us if things are anywhere between unclear and confusing or just downright wrong.

Thank you! ❤️

## Localization

As Nio aims to be accessible by anyone from around the globe, it's important to have Nio speak as many languages as possible.
Nio uses a tool called Weblate running on [translate.riot.im](https://translate.riot.im/engage/nio) to manage 
translation files. Unfortunately you do need an account there, but it's of course free and easy to register for one. After
doing that you can fix and modify existing translations or add new languages altogether, both of which are *highly* 
appreciated!

If Weblate isn't to your liking and you prefer a text editor and git, feel free to edit the translations directly in the 
project's repository. They're synchronized both ways.

This is the current status of the translations:

[![Translation status](https://translate.riot.im/widgets/nio/-/nio/multi-auto.svg)](https://translate.riot.im/engage/nio/?utm_source=widget)

## Implementation

Nio has (and probably always will have 😅) a [long list of open issues](https://github.com/niochat/nio/issues). You are more
than *extremely* welcome to tackle any of these and send pull requests.

***Note***: Please be aware that Nio builds against the iOS 14 SDK and thus currently requires the Xcode 12 Beta. Download a copy from [Apple's Developer Portal](https://developer.apple.com/download).

### Dependencies
Nio manages most of its dependencies via Swift package manager, which Xcode handles automatically. The `matrix-ios-sdk` 
however is integrated via Cocoapods (for the time being) which makes installing that necessary to setup a local checkout of 
the project.

```shell
$ pod install
```

### Automatic Signing
In order to use automatic signing in Xcode, it is possible to create
`Configs/LocalConfig.xcconfig` and override the default values. For more info
have a look [here](https://www.matrixprojects.net/p/xcconfig-for-shared-projects/).

If you are unsure where to start or have other questions, please reach out, preferably via Matrix in
[#niochat:matrix.org](https://matrix.to/#/#niochat:matrix.org) or whatever works for you 😊
