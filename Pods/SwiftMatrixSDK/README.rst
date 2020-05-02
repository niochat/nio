Matrix iOS SDK
==============

This open-source library allows you to build iOS apps compatible with Matrix
(http://www.matrix.org), an open standard for interoperable Instant Messaging
and VoIP.

This SDK implements an interface to communicate with the Matrix Client/Server
API which is defined at http://matrix.org/docs/api/client-server/.


Use the SDK in your app
=======================

The SDK uses CocoaPods (http://cocoapods.org/) as library dependency manager.
In order to set this up::

    sudo gem install cocoapods
    pod setup

The best way to add the last release of the Matrix SDK to your application
project is to add the MatrixSDK dependency to your Podfile::

    # Obj-C
    pod 'MatrixSDK'

    # Swift
    pod 'SwiftMatrixSDK'

If you want to use the develop version of the SDK, use instead:

    # Obj-C
    pod 'MatrixSDK', :git => 'https://github.com/matrix-org/matrix-ios-sdk.git',
    :branch => 'develop'

    # Swift
    pod 'SwiftMatrixSDK', :git => 'https://github.com/matrix-org/matrix-ios-sdk.git',
    :branch => 'develop'


Options
=======
If you want to enable VoIP using the http://webrtc.org VoIP stack, add the following pod to you app Podfile::

    pod 'MatrixSDK/JingleCallStack'


Overview
========

As a quick overview, there are the classes to know to use the SDK.

Matrix API level
----------------
:``MXRestClient``:
    Exposes the Matrix Client-Server API as specified by the Matrix standard to
    make requests to a homeserver.


Business logic and data model
-----------------------------
These classes are higher level tools to handle responses from a homeserver.
They contain logic to maintain consistent chat room data.

:``MXSession``:
    This class handles all data arriving from the homeserver. It uses a
    MXRestClient instance to fetch data from the homeserver, forwarding it to
    MXRoom, MXRoomState, MXRoomMember and MXUser objects.

:``MXRoom``:
     This class provides methods to get room data and to interact with the room
     (join, leave...).

:``MXRoomState``:
     This is the state of room at a certain point in time: its name, topic,
     visibility (public/private), members, etc.

:``MXRoomMember``:
     Represents a member of a room.

:``MXUser``:
     This is a user known by the current user, outside of the context of a
     room. MXSession exposes and maintains the list of MXUsers. It provides
     the user id, displayname and the current presence state

Usage
=====

The sample app (https://github.com/matrix-org/matrix-ios-console)
demonstrates how to build a chat app on top of Matrix. You can refer to it,
play with it, hack it to understand the full integration of the Matrix SDK.
This section comes back to the basics with sample codes for basic use cases.

One file to import:

**Obj-C**::

    #import <MatrixSDK/MatrixSDK.h>

**Swift**::

    import SwiftMatrixSDK

Use case #1: Get public rooms of an homeserver
-----------------------------------------------
This API does not require the user to be authenticated. So, MXRestClient
instantiated with initWithHomeServer does the job:

**Obj-C**::

    MXRestClient *mxRestClient = [[MXRestClient alloc] initWithHomeServer:@"http://matrix.org"];
    [mxRestClient publicRooms:^(NSArray *rooms) {

        // rooms is an array of MXPublicRoom objects containing information like room id
        NSLog(@"The public rooms are: %@", rooms);

    } failure:^(MXError *error) {
    }];

**Swift**::

    let homeServerUrl = URL(string: "http://matrix.org")!
    let mxRestClient = MXRestClient(homeServer: homeServerUrl, unrecognizedCertificateHandler: nil)
    mxRestClient.publicRooms { response in
        switch response {
        case .success(let rooms):

            // rooms is an array of MXPublicRoom objects containing information like room id
            print("The public rooms are: \(rooms)")

        case .failure: break
        }
    }


Use case #2: Get the rooms the user has interacted with
-------------------------------------------------------
Here the user needs to be authenticated. We will use
[MXRestClient initWithCredentials].
You'll normally create and initialise these two objects once the user has
logged in, then keep them throughout the app's lifetime or until the user logs
out:

**Obj-C**::

    MXCredentials *credentials = [[MXCredentials alloc] initWithHomeServer:@"http://matrix.org"
                                                                    userId:@"@your_user_id:matrix.org"
                                                               accessToken:@"your_access_token"];

    // Create a matrix client
    MXRestClient *mxRestClient = [[MXRestClient alloc] initWithCredentials:credentials];

    // Create a matrix session
    MXSession *mxSession = [[MXSession alloc] initWithMatrixRestClient:mxRestClient];

    // Launch mxSession: it will first make an initial sync with the homeserver
    // Then it will listen to new coming events and update its data
    [mxSession start:^{

        // mxSession is ready to be used
        // Now we can get all rooms with:
        mxSession.rooms;

    } failure:^(NSError *error) {
    }];

**Swift**::

    let credentials = MXCredentials(homeServer: "http://matrix.org",
                                    userId: "@your_user_id:matrix.org",
                                    accessToken: "your_access_token")

    // Create a matrix client
    let mxRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)

    // Create a matrix session
    let mxSession = MXSession(matrixRestClient: mxRestClient)

    // Launch mxSession: it will first make an initial sync with the homeserver
    mxSession.start { response in
        guard response.isSuccess else { return }

        // mxSession is ready to be used
        // now wer can get all rooms with:
        mxSession.rooms
    }


Use case #2 (bis): Get the rooms the user has interacted with (using a permanent MXStore)
-----------------------------------------------------------------------------------------
We use the same code as above but we add a MXFileStore that will be in charge of
storing user's data on the file system. This will avoid to do a full sync with the
homeserver each time the app is resumed. The app will be able to resume quickly.
Plus, it will be able to run in offline mode while syncing with the homeserver:

**Obj-C**::

    MXCredentials *credentials = [[MXCredentials alloc] initWithHomeServer:@"http://matrix.org"
                                                                    userId:@"@your_user_id:matrix.org"
                                                               accessToken:@"your_access_token"];

    // Create a matrix client
    MXRestClient *mxRestClient = [[MXRestClient alloc] initWithCredentials:credentials];

    // Create a matrix session
    MXSession *mxSession = [[MXSession alloc] initWithMatrixRestClient:mxRestClient];

    // Make the matrix session open the file store
    // This will preload user's messages and other data
    MXFileStore *store = [[MXFileStore alloc] init];
    [mxSession setStore:store success:^{

        // Launch mxSession: it will sync with the homeserver from the last stored data
        // Then it will listen to new coming events and update its data
        [mxSession start:^{

            // mxSession is ready to be used
            // Now we can get all rooms with:
            mxSession.rooms;

        } failure:^(NSError *error) {
        }];
    } failure:^(NSError *error) {
    }];

**Swift**::

    let credentials = MXCredentials(homeServer: "http://matrix.org",
                                    userId: "@your_user_id:matrix.org",
                                    accessToken: "your_access_token")

    // Create a matrix client
    let mxRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)

    // Create a matrix session
    let mxSession = MXSession(matrixRestClient: mxRestClient)

    // Make the matrix session open the file store
    // This will preload user's messages and other data
    let store = MXFileStore()
    mxSession.setStore(store) { response in
        guard response.isSuccess else { return }

        // Launch mxSession: it will sync with the homeserver from the last stored data
        // Then it will listen to new coming events and update its data
        mxSession.start { response in
            guard response.isSuccess else { return }

            // mxSession is ready to be used
            // now we can get all rooms with:
            mxSession.rooms()
        }
    }




Use case #3: Get messages of a room
-----------------------------------
We reuse the mxSession instance created before:

**Obj-C**::

    // Retrieve the room from its room id
    MXRoom *room = [mxSession room:@"!room_id:matrix.org"];

    // Add a listener on events related to this room
    [room.liveTimeline listenToEvents:^(MXEvent *event, MXEventDirection direction, MXRoomState *roomState) {

        if (direction == MXTimelineDirectionForwards) {
            // Live/New events come here
        }
        else if (direction == MXTimelineDirectionBackwards) {
            // Events that occurred in the past will come here when requesting pagination.
            // roomState contains the state of the room just before this event occurred.
        }
    }];

**Swift**::

    // Retrieve the room from its room id
    let room = mxSession.room(withRoomId: "!room_id:matrix.org")

    // Add a listener on events related to this room
    _ = room?.liveTimeline.listenToEvents { (event, direction, roomState) in
        switch direction {
        case .forwards:
            // Live/New events come here
            break

        case .backwards:
            // Events that occurred in the past will come here when requesting pagination.
            // roomState contains the state of the room just before this event occurred.
            break
        }
    }


Let's load a bit of room history using paginateBackMessages:

**Obj-C**::

    // Reset the pagination start point to now
    [room.liveTimeline resetPagination];

    [room.liveTimeline paginate:10 direction:MXTimelineDirectionBackwards onlyFromStore:NO complete:^{

        // At this point, the SDK has finished to enumerate the events to the attached listeners

    } failure:^(NSError *error) {
    }];

**Swift**::

    // Reset the pagination start point to now
    room?.liveTimeline.resetPagination()

    room?.liveTimeline.paginate(10, direction: .backwards, onlyFromStore: false) { _ in
        // At this point, the SDK has finished to enumerate the events to the attached listeners
    }



Use case #4: Post a text message to a room
------------------------------------------
This action does not require any business logic from MXSession: We can use
MXRestClient directly:

**Obj-C**::

    [mxRestClient sendTextMessageToRoom:@"the_room_id" text:@"Hello world!" success:^(NSString *event_id) {

        // event_id is for reference
        // If you have registered events listener like in the previous use case, you will get
        // a notification for this event coming down from the homeserver events stream and
        // now handled by MXSession.

    } failure:^(NSError *error) {
    }];

**Swift**::

    client.sendTextMessage(toRoom: "the_room_id", text: "Hello World!") { (response) in
        if case .success(let eventId) = response {
            // eventId is for reference
            // If you have registered events listener like in the previous use case, you will get
            // a notification for this event coming down from the homeserver events stream and
            // now handled by MXSession.
        }
    }

Push Notifications
==================

In Matrix, a homeserver can send notifications out to a user when events
arrive for them. However in APNS, only you, the app developer, can send APNS
notifications because doing so requires your APNS private key. Matrix
therefore requires a seperate server decoupled from the homeserver to send
Push Notifications, as you cannot trust arbitrary homeservers with your
application's APNS private key. This is called the 'Push Gateway'. More about
how notifications work in Matrix can be found at
https://matrix.org/docs/spec/push_gateway/latest.html

In simple terms, for your application to receive push notifications, you will
need to set up a push gateway. This is a publicly accessible server specific
to your particular iOS app that receives HTTP POST requests from Matrix Home
Servers and sends APNS. Matrix provides a reference push gateway, 'sygnal',
which can be found at https://github.com/matrix-org/sygnal along with
instructions on how to set it up.

You can also write your own Push Gateway. See
https://matrix.org/docs/spec/push_gateway/latest.html
for the specification on the HTTP Push Notification protocol. Your push
gateway can listen for notifications on any path (as long as your app knows
that path in order to inform the homeserver) but Matrix strongly recommends
that the path of this URL be
'/_matrix/push/v1/notify'.

In your application, you will first register for APNS in the normal way
(assuming iOS 8 or above)::

    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIRemoteNotificationTypeBadge
                                                                                         |UIRemoteNotificationTypeSound
                                                                                         |UIRemoteNotificationTypeAlert)
                                                                                         categories:nil];
    [...]

    - (void)application:(UIApplication *)application
            didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
    {
        [application registerForRemoteNotifications];
    }

When you receive the APNS token for this particular application instance, you
then encode this into text and use it as the 'pushkey' to call
setPusherWithPushkey in order to tell the homeserver to send pushes to this
device via your push gateway's URL. Matrix recommends base 64
encoding for APNS tokens (as this is what sygnal uses)::

    - (void)application:(UIApplication*)app
      didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
        NSString *b64Token = [self.deviceToken base64EncodedStringWithOptions:0];
        NSDictionary *pushData = @{
            @"url": @"https://example.com/_matrix/push/v1/notify" // your push gateway URL
        };
        NSString *deviceLang = [NSLocale preferredLanguages][0];
        NSString *profileTag = makeProfileTag(); // more about this later
        MXRestClient *restCli = [MatrixSDKHandler sharedHandler].mxRestClient;
        [restCli
            setPusherWithPushkey:b64Token
            kind:@"http"
            appId:@"com.example.supercoolmatrixapp.prod"
            appDisplayName:@"My Super Cool Matrix iOS App"
            deviceDisplayName:[[UIDevice currentDevice] name]
            profileTag:profileTag
            lang:deviceLang
            data:pushData
            success:^{
                // Hooray!
            } failure:^(NSError *error) {
                // Some super awesome error handling goes here
            }
        ];
    }

When you call setPusherWithPushkey, this creates a pusher on the homeserver
that your session is logged in to. This will send HTTP notifications to a URL
you supply as the 'url' key in the 'data' argument to setPusherWithPushkey.

You can read more about these parameters in the Client / Server specification
(http://matrix.org/docs/api/client-server/#!/Push32notifications/post_matrix_client_r0_pushers_set). A
little more information about some of these parameters is included below:

appId
  This has two purposes: firstly to form the namespace in which your pushkeys
  exist on a homeserver, which means you should use something unique to your
  application: a reverse-DNS style identifier is strongly recommended. Its
  second purpose is to identify your application to your Push Gateway, such that
  your Push Gateway knows which private key and certificate to use when talking
  to the APNS gateway. You should therefore use different app IDs depending on
  whether your application is in production or sandbox push mode so that your
  Push Gateway can send the APNS accordingly. Matrix recommends suffixing your
  appId with '.dev' or '.prod' accordingly.

profileTag
  This identifies which set of push rules this device should obey. For more
  information about push rules, see the Client / Server push specification:
  http://matrix.org/docs/api/client-server/#!/Push32notifications/post_matrix_client_r0_pushers_set
  This is an identifier for the set of device-specific push rules that this
  device will obey. The recommendation is to auto-generate a 16 character
  alphanumeric string and use this string for the lifetime of the application
  data. More advanced usage of this will allow for several devices sharing a set
  of push rules.

Development
===========

The repository contains a Xcode project in order to develop. This project does
not build an app but a test suite. See the next section to set the test
environment.

Before opening the Matrix SDK Xcode workspace, you need to build it.

The project has some third party library dependencies declared in a pod file.
You need to run the CocoaPods command to download them and to set up the Matrix
SDK workspace::

        $ pod install

Then, open ``MatrixSDK.xcworkspace``.

Tests
=====
The tests in the SDK Xcode project are both unit and integration tests.

Out of the box, the tests use one of the homeservers (located at
http://localhost:8080) of the "Demo Federation of Homeservers"
(https://github.com/matrix-org/synapse#running-a-demo-federation-of-synapses). 

You first need to follow instructions to set up Synapse in development mode at https://github.com/matrix-org/synapse#synapse-development.
If you have already installed all dependencies, the steps are::

      $ git clone https://github.com/matrix-org/synapse.git
      $ cd synapse
      $ virtualenv -p python3 env
      $ source env/bin/activate
      (env) $ python -m pip install --no-use-pep517 -e .

Every time you want to launch these test homeservers, type::

      $ virtualenv -p python3 env
      $ source env/bin/activate
      (env) $ demo/start.sh --no-rate-limit

You can now run tests from the Xcode Test navigator tab or select the
MatrixSDKTests scheme and click on the "Test" action.

Known issues
============

CocoaPods may fail to install on OSX 10.8.x with "i18n requires Ruby version
>= 1.9.3.".  This is a known problem similar to
https://github.com/CocoaPods/CocoaPods/issues/2458 that needs to be raised with
the cocoapods team.

### Dynamic Framework: Undefined symbols for architecture

If you are using "MatrixSDK" instead of "SwiftMatrixSDK", you may get a compile-
time error that looks like this::

    Undefined symbols for architecture x86_64:
      "_OBJC_CLASS_$_GAIDictionaryBuilder", referenced from:
          objc-class-ref in MXGoogleAnalytics.o
      "_OBJC_CLASS_$_GAI", referenced from:
          objc-class-ref in MXGoogleAnalytics.o
    ld: symbol(s) not found for architecture x86_64
    clang: error: linker command failed with exit code 1 (use -v to see invocation)

This happens when both of the following are true:

1. The MatrixSDK was compiled as a framework (i.e. the `use_frameworks!` setting
is enabled in your podfile)
2. Your project also uses the Google Analytics pod.

The root cause is that the `MXGoogleAnalytics` class recognizes that the Google
Analytics pod was included in your project, and attempts to include its headers.
This type of behavior is allowed in a Static Library, but it is not allowed in a
Dynamic Framework.

The easiest workaround is to switch to the "SwiftMatrixSDK" pod, even if you
don't use Swift (for an Obj-C project, the pods are virtually the same). The
"SwiftMatrixSDK" excludes the `MXGoogleAnalytics` class. If you want to collect
analytics data about initialization times (and so forth), you can implement your
own `MXAnalyticsDelegate` and set an instance to `MXSDKOptions.sharedInstance`.
See `MXAnalyticsDelegate.h` and `MXGoogleAnalytics.h/m` for more information.

Registration
------------
The SDK currently manages only login-password type registration.
This type of registration is not accepted by the homeserver hosted at
matrix.org. It has been disabled for security and spamming reasons.
So, for now, you will be not be able to register a new account with the SDK on
such homeserver. But you can login an existing user.

If you run your own homeserver, the default launch parameters enables the
login-password type registration and you will be able to register a new user to it.

Copyright & License
==================

Copyright (c) 2014-2017 OpenMarket Ltd
Copyright (c) 2017 Vector Creations Ltd
Copyright (c) 2017-2018 New Vector Ltd

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this work except in compliance with the License. You may obtain a copy of the License in the LICENSE file, or at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
