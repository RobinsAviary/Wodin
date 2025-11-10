package wodin

import "core:slice"

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