<div align="center">
  <img src="assets/logo.svg" alt="Quill Logo" width="120" height="120">

  <h1>quill.nvim</h1>

  <p>An elegant note-taking plugin for Neovim that emphasizes simplicity and efficiency.</p>
</div>

## ✨ Features

- 📝 Markdown-based note organization
- 🏷️ Intuitive tag support with search functionality
- 📁 Flexible directory-based organization
- 🔍 Seamless Telescope integration
- ⌚ Quick timestamp insertion
- 🚀 Fast and lightweight

## ⚡ Requirements

- Neovim >= 0.8.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for improved search)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "bradleydsmith/quill.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim", -- optional but recommended
    },
    cmd = { -- Register commands for lazy loading
        "QuillNew",
        "QuillSearch",
        "QuillTimestamp",
        "QuillTag",
        "QuillSearchTags",
        "QuillListTags",
    },
    opts = {
        notes_dir = vim.fn.expand("~/notes"), --set this to what ever you like
        date_format = "%Y-%m-%d %H:%M:%S",
        default_extension = ".md",
        tags_file = "tags.json",
        tag_identifier = "#"
    },
    keys = {
        { "<leader>qn", "<cmd>QuillNew<cr>", desc = "New Note" },
        { "<leader>qf", "<cmd>QuillSearch<cr>", desc = "Search Notes" },
        { "<leader>qi", "<cmd>QuillTimestamp<cr>", desc = "Insert Timestamp" },
        { "<leader>qa", "<cmd>QuillTag<cr>", desc = "Add Tag" },
        { "<leader>qft", "<cmd>QuillSearchTags<cr>", desc = "Search Tags" },
        { "<leader>qlt", "<cmd>QuillListTags<cr>", desc = "List Tags" },
    },
}
```

## 🚀 Usage

### Commands

- `:QuillNew [title]` - Create a new note
- `:QuillSearch` - Search through all notes
- `:QuillTimestamp` - Insert current timestamp at cursor
- `:QuillTag [tag]` - Add a tag at cursor position
- `:QuillSearchTags` - Search notes by tag
- `:QuillListTags` - Show all tags

### Default Keymaps

All commands are mapped under the `<leader>q` prefix:

- `<leader>qn` - Create new note
- `<leader>qf` - Search notes
- `<leader>qi` - Insert timestamp
- `<leader>qa` - Add tag
- `<leader>qft` - Search by tag
- `<leader>qlt` - List all tags

## ⚙️ Configuration

Customize quill.nvim by passing options to the setup function:

```lua
require('quill').setup({
    -- Directory where notes will be stored
    notes_dir = vim.fn.expand("~/notes"),
    
    -- Format for timestamps
    date_format = "%Y-%m-%d %H:%M:%S",
    
    -- Default file extension for new notes
    default_extension = ".md",
    
    -- File to store tag metadata
    tags_file = "tags.json",
    
    -- Symbol to use for tags (e.g., #tag)
    tag_identifier = "#"
})
```

## 📝 Example Note

```markdown
# Project Brainstorming
Created: 2024-12-10 14:30:00
Tags: #project #ideas #todo

## Key Points
- Review documentation #priority
- Set up next sprint #planning
```

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.
