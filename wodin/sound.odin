package wodin

import "core:slice"

Sound :: struct {
	format: u16le,
	sample_rate: u16le,
	sample_count: u32le,
	padding: []u8,
	samples: []byte,
	padding2: []u8,
}

load_sound :: proc(data: []byte) -> (sound: Sound) {
	sound.format = slice.to_type(data[0:][:2], u16le)
	sound.sample_rate = slice.to_type(data[2:][:2], u16le)
	sound.sample_count = slice.to_type(data[4:][:4], u32le)
	sound.padding = data[8:][:16]
	sound.samples = data[18:][:sound.sample_count - 32]
	sound.padding2 = data[18 + sound.sample_count - 32:][:16]

	return
}