## Learning on allocations:

### First: Use always, or often, this tracking allocator piece of code:

This will help find out about the non deallocated memory

```odin
main :: proc(){

	// Allocations trackers
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	context.logger = log.create_console_logger()

	// -------------------
	// PROGRAM HERE ...
	// -------------------
	
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
```

### Second: delete the created dynamic arrays:

```odin
	file_names_array : [dynamic]string
	defer delete(file_names_array) // <---

	// (...)


	find_duplicates_in_two_dirs :: proc(dir_a, dir_b: DirectoryInfo) -> ([dynamic]string){
	duplicates : [dynamic]string
	defer delete(duplicates) // <---
```


### Third: put all data in an Arena or similar:

```odin
get_array_file_names :: proc(dir_path: string, print_file_names: bool = false, arena_alloc: mem.Allocator) -> (DirectoryInfo){
	files_info_array, err := os.read_all_directory_by_path(dir_path, arena_alloc)
	// (...)
```

Note the `arena_alloc: mem.Allocator` arg and then its use in `os.read_all_directory_by_path(dir_path, arena_alloc)`.
Then you just have to free the whole arena: `free_all(arena_alloc)` and that's it!


### Fourth: Careful with input gotten in a proc -> make sure you clone it from the buffer:

For example, here if you don't clone from the bytes of the buffer to a string, you will lose the contents after leaving the scope of the procedure, and you'll find yourself without the expected input string:

```odin
get_user_input :: proc(arena_alloc: mem.Allocator) -> string {
	buffer: [256]byte
	user_input, input_err := os.read(os.stdin, buffer[:])
	assert(input_err == nil)
	user_input_str := strings.clone_from_bytes(buffer[:user_input], arena_alloc)
	return user_input_str
}
```

Note this part `strings.clone_from_bytes(buffer[:user_input], arena_alloc)` and also note how we allocate to the arena we create it. We're putting everything in the same arena in this case.

---
### Important when working with cstring:
It is better to import `strings` and do `strings.clone_from_ctring(the_cstring)` than trying to cast it, because it can look very weird.

---
### On Using `strings.join()` and the context.temp_allocator

I have seen that one can get growing allocations because of the main loop when doing the `strings.join()` like in here:

```odin 
{
	if len(list_files_dropped) == 0 { 
		text_to_put = lorem_ipsum()
	} else {
		text_to_put = strings.join(list_files_dropped[:], "\n", allocator=context.temp_allocator)
	}
	clay.Text(
		text_to_put,
		// lorem_ipsum(),
		{textColor = COLOR_BLACK, fontSize = 15, wrapMode = .Words},
	)
}
```
But the **problem** was that I was declaring and asigning to `text_to_put` right in there and if I was suign this `allocator=context.temp_allocator` then it would be wiped out per frame, so it would not show.

The **solution** has been just declaring `text_to_put` as a global, taking it out of the stack. This way you asign to it per frame.

 
---
# Exploring Gero

### How to drag and drop?

How to open a window for dir selectors?





