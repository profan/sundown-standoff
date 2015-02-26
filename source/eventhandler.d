module sundownstandoff.eventhandler;

import std.stdio : writefln;

import derelict.sdl2.sdl;

alias void delegate(ref SDL_Event) EventDelegate;
alias void delegate() KeyDelegate;
alias void delegate(int, int) MouseDelegate;

enum KeyState {

	UP = false,
	DOWN = true

} //KeyState

struct KeyBind {

	SDL_Scancode key;
	KeyDelegate func;

} //KeyBind

struct MouseBind {

	Uint8 mousebtn;
	MouseDelegate func;
	KeyState state;

} //MouseBind

struct EventHandler {

	SDL_Event ev;
	EventDelegate[] delegates;
	MouseBind[] mouse_events;
	MouseBind[] motion_events;
	KeyBind[] key_events;

	//mutated by SDL2
	Uint8* pressed_keys;

	this(Uint8* keys) {
		this.pressed_keys = keys;
	}

	void add_listener(EventDelegate ed) {
		delegates ~= ed;
	}

	void bind_mousebtn(Uint8 button, MouseDelegate md, KeyState state) {
		MouseBind mb = {mousebtn: button, func: md, state: state};
		mouse_events ~= mb;
	}

	void bind_key(SDL_Scancode key, KeyDelegate kd) {
		KeyBind kb = {key: key, func: kd};
		key_events ~= kb;
	}

	void bind_mousemov(MouseDelegate md) {
		MouseBind mb = {mousebtn: 0, func: md};
		motion_events ~= mb;
	}

	void handle_events() {
		
		while(SDL_PollEvent(&ev)) {
		
			switch (ev.type ) {
				case SDL_MOUSEBUTTONDOWN:
					foreach (ref bind; mouse_events) {
						if (ev.button.button == bind.mousebtn) {
							if (bind.state == KeyState.DOWN) {
								bind.func(ev.motion.x, ev.motion.y);
							}
						}
					}
					break;
				case SDL_MOUSEBUTTONUP:
					foreach (ref bind; mouse_events) {
						if (ev.button.button == bind.mousebtn) {
							if (bind.state == KeyState.UP) {
								bind.func(ev.motion.x, ev.motion.y);
							}
						}
					}
					break;
				case SDL_MOUSEMOTION:
					break;
				default:
					break;
			}
	
			foreach(ref receiver; delegates) {
				receiver(ev);
			}

		}

		foreach (ref bind; key_events) {
			if (pressed_keys[bind.key]) {
				bind.func();
			}
		}

		int m_x, m_y;
		SDL_GetMouseState(&m_x, &m_y);
		foreach (ref bind; motion_events) {
			bind.func(m_x, m_y);
		}

	}

} //EventHandler
