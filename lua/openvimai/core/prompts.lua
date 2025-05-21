local M = {}

local function t(...)
    return table.concat({ ... }, "\n")
end

----------------------------------------------------------------
-- 1.  System‑prompt
----------------------------------------------------------------
M.system = t(
    "You are **OpenVimAI**, an AI assistant living inside Neovim.",
    "Respond concisely; use markdown for formatting when helpful."
)

----------------------------------------------------------------
-- 2.  Explain‑snippet (AIExplain)
----------------------------------------------------------------
M.explain_simple = t(
    "Explain the following snippet *line by line* in simple terms:",
    ""
)

----------------------------------------------------------------
-- 3.  Inline‑completion (AIComplete)
----------------------------------------------------------------
function M.inline_complete(lang)
    lang = lang or "code"
    return t(
        "Analyze the following code snippet or context.",
        "If you notice any issues, suggest improvements and unify style.",
        "Then, continue the implementation from where the snippet ends.",
        "",
        "Respond only with the revised code block, including the continuation if applicable.",
        "",
        "```" .. lang
    )
end

----------------------------------------------------------------
-- 4.  Inline comments (AIComment)
----------------------------------------------------------------
function M.comment_block(lang)
    lang = lang or "code"
    return t(
        ("Add concise, helpful inline comments to the following %s snippet. "):format(lang),
        "Keep original code, prepend comments using the language’s syntax.",
        ""
    )
end

----------------------------------------------------------------
-- 5.  Docstring / docs (AIDoc)
----------------------------------------------------------------
function M.doc_block(lang)
    lang = lang or "code"
    return t(
        ("Write an idiomatic documentation comment for the following %s snippet."):format(lang),
        ""
    )
end

----------------------------------------------------------------
-- 6.  Chat‑history → prompt (for /completion)
----------------------------------------------------------------
function M.chat_history(history)
    local parts = {}
    for _, msg in ipairs(history) do
        local tag = (msg.role == "user") and "User:" or "Assistant:"
        table.insert(parts, tag .. " " .. msg.content)
    end
    table.insert(parts, "Assistant:")
    return table.concat(parts, "\n")
end


return M
