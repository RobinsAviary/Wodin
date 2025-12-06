package wodin

// short for wad-odin
// written by Robin <3
// https://robinsaviary.com
// thanks for the cool game, [id]!

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
	data: []byte,
}

Lump :: []byte

File :: struct {
	label: string,
	lump: Lump,
}

Directory :: struct {
	lumps: map[string]Lump,
	files: []File,
}

@(private)
read_header :: proc(data: []byte) -> (header: Header) {
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
	ok = true
	data, file_ok := os.read_entire_file(filename, allocator, loc)
	if !file_ok do ok = false

	wad.data = data
	wad.header = read_header(wad.data)
	if wad.header.type == .Unknown do return

	wad.directory.lumps = make(map[string]Lump, allocator, loc)
	wad.directory.files = make([]File, wad.header.lumps, allocator, loc)

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
		wad.directory.files[i] = {label, lump}
	}
}

lump_exists :: proc(wad: Wad, lump: string) -> (exists: bool) {
	return lump in wad.directory.lumps
}

read_playpal :: proc(wad: ^Wad) {
	if !lump_exists(wad^, "PLAYPAL") do return

	playpal_lump := wad.directory.lumps["PLAYPAL"]

	for paletteI in 0..< DOOM_PALETTE_COUNT {
		for colorI in 0 ..< PALETTE_SIZE {
			color_data := playpal_lump[(paletteI * (PALETTE_COLOR_SIZE * PALETTE_SIZE)) + (colorI * PALETTE_COLOR_SIZE):][:PALETTE_COLOR_SIZE]
			wad.playpal[paletteI].colors[colorI].rgb = {color_data[0], color_data[1], color_data[2]}
		}
	}
}

unload_wad :: proc(wad: ^Wad, allocator := context.allocator, loc := #caller_location) {
	delete(wad.data, allocator, loc)
	delete(wad.directory.files, allocator, loc)
	delete(wad.directory.lumps, loc)
}

read_text :: proc(wad: Wad, lump: string) -> (textlump: string) {
	if !lump_exists(wad, lump) do return
	
	return string(wad.directory.lumps[lump])
}