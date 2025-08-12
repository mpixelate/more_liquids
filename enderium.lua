local cooldowns = {}

local MAX_RANDOM_ATTEMPTS = 16
local SEARCH_RADIUS = 8
local TELEPORT_COOLDOWN = 2
local TELEPORT_INTERVAL = 0.2

local play_sound = false
if minetest.get_modpath("default") then
    play_sound = true
end


local function set_cd(pname)
    cooldowns[pname] = minetest.get_gametime() + TELEPORT_COOLDOWN
end

local function get_cd(pname)
    return cooldowns[pname] or 0
end

local function is_on_cd(pname)
    return minetest.get_gametime() < get_cd(pname)
end

local function is_node_safe_for_player(node_name)
    local node_def = minetest.registered_nodes[node_name]
    if not node_def then
        return false
    end

    if node_def.walkable or (node_def.damage_per_second and node_def.damage_per_second > 0) then
        return false
    end
    return true
end

local function find_ground_in_column(column_pos, search_up, search_down)
    local consecutive_safe_blocks = 0
    local start_y = column_pos.y + search_up
    local end_y = column_pos.y + search_down
    for y = start_y, end_y, -1 do
        local test_pos = {x = column_pos.x, y = y, z = column_pos.z}
        local node = minetest.get_node(test_pos)
        local node_def = minetest.registered_nodes[node.name]
        if is_node_safe_for_player(node.name) then
            consecutive_safe_blocks = consecutive_safe_blocks + 1
        elseif node_def and node_def.walkable and consecutive_safe_blocks > 1 then
            return {x = test_pos.x, y = test_pos.y + 1, z = test_pos.z}
        else
            consecutive_safe_blocks = 0
        end
    end

    return nil
end

local function find_teleport_position(pos)
    -- random search
    for attempt = 1, MAX_RANDOM_ATTEMPTS do
        local random_pos = {
            x = pos.x + math.random(-SEARCH_RADIUS, SEARCH_RADIUS),
            y = pos.y + math.random(-SEARCH_RADIUS, SEARCH_RADIUS),
            z = pos.z + math.random(-SEARCH_RADIUS, SEARCH_RADIUS)
        }

        local teleport_spot = find_ground_in_column(random_pos, 1, -8)
        if teleport_spot then
            return teleport_spot
        end
    end

    -- bruteforce

    local valid_teleport_spots = {}

    for offset = -SEARCH_RADIUS, SEARCH_RADIUS do
        for perp_offset = -1, 1 do
            if not (offset == 0 and perp_offset == 0) then
                -- varying x, fixed z
                local new_pos = {x = pos.x + offset, y = pos.y, z = pos.z + perp_offset}
                local spot = find_ground_in_column(new_pos, 2, -2)
                if spot then
                    table.insert(valid_teleport_spots, spot)
                end
                -- varying z, fixed x
                new_pos = {x = pos.x + perp_offset, y = pos.y, z = pos.z + offset}
                spot = find_ground_in_column(new_pos, 2, -2)
                if spot then
                    table.insert(valid_teleport_spots, spot)
                end
            end
        end
    end
    if #valid_teleport_spots > 0 then
        return valid_teleport_spots[math.random(#valid_teleport_spots)]
    end

    return nil
end



local function teleport_player(player)
    local pname = player:get_player_name()
    local new_pos = find_teleport_position(player:get_pos())
    if new_pos then
        if play_sound then
            minetest.sound_play("fire_extinguish_flame", {
                pos = player:get_pos(),
                gain = 0.4,
                pitch = 0.8
            })
        end

        player:set_pos(new_pos)

        if play_sound then
            minetest.after(0.1, function()
                minetest.sound_play("fire_extinguish_flame", {
                    pos = new_pos,
                    gain = 0.6,
                    pitch = 1.4
                })
            end)
        end

        minetest.add_particlespawner({
            amount = 100,
            time = 1,
            minpos = vector.subtract(new_pos, 1),
            maxpos = vector.add(new_pos, 2),
            texture = "enderium.png"
        })
    end
    set_cd(pname)
end


minetest.register_node("more_liquids:enderium_source", {
    description = "Enderium source",
    drawtype = "liquid",
    waving = 3,
    tiles = {
        {
            name = "enderium_source_animated.png",
            backface_culling = false,
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 4.0,
            },
        },
        {
            name = "enderium_source_animated.png",
            backface_culling = true,
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 4.0,
            },
        }
    },
    use_texture_alpha = "blend",
    paramtype = "light",
    light_source = 8,
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    is_ground_content = false,
    drop = "",
    damage_per_second = 1,
	drowning = 1,
	liquidtype = "source",
    liquid_alternative_flowing = "more_liquids:enderium_flowing",
	liquid_alternative_source = "more_liquids:enderium_source",
	liquid_viscosity = 1,
    liquid_range = 4,
    liquid_renewable = false,
    groups = {liquid = 2},
    post_effect_color = {a = 180, r = 11, g = 77, b = 66},
})

minetest.register_node("more_liquids:enderium_flowing", {
    description = "Flowig enderium",
    drawtype = "flowingliquid",
    waving = 3,
    tiles = {"enderium.png"},
    special_tiles = {
        {
            name = "enderium_flowing_animated.png",
            backface_culling = false,
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 4.0,
            },
        },
        {
            name = "enderium_flowing_animated.png",
            backface_culling = true,
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 4.0,
            },
        }
    },
    use_texture_alpha = "blend",
    paramtype = "light",
    paramtype2 = "flowingliquid",
    light_source = 8,
    walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	is_ground_content = false,
	drop = "",
    damage_per_second = 1,
	drowning = 1,
	liquidtype = "flowing",
    liquid_alternative_flowing = "more_liquids:enderium_flowing",
	liquid_alternative_source = "more_liquids:enderium_source",
	liquid_viscosity = 1,
    liquid_range = 4,
    liquid_renewable = false,

    groups = {liquid = 2},
    post_effect_color = {a = 180, r = 11, g = 77, b = 66},
})

minetest.register_abm({
    label = "Enderium teleportation",
    nodenames = {"more_liquids:enderium_source", "more_liquids:enderium_flowing"},
    interval = TELEPORT_INTERVAL,
    chance = 1,
    action = function(pos, node, active_object_count, active_object_count_wider)
        local objects = minetest.get_objects_inside_radius(pos, 0.7)
        for _, obj in ipairs(objects) do
            if obj:is_player() then
                local player = obj
                if not is_on_cd(player:get_player_name()) then
                    teleport_player(player)
                end
            end
        end
    end
})


minetest.register_chatcommand("enderium_rtp", {
    description = "Tests enderium teleportation",
    privs = {server = true},
    func = function (name, param)
        local player = minetest.get_player_by_name(name)

        if not player then
            return false, "Player not found"
        end

        local new_pos = find_teleport_position(player:get_pos())
        if new_pos then
            player:set_pos(new_pos)
            return true, "Teleported to " .. minetest.pos_to_string(new_pos)
        else
            return false, "No safe teleport location found"
        end
    end
})