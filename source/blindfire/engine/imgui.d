module blindfire.engine.imgui;

import core.stdc.stdio : printf;

import std.traits : isDelegate, ReturnType, ParameterTypeTuple;
auto bindDelegate(T, string file = __FILE__, size_t line = __LINE__)(T t) if(isDelegate!T) {

    static T dg;
	dg = t;

    extern(C)
		static ReturnType!T func(ParameterTypeTuple!T args) {
			return dg(args);
		}

	return &func;

} //bindDelegate (thanks Destructionator)

struct ImguiContext {

	import derelict.sdl2.types;
	import derelict.imgui.imgui;
	import derelict.opengl3.gl;

	import blindfire.engine.gl : AttribLocation, Shader, Texture;
	import blindfire.engine.memory : theAllocator, IAllocator, make, dispose;
	import blindfire.engine.eventhandler : AnyKey, EventHandler;
	import blindfire.engine.window : Window;

	//mammory
	IAllocator allocator_;

	//opengl handles
	Shader* shader_;
	Texture* font_texture_;
	GLuint vao, vbo, elements;

	double time_;
	bool[3] mouse_buttons_pressed_;
	float scroll_wheel_;

	//external state
	Window* window_;

	@disable this();
	@disable this(this);

	this(IAllocator allocator, Window* window) {

		this.allocator_ = allocator;
		this.window_ = window;

	} //this

	~this() {

		allocator_.dispose(shader_);
		allocator_.dispose(font_texture_);
		glDeleteVertexArrays(1, &vao);

	} //~this

	void initialize() {

		/* set the memory allocator */
		allocator_ = theAllocator;

		ImGuiIO* io = igGetIO();

		io.KeyMap[ImGuiKey_Tab] = SDL_SCANCODE_KP_TAB;
		io.KeyMap[ImGuiKey_LeftArrow] = SDL_SCANCODE_LEFT;
		io.KeyMap[ImGuiKey_RightArrow] = SDL_SCANCODE_RIGHT;
		io.KeyMap[ImGuiKey_UpArrow] = SDL_SCANCODE_UP;
		io.KeyMap[ImGuiKey_DownArrow] = SDL_SCANCODE_DOWN;
		io.KeyMap[ImGuiKey_Home] = SDL_SCANCODE_HOME;
		io.KeyMap[ImGuiKey_End] = SDL_SCANCODE_END;
		io.KeyMap[ImGuiKey_Delete] = SDL_SCANCODE_DELETE;
		io.KeyMap[ImGuiKey_Escape] = SDL_SCANCODE_ESCAPE;
		io.KeyMap[ImGuiKey_A] = SDL_SCANCODE_A;
		io.KeyMap[ImGuiKey_C] = SDL_SCANCODE_C;
		io.KeyMap[ImGuiKey_V] = SDL_SCANCODE_V;
		io.KeyMap[ImGuiKey_X] = SDL_SCANCODE_X;
		io.KeyMap[ImGuiKey_Y] = SDL_SCANCODE_Y;
		io.KeyMap[ImGuiKey_Z] = SDL_SCANCODE_Z;

		io.RenderDrawListsFn = bindDelegate(&render_draw_lists);
		io.SetClipboardTextFn = bindDelegate(&set_clipboard_text);
		io.GetClipboardTextFn = bindDelegate(&get_clipboard_text);

		create_device_objects();

	} //initialize

	void on_event(ref SDL_Event ev) {

		import std.stdio : writefln;

		auto io = igGetIO();

		switch (ev.type) {

			case SDL_KEYDOWN, SDL_KEYUP:
				io.KeysDown[ev.key.keysym.scancode] = (ev.type == SDL_KEYDOWN);
				break;

			case SDL_MOUSEBUTTONDOWN:
				auto btn = ev.button.button;
				if (btn < 4) {
					mouse_buttons_pressed_[btn-1] = true;
				}
				break;

			case SDL_MOUSEBUTTONUP:
				auto btn = ev.button.button;
				if (btn < 4) {
					auto cur = mouse_buttons_pressed_[btn-1];
					mouse_buttons_pressed_[btn-1] = !cur;
				}
				break;

			case SDL_MOUSEWHEEL:
				scroll_wheel_ += ev.wheel.y;
				break;

			default:
				writefln("unhandled event type in imgui: %d", ev.type);
				break;

		}

	} //on_event

	void create_device_objects() {

		AttribLocation[3] attrs = [
			AttribLocation(0, "Position"),
			AttribLocation(1, "UV"),
			AttribLocation(2, "Color")];

		char[16][2] uniforms = ["Texture", "ProjMtx"];
		shader_ = allocator_.make!Shader("shaders/imgui", attrs, uniforms);

		glGenBuffers(1, &vbo);
		glGenBuffers(1, &elements);

		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glEnableVertexAttribArray(0);
		glEnableVertexAttribArray(1);
		glEnableVertexAttribArray(2);

		glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, ImDrawVert.sizeof, cast(void*)0);
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, ImDrawVert.sizeof, cast(void*)ImDrawVert.uv.offsetof);
		glVertexAttribPointer(2, 4, GL_UNSIGNED_BYTE, GL_TRUE, ImDrawVert.sizeof, cast(void*)ImDrawVert.col.offsetof);

		glBindVertexArray(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);

		/*generate teh fonts*/
		create_font_texture();

	} //create_device_objects

	void create_font_texture() {

		auto io = igGetIO();

		ubyte* pixels;
		int width, height;
		ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &pixels, &width, &height, null);

		font_texture_ = allocator_.make!Texture(pixels, width, height, GL_RGBA, GL_RGBA);
		ImFontAtlas_SetTexID(io.Fonts, cast(void*)font_texture_.handle);

	} //create_font_texture

	void render_draw_lists(ImDrawData* data) nothrow {

		glDisable(GL_CULL_FACE);
		glDisable(GL_DEPTH_TEST);
		glEnable(GL_SCISSOR_TEST);

		shader_.bind();
		shader_.update(window_.view_projection);

		glBindVertexArray(vao);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elements);

		int width = window_.width;
		int height = window_.height;

		foreach (n; 0..data.CmdListsCount) {

			ImDrawList* cmd_list = data.CmdLists[n];
			ImDrawIdx* idx_buffer_offset;

			auto countVertices = ImDrawList_GetVertexBufferSize(cmd_list);
			auto countIndices = ImDrawList_GetIndexBufferSize(cmd_list);

			glBufferData(GL_ARRAY_BUFFER, countVertices * ImDrawVert.sizeof, cast(GLvoid*)ImDrawList_GetVertexPtr(cmd_list,0), GL_STREAM_DRAW);
			glBufferData(GL_ELEMENT_ARRAY_BUFFER, countIndices * ImDrawIdx.sizeof, cast(GLvoid*)ImDrawList_GetIndexPtr(cmd_list,0), GL_STREAM_DRAW);

			auto cmdCnt = ImDrawList_GetCmdSize(cmd_list);

			foreach(i; 0..cmdCnt) {

				auto pcmd = ImDrawList_GetCmdPtr(cmd_list, i);

				if (pcmd.UserCallback) {
					pcmd.UserCallback(cmd_list, pcmd);
				} else {
					glBindTexture(GL_TEXTURE_2D, cast(GLuint)pcmd.TextureId);
					glScissor(cast(int)pcmd.ClipRect.x, cast(int)(height - pcmd.ClipRect.w), cast(int)(pcmd.ClipRect.z - pcmd.ClipRect.x), cast(int)(pcmd.ClipRect.w - pcmd.ClipRect.y));
					glDrawElements(GL_TRIANGLES, pcmd.ElemCount, GL_UNSIGNED_SHORT, idx_buffer_offset);
				}

				idx_buffer_offset += pcmd.ElemCount;
			}
		}

		glDisable(GL_SCISSOR_TEST);

	} //render_draw_lists

	void new_frame(ref EventHandler ev, double dt) {

		auto io = igGetIO();

		int display_w = window_.width;
		int display_h = window_.height;
		io.DisplaySize = ImVec2(cast(float)display_w, cast(float)display_h);
		io.DeltaTime = cast(float)dt;

		int m_x, m_y;
		ev.mouse_pos(m_x, m_y);
		io.MousePos = ImVec2(m_x, m_y);

		foreach (i; 0..3) {
			io.MouseDown[i] = mouse_buttons_pressed_[i];
		}

		io.MouseWheel = scroll_wheel_;

		igNewFrame();

	} //new_frame

	void end_frame() {

		igRender();

	} //end_frame

	const(char*) get_clipboard_text() nothrow {

		import derelict.sdl2.functions : SDL_GetClipboardText;
		return SDL_GetClipboardText();

	} //get_clipboard_text

	void set_clipboard_text(const(char)* text) nothrow {

	} //set_clipboard_text

} //ImguiContext