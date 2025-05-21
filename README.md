# OpenVimAI.nvim

A context-aware AI assistant for Neovim, powered by OpenAI and a local FastAPI proxy.

OpenVimAI lets you interact with an LLM directly from Neovim. Features include inline completion, code explanation, comment generation, and a real-time chat popup — all streamed from a local proxy that manages caching, telemetry, and token budgeting.

![OpenVimAI popup](https://github.com/user-attachments/assets/5b3f90b4-2897-4def-988a-0fa09f9d67b7)

## ✨ Features

- Inline completions with smart token trimming
- Code explanation & docstring generation
- Live AI chat interface
- FastAPI-based local proxy with SSE
- Token budgeting & local caching
- Secure JWT-based communication

## 🛠 Installation

With [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "ram-rt/openvimai.nvim",
    config = function()
        require("openvimai").setup({
            endpoint = "http://127.0.0.1:8000",
            jwt_secret = "your-jwt-secret",
            timeout_ms = 15000,
        })
    end
}
```


## 📦 Requirements
- Neovim 0.9+

- A running local FastAPI proxy:
    https://github.com/ram-rt/openvimai-proxy


## 🧪 Commands
- :AIComplete — inline code generation

- :AIExplain — explain selected code
    
- :AIComment — generate inline comments
    
- :AIDoc — generate docstrings
    
- :AIChat — popup chat with context memory
    
- :AIPing — check backend status


## 📄 License
MIT — see [LICENSE](./LICENSE)
