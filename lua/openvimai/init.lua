local M   = {}
local cfg = require("openvimai.config")
local ui  = require("openvimai.ui.float")
local client = require("openvimai.core.client")
local helper = require("openvimai.core.helpers")
local prompts = require("openvimai.core.prompts")
local chat = require("openvimai.chat")
local context = require("openvimai.core.context")
local ntok    = require("openvimai.core.approx_token").count
local tlog    = require("openvimai.telemetry.logger")

vim.api.nvim_create_autocmd("TextChanged", {
    pattern = "*",
    callback = function()
        tlog.send("change", { buf = vim.api.nvim_get_current_buf() })
    end,
})

-- vim.notify("OpenVimAI loaded (Ping & Haiku demo)")

-- :AIPing – Show a ping response from the FastAPI backend in a popup
vim.api.nvim_create_user_command("AIPing", function()
    client.ping(function(resp)
        ui.show("Ping", resp)
    end)
end, { desc = "Ping FastAPI proxy" })

-- :AIExplain – Explain selected code (range, visual, or current line)
vim.api.nvim_create_user_command("AIExplain", function(opts)
    local snippet = nil
    if opts.range == 1 or opts.range == 2 then
        local l1, l2 = opts.line1, opts.line2
        if l1 and l2 and l1 ~= 0 and l2 ~= 0 then
            local lines = vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false)
            snippet = table.concat(lines, "\n")
        end
    end

    if not snippet or snippet == "" then
        snippet = require("openvimai.core.helpers").get_visual_selection()
    end

    if not snippet or snippet == "" then
        snippet = vim.api.nvim_get_current_line()
    end

    if not snippet or snippet == "" then
        vim.notify("Nothing to explain (selection empty).", vim.log.levels.WARN)
        return
    end

    local win, buf = ui.show("AI Explain", "Analyzing…")
    vim.bo[buf].modifiable = true
    local acc = {}

    local prompt = prompts.explain_simple .. "```" .. snippet .. "```" .. "\n"

    client.stream_prompt(
        prompt,
        function(tok)
            table.insert(acc, tok)
            vim.schedule(function()
                local lines = vim.split(table.concat(acc), "\n", { plain = true })
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                ui.resize(win, lines)
            end)
        end,
        function(full)
            vim.schedule(function()
                local lines = vim.split(full, "\n", { plain = true })
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                vim.bo[buf].filetype = "markdown"
                ui.resize(win, lines)
            end)
        end
    )
end, {
        desc  = "Explain selected code with ChatGPT",
        range = true,
    })

-- :AIComplete – Inline code completion based on current line

vim.api.nvim_create_user_command("AIComplete", function(opts)
    local snippet = nil
    if opts.range == 1 or opts.range == 2 then
        local l1, l2 = opts.line1, opts.line2
        if l1 and l2 and l1 ~= 0 and l2 ~= 0 then
            local lines = vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false)
            snippet = table.concat(lines, "\n")
        end
    end

    if not snippet or snippet == "" then
        snippet = require("openvimai.core.helpers").get_visual_selection()
    end

    if not snippet or snippet == "" then
        snippet = vim.api.nvim_get_current_line()
    end

    if not snippet or snippet == "" then
        vim.notify("Nothing to complete (selection empty).", vim.log.levels.WARN)
        return
    end

    --     local lang = vim.bo.filetype ~= "" and vim.bo.filetype or "code"


    local lang   = (vim.bo.filetype ~= "" and vim.bo.filetype) or "code"
    snippet      = context.trim(nil, snippet)
    local header = prompts.inline_complete(lang) .. "```" .. lang .. "\n"
    local footer = "\n```"
    while ntok(header .. snippet .. footer) > 8192 do
        snippet = snippet:sub(1, math.floor(#snippet / 2))
    end
    local win, buf = ui.show("AI Complete", "Thinking…")
    vim.bo[buf].modifiable = true
    local acc = {}
    local prompt = header .. snippet .. footer

    local t0 = vim.loop.hrtime()                -- ns
    tlog.send("request", {
        source        = "AIComplete",
        lang          = lang,
        prompt_tokens = ntok(prompt),
    })

    client.stream_prompt(
        prompt,
        function(tok)
            table.insert(acc, tok)
            vim.schedule(function()
                local lines = vim.split(table.concat(acc), "\n", { plain = true })
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                ui.resize(win, lines)
            end)
        end,
        function(full)
            vim.schedule(function()
                local lines = vim.split(full, "\n", { plain = true })
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                vim.bo[buf].filetype = "markdown"
                ui.resize(win, lines)
                local latency = math.floor((vim.loop.hrtime() - t0) / 1e6) -- ms
                tlog.send("accept", {
                    source            = "AIComplete",
                    latency_ms        = latency,
                    completion_tokens = ntok(full),
                })
            end)
        end
    )
end, {
        desc  = "Explain selected code with ChatGPT",
        range = true,
    })



-- :AIChat – Open interactive AI chat popup (with command or prompt)
vim.api.nvim_create_user_command("AIChat", function(opts)
    local c = chat.get()

    if #opts.fargs > 0 then
        c:user_say(table.concat(opts.fargs, " "))
        return
    end

    vim.ui.input({ prompt = "You: " }, function(input)
        if not input then return end
        c:user_say(input)
    end)
end, {
        desc  = "Open AI chat popup (uses history)",
        nargs = "*",
    })

-- :AIComment – Generate inline comments for selected code
vim.api.nvim_create_user_command("AIComment", function(opts)
    local snippet = nil
    if opts.range == 1 or opts.range == 2 then
        local l1, l2 = opts.line1, opts.line2
        snippet = table.concat(
            vim.api.nvim_buf_get_lines(0, l1 - 1, l2, false), "\n")
    end
    if not snippet or snippet == "" then
        snippet = helper.get_visual_selection()
    end
    if not snippet or snippet == "" then
        snippet = vim.api.nvim_get_current_line()
    end
    if not snippet or snippet:match("^%s*$") then
        vim.notify("Nothing to comment.", vim.log.levels.WARN); return
    end

    local lang = vim.bo.filetype ~= "" and vim.bo.filetype or "code"

    local win, buf = ui.show("AI Comment (" .. lang .. ")", "Thinking…")
    vim.bo[buf].modifiable = true
    local acc = {}

    local prompt = prompts.comment_block(lang) .. "```" .. lang .. "\n" .. snippet .. "```" .. "\n"

    client.stream_prompt(
        prompt,
        function(tok)
            table.insert(acc, tok)
            vim.schedule(function()
                local lines = vim.split(table.concat(acc), "\n", { plain = true })
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                ui.resize(win, lines)
            end)
        end,
        function(full)
            vim.schedule(function()
                local lines = vim.split(full, "\n", { plain = true })
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                vim.bo[buf].filetype = "markdown"
                ui.resize(win, lines)
            end)
        end
    )
end, {
        desc  = "Generate inline comments for selected code",
        range = true,
    })

-- :AIDoc – Generate a docstring for the selected code
vim.api.nvim_create_user_command("AIDoc", function(opts)
    local snippet
    if opts.range > 0 then
        snippet = table.concat(
            vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false), "\n")
    end
    if not snippet or snippet == "" then
        snippet = helper.get_visual_selection()
    end
    if not snippet or snippet == "" then
        snippet = vim.api.nvim_get_current_line()
    end
    if not snippet or snippet:match("^%s*$") then
        vim.notify("Nothing to document.", vim.log.levels.WARN)
        return
    end

    local lang = vim.bo.filetype ~= "" and vim.bo.filetype or "code"

    local prompt = prompts.doc_block(lang) .. "```" .. lang .. "\n" .. snippet .. "```" .. "\n"

    local win, buf = ui.show("AI Doc ("..lang..")", "Thinking…")
    vim.bo[buf].modifiable = true
    local acc = {}

    client.stream_prompt(
        prompt,
        function(tok)
            table.insert(acc, tok)
            vim.schedule(function()
                local lines = vim.split(table.concat(acc), "\n", { plain = true })
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                ui.resize(win, lines)
            end)
        end,
        function(full)
            vim.schedule(function()
                local lines = vim.split(full, "\n", { plain = true })
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                vim.bo[buf].filetype = "markdown"
                ui.resize(win, lines)
            end)
        end
    )
end, {
        desc  = "Show docstring / docs for selected code (popup only)",
        range = true,
    })

function M.setup(opts)
    cfg.setup(opts or {})
end

return M
