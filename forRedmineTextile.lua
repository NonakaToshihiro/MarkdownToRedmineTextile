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
    -- HTML <br> をそのまま保持（テーブルセル内の改行など）
    elseif el.t == "RawInline" then
      if el.format == "html" and el.text:match("<br") then res = res .. "<br>" end
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
  elseif block.t == "Table" then
    -- Pandoc AST にはセパレーター行（| --- | --- |）が含まれないため、
    -- そのまま行を出力するだけで自然に除外される
    local num_cols = #block.colspecs

    -- セル内の複数ブロックを <br> で結合
    local function render_cell(cell)
      local parts = {}
      for _, b in ipairs(cell.content) do
        local s = render_block(b)
        if s ~= "" then parts[#parts + 1] = s end
      end
      return table.concat(parts, "<br>")
    end

    -- 行のセルを配列として返す（列数に満たない場合は空セルで補完）
    local function render_row_cells(row)
      local cells = {}
      for _, cell in ipairs(row.cells) do
        cells[#cells + 1] = render_cell(cell)
      end
      while #cells < num_cols do cells[#cells + 1] = "" end
      return cells
    end

    -- 継続行の判定：2列目以降がすべて空
    -- Pandoc のパイプテーブルは1行1セルのため、改行を含む行は
    -- 別行として切り出され、続く列がすべて空になる
    local function is_continuation_row(cells)
      for i = 2, #cells do
        if cells[i] ~= "" then return false end
      end
      return true
    end

    local all_rows = {}

    if block.head and block.head.rows then
      for _, row in ipairs(block.head.rows) do
        all_rows[#all_rows + 1] = render_row_cells(row)
      end
    end

    if block.bodies then
      for _, tbody in ipairs(block.bodies) do
        if tbody.body then
          for _, row in ipairs(tbody.body) do
            all_rows[#all_rows + 1] = render_row_cells(row)
          end
        end
      end
    end

    -- 継続行を前の行の最終セルにマージ
    local merged = {}
    for _, cells in ipairs(all_rows) do
      if #merged > 0 and is_continuation_row(cells) and cells[1] ~= "" then
        local prev = merged[#merged]
        local last_idx = #prev
        while last_idx > 0 and prev[last_idx] == "" do last_idx = last_idx - 1 end
        if last_idx == 0 then last_idx = #prev end
        -- 前セル末尾と継続セル先頭の重複 <br> を正規化して結合
        local prev_s = prev[last_idx]:gsub("<br>%s*$", "")
        local cont_s = cells[1]:gsub("^<br>%s*", "")
        prev[last_idx] = prev_s .. "<br>" .. cont_s
      else
        merged[#merged + 1] = cells
      end
    end

    local lines = {}
    for _, cells in ipairs(merged) do
      lines[#lines + 1] = "| " .. table.concat(cells, " | ") .. " |"
    end

    return table.concat(lines, "\n")
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
    local first_para = nil
    local nested_lists = {}
    local other_blocks = {}
    
    -- リストアイテム内のブロックを分類
    for _, block in ipairs(item_blocks) do
      if block.t == "BulletList" or block.t == "OrderedList" then
        -- ネストしたリストを保存
        nested_lists[#nested_lists + 1] = block
      elseif (block.t == "Para" or block.t == "Plain") and first_para == nil then
        -- 最初の段落を保存
        first_para = render_block(block)
      else
        -- その他のブロックを保存
        other_blocks[#other_blocks + 1] = block
      end
    end
    
    -- 最初の段落を出力
    if first_para and first_para ~= "" then
      result[#result + 1] = my_prefix .. " " .. first_para
    end
    
    -- ネストしたリストを出力（同じ prefix レベルで継続）
    for _, nested_list in ipairs(nested_lists) do
      local nested_text = list_to_textile(nested_list, my_prefix)
      -- 各行を結果に追加（空行を除く）
      for line in nested_text:gmatch("[^\n]+") do
        if line:match("%S") then  -- 空白以外の文字を含む行のみ追加
          result[#result + 1] = line
        end
      end
    end
    
    -- その他のブロック（コードブロックなど）を出力
    for _, block in ipairs(other_blocks) do
      local s = render_block(block)
      if s ~= "" then
        result[#result + 1] = s
      end
    end
  end
  return table.concat(result, "\n")
end

-- 4. メイン処理：ドキュメント全体を RawBlock に置き換える
function Pandoc(doc)
  local blocks = {}
  local i = 1
  
  while i <= #doc.blocks do
    local block = doc.blocks[i]
    
    if block.t == "OrderedList" or block.t == "BulletList" then
      -- 連続するリストグループ（OrderedList+BulletList）を収集
      local list_groups = {}
      local j = i
      
      while j <= #doc.blocks do
        local current_block = doc.blocks[j]
        
        if current_block.t == "OrderedList" or current_block.t == "BulletList" then
          local primary_list = current_block
          local nested_bullets = {}
          j = j + 1
          
          -- この OrderedList に続く BulletList を収集
          if primary_list.t == "OrderedList" then
            while j <= #doc.blocks do
              local next_block = doc.blocks[j]
              
              if next_block.t == "BulletList" then
                nested_bullets[#nested_bullets + 1] = next_block
                j = j + 1
              elseif next_block.t == "Para" and pandoc.utils.stringify(next_block) == "" then
                j = j + 1
              else
                break
              end
            end
          end
          
          list_groups[#list_groups + 1] = {
            primary = primary_list,
            nested = nested_bullets
          }
          
          -- 次のブロックが OrderedList ならループ継続、そうでなければ終了
          if j <= #doc.blocks and doc.blocks[j].t == "OrderedList" then
            -- 空の Para をスキップ
            while j <= #doc.blocks and doc.blocks[j].t == "Para" and pandoc.utils.stringify(doc.blocks[j]) == "" do
              j = j + 1
            end
          else
            break
          end
        else
          break
        end
      end
      
      -- 収集したリストグループを連続して出力
      local all_results = {}
      for _, group in ipairs(list_groups) do
        if #group.nested == 0 then
          -- ネストなし
          local textile_text = list_to_textile(group.primary, "")
          for line in textile_text:gmatch("[^\n]+") do
            all_results[#all_results + 1] = line
          end
        else
          -- ネストした BulletList あり
          local result = {}
          local main_lines = {}
          
          local main_text = list_to_textile(group.primary, "")
          for line in main_text:gmatch("[^\n]+") do
            main_lines[#main_lines + 1] = line
          end
          
          for k = 1, #main_lines - 1 do
            result[#result + 1] = main_lines[k]
          end
          
          if #main_lines > 0 then
            result[#result + 1] = main_lines[#main_lines]
          end
          
          for _, nested in ipairs(group.nested) do
            local last_marker = (group.primary.t == "OrderedList") and "#" or "*"
            local nested_text = list_to_textile(nested, last_marker)
            result[#result + 1] = nested_text
          end
          
          for _, line in ipairs(result) do
            all_results[#all_results + 1] = line
          end
        end
      end
      
      blocks[#blocks + 1] = pandoc.RawBlock('textile', table.concat(all_results, "\n") .. "\n")
      i = j
    else
      local s = render_block(block)
      if s ~= "" then
        local sep = (block.t == "Header") and "\n" or "\n\n"
        blocks[#blocks + 1] = pandoc.RawBlock('textile', s .. sep)
      end
      i = i + 1
    end
  end
  
  return pandoc.Pandoc(blocks)
end