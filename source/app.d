import std.stdio : writefln;
import std.c.process : exit;

import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.sdl2.mixer;
import derelict.sdl2.ttf;

import derelict.opengl3.gl;

import sundownstandoff.game;
import sundownstandoff.window;
import sundownstandoff.eventhandler;


const uint DEFAULT_WINDOW_WIDTH = 640;
const uint DEFAULT_WINDOW_HEIGHT = 480;

void initialize_systems() {

	DerelictSDL2.load();
	DerelictSDL2Image.load();
	DerelictSDL2Mixer.load();
	DerelictSDL2ttf.load();
	DerelictGL.load();

	if (TTF_Init() == -1) {
		writefln("TTF_Init: %s\n", TTF_GetError());
		exit(2);
	}

}

void main() {

	initialize_systems();
	auto event_handler = EventHandler(SDL_GetKeyboardState(null));
	auto window = Window("Sundown Standoff", DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT);
	event_handler.add_listener(&window.handle_events);
	event_handler.bind_keyevent(SDL_SCANCODE_SPACE, &window.toggle_wireframe);
	auto game = Game(&window, &event_handler);
	game.run();

}
