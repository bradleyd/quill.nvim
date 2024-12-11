local config = require("quill.config")
local M = {}

-- Load tags from tags file
local function load_tags()
	-- Get absolute path to tags file
	local tags_path = config.options.notes_dir .. "/" .. config.options.tags_file
	-- Create empty tags file if it doesn't exist
	if vim.fn.filereadable(tags_path) == 0 then
		-- Create an empty tags structure
		local empty_tags = vim.json.encode({})
		-- Ensure directory exists
		if vim.fn.isdirectory(config.options.notes_dir) == 0 then
			vim.fn.mkdir(config.options.notes_dir, "p")
		end
		-- Write empty tags file
		vim.fn.writefile({ empty_tags }, tags_path)
		return {}
	end
	-- Read existing tags
	local content = vim.fn.readfile(tags_path)
	-- Handle empty file case
	if #content == 0 then
		return {}
	end
	-- Parse JSON content
	local ok, decoded = pcall(vim.json.decode, content[1])
	if not ok then
		vim.notify("Error reading tags file: " .. decoded, vim.log.levels.ERROR)
		return {}
	end
	return decoded
end

-- Save tags to tags file
local function save_tags(tags_data)
	-- Get absolute path to tags file
	local tags_path = config.options.notes_dir .. "/" .. config.options.tags_file
	-- Encode tags data
	local ok, encoded = pcall(vim.json.encode, tags_data)
	if not ok then
		vim.notify("Error encoding tags data: " .. encoded, vim.log.levels.ERROR)
		return
	end
	-- Ensure directory exists
	if vim.fn.isdirectory(config.options.notes_dir) == 0 then
		vim.fn.mkdir(config.options.notes_dir, "p")
	end
	-- Write tags file
	local write_ok, write_error = pcall(vim.fn.writefile, { encoded }, tags_path)
	if not write_ok then
		vim.notify("Error writing tags file: " .. write_error, vim.log.levels.ERROR)
	end
end

-- Update tags for the current file
local function update_tags_for_current_file()
	local current_file = vim.fn.expand("%:p")

	-- Debug current file path
	vim.notify("Current file: " .. current_file)
	vim.notify("Notes dir: " .. config.options.notes_dir)

	-- Check if file is in notes directory
	if not string.find(current_file, config.options.notes_dir, 1, true) then
		vim.notify("File not in notes directory")
		return
	end

	-- Get path relative to notes directory
	local relative_path = current_file:sub(#config.options.notes_dir + 2) -- +2 to account for trailing slash
	vim.notify("Relative path: " .. relative_path)

	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local tags = {}

	-- Extract tags from file content
	for _, line in ipairs(lines) do
		for tag in line:gmatch(config.options.tag_identifier .. "(%w+)") do
			tags[tag] = true
			vim.notify("Found tag: " .. tag)
		end
	end

	-- Update tags database
	local tags_data = load_tags()
	vim.notify("Current tags data: " .. vim.inspect(tags_data))

	-- Remove old file entries
	for tag, files in pairs(tags_data) do
		tags_data[tag] = vim.tbl_filter(function(f)
			return f ~= relative_path
		end, files)
		-- Remove tags with no files
		if #tags_data[tag] == 0 then
			tags_data[tag] = nil
		end
	end

	-- Add new tags
	for tag, _ in pairs(tags) do
		if not tags_data[tag] then
			tags_data[tag] = {}
		end
		table.insert(tags_data[tag], relative_path)
		vim.notify("Added path " .. relative_path .. " to tag " .. tag)
	end

	-- Save updated tags
	save_tags(tags_data)
	vim.notify("Saved tags data: " .. vim.inspect(tags_data))
end

-- Create a new note
function M.new_note(title)
	-- Generate filename from title or timestamp if no title provided
	local filename
	if title and title ~= "" then
		filename = title:gsub("%s", "_"):lower()
	else
		filename = os.date("%Y%m%d_%H%M%S")
	end

	-- Add extension
	filename = filename .. config.options.default_extension

	-- Get directory from user
	local dir = vim.fn.input("Directory (leave empty for root): ", "")
	local full_dir = config.options.notes_dir

	if dir ~= "" then
		full_dir = full_dir .. "/" .. dir
		-- Create directory if it doesn't exist
		if vim.fn.isdirectory(full_dir) == 0 then
			vim.fn.mkdir(full_dir, "p")
		end
	end

	-- Create full path
	local full_path = full_dir .. "/" .. filename

	-- Create and open the file
	vim.cmd("edit " .. vim.fn.fnameescape(full_path))

	-- Insert template if it's a new file
	if vim.fn.filereadable(full_path) == 0 then
		local template = {
			"# " .. (title or "Untitled Note"),
			"Created: " .. os.date(config.options.date_format),
			"Tags: ",
			"",
			"",
		}
		vim.api.nvim_buf_set_lines(0, 0, 0, false, template)
		-- Place cursor on the last line
		vim.api.nvim_win_set_cursor(0, { 4, 0 })
	end
end

-- Search notes
function M.search_notes()
	if pcall(require, "telescope.builtin") then
		require("telescope.builtin").live_grep({
			search_dirs = { config.options.notes_dir },
			prompt_title = "Search Notes",
			file_ignore_patterns = {
				config.options.tags_file,
				"%.git/.*",
				"%.obsidian/.*",
				"%.stversions/.*",
				"%.trash/.*",
			},
			additional_args = function()
				return { "-g", "*.md" }
			end,
		})
	else
		vim.ui.input({
			prompt = "Search notes: ",
		}, function(input)
			if input then
				if vim.fn.executable("rg") == 1 then
					local cmd = string.format(
						'rg --vimgrep --type-add "markdown:*.md" -tmarkdown --hidden -g "!%s" "%s" %s',
						config.options.tags_file,
						input,
						config.options.notes_dir
					)
					vim.fn.setqflist({}, " ", {
						title = "Notes Search Results",
						lines = vim.fn.systemlist(cmd),
					})
				else
					local pattern = config.options.notes_dir .. "/**/*" .. config.options.default_extension
					vim.cmd("vimgrep /" .. input .. "/j " .. pattern)
				end
				vim.cmd("copen")
			end
		end)
	end
end

-- Insert timestamp
function M.insert_timestamp()
	local timestamp = os.date(config.options.date_format)
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local new_line = line:sub(1, pos[2]) .. timestamp .. line:sub(pos[2] + 1)
	vim.api.nvim_set_current_line(new_line)
	vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #timestamp })
end

-- Add a tag
function M.add_tag(tag_input)
	if tag_input and tag_input ~= "" then
		local tag = config.options.tag_identifier .. tag_input
		local pos = vim.api.nvim_win_get_cursor(0)
		local line = vim.api.nvim_get_current_line()
		local new_line = line:sub(1, pos[2]) .. tag .. " " .. line:sub(pos[2] + 1)
		vim.api.nvim_set_current_line(new_line)
		vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #tag + 1 })
	else
		vim.ui.input({
			prompt = "Enter tag (without " .. config.options.tag_identifier .. "): ",
		}, function(input)
			if input then
				local tag = config.options.tag_identifier .. input
				local pos = vim.api.nvim_win_get_cursor(0)
				local line = vim.api.nvim_get_current_line()
				local new_line = line:sub(1, pos[2]) .. tag .. " " .. line:sub(pos[2] + 1)
				vim.api.nvim_set_current_line(new_line)
				vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + #tag + 1 })
			end
		end)
	end
end

-- Search by tag
function M.search_by_tag()
	local tags_data = load_tags()
	local tags = vim.tbl_keys(tags_data)

	if #tags == 0 then
		vim.notify("No tags found", vim.log.levels.INFO)
		return
	end

	vim.ui.select(tags, {
		prompt = "Select tag to search:",
		format_item = function(item)
			return config.options.tag_identifier .. item .. " (" .. #tags_data[item] .. " notes)"
		end,
	}, function(tag)
		if tag then
			local files = tags_data[tag]
			if pcall(require, "telescope.builtin") then
				require("telescope.pickers")
					.new({}, {
						prompt_title = "Notes with tag " .. config.options.tag_identifier .. tag,
						finder = require("telescope.finders").new_table({
							results = files,
							entry_maker = function(entry)
								-- Construct full path by combining notes_dir with the relative path
								local full_path = config.options.notes_dir .. "/" .. entry
								-- For display, just show the relative path
								return {
									value = entry,
									display = entry,
									ordinal = entry,
									path = full_path,
									filename = full_path,
								}
							end,
						}),
						sorter = require("telescope.config").values.generic_sorter({}),
						previewer = require("telescope.config").values.file_previewer({}),
						attach_mappings = function(prompt_bufnr, map)
							require("telescope.actions").select_default:replace(function()
								local selection = require("telescope.actions.state").get_selected_entry()
								require("telescope.actions").close(prompt_bufnr)
								if selection then
									-- Use the full path when opening the file
									vim.cmd("edit " .. vim.fn.fnameescape(selection.path))
								end
							end)
							return true
						end,
					})
					:find()
			else
				-- Fallback to quickfix list
				local qf_list = {}
				for _, file in ipairs(files) do
					local full_path = config.options.notes_dir .. "/" .. file
					table.insert(qf_list, {
						filename = full_path,
						text = "Tagged with " .. config.options.tag_identifier .. tag,
					})
				end
				vim.fn.setqflist(qf_list)
				vim.cmd("copen")
			end
		end
	end)
end

-- List all tags
function M.list_tags()
	local tags_data = load_tags()
	local output = { "# Tags Overview" }

	for tag, files in pairs(tags_data) do
		table.insert(output, string.format("- %s%s (%d notes)", config.options.tag_identifier, tag, #files))
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

	vim.cmd("vsplit")
	vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
end

-- Plugin setup function
function M.setup(user_opts)
	-- Initialize configuration
	config.setup(user_opts)

	-- Initialize tags file
	load_tags() -- This will create the tags file if it doesn't exist

	-- Create user commands with global availability
	local commands = {
		{
			name = "QuillNew",
			callback = function(cmd_opts)
				M.new_note(cmd_opts.args)
			end,
			opts = { nargs = "?" },
		},
		{
			name = "QuillSearch",
			callback = function()
				M.search_notes()
			end,
			opts = {},
		},
		{
			name = "QuillTimestamp",
			callback = function()
				M.insert_timestamp()
			end,
			opts = {},
		},
		{
			name = "QuillTag",
			callback = function(cmd_opts)
				M.add_tag(cmd_opts.args)
			end,
			opts = { nargs = "?" },
		},
		{
			name = "QuillSearchTags",
			callback = function()
				M.search_by_tag()
			end,
			opts = {},
		},
		{
			name = "QuillListTags",
			callback = function()
				M.list_tags()
			end,
			opts = {},
		},
	}

	-- Register each command
	for _, cmd in ipairs(commands) do
		vim.api.nvim_create_user_command(cmd.name, cmd.callback, cmd.opts)
	end

	-- Set up autocommands for tag management
	local group = vim.api.nvim_create_augroup("Quill", { clear = true })

	-- Modified BufWritePost autocmd to trigger for any markdown file
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = "*.md",
		callback = function()
			-- Only process files in the notes directory
			local current_file = vim.fn.expand("%:p")
			if string.find(current_file, config.options.notes_dir, 1, true) then
				update_tags_for_current_file()
			end
		end,
	})

	-- Set up buffer-local keymaps when opening markdown files in notes directory
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		group = group,
		pattern = "*.md",
		callback = function()
			local current_file = vim.fn.expand("%:p")
			if string.find(current_file, config.options.notes_dir, 1, true) then
				vim.opt_local.wrap = true
				vim.opt_local.linebreak = true
			end
		end,
	})
end
return M
