#include "bonjour_module.h"

#include "core/config/engine.h"

#include "bonjour.h"
#include "leaderboards.h"

static Bonjour *bonjour;
static Leaderboards *leaderboards;

void register_bonjour_types() {
	bonjour = memnew(Bonjour);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Bonjour", bonjour));
	leaderboards = memnew(Leaderboards);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Leaderboards", leaderboards));
}

void unregister_bonjour_types() {
	if (bonjour) {
		memdelete(bonjour);
		bonjour = nullptr;
	}
	if (leaderboards) {
		memdelete(leaderboards);
		leaderboards = nullptr;
	}
}
