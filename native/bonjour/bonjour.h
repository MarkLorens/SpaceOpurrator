#ifndef BONJOUR_H
#define BONJOUR_H

#include "core/object/class_db.h"

// Godot singleton "Bonjour": LAN lobby discovery over mDNSResponder.
// Native callbacks queue events; GDScript polls them (never emit from a native thread).
// Event dict: {type: "found"|"lost", name: String, host: String (found only)}.
class Bonjour : public Object {
	GDCLASS(Bonjour, Object);

	static void _bind_methods();

public:
	void start_advertising(String p_name, int p_port);
	void stop_advertising();
	void start_browsing();
	void stop_browsing();
	int get_pending_event_count();
	Variant pop_pending_event();

	Bonjour();
	~Bonjour();
};

#endif
