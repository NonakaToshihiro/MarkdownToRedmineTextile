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