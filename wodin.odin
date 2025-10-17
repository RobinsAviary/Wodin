package wodin

import "core:os"
import "core:slice"

WAD :: ^[]byte

Header :: struct {
	type: WadType,
	lumps: u32,
	offset: u32,
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
read_header :: proc(data: WAD) -> (header: Header) {
	ascii := string(data[0:4])

	if ascii == "IWAD" {
		header.type = .IWAD
	} else if ascii == "PWAD" {
		header.type = .PWAD
	} else {
		header.type = .Unknown
	}

	ok: bool

	header.lumps, ok = slice.to_type(data[4:9], u32)
	header.offset, ok = slice.to_type(data[8:13], u32)

	return
}

load_wad :: proc(filename: string) -> (wad: Wad, ok: bool) {
	data, file_ok := os.read_entire_file(filename)

	wad.data = &data
	wad.header = read_header(wad.data)

	return
}

load_directory :: proc(data: WAD) {
	
}

unload_wad :: proc(wad: ^Wad) {
	delete(wad.data^)
	delete(wad.directory.files)
}