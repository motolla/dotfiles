--[[
	This file is part of mdmenu.
	
	mdmenu is free software: you can redistribute it and/or modify it
	under the terms of the GNU Affero General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.
	
	mdmenu is distributed in the hope that it will be useful, but WITHOUT
	ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
	FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License
	for more details.
	
	You should have received a copy of the GNU Affero General Public License
	along with mdmenu. If not, see <https://www.gnu.org/licenses/>.
]]

local msg = require('mp.msg')
local mpopt = require('mp.options')
local utils = require('mp.utils')

local state = {
	playlist = nil,
	playlist_current = nil,
	tracklist = nil,
	chapters = nil,
	chapters_raw = nil,
}

local opt = {
	embed = true,
	preselect = false,
	cmd = { "dmenu", "-i", "-l", "16" },
}

local ob = { [false] = ' ', [true] = '[' }
local cb = { [false] = ' ', [true] = ']' }

function format_time(t)
	local h = math.floor(t / (60 * 60))
	t = t - (h * 60 * 60)
	local m = math.floor(t / 60)
	local s = t - (m * 60)
	return string.format("%.2d:%.2d:%.2d", h, m, s)
end

function humantime_to_sec(str)
	assert(string.len(str) >= 8)
	local h = tonumber(string.sub(str, 1, 2))
	local m = tonumber(string.sub(str, 4, 5))
	local s = tonumber(string.sub(str, 7, 8))
	if h and m and s and
	   string.sub(str, 3, 3) == ':' and
	   string.sub(str, 6, 6) == ':'
	then
		return (h * 60 * 60) + (m * 60) + s
	end
	return nil
end

function grab_xid(kind, ws)
	assert(kind == "current-window-scale")
	if (ws) then
		local wid = mp.get_property('window-id')
		if (wid == nil) then
			local pid = mp.get_property('pid')
			local r = mp.command_native({
				name = "subprocess",
				playback_only = false,
				capture_stdout = true,
				args = {"xdo", "id", "-p", pid},
			})
			if (r.status == 0 and string.len(r.stdout) > 0) then
				wid = string.match(r.stdout, "0x%x+")
			end
		end
		if (wid) then
			table.insert(opt.cmd, "-w")
			table.insert(opt.cmd, wid)
		else
			msg.warn("couldn't get mpv's xwindow id. make sure `xdo` is installed.")
		end
		mp.unobserve_property(grab_xid)
	end
end

function set_playlist(kind, plist)
	assert(kind == "playlist")
	local s = ''
	local f = "%"..(string.len(#plist) + string.len(ob[true]) + string.len(cb[true])).."s"
	state.playlist_current = nil
	for k,pl in ipairs(plist) do
		state.playlist_current = pl.current and k or state.playlist_current
		s = s .. string.format(f, ob[pl.current or false] .. k .. cb[pl.current or false]) .. ' '
		s = s .. (pl.title or select(2, utils.split_path(pl.filename))) .. '\n'
	end
	state.playlist = s
end

function set_tracklist(kind, tlist)
	assert(kind == "track-list")
	local s = ''
	for _,t in ipairs(tlist) do
		s = s .. ob[t.selected] .. string.sub(t.type, 1, 1)
		s = s .. t.id .. cb[t.selected] .. ' '

		if (t.title) then
			s = s .. t.title .. ' '
		end
		if (t.lang) then
			s = s .. t.lang .. ' '
		end
		s = s .. '\n'
	end
	state.tracklist = s
end

function set_chapter_list(kind, c)
	assert(kind == "chapter-list")
	if (c and #c > 0) then
		local s = ''
		for _,ch in ipairs(c) do
			s = s .. format_time(ch.time) .. ' '
			s = s .. ch.title .. '\n'
		end
		state.chapters = s
		state.chapters_raw = c
	else
		state.chapters = nil
		state.chapters_raw = nil
	end
end

function call_dmenu(stdin, extra_arg)
	local cmd = opt.cmd
	if (extra_arg) then
		for _,v in ipairs(extra_arg) do
			table.insert(cmd, v)
		end
	end
	return mp.command_native({
		name = "subprocess",
		playback_only = false,
		stdin_data = stdin,
		capture_stdout = true,
		args = cmd
	})
end

function menu_playlist()
	if (state.playlist == nil) then
		return
	end
	local narg = nil
	if (opt.preselect and state.playlist_current ~= nil) then
		narg =  { "-n", tostring(state.playlist_current - 1) }
	end
	local r = call_dmenu(state.playlist, narg)
	if (r.status == 0 and string.len(r.stdout) > 2) then
		s = string.match(r.stdout, "[%s%[]*(%d+)")
		if (tonumber(s)) then
			mp.set_property("playlist-pos-1", s)
		else
			msg.warn("bad playlist position: " .. r.stdout)
		end
	end
end

function menu_tracklist()
	if (state.tracklist == nil) then
		return
	end

	local r = call_dmenu(state.tracklist)
	if (r.status == 0 and string.len(r.stdout) > 4) then
		local active = string.sub(r.stdout, 1, 1) == '['
		local type = string.sub(r.stdout, 2, 2)
		local cmd = { ['v'] = 'vid', ['a'] = 'audio', ['s'] = 'sub' }
		local arg = { [false] = string.sub(r.stdout, 3, 3), [true] = 'no' }

		if (cmd[type]) then
			mp.commandv('set', cmd[type], arg[active])
		else
			msg.warn("messed up input: " .. r.stdout)
		end
	end
end

function menu_chapters()
	if (state.chapters == nil) then
		return
	end
	local narg = nil
	if (opt.preselect) then
		local t = mp.get_property_native('time-pos') or 0
		local n = 0
		for i,c in ipairs(state.chapters_raw) do
			if (t > c.time) then
				n = i - 1
			end
		end
		narg = { "-n", tostring(n) }
	end

	local r = call_dmenu(state.chapters, narg)
	if (r.status == 0 and string.len(r.stdout) > 8) then
		local t = humantime_to_sec(r.stdout)
		if (t) then
			mp.set_property("time-pos", t)
		else
			msg.warn("bad chapter position: " .. r.stdout)
		end
	end
end

function init()
	mpopt.read_options(opt, "mdmenu")
	if (type(opt.cmd) == "string") then -- what a pain
		local s = opt.cmd
		opt.cmd = {}
		for arg in string.gmatch(s, '[^,]+') do
			table.insert(opt.cmd, arg)
		end
	end

	-- grab mpv's xwindow id
	if (opt.embed) then
		-- HACK: mpv doesn't open the window instantly by default.
		-- so wait for 'current-window-scale' to be available before
		-- trying to grab the xid.
		mp.observe_property('current-window-scale', 'native', grab_xid)
	end

	mp.observe_property('playlist', 'native', set_playlist)
	mp.add_key_binding(nil, 'playlist', menu_playlist)

	mp.observe_property('track-list', 'native', set_tracklist)
	mp.add_key_binding(nil, 'tracklist', menu_tracklist)

	mp.observe_property('chapter-list', 'native', set_chapter_list)
	mp.add_forced_key_binding(nil, 'chapters', menu_chapters)
end

init()
