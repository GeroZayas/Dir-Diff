package visuals
import "core:fmt"
import "core:strings"

// UI ELEMENTS CONSTANTS
LINE_80c :: "================================================================================"
LINE_100c :: "===================================================================================================="
LINE_120c :: "========================================================================================================================"



// =========
// COLOR CONSTANTS
// TODO(gero): put a lot more colors here
// https://gist.github.com/JBlond/2fea43a3049b38287e5e9cefc87b2124
RESET := "\e[0m"


// Regular Colors
REG_BLACK 	:: "\e[0;30m"
REG_RED 	:: "\e[0;31m"
REG_GREEN 	:: "\e[0;32m"
REG_YELLOW 	:: "\e[0;33m"
REG_BLUE 	:: "\e[0;34m"
REG_PURPLE 	:: "\e[0;35m"
REG_CYAN 	:: "\e[0;36m"
REG_White 	:: "\e[0;37m"

// Bold
BOLD_BLACK 	:: "\e[1;30m"
BOLD_RED 	:: "\e[1;31m"
BOLD_GREEN 	:: "\e[1;32m"
BOLD_YELLOW :: "\e[1;33m"
BOLD_BLUE 	:: "\e[1;34m"
BOLD_PURPLE :: "\e[1;35m"
BOLD_CYAN 	:: "\e[1;36m"
BOLD_WHITE 	:: "\e[1;37m"

// Underline

UNDER_BLACK 	:: "\e[4;30m"
UNDER_RED 		:: "\e[4;31m"
UNDER_GREEN 	:: "\e[4;32m"
UNDER_YELLOW 	:: "\e[4;33m"
UNDER_BLUE 		:: "\e[4;34m"
UNDER_PURPLE 	:: "\e[4;35m"
UNDER_CYAN 		:: "\e[4;36m"
UNDER_WHITE 	:: "\e[4;37m"

// Background
BG_BLACK 	:: "\e[40m"
BG_RED 		:: "\e[41m"
BG_GREEN 	:: "\e[42m"
BG_YELLOW 	:: "\e[43m"
BG_BLUE 	:: "\e[44m"
BG_PURPLE 	:: "\e[45m"
BG_CYAN 	:: "\e[46m"
BG_WHITE 	:: "\e[47m"

get_color_from_string :: proc(color:string) -> string{
	switch color {
		case "red":
			return REG_RED
		case "yellow":
			return REG_YELLOW
		case "blue":
			return REG_BLUE
		case:

			return "nothing"
	}
}

title :: proc(content: string, line_color: string = "red", text_color: string = "yellow") {
	to_print := strings.center_justify(content, 100, "-")
	line_selected_color : string = get_color_from_string(line_color)
	text_selected_color : string = get_color_from_string(text_color)
	fmt.println(line_selected_color, LINE_100c, RESET)
	fmt.println(text_selected_color, to_print, RESET)
	fmt.println(line_selected_color, LINE_100c, RESET)
}

main :: proc() {
}
