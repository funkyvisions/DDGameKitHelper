DDGameKitHelper
===============

A simpler GameKitHelper inspired by Steffen Itterheim's version
(http://www.learn-cocos2d.com). This version takes a different approach
by synchronizing a local cache with game center and visa versa.

Story
---------------

I was having a lot of troubles getting Steffen's library to work nicely
on iOS 4.2 devices.  For one it was trying to write to the root bundle
directory.  I've switch it to write to /Library.

I was also having trouble with achievements not always getting reported
successfully.  I think this has to do with Game Center not being
consistent with callback errors on 4.x devices.  Now everything is kept
cached locally and each time game center comes back online it synchs
both ways.  So if an achievement is reported on game center but not
locally, we re-cache it.  If it's local but not in game center, we
report it.  This allows a fresh install of the app to automatically get
all achievements and scores the first time it starts up.

Steffen's GameKitHelper also did not cache scores.  DDGameKitHelper
keeps track of the high score in each category.  So even though it
reports the score each time (so that daily and weekly comparisons work),
it's only cached locally if the high score has been beat. It also
displays a message banner.

Also, I've implemented a cache per game center user.

DDGameKitHelper only deals with achievements and scores. Since none of
my games use multiplayer I didn't try to tackle an api for that.

Dependencies
---------------

The DDGameKitHelperDelegate class is dependent on Benjamin Borowski's 
GKAchievementNotification class. 

https://github.com/typeoneerror/GKAchievementNotification

It does an excellent job of display a slide down notification that fits in
seamlessly with game center. The only thing I needed to add to it was an
adjustFrame method to compensate for the iPad.

If you don't want to use it, then change pre-processor macro `DDGAMEKIT_USE_NOTIFICATION` to `0` in `DDGameKitHelperDelegate.m` file.

Installation
------------

1. Add the `GameKit` framework to your Xcode project

2. Add the following files to your Xcode project (make sure to select Copy Items in the dialog):
 - DDGameKitHelper.h
 - DDGameKitHelper.m
 - DDGameKitHelperDelegate.h
 - DDGameKitHelperDelegate.m

3. Import the `DDGameKitHelper.h` file

Usage
-----------------------

###Authenticating a player 

<pre>
[[DDGameKitHelper sharedGameKitHelper] authenticateLocalPlayer];
</pre>
###Checking authentication
<pre>
[[DDGameKitHelper sharedGameKitHelper] isLocalPlayerAuthenticated];
</pre>
###Unlocking an achievement 
<pre>
[[DDGameKitHelper sharedGameKitHelper] reportAchievement:@"1"
percentComplete:100];
</pre>
###Reporting a score
<pre>
[[DDGameKitHelper sharedGameKitHelper] submitScore:newscore
category:@"1"];
</pre>
###Showing achievements
<pre>
[[DDGameKitHelper sharedGameKitHelper] showAchievements];
</pre>
###Showing scores
<pre>
[[DDGameKitHelper sharedGameKitHelper] showLeaderboard];
</pre>
<pre>
[[DDGameKitHelper sharedGameKitHelper] showLeaderboardwithCategory:@"LeaderboardID" timeScope:GKLeaderboardTimeScopeAllTime];
where GKLeaderboardTimeScopeAllTime is also available in GKLeaderboardTimeScopeToday and GKLeaderboardTimeScopeWeek
</pre>
###Resetting achievements
<pre>
[[DDGameKitHelper sharedGameKitHelper] resetAchievements];
</pre>

Summary
----------

I know all of this functionality is available in iOS 5.x, but I want to
still support my 4.x users.  This library plays nicely with iOS 4.x and
5.x.

-----------

Doug Davies 
Owner, Funky Visions 
www.funkyvisions.com
