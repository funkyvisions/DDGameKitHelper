//
//  DDGameKitHelper.h
//  Version 1.0
//
//  Inspired by Steffen Itterheim's GameKitHelper

#import <GameKit/GameKit.h>

// -----------------------------------------------------------------
#define DDGAMEKIT_LOGGING 0
// -----------------------------------------------------------------

@protocol DDGameKitHelperProtocol
- (BOOL) compareScore:(int64_t)score1 toScore:(int64_t)score2;
- (void) onSubmitScore:(int64_t)score;
- (void) onReportAchievement:(GKAchievement*)achievement;
@end

// -----------------------------------------------------------------

@interface DDGameKitHelper : NSObject <GKLeaderboardViewControllerDelegate, GKAchievementViewControllerDelegate, GKGameCenterControllerDelegate>
{
    id <DDGameKitHelperProtocol> _delegate;
    BOOL _isGameCenterAvailable;
    NSMutableDictionary* _achievements;
    NSMutableDictionary* _scores;
    NSMutableDictionary* _achievementDescriptions;
    NSString* _currentPlayerID;
}

// -----------------------------------------------------------------

@property (nonatomic, strong) id <DDGameKitHelperProtocol> delegate;
@property (nonatomic, readonly) BOOL isGameCenterAvailable;
@property (nonatomic, readonly) NSMutableDictionary* achievements;
@property (nonatomic, readonly) NSMutableDictionary* scores;
@property (nonatomic, readonly) NSMutableDictionary* achievementDescriptions;
@property (nonatomic, strong) NSString* currentPlayerID;

// -----------------------------------------------------------------

// Singleton instance
+ (DDGameKitHelper*) sharedGameKitHelper;

// -----------------------------------------------------------------

// Check and set availability
- (void) setNotAvailable;
- (BOOL) isAvailable;

// Authenticate and check authentication
- (void) authenticateLocalPlayer;
- (BOOL) isLocalPlayerAuthenticated;

// Submitting score and achievements
- (void) submitScore:(int64_t)value category:(NSString*)category;
- (void) reportAchievement:(NSString*)identifier percentComplete:(float)percent;

// Resetting achievements
- (void) resetAchievements;

// Showing GameCenter
- (void) showGameCenter;
- (void) showLeaderboard;
- (void) showLeaderboardWithCategory:(NSString*)category timeScope:(int)tscope;
- (void) showAchievements;

// Achievement info
- (int) numberOfTotalAchievements;
- (int) numberOfCompletedAchievements;
- (GKAchievementDescription*) getAchievementDescription:(NSString*)identifier;

// -----------------------------------------------------------------
@end
// -----------------------------------------------------------------