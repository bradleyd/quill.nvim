-- Default configuration
local M = {}

M.defaults = {
	-- Directory where notes will be stored
	notes_dir = vim.fn.expand("~/notes"),

	-- Format for timestamps
	date_format = "%Y-%m-%d %H:%M:%S",

	-- Default file extension for new notes
	default_extension = ".md",

	-- File to store tag metadata
	tags_file = "tags.json",

	-- Symbol to use for tags
	tag_identifier = "#",
}

-- The current configuration, populated in setup()
M.options = {}

-- Setup function for configuration
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})

	-- Ensure notes directory exists
	if vim.fn.isdirectory(M.options.notes_dir) == 0 then
		vim.fn.mkdir(M.options.notes_dir, "p")
	end
end

return M
