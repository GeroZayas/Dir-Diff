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

import "core:fmt"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import "./visuals"

print :: fmt.println
printf :: fmt.printfln




// STRUCTS
// =========

DirectoryInfo :: struct {
	name_dir:         string,
	path:             string,
	total_files:      int,
	files_array: [dynamic]os.File_Info,
}


// PROCEDURES
// ===========

welcome_header :: proc() {
	print("")
	printf("%v          ====================%v", visuals.BOLD_RED, visuals.RESET)
	printf("%v          ||||  DIR DIFF  ||||%v", visuals.BOLD_YELLOW, visuals.RESET)
	printf("%v          ====================%v", visuals.BOLD_RED, visuals.RESET)
	printf("%vWelcome! Insert the paths of the two dirs to compare:%v", visuals.BOLD_BLUE, visuals.RESET)
	print("")
}

/*
Returns a DirectoryInfo struct
*/
get_array_file_names :: proc(dir_path: string, print_file_names: bool = false, arena_alloc: mem.Allocator) -> DirectoryInfo {
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
		name_dir        = dir_name,
		total_files     = total_files,
		files_array 	= files_array,
		path            = abs_path,
	}

	return dir_info

}

return_big_then_small_dir :: proc(dir_a, dir_b: DirectoryInfo, allocator: mem.Allocator) -> [2]DirectoryInfo {

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

	big_then_small_dirs_array: [2]DirectoryInfo = return_big_then_small_dir(path1_dir^, path2_dir^, allocator = arena_alloc)
	printf("Biggest DIR: %v", big_then_small_dirs_array[0].name_dir)
	printf("Biggest DIR Path: %v", big_then_small_dirs_array[0].path)

	return big_then_small_dirs_array
}

find_duplicates_in_two_dirs :: proc(dir_a, dir_b: DirectoryInfo, alloc: mem.Allocator) -> [dynamic]string {
	// TODO(gero): Measure mathematically which one is better, or if it is the same exactly:
	// 1st for loop the dir with more files, 2nd loop dir with fewer, OR the other way around

	// Dir A has to be the dir with the most files
	duplicates := make([dynamic]string, alloc)

	more_files_dir_array := dir_a.files_array
	fewer_files_dir_array := dir_b.files_array

	stopwatch : time.Stopwatch

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

	// =============== START OF ACTUAL PROGRAM ===================
	title := " WELCOME to DIR DIFF "
	visuals.title(title, line_color="yellow", text_color="blue")
	// welcome_header()
	// if get_paths_dirs(true) <- true means hardcoded paths for testing. MAKE IT FALSE when for real

	str1 := " Default is DEBUG -> hardcoded dirs' paths "
	str1 = strings.centre_justify(str1, 100, "=", allocator = arena_alloc)
	str2 := " Type `Y` for DEBUG `N` to type in the dirs' paths (Hit `ENTER` for default): "
	str2 = strings.centre_justify(str2, 100, "=", allocator = arena_alloc)

	prompt := strings.concatenate({str1, "\n", str2}, allocator = arena_alloc)

	user_input := get_user_input(prompt_message = prompt, allocator = arena_alloc)
	user_input = clean_user_input(user_input, arena_alloc)

	DEBUG: bool
	if user_input == "y" {
		DEBUG = true
	} else if user_input == "n" {
		DEBUG = false
	}

	printf("DEBUG IS %v", DEBUG)

	// TODO(gero) take this /* */ comment marks out:
	big_then_small_dirs_array: [2]DirectoryInfo = get_paths_dirs(DEBUG, arena_alloc)

	big_dir, small_dir := big_then_small_dirs_array[0], big_then_small_dirs_array[1]

	duplicates := find_duplicates_in_two_dirs(big_dir, small_dir, arena_alloc)

	exist_duplicates: bool = len(duplicates) > 0

	log.debug("exist_duplicates", exist_duplicates)

	if exist_duplicates {
		print_all_duplicates(duplicates)
	}

	prompt = `
	>> INPUT 'm' to move these duplicates to new a new dir called "duplicates"
	>> INPUT 'd' to delete all these duplicate files
	`
	user_input = get_user_input(prompt_message = prompt, allocator = arena_alloc)
	user_input = clean_user_input(user_input, arena_alloc)

	switch user_input {
	case "m":
		printf("%vYOU HAVE SELECTED: MOVE FILES%v", visuals.BOLD_YELLOW, visuals.RESET)
		printf(
			"This will move the duplicates files from >> %v << to a new dir called `duplicates`",
			big_dir.path,
		)
		printf("In the PARENT path of >> %v <<", big_dir.path)
		prompt = `
		>> Type "y" to confirm, "n" to cancel
		`
		move_user_input := get_user_input(prompt_message = prompt, allocator = arena_alloc)
		move_user_input = clean_user_input(move_user_input, arena_alloc)
		if move_user_input == "y" {
			printf("%v\n>>>>>>>>> MOVING FILES >>>>>>>>> %v", visuals.BOLD_YELLOW, visuals.RESET)
			new_path, np_err := filepath.join({big_dir.path, "duplicates"}, arena_alloc)
			if np_err != nil {
				fmt.eprintln("NEW PATH ERROR", np_err)
			}
			// if the DIR does not exist already, we create one else, just jump to the next part
			if !os.is_dir(new_path) {
				mkdir_err := os.make_directory(new_path)
				if mkdir_err != nil {
					fmt.eprintfln("ERROR %v", mkdir_err)
				}
			}

			// TODO we want to copy all the duplicate files into the new path
			for dup, index in duplicates {
				if dup != "" {
					// log.debug(dup)
					printf("COPYING %i - %s", index + 1, dup)
					source := strings.concatenate({big_dir.path, "/", dup}, arena_alloc)
					destination := strings.concatenate({new_path, "/", dup}, arena_alloc)
					// log.debug("SOURCE= ", source) // could be EISDIR :: _Platform_Error.EISDIR
					// log.debug("DESTINATION= ", destination)
					c_err := os.copy_file(dst_path = destination, src_path = source)
					if c_err != nil {
						log.error("COPY ERROR= ", c_err)
					}
					rm_err := os.remove(name = source)
					if rm_err != nil {
						log.error("REMOVE ERROR= ", c_err)
					}

				}
			}
			printf("%v\n============================= %v", visuals.REG_CYAN, visuals.RESET)
			printf("%v\nDONE DONE DONE %v", visuals.REG_CYAN, visuals.RESET)
			printf("%v\n============================= %v", visuals.REG_CYAN, visuals.RESET)


		} else {
			printf("%v\n>>>>>>>>> You CANCELLED the Move >>>>>>>>>%v", visuals.BOLD_RED, visuals.RESET)
		}

	case "d":
		printf("%vYOU HAVE SELECTED: DELETE FILES%v", visuals.BOLD_RED, visuals.RESET)
		// TODO we want to copy all the duplicate files into the new path
		for dup, index in duplicates {
			if dup != "" {

				printf("DELETING %i - %s", index + 1, dup)
				source := strings.concatenate({big_dir.path, "/", dup}, arena_alloc)
				rm_err := os.remove(name = source)
				if rm_err != nil {
					log.error("REMOVE ERROR= ", rm_err)
				}

			}
		}
	case:
		print("UNKNOWN COMMAND")
	}


	// NOTES:
	// we have to know which FILES are in both dirs.

	// TODO(gero)
	// 1) Ask the user what to do with the duplicates
	// OPTIONS: a) delete all duplicates from a selected dir, by default the one with more files
	//          b) move all those files to a brand new dir
	//          c) Do nothing - just put the results in a txt or md file if user wants that
	// 2)
	// 3)
	// 4) Write tests (do not be lazy, Gero)


	// =============== END OF ACTUAL PROGRAM ===================
	free_all(arena_alloc)

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
