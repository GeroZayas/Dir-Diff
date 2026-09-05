/* //////////////////////////////////////////////////////////////
=== UTILS ===
* Go to https://htmlcolorcodes.com/es/
To try and conform RGA colors




*////////////////////////////////////////////////////////////////


package dir_diff

import "./visuals"
import "base:runtime"
import clay "clay-odin"
import "core:c"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import rl "vendor:raylib"


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

// Colors for top stripe
COLOR_TOP_BORDER_1 :: clay.Color{168, 66, 28, 255}
COLOR_TOP_BORDER_2 :: clay.Color{223, 110, 44, 255}
COLOR_TOP_BORDER_3 :: clay.Color{225, 138, 50, 255}
COLOR_TOP_BORDER_4 :: clay.Color{236, 189, 80, 255}
COLOR_TOP_BORDER_5 :: clay.Color{240, 213, 137, 255}

COLOR_LIGHT :: clay.Color{244, 235, 230, 255}
COLOR_LIGHT_LIGHTER :: clay.Color{230, 225, 225, 255}
COLOR_LIGHTGRAYGERO_1 :: clay.Color{0, 0, 0, 255 * 0.1}
COLOR_LIGHTGRAYGERO_2 :: clay.Color{0, 0, 0, 255 * 0.2}
COLOR_LIGHT_HOVER :: clay.Color{224, 215, 210, 255}
COLOR_BUTTON_HOVER :: clay.Color{238, 227, 225, 255}
COLOR_BROWN :: clay.Color{61, 26, 5, 255}
//COLOR_RED :: clay.Color {252, 67, 27, 255}
COLOR_RED :: clay.Color{168, 66, 28, 255}
COLOR_RED_HOVER :: clay.Color{148, 46, 8, 255}
COLOR_ORANGE :: clay.Color{225, 138, 50, 255}
COLOR_ORANGE_BRIGHTER :: clay.Color{250, 138, 50, 255}
COLOR_BLUE :: clay.Color{111, 173, 162, 255}
COLOR_TEAL :: clay.Color{111, 173, 162, 255}
COLOR_BLUE_DARK :: clay.Color{2, 32, 82, 255}
COLOR_BLACK :: clay.Color{0, 0, 0, 255}


// Pictures
geroImage: rl.Texture2D = {}
dir_one: rl.Texture2D = {}


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

get_center_text :: proc(width, height: f32, text: cstring, text_fs: int) -> rl.Vector2 {
	text_len := rl.MeasureText(text, i32(text_fs))
	// log.debug(text_len)
	x: f32 = width / 2 - f32(text_len / 2)
	y: f32 = height / 2 - f32(text_fs / 2)
	return {x, y}
}

// ============== CLAY ==============

sidebar_item_component :: proc(index: u32) {
	if clay.UI(clay.ID("Sidebar Gero", index))(
	{
		layout = clay.LayoutConfig {
			sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(50)},
		},
		backgroundColor = COLOR_ORANGE,
	},
	) {}
}

error_handler :: proc "c" (errorData: clay.ErrorData) {
	context = runtime.default_context() // <- we need explicit context for c procedures
	log.debug("CLAY ERROR DATA:", errorData)
}

measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	line_width: f32 = 0
	font := raylib_fonts[config.fontId].font
	text_str := string(text.chars[:text.length])

	for i in 0 ..< len(text_str) {
		glyph_index := text_str[i] - 32
		glyph := font.glyphs[glyph_index]
		if glyph.advanceX != 0 {
			line_width += f32(glyph.advanceX)
		} else {
			line_width += font.recs[glyph_index].width + f32(font.glyphs[glyph_index].offsetX)
		}
	}
	scale_factor := f32(config.fontSize) / f32(font.baseSize)
	total_spacing := f32(len(text_str)) * f32(config.letterSpacing)

	return {width = line_width * scale_factor + total_spacing, height = f32(config.fontSize)}
}

headerTextConfig := clay.TextElementConfig {
	fontId        = 8,
	fontSize      = 50,
	textColor     = COLOR_ORANGE,
	letterSpacing = 5,
}


border_config_1 := clay.BorderElementConfig {
	color = COLOR_BLUE,
	width = {5, 5, 5, 5, 5},
}
border_config_2 := clay.BorderElementConfig {
	color = COLOR_BROWN,
	width = {5, 5, 5, 5, 5},
}

write_to_log :: proc(data: string) {
	os_err := os.write_entire_file("log.txt", data)
}


/*
BASE FOR ELEMENTS
-------------------------------------
if clay.UI(clay.ID("ID-HERE"))({

	}){}

-------------------------------------
ElementDeclaration :: struct {
	layout:          LayoutConfig,
	backgroundColor: Color,
	overlayColor:    Color,
	cornerRadius:    CornerRadius,
	aspectRatio:     AspectRatioElementConfig,
	image:           ImageElementConfig,
	floating:        FloatingElementConfig,
	custom:          CustomElementConfig,
	clip:            ClipElementConfig,
	border:          BorderElementConfig,
	transition:      TransitionElementConfig,
	userData:        rawptr,
}


*/


draw_stripe :: proc(id: string, color: clay.Color, w: f32 = 0, h: f32 = 15) {
	if clay.UI(clay.ID(id))(
	{
		layout = {
			sizing = {clay.SizingGrow() if w == 0 else clay.SizingFixed(w), clay.SizingFixed(h)},
			layoutDirection = .TopToBottom,
		},
		backgroundColor = color,
	},
	) {}

}

draw_space :: proc(color: clay.Color, id: string, sizing: f32 = 20) {
	if clay.UI(clay.ID(id))(
	{layout = {sizing = {clay.SizingGrow(), clay.SizingFixed(sizing)}}, backgroundColor = color},
	) {}
}


fade_out_transition :: proc() -> clay.TransitionElementConfig {
	transition: clay.TransitionElementConfig = {
		handler    = clay.EaseOut,
		duration   = clay.Hovered() && clay.GetPointerState().state != clay.PointerDataInteractionState.PressedThisFrame ? 0.8 : 0.5,
		properties = {clay.TransitionPropertyFlags.BackgroundColor},
	}
	return transition
}

foo :: proc "c" (
	initial_state: clay.TransitionData,
	properties: clay.TransitionPropertyFlags,
) -> clay.TransitionData {
	target: clay.TransitionData
	if .BackgroundColor in properties {
		target = {
			boundingBox     = {100, 100, 100, 100},
			backgroundColor = COLOR_RED,
			overlayColor    = COLOR_BLUE,
			borderColor     = COLOR_ORANGE,
			borderWidth     = {3, 3, 3, 3, 3},
		}
	}

	return target
}

rectangle_trans_elem_config :: proc() -> clay.TransitionElementConfig {
	transition: clay.TransitionElementConfig
	transition = {
		handler             = clay.EaseOut,
		duration            = 0.2,
		properties          = {.Width, .BackgroundColor, .Height},
		interactionHandling = .AllowInteractionsWhileTransitioningPosition,
	}
	return transition

}

// *** BBB
lorem_ipsum :: proc() -> (lorem: string) {
	lorem = `
	Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. 
	In id cursus mi pretium tellus duis convallis. 
	Tempus leo eu aenean sed diam urna tempor. 
	Pulvinar vivamus fringilla lacus nec metus bibendum egestas. 
	Iaculis massa nisl malesuada lacinia integer nunc posuere. 
	Ut hendrerit semper vel class aptent taciti sociosqu. 
	Ad litora torquent per conubia nostra inceptos himenaeos.

		Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. 
	In id cursus mi pretium tellus duis convallis. 
	Tempus leo eu aenean sed diam urna tempor. 
	Pulvinar vivamus fringilla lacus nec metus bibendum egestas. 
	Iaculis massa nisl malesuada lacinia integer nunc posuere. 
	Ut hendrerit semper vel class aptent taciti sociosqu. 
	Ad litora torquent per conubia nostra inceptos himenaeos.

		Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. 
	In id cursus mi pretium tellus duis convallis. 
	Tempus leo eu aenean sed diam urna tempor. 
	Pulvinar vivamus fringilla lacus nec metus bibendum egestas. 
	Iaculis massa nisl malesuada lacinia integer nunc posuere. 
	Ut hendrerit semper vel class aptent taciti sociosqu. 
	Ad litora torquent per conubia nostra inceptos himenaeos.

			Lorem ipsum dolor sit amet consectetur adipiscing elit. Quisque faucibus ex sapien vitae pellentesque sem placerat. 
	In id cursus mi pretium tellus duis convallis. 
	Tempus leo eu aenean sed diam urna tempor. 
	Pulvinar vivamus fringilla lacus nec metus bibendum egestas. 
	Iaculis massa nisl malesuada lacinia integer nunc posuere. 
	Ut hendrerit semper vel class aptent taciti sociosqu. 
	Ad litora torquent per conubia nostra inceptos himenaeos.
	`
	return
}


createLayout :: proc(lerpValue: f32, frametime: f32) -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	if clay.UI(clay.ID("OuterContainer"))(
	{
		layout = {
			sizing          = {clay.SizingGrow(), clay.SizingGrow()},
			// padding = clay.PaddingAll(2),
			layoutDirection = .TopToBottom,
		},
		backgroundColor = COLOR_LIGHT,
	},
	) {
		draw_stripe("stripe1", cast(clay.Color)rl.WHITE, h = 10)
		draw_stripe("stripe2", cast(clay.Color)rl.GOLD, h = 8)
		draw_stripe("stripe3", cast(clay.Color)rl.ORANGE, h = 6)
		if clay.UI(clay.ID("Header"))(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFixed(50)},
				padding = clay.PaddingAll(10),
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = clay.Hovered() ? COLOR_ORANGE_BRIGHTER : COLOR_ORANGE,
			transition = {handler = clay.EaseOut, duration = 0.5, properties = {.BackgroundColor}},
		},
		) {
			clay.Text(
				"DirDiff",
				clay.TextElementConfig {
					fontId = 8,
					fontSize = 45,
					textColor = cast(clay.Color)rl.RAYWHITE,
					letterSpacing = 10,
				},
			)
		}
		if clay.UI(clay.ID("SubHeaderVersionAndData"))(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFixed(8)},
				padding = clay.PaddingAll(2),
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = COLOR_BROWN,
		},
		) {

		}
		if clay.UI(clay.ID("SubHeader"))(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFixed(25)},
				padding = clay.PaddingAll(10),
				childAlignment = {x = .Center, y = .Center},
			},
			backgroundColor = COLOR_RED,
		},
		) {
			clay.Text(
				"Compare Dirs - Manage Duplicates",
				clay.TextElementConfig {
					fontId        = 8,
					// fontSize = clay.Hovered() ? 22 : 20,
					fontSize      = 20,
					textColor     = cast(clay.Color)rl.RAYWHITE,
					letterSpacing = 2,
				},
			)
		}
		// draw_stripe("stripe3", cast(clay.Color)rl.ORANGE, h = 6)
		// draw_stripe("stripe2", cast(clay.Color)rl.GOLD, h = 8)
		// draw_stripe("stripe1", cast(clay.Color)rl.WHITE, h = 10)

		draw_space(id = "Space1", color = COLOR_BROWN, sizing = 8)


		if clay.UI(clay.ID("OuterDropDirContainer"))(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				// padding = clay.PaddingAll(10),
				childAlignment = {x = .Center, y = .Center},
				layoutDirection = .LeftToRight,
			},
		},
		) {

			if clay.UI(clay.ID("DropDirContainer"))(
			{
				layout = {
					sizing = {clay.SizingFixed(550), clay.SizingFixed(280)},
					padding = clay.PaddingAll(5),
					childAlignment = {x = .Center, y = .Center},
					layoutDirection = .LeftToRight,
					childGap = 20,
				},
				backgroundColor = cast(clay.Color)rl.WHITE,
				cornerRadius = clay.CornerRadiusAll(5),
			},
			) {
				if clay.UI(clay.ID("DropDir1Container"))(
				{
					layout = {
						sizing = {clay.SizingGrow(), clay.SizingGrow()},
						layoutDirection = .TopToBottom,
						childAlignment = {x = .Center, y = .Center},
						childGap = 10,
					},
				},
				) {
					clay.Text(
						"Drag & Drop Dir 1",
						clay.TextElementConfig {
							fontId = 8,
							fontSize = 18,
							textColor = cast(clay.Color)rl.RED,
							letterSpacing = 2,
						},
					)
					if clay.UI(clay.ID("DropDir1"))(
					{
						layout = {
							sizing = {clay.SizingFixed(200), clay.SizingFixed(200)},
							childAlignment = {x = .Center, y = .Center},
							// padding = clay.PaddingAll(2),
							layoutDirection = .TopToBottom,
						},
						// backgroundColor = clay.Hovered() ? COLOR_LIGHTGRAYGERO_2 : COLOR_LIGHTGRAYGERO_1,
						backgroundColor = clay.Hovered() ? COLOR_LIGHTGRAYGERO_2 : COLOR_LIGHTGRAYGERO_1,
						cornerRadius = clay.CornerRadiusAll(5),
						transition = fade_out_transition(),
					},
					) {
						if clay.UI(clay.ID("ImageDir"))(
						{
							layout = {sizing = {clay.SizingFixed(50), clay.SizingFixed(50)}},
							image = {imageData = &dir_one},
						},
						) {}

					}
				}
				if clay.UI(clay.ID("DropDir2Container"))(
				{
					layout = {
						sizing = {clay.SizingGrow(), clay.SizingGrow()},
						layoutDirection = .TopToBottom,
						childAlignment = {x = .Center, y = .Center},
						childGap = 10,
					},
				},
				) {
					clay.Text(
						"Drag & Drop Dir 2",
						clay.TextElementConfig {
							fontId = 8,
							fontSize = 18,
							textColor = cast(clay.Color)rl.BLUE,
							letterSpacing = 2,
						},
					)
					if clay.UI(clay.ID("DropDir2"))(
					{
						layout = {
							sizing = {clay.SizingFixed(200), clay.SizingFixed(200)},
							childAlignment = {x = .Center, y = .Center},
							// padding = clay.PaddingAll(2),
							layoutDirection = .TopToBottom,
						},
						backgroundColor = clay.Hovered() ? COLOR_LIGHTGRAYGERO_2 : COLOR_LIGHTGRAYGERO_1,
						cornerRadius = clay.CornerRadiusAll(5),
						transition = fade_out_transition(),
					},
					) {
						if clay.UI(clay.ID("ImageDir"))(
						{
							layout = {sizing = {clay.SizingFixed(50), clay.SizingFixed(50)}},
							image = {imageData = &dir_one},
						},
						) {}
					}
				}
			}
		}

		draw_space(id = "Space2", color = COLOR_LIGHT_LIGHTER)

		if clay.UI(clay.ID("DirsInfoArea"))(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingGrow()},
				childAlignment = {x = .Left, y = .Top},
				layoutDirection = .LeftToRight,
				padding = {5, 0, 5, 0},
			},
			backgroundColor = COLOR_LIGHTGRAYGERO_1,
			border = {COLOR_LIGHT_HOVER, {betweenChildren = 5}},
		},
		) {

			if clay.UI(clay.ID("ScrollContainerDirInfoOne"))(
			{ 	//***
				clip = {vertical = true, childOffset = clay.GetScrollOffset()},
				layout = {
					sizing = {clay.SizingFixed(cast(f32)(rl.GetScreenWidth())/2), clay.SizingGrow()},
					childAlignment = {x = .Left, y = .Top},
					layoutDirection = .LeftToRight,
					padding = {10, 0, 10, 0},
				},
				backgroundColor = COLOR_LIGHT
			},
			) {
				// *** 
				clay.Text(lorem_ipsum(), {textColor = COLOR_BLACK, fontSize = 15, wrapMode = .Words})
			}
			if clay.UI(clay.ID("ScrollContainerDirInfoTwo"))(
			{ 	
				clip = {vertical = true, childOffset = clay.GetScrollOffset()},
				layout = {
					sizing = {clay.SizingFixed(cast(f32)(rl.GetScreenWidth())/2), clay.SizingGrow()},
					childAlignment = {x = .Left, y = .Top},
					layoutDirection = .LeftToRight,
					padding = {10, 0, 10, 0},
				},
				backgroundColor = COLOR_LIGHT
			},
			) {
				// *** 
				clay.Text(lorem_ipsum(), {textColor = COLOR_BLACK, fontSize = 15, wrapMode = .Words})
			}

		}


		// =================================================================
		// --- Footer Area ---
		// =================================================================
		draw_stripe("stripe3", cast(clay.Color)rl.ORANGE, h = 6)
		draw_stripe("stripe2", cast(clay.Color)rl.GOLD, h = 8)
		// draw_stripe("stripe1", cast(clay.Color)rl.WHITE, h = 10)
		if clay.UI(clay.ID("Footer"))(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFixed(20)},
				// padding = clay.PaddingAll(10),
				childAlignment = {x = .Center, y = .Center},
				layoutDirection = .TopToBottom,
			},
			backgroundColor = cast(clay.Color)rl.WHITE,
			border = {COLOR_RED, {betweenChildren = 2}},
		},
		) {
			clay.Text(
				"v0.1.0 - Gero Zayas",
				clay.TextElementConfig {
					fontId = 8,
					fontSize = 15,
					textColor = cast(clay.Color)rl.BROWN,
					letterSpacing = 2,
				},
			)
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

load_font :: proc(fontId: u16, fontSize: u16, path: cstring) {
	assign_at(
		&raylib_fonts,
		fontId,
		Raylib_Font {
			font = rl.LoadFontEx(path, cast(i32)fontSize * 6, nil, 0),
			fontId = cast(u16)fontId,
		},
	)
	rl.SetTextureFilter(raylib_fonts[fontId].font.texture, rl.TextureFilter.BILINEAR)
}

clay_color_to_rl_color :: proc(color: clay.Color) -> rl.Color {
	return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

clay_raylib_render :: proc(
	render_commands: ^clay.ClayArray(clay.RenderCommand),
	allocator := context.temp_allocator,
) {
	overlay_colors := make([dynamic]clay.Color, allocator)
	for i in 0 ..< render_commands.length {
		render_command := clay.RenderCommandArray_Get(render_commands, i)
		bounds := render_command.boundingBox

		switch render_command.commandType {
		case .None: // None
		case .Text:
			config := render_command.renderData.text
			text := string(config.stringContents.chars[:config.stringContents.length])
			cstr_text := strings.clone_to_cstring(text, allocator)
			font := raylib_fonts[config.fontId].font
			rl.DrawTextEx(
				font,
				cstr_text,
				{bounds.x, bounds.y},
				f32(config.fontSize),
				f32(config.letterSpacing),
				clay_color_to_rl_color(config.textColor),
			)

		case .Image:
			config := render_command.renderData.image
			tint: clay.Color
			if len(overlay_colors) > 0 {
				tint = overlay_colors[len(overlay_colors) - 1]
			}
			if tint == 0 {
				tint = {255, 255, 255, 255}
			}

			imageTexture := (^rl.Texture2D)(config.imageData)
			rl.DrawTextureEx(
				imageTexture^,
				{bounds.x, bounds.y},
				0,
				bounds.width / f32(imageTexture.width),
				clay_color_to_rl_color(tint),
			)

		case .ScissorStart:
			rl.BeginScissorMode(
				i32(math.round(bounds.x)),
				i32(math.round(bounds.y)),
				i32(math.round(bounds.width)),
				i32(math.round(bounds.height)),
			)
		case .ScissorEnd:
			rl.EndScissorMode()
		case .Rectangle:
			config := render_command.renderData.rectangle
			if config.cornerRadius.topLeft > 0 {
				radius: f32 = (config.cornerRadius.topLeft * 2) / min(bounds.width, bounds.height)
				draw_rect_rounded(
					bounds.x,
					bounds.y,
					bounds.width,
					bounds.height,
					radius,
					config.backgroundColor,
				)
			} else {
				draw_rect(bounds.x, bounds.y, bounds.width, bounds.height, config.backgroundColor)
			}
		case .Border:
			config := render_command.renderData.border
			// Letf border
			if config.width.left > 0 {
				draw_rect(
					bounds.x,
					bounds.y + config.cornerRadius.topLeft,
					f32(config.width.left),
					bounds.height - config.cornerRadius.topLeft - config.cornerRadius.bottomLeft,
					config.color,
				)
			}
			// Right border
			if config.width.right > 0 {
				draw_rect(
					bounds.x + bounds.width - f32(config.width.right),
					bounds.y + config.cornerRadius.topRight,
					f32(config.width.right),
					bounds.height - config.cornerRadius.topRight - config.cornerRadius.bottomRight,
					config.color,
				)
			}
			// Top border
			if config.width.top > 0 {
				draw_rect(
					bounds.x + config.cornerRadius.topLeft,
					bounds.y,
					bounds.width - config.cornerRadius.topLeft - config.cornerRadius.topRight,
					f32(config.width.top),
					config.color,
				)
			}
			// Bottom border
			if config.width.bottom > 0 {
				draw_rect(
					bounds.x + config.cornerRadius.bottomLeft,
					bounds.y + bounds.height - f32(config.width.bottom),
					bounds.width -
					config.cornerRadius.bottomLeft -
					config.cornerRadius.bottomRight,
					f32(config.width.bottom),
					config.color,
				)
			}
			// Rounded Borders

			if config.cornerRadius.topLeft > 0 {
				draw_arc(
					bounds.x + config.cornerRadius.topLeft,
					bounds.y + config.cornerRadius.topLeft,
					config.cornerRadius.topLeft - f32(config.width.top),
					config.cornerRadius.topLeft,
					180, // start angle
					270, // end angle
					config.color,
				)
			}

			if config.cornerRadius.topRight > 0 {
				draw_arc(
					bounds.x + bounds.width - config.cornerRadius.topRight,
					bounds.y + config.cornerRadius.topRight,
					config.cornerRadius.topRight - f32(config.width.top),
					config.cornerRadius.topRight,
					270, // start angle
					360, // end angle
					config.color,
				)
			}

			if config.cornerRadius.bottomLeft > 0 {
				draw_arc(
					bounds.x + config.cornerRadius.bottomLeft,
					bounds.y + bounds.height - config.cornerRadius.bottomLeft,
					config.cornerRadius.bottomLeft - f32(config.width.top),
					config.cornerRadius.bottomLeft,
					90, // start angle
					180, // end angle
					config.color,
				)
			}

			if config.cornerRadius.bottomRight > 0 {
				draw_arc(
					bounds.x + bounds.width - config.cornerRadius.bottomRight,
					bounds.y + bounds.height - config.cornerRadius.bottomRight,
					config.cornerRadius.bottomRight - f32(config.width.bottom),
					config.cornerRadius.bottomRight,
					0.1, // start angle
					90, // end angle
					config.color,
				)
			}
		case .OverlayColorStart:
			config := render_command.renderData.overlayColor
			append(&overlay_colors, config.color)
		case .OverlayColorEnd:
			pop(&overlay_colors)

		case .Custom:
		// Implement custom element rendering here
		}

	}
}

draw_rect :: proc(x, y, w, h: f32, color: clay.Color) {
	rl.DrawRectangle(
		i32(math.round(x)),
		i32(math.round(y)),
		i32(math.round(w)),
		i32(math.round(h)),
		clay_color_to_rl_color(color),
	)
}

draw_rect_rounded :: proc(x, y, w, h: f32, radius: f32, color: clay.Color) {
	rl.DrawRectangleRounded({x, y, w, h}, radius, 8, clay_color_to_rl_color(color))
}

draw_arc :: proc(
	x, y: f32,
	inner_rad, outer_rad: f32,
	start_angle, end_angle: f32,
	color: clay.Color,
) {
	rl.DrawRing(
		{math.round(x), math.round(y)},
		math.round(inner_rad),
		outer_rad,
		start_angle,
		end_angle,
		10,
		clay_color_to_rl_color(color),
	)
}

debugModeEnabled: bool = false

screenWidth: i32 = 1000
screenHeight: i32 = 800

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


	min_memory_size := clay.MinMemorySize()
	memory := make([^]u8, min_memory_size)
	clay_arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
	clay.Initialize(
		clay_arena,
		{cast(f32)(rl.GetScreenWidth()), cast(f32)(rl.GetScreenHeight())},
		{handler = error_handler},
	)
	clay.SetMeasureTextFunction(measure_text, nil)
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT, .WINDOW_HIGHDPI})

	// --------------------------- Start of Program ---------------------------

	rl.InitWindow(screenWidth, screenHeight, "DirDiff")
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))

	geroImage = rl.LoadTexture("assets/images/webcam-toy-foto1.png")
	dir_one = rl.LoadTexture("assets/images/dir1.png")
	font_one_path: cstring = "assets/fonts/MPLUSCodeLatin-VariableFont_wdth,wght.ttf"
	load_font(FONT_ID_TITLE_56, 56, font_one_path)
	load_font(FONT_ID_TITLE_52, 52, font_one_path)
	load_font(FONT_ID_TITLE_48, 48, font_one_path)
	load_font(FONT_ID_TITLE_36, 36, font_one_path)
	load_font(FONT_ID_TITLE_32, 32, font_one_path)
	load_font(FONT_ID_BODY_36, 36, font_one_path)
	load_font(FONT_ID_BODY_30, 30, font_one_path)
	load_font(FONT_ID_BODY_28, 28, font_one_path)
	load_font(FONT_ID_BODY_24, 24, font_one_path)
	load_font(FONT_ID_BODY_16, 16, font_one_path)


	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		// --------------------------- UPDATE ---------------------------
		animationLerpValue += rl.GetFrameTime()
		if animationLerpValue > 1 {
			animationLerpValue = animationLerpValue - 2
		}

		screenWidth = rl.GetScreenWidth()
		screenHeight = rl.GetScreenHeight()
		if (rl.IsKeyPressed(.D)) {
			debugModeEnabled = !debugModeEnabled
			clay.SetDebugModeEnabled(debugModeEnabled)
		}
		clay.SetPointerState(
			transmute(clay.Vector2)rl.GetMousePosition(),
			rl.IsMouseButtonDown(rl.MouseButton.LEFT),
		)
		clay.UpdateScrollContainers(
			false,
			transmute(clay.Vector2)rl.GetMouseWheelMoveV(),
			rl.GetFrameTime(),
		)
		clay.SetLayoutDimensions({cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()})

		renderCommands := createLayout(
			animationLerpValue < 0 ? (animationLerpValue + 1) : (1 - animationLerpValue),
			rl.GetFrameTime(),
		)

		// --------------------------- DRAW ---------------------------
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		clay_raylib_render(&renderCommands)
		rl.EndDrawing()
	}

	// --------------------------- End of Program ---------------------------

	free_all(arena_alloc)
	free(clay_arena.memory)
	delete(raylib_fonts)

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
