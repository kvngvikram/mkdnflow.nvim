-- mkdnflow.nvim (Tools for fluent markdown notebook navigation and management)
-- Copyright (C) 2022 Jake W. Vincent <https://github.com/jakewvincent>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

-- File and link navigation functions
local M = {}

-- Get OS for use in a couple of functions
local this_os = vim.loop.os_uname().sysname
-- Generic OS message
local this_os_err = 'Function unavailable for '..this_os..'. Please file an issue.'
-- Get config setting for whether to make missing directories or not
local create_dirs = require('mkdnflow').config.create_dirs
-- Get config setting for where links should be relative to
local links_relative_to = require('mkdnflow').config.links_relative_to
-- Get directory of first-opened file
local initial_dir = require('mkdnflow').initial_dir
-- Get the user's prefix string
local new_file_prefix = require('mkdnflow').config.new_file_prefix
-- Get the user's prefix evaluation preference
local evaluate_prefix = require('mkdnflow').config.evaluate_prefix

--[[

get_path() extracts the path part of a markdown link, i.e. the part in → []
Returns a string--the string in the square brackets
Private function

--]]
local get_path = function()
    -- Get current cursor position
    local position = vim.api.nvim_win_get_cursor(0)
    local row = position[1]
    local col = position[2]

    -- Get the indices of the links in the line
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false) -- Get the line text
    local link_pattern = '%b[](%b())' -- What links look like
    local bib_pattern = '[^%a%d]-(@[%a%d_%.%-\']+)[%s%p%c]?' -- Bib. citation pattern
    local indices = {} -- Table for match indices
    local last_fin = 1 -- Last end index
    local link_type = nil
    local unfound = true
    -- TODO: Move the check overlap bit, which is repeated twice, to a function
    -- definition here, then call the function twice
    while unfound do
        -- Get the indices of any match on the current line
        local com, fin = string.find(line[1], link_pattern, last_fin)
        -- Check if there's a match that begins after the fin from the previous
        -- iteration of the loop
        if com and fin then
            -- If there is, check if the match overlaps with the cursor position
            if com - 1 <= col and fin - 1 >= col then
                -- If it does overlap, save the indices of the match
                indices = {com = com, fin = fin}
                -- End the loop
                unfound = false
                -- Note link type
                link_type = 'address'
            else
                -- If it doesn't overlap, save the end index of the match so
                -- we can look for a match following it on the next loop.
                last_fin = fin
            end
        else
            unfound = nil
        end
    end

    -- Check if a link was found under the cursor
    if unfound == false then
        -- If one was found and it's an address, get the path part of the match
        -- and return it
        if link_type == 'address' then
            local path_pattern = '%b[](%b())'
            local path = string.sub(
                string.match(
                    string.sub(line[1], indices['com'], indices['fin']),
                    path_pattern
                ), 2, -2
            )
            return(path)
        end
    else -- If one wasn't found, perform another search, this time for citations
        unfound = true
        while unfound do
            local com, fin = string.find(line[1], bib_pattern, last_fin)
            -- If there was a match, see if the cursor is inside it
            if com and fin then
                -- If there is, check if the match overlaps with the cursor
                -- position
                if com - 1 <= col and fin - 1 >= col then
                    -- If it does overlap, save the indices of the match
                    indices = {com = com, fin = fin}
                    -- End the loop
                    unfound = false
                    -- Note link type
                    link_type = 'citation'
                else
                    -- If it doesn't overlap, save the end index of the match so
                    -- we can look for a match following it on the next loop.
                    last_fin = fin
                end
            else
                unfound = nil
            end
        end
        if unfound == false then
            if link_type == 'citation' then
                local citation = string.match(
                    string.sub(
                        line[1], indices['com'], indices['fin']
                    ), bib_pattern
                )
                return(citation)
            end
        else
            -- Below will need to be the else condition
            return(nil)
        end
    end
end

--[[

is_url() determines whether a string is a URL
Returns a boolean or nil
Private function

--]]
local is_url = function(string)
    -- This function based largely on the solution in https://stackoverflow.com/
    -- questions/23590304/finding-a-url-in-a-string-lua-pattern
    -- Table of top-level domains
    local tlds = {ac = true, ad = true, ae = true, aero = true, af = true,
        ag = true, ai = true, al = true, am = true, an = true, ao = true,
        aq = true, ar = true, arpa = true, as = true, asia = true, at = true,
        au = true, aw = true, ax = true, az = true, ba = true, bb = true,
        bd = true, be = true, bf = true, bg = true, bh = true, bi = true,
        biz = true, bj = true, bm = true, bn = true, bo = true, br = true,
        bs = true, bt = true, bv = true, bw = true, by = true, bz = true,
        ca = true, cat = true, cc = true, cd = true, cf = true, cg = true,
        ch = true, ci = true, ck = true, cl = true, cm = true, cn = true,
        co = true, com = true, coop = true, cr = true, cs = true, cu = true,
        cv = true, cx = true, cy = true, cz = true, dd = true, de = true,
        dj = true, dk = true, dm = true, ['do'] = true, dz = true, ec = true,
        edu = true, ee = true, eg = true, eh = true, er = true, es = true,
        et = true, eu = true, fi = true, firm = true, fj = true, fk = true,
        fm = true, fo = true, fr = true, fx = true, ga = true, gb = true,
        gd = true, ge = true, gf = true, gh = true, gi = true, gl = true,
        gm = true, gn = true, gov = true, gp = true, gq = true, gr = true,
        gs = true, gt = true, gu = true, gw = true, gy = true, hk = true,
        hm = true, hn = true, hr = true, ht = true, hu = true, id = true,
        ie = true, il = true, im = true, ['in'] = true, info = true, int = true,
        io = true, iq = true, ir = true, is = true, it = true, je = true,
        jm = true, jo = true, jobs = true, jp = true, ke = true, kg = true,
        kh = true, ki = true, km = true, kn = true, kp = true, kr = true,
        kw = true, ky = true, kz = true, la = true, lb = true, lc = true,
        li = true, lk = true, lr = true, ls = true, lt = true, lu = true,
        lv = true, ly = true, ma = true, mc = true, md = false, me = true,
        mg = true, mh = true, mil = true, mk = true, ml = true, mm = true,
        mn = true, mo = true, mobi = true, mp = true, mq = true, mr = true,
        ms = true, mt = true, mu = true, museum = true, mv = true, mw = true,
        mx = true, my = true, mz = true, na = true, name = true, nato = true,
        nc = true, ne = true, net = true, nf = true, ng = true, ni = true,
        nl = true, no = true, nom = true, np = true, nr = true, nt = true,
        nu = true, nz = true, om = true, org = true, pa = true, pe = true,
        pf = true, pg = true, ph = true, pk = true, pl = true, pm = true,
        pn = true, post = true, pr = true, pro = true, ps = true, pt = true,
        pw = true, py = true, qa = true, re = true, ro = true, ru = true,
        rw = true, sa = true, sb = true, sc = true, sd = true, se = true,
        sg = true, sh = true, si = true, sj = true, sk = true, sl = true,
        sm = true, sn = true, so = true, sr = true, ss = true, st = true,
        store = true, su = true, sv = true, sy = true, sz = true, tc = true,
        td = true, tel = true, tf = true, tg = true, th = true, tj = true,
        tk = true, tl = true, tm = true, tn = true, to = true, tp = true,
        tr = true, travel = true, tt = true, tv = true, tw = true, tz = true,
        ua = true, ug = true, uk = true, um = true, us = true, uy = true,
        va = true, vc = true, ve = true, vg = true, vi = true, vn = true,
        vu = true, web = true, wf = true, ws = true, xxx = true, ye = true,
        yt = true, yu = true, za = true, zm = true, zr = true, zw = true}

    -- Table of protocols
    local protocols = {
        [''] = 0,
        ['http://'] = 0,
        ['https://'] = 0,
        ['ftp://'] = 0
    }

    -- Table for status of url search
    local finished = {}

    -- URL identified
    local found_url = nil

    -- Function to return the max value of the four inputs
    local max_of_four = function(a, b, c, d)
        return math.max(a + 0, b + 0, c + 0, d + 0)
    end

    -- For each group in the match, do some stuff
    for pos_start, url, prot, subd, tld, colon, port, slash, path in
        string:gmatch('()(([%w_.~!*:@&+$/?%%#-]-)(%w[-.%w]*%.)(%w+)(:?)(%d*)(/?)([%w_.~!*:@&+$/?%%#=-]*))')
    do
        if protocols[prot:lower()] == (1 - #slash) * #path and not subd:find'%W%W'
            and (colon == '' or port ~= '' and port + 0 < 65536)
            and (tlds[tld:lower()] or tld:find'^%d+$' and subd:find'^%d+%.%d+%.%d+%.$'
            and max_of_four(tld, subd:match'^(%d+)%.(%d+)%.(%d+)%.$') < 256)
        then
            finished[pos_start] = true
            found_url = true
        end
    end

    for pos_start, url, prot, dom, colon, port, slash, path in
        string:gmatch'()((%f[%w]%a+://)(%w[-.%w]*)(:?)(%d*)(/?)([%w_.~!*:@&+$/?%%#=-]*))'
        do
        if not finished[pos_start] and not (dom..'.'):find'%W%W'
            and protocols[prot:lower()] == (1 - #slash) * #path
            and (colon == '' or port ~= '' and port + 0 < 65536)
        then
            found_url = true
        end
    end

    if found_url ~= true then found_url = false end
    return(found_url)
end

--[[

path_handler() handles vim-external paths, including local files or web URLs
Returns nothing
Private function

--]]
local path_handler = function(path)
    if this_os == "Linux" then
        vim.api.nvim_command('silent !xdg-open '..path)
    elseif this_os == "Darwin" then
        vim.api.nvim_command('silent !open '..path..' &')
    else
        print('⬇️ : '..this_os_err)
    end
end

--[[

path_type() determines what kind of path is in a url
Returns a string:
     1. 'file' if the path has the 'file:' prefix,
     2. 'url' is the result of is_url(path) is true
     3. 'filename' if (1) and (2) aren't true
Private function

--]]
local path_type = function(path)
    if string.find(path, '^file:') then
        return('file')
    elseif is_url(path) then
        return('url')
    elseif string.find(path, '^@') then
        return('citation')
    elseif string.find(path, '^#') then
        return('anchor')
    else
        return('filename')
    end
end

--[[

formatLink() creates a formatted link from whatever text is passed to it
Returns a string:
     1. '[string of text](<prefix>_string-of-text.md)' in most cases
     2. '[anchor link](#anchor-link)' if the text starts with a hash (#)
Public function

--]]
M.formatLink = function(text, part)
    -- If the text starts with a hash, format the link as an anchor link
    if string.sub(text, 0, 1) == '#' then
        local name = string.gsub(text, '^#* *', '')
        local path_text = string.gsub(text, '[^%a%s%d]', '')
        path_text = string.gsub(path_text, '^ ', '')
        path_text = string.gsub(path_text, ' ', '-')
        path_text = string.gsub(path_text, '%-%-', '-')
        path_text = '#'..string.lower(path_text)
        local replacement = {'['..name..']'..'('..path_text..')'}
        if part == nil then
            return(replacement)
        elseif part == 1 then
            return(text)
        elseif part == 2 then
            return(path_text)
        end
    else
        -- Make a variable for the prefix to use
        local prefix = nil
        -- If the user wants the prefix evaluated, eval when this function is
        -- run (i.e., right here)
        if evaluate_prefix then
            prefix = loadstring("return "..new_file_prefix)()
            -- Otherwise, use the string provided by the user for the prefix
        else
            prefix = new_file_prefix
        end

        local path_text = string.gsub(text, " ", "-")
        -- Set up the replacement
        local replacement = {'['..text..']'..'('..prefix..path_text..'.md)'}
        if part == nil then
            return(replacement)
        elseif part == 1 then
            return(text)
        elseif part == 2 then
            return(path_text)
        end
    end
end

--[[

createLink() makes a link from the word under the cursor--or, if no word is
under the cursor, produces the syntax for a md link: [](YYYY-MM-DD_.md)
Returns nothing via stdout, but does insert text into the vim buffer
Public function

--]]
M.createLink = function()
    -- Make a variable for the prefix to use
    local prefix = nil
    -- If the user wants the prefix evaluated, eval when this function is run
    -- (i.e. right here)
    if evaluate_prefix then
        prefix = loadstring("return "..new_file_prefix)()
        -- Otherwise, just use the string provided by the user for the prefix
    else
        prefix = new_file_prefix
    end

    -- Get mode from vim
    local mode = vim.api.nvim_get_mode()['mode']

    -- Get the cursor position
    local position = vim.api.nvim_win_get_cursor(0)
    local row = position[1]
    local col = position[2]

    -- If the current mode is 'normal', make link from word under cursor
    if mode == 'n' then
        -- Get the text of the line the cursor is on
        local line = vim.api.nvim_get_current_line()
        -- Get the word under the cursor
        local cursor_word = vim.fn.expand('<cword>')
        -- Make a markdown link out of the date and cursor
        local replacement = {
            '['..cursor_word..']'..'('..prefix..cursor_word..'.md)'
        }

        -- Find the (first) position of the matched word in the line
        local left, right = string.find(line, cursor_word, nil, true)

        -- Make sure it's not a duplicate of the word under the cursor, and if it
        -- is, perform the search until a match is found whose right edge follows
        -- the cursor position
        while right < col do
            left, right = string.find(line, cursor_word, right, true)
        end

        -- Replace the word under the cursor w/ the formatted link replacement
        vim.api.nvim_buf_set_text(
            0, row - 1, left - 1, row - 1, right, replacement
        )

    -- If current mode is 'visual', make link from selection
    elseif mode == 'v' then

        -- Get the start of the visual selection (the end is the cursor position)
        local com = vim.fn.getpos('v')

        -- If the start of the visual selection is after the cursor position,
        -- use the cursor position as start and the visual position as finish
        local start = {}
        local finish = {}
        if com[3] > col then
            start = {row - 1, col}
            finish = {com[2] - 1, com[3] - 1 + com[4]}

            local region =
                vim.region(
                    0,
                    start,
                    finish,
                    vim.fn.visualmode(),
                (vim.o.selection ~= 'exclusive')
                )
            local lines = vim.api.nvim_buf_get_lines(
                0, start[1], finish[1] + 1, false
            )
            lines[1] = lines[1]:sub(
                region[start[1]][1] + 1, region[start[1]][2]
            )
            if start[1] ~= finish[1] then
                lines[#lines] = lines[#lines]:sub(
                    region[finish[1]][1] + 1, region[finish[1]][2]
                )
            end

            -- Save the text selection & replace spaces with dashes
            local text = table.concat(lines)
            local replacement = M.formatLink(text)

            -- Replace the visual selection w/ the formatted link replacement
            vim.api.nvim_buf_set_text(
                0, row - 1, col, com[2] - 1, com[3], replacement
            )
        else
            start = {com[2] - 1, com[3] - 1 + com[4]}
            finish = {row - 1, col}

            local region =
                vim.region(
                    0,
                    start,
                    finish,
                    vim.fn.visualmode(),
                (vim.o.selection ~= 'exclusive')
                )
            local lines = vim.api.nvim_buf_get_lines(
                0, start[1], finish[1] + 1, false
            )
            lines[1] = lines[1]:sub(
                region[start[1]][1] + 1, region[start[1]][2]
            )
            if start[1] ~= finish[1] then
                lines[#lines] = lines[#lines]:sub(
                    region[finish[1]][1] + 1, region[finish[1]][2]
                )
            end

            -- Save the text selection
            local text = table.concat(lines)
            local replacement = M.formatLink(text)
            -- Replace the visual selection w/ the formatted link replacement
            vim.api.nvim_buf_set_text(
                0, com[2] - 1, com[3] - 1, row - 1, col + 1, replacement
            )
        end

    end
end

--[[

does_exist() determines whether the path specified as the argument exists
NOTE: Assumes that the initially opened file is in an existing directory!
Private function

--]]
local does_exist = function(path, type)
    -- If type is not specified, use "d" (directory) by default
    type = type or "d"
    if this_os == "Linux" or this_os == "POSIX" or this_os == "Darwin" then

        -- Use the shell to determine if the path exists
        local handle = io.popen(
            'if [ -'..type..' "'..path..'" ]; then echo true; else echo false; fi'
        )
        local exists = handle:read('*l')
        io.close(handle)

        -- Get the contents of the first (only) line & store as a boolean
        if exists == 'false' then
            exists = false
        else
            exists = true
        end

        -- Return the existence property of the path
        return(exists)
    else
        print('⬇️ : '..this_os_err)

        -- Return a blep
        return(nil)
    end
end

-- Create a local table to keep track of buffers for backwards navigation
local buffer_stack = {}

-- Add two tables
buffer_stack.main = {}
buffer_stack.hist = {}

buffer_stack.push = function(stack_name, bufnr)
    -- Add the provided buffer number to the first position in the provided
    -- stack, pushing down the others in the provided stack
    table.insert(buffer_stack[stack_name], 1, bufnr)
end

buffer_stack.pop = function(stack_name)
    -- Remove the topmost element in the provided stack
    table.remove(buffer_stack[stack_name], 1)
end

buffer_stack.report = function(stack_name)
    -- Print out the contents of a stack
    for i = 1, #buffer_stack[stack_name], 1 do
        print(buffer_stack[stack_name][i])
    end
end

local escape_chars = function(string)
    -- Which characters to match
    local chars = "[ '&()$]"
    -- Set up table of replacements
    local replacements = {
        [" "] = "\\ ",
        ["'"] = "\\'",
        ["&"] = "\\&",
        ["("] = "\\(",
        [")"] = "\\)",
        ["$"] = "\\$",
        ["#"] = "\\#",
    }
    -- Do the replacement
    local escaped = string.gsub(string, chars, replacements)
    -- Return the new string
    return(escaped)
end

local escape_lua_chars = function(string)
    -- Which characters to match
    local chars = "[-.'\"a]"
    -- Set up table of replacements
    local replacements = {
        ["-"] = "%-",
        ["."] = "%.",
        ["'"] = "\'",
        ['"'] = '\"'
    }
    -- Do the replacement
    local escaped = string.gsub(string, chars, replacements)
    -- Return the new string
    return(escaped)
end

--[[

followPath() does something with the path in the link under the cursor:
     1. Creates the file specified in the path, if the path is determined to
        be a filename,
     2. Uses path_handler to open the URL specified in the path, if the path
        is determined to be a URL, or
     3. Uses path_handler to open a local file at the specified path via the
        system's default application for that filetype, if the path is dete-
        rmined to be neither the filename for a text file nor a URL.
Returns nothing
Public function

--]]
M.followPath = function(path)

    -- Path can be provided as an argument (this is currently only used when
    -- this function retrieves a path from the citation handler). If no path
    -- is provided as an arg, get the path under the cursor via get_path().
    if not path then
        -- Get the path in the link
        path = get_path()
    end

    -- Check that there's a non-nil output of get_path()
    if path then

        -- Get the name of the file in the link path. Will return nil if the
        -- link doesn't contain any directories.
        local filename = string.match(path, '.*/(.-)$')
        -- Get the name of the directory path to the file in the link path. Will
        -- return nil if the link doesn't contain any directories.
        local dir = string.match(path, '(.*)/.-$')

        -- If so, go to the path specified in the output
        if path_type(path) == 'filename' then

            -- Check if the user wants directories to be created and if
            -- a directory is specified in the link that we need to check
            if create_dirs and dir then
                -- If so, check how the user wants links to be interpreted
                if links_relative_to == 'first' then
                    -- Paste together the directory of the first-opened file
                    -- and the directory in the link path
                    local paste = initial_dir..'/'..dir

                    -- See if the path exists
                    local exists = does_exist(paste)

                    -- If the path doesn't exist, make it!
                    if not exists then
                        -- Escape special characters in path
                        local sh_esc_paste = escape_chars(paste)
                        -- Send command to shell
                        os.execute('mkdir -p '..sh_esc_paste)
                    end

                    -- Remember the buffer we're currently viewing
                    buffer_stack.push('main', vim.api.nvim_win_get_buf(0))
                    -- And follow the path!
                    vim.cmd(':e '..paste..'/'..filename)

                else -- Otherwise, they want it relative to the current file

                    -- So, get the path of the current file
                    local cur_file = vim.api.nvim_buf_get_name(0)

                    -- Get the directory the current file is in
                    local cur_file_dir = string.match(cur_file, '(.*)/.-$')

                    -- Paste together the directory of the current file and the
                    -- directory path provided in the link
                    local paste = cur_file_dir..'/'..dir

                    -- See if the path exists
                    local exists = does_exist(paste)

                    -- If the path doesn't exist, make it!
                    if not exists then
                        -- Escape special characters in path
                        local sh_esc_paste = escape_chars(paste)
                        -- Send command to shell
                        os.execute('mkdir -p '..sh_esc_paste)
                    end

                    -- Remember the buffer we're currently viewing
                    buffer_stack.push('main', vim.api.nvim_win_get_buf(0))
                    -- And follow the path!
                    vim.cmd(':e '..paste..'/'..filename)
                end

            -- Otherwise, if links are interpreted rel to first-opened file
            elseif links_relative_to == 'current' then

                -- Get the path of the current file
                local cur_file = vim.api.nvim_buf_get_name(0)

                -- Get the directory the current file is in
                local cur_file_dir = string.match(cur_file, '(.*)/.-$')

                -- Paste together the directory of the current file and the
                -- directory path provided in the link
                local paste = cur_file_dir..'/'..path

                -- Remember the buffer we're currently viewing
                buffer_stack.push('main', vim.api.nvim_win_get_buf(0))
                -- And follow the path!
                vim.cmd(':e '..paste)

            else -- Otherwise, links are relative to the first-opened file

                -- Paste the dir of the first-opened file and path in the link
                local paste = initial_dir..'/'..path

                -- Remember the buffer we're currently viewing
                buffer_stack.push('main', vim.api.nvim_win_get_buf(0))
                -- And follow the path!
                vim.cmd(':e '..paste)

            end

        elseif path_type(path) == 'url' then

            local se_path = vim.fn.shellescape(path)
            path_handler(se_path)

        elseif path_type(path) == 'file' then

            -- Get what's after the file: tag
            local real_path = string.match(path, '^file:(.*)')

            -- Check if path provided is absolute or relative to $HOME
            if string.match(real_path, '^~/') or string.match(real_path, '^/') then

                local se_paste = escape_chars(real_path)

                -- If the path starts with a tilde, replace it w/ $HOME
                if string.match(real_path, '^~/') then
                    se_paste = string.gsub(se_paste, '^~/', '$HOME/')
                end

                -- If the file exists, handle it; otherwise, print a warning
                -- Don't want to use the shell-escaped version; it will throw a
                -- false alert if there are escape chars
                if does_exist(se_paste, "f") == false and
                   does_exist(se_paste, "d") == false then
                    print("⬇️ : "..se_paste.." doesn't seem to exist!")
                else
                    path_handler(se_paste)
                end

            elseif links_relative_to == 'current' then

                -- Get the path of the current file
                local cur_file = vim.api.nvim_buf_get_name(0)

                -- Get the directory the current file is in
                local cur_file_dir = string.match(cur_file, '(.*)/.-$')

                -- Paste together the directory of the current file and the
                -- directory path provided in the link
                local paste = cur_file_dir..'/'..real_path

                -- Escape special characters
                local se_paste = escape_chars(paste)
                -- Pass to the path_handler function
                path_handler(se_paste)

            else
                -- Otherwise, links are relative to the first-opened file
                -- Paste together the directory of the first-opened file
                -- and the path in the link
                local paste = initial_dir..'/'..real_path

                -- Escape special characters
                local se_paste = escape_chars(paste)
                -- Pass to the path_handler function
                path_handler(se_paste)

            end
        elseif path_type(path) == 'anchor' then
            require('mkdnflow.cursor').toHeading(path)
        elseif path_type(path) == 'citation' then
            -- Pass to the citation_handler function from bib.lua to get
            -- highest-priority field in bib entry (if it exists)
            local field = require('mkdnflow.bib').citationHandler(
                escape_lua_chars(path)
            )
            -- Use this function to do sth with the information returned (if any)
            if field then
                M.followPath(field)
            end
        end
    else
        M.createLink()
    end
end

--[[

goBack() gets the current buffer number to see if it's greater than 1. If it
is, the current buffer is not the first that was opened, and there is a buffer
to go back to. It gets the previous buffer number from the buffer stack, goes
there, and then pops the top element from the main stack.
Public function

--]]
M.goBack = function()
    local cur_bufnr = vim.api.nvim_win_get_buf(0)
    if cur_bufnr > 1 then
        -- Add current buffer number to history
        buffer_stack.push('hist', cur_bufnr)
        -- Get previous buffer number
        local prev_buf = buffer_stack.main[1]
        -- Go to buffer
        vim.api.nvim_command("buffer "..prev_buf)
        -- Pop the buffer we just navigated to off the top of the stack
        buffer_stack.pop('main')
        -- return a boolean if goback succeeded (for users who want <bs> to do
        -- sth else if goback isn't possible)
        return(true)
    else
        print('⬇️ : Can\'t go back any further!')
        -- Return a boolean if goBack fails
        return(false)
    end
end

--[[

goForward() looks at the historical buffer stack to see if there's anything to
be navigated to. If there is, it adds the current buffer to the main stack,
goes to the buffer at the top of the history stack, and pops it from the histo-
ry stack. Returns `true` if successful, `false` if it fails.
Public function

--]]
M.goForward = function()
    -- Get current buffer number
    local cur_bufnr = vim.api.nvim_win_get_buf(0)
    -- Get historical buffer number
    local hist_bufnr = buffer_stack.hist[1]

    -- If there is a buffer number in the history stack, do the following; if
    -- not, print a warning
    if hist_bufnr then
        buffer_stack.push('main', cur_bufnr)
        -- Go to the historical buffer number
        vim.api.nvim_command("buffer "..hist_bufnr)
        -- Pop historical buffer stack
        buffer_stack.pop('hist')
        -- Return a boolean if goForward succeeded (for users who want <Del> to
        -- do sth else if goForward isn't possible)
        return(true)
    else
        -- Print out an error if there's nothing in the historical buffer stack
        print('⬇️ : Can\'t go forward any further!')
        -- Return a boolean if goForward failed (for users who want <Del> to do
        -- sth else if goForward isn't possible)
        return(false)
    end
end

-- Return all the functions added to the table M!
return M
