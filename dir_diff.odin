/*
* Improve the algorithm of checking for duplicates, have a seen-already array
* Have a way to measure it (time)

User Story:

The user opens the program.
They are presented with what the program does.
The user inserts the paths of the two dirs to compare.
The user gets a table [?] with the info about both dirs, what files are duplicates if any.
If there are duplicates, the program shows which version was more recently modified.
The program shows options.
Take out all of the duplicates from one of the Dirs and put it in a dir called `duplicates` by default,
or the user inserts name of dir.
The user can select which version to keep from either file, or based on more or less recently modified.
The program presents the results.
*/

package dir_diff

import "base:runtime"
import "./visuals"
import "core:fmt"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import rl "vendor:raylib"
import clay "clay-odin"

print :: fmt.println
printf :: fmt.printfln


// FONTS
// =========

FONT_ID_BODY_16 :: 0
FONT_ID_TITLE_56 :: 9
FONT_ID_TITLE_52 :: 1
FONT_ID_TITLE_48 :: 2
FONT_ID_TITLE_36 :: 3
FONT_ID_TITLE_32 :: 4
FONT_ID_BODY_36 :: 5
FONT_ID_BODY_30 :: 6
FONT_ID_BODY_28 :: 7
FONT_ID_BODY_24 :: 8


// STRUCTS
// =========

DirectoryInfo :: struct {
	name_dir:    string,
	path:        string,
	total_files: int,
	files_array: [dynamic]os.File_Info,
}


// PROCEDURES
// ===========

/*
Returns a DirectoryInfo struct
*/
get_array_file_names :: proc(
	dir_path: string,
	print_file_names: bool = false,
	arena_alloc: mem.Allocator,
) -> DirectoryInfo {
	files_info_array, err := os.read_all_directory_by_path(dir_path, arena_alloc)

	files_array := make([dynamic]os.File_Info, arena_alloc)

	for elem in files_info_array {
		if elem.type == .Directory {
			continue
		}
		append(&files_array, elem)
	}

	total_files := len(files_array)

	// BASE for name of dir
	dir_name := os.base(dir_path)

	if print_file_names {
		for file in files_array {
			print("=============================")
			print(file.name)
		}
	}

	abs_path, _ := os.get_absolute_path(dir_path, arena_alloc)

	dir_info := DirectoryInfo {
		name_dir    = dir_name,
		total_files = total_files,
		files_array = files_array,
		path        = abs_path,
	}

	return dir_info

}

return_big_then_small_dir :: proc(
	dir_a, dir_b: DirectoryInfo,
	allocator: mem.Allocator,
) -> [2]DirectoryInfo {

	res := "The directory with more files is: "

	if dir_a.total_files >= dir_b.total_files {
		res = strings.concatenate({res, dir_a.name_dir}, allocator = allocator)

		printf("%v%v with %v files %v", visuals.BOLD_YELLOW, res, dir_a.total_files, visuals.RESET)
		return {dir_a, dir_b}
	} else {
		res = strings.concatenate({res, dir_b.name_dir}, allocator = allocator)
		printf("%v%v with %v files %v", visuals.BOLD_YELLOW, res, dir_b.total_files, visuals.RESET)
		return {dir_b, dir_a}
	}
}

/*
Returns a [2]DirectoryInfo with the info from the dirs given as input paths
*/
get_paths_dirs :: proc(debug: bool, arena_alloc: mem.Allocator) -> [2]DirectoryInfo {
	path1_str := new(string, arena_alloc)
	path2_str := new(string, arena_alloc)
	// FOR testing and debugging only:
	if debug {
		path1_str^ = "/Users/gero/Documents/Coding/Odin-Programs/dir-diff/foo"
		path2_str^ = "/Users/gero/Documents/Coding/Odin-Programs/dir-diff/bar"
	} else {
		buffer: [1024]byte
		// get input from the user
		print("Insert DIR 1 FULL PATH: ")
		path1, err_1 := os.read(os.stdin, buffer[:])
		if err_1 != nil {
			fmt.eprintln("ERROR with PATH 1:", err_1)
			panic("ERROR with PATH 1")
		}
		path1_str^ = string(buffer[:path1])
		path1_str^ = strings.trim_right(path1_str^, "\n")
		if !os.is_directory(path1_str^) {
			print(path1_str^, "is not a DIRECTORY")
		}

		print("Insert DIR 2 FULL PATH: ")
		path2, err_2 := os.read(os.stdin, buffer[path1:])
		if err_2 != nil {
			fmt.eprintln("ERROR with PATH 2:", err_2)
			panic("ERROR with PATH 2")
		}
		path2_str^ = string(buffer[path1:path1 + path2])
		path2_str^ = strings.trim_right(path2_str^, "\n")
		assert(os.is_directory(path2_str^), "PATH is not a directory")
	}

	path1_dir := new(DirectoryInfo, arena_alloc)
	path2_dir := new(DirectoryInfo, arena_alloc)

	path1_dir^ = get_array_file_names(path1_str^, arena_alloc = arena_alloc)
	path2_dir^ = get_array_file_names(path2_str^, arena_alloc = arena_alloc)

	// TODO(gero) Check this in the future:
	// NOTE: we do assume, for the time being, that the biggest dir is the one containing duplicates
	// BUT this is not necessarily the case always

	big_then_small_dirs_array: [2]DirectoryInfo = return_big_then_small_dir(
		path1_dir^,
		path2_dir^,
		allocator = arena_alloc,
	)
	printf("Biggest DIR: %v", big_then_small_dirs_array[0].name_dir)
	printf("Biggest DIR Path: %v", big_then_small_dirs_array[0].path)

	return big_then_small_dirs_array
}

find_duplicates_in_two_dirs :: proc(
	dir_a, dir_b: DirectoryInfo,
	alloc: mem.Allocator,
) -> [dynamic]string {
	// TODO(gero): Measure mathematically which one is better, or if it is the same exactly:
	// 1st for loop the dir with more files, 2nd loop dir with fewer, OR the other way around

	// Dir A has to be the dir with the most files
	duplicates := make([dynamic]string, alloc)

	more_files_dir_array := dir_a.files_array
	fewer_files_dir_array := dir_b.files_array

	stopwatch: time.Stopwatch

	time.stopwatch_start(&stopwatch)

	seen := make([dynamic]string, alloc)

	// TODO(gero): add StopWatch here to measure how long it takes
	// NOTE: we are gonna loop over the fewer files dir - outer loop, more dirs - inner loop
	for file_i in fewer_files_dir_array {
		// log.debug("file_i in fewer_files_dir_array ", file_i)
		for file_j, file_j_index in more_files_dir_array {
			// log.debug("file_j in more_files_dir_array ", file_j)
			if file_i.name == file_j.name {
				// log.debug("file_i == file_j", file_i.name == file_j.name)
				append(&duplicates, file_i.name)
				unordered_remove_dynamic_array(&more_files_dir_array, file_j_index)
			}
		}
	}

	time.stopwatch_stop(&stopwatch)
	print("===========================================")
	print("THE ALGORITHM HAS LASTED:")
	log.debug(time.stopwatch_duration(stopwatch))
	print("===========================================")

	return duplicates
}

get_user_input :: proc(prompt_message: string, allocator: mem.Allocator) -> string {
	print(prompt_message)
	buffer: [256]byte
	user_input, input_err := os.read(os.stdin, buffer[:])
	assert(input_err == nil)
	user_input_str := strings.clone_from_bytes(buffer[:user_input], allocator)
	return user_input_str
}


clean_user_input :: proc(user_input: string, allocator: mem.Allocator) -> string {
	res := strings.trim_right(strings.to_lower(user_input, allocator), "\n") // note you have to trim it
	return res
}

print_all_duplicates :: proc(dups: [dynamic]string) {
	print("DUPLICATES ARE:")
	print("========================================")
	printf("TOTAL: %i", len(dups))
	print("========================================")
	for dup, index in dups {
		if dup != "" {
			printf("%i ==> %s", index + 1, dup)
		}
	}
	print("========================================")
}

get_center_text :: proc(width, height: f32, text: cstring, text_fs: int) -> rl.Vector2{
	text_len := rl.MeasureText(text, i32(text_fs))
	// log.debug(text_len)
	x: f32 = width / 2 - f32(text_len/2)
	y : f32 = height / 2 - f32(text_fs/2)
	return {x,y}
}

// ============== CLAY ==============
// Define some colors.
COLOR_LIGHT :: clay.Color{224, 215, 210, 255}
COLOR_RED :: clay.Color{168, 66, 28, 255}
COLOR_ORANGE :: clay.Color{225, 138, 50, 255}
COLOR_BLACK :: clay.Color{0, 0, 0, 255}

sidebar_item_component :: proc(index : u32){
	if clay.UI(clay.ID("Sidebar Gero", index))({
		layout = clay.LayoutConfig{
			sizing = {
				width = clay.SizingGrow({}),
				height = clay.SizingFixed(50)
			}
		},
		backgroundColor = COLOR_ORANGE,
		}) {}
}

error_handler :: proc "c" (errorData: clay.ErrorData){
		context = runtime.default_context() // <- we need explicit context for c procedures
		log.debug("CLAY ERROR DATA:", errorData)
}

measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
	) -> clay.Dimensions{
		return {
			width = f32(text.length * i32(config.fontSize)),
			height = f32(config.fontSize)
		}
}

headerTextConfig := clay.TextElementConfig {
	fontId = 8,
	fontSize = 45,
	textColor = {50, 250, 150, 250},
	letterSpacing=10,
}

createLayout :: proc(lerpValue: f32, frametime: f32) -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	if clay.UI(clay.ID("OuterContainer"))({
		layout = {layoutDirection =.TopToBottom, sizing = {clay.SizingGrow(), clay.SizingGrow()}}, backgroundColor = {250, 0, 0, 250}}) {
			if clay.UI(clay.ID("Header"))(
				{layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(100)}, childAlignment = {y =.Center}, childGap = 24, padding = {left = 15, right=15}}},
			){
				clay.Text("DirDiff", headerTextConfig)
			}
		}
	return clay.EndLayout(frametime)
}

animationLerpValue: f32 = -1.0

Raylib_Font :: struct {
	fontId: u16,
	font:   rl.Font,
}

raylib_fonts := [dynamic]Raylib_Font{}

clay_color_to_rl_color :: proc(color: clay.Color) -> rl.Color{
	return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

clay_raylib_render :: proc(render_commands : ^clay.ClayArray(clay.RenderCommand), allocator := context.temp_allocator){
	overlay_colors := make([dynamic]clay.Color, allocator)
	for i in 0..< render_commands.length {
		render_command := clay.RenderCommandArray_Get(render_commands, i)
		bounds := render_command.boundingBox

		#partial switch render_command.commandType {
		case .None: // None
		case .Text:
			config := render_command.renderData.text
			text := string(config.stringContents.chars[:config.stringContents.length])
			cstr_text := strings.clone_to_cstring(text, allocator)
			font := rl.GetFontDefault()
			rl.DrawTextEx(font, cstr_text, {bounds.x, bounds.y}, f32(config.fontSize), f32(config.letterSpacing), clay_color_to_rl_color(config.textColor))
		case .OverlayColorStart:
			config := render_command.renderData.overlayColor
			append(&overlay_colors, config.color)
		case .OverlayColorEnd:
			pop(&overlay_colors)
		}

	}
}

// MAIN - ENTRY POINT
// ==================
main :: proc() {

	// ARENA LOGIC
	arena: vmem.Arena
	arena_err := vmem.arena_init_growing(&arena)
	ensure(arena_err == nil)
	arena_alloc: mem.Allocator = vmem.arena_allocator(&arena)

	// Allocations trackers
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	context.logger = log.create_console_logger()

	// CLAY
	screenWidth :i32= 900
	screenHeight :i32= 600

	min_memory_size := clay.MinMemorySize()
	memory := make([^]u8, min_memory_size)
	clay_arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
	clay.Initialize(clay_arena, {f32(screenHeight), f32(screenWidth)}, {handler=error_handler})
	clay.SetMeasureTextFunction(measure_text, nil)
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT, .WINDOW_HIGHDPI})

	// =============== START OF ACTUAL PROGRAM ===================
	rl.InitWindow(screenWidth, screenHeight, "DirDiff")
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))
	geroImage := rl.LoadTexture("assets/images/webcam-toy-foto1.png")


	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)
		screenWidth = rl.GetScreenWidth()
		screenHeight = rl.GetScreenHeight()

		clay.SetLayoutDimensions({cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()})
		clay.SetPointerState(transmute(clay.Vector2)rl.GetMousePosition(), rl.IsMouseButtonDown(rl.MouseButton.LEFT))
		clay.UpdateScrollContainers(false, transmute(clay.Vector2)rl.GetMouseWheelMoveV(), rl.GetFrameTime())

		renderCommands := createLayout(animationLerpValue < 0 ? (animationLerpValue + 1) : (1 - animationLerpValue), rl.GetFrameTime())
		// BEGIN DRAWING
		rl.BeginDrawing()
		clay_raylib_render(&renderCommands)
		rl.EndDrawing()
	}

	// =============== END OF ACTUAL PROGRAM ===================
	free_all(arena_alloc)
	free(clay_arena.memory)

	log.destroy_console_logger(context.logger)

	if len(track.allocation_map) > 0 {
		fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
		for _, entry in track.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	} else {
		fmt.println("\n\n=== ALL GOOD WITH ALLOCATIONS! CONGRATS ===\n\n")
	}
	mem.tracking_allocator_destroy(&track)

}
