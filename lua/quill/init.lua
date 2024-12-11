local config = require("quill.config")
local M = {}

-- Load tags from tags file
local function load_tags()
	local tags_path = config.options.notes_dir .. "/" .. config.options.tags_file
	if vim.fn.filereadable(tags_path) == 1 then
		local content = vim.fn.readfile(tags_path)
		return vim.json.decode(content[1] or "{}")
	end
	return {}
end

-- Save tags to tags file
local function save_tags(tags_data)
	local tags_path = config.options.notes_dir .. "/" .. config.options.tags_file
	local content = vim.json.encode(tags_data)
	vim.fn.writefile({ content }, tags_path)
end

-- Update tags for the current file
local function update_tags_for_current_file()
	local current_file = vim.fn.expand("%:p")
	if not vim.startswith(current_file, config.options.notes_dir) then
		return
	end

	local relative_path = vim.fn.fnamemodify(current_file, ":.")
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local tags = {}

	-- Extract tags from file content
	for _, line in ipairs(lines) do
		for tag in line:gmatch(config.options.tag_identifier .. "(%w+)") do
			tags[tag] = true
		end
	end

	-- Update tags database
	local tags_data = load_tags()

	-- Remove old file entries
	for tag, files in pairs(tags_data) do
		tags_data[tag] = vim.tbl_filter(function(f)
			return f ~= relative_path
		end, files)
	end

	-- Add new tags
	for tag, _ in pairs(tags) do
		if not tags_data[tag] then
			tags_data[tag] = {}
		end
		table.insert(tags_data[tag], relative_path)
	end

	save_tags(tags_data)
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
								return {
									value = entry,
									display = entry,
									ordinal = entry,
									path = entry,
									filename = entry,
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
									vim.cmd("edit " .. vim.fn.fnameescape(selection.path))
								end
							end)
							return true
						end,
					})
					:find()
			else
				local qf_list = {}
				for _, file in ipairs(files) do
					table.insert(qf_list, {
						filename = file,
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
function M.setup(opts)
	-- Initialize configuration
	config.setup(opts)

	-- Create user commands
	vim.api.nvim_create_user_command("QuillNew", function(opts)
		M.new_note(opts.args)
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("QuillSearch", function()
		M.search_notes()
	end, {})

	vim.api.nvim_create_user_command("QuillTimestamp", function()
		M.insert_timestamp()
	end, {})

	vim.api.nvim_create_user_command("QuillTag", function(opts)
		M.add_tag(opts.args)
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("QuillSearchTags", function()
		M.search_by_tag()
	end, {})

	vim.api.nvim_create_user_command("QuillListTags", function()
		M.list_tags()
	end, {})

	-- Set up autocommands for tag management
	local group = vim.api.nvim_create_augroup("Quill", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = config.options.notes_dir .. "/**/*" .. config.options.default_extension,
		callback = function()
			update_tags_for_current_file()
		end,
	})
end

return M
