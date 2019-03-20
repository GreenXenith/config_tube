local fs_helpers = pipeworks.fs_helpers

function pipeworks.directions.dir_to_side(dir)
	local c = pipeworks.vector_dot(dir, vector.new(1, 2, 3)) + 4
	return ({1, 3, 5, 7, 6, 4, 2})[c]
end

local function update_formspec(pos)
	local meta = minetest.get_meta(pos)
	local buttons_formspec = ""
	for i = 0, 5 do
		buttons_formspec = buttons_formspec .. fs_helpers.cycling_button(meta,
			"image_button[2,"..(i+1.2)..";1,0.6", "in"..(i+1),
			{
				pipeworks.button_off,
				pipeworks.button_on
			}
		)
		buttons_formspec = buttons_formspec .. fs_helpers.cycling_button(meta,
			"image_button[3,"..(i+1.2)..";1,0.6", "out"..(i+1),
			{
				pipeworks.button_off,
				pipeworks.button_on
			}
		)
	end
	meta:set_string("formspec",
		"size[4,7]"..
		"label[2,0;In]"..
		"label[3,0;Out]"..
		"image[0,1;1,1;pipeworks_white.png]"..
		"image[0,2;1,1;pipeworks_black.png]"..
		"image[0,3;1,1;pipeworks_green.png]"..
		"image[0,4;1,1;pipeworks_yellow.png]"..
		"image[0,5;1,1;pipeworks_blue.png]"..
		"image[0,6;1,1;pipeworks_red.png]"..
		buttons_formspec
		)
end

pipeworks.register_tube("config_tube:config_tube", {
		description = "Configurable Pneumatic Tube Segment",
		inventory_image = "pipeworks_config_tube_inv.png",
		noctr = {"pipeworks_config_tube_noctr_1.png", "pipeworks_config_tube_noctr_2.png", "pipeworks_config_tube_noctr_3.png",
			"pipeworks_config_tube_noctr_4.png", "pipeworks_config_tube_noctr_5.png", "pipeworks_config_tube_noctr_6.png"},
		plain = {"pipeworks_config_tube_plain_1.png", "pipeworks_config_tube_plain_2.png", "pipeworks_config_tube_plain_3.png",
			"pipeworks_config_tube_plain_4.png", "pipeworks_config_tube_plain_5.png", "pipeworks_config_tube_plain_6.png"},
		ends = { "pipeworks_config_tube_end.png" },
		short = "pipeworks_config_tube_short.png",
		no_facedir = true,  -- Must use old tubes, since the textures are rotated with 6d ones
		node_def = {
			tube = {
				can_go = function(pos, node, velocity, stack)
						local tbl, tbln = {}, 0
						local meta = minetest.get_meta(pos)
						local name = stack:get_name()
						for i, vect in ipairs(pipeworks.meseadjlist) do
							local npos = vector.add(pos, vect)
							local node = minetest.get_node(npos)
							local reg_node = minetest.registered_nodes[node.name]
							if meta:get_int("out"..i) == 1 and reg_node then
								local tube_def = reg_node.tube
								if not tube_def or not tube_def.can_insert or
								tube_def.can_insert(npos, node, stack, vect) then
									tbln = tbln + 1
									tbl[tbln] = vect
								end
							end
						end
						return tbl
				end,
				can_insert = function(pos, node, stack, direction)
					local meta = minetest.get_meta(pos)
					return meta:get_int("in"..pipeworks.directions.dir_to_side(direction)) == 1
				end,
			},
			on_construct = function(pos)
				local meta = minetest.get_meta(pos)
				for i = 1, 6 do
					meta:set_int("in"..tostring(i), 1)
					meta:set_int("out"..tostring(i), 1)
				end
				update_formspec(pos)
				meta:set_string("infotext", "Configurable pneumatic tube")
			end,
			on_punch = update_formspec,
			on_receive_fields = function(pos, formname, fields, sender)
				if not pipeworks.may_configure(pos, sender) then return end
				fs_helpers.on_receive_fields(pos, fields)
				update_formspec(pos)
			end,
			can_dig = function(pos, player)
				update_formspec(pos) -- so non-virtual items would be dropped for old tubes
				return true
			end,
		},
})

minetest.register_craft( {
	output = "config_tube:config_tube_000000 2",
	recipe = {
		{"basic_materials:plastic_sheet", "basic_materials:plastic_sheet", "basic_materials:plastic_sheet"},
		{"", "basic_materials:ic", ""},
		{"basic_materials:plastic_sheet", "basic_materials:plastic_sheet", "basic_materials:plastic_sheet"}
	},
})

minetest.register_craft( {
	output = "config_tube:config_tube_000000",
	type = "shapeless",
	recipe = {"basic_materials:ic", "pipeworks:tube_1"},
})

minetest.register_tool("config_tube:controller", {
	description = "Config Tube Controller (Click to copy, shift+rightclick to paste)",
	inventory_image = "pipeworks_config_tube_controller.png",
	on_use = function(itemstack, user, pointed_thing)
		local pos = minetest.get_pointed_thing_position(pointed_thing)
		local node = minetest.get_node(pos)
		if node.name:match("^config_tube:config_tube") then
			local meta = minetest.get_meta(pos)
			local imeta = itemstack:get_meta()
			for i = 1, 6 do
				imeta:set_int("in"..tostring(i), meta:get_int("in"..i))
				imeta:set_int("out"..tostring(i), meta:get_int("out"..i))
			end
			minetest.chat_send_player(user:get_player_name(), "Tube config copied.")
			return itemstack
		end
	end,
	on_place = function(itemstack, placer, pointed_thing)
		local pos = minetest.get_pointed_thing_position(pointed_thing)
		if not pipeworks.may_configure(pos, placer) then return	end
		local node = minetest.get_node(pos)
		if node.name:match("^config_tube:config_tube") then
			local meta = minetest.get_meta(pos)
			local imeta = itemstack:get_meta()
			for i = 1, 6 do
				meta:set_int("in"..tostring(i), imeta:get_int("in"..i))
				meta:set_int("out"..tostring(i), imeta:get_int("out"..i))
			end
			update_formspec(pos)
			minetest.chat_send_player(placer:get_player_name(), "Tube config set.")
		end
	end
})

minetest.register_craft( {
	output = "config_tube:controller",
	type = "shapeless",
	recipe = {"basic_materials:plastic_sheet", "basic_materials:ic", "config_tube:config_tube_000000"},
})
