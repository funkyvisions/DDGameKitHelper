//
//  DDGameKitHelperDelegate.h
//  Version 1.0

// -----------------------------------------------------------------
#define DDGAMEKIT_USE_NOTIFICATION 1
// -----------------------------------------------------------------

#import "DDGameKitHelperDelegate.h"
#if DDGAMEKIT_USE_NOTIFICATION == 1
#import "GKAchievementHandler.h"
#endif

// -----------------------------------------------------------------
@implementation DDGameKitHelperDelegate
// -----------------------------------------------------------------

// Returns 'true' if score1 is greater than score2
// Modify this if your scoreboard is reversed (lowest scores first)
// For example -  a lap time in a racer game (the lower the better)
- (BOOL) compareScore:(int64_t)score1 toScore:(int64_t)score2
{
    return score1 > score2;
}

// -----------------------------------------------------------------

// If enabled, display new high score notification using GKAchievementHandler
- (void) onSubmitScore:(int64_t)score;
{
#if DDGAMEKIT_USE_NOTIFICATION == 1
    [[GKAchievementHandler defaultHandler] notifyAchievementTitle:@"New High Score!" andMessage:[NSString stringWithFormat:@"%d", (int)score]];
#endif
}

// -----------------------------------------------------------------

// If enabled, display achievement notification using GKAchievementHandler
- (void) onReportAchievement:(GKAchievement*)achievement
{
#if DDGAMEKIT_USE_NOTIFICATION == 1
    DDGameKitHelper* gkHelper = [DDGameKitHelper sharedGameKitHelper];
    [[GKAchievementHandler defaultHandler] notifyAchievement:[gkHelper getAchievementDescription:achievement.identifier]];
#endif
}

// -----------------------------------------------------------------
@end
// -----------------------------------------------------------------