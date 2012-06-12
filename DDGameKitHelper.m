//
//  DDGameKitHelper.m
//  Version 1.0
//
//  Inspired by Steffen Itterheim's GameKitHelper

#import "DDGameKitHelper.h"
#import "DDGameKitHelperDelegate.h"
#import <CommonCrypto/CommonDigest.h>

static NSString* kAchievementsFile = @".achievements";
static NSString* kScoresFile = @".scores";

@interface DDGameKitHelper (Private)
-(void) registerForLocalPlayerAuthChange;
-(void) initScores;
-(void) initAchievements;
-(void) synchronizeAchievements;
-(void) synchronizeScores;
-(void) saveScores;
-(void) saveAchievements;
-(void) loadAchievementDescriptions;
-(GKScore*) getScoreByCategory:(NSString*)category;
-(GKAchievement*) getAchievement:(NSString*)identifier;
-(UIViewController*) getRootViewController;
@end

@implementation DDGameKitHelper

static DDGameKitHelper *instanceOfGameKitHelper;

+(id) alloc
{
    @synchronized(self) 
    {
        NSAssert(instanceOfGameKitHelper == nil, @"Attempted to allocate a second instance of the singleton: GameKitHelper");
        instanceOfGameKitHelper = [[super alloc] retain];
        return instanceOfGameKitHelper;
    }
    
    return nil;
}

+(DDGameKitHelper*) sharedGameKitHelper
{
    @synchronized(self)
    {
        if (instanceOfGameKitHelper == nil)
        {
            [[DDGameKitHelper alloc] init];
        }
        
        return instanceOfGameKitHelper;
    }
    
    return nil;
}

@synthesize delegate;
@synthesize isGameCenterAvailable;
@synthesize achievements;
@synthesize scores;
@synthesize achievementDescriptions;
@synthesize currentPlayerID;

-(NSString *) returnMD5Hash:(NSString*)concat 
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

-(id) init
{
    if ((self = [super init]))
    {
        delegate = [[DDGameKitHelperDelegate alloc] init];
        
        // Test for Game Center availability
        Class gameKitLocalPlayerClass = NSClassFromString(@"GKLocalPlayer");
        bool isLocalPlayerAvailable = (gameKitLocalPlayerClass != nil);
        
        // Test if device is running iOS 4.1 or higher
        NSString* reqSysVer = @"4.1";
        NSString* currSysVer = [[UIDevice currentDevice] systemVersion];
        bool isOSVer41 = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
        
        isGameCenterAvailable = (isLocalPlayerAvailable && isOSVer41);
        NSLog(@"GameCenter available = %@", isGameCenterAvailable ? @"YES" : @"NO");
        
        if (isGameCenterAvailable)
            [self registerForLocalPlayerAuthChange];
    }
    
    return self;
}

-(void) dealloc
{
    [instanceOfGameKitHelper release];
    instanceOfGameKitHelper = nil;
    
    [self saveScores];
    [self saveAchievements];
    
    [scores release];
    [achievements release];
    [achievementDescriptions release];
    
    [currentPlayerID release];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

-(void) setNotAvailable
{
    isGameCenterAvailable = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(bool) isAvailable
{
    return isGameCenterAvailable;
}

-(void) authenticateLocalPlayer
{
    if (isGameCenterAvailable == NO)
        return;
    
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    if (localPlayer.authenticated == NO)
    {
        [localPlayer authenticateWithCompletionHandler:^(NSError* error)
         {
             if (error != nil)
             {
                 NSLog(@"error authenticating player");
             }
             else
             {
                 NSLog(@"player authenticated");
             }
         }];
    }
}

-(bool) isLocalPlayerAuthenticated
{
	if (isGameCenterAvailable == NO)
		return isGameCenterAvailable;

	GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
	return localPlayer.authenticated;
}

-(void) onLocalPlayerAuthenticationChanged
{
    NSString* newPlayerID;
    GKLocalPlayer* localPlayer = [GKLocalPlayer localPlayer];
    
    // if not authenticating then just return
    
    if (!localPlayer.isAuthenticated)
    {
        return;
    }
    
    NSLog(@"onLocalPlayerAuthenticationChanged. reloading scores and achievements and resynchronzing.");
    
    if (localPlayer.playerID != nil)
    {
        newPlayerID = [self returnMD5Hash:localPlayer.playerID];
    }
    else
    {
        newPlayerID = @"unknown";
    }
    
    if (currentPlayerID != nil && [currentPlayerID compare:newPlayerID] == NSOrderedSame)
    {
        NSLog(@"player is the same");
        return;
    }
    
    self.currentPlayerID = newPlayerID;
    NSLog(@"currentPlayerID=%@", currentPlayerID);
    
    [self initScores];
    [self initAchievements];
    
    [self synchronizeScores];
    [self synchronizeAchievements];
    [self loadAchievementDescriptions];
}

-(void) registerForLocalPlayerAuthChange
{
    if (isGameCenterAvailable == NO)
        return;
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(onLocalPlayerAuthenticationChanged) name:GKPlayerAuthenticationDidChangeNotificationName object:nil];
}

-(void) initScores
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:currentPlayerID];
    file = [file stringByAppendingString:kScoresFile];
    id object = [NSKeyedUnarchiver unarchiveObjectWithFile:file];
    
    if ([object isKindOfClass:[NSMutableDictionary class]])
    {
        NSMutableDictionary* loadedScores = (NSMutableDictionary*)object;
        scores = [[NSMutableDictionary alloc] initWithDictionary:loadedScores];
    }
    else
    {
        scores = [[NSMutableDictionary alloc] init];
    }
    
    NSLog(@"scores initialized: %d", scores.count);
}

-(void) initAchievements
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:currentPlayerID];
    file = [file stringByAppendingString:kAchievementsFile];
    id object = [NSKeyedUnarchiver unarchiveObjectWithFile:file];
    
    if ([object isKindOfClass:[NSMutableDictionary class]])
    {
        NSMutableDictionary* loadedAchievements = (NSMutableDictionary*)object;
        achievements = [[NSMutableDictionary alloc] initWithDictionary:loadedAchievements];
    }
    else
    {
        achievements = [[NSMutableDictionary alloc] init];
    }
    
    NSLog(@"achievements initialized: %d", achievements.count);
}

- (void) saveScores
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:currentPlayerID];
    file = [file stringByAppendingString:kScoresFile];
    [NSKeyedArchiver archiveRootObject:scores toFile:file];
    NSLog(@"scores saved: %d", scores.count);
}

-(void) saveAchievements
{
    NSString* libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* file = [libraryPath stringByAppendingPathComponent:currentPlayerID];
    file = [file stringByAppendingString:kAchievementsFile];
    [NSKeyedArchiver archiveRootObject:achievements toFile:file];
    NSLog(@"achievements saved: %d", achievements.count);
}

-(void) synchronizeScores
{
    NSLog(@"synchronizing scores");
    
    // get the top score for each category for current player and compare it to the game center score for the same category
    
    [GKLeaderboard loadCategoriesWithCompletionHandler:^(NSArray *categories, NSArray *titles, NSError *error) 
     {
         if (error != nil)
         {
             NSLog(@"unable to synchronize scores");
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
                      NSLog(@"unable to synchronize scores");
                      return;
                  }
                  
                  GKScore* gcScore = nil;
                  if ([playerScores count] > 0)
                      gcScore = [playerScores objectAtIndex:0];
                  GKScore* localScore = [scores objectForKey:category];
                  
                  if (gcScore == nil && localScore == nil)
                  {
                      NSLog(@"%@(%lld,%lld): no score yet. nothing to synch", category, gcScore.value, localScore.value);
                  }
                  
                  else if (gcScore == nil)
                  {
                      NSLog(@"%@(%lld,%lld): gc score missing. reporting local score", category, gcScore.value, localScore.value);
                      [localScore reportScoreWithCompletionHandler:^(NSError* error) {}];
                  }
                  
                  else if (localScore == nil)
                  {
                      NSLog(@"%@(%lld,%lld): local score missing. caching gc score", category, gcScore.value, localScore.value);
                      [scores setObject:gcScore forKey:gcScore.category];
                      [self saveScores];
                  }
                  
                  else if ([delegate compare:localScore.value to:gcScore.value])
                  {
                      NSLog(@"%@(%lld,%lld): local score more current than gc score. reporting local score", category, gcScore.value, localScore.value);
                      [localScore reportScoreWithCompletionHandler:^(NSError* error) {}];
                  }
                  
                  else if ([delegate compare:gcScore.value to:localScore.value])
                  {
                      NSLog(@"%@(%lld,%lld): gc score is more current than local score. caching gc score", category, gcScore.value, localScore.value);
                      [scores setObject:gcScore forKey:gcScore.category];
                      [self saveScores];
                  }
                  
                  else
                  {
                      NSLog(@"%@(%lld,%lld): scores are equal. nothing to synch", category, gcScore.value, localScore.value);
                  }
              }];
             
             [leaderboardRequest release];
         }
     }];
}

-(void) synchronizeAchievements
{
    NSLog(@"synchronizing achievements");
    
    // get the achievements from game center
    
    [GKAchievement loadAchievementsWithCompletionHandler:^(NSArray* gcAchievementsArray, NSError* error)
     {
         if (error != nil)
         {
             NSLog(@"unable to synchronize achievements");
             return;
         }
         
         // convert NSArray into NSDictionary for ease of use
         NSMutableDictionary *gcAchievements = [[NSMutableDictionary alloc] init];
         for (GKAchievement* gcAchievement in gcAchievementsArray) 
         {
             [gcAchievements setObject:gcAchievement forKey:gcAchievement.identifier];
         }
         
         // find local achievements not yet reported in game center and report them
         for (NSString* identifier in achievements)
         {
             GKAchievement *gcAchievement = [gcAchievements objectForKey:identifier];
             if (gcAchievement == nil)
             {
                 NSLog(@"achievement %@ not in game center. reporting it", identifier);
                 [[achievements objectForKey:identifier] reportAchievementWithCompletionHandler:^(NSError* error) {}];
             }
         }
         
         // find game center achievements that are not reported locally and store them
         for (GKAchievement* gcAchievement in gcAchievementsArray)
         {
             GKAchievement* localAchievement = [achievements objectForKey:gcAchievement.identifier];
             if (localAchievement == nil)
             {
                 NSLog(@"achievement %@ not stored locally. storing it", gcAchievement.identifier);
                 [achievements setObject:gcAchievement forKey:gcAchievement.identifier];
             }
         }
         
         [self saveAchievements];
         
         [gcAchievements release];
     }];
}

-(void) submitScore:(int64_t)value category:(NSString*)category
{
    if (isGameCenterAvailable == NO)
        return;
    
    // always report the new score
    NSLog(@"reporting score of %lld for %@", value, category);
    GKScore* newScore = [[GKScore alloc] initWithCategory:category];
    newScore.value = value;
    [newScore reportScoreWithCompletionHandler:^(NSError* error) 
     {
         // if it's better than the previous score, then save it and notify the user
         GKScore* score = [self getScoreByCategory:category];
         if ([delegate compare:value to:score.value])
         {
             NSLog(@"new high score of %lld for %@", score.value, category);
             score.value = value;
             [self saveScores];
             [delegate onSubmitScore:value];
         }
     }];
    
    [newScore release];
}

-(GKScore*) getScoreByCategory:(NSString*)category
{
    GKScore* score = [scores objectForKey:category];
    
    if (score == nil)
    {
        score = [[[GKScore alloc] initWithCategory:category] autorelease];
        score.value = 0;
        [scores setObject:score forKey:category];
    }
    
    return score;
}

-(void) reportAchievement:(NSString*)identifier percentComplete:(float)percent
{
    if (isGameCenterAvailable == NO)
        return;
    
    GKAchievement* achievement = [self getAchievement:identifier];
    if (achievement.percentComplete < percent)
    {
        NSLog(@"new achievement %@ reported", achievement.identifier);
        achievement.percentComplete = percent;
        [achievement reportAchievementWithCompletionHandler:^(NSError* error)
         {
             [delegate onReportAchievement:(GKAchievement*)achievement];
         }];
        
        [self saveAchievements];
    }
}

-(GKAchievement*) getAchievement:(NSString*)identifier
{
    GKAchievement* achievement = [achievements objectForKey:identifier];
    
    if (achievement == nil)
    {
        achievement = [[[GKAchievement alloc] initWithIdentifier:identifier] autorelease];
        [achievements setObject:achievement forKey:achievement.identifier];
    }
    
    return achievement;
}

- (void)loadAchievementDescriptions
{
    NSLog(@"loading achievement descriptions");
    
    [GKAchievementDescription loadAchievementDescriptionsWithCompletionHandler:^(NSArray *achievementDesc, NSError *error) 
     {
         achievementDescriptions = [[NSMutableDictionary alloc] init];
         
         if (error != nil)
         {
             NSLog(@"unable to load achievements");
             return;
         }
         
         for (GKAchievementDescription *description in achievementDesc) 
         {
             [achievementDescriptions setObject:description forKey:description.identifier];    
         }
         
         NSLog(@"achievement descriptions initialized: %d", achievementDescriptions.count);
     }];
}

-(GKAchievementDescription*) getAchievementDescription:(NSString*)identifier
{
    GKAchievementDescription* description = [achievementDescriptions objectForKey:identifier];
    return description;    
}

-(void) resetAchievements
{
    if (isGameCenterAvailable == NO)
        return;
    
    [achievements removeAllObjects];
    [self saveAchievements];
    
    [GKAchievement resetAchievementsWithCompletionHandler:^(NSError* error) {}];
    
    NSLog(@"achievements reset");
}

-(UIViewController*) getRootViewController
{
    return [UIApplication sharedApplication].keyWindow.rootViewController;
}

-(void) presentViewController:(UIViewController*)vc
{
    UIViewController* rootVC = [self getRootViewController];
    [rootVC presentModalViewController:vc animated:YES];
}

-(void) dismissModalViewController
{
    UIViewController* rootVC = [self getRootViewController];
    [rootVC dismissModalViewControllerAnimated:YES];
}

-(void) showLeaderboard
{
    if (isGameCenterAvailable == NO)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center" message:@"Game Center is not available" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil, nil];
        [alert show];
        [alert release];
        
        return;
    }
    
    GKLeaderboardViewController* leaderboardVC = [[[GKLeaderboardViewController alloc] init] autorelease];
    if (leaderboardVC != nil)
    {
        leaderboardVC.leaderboardDelegate = self;
        [self presentViewController:leaderboardVC];
    }
}

-(void) showLeaderboardwithCategory:(NSString*)category timeScope:(int)tscope 
{
    if (isGameCenterAvailable == NO)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center" message:@"Game Center is not available" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil, nil];
        [alert show];
        [alert release];
        
        return;
    }
    
    GKLeaderboardViewController* leaderboardVC = [[[GKLeaderboardViewController alloc] init] autorelease];
    if (leaderboardVC != nil)
    {
        leaderboardVC.leaderboardDelegate = self;
        leaderboardVC.category = category;
        leaderboardVC.timeScope = tscope;
        [self presentViewController:leaderboardVC];
    }  
}

-(void) leaderboardViewControllerDidFinish:(GKLeaderboardViewController*)viewController
{
    [self dismissModalViewController];
}

-(void) showAchievements
{
    if (isGameCenterAvailable == NO)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Game Center" message:@"Game Center is not available" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil, nil];
        [alert show];
        [alert release];
        
        return;
    }
    
    GKAchievementViewController* achievementsVC = [[[GKAchievementViewController alloc] init] autorelease];
    if (achievementsVC != nil)
    {
        achievementsVC.achievementDelegate = self;
        [self presentViewController:achievementsVC];
    }
}

-(void) achievementViewControllerDidFinish:(GKAchievementViewController*)viewController
{
    [self dismissModalViewController];
}

@end
