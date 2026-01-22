-- 1. コードブロックの修正
function CodeBlock(el)
  local lang = el.classes[1] or ""
  local attr = ""
  if lang ~= "" then
    attr = ' class="' .. lang .. '"'
  end
  local html = '<pre><code' .. attr .. '>' .. el.text .. '</code></pre>\n'
  return pandoc.RawBlock('textile', html)
end

-- 2. 水平線 (---) をそのまま出力する
function HorizontalRule(el)
  -- <hr /> ではなく Textile 記法の --- を返す
  return pandoc.RawBlock('textile', '\n---\n')
end

-- 3. 文字装飾（太字、斜体、打ち消し線）の前後にスペースを強制挿入する
function Strong(el)
  return {pandoc.Space(), el, pandoc.Space()}
end

function Emph(el)
  return {pandoc.Space(), el, pandoc.Space()}
end

function Strikeout(el)
  return {pandoc.Space(), el, pandoc.Space()}
end

-- 4. リストを HTML 化させずに強制出力（改行制御を最適化）
local function list_to_textile(el, marker)
  local result = {}
  for _, item_blocks in ipairs(el.content) do
    local item_text = ""
    for i, block in ipairs(item_blocks) do
      -- 各ブロックを個別に Textile 変換
      local text = pandoc.write(pandoc.Pandoc({block}), 'textile')
      -- 末尾の余分な改行をトリミング
      text = text:gsub("\n+$", "")
      
      if i > 1 then
        -- 2つ目以降のブロック（テキストの後のコードなど）は1つの改行で繋ぐ
        item_text = item_text .. "\n" .. text
      else
        item_text = text
      end
    end
    table.insert(result, marker .. " " .. item_text)
  end
  return pandoc.RawBlock('textile', table.concat(result, "\n") .. "\n")
end

function OrderedList(el)
  return list_to_textile(el, "#")
end

function BulletList(el)
  return list_to_textile(el, "*")
end
