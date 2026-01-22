-- forRedmineTextile.lua

-- 1. インライン要素（太字、リンク、コード等）を文字列に変換
local function render_inlines(inlines)
  local res = ""
  for _, el in ipairs(inlines) do
    if el.t == "Str" then res = res .. el.text
    elseif el.t == "Space" then res = res .. " "
    elseif el.t == "SoftBreak" then res = res .. " "
    -- 装飾の前後にスペースを強制挿入
    elseif el.t == "Strong" then res = res .. " *" .. render_inlines(el.content) .. "* "
    elseif el.t == "Emph" then res = res .. " _" .. render_inlines(el.content) .. "_ "
    elseif el.t == "Strikeout" then res = res .. " -" .. render_inlines(el.content) .. "- "
    -- インラインコード (@code@)
    elseif el.t == "Code" then res = res .. " @" .. el.text .. "@ "
    -- リンク ("text":url)
    elseif el.t == "Link" then res = res .. ' "' .. render_inlines(el.content) .. '":' .. el.target
    else res = res .. pandoc.utils.stringify(el) end
  end
  -- 連続するスペースを整理
  return res:gsub(" +", " "):gsub("^ +", ""):gsub(" +$", "")
end

-- 2. ブロック要素（段落、ヘッダー、コードブロック）を文字列に変換
local function render_block(block)
  if block.t == "Para" or block.t == "Plain" then
    return render_inlines(block.content)
  elseif block.t == "Header" then
    return "h" .. block.level .. ". " .. render_inlines(block.content)
  elseif block.t == "CodeBlock" then
    local lang = block.classes[1] or ""
    local attr = lang ~= "" and (' class="' .. lang .. '"') or ""
    return '<pre><code' .. attr .. '>' .. block.text .. '</code></pre>'
  elseif block.t == "HorizontalRule" then
    return "---"
  else
    return pandoc.utils.stringify(block)
  end
end

-- 3. リストを再帰的に Textile 文字列へ変換（ネスト対応）
local function list_to_textile(el, prefix)
  local result = {}
  local marker = (el.t == "OrderedList") and "#" or "*"
  local my_prefix = prefix .. marker
  
  for _, item_blocks in ipairs(el.content) do
    local is_first_block = true
    for _, block in ipairs(item_blocks) do
      if block.t == "BulletList" or block.t == "OrderedList" then
        -- ネストしたリストを再帰処理（プレフィックスを引き継ぐ）
        result[#result + 1] = list_to_textile(block, my_prefix)
      else
        local s = render_block(block)
        if s ~= "" then
          if is_first_block then
            result[#result + 1] = my_prefix .. " " .. s
            is_first_block = false
          else
            -- リスト内の2つ目以降の要素（コードブロック等）は改行で繋ぐ
            result[#result + 1] = s
          end
        end
      end
    end
  end
  return table.concat(result, "\n")
end

-- 4. メイン処理：ドキュメント全体を RawBlock に置き換える
function Pandoc(doc)
  local blocks = {}
  for _, block in ipairs(doc.blocks) do
    if block.t == "BulletList" or block.t == "OrderedList" then
      blocks[#blocks + 1] = pandoc.RawBlock('textile', list_to_textile(block, "") .. "\n\n")
    else
      local s = render_block(block)
      if s ~= "" then
        -- ヘッダーや段落の後に適切な空行を入れる
        local sep = (block.t == "Header") and "\n" or "\n\n"
        blocks[#blocks + 1] = pandoc.RawBlock('textile', s .. sep)
      end
    end
  end
  return pandoc.Pandoc(blocks)
end