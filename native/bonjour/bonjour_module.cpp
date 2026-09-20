#include "bonjour_module.h"

#include "core/config/engine.h"

#include "bonjour.h"

static Bonjour *bonjour;

void register_bonjour_types() {
	bonjour = memnew(Bonjour);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Bonjour", bonjour));
}

void unregister_bonjour_types() {
	if (bonjour) {
		memdelete(bonjour);
		bonjour = nullptr;
	}
}
