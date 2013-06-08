//
//  DDGameKitHelper.m
//  Version 1.0
//
//  Inspired by Steffen Itterheim's GameKitHelper

#import "DDGameKitHelper.h"
#import "DDGameKitHelperDelegate.h"
#import <CommonCrypto/CommonDigest.h>

// -----------------------------------------------------------------

static NSString* kAchievementsFile = @".achievements";
static NSString* kScoresFile = @".scores";

// -----------------------------------------------------------------

@interface DDGameKitHelper (Private)
// Init
- (void) initScores;
- (void) initAchievements;
- (void) loadAchievementDescriptions;
// Saving
- (void) saveScores;
- (void) saveAchievements;
// Synchronizing
- (void) synchronizeAchievements;
- (void) synchronizeScores;
// Authentication
- (void) registerForLocalPlayerAuthChange;
// Getters
- (UIViewController*) getRootViewController;
- (GKScore*) getScoreByCategory:(NSString*)category;
- (GKAchievement*) getAchievement:(NSString*)identifier;
@end

// -----------------------------------------------------------------
@implementation DDGameKitHelper
// -----------------------------------------------------------------

// -----------------------------------------------------------------
#pragma mark - Singleton
#pragma mark -
// -----------------------------------------------------------------

+ (instancetype) sharedGameKitHelper
{
    dispatch_once_t pred;
    __strong static DDGameKitHelper *sharedGameKitHelper = nil;
    
    dispatch_once(&pred, ^{
        sharedGameKitHelper = [[self alloc] init];
    });
    
    return sharedGameKitHelper;
}

// -----------------------------------------------------------------
#pragma mark - 00 Init & Dealloc
#pragma mark -
// -----------------------------------------------------------------

- (instancetype) init
{
    if ((self = [super init]))
    {
        _delegate = [[DDGameKitHelperDelegate alloc] init];
        
        // Test for Game Center availability
        Class gameKitLocalPlayerClass = NSClassFromString(@"GKLocalPlayer");
        bool isLocalPlayerAvailable = (gameKitLocalPlayerClass != nil);
        
        // Test if device is running iOS 4.1 or higher
        NSString* reqSysVer = @"4.1";
        NSString* currSysVer = [[UIDevice currentDevice] systemVersion];
        bool isOSVer41 = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
        
        _isGameCenterAvailable = (isLocalPlayerAvailable && isOSVer41);
        if (DDGAMEKIT_LOGGING == 1) NSLog(@"GameCenter available = %@", _isGameCenterAvailable ? @"YES" : @"NO");
        
        if (_isGameCenterAvailable)
            [self registerForLocalPlayerAuthChange];
    }
    
    return self;
}

// -----------------------------------------------------------------

- (void) dealloc
{
    [self saveScores];
    [self saveAchievements];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

// -----------------------------------------------------------------
#pragma mark - 01 Public
#pragma mark -
#pragma mark a) Availability
// -----------------------------------------------------------------

- (void) setNotAvailable
{
    _isGameCenterAvailable = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// -----------------------------------------------------------------

- (BOOL) isAvailable
{
    return _isGameCenterAvailable;
}

// -----------------------------------------------------------------
#pragma mark b) Authentication
// -----------------------------------------------------------------

- (void) authenticateLocalPlayer
{
    if (_isGameCenterAvailable == NO)
        return;
    
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if (localPlayer.authenticated == NO)
    {
        [localPlayer authenticateWithCompletionHandler:^(NSError* error)
         {
             if (error != nil)
             {
                 if (DDGAMEKIT_LOGGING == 1) NSLog(@"error authenticating player: %@", [error localizedDescription]);
             }
             else
             {
                 if (DDGAMEKIT_LOGGING == 1) NSLog(@"player authenticated");
             }
         }];
    }
}

// -----------------------------------------------------------------

- (BOOL) isLocalPlayerAuthenticated
{
	if (_isGameCenterAvailable == NO)
		return _isGameCenterAvailable;
    
	GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
	return localPlayer.authenticated;
}

// -----------------------------------------------------------------
#pragma mark c) Submit Progress
// -----------------------------------------------------------------

- (void) submitScore:(int64_t)value category:(NSString*)category
{
    if (_isGameCenterAvailable == NO)
        return;
    
    // always report the new score
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"reporting score of %lld for %@", value, category);
    GKScore* newScore = [[GKScore alloc] initWithCategory:category];
    newScore.value = value;
    [newScore reportScoreWithCompletionHandler:^(NSError* error)
     {
         // if it's better than the previous score, then save it and notify the user
         GKScore* score = [self getScoreByCategory:category];
         if ([_delegate compareScore:value toScore:score.value])
         {
             if (DDGAMEKIT_LOGGING == 1) NSLog(@"new high score of %lld for %@", score.value, category);
             score.value = value;
             [self saveScores];
             [_delegate onSubmitScore:value];
         }
     }];
    
}

// -----------------------------------------------------------------

- (void) reportAchievement:(NSString*)identifier percentComplete:(float)percent
{
    if (_isGameCenterAvailable == NO)
        return;
    
    GKAchievement* achievement = [self getAchievement:identifier];
    if (achievement.percentComplete < percent)
    {
        if (DDGAMEKIT_LOGGING == 1) NSLog(@"new achievement %@ reported", achievement.identifier);
        achievement.percentComplete = percent;
        [achievement reportAchievementWithCompletionHandler:^(NSError* error)
         {
             [_delegate onReportAchievement:(GKAchievement*)achievement];
         }];
        
        [self saveAchievements];
    }
}

// -----------------------------------------------------------------
#pragma mark d) Resetting Achievements
// -----------------------------------------------------------------

- (void) resetAchievements
{
    if (_isGameCenterAvailable == NO)
        return;
    
    [_achievements removeAllObjects];
    [self saveAchievements];
    
    [GKAchievement resetAchievementsWithCompletionHandler:^(NSError* error) {}];
    
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"achievements reset");
}
// -----------------------------------------------------------------
#pragma mark e) Showing Game Center
// -----------------------------------------------------------------

- (void) showGameCenter
{
    if (_isGameCenterAvailable == NO)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center" message:@"Game Center is not available" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil, nil];
        [alert show];
        
        return;
    }
    
    if ([GKGameCenterViewController class])
    {
        GKGameCenterViewController *gameCenterController = [[GKGameCenterViewController alloc] init];
        if (gameCenterController != nil)
        {
            gameCenterController.gameCenterDelegate = self;
            [self presentViewController:gameCenterController];
        }
    }
    else
    {
        [self showLeaderboard];
    }
}

// -----------------------------------------------------------------

- (void) showLeaderboard
{
    if (_isGameCenterAvailable == NO)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center" message:@"Game Center is not available" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil, nil];
        [alert show];
        
        return;
    }
    
    GKLeaderboardViewController* leaderboardVC = [[GKLeaderboardViewController alloc] init];
    if (leaderboardVC != nil)
    {
        leaderboardVC.leaderboardDelegate = self;
        [self presentViewController:leaderboardVC];
    }
}

// -----------------------------------------------------------------

- (void) showLeaderboardWithCategory:(NSString*)category timeScope:(int)tscope
{
    if (_isGameCenterAvailable == NO)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center" message:@"Game Center is not available" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil, nil];
        [alert show];
        
        return;
    }
    
    GKLeaderboardViewController* leaderboardVC = [[GKLeaderboardViewController alloc] init];
    if (leaderboardVC != nil)
    {
        leaderboardVC.leaderboardDelegate = self;
        leaderboardVC.category = category;
        leaderboardVC.timeScope = tscope;
        [self presentViewController:leaderboardVC];
    }
}

// -----------------------------------------------------------------

- (void) showAchievements
{
    if (_isGameCenterAvailable == NO)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center" message:@"Game Center is not available" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil, nil];
        [alert show];
        
        return;
    }
    
    GKAchievementViewController* achievementsVC = [[GKAchievementViewController alloc] init];
    if (achievementsVC != nil)
    {
        achievementsVC.achievementDelegate = self;
        [self presentViewController:achievementsVC];
    }
}

// -----------------------------------------------------------------
#pragma mark f) Achievement Numbers
// -----------------------------------------------------------------

- (int) numberOfTotalAchievements
{
    int count = 0;
    if (_isGameCenterAvailable)
    {
        count = [_achievementDescriptions allValues].count;
    }
    return count;
}


// -----------------------------------------------------------------

- (int) numberOfCompletedAchievements
{
    int count = 0;
    if (_isGameCenterAvailable)
    {
        NSArray* gcAchievementsArray = [_achievements allValues];
        for (GKAchievement* gcAchievement in gcAchievementsArray)
        {
            if (gcAchievement.completed)
                count++;
        }
    }
    return count;
}

// -----------------------------------------------------------------
#pragma mark g) Achievement Description
// -----------------------------------------------------------------

- (GKAchievementDescription*) getAchievementDescription:(NSString*)identifier
{
    GKAchievementDescription* description = [_achievementDescriptions objectForKey:identifier];
    return description;
}

// -----------------------------------------------------------------
#pragma mark - 02 Private
#pragma mark -
#pragma mark a) Init
// -----------------------------------------------------------------

- (void) initScores
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:_currentPlayerID];
    file = [file stringByAppendingString:kScoresFile];
    id object = [NSKeyedUnarchiver unarchiveObjectWithFile:file];
    
    if ([object isKindOfClass:[NSMutableDictionary class]])
    {
        NSMutableDictionary* loadedScores = (NSMutableDictionary*)object;
        _scores = [[NSMutableDictionary alloc] initWithDictionary:loadedScores];
    }
    else
    {
        _scores = [[NSMutableDictionary alloc] init];
    }
    
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"scores initialized: %d", _scores.count);
}

// -----------------------------------------------------------------

- (void) initAchievements
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:_currentPlayerID];
    file = [file stringByAppendingString:kAchievementsFile];
    id object = [NSKeyedUnarchiver unarchiveObjectWithFile:file];
    
    if ([object isKindOfClass:[NSMutableDictionary class]])
    {
        NSMutableDictionary* loadedAchievements = (NSMutableDictionary*)object;
        _achievements = [[NSMutableDictionary alloc] initWithDictionary:loadedAchievements];
    }
    else
    {
        _achievements = [[NSMutableDictionary alloc] init];
    }
    
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"achievements initialized: %d", _achievements.count);
}

// -----------------------------------------------------------------

- (void)loadAchievementDescriptions
{
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"loading achievement descriptions");
    
    [GKAchievementDescription loadAchievementDescriptionsWithCompletionHandler:^(NSArray *achievementDesc, NSError *error)
     {
         _achievementDescriptions = [[NSMutableDictionary alloc] init];
         
         if (error != nil)
         {
             if (DDGAMEKIT_LOGGING == 1) NSLog(@"unable to load achievements");
             return;
         }
         
         for (GKAchievementDescription *description in achievementDesc)
         {
             [_achievementDescriptions setObject:description forKey:description.identifier];
         }
         
         if (DDGAMEKIT_LOGGING == 1) NSLog(@"achievement descriptions initialized: %d", _achievementDescriptions.count);
     }];
}

// -----------------------------------------------------------------
#pragma mark b) Saving
// -----------------------------------------------------------------

- (void) saveScores
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:_currentPlayerID];
    file = [file stringByAppendingString:kScoresFile];
    [NSKeyedArchiver archiveRootObject:_scores toFile:file];
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"scores saved: %d", _scores.count);
}

// -----------------------------------------------------------------

- (void) saveAchievements
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:_currentPlayerID];
    file = [file stringByAppendingString:kAchievementsFile];
    [NSKeyedArchiver archiveRootObject:_achievements toFile:file];
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"achievements saved: %d", _achievements.count);
}

// -----------------------------------------------------------------
#pragma mark c) Synchronizing
// -----------------------------------------------------------------

- (void) synchronizeScores
{
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"synchronizing scores");
    
    // get the top score for each category for current player and compare it to the game center score for the same category
    
    [GKLeaderboard loadCategoriesWithCompletionHandler:^(NSArray *categories, NSArray *titles, NSError *error)
     {
         if (error != nil)
         {
             if (DDGAMEKIT_LOGGING == 1) NSLog(@"unable to synchronize scores");
             return;
         }
         
         NSString* playerId = [GKLocalPlayer localPlayer].playerID;
         
         for (NSString* category in categories)
         {
             GKLeaderboard *leaderboardRequest = [[GKLeaderboard alloc] initWithPlayerIDs:[NSArray arrayWithObject:playerId]];
             leaderboardRequest.category = category;
             leaderboardRequest.timeScope = GKLeaderboardTimeScopeAllTime;
             leaderboardRequest.range = NSMakeRange(1,1);
             [leaderboardRequest loadScoresWithCompletionHandler: ^(NSArray *playerScores, NSError *error)
              {
                  if (error != nil)
                  {
                      if (DDGAMEKIT_LOGGING == 1) NSLog(@"unable to synchronize scores");
                      return;
                  }
                  
                  GKScore* gcScore = nil;
                  if ([playerScores count] > 0)
                      gcScore = [playerScores objectAtIndex:0];
                  GKScore* localScore = [_scores objectForKey:category];
                  
                  //Must add the next two lines in order to prevent a 'A GKScore must contain an initialized value' crash
                  GKScore *toReport = [[GKScore alloc] initWithCategory:category];
                  toReport.value = localScore.value;
                  
                  if (gcScore == nil && localScore == nil)
                  {
                      if (DDGAMEKIT_LOGGING == 1) NSLog(@"%@(%lld,%lld): no score yet. nothing to synch", category, gcScore.value, localScore.value);
                  }
                  
                  else if (gcScore == nil)
                  {
                      if (DDGAMEKIT_LOGGING == 1) NSLog(@"%@(%lld,%lld): gc score missing. reporting local score", category, gcScore.value, localScore.value);
                      [localScore reportScoreWithCompletionHandler:^(NSError* error) {}];
                  }
                  
                  else if (localScore == nil)
                  {
                      if (DDGAMEKIT_LOGGING == 1) NSLog(@"%@(%lld,%lld): local score missing. caching gc score", category, gcScore.value, localScore.value);
                      [_scores setObject:gcScore forKey:gcScore.category];
                      [self saveScores];
                  }
                  
                  else if ([_delegate compareScore:localScore.value toScore:gcScore.value])
                  {
                      if (DDGAMEKIT_LOGGING == 1) NSLog(@"%@(%lld,%lld): local score more current than gc score. reporting local score", category, gcScore.value, localScore.value);
                      [toReport reportScoreWithCompletionHandler:^(NSError* error) {}];
                  }
                  
                  else if ([_delegate compareScore:gcScore.value toScore:localScore.value])
                  {
                      if (DDGAMEKIT_LOGGING == 1) NSLog(@"%@(%lld,%lld): gc score is more current than local score. caching gc score", category, gcScore.value, localScore.value);
                      [_scores setObject:gcScore forKey:gcScore.category];
                      [self saveScores];
                  }
                  
                  else
                  {
                      if (DDGAMEKIT_LOGGING == 1) NSLog(@"%@(%lld,%lld): scores are equal. nothing to synch", category, gcScore.value, localScore.value);
                  }
              }];
             
         }
     }];
}

// -----------------------------------------------------------------

- (void) synchronizeAchievements
{
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"synchronizing achievements");
    
    // get the achievements from game center
    
    [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray* gcAchievementsArray, NSError* error)
     {
         if (error != nil)
         {
             if (DDGAMEKIT_LOGGING == 1) NSLog(@"unable to synchronize achievements");
             return;
         }
         
         // convert NSArray into NSDictionary for ease of use
         NSMutableDictionary *gcAchievements = [[NSMutableDictionary alloc] init];
         for (GKAchievement* gcAchievement in gcAchievementsArray)
         {
             [gcAchievements setObject:gcAchievement forKey:gcAchievement.identifier];
         }
         
         // find local achievements not yet reported in game center and report them
         for (NSString* identifier in _achievements)
         {
             GKAchievement *gcAchievement = [gcAchievements objectForKey:identifier];
             if (gcAchievement == nil)
             {
                 if (DDGAMEKIT_LOGGING == 1) NSLog(@"achievement %@ not in game center. reporting it", identifier);
                 [[_achievements objectForKey:identifier] reportAchievementWithCompletionHandler:^(NSError* error) {}];
             }
         }
         
         // find game center achievements that are not reported locally and store them
         for (GKAchievement* gcAchievement in gcAchievementsArray)
         {
             GKAchievement* localAchievement = [_achievements objectForKey:gcAchievement.identifier];
             if (localAchievement == nil)
             {
                 if (DDGAMEKIT_LOGGING == 1) NSLog(@"achievement %@ not stored locally. storing it", gcAchievement.identifier);
                 [_achievements setObject:gcAchievement forKey:gcAchievement.identifier];
             }
         }
         
         [self saveAchievements];
         
     }];
}

// -----------------------------------------------------------------
#pragma mark d) Authentication
// -----------------------------------------------------------------

- (void) onLocalPlayerAuthenticationChanged
{
    NSString* newPlayerID;
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    
    // if not authenticating then just return
    
    if (!localPlayer.isAuthenticated)
    {
        return;
    }
    
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"onLocalPlayerAuthenticationChanged. reloading scores and achievements and resynchronzing.");
    
    if (localPlayer.playerID != nil)
    {
        newPlayerID = [self returnMD5Hash:localPlayer.playerID];
    }
    else
    {
        newPlayerID = @"unknown";
    }
    
    if (_currentPlayerID != nil && [_currentPlayerID compare:newPlayerID] == NSOrderedSame)
    {
        if (DDGAMEKIT_LOGGING == 1) NSLog(@"player is the same");
        return;
    }
    
    self.currentPlayerID = newPlayerID;
    if (DDGAMEKIT_LOGGING == 1) NSLog(@"currentPlayerID=%@", _currentPlayerID);
    
    [self initScores];
    [self initAchievements];
    
    [self synchronizeScores];
    [self synchronizeAchievements];
    [self loadAchievementDescriptions];
}

// -----------------------------------------------------------------

- (void) registerForLocalPlayerAuthChange
{
    if (_isGameCenterAvailable == NO)
        return;
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(onLocalPlayerAuthenticationChanged) name:GKPlayerAuthenticationDidChangeNotificationName object:nil];
}

// -----------------------------------------------------------------
#pragma mark e) Getters
// -----------------------------------------------------------------

- (GKScore*) getScoreByCategory:(NSString*)category
{
    GKScore* score = [_scores objectForKey:category];
    
    if (score == nil)
    {
        score = [[GKScore alloc] initWithCategory:category];
        score.value = 0;
        [_scores setObject:score forKey:category];
    }
    
    return score;
}

// -----------------------------------------------------------------

- (GKAchievement*) getAchievement:(NSString*)identifier
{
    GKAchievement* achievement = [_achievements objectForKey:identifier];
    
    if (achievement == nil)
    {
        achievement = [[GKAchievement alloc] initWithIdentifier:identifier];
        [_achievements setObject:achievement forKey:achievement.identifier];
    }
    
    return achievement;
}

// -----------------------------------------------------------------

- (UIViewController*) getRootViewController
{
    return [UIApplication sharedApplication].keyWindow.rootViewController;
}

// -----------------------------------------------------------------
#pragma mark f) View Controllers
// -----------------------------------------------------------------

- (void) presentViewController:(UIViewController*)vc
{
    UIViewController* rootVC = [self getRootViewController];
    [rootVC presentModalViewController:vc animated:YES];
}

// -----------------------------------------------------------------

- (void) dismissModalViewController
{
    UIViewController* rootVC = [self getRootViewController];
    [rootVC dismissModalViewControllerAnimated:YES];
}

// -----------------------------------------------------------------

- (void) gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController
{
    [self dismissModalViewController];
}

// -----------------------------------------------------------------

- (void) leaderboardViewControllerDidFinish:(GKLeaderboardViewController*)viewController
{
    [self dismissModalViewController];
}

// -----------------------------------------------------------------

- (void) achievementViewControllerDidFinish:(GKAchievementViewController*)viewController
{
    [self dismissModalViewController];
}

// -----------------------------------------------------------------
#pragma mark g) Other
// -----------------------------------------------------------------

- (NSString *) returnMD5Hash:(NSString*)concat
{
    const char *concat_str = [concat UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(concat_str, strlen(concat_str), result);
    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < 16; i++)
    {
        [hash appendFormat:@"%02X", result[i]];
    }
    
    return [hash lowercaseString];
}

// -----------------------------------------------------------------
@end
// -----------------------------------------------------------------
