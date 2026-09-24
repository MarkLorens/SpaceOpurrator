#import <Foundation/Foundation.h>
#import <Network/Network.h>
#include <arpa/inet.h>
#include <dns_sd.h>

#include "bonjour.h"

static const char *SERVICE_TYPE = "_spaceopurrator._udp";

// One serial queue owns all state below; Godot's thread only touches it via dispatch_sync.
static dispatch_queue_t queue;
static NSMutableArray<NSDictionary *> *events;
static DNSServiceRef advert;
static nw_browser_t browser;
static NSMutableSet<NSString *> *live; // Rooms the current browser can see; late resolves for others are dropped.

static void push(NSString *type, NSString *name, NSString *host) {
	NSMutableDictionary *e = [@{ @"type" : type, @"name" : name } mutableCopy];
	if (host) {
		e[@"host"] = host;
	}
	[events addObject:e];
}

// A .service endpoint has no address yet: open a throwaway UDP connection so
// Network.framework resolves it, then read the IPv4 address off the path.
// Resolution can stall (waiting) or fail on flaky Wi-Fi / while the Local Network
// prompt is up, and the browser won't re-report the room, so retry a few times.
static void resolve(nw_endpoint_t endpoint, NSString *name, int attempts_left) {
	nw_parameters_t params = nw_parameters_create_secure_udp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
	nw_protocol_options_t ip = nw_protocol_stack_copy_internet_protocol(nw_parameters_copy_default_protocol_stack(params));
	nw_ip_options_set_version(ip, nw_ip_version_4); // ENet host is reached over IPv4.

	nw_connection_t conn = nw_connection_create(endpoint, params);
	nw_connection_set_queue(conn, queue);
	nw_connection_set_state_changed_handler(conn, ^(nw_connection_state_t state, nw_error_t error) {
		if (state == nw_connection_state_ready) {
			nw_endpoint_t remote = nw_path_copy_effective_remote_endpoint(nw_connection_copy_current_path(conn));
			const struct sockaddr *sa = remote ? nw_endpoint_get_address(remote) : NULL;
			nw_connection_cancel(conn);
			if (sa && sa->sa_family == AF_INET) {
				if ([live containsObject:name]) {
					char buf[INET_ADDRSTRLEN];
					inet_ntop(AF_INET, &((const struct sockaddr_in *)sa)->sin_addr, buf, sizeof(buf));
					push(@"found", name, @(buf));
				}
				return;
			}
			NSLog(@"Bonjour: '%@' resolved without an IPv4 address", name);
		} else if (state == nw_connection_state_waiting || state == nw_connection_state_failed) {
			NSLog(@"Bonjour: resolving '%@' %s: %@", name, state == nw_connection_state_failed ? "failed" : "waiting", error);
			nw_connection_cancel(conn);
		} else {
			return;
		}
		if (attempts_left > 0) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), queue, ^{
				if ([live containsObject:name]) {
					resolve(endpoint, name, attempts_left - 1);
				}
			});
		}
	});
	nw_connection_start(conn);
}

static void registered(DNSServiceRef, DNSServiceFlags, DNSServiceErrorType err, const char *name, const char *, const char *, void *) {
	// -65570 (PolicyDenied) = Local Network permission off for this app.
	if (err != kDNSServiceErr_NoError) {
		NSLog(@"Bonjour: advertising failed (%d)", err);
	} else {
		NSLog(@"Bonjour: advertising as '%s'", name);
	}
}

void Bonjour::start_advertising(String p_name, int p_port) {
	CharString name = p_name.utf8();
	const char *name_c = p_name.is_empty() ? NULL : name.get_data(); // NULL = device name.
	dispatch_sync(queue, ^{
		if (advert) {
			DNSServiceRefDeallocate(advert);
			advert = NULL;
		}
		// Registers name/type/port with mDNSResponder without binding the port, so ENet keeps it.
		if (DNSServiceRegister(&advert, 0, 0, name_c, SERVICE_TYPE, NULL, NULL, htons(p_port), 0, NULL, registered, NULL) == kDNSServiceErr_NoError) {
			DNSServiceSetDispatchQueue(advert, queue);
		} else {
			advert = NULL;
		}
	});
}

void Bonjour::stop_advertising() {
	dispatch_sync(queue, ^{
		if (advert) {
			DNSServiceRefDeallocate(advert);
			advert = NULL;
		}
	});
}

void Bonjour::start_browsing() {
	dispatch_sync(queue, ^{
		if (browser) {
			return;
		}
		browser = nw_browser_create(nw_browse_descriptor_create_bonjour_service(SERVICE_TYPE, "local"), NULL);
		nw_browser_set_queue(browser, queue);
		nw_browser_set_state_changed_handler(browser, ^(nw_browser_state_t state, nw_error_t error) {
			// waiting with -65570 (PolicyDenied) = Local Network permission off for this app.
			if (state == nw_browser_state_waiting || state == nw_browser_state_failed) {
				NSLog(@"Bonjour: browser %s: %@", state == nw_browser_state_failed ? "failed" : "waiting", error);
			}
		});
		nw_browser_set_browse_results_changed_handler(browser, ^(nw_browse_result_t old_result, nw_browse_result_t new_result, bool batch_complete) {
			nw_browse_result_change_t change = nw_browse_result_get_changes(old_result, new_result);
			if (change & nw_browse_result_change_result_added) {
				nw_endpoint_t ep = nw_browse_result_copy_endpoint(new_result);
				NSString *name = @(nw_endpoint_get_bonjour_service_name(ep));
				[live addObject:name];
				resolve(ep, name, 5);
			} else if (change & nw_browse_result_change_result_removed) {
				NSString *name = @(nw_endpoint_get_bonjour_service_name(nw_browse_result_copy_endpoint(old_result)));
				[live removeObject:name];
				push(@"lost", name, nil);
			}
		});
		nw_browser_start(browser);
	});
}

void Bonjour::stop_browsing() {
	dispatch_sync(queue, ^{
		if (browser) {
			nw_browser_cancel(browser);
			browser = nil;
			[live removeAllObjects];
		}
	});
}

int Bonjour::get_pending_event_count() {
	__block int count = 0;
	dispatch_sync(queue, ^{
		count = (int)events.count;
	});
	return count;
}

Variant Bonjour::pop_pending_event() {
	__block NSDictionary *e = nil;
	dispatch_sync(queue, ^{
		if (events.count) {
			e = events[0];
			[events removeObjectAtIndex:0];
		}
	});
	if (!e) {
		return Variant();
	}
	Dictionary d;
	for (NSString *key in e) {
		d[String::utf8(key.UTF8String)] = String::utf8(((NSString *)e[key]).UTF8String);
	}
	return d;
}

void Bonjour::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start_advertising", "name", "port"), &Bonjour::start_advertising);
	ClassDB::bind_method(D_METHOD("stop_advertising"), &Bonjour::stop_advertising);
	ClassDB::bind_method(D_METHOD("start_browsing"), &Bonjour::start_browsing);
	ClassDB::bind_method(D_METHOD("stop_browsing"), &Bonjour::stop_browsing);
	ClassDB::bind_method(D_METHOD("get_pending_event_count"), &Bonjour::get_pending_event_count);
	ClassDB::bind_method(D_METHOD("pop_pending_event"), &Bonjour::pop_pending_event);
}

Bonjour::Bonjour() {
	queue = dispatch_queue_create("bonjour", DISPATCH_QUEUE_SERIAL);
	events = [NSMutableArray new];
	live = [NSMutableSet new];
}

Bonjour::~Bonjour() {
	stop_advertising();
	stop_browsing();
}
