#ifndef LEADERBOARDS_H
#define LEADERBOARDS_H

#include "core/object/class_db.h"

// Godot singleton "Leaderboards": opens Game Center's list of every leaderboard.
// GameCenterKit can only open one board by ID, so this fills that gap.
class Leaderboards : public Object {
	GDCLASS(Leaderboards, Object);

	static void _bind_methods();

public:
	void show_all();
};

#endif
