<h1>💬 Nio
  <img src="https://user-images.githubusercontent.com/2625584/69157504-52bb0c00-0ae5-11ea-9794-f0fd7affb307.png"
       align="right" width="128" height="128" />
</h1>

Nio is an upcoming matrix client for iOS.

For the time being this project is still very much a work in progress. For updates, please check by in our matrix room → [#niochat:matrix.org](https://matrix.to/#/#niochat:matrix.org).

Want to give it a spin? Join the public [TestFlight Beta](https://testflight.apple.com/join/KlXr3kKz).

### Getting Started

The following steps should be all that's necessary to build Nio with Xcode. 

```bash
$ git clone https://github.com/kiliankoe/nio.git
$ cd nio
$ gem install cocoapods-keys
$ pod install
$ xed .
```

The cocoapods-keys plugin is used for storing the API key for Microsoft AppCenter, the SDK of which is bundled to gather crashlogs (crashlogs **only**, no analytics). This will be removed altogether once a first version of Nio is released to the App Store, but tracking crash information through TestFlight is unfortunately quite a pain 😕

Running `pod install` will prompt you for *your* API key, feel free to enter whatever gibberish you like.

