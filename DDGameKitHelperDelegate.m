//
//	DDGameKitHelperDelegate.h
//	Version 1.0

#import "DDGameKitHelperDelegate.h"
#import "GKAchievementHandler.h"

@implementation DDGameKitHelperDelegate

// return true if score1 is greater than score2
// modify this if your scoreboard is reversed (low scores on top)
-(bool) compare:(int64_t)score1 to:(int64_t)score2
{
	return score1 > score2;
}

// display new high score using GKAchievement class
-(void) onSubmitScore:(int64_t)score;
{
	[[GKAchievementHandler defaultHandler] notifyAchievementTitle:@"New High Score!!!" andMessage:[NSString stringWithFormat:@"%d", score]];
}

// display the achievement using GKAchievement class
-(void) onReportAchievement:(GKAchievement*)achievement
{
	DDGameKitHelper* gkHelper = [DDGameKitHelper sharedGameKitHelper];
	[[GKAchievementHandler defaultHandler] notifyAchievement:[gkHelper getAchievementDescription:achievement.identifier]];
}

@end
