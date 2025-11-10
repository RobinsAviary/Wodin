package wodin

import "core:slice"

Flat :: struct {
	data: []byte,
}

load_flat :: proc(data: []byte) -> (flat: Flat) {
	flat.data = data

	return
}

unload_flat :: proc(flat: Flat) {
	// nothing required
}