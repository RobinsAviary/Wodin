package wodin

import "core:os"
import "core:slice"
import "core:strings"

LUMPDEF_SIZE : u32 : 16
PALETTE_SIZE : u32 : 256
DOOM_PALETTE_COUNT : u32 : 14
PALETTE_COLOR_SIZE : u32 : 3

// Read means statically allocated
// Load means dynamically allocated - has matching unload function

Header :: struct {
	type: WadType,
	lumps: u32,
	offset: u32,
}

PaletteColor :: distinct [3]u8

Palette :: struct {
	colors: [PALETTE_SIZE]PaletteColor,
}

Playpal :: [DOOM_PALETTE_COUNT]Palette

WadType :: enum {
	IWAD,
	PWAD,
	Unknown,
}

Wad :: struct {
	header: Header,
	directory: Directory,
	playpal: Playpal,
	data: ^[]byte,
}

Lump :: []byte

File :: struct {
	label: string,
	lump: Lump,
}

Directory :: struct {
	lumps: map[string]Lump,
	files: [dynamic]File,
}

@(private)
read_header :: proc(data: ^[]byte) -> (header: Header) {
	ascii := string(data[0:4])

	if ascii == "IWAD" {
		header.type = .IWAD
	} else if ascii == "PWAD" {
		header.type = .PWAD
	} else {
		header.type = .Unknown
	}

	if header.type != .Unknown {
		ok: bool

		header.lumps, ok = slice.to_type(data[4:][:4], u32)
		header.offset, ok = slice.to_type(data[8:][:4], u32)
	}

	return
}

load_wad :: proc(filename: string, allocator := context.allocator, loc := #caller_location) -> (wad: Wad, ok: bool) {
	wad.directory.lumps = make(map[string]Lump, allocator, loc)
	wad.directory.files = make([dynamic]File, allocator, loc)

	data, file_ok := os.read_entire_file(filename, allocator, loc)

	wad.data = &data
	wad.header = read_header(wad.data)
	if wad.header.type == .Unknown do return

	read_directory(&wad, loc)

	read_playpal(&wad)

	return
}

read_directory :: proc(wad: ^Wad, loc := #caller_location) {
	// Grab a slice of all the data we need
	data := wad.data[wad.header.offset:][:wad.header.lumps * LUMPDEF_SIZE]

	for i in 0 ..< wad.header.lumps {
		offset := i * LUMPDEF_SIZE

		lump: Lump

		lump_offset := slice.to_type(data[offset:][:4], u32)
		lump_size := slice.to_type(data[offset+4:][:8], u32)

		lump = wad.data[lump_offset:][:lump_size]

		label := strings.trim_right_null(string(data[offset+8:][:8]))

		wad.directory.lumps[label] = lump
		append_elem(&wad.directory.files, File {label, lump}, loc)
	}
}

read_playpal :: proc(wad: ^Wad) {
	playpal_lump := wad.directory.lumps["PLAYPAL"]

	for paletteI in 0..< DOOM_PALETTE_COUNT {
		for colorI in 0 ..< PALETTE_SIZE {
			color_data := playpal_lump[(paletteI * (PALETTE_COLOR_SIZE * PALETTE_SIZE)) + (colorI * PALETTE_COLOR_SIZE):][:PALETTE_COLOR_SIZE]
			wad.playpal[paletteI].colors[colorI].rgb = {color_data[0], color_data[1], color_data[2]}
		}
	}
}

unload_wad :: proc(wad: ^Wad, allocator := context.allocator, loc := #caller_location) {
	delete(wad.data^, allocator, loc)
	delete(wad.directory.files, loc)
	delete(wad.directory.lumps, loc)
}

Picture :: struct {
	width: u16,
	height: u16,
	left_offset: i16,
	top_offset: i16,
	columnofs: []u32,
	columns: []Column,
}

Column :: struct {
	posts: [dynamic]Post,
}

Post :: struct {
	top_delta: u8,
	length: u8,
	unused: u8,
	data: []byte,
	unused2: u8,
}

load_picture :: proc(data: []byte, allocator := context.allocator, loc := #caller_location) -> (picture: Picture) {
	picture.width = slice.to_type(data[:2], u16)
	picture.height = slice.to_type(data[2:][:2], u16)
	picture.left_offset = slice.to_type(data[4:][:2], i16)
	picture.top_offset = slice.to_type(data[6:][:2], i16)
	picture.columnofs = make([]u32, picture.width)
	picture.columns = make([]Column, picture.width)

	for &columnof, x in picture.columnofs {
		columnof = slice.to_type(data[8 + (x * 4):][:4], u32)
	}

	for &column, x in picture.columns {
		offset := 0

		for true {
			posts_data := data[int(picture.columnofs[x]) + offset:][:len(data) - (int(picture.columnofs[x])) - offset]

			first_byte := slice.to_type(posts_data[0:][:1], u8)
			if first_byte == 255 {
				break
			}
			new_post: Post

			new_post.top_delta = first_byte
			new_post.length = slice.to_type(posts_data[1:][:1], u8)
			new_post.unused = slice.to_type(posts_data[2:][:2], u8)
			new_post.data = posts_data[3:][:new_post.length]
			new_post.unused2 = slice.to_type(posts_data[3 + new_post.length:][:1], u8)
			append(&column.posts, new_post)

			offset_amount := 3 + int(new_post.length) + 1

			next_byte := slice.to_type(posts_data[offset_amount:][:1], u8)

			if next_byte != 255 {
				offset += offset_amount

				continue
			} else {
				break
			}
		}
	}

	return
}

unload_picture :: proc(picture: ^Picture, allocator := context.allocator, loc := #caller_location) {
	for column in picture.columns {
		delete(column.posts, loc)
	}
	
	delete(picture^.columns, allocator, loc)
	delete(picture^.columnofs, allocator, loc)
}