package wodin

import "core:os"
import "core:fmt"
import "core:slice"

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
	data: ^[]byte,
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

unload_wad :: proc(wad: ^Wad) {
	delete(wad.data^)
}