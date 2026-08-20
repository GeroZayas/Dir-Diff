/*
- get all files from dir 1, and dir 2
- common files array
- take the dir with more files
- loop over each file, compare if found in array of files of other dir
- when matched, save name to common files array

- It would be great to have something that tells us which copy of the duplicates, was modifed the latest

Another way is to do set logic

*/

package dir_diff

import "core:fmt"
import "core:log"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

print :: fmt.println
printf :: fmt.printfln


// CONSTANTS
// =========

BOLD_YELLOW := "\e[1;33m"
RESET := "\e[0m"
HIGH_BLUE := "\e[1;94m"
RED := "\e[0;91m"


// STRUCTS
// =========

DirectoryInfo :: struct {
	name_dir:         string,
	path:             string,
	total_files:      int,
	file_names_array: [dynamic]string,
}


// PROCEDURES
// ===========

welcome_header :: proc() {
	print("")
	printf("%v          ====================%v", RED, RESET)
	printf("%v          ||||  DIR DIFF  ||||%v", BOLD_YELLOW, RESET)
	printf("%v          ====================%v", RED, RESET)
	printf("%vWelcome! Insert the paths of the two dirs to compare:%v", HIGH_BLUE, RESET)
	print("")
}

/*
Returns a DirectoryInfo struct
*/
get_array_file_names :: proc(
	dir_path: string,
	print_file_names: bool = false,
	arena_alloc: mem.Allocator,
) -> DirectoryInfo {

	files_info_array, err := os.read_all_directory_by_path(dir_path, arena_alloc)
	total_files := len(files_info_array)

	// BASE for name of dir
	dir_name := os.base(dir_path)

	file_names_array: [dynamic]string
	defer delete(file_names_array)

	for file in files_info_array {
		append(&file_names_array, file.name)
	}

	if print_file_names {
		for name in file_names_array {
			print("=============================")
			print(name)
		}
	}

	abs_path, _ := os.get_absolute_path(dir_path, arena_alloc)
	log.debug("ABS PATH >>>>>>>>>>>", abs_path)

	dir_info := DirectoryInfo {
		name_dir         = dir_name,
		total_files      = total_files,
		file_names_array = file_names_array,
		path             = abs_path,
	}

	return dir_info

}

find_bigger_dir :: proc(dir_a, dir_b: DirectoryInfo, allocator: mem.Allocator) -> DirectoryInfo {

	res := "The Dir with the most files is: "

	if dir_a.total_files >= dir_b.total_files {
		res = strings.concatenate({res, dir_a.name_dir}, allocator = allocator)

		printf("%v%v with %v files %v", BOLD_YELLOW, res, dir_a.total_files, RESET)
		return dir_a
	} else {
		res = strings.concatenate({res, dir_b.name_dir}, allocator = allocator)
		printf("%v%v with %v files %v", BOLD_YELLOW, res, dir_b.total_files, RESET)
		return dir_b
	}
}

get_paths_dirs :: proc(debug: bool, arena_alloc: mem.Allocator) -> [2]DirectoryInfo {
	path1_str := new(string, arena_alloc)
	path2_str := new(string, arena_alloc)
	// FOR testing and debugging only:
	if debug {
		path1_str^ = "/Users/gero/Documents/Obsidian-docs/Coding-Books"
		path2_str^ = "/Users/gero/Documents/Obsidian-docs/Obsidian-Gero-Zayas"
	} else {
		buffer: [1024]byte
		// get input from the user
		print("Insert DIR 1 path: ")
		path1, err_1 := os.read(os.stdin, buffer[:])
		if err_1 != nil {
			fmt.eprintln("ERROR with PATH 1:", err_1)
			panic("ERROR with PATH 1")
		}

		print("Insert DIR 2 path: ")
		path2, err_2 := os.read(os.stdin, buffer[path1:])
		if err_2 != nil {
			fmt.eprintln("ERROR with PATH 2:", err_2)
			panic("ERROR with PATH 2")
		}
		path1_str^ = string(buffer[:path1])
		path2_str^ = string(buffer[path1:path1 + path2])

		path1_str^ = strings.trim_right(path1_str^, "\n")
		path2_str^ = strings.trim_right(path2_str^, "\n")
	}

	path1_dir := new(DirectoryInfo, arena_alloc)
	path2_dir := new(DirectoryInfo, arena_alloc)

	path1_dir^ = get_array_file_names(path1_str^, arena_alloc = arena_alloc)
	path2_dir^ = get_array_file_names(path2_str^, arena_alloc = arena_alloc)

	// TODO(gero) Check this in the future:
	// NOTE: we do assume, for the time being, that the biggest dir is the one containing duplicates
	// BUT this is not necessarily the case always

	biggest_dir: DirectoryInfo = find_bigger_dir(path1_dir^, path2_dir^, allocator = arena_alloc)
	other_dir: DirectoryInfo =
		path1_dir^ if path1_dir^.name_dir != biggest_dir.name_dir else path2_dir^
	printf("Biggest DIR: %v", biggest_dir.name_dir)
	printf("Biggest DIR Path: %v", biggest_dir.path)

	return {biggest_dir, other_dir}
}

find_duplicates_in_two_dirs :: proc(dir_a, dir_b: DirectoryInfo) -> [dynamic]string {
	// TODO(gero): Measure mathematically which one is better, or if it is the same exactly:
	// 1st for loop the dir with more files, 2nd loop dir with fewer, OR the other way around

	// Dir A has to be the dir with the most files
	duplicates: [dynamic]string
	defer delete(duplicates)

	more_files_dir_array := dir_a.file_names_array
	fewer_files_dir_array := dir_b.file_names_array

	// NOTE: we are gonna loop over the fewer files dir - outer loop, more dirs - inner loop
	for file_i in fewer_files_dir_array {
		for file_j in more_files_dir_array {
			if file_i == file_j {
				append(&duplicates, file_i)
			}
		}
	}

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

	welcome_header()
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
	dirs := get_paths_dirs(DEBUG, arena_alloc)
	biggest_dir, other_dir := dirs[0], dirs[1]
	duplicates := find_duplicates_in_two_dirs(biggest_dir, other_dir)

	print("DUPLICATES ARE:")
	print("========================================")
	printf("TOTAL: %i", len(duplicates))
	print("========================================")
	for dup, index in duplicates {
		if dup != "" {
			printf("%i ==> %s", index + 1, dup)
		}
	}
	print("========================================")

	prompt = `
	>> INPUT 'm' to move these duplicates to new a new dir called "duplicates"
	>> INPUT 'd' to delete all these duplicate files
	`
	user_input = get_user_input(prompt_message = prompt, allocator = arena_alloc)
	user_input = clean_user_input(user_input, arena_alloc)

	switch user_input {
	case "m":
		printf("%vYOU HAVE SELECTED: MOVE FILES%v", BOLD_YELLOW, RESET)
		printf(
			"This will move the duplicates files from >> %v << to a new dir called `duplicates`",
			biggest_dir.name_dir,
		)
		printf("In the PARENT path of >> %v <<", biggest_dir.path)
		prompt = `
		>> Type "y" to confirm, "n" to cancel
		`
		move_user_input := get_user_input(prompt_message = prompt, allocator = arena_alloc)
		move_user_input = clean_user_input(move_user_input, arena_alloc)
		if move_user_input == "y" {
			printf("%v\n>>>>>>>>> MOVING FILES >>>>>>>>> %v", BOLD_YELLOW, RESET)
			new_path := strings.concatenate({biggest_dir.path, "/duplicates"}, arena_alloc)
			log.debug("NEW PATH:", new_path)

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
					source := strings.concatenate({biggest_dir.path, "/", dup}, arena_alloc)
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
			printf("%v\n============================= %v", HIGH_BLUE, RESET)
			printf("%v\nDONE DONE DONE %v", HIGH_BLUE, RESET)
			printf("%v\n============================= %v", HIGH_BLUE, RESET)


		} else {
			printf("%v\n>>>>>>>>> You CANCELLED the Move >>>>>>>>>%v", RED, RESET)
		}

	case "d":
		printf("%vYOU HAVE SELECTED: DELETE FILES%v", RED, RESET)
		// TODO we want to copy all the duplicate files into the new path
		for dup, index in duplicates {
			if dup != "" {

				printf("DELETING %i - %s", index + 1, dup)
				source := strings.concatenate({biggest_dir.path, "/", dup}, arena_alloc)
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
