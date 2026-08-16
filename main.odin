/*
- get all files from dir 1, and dir 2
- common files array
- take the dir with more files
- loop over each file, compare if found in array of files of other dir
- when matched, save name to common files array

Another way is to do set logic

*/

package dir_diff

import "core:fmt"
import "core:os"
import "core:strings"

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
	name_dir: string,
	total_files: int,
	file_names_array : [dynamic]string
}



// PROCEDURES
// ===========

welcome_header :: proc(){
	print("")
	printf("%v          ====================%v", RED, RESET)
	printf("%v          ||||  DIR DIFF  ||||%v", BOLD_YELLOW, RESET)
	printf("%v          ====================%v", RED, RESET)
	printf("%vWelcome! Insert the paths of the two dirs to compare:%v", HIGH_BLUE, RESET)
	print("")
}

/*
Returns an array of strings with the names of all files in the dir & the total amount of files in the dir
*/
get_array_file_names :: proc(dir_path: string, print_file_names: bool = false) -> (DirectoryInfo){

	files_info_array, err := os.read_all_directory_by_path(dir_path, context.allocator)
	total_files := len(files_info_array)

	// BASE for name of dir
	dir_name := os.base(dir_path)

	file_names_array : [dynamic]string
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

	dir_info := DirectoryInfo{
		name_dir = dir_name,
		total_files = total_files,
		file_names_array = file_names_array
	}

	return dir_info

}

find_bigger_dir :: proc(dir_a, dir_b: DirectoryInfo ) -> (string) {

	a := dir_a.total_files
	b := dir_b.total_files

	res := "The Dir with the most files is: "

	if a >= b {
		res = strings.concatenate({res, dir_a.name_dir})
		printf("%vRES: %v%v", BOLD_YELLOW, res, RESET)
		return res
	} else {
		res = strings.concatenate({res, dir_b.name_dir})
		printf("%vRES: %v%v", BOLD_YELLOW, res, RESET)
		return res
	}
}

get_paths_dirs :: proc(){
	buffer : [1024]byte
	// get input from the user
	print("Insert DIR 1 path: ")
	path1, err_1 := os.read(os.stdin, buffer[:])
	if err_1 != nil {
		fmt.eprintln("ERROR with PATH 1:", err_1)
		return
	}

	print("Insert DIR 2 path: ")
 	path2, err_2 := os.read(os.stdin, buffer[path1:])
	if err_1 != nil {
		fmt.eprintln("ERROR with PATH 1:", err_1)
		return
	}
	path1_str := string(buffer[:path1])
	path2_str := string(buffer[path1:path1+path2])

	path1_str = strings.trim_right(path1_str, "\n")
	path2_str = strings.trim_right(path2_str, "\n")

	printf("path1_str ==> : %v", path1_str)
	printf("path2_str ==> : %v", path2_str)

	// path1_str := "/Users/gero/Documents/Obsidian-docs/Coding-Books"
	// path2_str := "/Users/gero/Documents/Obsidian-docs/Obsidian-Gero-Zayas"

	path1_dir := get_array_file_names(path1_str)
	path2_dir := get_array_file_names(path2_str)	


	// print(path1_dir)
	// print(path2_dir)
	printf("BIGGER FILE %v", find_bigger_dir(path1_dir, path2_dir))
}



// MAIN - ENTRY POINT 
// ==================

main :: proc(){
	welcome_header()
	get_paths_dirs()

	// path_dir_1, path_dir_2 := get_paths_dirs()
	// result := compare_dirs(path_dir_1, path_dir_2)

	// print(result)
}
