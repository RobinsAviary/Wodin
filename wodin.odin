package wodin

import "core:os"
import "core:slice"
import "core:strings"
import "core:fmt"

LUMP_SIZE : u32 : 16
PALETTE_SIZE : u32 : 256



Header :: struct {
	type: WadType,
	lumps: u32,
	offset: u32,
}

PaletteColor :: distinct [3]u8

Palette :: struct {
	colors: [PALETTE_SIZE]PaletteColor,
}

Playpal :: struct {
	palettes: [14]Palette
}

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

Lump :: struct {
	offset: u32,
	size: u32,
}

File :: struct {
	label: string,
	lump: Lump,
}

/*
Lump :: []byte

File :: struct {
	label: string,
	lump: Lump
}
*/

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

	load_directory(&wad, loc)

	load_playpal(&wad)

	return
}

load_directory :: proc(wad: ^Wad, loc := #caller_location) {
	// Grab a slice of all the data we need
	data := wad.data[wad.header.offset:wad.header.offset + (wad.header.lumps * LUMP_SIZE)]

	for i in 0 ..< wad.header.lumps {
		offset := i * LUMP_SIZE

		lump: Lump

		lump.offset = slice.to_type(data[offset:][:4], u32)
		lump.size = slice.to_type(data[offset+4:][:8], u32)
		label := strings.trim_right_null(string(data[offset+8:][:8]))

		wad.directory.lumps[label] = lump
		append_elem(&wad.directory.files, File {label, lump}, loc)
	}
}

load_playpal :: proc(wad: ^Wad) {
	
}

unload_wad :: proc(wad: ^Wad, allocator := context.allocator, loc := #caller_location) {
	delete(wad.data^, allocator, loc)
	delete(wad.directory.files, loc)
	delete(wad.directory.lumps, loc)
}