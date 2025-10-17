package wodin

import "core:os"
import "core:slice"
import "core:strings"
import "core:fmt"

LUMP_SIZE :: 16

Header :: struct {
	type: WadType,
	lumps: u32,
	offset: u32,
}

PaletteColor :: distinct [3]u8

Palette :: struct {
	[256]PaletteColor,
}

Playpal_Doom :: struct {
	[14]Palette
}

WadType :: enum {
	IWAD,
	PWAD,
	Unknown,
}

Wad :: struct {
	header: Header,
	directory: Directory,
	data: ^[]byte,
}

Lump :: struct {

}

File_Info :: struct {
	offset: u32,
	size: u32,
}

Directory :: struct {
	files: [dynamic]File,
}

File :: struct {
	info: File_Info,
	label: string,
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

		header.lumps, ok = slice.to_type(data[4:9], u32)
		header.offset, ok = slice.to_type(data[8:13], u32)
	}

	return
}

load_wad :: proc(filename: string, allocator := context.allocator, loc := #caller_location) -> (wad: Wad, ok: bool) {
	wad.directory.files = make([dynamic]File, allocator, loc)

	data, file_ok := os.read_entire_file(filename, allocator, loc)

	wad.data = &data
	wad.header = read_header(wad.data)
	if wad.header.type == .Unknown do return

	load_directory(&wad, loc)

	return
}

load_directory :: proc(wad: ^Wad, loc := #caller_location) {
	// Grab a slice of all the data we need
	data := wad.data[wad.header.offset:wad.header.offset + (wad.header.lumps * LUMP_SIZE)]

	file: File

	for i: u32; i < wad.header.lumps; i += 1 {
		offset := i * LUMP_SIZE

		file.info.offset = slice.to_type(data[offset:offset+4], u32)
		file.info.size = slice.to_type(data[offset+4:offset+8], u32)
		file.label = strings.trim_right_null(string(data[offset+8:offset+16]))

		append_elem(&wad.directory.files, file, loc)
	}
}

unload_wad :: proc(wad: ^Wad, allocator := context.allocator, loc := #caller_location) {
	delete(wad.data^, allocator, loc)
	delete(wad.directory.files, loc)
}