#import <GameKit/GameKit.h>

#include "leaderboards.h"

void Leaderboards::show_all() {
	// The access point presents and dismisses the dashboard itself, even while its badge is hidden.
	dispatch_async(dispatch_get_main_queue(), ^{
		[GKAccessPoint.shared triggerAccessPointWithState:GKGameCenterViewControllerStateLeaderboards handler:^{}];
	});
}

void Leaderboards::_bind_methods() {
	ClassDB::bind_method(D_METHOD("show_all"), &Leaderboards::show_all);
}
