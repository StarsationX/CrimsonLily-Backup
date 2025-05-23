local luacompactImports = {}
local luacompactModules = {}

function resolvePath(dir, luacompactTable)
	while string.sub(dir, 1, 1) == "." or string.sub(dir, 1, 1) == "/" do
		dir = string.sub(dir, 2)
	end

	if luacompactTable[dir..".lua"] then
		dir = dir..".lua"
	elseif luacompactTable[dir..".luau"] then
		dir = dir..".luau"
	end
	return dir
end

function load(dir)
	local path = resolvePath(dir, luacompactModules)
	local loadedScript = luacompactModules[path]
	if typeof(loadedScript) == "function" then
		return loadedScript()
	end
	return "Invalid script path."
end

function import(dir)
	local path = resolvePath(dir, luacompactImports)
	local importedFile = luacompactImports[path]
	if typeof(importedFile) == "function" then
		return importedFile()
	end
	return "Invalid file path."
end

luacompactModules["src/lib/ESP.lua"] = function()
	--Settings--
	local ESP = {
	    Enabled = false,
	    Boxes = true,
	    BoxShift = CFrame.new(0,-1.5,0),
		BoxSize = Vector3.new(4,6,0),
	    Color = Color3.fromRGB(255, 170, 0),
	    FaceCamera = false,
	    Names = true,
	    TeamColor = true,
	    Thickness = 2,
	    AttachShift = 1,
	    TeamMates = true,
	    Players = true,
	    
	    Objects = setmetatable({}, {__mode="kv"}),
	    Overrides = {}
	}

	--Declarations--
	local cam = workspace.CurrentCamera
	local plrs = game:GetService("Players")
	local plr = plrs.LocalPlayer
	local mouse = plr:GetMouse()

	local V3new = Vector3.new
	local WorldToViewportPoint = cam.WorldToViewportPoint

	--Functions--
	local function Draw(obj, props)
		local new = Drawing.new(obj)
		
		props = props or {}
		for i,v in pairs(props) do
			new[i] = v
		end
		return new
	end

	function ESP:GetTeam(p)
		local ov = self.Overrides.GetTeam
		if ov then
			return ov(p)
		end
		
		return p and p.Team
	end

	function ESP:IsTeamMate(p)
	    local ov = self.Overrides.IsTeamMate
		if ov then
			return ov(p)
	    end
	    
	    return self:GetTeam(p) == self:GetTeam(plr)
	end

	function ESP:GetColor(obj)
		local ov = self.Overrides.GetColor
		if ov then
			return ov(obj)
	    end
	    local p = self:GetPlrFromChar(obj)
		return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
	end

	function ESP:GetPlrFromChar(char)
		local ov = self.Overrides.GetPlrFromChar
		if ov then
			return ov(char)
		end
		
		return plrs:GetPlayerFromCharacter(char)
	end

	function ESP:Toggle(bool)
	    self.Enabled = bool
	    if not bool then
	        for i,v in pairs(self.Objects) do
	            if v.Type == "Box" then --fov circle etc
	                if v.Temporary then
	                    v:Remove()
	                else
	                    for i,v in pairs(v.Components) do
	                        v.Visible = false
	                    end
	                end
	            end
	        end
	    end
	end

	function ESP:GetBox(obj)
	    return self.Objects[obj]
	end

	function ESP:AddObjectListener(parent, options)
	    local function NewListener(c)
	        if type(options.Type) == "string" and c:IsA(options.Type) or options.Type == nil then
	            if type(options.Name) == "string" and c.Name == options.Name or options.Name == nil then
	                if not options.Validator or options.Validator(c) then
	                    local box = ESP:Add(c, {
	                        PrimaryPart = type(options.PrimaryPart) == "string" and c:WaitForChild(options.PrimaryPart) or type(options.PrimaryPart) == "function" and options.PrimaryPart(c),
	                        Color = type(options.Color) == "function" and options.Color(c) or options.Color,
	                        ColorDynamic = options.ColorDynamic,
	                        Name = type(options.CustomName) == "function" and options.CustomName(c) or options.CustomName,
	                        IsEnabled = options.IsEnabled,
	                        RenderInNil = options.RenderInNil
	                    })
	                    --TODO: add a better way of passing options
	                    if options.OnAdded then
	                        coroutine.wrap(options.OnAdded)(box)
	                    end
	                end
	            end
	        end
	    end

	    if options.Recursive then
	        parent.DescendantAdded:Connect(NewListener)
	        for i,v in pairs(parent:GetDescendants()) do
	            coroutine.wrap(NewListener)(v)
	        end
	    else
	        parent.ChildAdded:Connect(NewListener)
	        for i,v in pairs(parent:GetChildren()) do
	            coroutine.wrap(NewListener)(v)
	        end
	    end
	end

	local boxBase = {}
	boxBase.__index = boxBase

	function boxBase:Remove()
	    ESP.Objects[self.Object] = nil
	    for i,v in pairs(self.Components) do
	        v.Visible = false
	        v:Remove()
	        self.Components[i] = nil
	    end
	end

	function boxBase:Update()
	    if not self.PrimaryPart then
	        --warn("not supposed to print", self.Object)
	        return self:Remove()
	    end

	    local color
	    if ESP.Highlighted == self.Object then
	       color = ESP.HighlightColor
	    else
	        color = self.Color or self.ColorDynamic and self:ColorDynamic() or ESP:GetColor(self.Object) or ESP.Color
	    end

	    local allow = true
	    if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then
	        allow = false
	    end
	    if self.Player and not ESP.TeamMates and ESP:IsTeamMate(self.Player) then
	        allow = false
	    end
	    if self.Player and not ESP.Players then
	        allow = false
	    end
	    if self.IsEnabled and (type(self.IsEnabled) == "string" and not ESP[self.IsEnabled] or type(self.IsEnabled) == "function" and not self:IsEnabled()) then
	        allow = false
	    end
	    if not workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then
	        allow = false
	    end

	    if not allow then
	        for i,v in pairs(self.Components) do
	            v.Visible = false
	        end
	        return
	    end

	    if ESP.Highlighted == self.Object then
	        color = ESP.HighlightColor
	    end

	    --calculations--
	    local cf = self.PrimaryPart.CFrame
	    if ESP.FaceCamera then
	        cf = CFrame.new(cf.p, cam.CFrame.p)
	    end
	    local size = self.Size
	    local locs = {
	        TopLeft = cf * ESP.BoxShift * CFrame.new(size.X/2,size.Y/2,0),
	        TopRight = cf * ESP.BoxShift * CFrame.new(-size.X/2,size.Y/2,0),
	        BottomLeft = cf * ESP.BoxShift * CFrame.new(size.X/2,-size.Y/2,0),
	        BottomRight = cf * ESP.BoxShift * CFrame.new(-size.X/2,-size.Y/2,0),
	        TagPos = cf * ESP.BoxShift * CFrame.new(0,size.Y/2,0),
	        Torso = cf * ESP.BoxShift
	    }

	    if ESP.Boxes then
	        local TopLeft, Vis1 = WorldToViewportPoint(cam, locs.TopLeft.p)
	        local TopRight, Vis2 = WorldToViewportPoint(cam, locs.TopRight.p)
	        local BottomLeft, Vis3 = WorldToViewportPoint(cam, locs.BottomLeft.p)
	        local BottomRight, Vis4 = WorldToViewportPoint(cam, locs.BottomRight.p)

	        if self.Components.Quad then
	            if Vis1 or Vis2 or Vis3 or Vis4 then
	                self.Components.Quad.Visible = true
	                self.Components.Quad.PointA = Vector2.new(TopRight.X, TopRight.Y)
	                self.Components.Quad.PointB = Vector2.new(TopLeft.X, TopLeft.Y)
	                self.Components.Quad.PointC = Vector2.new(BottomLeft.X, BottomLeft.Y)
	                self.Components.Quad.PointD = Vector2.new(BottomRight.X, BottomRight.Y)
	                self.Components.Quad.Color = color
	            else
	                self.Components.Quad.Visible = false
	            end
	        end
	    else
	        self.Components.Quad.Visible = false
	    end

	    if ESP.Names then
	        local TagPos, Vis5 = WorldToViewportPoint(cam, locs.TagPos.p)
	        
	        if Vis5 then
	            self.Components.Name.Visible = true
	            self.Components.Name.Position = Vector2.new(TagPos.X, TagPos.Y)
	            self.Components.Name.Text = self.Name
	            self.Components.Name.Color = color
	            
	            self.Components.Data.Visible = true
	            self.Components.Data.Position = Vector2.new(TagPos.X, TagPos.Y + 14)
	            self.Components.Data.Text = self.Data or ""
	            self.Components.Data.Color = color
	            
	            self.Components.Distance.Visible = true
	            self.Components.Distance.Position = Vector2.new(TagPos.X, TagPos.Y + 30)
	            self.Components.Distance.Text = math.floor((cam.CFrame.p - cf.p).magnitude) .."m"
	            self.Components.Distance.Color = color
	        else
	            self.Components.Name.Visible = false
	            self.Components.Distance.Visible = false
	            self.Components.Data.Visible = false
	        end
	    else
	        self.Components.Name.Visible = false
	        self.Components.Distance.Visible = false
	        self.Components.Data.Visible = false
	    end
	    
	    if ESP.Tracers then
	        local TorsoPos, Vis6 = WorldToViewportPoint(cam, locs.Torso.p)

	        if Vis6 then
	            self.Components.Tracer.Visible = true
	            self.Components.Tracer.From = Vector2.new(TorsoPos.X, TorsoPos.Y)
	            self.Components.Tracer.To = Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/ESP.AttachShift)
	            self.Components.Tracer.Color = color
	        else
	            self.Components.Tracer.Visible = false
	        end
	    else
	        self.Components.Tracer.Visible = false
	    end
	end

	function ESP:Add(obj, options)
	    if not obj.Parent and not options.RenderInNil then
	        return warn(obj, "has no parent")
	    end

	    local box = setmetatable({
	        Name = options.Name or obj.Name,
	        Data = options.Data,
	        Type = "Box",
	        Color = options.Color --[[or self:GetColor(obj)]],
	        Size = options.Size or self.BoxSize,
	        Object = obj,
	        Player = options.Player or plrs:GetPlayerFromCharacter(obj),
	        PrimaryPart = options.PrimaryPart or obj.ClassName == "Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj,
	        Components = {},
	        IsEnabled = options.IsEnabled,
	        Temporary = options.Temporary,
	        ColorDynamic = options.ColorDynamic,
	        RenderInNil = options.RenderInNil
	    }, boxBase)

	    if self:GetBox(obj) then
	        self:GetBox(obj):Remove()
	    end

	    box.Components["Quad"] = Draw("Quad", {
	        Thickness = self.Thickness,
	        Color = color,
	        Transparency = 1,
	        Filled = false,
	        Visible = self.Enabled and self.Boxes
	    })
	    box.Components["Name"] = Draw("Text", {
			Text = box.Name,
			Color = box.Color,
			Center = true,
			Outline = true,
	        Size = 19,
	        Visible = self.Enabled and self.Names
		})

	    box.Components["Data"] = Draw("Text", {
			Text = options.Data or "",
			Color = box.Color,
			Center = true,
			Outline = true,
	        Size = 19,
	        Visible = self.Enabled
		})

		box.Components["Distance"] = Draw("Text", {
			Color = box.Color,
			Center = true,
			Outline = true,
	        Size = 19,
	        Visible = self.Enabled and self.Names
		})
		
		box.Components["Tracer"] = Draw("Line", {
			Thickness = ESP.Thickness,
			Color = box.Color,
	        Transparency = 1,
	        Visible = self.Enabled and self.Tracers
	    })
	    self.Objects[obj] = box
	    
	    ODYSSEY.Maid:GiveTask(obj:GetPropertyChangedSignal("Parent"):Connect(function()
	        if obj.Parent == nil and ESP.AutoRemove ~= false then
	            box:Remove()
	        end
	    end))

	    return box
	end

	ODYSSEY.Maid:GiveTask(game:GetService("RunService").RenderStepped:Connect(function()
	    cam = workspace.CurrentCamera
	    for i,v in (ESP.Enabled and pairs or ipairs)(ESP.Objects) do
	        if v.Update then
	            pcall(v.Update, v)
	        end
	    end
	end))

	return ESP
	
end
luacompactModules["src/lib/json.lua"] = function()
	-- Module options:
	local always_use_lpeg = false
	local register_global_module_table = false
	local global_module_name = 'json'

	--[==[

	David Kolf's JSON module for Lua 5.1 - 5.4

	Version 2.6


	For the documentation see the corresponding readme.txt or visit
	<http://dkolf.de/src/dkjson-lua.fsl/>.

	You can contact the author by sending an e-mail to 'david' at the
	domain 'dkolf.de'.


	Copyright (C) 2010-2021 David Heiko Kolf

	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
	BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
	ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

	--]==]

	-- global dependencies:
	local pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset =
	      pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset
	local error, require, pcall, select = error, require, pcall, select
	local floor, huge = math.floor, math.huge
	local strrep, gsub, strsub, strbyte, strchar, strfind, strlen, strformat =
	      string.rep, string.gsub, string.sub, string.byte, string.char,
	      string.find, string.len, string.format
	local strmatch = string.match
	local concat = table.concat

	local json = { version = "dkjson 2.6" }

	local jsonlpeg = {}

	if register_global_module_table then
	  if always_use_lpeg then
	    _G[global_module_name] = jsonlpeg
	  else
	    _G[global_module_name] = json
	  end
	end

	local _ENV = nil -- blocking globals in Lua 5.2 and later

	pcall (function()
	  -- Enable access to blocked metatables.
	  -- Don't worry, this module doesn't change anything in them.
	  local debmeta = require "debug".getmetatable
	  if debmeta then getmetatable = debmeta end
	end)

	json.null = setmetatable ({}, {
	  __tojson = function () return "null" end
	})

	local function isarray (tbl)
	  local max, n, arraylen = 0, 0, 0
	  for k,v in pairs (tbl) do
	    if k == 'n' and type(v) == 'number' then
	      arraylen = v
	      if v > max then
	        max = v
	      end
	    else
	      if type(k) ~= 'number' or k < 1 or floor(k) ~= k then
	        return false
	      end
	      if k > max then
	        max = k
	      end
	      n = n + 1
	    end
	  end
	  if max > 10 and max > arraylen and max > n * 2 then
	    return false -- don't create an array with too many holes
	  end
	  return true, max
	end

	local escapecodes = {
	  ["\""] = "\\\"", ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
	  ["\n"] = "\\n",  ["\r"] = "\\r",  ["\t"] = "\\t"
	}

	local function escapeutf8 (uchar)
	  local value = escapecodes[uchar]
	  if value then
	    return value
	  end
	  local a, b, c, d = strbyte (uchar, 1, 4)
	  a, b, c, d = a or 0, b or 0, c or 0, d or 0
	  if a <= 0x7f then
	    value = a
	  elseif 0xc0 <= a and a <= 0xdf and b >= 0x80 then
	    value = (a - 0xc0) * 0x40 + b - 0x80
	  elseif 0xe0 <= a and a <= 0xef and b >= 0x80 and c >= 0x80 then
	    value = ((a - 0xe0) * 0x40 + b - 0x80) * 0x40 + c - 0x80
	  elseif 0xf0 <= a and a <= 0xf7 and b >= 0x80 and c >= 0x80 and d >= 0x80 then
	    value = (((a - 0xf0) * 0x40 + b - 0x80) * 0x40 + c - 0x80) * 0x40 + d - 0x80
	  else
	    return ""
	  end
	  if value <= 0xffff then
	    return strformat ("\\u%.4x", value)
	  elseif value <= 0x10ffff then
	    -- encode as UTF-16 surrogate pair
	    value = value - 0x10000
	    local highsur, lowsur = 0xD800 + floor (value/0x400), 0xDC00 + (value % 0x400)
	    return strformat ("\\u%.4x\\u%.4x", highsur, lowsur)
	  else
	    return ""
	  end
	end

	local function fsub (str, pattern, repl)
	  -- gsub always builds a new string in a buffer, even when no match
	  -- exists. First using find should be more efficient when most strings
	  -- don't contain the pattern.
	  if strfind (str, pattern) then
	    return gsub (str, pattern, repl)
	  else
	    return str
	  end
	end

	local function quotestring (value)
	  -- based on the regexp "escapable" in https://github.com/douglascrockford/JSON-js
	  value = fsub (value, "[%z\1-\31\"\\\127]", escapeutf8)
	  if strfind (value, "[\194\216\220\225\226\239]") then
	    value = fsub (value, "\194[\128-\159\173]", escapeutf8)
	    value = fsub (value, "\216[\128-\132]", escapeutf8)
	    value = fsub (value, "\220\143", escapeutf8)
	    value = fsub (value, "\225\158[\180\181]", escapeutf8)
	    value = fsub (value, "\226\128[\140-\143\168-\175]", escapeutf8)
	    value = fsub (value, "\226\129[\160-\175]", escapeutf8)
	    value = fsub (value, "\239\187\191", escapeutf8)
	    value = fsub (value, "\239\191[\176-\191]", escapeutf8)
	  end
	  return "\"" .. value .. "\""
	end
	json.quotestring = quotestring

	local function replace(str, o, n)
	  local i, j = strfind (str, o, 1, true)
	  if i then
	    return strsub(str, 1, i-1) .. n .. strsub(str, j+1, -1)
	  else
	    return str
	  end
	end

	-- locale independent num2str and str2num functions
	local decpoint, numfilter

	local function updatedecpoint ()
	  decpoint = strmatch(tostring(0.5), "([^05+])")
	  -- build a filter that can be used to remove group separators
	  numfilter = "[^0-9%-%+eE" .. gsub(decpoint, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "]+"
	end

	updatedecpoint()

	local function num2str (num)
	  return replace(fsub(tostring(num), numfilter, ""), decpoint, ".")
	end

	local function str2num (str)
	  local num = tonumber(replace(str, ".", decpoint))
	  if not num then
	    updatedecpoint()
	    num = tonumber(replace(str, ".", decpoint))
	  end
	  return num
	end

	local function addnewline2 (level, buffer, buflen)
	  buffer[buflen+1] = "\n"
	  buffer[buflen+2] = strrep ("  ", level)
	  buflen = buflen + 2
	  return buflen
	end

	function json.addnewline (state)
	  if state.indent then
	    state.bufferlen = addnewline2 (state.level or 0,
	                           state.buffer, state.bufferlen or #(state.buffer))
	  end
	end

	local encode2 -- forward declaration

	local function addpair (key, value, prev, indent, level, buffer, buflen, tables, globalorder, state)
	  local kt = type (key)
	  if kt ~= 'string' and kt ~= 'number' then
	    return nil, "type '" .. kt .. "' is not supported as a key by JSON."
	  end
	  if prev then
	    buflen = buflen + 1
	    buffer[buflen] = ","
	  end
	  if indent then
	    buflen = addnewline2 (level, buffer, buflen)
	  end
	  buffer[buflen+1] = quotestring (key)
	  buffer[buflen+2] = ":"
	  return encode2 (value, indent, level, buffer, buflen + 2, tables, globalorder, state)
	end

	local function appendcustom(res, buffer, state)
	  local buflen = state.bufferlen
	  if type (res) == 'string' then
	    buflen = buflen + 1
	    buffer[buflen] = res
	  end
	  return buflen
	end

	local function exception(reason, value, state, buffer, buflen, defaultmessage)
	  defaultmessage = defaultmessage or reason
	  local handler = state.exception
	  if not handler then
	    return nil, defaultmessage
	  else
	    state.bufferlen = buflen
	    local ret, msg = handler (reason, value, state, defaultmessage)
	    if not ret then return nil, msg or defaultmessage end
	    return appendcustom(ret, buffer, state)
	  end
	end

	function json.encodeexception(reason, value, state, defaultmessage)
	  return quotestring("<" .. defaultmessage .. ">")
	end

	encode2 = function (value, indent, level, buffer, buflen, tables, globalorder, state)
	  local valtype = type (value)
	  local valmeta = getmetatable (value)
	  valmeta = type (valmeta) == 'table' and valmeta -- only tables
	  local valtojson = valmeta and valmeta.__tojson
	  if valtojson then
	    if tables[value] then
	      return exception('reference cycle', value, state, buffer, buflen)
	    end
	    tables[value] = true
	    state.bufferlen = buflen
	    local ret, msg = valtojson (value, state)
	    if not ret then return exception('custom encoder failed', value, state, buffer, buflen, msg) end
	    tables[value] = nil
	    buflen = appendcustom(ret, buffer, state)
	  elseif value == nil then
	    buflen = buflen + 1
	    buffer[buflen] = "null"
	  elseif valtype == 'number' then
	    local s
	    if value ~= value or value >= huge or -value >= huge then
	      -- This is the behaviour of the original JSON implementation.
	      s = "null"
	    else
	      s = num2str (value)
	    end
	    buflen = buflen + 1
	    buffer[buflen] = s
	  elseif valtype == 'boolean' then
	    buflen = buflen + 1
	    buffer[buflen] = value and "true" or "false"
	  elseif valtype == 'string' then
	    buflen = buflen + 1
	    buffer[buflen] = quotestring (value)
	  elseif valtype == 'table' then
	    if tables[value] then
	      return exception('reference cycle', value, state, buffer, buflen)
	    end
	    tables[value] = true
	    level = level + 1
	    local isa, n = isarray (value)
	    if n == 0 and valmeta and valmeta.__jsontype == 'object' then
	      isa = false
	    end
	    local msg
	    if isa then -- JSON array
	      buflen = buflen + 1
	      buffer[buflen] = "["
	      for i = 1, n do
	        buflen, msg = encode2 (value[i], indent, level, buffer, buflen, tables, globalorder, state)
	        if not buflen then return nil, msg end
	        if i < n then
	          buflen = buflen + 1
	          buffer[buflen] = ","
	        end
	      end
	      buflen = buflen + 1
	      buffer[buflen] = "]"
	    else -- JSON object
	      local prev = false
	      buflen = buflen + 1
	      buffer[buflen] = "{"
	      local order = valmeta and valmeta.__jsonorder or globalorder
	      if order then
	        local used = {}
	        n = #order
	        for i = 1, n do
	          local k = order[i]
	          local v = value[k]
	          if v ~= nil then
	            used[k] = true
	            buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
	            prev = true -- add a seperator before the next element
	          end
	        end
	        for k,v in pairs (value) do
	          if not used[k] then
	            buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
	            if not buflen then return nil, msg end
	            prev = true -- add a seperator before the next element
	          end
	        end
	      else -- unordered
	        for k,v in pairs (value) do
	          buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
	          if not buflen then return nil, msg end
	          prev = true -- add a seperator before the next element
	        end
	      end
	      if indent then
	        buflen = addnewline2 (level - 1, buffer, buflen)
	      end
	      buflen = buflen + 1
	      buffer[buflen] = "}"
	    end
	    tables[value] = nil
	  else
	    return exception ('unsupported type', value, state, buffer, buflen,
	      "type '" .. valtype .. "' is not supported by JSON.")
	  end
	  return buflen
	end

	function json.encode (value, state)
	  state = state or {}
	  local oldbuffer = state.buffer
	  local buffer = oldbuffer or {}
	  state.buffer = buffer
	  updatedecpoint()
	  local ret, msg = encode2 (value, state.indent, state.level or 0,
	                   buffer, state.bufferlen or 0, state.tables or {}, state.keyorder, state)
	  if not ret then
	    error (msg, 2)
	  elseif oldbuffer == buffer then
	    state.bufferlen = ret
	    return true
	  else
	    state.bufferlen = nil
	    state.buffer = nil
	    return concat (buffer)
	  end
	end

	local function loc (str, where)
	  local line, pos, linepos = 1, 1, 0
	  while true do
	    pos = strfind (str, "\n", pos, true)
	    if pos and pos < where then
	      line = line + 1
	      linepos = pos
	      pos = pos + 1
	    else
	      break
	    end
	  end
	  return "line " .. line .. ", column " .. (where - linepos)
	end

	local function unterminated (str, what, where)
	  return nil, strlen (str) + 1, "unterminated " .. what .. " at " .. loc (str, where)
	end

	local function scanwhite (str, pos)
	  while true do
	    pos = strfind (str, "%S", pos)
	    if not pos then return nil end
	    local sub2 = strsub (str, pos, pos + 1)
	    if sub2 == "\239\187" and strsub (str, pos + 2, pos + 2) == "\191" then
	      -- UTF-8 Byte Order Mark
	      pos = pos + 3
	    elseif sub2 == "//" then
	      pos = strfind (str, "[\n\r]", pos + 2)
	      if not pos then return nil end
	    elseif sub2 == "/*" then
	      pos = strfind (str, "*/", pos + 2)
	      if not pos then return nil end
	      pos = pos + 2
	    else
	      return pos
	    end
	  end
	end

	local escapechars = {
	  ["\""] = "\"", ["\\"] = "\\", ["/"] = "/", ["b"] = "\b", ["f"] = "\f",
	  ["n"] = "\n", ["r"] = "\r", ["t"] = "\t"
	}

	local function unichar (value)
	  if value < 0 then
	    return nil
	  elseif value <= 0x007f then
	    return strchar (value)
	  elseif value <= 0x07ff then
	    return strchar (0xc0 + floor(value/0x40),
	                    0x80 + (floor(value) % 0x40))
	  elseif value <= 0xffff then
	    return strchar (0xe0 + floor(value/0x1000),
	                    0x80 + (floor(value/0x40) % 0x40),
	                    0x80 + (floor(value) % 0x40))
	  elseif value <= 0x10ffff then
	    return strchar (0xf0 + floor(value/0x40000),
	                    0x80 + (floor(value/0x1000) % 0x40),
	                    0x80 + (floor(value/0x40) % 0x40),
	                    0x80 + (floor(value) % 0x40))
	  else
	    return nil
	  end
	end

	local function scanstring (str, pos)
	  local lastpos = pos + 1
	  local buffer, n = {}, 0
	  while true do
	    local nextpos = strfind (str, "[\"\\]", lastpos)
	    if not nextpos then
	      return unterminated (str, "string", pos)
	    end
	    if nextpos > lastpos then
	      n = n + 1
	      buffer[n] = strsub (str, lastpos, nextpos - 1)
	    end
	    if strsub (str, nextpos, nextpos) == "\"" then
	      lastpos = nextpos + 1
	      break
	    else
	      local escchar = strsub (str, nextpos + 1, nextpos + 1)
	      local value
	      if escchar == "u" then
	        value = tonumber (strsub (str, nextpos + 2, nextpos + 5), 16)
	        if value then
	          local value2
	          if 0xD800 <= value and value <= 0xDBff then
	            -- we have the high surrogate of UTF-16. Check if there is a
	            -- low surrogate escaped nearby to combine them.
	            if strsub (str, nextpos + 6, nextpos + 7) == "\\u" then
	              value2 = tonumber (strsub (str, nextpos + 8, nextpos + 11), 16)
	              if value2 and 0xDC00 <= value2 and value2 <= 0xDFFF then
	                value = (value - 0xD800)  * 0x400 + (value2 - 0xDC00) + 0x10000
	              else
	                value2 = nil -- in case it was out of range for a low surrogate
	              end
	            end
	          end
	          value = value and unichar (value)
	          if value then
	            if value2 then
	              lastpos = nextpos + 12
	            else
	              lastpos = nextpos + 6
	            end
	          end
	        end
	      end
	      if not value then
	        value = escapechars[escchar] or escchar
	        lastpos = nextpos + 2
	      end
	      n = n + 1
	      buffer[n] = value
	    end
	  end
	  if n == 1 then
	    return buffer[1], lastpos
	  elseif n > 1 then
	    return concat (buffer), lastpos
	  else
	    return "", lastpos
	  end
	end

	local scanvalue -- forward declaration

	local function scantable (what, closechar, str, startpos, nullval, objectmeta, arraymeta)
	  local len = strlen (str)
	  local tbl, n = {}, 0
	  local pos = startpos + 1
	  if what == 'object' then
	    setmetatable (tbl, objectmeta)
	  else
	    setmetatable (tbl, arraymeta)
	  end
	  while true do
	    pos = scanwhite (str, pos)
	    if not pos then return unterminated (str, what, startpos) end
	    local char = strsub (str, pos, pos)
	    if char == closechar then
	      return tbl, pos + 1
	    end
	    local val1, err
	    val1, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
	    if err then return nil, pos, err end
	    pos = scanwhite (str, pos)
	    if not pos then return unterminated (str, what, startpos) end
	    char = strsub (str, pos, pos)
	    if char == ":" then
	      if val1 == nil then
	        return nil, pos, "cannot use nil as table index (at " .. loc (str, pos) .. ")"
	      end
	      pos = scanwhite (str, pos + 1)
	      if not pos then return unterminated (str, what, startpos) end
	      local val2
	      val2, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
	      if err then return nil, pos, err end
	      tbl[val1] = val2
	      pos = scanwhite (str, pos)
	      if not pos then return unterminated (str, what, startpos) end
	      char = strsub (str, pos, pos)
	    else
	      n = n + 1
	      tbl[n] = val1
	    end
	    if char == "," then
	      pos = pos + 1
	    end
	  end
	end

	scanvalue = function (str, pos, nullval, objectmeta, arraymeta)
	  pos = pos or 1
	  pos = scanwhite (str, pos)
	  if not pos then
	    return nil, strlen (str) + 1, "no valid JSON value (reached the end)"
	  end
	  local char = strsub (str, pos, pos)
	  if char == "{" then
	    return scantable ('object', "}", str, pos, nullval, objectmeta, arraymeta)
	  elseif char == "[" then
	    return scantable ('array', "]", str, pos, nullval, objectmeta, arraymeta)
	  elseif char == "\"" then
	    return scanstring (str, pos)
	  else
	    local pstart, pend = strfind (str, "^%-?[%d%.]+[eE]?[%+%-]?%d*", pos)
	    if pstart then
	      local number = str2num (strsub (str, pstart, pend))
	      if number then
	        return number, pend + 1
	      end
	    end
	    pstart, pend = strfind (str, "^%a%w*", pos)
	    if pstart then
	      local name = strsub (str, pstart, pend)
	      if name == "true" then
	        return true, pend + 1
	      elseif name == "false" then
	        return false, pend + 1
	      elseif name == "null" then
	        return nullval, pend + 1
	      end
	    end
	    return nil, pos, "no valid JSON value at " .. loc (str, pos)
	  end
	end

	local function optionalmetatables(...)
	  if select("#", ...) > 0 then
	    return ...
	  else
	    return {__jsontype = 'object'}, {__jsontype = 'array'}
	  end
	end

	function json.decode (str, pos, nullval, ...)
	  local objectmeta, arraymeta = optionalmetatables(...)
	  return scanvalue (str, pos, nullval, objectmeta, arraymeta)
	end

	function json.use_lpeg ()
	  local g = require ("lpeg")

	  if g.version() == "0.11" then
	    error "due to a bug in LPeg 0.11, it cannot be used for JSON matching"
	  end

	  local pegmatch = g.match
	  local P, S, R = g.P, g.S, g.R

	  local function ErrorCall (str, pos, msg, state)
	    if not state.msg then
	      state.msg = msg .. " at " .. loc (str, pos)
	      state.pos = pos
	    end
	    return false
	  end

	  local function Err (msg)
	    return g.Cmt (g.Cc (msg) * g.Carg (2), ErrorCall)
	  end

	  local function ErrorUnterminatedCall (str, pos, what, state)
	    return ErrorCall (str, pos - 1, "unterminated " .. what, state)
	  end

	  local SingleLineComment = P"//" * (1 - S"\n\r")^0
	  local MultiLineComment = P"/*" * (1 - P"*/")^0 * P"*/"
	  local Space = (S" \n\r\t" + P"\239\187\191" + SingleLineComment + MultiLineComment)^0

	  local function ErrUnterminated (what)
	    return g.Cmt (g.Cc (what) * g.Carg (2), ErrorUnterminatedCall)
	  end

	  local PlainChar = 1 - S"\"\\\n\r"
	  local EscapeSequence = (P"\\" * g.C (S"\"\\/bfnrt" + Err "unsupported escape sequence")) / escapechars
	  local HexDigit = R("09", "af", "AF")
	  local function UTF16Surrogate (match, pos, high, low)
	    high, low = tonumber (high, 16), tonumber (low, 16)
	    if 0xD800 <= high and high <= 0xDBff and 0xDC00 <= low and low <= 0xDFFF then
	      return true, unichar ((high - 0xD800)  * 0x400 + (low - 0xDC00) + 0x10000)
	    else
	      return false
	    end
	  end
	  local function UTF16BMP (hex)
	    return unichar (tonumber (hex, 16))
	  end
	  local U16Sequence = (P"\\u" * g.C (HexDigit * HexDigit * HexDigit * HexDigit))
	  local UnicodeEscape = g.Cmt (U16Sequence * U16Sequence, UTF16Surrogate) + U16Sequence/UTF16BMP
	  local Char = UnicodeEscape + EscapeSequence + PlainChar
	  local String = P"\"" * (g.Cs (Char ^ 0) * P"\"" + ErrUnterminated "string")
	  local Integer = P"-"^(-1) * (P"0" + (R"19" * R"09"^0))
	  local Fractal = P"." * R"09"^0
	  local Exponent = (S"eE") * (S"+-")^(-1) * R"09"^1
	  local Number = (Integer * Fractal^(-1) * Exponent^(-1))/str2num
	  local Constant = P"true" * g.Cc (true) + P"false" * g.Cc (false) + P"null" * g.Carg (1)
	  local SimpleValue = Number + String + Constant
	  local ArrayContent, ObjectContent

	  -- The functions parsearray and parseobject parse only a single value/pair
	  -- at a time and store them directly to avoid hitting the LPeg limits.
	  local function parsearray (str, pos, nullval, state)
	    local obj, cont
	    local start = pos
	    local npos
	    local t, nt = {}, 0
	    repeat
	      obj, cont, npos = pegmatch (ArrayContent, str, pos, nullval, state)
	      if cont == 'end' then
	        return ErrorUnterminatedCall (str, start, "array", state)
	      end
	      pos = npos
	      if cont == 'cont' or cont == 'last' then
	        nt = nt + 1
	        t[nt] = obj
	      end
	    until cont ~= 'cont'
	    return pos, setmetatable (t, state.arraymeta)
	  end

	  local function parseobject (str, pos, nullval, state)
	    local obj, key, cont
	    local start = pos
	    local npos
	    local t = {}
	    repeat
	      key, obj, cont, npos = pegmatch (ObjectContent, str, pos, nullval, state)
	      if cont == 'end' then
	        return ErrorUnterminatedCall (str, start, "object", state)
	      end
	      pos = npos
	      if cont == 'cont' or cont == 'last' then
	        t[key] = obj
	      end
	    until cont ~= 'cont'
	    return pos, setmetatable (t, state.objectmeta)
	  end

	  local Array = P"[" * g.Cmt (g.Carg(1) * g.Carg(2), parsearray)
	  local Object = P"{" * g.Cmt (g.Carg(1) * g.Carg(2), parseobject)
	  local Value = Space * (Array + Object + SimpleValue)
	  local ExpectedValue = Value + Space * Err "value expected"
	  local ExpectedKey = String + Err "key expected"
	  local End = P(-1) * g.Cc'end'
	  local ErrInvalid = Err "invalid JSON"
	  ArrayContent = (Value * Space * (P"," * g.Cc'cont' + P"]" * g.Cc'last'+ End + ErrInvalid)  + g.Cc(nil) * (P"]" * g.Cc'empty' + End  + ErrInvalid)) * g.Cp()
	  local Pair = g.Cg (Space * ExpectedKey * Space * (P":" + Err "colon expected") * ExpectedValue)
	  ObjectContent = (g.Cc(nil) * g.Cc(nil) * P"}" * g.Cc'empty' + End + (Pair * Space * (P"," * g.Cc'cont' + P"}" * g.Cc'last' + End + ErrInvalid) + ErrInvalid)) * g.Cp()
	  local DecodeValue = ExpectedValue * g.Cp ()

	  jsonlpeg.version = json.version
	  jsonlpeg.encode = json.encode
	  jsonlpeg.null = json.null
	  jsonlpeg.quotestring = json.quotestring
	  jsonlpeg.addnewline = json.addnewline
	  jsonlpeg.encodeexception = json.encodeexception
	  jsonlpeg.using_lpeg = true

	  function jsonlpeg.decode (str, pos, nullval, ...)
	    local state = {}
	    state.objectmeta, state.arraymeta = optionalmetatables(...)
	    local obj, retpos = pegmatch (DecodeValue, str, pos, nullval, state)
	    if state.msg then
	      return nil, state.pos, state.msg
	    else
	      return obj, retpos
	    end
	  end

	  -- cache result of this function:
	  json.use_lpeg = function () return jsonlpeg end
	  jsonlpeg.use_lpeg = json.use_lpeg

	  return jsonlpeg
	end

	if always_use_lpeg then
	  return json.use_lpeg()
	end

	return json

	
end
luacompactModules["src/lib/Maid.lua"] = function()
	--[=[
		Manages the cleaning of events and other things. Useful for
		encapsulating state and make deconstructors easy.

		See the [Five Powerful Code Patterns talk](https://developer.roblox.com/en-us/videos/5-powerful-code-patterns-behind-top-roblox-games)
		for a more in-depth look at Maids in top games.

		```lua
		local maid = Maid.new()

		maid:GiveTask(function()
			print("Cleaning up")
		end)

		maid:GiveTask(workspace.ChildAdded:Connect(print))

		-- Disconnects all events, and executes all functions
		maid:DoCleaning()
		```

		@class Maid
	]=]
	-- luacheck: pop

	local Maid = {}
	Maid.ClassName = "Maid"

	--[=[
		Constructs a new Maid object

		```lua
		local maid = Maid.new()
		```

		@return Maid
	]=]
	function Maid.new()
		return setmetatable({
			_tasks = {},
		}, Maid)
	end

	--[=[
		Returns true if the class is a maid, and false otherwise.

		```lua
		print(Maid.isMaid(Maid.new())) --> true
		print(Maid.isMaid(nil)) --> false
		```

		@param value any
		@return boolean
	]=]
	function Maid.isMaid(value)
		return type(value) == "table" and value.ClassName == "Maid"
	end

	--[=[
		Returns Maid[key] if not part of Maid metatable

		```lua
		local maid = Maid.new()
		maid._current = Instance.new("Part")
		print(maid._current) --> Part

		maid._current = nil
		print(maid._current) --> nil
		```

		@param index any
		@return MaidTask
	]=]
	function Maid:__index(index)
		if Maid[index] then
			return Maid[index]
		else
			return self._tasks[index]
		end
	end

	--[=[
		Add a task to clean up. Tasks given to a maid will be cleaned when
		maid[index] is set to a different value.

		Task cleanup is such that if the task is an event, it is disconnected.
		If it is an object, it is destroyed.

		```
		Maid[key] = (function)         Adds a task to perform
		Maid[key] = (event connection) Manages an event connection
		Maid[key] = (thread)           Manages a thread
		Maid[key] = (Maid)             Maids can act as an event connection, allowing a Maid to have other maids to clean up.
		Maid[key] = (Object)           Maids can cleanup objects with a `Destroy` method
		Maid[key] = nil                Removes a named task.
		```

		@param index any
		@param newTask MaidTask
	]=]
	function Maid:__newindex(index, newTask)
		if Maid[index] ~= nil then
			error(("Cannot use '%s' as a Maid key"):format(tostring(index)), 2)
		end

		local tasks = self._tasks
		local oldTask = tasks[index]

		if oldTask == newTask then
			return
		end

		tasks[index] = newTask

		if oldTask then
			if type(oldTask) == "function" then
				oldTask()
			elseif type(oldTask) == "thread" then
				task.cancel(oldTask)
			elseif typeof(oldTask) == "RBXScriptConnection" then
				oldTask:Disconnect()
			elseif oldTask.Destroy then
				oldTask:Destroy()
			end
		end
	end

	--[=[
		Gives a task to the maid for cleanup, but uses an incremented number as a key.

		@param task MaidTask -- An item to clean
		@return number -- taskId
	]=]
	function Maid:GiveTask(task)
		if not task then
			error("Task cannot be false or nil", 2)
		end

		local taskId = #self._tasks + 1
		self[taskId] = task

		if type(task) == "table" and not task.Destroy then
			warn("[Maid.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
		end

		return taskId
	end

	--[=[
		Gives a promise to the maid for clean.

		@param promise Promise<T>
		@return Promise<T>
	]=]
	function Maid:GivePromise(promise)
		if not promise:IsPending() then
			return promise
		end

		local newPromise = promise.resolved(promise)
		local id = self:GiveTask(newPromise)

		-- Ensure GC
		newPromise:Finally(function()
			self[id] = nil
		end)

		return newPromise
	end

	--[=[
		Cleans up all tasks and removes them as entries from the Maid.

		:::note
		Signals that are already connected are always disconnected first. After that
		any signals added during a cleaning phase will be disconnected at random times.
		:::

		:::tip
		DoCleaning() may be recursively invoked. This allows the you to ensure that
		tasks or other tasks. Each task will be executed once.

		However, adding tasks while cleaning is not generally a good idea, as if you add a
		function that adds itself, this will loop indefinitely.
		:::
	]=]
	function Maid:DoCleaning()
		local tasks = self._tasks

		-- Disconnect all events first as we know this is safe
		for index, job in pairs(tasks) do
			if typeof(job) == "RBXScriptConnection" then
				tasks[index] = nil
				job:Disconnect()
			end
		end

		-- Clear out tasks table completely, even if clean up tasks add more tasks to the maid
		local index, job = next(tasks)
		while job ~= nil do
			tasks[index] = nil
			if type(job) == "function" then
				job()
			elseif type(job) == "thread" then
				task.cancel(job)
			elseif typeof(job) == "RBXScriptConnection" then
				job:Disconnect()
			elseif job.Destroy then
				job:Destroy()
			end
			index, job = next(tasks)
		end
	end

	--[=[
		Alias for [Maid.DoCleaning()](/api/Maid#DoCleaning)

		@function Destroy
		@within Maid
	]=]
	Maid.Destroy = Maid.DoCleaning

	return Maid
	
end
luacompactModules["src/lib/Promise.lua"] = function()
	--[[
		An implementation of Promises similar to Promise/A+.
	]]

	local ERROR_NON_PROMISE_IN_LIST = "Non-promise value passed into %s at index %s"
	local ERROR_NON_LIST = "Please pass a list of promises to %s"
	local ERROR_NON_FUNCTION = "Please pass a handler function to %s!"
	local MODE_KEY_METATABLE = { __mode = "k" }

	local function isCallable(value)
		if type(value) == "function" then
			return true
		end

		if type(value) == "table" then
			local metatable = getmetatable(value)
			if metatable and type(rawget(metatable, "__call")) == "function" then
				return true
			end
		end

		return false
	end

	--[[
		Creates an enum dictionary with some metamethods to prevent common mistakes.
	]]
	local function makeEnum(enumName, members)
		local enum = {}

		for _, memberName in ipairs(members) do
			enum[memberName] = memberName
		end

		return setmetatable(enum, {
			__index = function(_, k)
				error(string.format("%s is not in %s!", k, enumName), 2)
			end,
			__newindex = function()
				error(string.format("Creating new members in %s is not allowed!", enumName), 2)
			end,
		})
	end

	--[=[
		An object to represent runtime errors that occur during execution.
		Promises that experience an error like this will be rejected with
		an instance of this object.

		@class Error
	]=]
	local Error
	do
		Error = {
			Kind = makeEnum("Promise.Error.Kind", {
				"ExecutionError",
				"AlreadyCancelled",
				"NotResolvedInTime",
				"TimedOut",
			}),
		}
		Error.__index = Error

		function Error.new(options, parent)
			options = options or {}
			return setmetatable({
				error = tostring(options.error) or "[This error has no error text.]",
				trace = options.trace,
				context = options.context,
				kind = options.kind,
				parent = parent,
				createdTick = os.clock(),
				createdTrace = debug.traceback(),
			}, Error)
		end

		function Error.is(anything)
			if type(anything) == "table" then
				local metatable = getmetatable(anything)

				if type(metatable) == "table" then
					return rawget(anything, "error") ~= nil and type(rawget(metatable, "extend")) == "function"
				end
			end

			return false
		end

		function Error.isKind(anything, kind)
			assert(kind ~= nil, "Argument #2 to Promise.Error.isKind must not be nil")

			return Error.is(anything) and anything.kind == kind
		end

		function Error:extend(options)
			options = options or {}

			options.kind = options.kind or self.kind

			return Error.new(options, self)
		end

		function Error:getErrorChain()
			local runtimeErrors = { self }

			while runtimeErrors[#runtimeErrors].parent do
				table.insert(runtimeErrors, runtimeErrors[#runtimeErrors].parent)
			end

			return runtimeErrors
		end

		function Error:__tostring()
			local errorStrings = {
				string.format("-- Promise.Error(%s) --", self.kind or "?"),
			}

			for _, runtimeError in ipairs(self:getErrorChain()) do
				table.insert(
					errorStrings,
					table.concat({
						runtimeError.trace or runtimeError.error,
						runtimeError.context,
					}, "\n")
				)
			end

			return table.concat(errorStrings, "\n")
		end
	end

	--[[
		Packs a number of arguments into a table and returns its length.

		Used to cajole varargs without dropping sparse values.
	]]
	local function pack(...)
		return select("#", ...), { ... }
	end

	--[[
		Returns first value (success), and packs all following values.
	]]
	local function packResult(success, ...)
		return success, select("#", ...), { ... }
	end

	local function makeErrorHandler(traceback)
		assert(traceback ~= nil, "traceback is nil")

		return function(err)
			-- If the error object is already a table, forward it directly.
			-- Should we extend the error here and add our own trace?

			if type(err) == "table" then
				return err
			end

			return Error.new({
				error = err,
				kind = Error.Kind.ExecutionError,
				trace = debug.traceback(tostring(err), 2),
				context = "Promise created at:\n\n" .. traceback,
			})
		end
	end

	--[[
		Calls a Promise executor with error handling.
	]]
	local function runExecutor(traceback, callback, ...)
		return packResult(xpcall(callback, makeErrorHandler(traceback), ...))
	end

	--[[
		Creates a function that invokes a callback with correct error handling and
		resolution mechanisms.
	]]
	local function createAdvancer(traceback, callback, resolve, reject)
		return function(...)
			local ok, resultLength, result = runExecutor(traceback, callback, ...)

			if ok then
				resolve(unpack(result, 1, resultLength))
			else
				reject(result[1])
			end
		end
	end

	local function isEmpty(t)
		return next(t) == nil
	end

	--[=[
		An enum value used to represent the Promise's status.
		@interface Status
		@tag enum
		@within Promise
		.Started "Started" -- The Promise is executing, and not settled yet.
		.Resolved "Resolved" -- The Promise finished successfully.
		.Rejected "Rejected" -- The Promise was rejected.
		.Cancelled "Cancelled" -- The Promise was cancelled before it finished.
	]=]
	--[=[
		@prop Status Status
		@within Promise
		@readonly
		@tag enums
		A table containing all members of the `Status` enum, e.g., `Promise.Status.Resolved`.
	]=]
	--[=[
		A Promise is an object that represents a value that will exist in the future, but doesn't right now.
		Promises allow you to then attach callbacks that can run once the value becomes available (known as *resolving*),
		or if an error has occurred (known as *rejecting*).

		@class Promise
		@__index prototype
	]=]
	local Promise = {
		Error = Error,
		Status = makeEnum("Promise.Status", { "Started", "Resolved", "Rejected", "Cancelled" }),
		_getTime = os.clock,
		_timeEvent = game:GetService("RunService").Heartbeat,
		_unhandledRejectionCallbacks = {},
	}
	Promise.prototype = {}
	Promise.__index = Promise.prototype

	function Promise._new(traceback, callback, parent)
		if parent ~= nil and not Promise.is(parent) then
			error("Argument #2 to Promise.new must be a promise or nil", 2)
		end

		local self = {
			-- The executor thread.
			_thread = nil,

			-- Used to locate where a promise was created
			_source = traceback,

			_status = Promise.Status.Started,

			-- A table containing a list of all results, whether success or failure.
			-- Only valid if _status is set to something besides Started
			_values = nil,

			-- Lua doesn't like sparse arrays very much, so we explicitly store the
			-- length of _values to handle middle nils.
			_valuesLength = -1,

			-- Tracks if this Promise has no error observers..
			_unhandledRejection = true,

			-- Queues representing functions we should invoke when we update!
			_queuedResolve = {},
			_queuedReject = {},
			_queuedFinally = {},

			-- The function to run when/if this promise is cancelled.
			_cancellationHook = nil,

			-- The "parent" of this promise in a promise chain. Required for
			-- cancellation propagation upstream.
			_parent = parent,

			-- Consumers are Promises that have chained onto this one.
			-- We track them for cancellation propagation downstream.
			_consumers = setmetatable({}, MODE_KEY_METATABLE),
		}

		if parent and parent._status == Promise.Status.Started then
			parent._consumers[self] = true
		end

		setmetatable(self, Promise)

		local function resolve(...)
			self:_resolve(...)
		end

		local function reject(...)
			self:_reject(...)
		end

		local function onCancel(cancellationHook)
			if cancellationHook then
				if self._status == Promise.Status.Cancelled then
					cancellationHook()
				else
					self._cancellationHook = cancellationHook
				end
			end

			return self._status == Promise.Status.Cancelled
		end

		self._thread = coroutine.create(function()
			local ok, _, result = runExecutor(self._source, callback, resolve, reject, onCancel)

			if not ok then
				reject(result[1])
			end
		end)

		task.spawn(self._thread)

		return self
	end

	--[=[
		Construct a new Promise that will be resolved or rejected with the given callbacks.

		If you `resolve` with a Promise, it will be chained onto.

		You can safely yield within the executor function and it will not block the creating thread.

		```lua
		local myFunction()
			return Promise.new(function(resolve, reject, onCancel)
				wait(1)
				resolve("Hello world!")
			end)
		end

		myFunction():andThen(print)
		```

		You do not need to use `pcall` within a Promise. Errors that occur during execution will be caught and turned into a rejection automatically. If `error()` is called with a table, that table will be the rejection value. Otherwise, string errors will be converted into `Promise.Error(Promise.Error.Kind.ExecutionError)` objects for tracking debug information.

		You may register an optional cancellation hook by using the `onCancel` argument:

		* This should be used to abort any ongoing operations leading up to the promise being settled.
		* Call the `onCancel` function with a function callback as its only argument to set a hook which will in turn be called when/if the promise is cancelled.
		* `onCancel` returns `true` if the Promise was already cancelled when you called `onCancel`.
		* Calling `onCancel` with no argument will not override a previously set cancellation hook, but it will still return `true` if the Promise is currently cancelled.
		* You can set the cancellation hook at any time before resolving.
		* When a promise is cancelled, calls to `resolve` or `reject` will be ignored, regardless of if you set a cancellation hook or not.

		:::caution
		If the Promise is cancelled, the `executor` thread is closed with `coroutine.close` after the cancellation hook is called.

		You must perform any cleanup code in the cancellation hook: any time your executor yields, it **may never resume**.
		:::

		@param executor (resolve: (...: any) -> (), reject: (...: any) -> (), onCancel: (abortHandler?: () -> ()) -> boolean) -> ()
		@return Promise
	]=]
	function Promise.new(executor)
		return Promise._new(debug.traceback(nil, 2), executor)
	end

	function Promise:__tostring()
		return string.format("Promise(%s)", self._status)
	end

	--[=[
		The same as [Promise.new](/api/Promise#new), except execution begins after the next `Heartbeat` event.

		This is a spiritual replacement for `spawn`, but it does not suffer from the same [issues](https://eryn.io/gist/3db84579866c099cdd5bb2ff37947cec) as `spawn`.

		```lua
		local function waitForChild(instance, childName, timeout)
		  return Promise.defer(function(resolve, reject)
			local child = instance:WaitForChild(childName, timeout)

			;(child and resolve or reject)(child)
		  end)
		end
		```

		@param executor (resolve: (...: any) -> (), reject: (...: any) -> (), onCancel: (abortHandler?: () -> ()) -> boolean) -> ()
		@return Promise
	]=]
	function Promise.defer(executor)
		local traceback = debug.traceback(nil, 2)
		local promise
		promise = Promise._new(traceback, function(resolve, reject, onCancel)
			local connection
			connection = Promise._timeEvent:Connect(function()
				connection:Disconnect()
				local ok, _, result = runExecutor(traceback, executor, resolve, reject, onCancel)

				if not ok then
					reject(result[1])
				end
			end)
		end)

		return promise
	end

	-- Backwards compatibility
	Promise.async = Promise.defer

	--[=[
		Creates an immediately resolved Promise with the given value.

		```lua
		-- Example using Promise.resolve to deliver cached values:
		function getSomething(name)
			if cache[name] then
				return Promise.resolve(cache[name])
			else
				return Promise.new(function(resolve, reject)
					local thing = getTheThing()
					cache[name] = thing

					resolve(thing)
				end)
			end
		end
		```

		@param ... any
		@return Promise<...any>
	]=]
	function Promise.resolve(...)
		local length, values = pack(...)
		return Promise._new(debug.traceback(nil, 2), function(resolve)
			resolve(unpack(values, 1, length))
		end)
	end

	--[=[
		Creates an immediately rejected Promise with the given value.

		:::caution
		Something needs to consume this rejection (i.e. `:catch()` it), otherwise it will emit an unhandled Promise rejection warning on the next frame. Thus, you should not create and store rejected Promises for later use. Only create them on-demand as needed.
		:::

		@param ... any
		@return Promise<...any>
	]=]
	function Promise.reject(...)
		local length, values = pack(...)
		return Promise._new(debug.traceback(nil, 2), function(_, reject)
			reject(unpack(values, 1, length))
		end)
	end

	--[[
		Runs a non-promise-returning function as a Promise with the
	  given arguments.
	]]
	function Promise._try(traceback, callback, ...)
		local valuesLength, values = pack(...)

		return Promise._new(traceback, function(resolve)
			resolve(callback(unpack(values, 1, valuesLength)))
		end)
	end

	--[=[
		Begins a Promise chain, calling a function and returning a Promise resolving with its return value. If the function errors, the returned Promise will be rejected with the error. You can safely yield within the Promise.try callback.

		:::info
		`Promise.try` is similar to [Promise.promisify](#promisify), except the callback is invoked immediately instead of returning a new function.
		:::

		```lua
		Promise.try(function()
			return math.random(1, 2) == 1 and "ok" or error("Oh an error!")
		end)
			:andThen(function(text)
				print(text)
			end)
			:catch(function(err)
				warn("Something went wrong")
			end)
		```

		@param callback (...: T...) -> ...any
		@param ... T... -- Additional arguments passed to `callback`
		@return Promise
	]=]
	function Promise.try(callback, ...)
		return Promise._try(debug.traceback(nil, 2), callback, ...)
	end

	--[[
		Returns a new promise that:
			* is resolved when all input promises resolve
			* is rejected if ANY input promises reject
	]]
	function Promise._all(traceback, promises, amount)
		if type(promises) ~= "table" then
			error(string.format(ERROR_NON_LIST, "Promise.all"), 3)
		end

		-- We need to check that each value is a promise here so that we can produce
		-- a proper error rather than a rejected promise with our error.
		for i, promise in pairs(promises) do
			if not Promise.is(promise) then
				error(string.format(ERROR_NON_PROMISE_IN_LIST, "Promise.all", tostring(i)), 3)
			end
		end

		-- If there are no values then return an already resolved promise.
		if #promises == 0 or amount == 0 then
			return Promise.resolve({})
		end

		return Promise._new(traceback, function(resolve, reject, onCancel)
			-- An array to contain our resolved values from the given promises.
			local resolvedValues = {}
			local newPromises = {}

			-- Keep a count of resolved promises because just checking the resolved
			-- values length wouldn't account for promises that resolve with nil.
			local resolvedCount = 0
			local rejectedCount = 0
			local done = false

			local function cancel()
				for _, promise in ipairs(newPromises) do
					promise:cancel()
				end
			end

			-- Called when a single value is resolved and resolves if all are done.
			local function resolveOne(i, ...)
				if done then
					return
				end

				resolvedCount = resolvedCount + 1

				if amount == nil then
					resolvedValues[i] = ...
				else
					resolvedValues[resolvedCount] = ...
				end

				if resolvedCount >= (amount or #promises) then
					done = true
					resolve(resolvedValues)
					cancel()
				end
			end

			onCancel(cancel)

			-- We can assume the values inside `promises` are all promises since we
			-- checked above.
			for i, promise in ipairs(promises) do
				newPromises[i] = promise:andThen(function(...)
					resolveOne(i, ...)
				end, function(...)
					rejectedCount = rejectedCount + 1

					if amount == nil or #promises - rejectedCount < amount then
						cancel()
						done = true

						reject(...)
					end
				end)
			end

			if done then
				cancel()
			end
		end)
	end

	--[=[
		Accepts an array of Promises and returns a new promise that:
		* is resolved after all input promises resolve.
		* is rejected if *any* input promises reject.

		:::info
		Only the first return value from each promise will be present in the resulting array.
		:::

		After any input Promise rejects, all other input Promises that are still pending will be cancelled if they have no other consumers.

		```lua
		local promises = {
			returnsAPromise("example 1"),
			returnsAPromise("example 2"),
			returnsAPromise("example 3"),
		}

		return Promise.all(promises)
		```

		@param promises {Promise<T>}
		@return Promise<{T}>
	]=]
	function Promise.all(promises)
		return Promise._all(debug.traceback(nil, 2), promises)
	end

	--[=[
		Folds an array of values or promises into a single value. The array is traversed sequentially.

		The reducer function can return a promise or value directly. Each iteration receives the resolved value from the previous, and the first receives your defined initial value.

		The folding will stop at the first rejection encountered.
		```lua
		local basket = {"blueberry", "melon", "pear", "melon"}
		Promise.fold(basket, function(cost, fruit)
			if fruit == "blueberry" then
				return cost -- blueberries are free!
			else
				-- call a function that returns a promise with the fruit price
				return fetchPrice(fruit):andThen(function(fruitCost)
					return cost + fruitCost
				end)
			end
		end, 0)
		```

		@since v3.1.0
		@param list {T | Promise<T>}
		@param reducer (accumulator: U, value: T, index: number) -> U | Promise<U>
		@param initialValue U
	]=]
	function Promise.fold(list, reducer, initialValue)
		assert(type(list) == "table", "Bad argument #1 to Promise.fold: must be a table")
		assert(isCallable(reducer), "Bad argument #2 to Promise.fold: must be a function")

		local accumulator = Promise.resolve(initialValue)
		return Promise.each(list, function(resolvedElement, i)
			accumulator = accumulator:andThen(function(previousValueResolved)
				return reducer(previousValueResolved, resolvedElement, i)
			end)
		end):andThen(function()
			return accumulator
		end)
	end

	--[=[
		Accepts an array of Promises and returns a Promise that is resolved as soon as `count` Promises are resolved from the input array. The resolved array values are in the order that the Promises resolved in. When this Promise resolves, all other pending Promises are cancelled if they have no other consumers.

		`count` 0 results in an empty array. The resultant array will never have more than `count` elements.

		```lua
		local promises = {
			returnsAPromise("example 1"),
			returnsAPromise("example 2"),
			returnsAPromise("example 3"),
		}

		return Promise.some(promises, 2) -- Only resolves with first 2 promises to resolve
		```

		@param promises {Promise<T>}
		@param count number
		@return Promise<{T}>
	]=]
	function Promise.some(promises, count)
		assert(type(count) == "number", "Bad argument #2 to Promise.some: must be a number")

		return Promise._all(debug.traceback(nil, 2), promises, count)
	end

	--[=[
		Accepts an array of Promises and returns a Promise that is resolved as soon as *any* of the input Promises resolves. It will reject only if *all* input Promises reject. As soon as one Promises resolves, all other pending Promises are cancelled if they have no other consumers.

		Resolves directly with the value of the first resolved Promise. This is essentially [[Promise.some]] with `1` count, except the Promise resolves with the value directly instead of an array with one element.

		```lua
		local promises = {
			returnsAPromise("example 1"),
			returnsAPromise("example 2"),
			returnsAPromise("example 3"),
		}

		return Promise.any(promises) -- Resolves with first value to resolve (only rejects if all 3 rejected)
		```

		@param promises {Promise<T>}
		@return Promise<T>
	]=]
	function Promise.any(promises)
		return Promise._all(debug.traceback(nil, 2), promises, 1):andThen(function(values)
			return values[1]
		end)
	end

	--[=[
		Accepts an array of Promises and returns a new Promise that resolves with an array of in-place Statuses when all input Promises have settled. This is equivalent to mapping `promise:finally` over the array of Promises.

		```lua
		local promises = {
			returnsAPromise("example 1"),
			returnsAPromise("example 2"),
			returnsAPromise("example 3"),
		}

		return Promise.allSettled(promises)
		```

		@param promises {Promise<T>}
		@return Promise<{Status}>
	]=]
	function Promise.allSettled(promises)
		if type(promises) ~= "table" then
			error(string.format(ERROR_NON_LIST, "Promise.allSettled"), 2)
		end

		-- We need to check that each value is a promise here so that we can produce
		-- a proper error rather than a rejected promise with our error.
		for i, promise in pairs(promises) do
			if not Promise.is(promise) then
				error(string.format(ERROR_NON_PROMISE_IN_LIST, "Promise.allSettled", tostring(i)), 2)
			end
		end

		-- If there are no values then return an already resolved promise.
		if #promises == 0 then
			return Promise.resolve({})
		end

		return Promise._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
			-- An array to contain our resolved values from the given promises.
			local fates = {}
			local newPromises = {}

			-- Keep a count of resolved promises because just checking the resolved
			-- values length wouldn't account for promises that resolve with nil.
			local finishedCount = 0

			-- Called when a single value is resolved and resolves if all are done.
			local function resolveOne(i, ...)
				finishedCount = finishedCount + 1

				fates[i] = ...

				if finishedCount >= #promises then
					resolve(fates)
				end
			end

			onCancel(function()
				for _, promise in ipairs(newPromises) do
					promise:cancel()
				end
			end)

			-- We can assume the values inside `promises` are all promises since we
			-- checked above.
			for i, promise in ipairs(promises) do
				newPromises[i] = promise:finally(function(...)
					resolveOne(i, ...)
				end)
			end
		end)
	end

	--[=[
		Accepts an array of Promises and returns a new promise that is resolved or rejected as soon as any Promise in the array resolves or rejects.

		:::warning
		If the first Promise to settle from the array settles with a rejection, the resulting Promise from `race` will reject.

		If you instead want to tolerate rejections, and only care about at least one Promise resolving, you should use [Promise.any](#any) or [Promise.some](#some) instead.
		:::

		All other Promises that don't win the race will be cancelled if they have no other consumers.

		```lua
		local promises = {
			returnsAPromise("example 1"),
			returnsAPromise("example 2"),
			returnsAPromise("example 3"),
		}

		return Promise.race(promises) -- Only returns 1st value to resolve or reject
		```

		@param promises {Promise<T>}
		@return Promise<T>
	]=]
	function Promise.race(promises)
		assert(type(promises) == "table", string.format(ERROR_NON_LIST, "Promise.race"))

		for i, promise in pairs(promises) do
			assert(Promise.is(promise), string.format(ERROR_NON_PROMISE_IN_LIST, "Promise.race", tostring(i)))
		end

		return Promise._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
			local newPromises = {}
			local finished = false

			local function cancel()
				for _, promise in ipairs(newPromises) do
					promise:cancel()
				end
			end

			local function finalize(callback)
				return function(...)
					cancel()
					finished = true
					return callback(...)
				end
			end

			if onCancel(finalize(reject)) then
				return
			end

			for i, promise in ipairs(promises) do
				newPromises[i] = promise:andThen(finalize(resolve), finalize(reject))
			end

			if finished then
				cancel()
			end
		end)
	end

	--[=[
		Iterates serially over the given an array of values, calling the predicate callback on each value before continuing.

		If the predicate returns a Promise, we wait for that Promise to resolve before moving on to the next item
		in the array.

		:::info
		`Promise.each` is similar to `Promise.all`, except the Promises are ran in order instead of all at once.

		But because Promises are eager, by the time they are created, they're already running. Thus, we need a way to defer creation of each Promise until a later time.

		The predicate function exists as a way for us to operate on our data instead of creating a new closure for each Promise. If you would prefer, you can pass in an array of functions, and in the predicate, call the function and return its return value.
		:::

		```lua
		Promise.each({
			"foo",
			"bar",
			"baz",
			"qux"
		}, function(value, index)
			return Promise.delay(1):andThen(function()
			print(("%d) Got %s!"):format(index, value))
			end)
		end)

		--[[
			(1 second passes)
			> 1) Got foo!
			(1 second passes)
			> 2) Got bar!
			(1 second passes)
			> 3) Got baz!
			(1 second passes)
			> 4) Got qux!
		]]
		```

		If the Promise a predicate returns rejects, the Promise from `Promise.each` is also rejected with the same value.

		If the array of values contains a Promise, when we get to that point in the list, we wait for the Promise to resolve before calling the predicate with the value.

		If a Promise in the array of values is already Rejected when `Promise.each` is called, `Promise.each` rejects with that value immediately (the predicate callback will never be called even once). If a Promise in the list is already Cancelled when `Promise.each` is called, `Promise.each` rejects with `Promise.Error(Promise.Error.Kind.AlreadyCancelled`). If a Promise in the array of values is Started at first, but later rejects, `Promise.each` will reject with that value and iteration will not continue once iteration encounters that value.

		Returns a Promise containing an array of the returned/resolved values from the predicate for each item in the array of values.

		If this Promise returned from `Promise.each` rejects or is cancelled for any reason, the following are true:
		- Iteration will not continue.
		- Any Promises within the array of values will now be cancelled if they have no other consumers.
		- The Promise returned from the currently active predicate will be cancelled if it hasn't resolved yet.

		@since 3.0.0
		@param list {T | Promise<T>}
		@param predicate (value: T, index: number) -> U | Promise<U>
		@return Promise<{U}>
	]=]
	function Promise.each(list, predicate)
		assert(type(list) == "table", string.format(ERROR_NON_LIST, "Promise.each"))
		assert(isCallable(predicate), string.format(ERROR_NON_FUNCTION, "Promise.each"))

		return Promise._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
			local results = {}
			local promisesToCancel = {}

			local cancelled = false

			local function cancel()
				for _, promiseToCancel in ipairs(promisesToCancel) do
					promiseToCancel:cancel()
				end
			end

			onCancel(function()
				cancelled = true

				cancel()
			end)

			-- We need to preprocess the list of values and look for Promises.
			-- If we find some, we must register our andThen calls now, so that those Promises have a consumer
			-- from us registered. If we don't do this, those Promises might get cancelled by something else
			-- before we get to them in the series because it's not possible to tell that we plan to use it
			-- unless we indicate it here.

			local preprocessedList = {}

			for index, value in ipairs(list) do
				if Promise.is(value) then
					if value:getStatus() == Promise.Status.Cancelled then
						cancel()
						return reject(Error.new({
							error = "Promise is cancelled",
							kind = Error.Kind.AlreadyCancelled,
							context = string.format(
								"The Promise that was part of the array at index %d passed into Promise.each was already cancelled when Promise.each began.\n\nThat Promise was created at:\n\n%s",
								index,
								value._source
							),
						}))
					elseif value:getStatus() == Promise.Status.Rejected then
						cancel()
						return reject(select(2, value:await()))
					end

					-- Chain a new Promise from this one so we only cancel ours
					local ourPromise = value:andThen(function(...)
						return ...
					end)

					table.insert(promisesToCancel, ourPromise)
					preprocessedList[index] = ourPromise
				else
					preprocessedList[index] = value
				end
			end

			for index, value in ipairs(preprocessedList) do
				if Promise.is(value) then
					local success
					success, value = value:await()

					if not success then
						cancel()
						return reject(value)
					end
				end

				if cancelled then
					return
				end

				local predicatePromise = Promise.resolve(predicate(value, index))

				table.insert(promisesToCancel, predicatePromise)

				local success, result = predicatePromise:await()

				if not success then
					cancel()
					return reject(result)
				end

				results[index] = result
			end

			resolve(results)
		end)
	end

	--[=[
		Checks whether the given object is a Promise via duck typing. This only checks if the object is a table and has an `andThen` method.

		@param object any
		@return boolean -- `true` if the given `object` is a Promise.
	]=]
	function Promise.is(object)
		if type(object) ~= "table" then
			return false
		end

		local objectMetatable = getmetatable(object)

		if objectMetatable == Promise then
			-- The Promise came from this library.
			return true
		elseif objectMetatable == nil then
			-- No metatable, but we should still chain onto tables with andThen methods
			return isCallable(object.andThen)
		elseif
			type(objectMetatable) == "table"
			and type(rawget(objectMetatable, "__index")) == "table"
			and isCallable(rawget(rawget(objectMetatable, "__index"), "andThen"))
		then
			-- Maybe this came from a different or older Promise library.
			return true
		end

		return false
	end

	--[=[
		Wraps a function that yields into one that returns a Promise.

		Any errors that occur while executing the function will be turned into rejections.

		:::info
		`Promise.promisify` is similar to [Promise.try](#try), except the callback is returned as a callable function instead of being invoked immediately.
		:::

		```lua
		local sleep = Promise.promisify(wait)

		sleep(1):andThen(print)
		```

		```lua
		local isPlayerInGroup = Promise.promisify(function(player, groupId)
			return player:IsInGroup(groupId)
		end)
		```

		@param callback (...: any) -> ...any
		@return (...: any) -> Promise
	]=]
	function Promise.promisify(callback)
		return function(...)
			return Promise._try(debug.traceback(nil, 2), callback, ...)
		end
	end

	--[=[
		Returns a Promise that resolves after `seconds` seconds have passed. The Promise resolves with the actual amount of time that was waited.

		This function is **not** a wrapper around `wait`. `Promise.delay` uses a custom scheduler which provides more accurate timing. As an optimization, cancelling this Promise instantly removes the task from the scheduler.

		:::warning
		Passing `NaN`, infinity, or a number less than 1/60 is equivalent to passing 1/60.
		:::

		```lua
			Promise.delay(5):andThenCall(print, "This prints after 5 seconds")
		```

		@function delay
		@within Promise
		@param seconds number
		@return Promise<number>
	]=]
	do
		-- uses a sorted doubly linked list (queue) to achieve O(1) remove operations and O(n) for insert

		-- the initial node in the linked list
		local first
		local connection

		function Promise.delay(seconds)
			assert(type(seconds) == "number", "Bad argument #1 to Promise.delay, must be a number.")
			-- If seconds is -INF, INF, NaN, or less than 1 / 60, assume seconds is 1 / 60.
			-- This mirrors the behavior of wait()
			if not (seconds >= 1 / 60) or seconds == math.huge then
				seconds = 1 / 60
			end

			return Promise._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
				local startTime = Promise._getTime()
				local endTime = startTime + seconds

				local node = {
					resolve = resolve,
					startTime = startTime,
					endTime = endTime,
				}

				if connection == nil then -- first is nil when connection is nil
					first = node
					connection = Promise._timeEvent:Connect(function()
						local threadStart = Promise._getTime()

						while first ~= nil and first.endTime < threadStart do
							local current = first
							first = current.next

							if first == nil then
								connection:Disconnect()
								connection = nil
							else
								first.previous = nil
							end

							current.resolve(Promise._getTime() - current.startTime)
						end
					end)
				else -- first is non-nil
					if first.endTime < endTime then -- if `node` should be placed after `first`
						-- we will insert `node` between `current` and `next`
						-- (i.e. after `current` if `next` is nil)
						local current = first
						local next = current.next

						while next ~= nil and next.endTime < endTime do
							current = next
							next = current.next
						end

						-- `current` must be non-nil, but `next` could be `nil` (i.e. last item in list)
						current.next = node
						node.previous = current

						if next ~= nil then
							node.next = next
							next.previous = node
						end
					else
						-- set `node` to `first`
						node.next = first
						first.previous = node
						first = node
					end
				end

				onCancel(function()
					-- remove node from queue
					local next = node.next

					if first == node then
						if next == nil then -- if `node` is the first and last
							connection:Disconnect()
							connection = nil
						else -- if `node` is `first` and not the last
							next.previous = nil
						end
						first = next
					else
						local previous = node.previous
						-- since `node` is not `first`, then we know `previous` is non-nil
						previous.next = next

						if next ~= nil then
							next.previous = previous
						end
					end
				end)
			end)
		end
	end

	--[=[
		Returns a new Promise that resolves if the chained Promise resolves within `seconds` seconds, or rejects if execution time exceeds `seconds`. The chained Promise will be cancelled if the timeout is reached.

		Rejects with `rejectionValue` if it is non-nil. If a `rejectionValue` is not given, it will reject with a `Promise.Error(Promise.Error.Kind.TimedOut)`. This can be checked with [[Error.isKind]].

		```lua
		getSomething():timeout(5):andThen(function(something)
			-- got something and it only took at max 5 seconds
		end):catch(function(e)
			-- Either getting something failed or the time was exceeded.

			if Promise.Error.isKind(e, Promise.Error.Kind.TimedOut) then
				warn("Operation timed out!")
			else
				warn("Operation encountered an error!")
			end
		end)
		```

		Sugar for:

		```lua
		Promise.race({
			Promise.delay(seconds):andThen(function()
				return Promise.reject(
					rejectionValue == nil
					and Promise.Error.new({ kind = Promise.Error.Kind.TimedOut })
					or rejectionValue
				)
			end),
			promise
		})
		```

		@param seconds number
		@param rejectionValue? any -- The value to reject with if the timeout is reached
		@return Promise
	]=]
	function Promise.prototype:timeout(seconds, rejectionValue)
		local traceback = debug.traceback(nil, 2)

		return Promise.race({
			Promise.delay(seconds):andThen(function()
				return Promise.reject(rejectionValue == nil and Error.new({
					kind = Error.Kind.TimedOut,
					error = "Timed out",
					context = string.format(
						"Timeout of %d seconds exceeded.\n:timeout() called at:\n\n%s",
						seconds,
						traceback
					),
				}) or rejectionValue)
			end),
			self,
		})
	end

	--[=[
		Returns the current Promise status.

		@return Status
	]=]
	function Promise.prototype:getStatus()
		return self._status
	end

	--[[
		Creates a new promise that receives the result of this promise.

		The given callbacks are invoked depending on that result.
	]]
	function Promise.prototype:_andThen(traceback, successHandler, failureHandler)
		self._unhandledRejection = false

		-- If we are already cancelled, we return a cancelled Promise
		if self._status == Promise.Status.Cancelled then
			local promise = Promise.new(function() end)
			promise:cancel()

			return promise
		end

		-- Create a new promise to follow this part of the chain
		return Promise._new(traceback, function(resolve, reject, onCancel)
			-- Our default callbacks just pass values onto the next promise.
			-- This lets success and failure cascade correctly!

			local successCallback = resolve
			if successHandler then
				successCallback = createAdvancer(traceback, successHandler, resolve, reject)
			end

			local failureCallback = reject
			if failureHandler then
				failureCallback = createAdvancer(traceback, failureHandler, resolve, reject)
			end

			if self._status == Promise.Status.Started then
				-- If we haven't resolved yet, put ourselves into the queue
				table.insert(self._queuedResolve, successCallback)
				table.insert(self._queuedReject, failureCallback)

				onCancel(function()
					-- These are guaranteed to exist because the cancellation handler is guaranteed to only
					-- be called at most once
					if self._status == Promise.Status.Started then
						table.remove(self._queuedResolve, table.find(self._queuedResolve, successCallback))
						table.remove(self._queuedReject, table.find(self._queuedReject, failureCallback))
					end
				end)
			elseif self._status == Promise.Status.Resolved then
				-- This promise has already resolved! Trigger success immediately.
				successCallback(unpack(self._values, 1, self._valuesLength))
			elseif self._status == Promise.Status.Rejected then
				-- This promise died a terrible death! Trigger failure immediately.
				failureCallback(unpack(self._values, 1, self._valuesLength))
			end
		end, self)
	end

	--[=[
		Chains onto an existing Promise and returns a new Promise.

		:::warning
		Within the failure handler, you should never assume that the rejection value is a string. Some rejections within the Promise library are represented by [[Error]] objects. If you want to treat it as a string for debugging, you should call `tostring` on it first.
		:::

		You can return a Promise from the success or failure handler and it will be chained onto.

		Calling `andThen` on a cancelled Promise returns a cancelled Promise.

		:::tip
		If the Promise returned by `andThen` is cancelled, `successHandler` and `failureHandler` will not run.

		To run code no matter what, use [Promise:finally].
		:::

		@param successHandler (...: any) -> ...any
		@param failureHandler? (...: any) -> ...any
		@return Promise<...any>
	]=]
	function Promise.prototype:andThen(successHandler, failureHandler)
		assert(successHandler == nil or isCallable(successHandler), string.format(ERROR_NON_FUNCTION, "Promise:andThen"))
		assert(failureHandler == nil or isCallable(failureHandler), string.format(ERROR_NON_FUNCTION, "Promise:andThen"))

		return self:_andThen(debug.traceback(nil, 2), successHandler, failureHandler)
	end

	--[=[
		Shorthand for `Promise:andThen(nil, failureHandler)`.

		Returns a Promise that resolves if the `failureHandler` worked without encountering an additional error.

		:::warning
		Within the failure handler, you should never assume that the rejection value is a string. Some rejections within the Promise library are represented by [[Error]] objects. If you want to treat it as a string for debugging, you should call `tostring` on it first.
		:::

		Calling `catch` on a cancelled Promise returns a cancelled Promise.

		:::tip
		If the Promise returned by `catch` is cancelled,  `failureHandler` will not run.

		To run code no matter what, use [Promise:finally].
		:::

		@param failureHandler (...: any) -> ...any
		@return Promise<...any>
	]=]
	function Promise.prototype:catch(failureHandler)
		assert(failureHandler == nil or isCallable(failureHandler), string.format(ERROR_NON_FUNCTION, "Promise:catch"))
		return self:_andThen(debug.traceback(nil, 2), nil, failureHandler)
	end

	--[=[
		Similar to [Promise.andThen](#andThen), except the return value is the same as the value passed to the handler. In other words, you can insert a `:tap` into a Promise chain without affecting the value that downstream Promises receive.

		```lua
			getTheValue()
			:tap(print)
			:andThen(function(theValue)
				print("Got", theValue, "even though print returns nil!")
			end)
		```

		If you return a Promise from the tap handler callback, its value will be discarded but `tap` will still wait until it resolves before passing the original value through.

		@param tapHandler (...: any) -> ...any
		@return Promise<...any>
	]=]
	function Promise.prototype:tap(tapHandler)
		assert(isCallable(tapHandler), string.format(ERROR_NON_FUNCTION, "Promise:tap"))
		return self:_andThen(debug.traceback(nil, 2), function(...)
			local callbackReturn = tapHandler(...)

			if Promise.is(callbackReturn) then
				local length, values = pack(...)
				return callbackReturn:andThen(function()
					return unpack(values, 1, length)
				end)
			end

			return ...
		end)
	end

	--[=[
		Attaches an `andThen` handler to this Promise that calls the given callback with the predefined arguments. The resolved value is discarded.

		```lua
			promise:andThenCall(someFunction, "some", "arguments")
		```

		This is sugar for

		```lua
			promise:andThen(function()
			return someFunction("some", "arguments")
			end)
		```

		@param callback (...: any) -> any
		@param ...? any -- Additional arguments which will be passed to `callback`
		@return Promise
	]=]
	function Promise.prototype:andThenCall(callback, ...)
		assert(isCallable(callback), string.format(ERROR_NON_FUNCTION, "Promise:andThenCall"))
		local length, values = pack(...)
		return self:_andThen(debug.traceback(nil, 2), function()
			return callback(unpack(values, 1, length))
		end)
	end

	--[=[
		Attaches an `andThen` handler to this Promise that discards the resolved value and returns the given value from it.

		```lua
			promise:andThenReturn("some", "values")
		```

		This is sugar for

		```lua
			promise:andThen(function()
				return "some", "values"
			end)
		```

		:::caution
		Promises are eager, so if you pass a Promise to `andThenReturn`, it will begin executing before `andThenReturn` is reached in the chain. Likewise, if you pass a Promise created from [[Promise.reject]] into `andThenReturn`, it's possible that this will trigger the unhandled rejection warning. If you need to return a Promise, it's usually best practice to use [[Promise.andThen]].
		:::

		@param ... any -- Values to return from the function
		@return Promise
	]=]
	function Promise.prototype:andThenReturn(...)
		local length, values = pack(...)
		return self:_andThen(debug.traceback(nil, 2), function()
			return unpack(values, 1, length)
		end)
	end

	--[=[
		Cancels this promise, preventing the promise from resolving or rejecting. Does not do anything if the promise is already settled.

		Cancellations will propagate upwards and downwards through chained promises.

		Promises will only be cancelled if all of their consumers are also cancelled. This is to say that if you call `andThen` twice on the same promise, and you cancel only one of the child promises, it will not cancel the parent promise until the other child promise is also cancelled.

		```lua
			promise:cancel()
		```
	]=]
	function Promise.prototype:cancel()
		if self._status ~= Promise.Status.Started then
			return
		end

		self._status = Promise.Status.Cancelled

		if self._cancellationHook then
			self._cancellationHook()
		end

		coroutine.close(self._thread)

		if self._parent then
			self._parent:_consumerCancelled(self)
		end

		for child in pairs(self._consumers) do
			child:cancel()
		end

		self:_finalize()
	end

	--[[
		Used to decrease the number of consumers by 1, and if there are no more,
		cancel this promise.
	]]
	function Promise.prototype:_consumerCancelled(consumer)
		if self._status ~= Promise.Status.Started then
			return
		end

		self._consumers[consumer] = nil

		if next(self._consumers) == nil then
			self:cancel()
		end
	end

	--[[
		Used to set a handler for when the promise resolves, rejects, or is
		cancelled.
	]]
	function Promise.prototype:_finally(traceback, finallyHandler)
		self._unhandledRejection = false

		local promise = Promise._new(traceback, function(resolve, reject, onCancel)
			local handlerPromise

			onCancel(function()
				-- The finally Promise is not a proper consumer of self. We don't care about the resolved value.
				-- All we care about is running at the end. Therefore, if self has no other consumers, it's safe to
				-- cancel. We don't need to hold out cancelling just because there's a finally handler.
				self:_consumerCancelled(self)

				if handlerPromise then
					handlerPromise:cancel()
				end
			end)

			local finallyCallback = resolve
			if finallyHandler then
				finallyCallback = function(...)
					local callbackReturn = finallyHandler(...)

					if Promise.is(callbackReturn) then
						handlerPromise = callbackReturn

						callbackReturn
							:finally(function(status)
								if status ~= Promise.Status.Rejected then
									resolve(self)
								end
							end)
							:catch(function(...)
								reject(...)
							end)
					else
						resolve(self)
					end
				end
			end

			if self._status == Promise.Status.Started then
				-- The promise is not settled, so queue this.
				table.insert(self._queuedFinally, finallyCallback)
			else
				-- The promise already settled or was cancelled, run the callback now.
				finallyCallback(self._status)
			end
		end)

		return promise
	end

	--[=[
		Set a handler that will be called regardless of the promise's fate. The handler is called when the promise is
		resolved, rejected, *or* cancelled.

		Returns a new Promise that:
		- resolves with the same values that this Promise resolves with.
		- rejects with the same values that this Promise rejects with.
		- is cancelled if this Promise is cancelled.

		If the value you return from the handler is a Promise:
		- We wait for the Promise to resolve, but we ultimately discard the resolved value.
		- If the returned Promise rejects, the Promise returned from `finally` will reject with the rejected value from the
		*returned* promise.
		- If the `finally` Promise is cancelled, and you returned a Promise from the handler, we cancel that Promise too.

		Otherwise, the return value from the `finally` handler is entirely discarded.

		:::note Cancellation
		As of Promise v4, `Promise:finally` does not count as a consumer of the parent Promise for cancellation purposes.
		This means that if all of a Promise's consumers are cancelled and the only remaining callbacks are finally handlers,
		the Promise is cancelled and the finally callbacks run then and there.

		Cancellation still propagates through the `finally` Promise though: if you cancel the `finally` Promise, it can cancel
		its parent Promise if it had no other consumers. Likewise, if the parent Promise is cancelled, the `finally` Promise
		will also be cancelled.
		:::

		```lua
		local thing = createSomething()

		doSomethingWith(thing)
			:andThen(function()
				print("It worked!")
				-- do something..
			end)
			:catch(function()
				warn("Oh no it failed!")
			end)
			:finally(function()
				-- either way, destroy thing

				thing:Destroy()
			end)

		```

		@param finallyHandler (status: Status) -> ...any
		@return Promise<...any>
	]=]
	function Promise.prototype:finally(finallyHandler)
		assert(finallyHandler == nil or isCallable(finallyHandler), string.format(ERROR_NON_FUNCTION, "Promise:finally"))
		return self:_finally(debug.traceback(nil, 2), finallyHandler)
	end

	--[=[
		Same as `andThenCall`, except for `finally`.

		Attaches a `finally` handler to this Promise that calls the given callback with the predefined arguments.

		@param callback (...: any) -> any
		@param ...? any -- Additional arguments which will be passed to `callback`
		@return Promise
	]=]
	function Promise.prototype:finallyCall(callback, ...)
		assert(isCallable(callback), string.format(ERROR_NON_FUNCTION, "Promise:finallyCall"))
		local length, values = pack(...)
		return self:_finally(debug.traceback(nil, 2), function()
			return callback(unpack(values, 1, length))
		end)
	end

	--[=[
		Attaches a `finally` handler to this Promise that discards the resolved value and returns the given value from it.

		```lua
			promise:finallyReturn("some", "values")
		```

		This is sugar for

		```lua
			promise:finally(function()
				return "some", "values"
			end)
		```

		@param ... any -- Values to return from the function
		@return Promise
	]=]
	function Promise.prototype:finallyReturn(...)
		local length, values = pack(...)
		return self:_finally(debug.traceback(nil, 2), function()
			return unpack(values, 1, length)
		end)
	end

	--[=[
		Yields the current thread until the given Promise completes. Returns the Promise's status, followed by the values that the promise resolved or rejected with.

		@yields
		@return Status -- The Status representing the fate of the Promise
		@return ...any -- The values the Promise resolved or rejected with.
	]=]
	function Promise.prototype:awaitStatus()
		self._unhandledRejection = false

		if self._status == Promise.Status.Started then
			local thread = coroutine.running()

			self
				:finally(function()
					task.spawn(thread)
				end)
				-- The finally promise can propagate rejections, so we attach a catch handler to prevent the unhandled
				-- rejection warning from appearing
				:catch(
					function() end
				)

			coroutine.yield()
		end

		if self._status == Promise.Status.Resolved then
			return self._status, unpack(self._values, 1, self._valuesLength)
		elseif self._status == Promise.Status.Rejected then
			return self._status, unpack(self._values, 1, self._valuesLength)
		end

		return self._status
	end

	local function awaitHelper(status, ...)
		return status == Promise.Status.Resolved, ...
	end

	--[=[
		Yields the current thread until the given Promise completes. Returns true if the Promise resolved, followed by the values that the promise resolved or rejected with.

		:::caution
		If the Promise gets cancelled, this function will return `false`, which is indistinguishable from a rejection. If you need to differentiate, you should use [[Promise.awaitStatus]] instead.
		:::

		```lua
			local worked, value = getTheValue():await()

		if worked then
			print("got", value)
		else
			warn("it failed")
		end
		```

		@yields
		@return boolean -- `true` if the Promise successfully resolved
		@return ...any -- The values the Promise resolved or rejected with.
	]=]
	function Promise.prototype:await()
		return awaitHelper(self:awaitStatus())
	end

	local function expectHelper(status, ...)
		if status ~= Promise.Status.Resolved then
			error((...) == nil and "Expected Promise rejected with no value." or (...), 3)
		end

		return ...
	end

	--[=[
		Yields the current thread until the given Promise completes. Returns the values that the promise resolved with.

		```lua
		local worked = pcall(function()
			print("got", getTheValue():expect())
		end)

		if not worked then
			warn("it failed")
		end
		```

		This is essentially sugar for:

		```lua
		select(2, assert(promise:await()))
		```

		**Errors** if the Promise rejects or gets cancelled.

		@error any -- Errors with the rejection value if this Promise rejects or gets cancelled.
		@yields
		@return ...any -- The values the Promise resolved with.
	]=]
	function Promise.prototype:expect()
		return expectHelper(self:awaitStatus())
	end

	-- Backwards compatibility
	Promise.prototype.awaitValue = Promise.prototype.expect

	--[[
		Intended for use in tests.

		Similar to await(), but instead of yielding if the promise is unresolved,
		_unwrap will throw. This indicates an assumption that a promise has
		resolved.
	]]
	function Promise.prototype:_unwrap()
		if self._status == Promise.Status.Started then
			error("Promise has not resolved or rejected.", 2)
		end

		local success = self._status == Promise.Status.Resolved

		return success, unpack(self._values, 1, self._valuesLength)
	end

	function Promise.prototype:_resolve(...)
		if self._status ~= Promise.Status.Started then
			if Promise.is((...)) then
				(...):_consumerCancelled(self)
			end
			return
		end

		-- If the resolved value was a Promise, we chain onto it!
		if Promise.is((...)) then
			-- Without this warning, arguments sometimes mysteriously disappear
			if select("#", ...) > 1 then
				local message = string.format(
					"When returning a Promise from andThen, extra arguments are " .. "discarded! See:\n\n%s",
					self._source
				)
				warn(message)
			end

			local chainedPromise = ...

			local promise = chainedPromise:andThen(function(...)
				self:_resolve(...)
			end, function(...)
				local maybeRuntimeError = chainedPromise._values[1]

				-- Backwards compatibility < v2
				if chainedPromise._error then
					maybeRuntimeError = Error.new({
						error = chainedPromise._error,
						kind = Error.Kind.ExecutionError,
						context = "[No stack trace available as this Promise originated from an older version of the Promise library (< v2)]",
					})
				end

				if Error.isKind(maybeRuntimeError, Error.Kind.ExecutionError) then
					return self:_reject(maybeRuntimeError:extend({
						error = "This Promise was chained to a Promise that errored.",
						trace = "",
						context = string.format(
							"The Promise at:\n\n%s\n...Rejected because it was chained to the following Promise, which encountered an error:\n",
							self._source
						),
					}))
				end

				self:_reject(...)
			end)

			if promise._status == Promise.Status.Cancelled then
				self:cancel()
			elseif promise._status == Promise.Status.Started then
				-- Adopt ourselves into promise for cancellation propagation.
				self._parent = promise
				promise._consumers[self] = true
			end

			return
		end

		self._status = Promise.Status.Resolved
		self._valuesLength, self._values = pack(...)

		-- We assume that these callbacks will not throw errors.
		for _, callback in ipairs(self._queuedResolve) do
			coroutine.wrap(callback)(...)
		end

		self:_finalize()
	end

	function Promise.prototype:_reject(...)
		if self._status ~= Promise.Status.Started then
			return
		end

		self._status = Promise.Status.Rejected
		self._valuesLength, self._values = pack(...)

		-- If there are any rejection handlers, call those!
		if not isEmpty(self._queuedReject) then
			-- We assume that these callbacks will not throw errors.
			for _, callback in ipairs(self._queuedReject) do
				coroutine.wrap(callback)(...)
			end
		else
			-- At this point, no one was able to observe the error.
			-- An error handler might still be attached if the error occurred
			-- synchronously. We'll wait one tick, and if there are still no
			-- observers, then we should put a message in the console.

			local err = tostring((...))

			coroutine.wrap(function()
				Promise._timeEvent:Wait()

				-- Someone observed the error, hooray!
				if not self._unhandledRejection then
					return
				end

				-- Build a reasonable message
				local message = string.format("Unhandled Promise rejection:\n\n%s\n\n%s", err, self._source)

				for _, callback in ipairs(Promise._unhandledRejectionCallbacks) do
					task.spawn(callback, self, unpack(self._values, 1, self._valuesLength))
				end

				if Promise.TEST then
					-- Don't spam output when we're running tests.
					return
				end

				warn(message)
			end)()
		end

		self:_finalize()
	end

	--[[
		Calls any :finally handlers. We need this to be a separate method and
		queue because we must call all of the finally callbacks upon a success,
		failure, *and* cancellation.
	]]
	function Promise.prototype:_finalize()
		for _, callback in ipairs(self._queuedFinally) do
			-- Purposefully not passing values to callbacks here, as it could be the
			-- resolved values, or rejected errors. If the developer needs the values,
			-- they should use :andThen or :catch explicitly.
			coroutine.wrap(callback)(self._status)
		end

		self._queuedFinally = nil
		self._queuedReject = nil
		self._queuedResolve = nil

		-- Clear references to other Promises to allow gc
		if not Promise.TEST then
			self._parent = nil
			self._consumers = nil
		end

		task.defer(coroutine.close, self._thread)
	end

	--[=[
		Chains a Promise from this one that is resolved if this Promise is already resolved, and rejected if it is not resolved at the time of calling `:now()`. This can be used to ensure your `andThen` handler occurs on the same frame as the root Promise execution.

		```lua
		doSomething()
			:now()
			:andThen(function(value)
				print("Got", value, "synchronously.")
			end)
		```

		If this Promise is still running, Rejected, or Cancelled, the Promise returned from `:now()` will reject with the `rejectionValue` if passed, otherwise with a `Promise.Error(Promise.Error.Kind.NotResolvedInTime)`. This can be checked with [[Error.isKind]].

		@param rejectionValue? any -- The value to reject with if the Promise isn't resolved
		@return Promise
	]=]
	function Promise.prototype:now(rejectionValue)
		local traceback = debug.traceback(nil, 2)
		if self._status == Promise.Status.Resolved then
			return self:_andThen(traceback, function(...)
				return ...
			end)
		else
			return Promise.reject(rejectionValue == nil and Error.new({
				kind = Error.Kind.NotResolvedInTime,
				error = "This Promise was not resolved in time for :now()",
				context = ":now() was called at:\n\n" .. traceback,
			}) or rejectionValue)
		end
	end

	--[=[
		Repeatedly calls a Promise-returning function up to `times` number of times, until the returned Promise resolves.

		If the amount of retries is exceeded, the function will return the latest rejected Promise.

		```lua
		local function canFail(a, b, c)
			return Promise.new(function(resolve, reject)
				-- do something that can fail

				local failed, thing = doSomethingThatCanFail(a, b, c)

				if failed then
					reject("it failed")
				else
					resolve(thing)
				end
			end)
		end

		local MAX_RETRIES = 10
		local value = Promise.retry(canFail, MAX_RETRIES, "foo", "bar", "baz") -- args to send to canFail
		```

		@since 3.0.0
		@param callback (...: P) -> Promise<T>
		@param times number
		@param ...? P
		@return Promise<T>
	]=]
	function Promise.retry(callback, times, ...)
		assert(isCallable(callback), "Parameter #1 to Promise.retry must be a function")
		assert(type(times) == "number", "Parameter #2 to Promise.retry must be a number")

		local args, length = { ... }, select("#", ...)

		return Promise.resolve(callback(...)):catch(function(...)
			if times > 0 then
				return Promise.retry(callback, times - 1, unpack(args, 1, length))
			else
				return Promise.reject(...)
			end
		end)
	end

	--[=[
		Repeatedly calls a Promise-returning function up to `times` number of times, waiting `seconds` seconds between each
		retry, until the returned Promise resolves.

		If the amount of retries is exceeded, the function will return the latest rejected Promise.

		@since v3.2.0
		@param callback (...: P) -> Promise<T>
		@param times number
		@param seconds number
		@param ...? P
		@return Promise<T>
	]=]
	function Promise.retryWithDelay(callback, times, seconds, ...)
		assert(isCallable(callback), "Parameter #1 to Promise.retry must be a function")
		assert(type(times) == "number", "Parameter #2 (times) to Promise.retry must be a number")
		assert(type(seconds) == "number", "Parameter #3 (seconds) to Promise.retry must be a number")

		local args, length = { ... }, select("#", ...)

		return Promise.resolve(callback(...)):catch(function(...)
			if times > 0 then
				Promise.delay(seconds):await()

				return Promise.retryWithDelay(callback, times - 1, seconds, unpack(args, 1, length))
			else
				return Promise.reject(...)
			end
		end)
	end

	--[=[
		Converts an event into a Promise which resolves the next time the event fires.

		The optional `predicate` callback, if passed, will receive the event arguments and should return `true` or `false`, based on if this fired event should resolve the Promise or not. If `true`, the Promise resolves. If `false`, nothing happens and the predicate will be rerun the next time the event fires.

		The Promise will resolve with the event arguments.

		:::tip
		This function will work given any object with a `Connect` method. This includes all Roblox events.
		:::

		```lua
		-- Creates a Promise which only resolves when `somePart` is touched
		-- by a part named `"Something specific"`.
		return Promise.fromEvent(somePart.Touched, function(part)
			return part.Name == "Something specific"
		end)
		```

		@since 3.0.0
		@param event Event -- Any object with a `Connect` method. This includes all Roblox events.
		@param predicate? (...: P) -> boolean -- A function which determines if the Promise should resolve with the given value, or wait for the next event to check again.
		@return Promise<P>
	]=]
	function Promise.fromEvent(event, predicate)
		predicate = predicate or function()
			return true
		end

		return Promise._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
			local connection
			local shouldDisconnect = false

			local function disconnect()
				connection:Disconnect()
				connection = nil
			end

			-- We use shouldDisconnect because if the callback given to Connect is called before
			-- Connect returns, connection will still be nil. This happens with events that queue up
			-- events when there's nothing connected, such as RemoteEvents

			connection = event:Connect(function(...)
				local callbackValue = predicate(...)

				if callbackValue == true then
					resolve(...)

					if connection then
						disconnect()
					else
						shouldDisconnect = true
					end
				elseif type(callbackValue) ~= "boolean" then
					error("Promise.fromEvent predicate should always return a boolean")
				end
			end)

			if shouldDisconnect and connection then
				return disconnect()
			end

			onCancel(disconnect)
		end)
	end

	--[=[
		Registers a callback that runs when an unhandled rejection happens. An unhandled rejection happens when a Promise
		is rejected, and the rejection is not observed with `:catch`.

		The callback is called with the actual promise that rejected, followed by the rejection values.

		@since v3.2.0
		@param callback (promise: Promise, ...: any) -- A callback that runs when an unhandled rejection happens.
		@return () -> () -- Function that unregisters the `callback` when called
	]=]
	function Promise.onUnhandledRejection(callback)
		table.insert(Promise._unhandledRejectionCallbacks, callback)

		return function()
			local index = table.find(Promise._unhandledRejectionCallbacks, callback)

			if index then
				table.remove(Promise._unhandledRejectionCallbacks, index)
			end
		end
	end

	return Promise
	
end
luacompactModules["src/lib/xsxLib.lua"] = function()
	--[[
	  UI lib made by bungie#0001
	  
	  - Please do not use this without permission, I am working really hard on this UI to make it perfect and do not have a big 
	    problem with other people using it, please just make sure you message me and ask me before using.
	]]

	-- / Locals
	local Workspace = game:GetService("Workspace")
	local Player = game:GetService("Players").LocalPlayer
	local Mouse = Player:GetMouse()

	-- / Services
	local UserInputService = game:GetService("UserInputService")
	local TextService = game:GetService("TextService")
	local TweenService = game:GetService("TweenService")
	local RunService = game:GetService("RunService")
	local CoreGuiService = game:GetService("CoreGui")
	local ContentService = game:GetService("ContentProvider")
	local TeleportService = game:GetService("TeleportService")

	-- / Tween table & function
	local TweenTable = {
	    Default = {
	        TweenInfo.new(0.17, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, 0)
	    }
	}
	local CreateTween = function(name, speed, style, direction, loop, reverse, delay)
	    name = name
	    speed = speed or 0.17
	    style = style or Enum.EasingStyle.Sine
	    direction = direction or Enum.EasingDirection.InOut
	    loop = loop or 0
	    reverse = reverse or false
	    delay = delay or 0

	    TweenTable[name] = TweenInfo.new(speed, style, direction, loop, reverse, delay)
	end

	-- / Dragging
	local drag = function(obj, latency)
	    obj = obj
	    latency = latency or 0.06

	    toggled = nil
	    input = nil
	    start = nil

	    function updateInput(input)
	        local Delta = input.Position - start
	        local Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + Delta.X, startPos.Y.Scale, startPos.Y.Offset + Delta.Y)
	        TweenService:Create(obj, TweenInfo.new(latency), {Position = Position}):Play()
	    end

	    obj.InputBegan:Connect(function(inp)
	        if (inp.UserInputType == Enum.UserInputType.MouseButton1) then
	            toggled = true
	            start = inp.Position
	            startPos = obj.Position
	            inp.Changed:Connect(function()
	                if (inp.UserInputState == Enum.UserInputState.End) then
	                    toggled = false
	                end
	            end)
	        end
	    end)

	    obj.InputChanged:Connect(function(inp)
	        if (inp.UserInputType == Enum.UserInputType.MouseMovement) then
	            input = inp
	        end
	    end)

	    UserInputService.InputChanged:Connect(function(inp)
	        if (inp == input and toggled) then
	            updateInput(inp)
	        end
	    end)
	end

	local library = {
	    version = "2.0.2",
	    title = title or "xsx " .. tostring(math.random(1,366)),
	    fps = 0,
	    rank = "private"
	}

	coroutine.wrap(function()
	    RunService.RenderStepped:Connect(function(v)
	        library.fps =  math.round(1/v)
	    end)
	end)()

	function library:RoundNumber(int, float)
	    return tonumber(string.format("%." .. (int or 0) .. "f", float))
	end

	function library:GetUsername()
	    return Player.Name
	end

	function library:CheckIfLoaded()
	    if game:IsLoaded() then
	        return true
	    else
	        return false
	    end
	end

	function library:GetUserId()
	    return Player.UserId
	end

	function library:GetPlaceId()
	    return game.PlaceId
	end

	function library:GetJobId()
	    return game.JobId
	end

	function library:Rejoin()
	    TeleportService:TeleportToPlaceInstance(library:GetPlaceId(), library:GetJobId(), library:GetUserId())
	end

	function library:Copy(input) -- only works with synapse
	    if syn then
	        syn.write_clipboard(input)
	    end
	end

	function library:GetDay(type)
	    if type == "word" then -- day in a full word
	        return os.date("%A")
	    elseif type == "short" then -- day in a shortened word
	        return os.date("%a")
	    elseif type == "month" then -- day of the month in digits
	        return os.date("%d")
	    elseif type == "year" then -- day of the year in digits
	        return os.date("%j")
	    end
	end

	function library:GetTime(type)
	    if type == "24h" then -- time using a 24 hour clock
	        return os.date("%H")
	    elseif type == "12h" then -- time using a 12 hour clock
	        return os.date("%I")
	    elseif type == "minute" then -- time in minutes
	        return os.date("%M")
	    elseif type == "half" then -- what part of the day it is (AM or PM)
	        return os.date("%p")
	    elseif type == "second" then -- time in seconds
	        return os.date("%S")
	    elseif type == "full" then -- full time
	        return os.date("%X")
	    elseif type == "ISO" then -- ISO / UTC ( 1min = 1, 1hour = 100)
	        return os.date("%z")
	    elseif type == "zone" then -- time zone
	        return os.date("%Z") 
	    end
	end

	function library:GetMonth(type)
	    if type == "word" then -- full month name
	        return os.date("%B")
	    elseif type == "short" then -- month in shortened word
	        return os.date("%b")
	    elseif type == "digit" then -- the months digit
	        return os.date("%m")
	    end
	end

	function library:GetWeek(type)
	    if type == "year_S" then -- the number of the week in the current year (sunday first day)
	        return os.date("%U")
	    elseif type == "day" then -- the week day
	        return os.date("%w")
	    elseif type == "year_M" then -- the number of the week in the current year (monday first day)
	        return os.date("%W")
	    end
	end

	function library:GetYear(type)
	    if type == "digits" then -- the second 2 digits of the year
	        return os.date("%y")
	    elseif type == "full" then -- the full year
	        return os.date("%Y")
	    end
	end

	function library:UnlockFps(new) -- syn only
	    if syn then
	        setfpscap(new)
	    end
	end

	function library:Watermark(text)
	    for i,v in pairs(CoreGuiService:GetChildren()) do
	        if v.Name == "watermark" then
	            v:Destroy()
	        end
	    end

	    tetx = text or "xsx v2"

	    local watermark = Instance.new("ScreenGui")
	    local watermarkPadding = Instance.new("UIPadding")
	    local watermarkLayout = Instance.new("UIListLayout")
	    local edge = Instance.new("Frame")
	    local edgeCorner = Instance.new("UICorner")
	    local background = Instance.new("Frame")
	    local barFolder = Instance.new("Folder")
	    local bar = Instance.new("Frame")
	    local barCorner = Instance.new("UICorner")
	    local barLayout = Instance.new("UIListLayout")
	    local backgroundGradient = Instance.new("UIGradient")
	    local backgroundCorner = Instance.new("UICorner")
	    local waterText = Instance.new("TextLabel")
	    local waterPadding = Instance.new("UIPadding")
	    local backgroundLayout = Instance.new("UIListLayout")

	    watermark.Name = "watermark"
	    watermark.Parent = CoreGuiService
	    watermark.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	    
	    watermarkLayout.Name = "watermarkLayout"
	    watermarkLayout.Parent = watermark
	    watermarkLayout.FillDirection = Enum.FillDirection.Horizontal
	    watermarkLayout.SortOrder = Enum.SortOrder.LayoutOrder
	    watermarkLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	    watermarkLayout.Padding = UDim.new(0, 4)
	    
	    watermarkPadding.Name = "watermarkPadding"
	    watermarkPadding.Parent = watermark
	    watermarkPadding.PaddingBottom = UDim.new(0, 6)
	    watermarkPadding.PaddingLeft = UDim.new(0, 6)

	    edge.Name = "edge"
	    edge.Parent = watermark
	    edge.AnchorPoint = Vector2.new(0.5, 0.5)
	    edge.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	    edge.Position = UDim2.new(0.5, 0, -0.03, 0)
	    edge.Size = UDim2.new(0, 0, 0, 26)
	    edge.BackgroundTransparency = 1

	    edgeCorner.CornerRadius = UDim.new(0, 2)
	    edgeCorner.Name = "edgeCorner"
	    edgeCorner.Parent = edge

	    background.Name = "background"
	    background.Parent = edge
	    background.AnchorPoint = Vector2.new(0.5, 0.5)
	    background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	    background.BackgroundTransparency = 1
	    background.ClipsDescendants = true
	    background.Position = UDim2.new(0.5, 0, 0.5, 0)
	    background.Size = UDim2.new(0, 0, 0, 24)

	    barFolder.Name = "barFolder"
	    barFolder.Parent = background

	    bar.Name = "bar"
	    bar.Parent = barFolder
	    bar.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	    bar.BackgroundTransparency = 0
	    bar.Size = UDim2.new(0, 0, 0, 1)

	    barCorner.CornerRadius = UDim.new(0, 2)
	    barCorner.Name = "barCorner"
	    barCorner.Parent = bar

	    barLayout.Name = "barLayout"
	    barLayout.Parent = barFolder
	    barLayout.SortOrder = Enum.SortOrder.LayoutOrder

	    backgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	    backgroundGradient.Rotation = 90
	    backgroundGradient.Name = "backgroundGradient"
	    backgroundGradient.Parent = background

	    backgroundCorner.CornerRadius = UDim.new(0, 2)
	    backgroundCorner.Name = "backgroundCorner"
	    backgroundCorner.Parent = background

	    waterText.Name = "notifText"
	    waterText.Parent = background
	    waterText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	    waterText.BackgroundTransparency = 1.000
	    waterText.Position = UDim2.new(0, 0, -0.0416666679, 0)
	    waterText.Size = UDim2.new(0, 0, 0, 24)
	    waterText.Font = Enum.Font.Code
	    waterText.Text = text
	    waterText.TextColor3 = Color3.fromRGB(198, 198, 198)
	    waterText.TextTransparency = 1
	    waterText.TextSize = 14.000
	    waterText.RichText = true

	    local NewSize = TextService:GetTextSize(waterText.Text, waterText.TextSize, waterText.Font, Vector2.new(math.huge, math.huge))
	    waterText.Size = UDim2.new(0, NewSize.X + 8, 0, 24)

	    waterPadding.Name = "notifPadding"
	    waterPadding.Parent = waterText
	    waterPadding.PaddingBottom = UDim.new(0, 4)
	    waterPadding.PaddingLeft = UDim.new(0, 4)
	    waterPadding.PaddingRight = UDim.new(0, 4)
	    waterPadding.PaddingTop = UDim.new(0, 4)

	    backgroundLayout.Name = "backgroundLayout"
	    backgroundLayout.Parent = background
	    backgroundLayout.SortOrder = Enum.SortOrder.LayoutOrder
	    backgroundLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	    CreateTween("wm", 0.24)
	    CreateTween("wm_2", 0.04)
	    coroutine.wrap(function()
	        TweenService:Create(edge, TweenTable["wm"], {BackgroundTransparency = 0}):Play()
	        TweenService:Create(edge, TweenTable["wm"], {Size = UDim2.new(0, NewSize.x + 10, 0, 26)}):Play()
	        TweenService:Create(background, TweenTable["wm"], {BackgroundTransparency = 0}):Play()
	        TweenService:Create(background, TweenTable["wm"], {Size = UDim2.new(0, NewSize.x + 8, 0, 24)}):Play()
	        wait(.2)
	        TweenService:Create(bar, TweenTable["wm"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
	        wait(.1)
	        TweenService:Create(waterText, TweenTable["wm"], {TextTransparency = 0}):Play()
	    end)()

	    local WatermarkFunctions = {}
	    function WatermarkFunctions:AddWatermark(text)
	        tetx = text or "xsx v2"

	        local edge = Instance.new("Frame")
	        local edgeCorner = Instance.new("UICorner")
	        local background = Instance.new("Frame")
	        local barFolder = Instance.new("Folder")
	        local bar = Instance.new("Frame")
	        local barCorner = Instance.new("UICorner")
	        local barLayout = Instance.new("UIListLayout")
	        local backgroundGradient = Instance.new("UIGradient")
	        local backgroundCorner = Instance.new("UICorner")
	        local waterText = Instance.new("TextLabel")
	        local waterPadding = Instance.new("UIPadding")
	        local backgroundLayout = Instance.new("UIListLayout")
	    
	        edge.Name = "edge"
	        edge.Parent = watermark
	        edge.AnchorPoint = Vector2.new(0.5, 0.5)
	        edge.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	        edge.Position = UDim2.new(0.5, 0, -0.03, 0)
	        edge.Size = UDim2.new(0, 0, 0, 26)
	        edge.BackgroundTransparency = 1
	    
	        edgeCorner.CornerRadius = UDim.new(0, 2)
	        edgeCorner.Name = "edgeCorner"
	        edgeCorner.Parent = edge
	    
	        background.Name = "background"
	        background.Parent = edge
	        background.AnchorPoint = Vector2.new(0.5, 0.5)
	        background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	        background.BackgroundTransparency = 1
	        background.ClipsDescendants = true
	        background.Position = UDim2.new(0.5, 0, 0.5, 0)
	        background.Size = UDim2.new(0, 0, 0, 24)
	    
	        barFolder.Name = "barFolder"
	        barFolder.Parent = background
	    
	        bar.Name = "bar"
	        bar.Parent = barFolder
	        bar.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	        bar.BackgroundTransparency = 0
	        bar.Size = UDim2.new(0, 0, 0, 1)
	    
	        barCorner.CornerRadius = UDim.new(0, 2)
	        barCorner.Name = "barCorner"
	        barCorner.Parent = bar
	    
	        barLayout.Name = "barLayout"
	        barLayout.Parent = barFolder
	        barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	    
	        backgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	        backgroundGradient.Rotation = 90
	        backgroundGradient.Name = "backgroundGradient"
	        backgroundGradient.Parent = background
	    
	        backgroundCorner.CornerRadius = UDim.new(0, 2)
	        backgroundCorner.Name = "backgroundCorner"
	        backgroundCorner.Parent = background
	    
	        waterText.Name = "notifText"
	        waterText.Parent = background
	        waterText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	        waterText.BackgroundTransparency = 1.000
	        waterText.Position = UDim2.new(0, 0, -0.0416666679, 0)
	        waterText.Size = UDim2.new(0, 0, 0, 24)
	        waterText.Font = Enum.Font.Code
	        waterText.Text = text
	        waterText.TextColor3 = Color3.fromRGB(198, 198, 198)
	        waterText.TextTransparency = 1
	        waterText.TextSize = 14.000
	        waterText.RichText = true
	    
	        local NewSize = TextService:GetTextSize(waterText.Text, waterText.TextSize, waterText.Font, Vector2.new(math.huge, math.huge))
	        waterText.Size = UDim2.new(0, NewSize.X + 8, 0, 24)
	    
	        waterPadding.Name = "notifPadding"
	        waterPadding.Parent = waterText
	        waterPadding.PaddingBottom = UDim.new(0, 4)
	        waterPadding.PaddingLeft = UDim.new(0, 4)
	        waterPadding.PaddingRight = UDim.new(0, 4)
	        waterPadding.PaddingTop = UDim.new(0, 4)
	    
	        backgroundLayout.Name = "backgroundLayout"
	        backgroundLayout.Parent = background
	        backgroundLayout.SortOrder = Enum.SortOrder.LayoutOrder
	        backgroundLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	    
	        coroutine.wrap(function()
	            TweenService:Create(edge, TweenTable["wm"], {BackgroundTransparency = 0}):Play()
	            TweenService:Create(edge, TweenTable["wm"], {Size = UDim2.new(0, NewSize.x + 10, 0, 26)}):Play()
	            TweenService:Create(background, TweenTable["wm"], {BackgroundTransparency = 0}):Play()
	            TweenService:Create(background, TweenTable["wm"], {Size = UDim2.new(0, NewSize.x + 8, 0, 24)}):Play()
	            wait(.2)
	            TweenService:Create(bar, TweenTable["wm"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
	            wait(.1)
	            TweenService:Create(waterText, TweenTable["wm"], {TextTransparency = 0}):Play()
	        end)()

	        local NewWatermarkFunctions = {}
	        function NewWatermarkFunctions:Hide()
	            edge.Visible = false
	            return NewWatermarkFunctions
	        end
	        --
	        function NewWatermarkFunctions:Show()
	            edge.Visible = true
	            return NewWatermarkFunctions
	        end
	        --
	        function NewWatermarkFunctions:Text(new)
	            new = new or text
	            waterText.Text = new
	    
	            local NewSize = TextService:GetTextSize(waterText.Text, waterText.TextSize, waterText.Font, Vector2.new(math.huge, math.huge))
	            waterText.Size = UDim2.new(0, NewSize.X + 8, 0, 24)
	            coroutine.wrap(function()
	                TweenService:Create(edge, TweenTable["wm_2"], {Size = UDim2.new(0, NewSize.x + 10, 0, 26)}):Play()
	                TweenService:Create(background, TweenTable["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 24)}):Play()
	                TweenService:Create(bar, TweenTable["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
	                TweenService:Create(waterText, TweenTable["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
	            end)()
	    
	            return NewWatermarkFunctions
	        end
	        --
	        function NewWatermarkFunctions:Remove()
	            Watermark:Destroy()
	            return NewWatermarkFunctions
	        end
	        return NewWatermarkFunctions
	    end

	    function WatermarkFunctions:Hide()
	        edge.Visible = false
	        return WatermarkFunctions
	    end
	    --
	    function WatermarkFunctions:Show()
	        edge.Visible = true
	        return WatermarkFunctions
	    end
	    --
	    function WatermarkFunctions:Text(new)
	        new = new or text
	        waterText.Text = new

	        local NewSize = TextService:GetTextSize(waterText.Text, waterText.TextSize, waterText.Font, Vector2.new(math.huge, math.huge))
	        coroutine.wrap(function()
	            TweenService:Create(edge, TweenTable["wm_2"], {Size = UDim2.new(0, NewSize.x + 10, 0, 26)}):Play()
	            TweenService:Create(background, TweenTable["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 24)}):Play()
	            TweenService:Create(bar, TweenTable["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
	            TweenService:Create(waterText, TweenTable["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
	        end)()

	        return WatermarkFunctions
	    end
	    --
	    function WatermarkFunctions:Remove()
	        Watermark:Destroy()
	        return WatermarkFunctions
	    end
	    return WatermarkFunctions
	end

	function library:InitNotifications(text, duration, callback)
	    for i,v in next, CoreGuiService:GetChildren() do
	        if v.name == "Notifications" then
	            v:Destroy()
	        end
	    end

	    local Notifications = Instance.new("ScreenGui")
	    local notificationsLayout = Instance.new("UIListLayout")
	    local notificationsPadding = Instance.new("UIPadding")

	    Notifications.Name = "Notifications"
	    Notifications.Parent = CoreGuiService
	    Notifications.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	    notificationsLayout.Name = "notificationsLayout"
	    notificationsLayout.Parent = Notifications
	    notificationsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	    notificationsLayout.Padding = UDim.new(0, 4)

	    notificationsPadding.Name = "notificationsPadding"
	    notificationsPadding.Parent = Notifications
	    notificationsPadding.PaddingLeft = UDim.new(0, 6)
	    notificationsPadding.PaddingTop = UDim.new(0, 18)

	    local Notification = {}
	    function Notification:Notify(text, duration, type, callback)
	        
	        CreateTween("notification_load", 0.2)

	        text = text or "please wait."
	        duration = duration or 5
	        type = type or "notification"
	        callback = callback or function() end

	        local edge = Instance.new("Frame")
	        local edgeCorner = Instance.new("UICorner")
	        local background = Instance.new("Frame")
	        local barFolder = Instance.new("Folder")
	        local bar = Instance.new("Frame")
	        local barCorner = Instance.new("UICorner")
	        local barLayout = Instance.new("UIListLayout")
	        local backgroundGradient = Instance.new("UIGradient")
	        local backgroundCorner = Instance.new("UICorner")
	        local notifText = Instance.new("TextLabel")
	        local notifPadding = Instance.new("UIPadding")
	        local backgroundLayout = Instance.new("UIListLayout")
	    
	        edge.Name = "edge"
	        edge.Parent = Notifications
	        edge.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	        edge.BackgroundTransparency = 1.000
	        edge.Size = UDim2.new(0, 0, 0, 26)
	    
	        edgeCorner.CornerRadius = UDim.new(0, 2)
	        edgeCorner.Name = "edgeCorner"
	        edgeCorner.Parent = edge
	    
	        background.Name = "background"
	        background.Parent = edge
	        background.AnchorPoint = Vector2.new(0.5, 0.5)
	        background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	        background.BackgroundTransparency = 1.000
	        background.ClipsDescendants = true
	        background.Position = UDim2.new(0.5, 0, 0.5, 0)
	        background.Size = UDim2.new(0, 0, 0, 24)
	    
	        barFolder.Name = "barFolder"
	        barFolder.Parent = background
	    
	        bar.Name = "bar"
	        bar.Parent = barFolder
	        bar.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	        bar.BackgroundTransparency = 0.200
	        bar.Size = UDim2.new(0, 0, 0, 1)
	        if type == "notification" then
	            bar.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	        elseif type == "alert" then
	            bar.BackgroundColor3 = Color3.fromRGB(255, 246, 112)
	        elseif type == "error" then
	            bar.BackgroundColor3 = Color3.fromRGB(255, 74, 77)
	        elseif type == "success" then
	            bar.BackgroundColor3 = Color3.fromRGB(131, 255, 103)
	        elseif type == "information" then
	            bar.BackgroundColor3 = Color3.fromRGB(126, 117, 255)
	        end
	    
	        barCorner.CornerRadius = UDim.new(0, 2)
	        barCorner.Name = "barCorner"
	        barCorner.Parent = bar
	    
	        barLayout.Name = "barLayout"
	        barLayout.Parent = barFolder
	        barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	    
	        backgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	        backgroundGradient.Rotation = 90
	        backgroundGradient.Name = "backgroundGradient"
	        backgroundGradient.Parent = background
	    
	        backgroundCorner.CornerRadius = UDim.new(0, 2)
	        backgroundCorner.Name = "backgroundCorner"
	        backgroundCorner.Parent = background
	    
	        notifText.Name = "notifText"
	        notifText.Parent = background
	        notifText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	        notifText.BackgroundTransparency = 1.000
	        notifText.Size = UDim2.new(0, 230, 0, 26)
	        notifText.Font = Enum.Font.Code
	        notifText.Text = text
	        notifText.TextColor3 = Color3.fromRGB(198, 198, 198)
	        notifText.TextSize = 14.000
	        notifText.TextTransparency = 1.000
	        notifText.TextXAlignment = Enum.TextXAlignment.Left
	        notifText.RichText = true
	    
	        notifPadding.Name = "notifPadding"
	        notifPadding.Parent = notifText
	        notifPadding.PaddingBottom = UDim.new(0, 4)
	        notifPadding.PaddingLeft = UDim.new(0, 4)
	        notifPadding.PaddingRight = UDim.new(0, 4)
	        notifPadding.PaddingTop = UDim.new(0, 4)
	    
	        backgroundLayout.Name = "backgroundLayout"
	        backgroundLayout.Parent = background
	        backgroundLayout.SortOrder = Enum.SortOrder.LayoutOrder
	        backgroundLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	    
	        local NewSize = TextService:GetTextSize(notifText.Text, notifText.TextSize, notifText.Font, Vector2.new(math.huge, math.huge))
	        CreateTween("notification_wait", duration, Enum.EasingStyle.Quad)
	        local IsRunning = false
	        coroutine.wrap(function()
	            IsRunning = true
	            TweenService:Create(edge, TweenTable["notification_load"], {BackgroundTransparency = 0}):Play()
	            TweenService:Create(background, TweenTable["notification_load"], {BackgroundTransparency = 0}):Play()
	            TweenService:Create(notifText, TweenTable["notification_load"], {TextTransparency = 0}):Play()
	            TweenService:Create(edge, TweenTable["notification_load"], {Size = UDim2.new(0, NewSize.X + 10, 0, 26)}):Play()
	            TweenService:Create(background, TweenTable["notification_load"], {Size = UDim2.new(0, NewSize.X + 8, 0, 24)}):Play()
	            TweenService:Create(notifText, TweenTable["notification_load"], {Size = UDim2.new(0, NewSize.X + 8, 0, 24)}):Play()
	            wait()
	            TweenService:Create(bar, TweenTable["notification_wait"], {Size = UDim2.new(0, NewSize.X + 8, 0, 1)}):Play()
	            repeat wait() until bar.Size == UDim2.new(0, NewSize.X + 8, 0, 1)
	            IsRunning = false
	            TweenService:Create(edge, TweenTable["notification_load"], {BackgroundTransparency = 1}):Play()
	            TweenService:Create(background, TweenTable["notification_load"], {BackgroundTransparency = 1}):Play()
	            TweenService:Create(notifText, TweenTable["notification_load"], {TextTransparency = 1}):Play()
	            TweenService:Create(bar, TweenTable["notification_load"], {BackgroundTransparency = 1}):Play()
	            TweenService:Create(edge, TweenTable["notification_load"], {Size = UDim2.new(0, 0, 0, 26)}):Play()
	            TweenService:Create(background, TweenTable["notification_load"], {Size = UDim2.new(0, 0, 0, 24)}):Play()
	            TweenService:Create(notifText, TweenTable["notification_load"], {Size = UDim2.new(0, 0, 0, 24)}):Play()
	            TweenService:Create(bar, TweenTable["notification_load"], {Size = UDim2.new(0, 0, 0, 1)}):Play()
	            wait(.2)
	            edge:Destroy()
	        end)()

	        CreateTween("notification_reset", 0.4)
	        local NotificationFunctions = {}
	        function NotificationFunctions:Text(new)
	            new = new or text
	            notifText.Text = new

	            NewSize = TextService:GetTextSize(notifText.Text, notifText.TextSize, notifText.Font, Vector2.new(math.huge, math.huge))
	            local NewSize_2 = NewSize
	            if IsRunning then
	                TweenService:Create(edge, TweenTable["notification_load"], {Size = UDim2.new(0, NewSize.X + 10, 0, 26)}):Play()
	                TweenService:Create(background, TweenTable["notification_load"], {Size = UDim2.new(0, NewSize.X + 8, 0, 24)}):Play()
	                TweenService:Create(notifText, TweenTable["notification_load"], {Size = UDim2.new(0, NewSize.X + 8, 0, 24)}):Play()
	                wait()
	                TweenService:Create(bar, TweenTable["notification_reset"], {Size = UDim2.new(0, 0, 0, 1)}):Play()
	                wait(.4)
	                TweenService:Create(bar, TweenTable["notification_wait"], {Size = UDim2.new(0, NewSize.X + 8, 0, 1)}):Play()
	            end

	            return NotificationFunctions
	        end
	        return NotificationFunctions
	    end
	    return Notification
	end

	function library:Introduction()
	    for _,v in next, CoreGuiService:GetChildren() do
	        if v.Name == "screen" then
	            v:Destroy()
	        end
	    end

	    CreateTween("introduction",0.175)
	    local introduction = Instance.new("ScreenGui")
	    local edge = Instance.new("Frame")
	    local edgeCorner = Instance.new("UICorner")
	    local background = Instance.new("Frame")
	    local backgroundGradient = Instance.new("UIGradient")
	    local backgroundCorner = Instance.new("UICorner")
	    local barFolder = Instance.new("Folder")
	    local bar = Instance.new("Frame")
	    local barCorner = Instance.new("UICorner")
	    local barLayout = Instance.new("UIListLayout")
	    local xsxLogo = Instance.new("ImageLabel")
	    local hashLogo = Instance.new("ImageLabel")
	    local xsx = Instance.new("TextLabel")
	    local text = Instance.new("TextLabel")
	    local pageLayout = Instance.new("UIListLayout")
	    
	    introduction.Name = "introduction"
	    introduction.Parent = CoreGuiService
	    introduction.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	    
	    edge.Name = "edge"
	    edge.Parent = introduction
	    edge.AnchorPoint = Vector2.new(0.5, 0.5)
	    edge.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	    edge.BackgroundTransparency = 1
	    edge.Position = UDim2.new(0.511773348, 0, 0.5, 0)
	    edge.Size = UDim2.new(0, 300, 0, 308)
	    
	    edgeCorner.CornerRadius = UDim.new(0, 2)
	    edgeCorner.Name = "edgeCorner"
	    edgeCorner.Parent = edge
	    
	    background.Name = "background"
	    background.Parent = edge
	    background.AnchorPoint = Vector2.new(0.5, 0.5)
	    background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	    background.BackgroundTransparency = 1
	    background.ClipsDescendants = true
	    background.Position = UDim2.new(0.5, 0, 0.5, 0)
	    background.Size = UDim2.new(0, 298, 0, 306)
	    
	    backgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	    backgroundGradient.Rotation = 90
	    backgroundGradient.Name = "backgroundGradient"
	    backgroundGradient.Parent = background
	    
	    backgroundCorner.CornerRadius = UDim.new(0, 2)
	    backgroundCorner.Name = "backgroundCorner"
	    backgroundCorner.Parent = background
	    
	    barFolder.Name = "barFolder"
	    barFolder.Parent = background
	    
	    bar.Name = "bar"
	    bar.Parent = barFolder
	    bar.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	    bar.BackgroundTransparency = 0.200
	    bar.Size = UDim2.new(0, 0, 0, 1)
	    
	    barCorner.CornerRadius = UDim.new(0, 2)
	    barCorner.Name = "barCorner"
	    barCorner.Parent = bar
	    
	    barLayout.Name = "barLayout"
	    barLayout.Parent = barFolder
	    barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	    barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	    
	    xsxLogo.Name = "xsxLogo"
	    xsxLogo.Parent = background
	    xsxLogo.AnchorPoint = Vector2.new(0.5, 0.5)
	    xsxLogo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	    xsxLogo.BackgroundTransparency = 1.000
	    xsxLogo.Position = UDim2.new(0.5, 0, 0.5, 0)
	    xsxLogo.Size = UDim2.new(0, 448, 0, 150)
	    xsxLogo.Visible = true
	    xsxLogo.Image = "http://www.roblox.com/asset/?id=9365068051"
	    xsxLogo.ImageColor3 = Color3.fromRGB(150, 0, 0)
	    xsxLogo.ImageTransparency = 1
	    
	    hashLogo.Name = "hashLogo"
	    hashLogo.Parent = background
	    hashLogo.AnchorPoint = Vector2.new(0.5, 0.5)
	    hashLogo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	    hashLogo.BackgroundTransparency = 1.000
	    hashLogo.Position = UDim2.new(0.5, 0, 0.5, 0)
	    hashLogo.Size = UDim2.new(0, 150, 0, 150)
	    hashLogo.Visible = true
	    hashLogo.Image = "http://www.roblox.com/asset/?id=9365069861"
	    hashLogo.ImageColor3 = Color3.fromRGB(150, 0, 0)
	    hashLogo.ImageTransparency = 1
	    
	    xsx.Name = "xsx"
	    xsx.Parent = background
	    xsx.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	    xsx.BackgroundTransparency = 1.000
	    xsx.Size = UDim2.new(0, 80, 0, 21)
	    xsx.Font = Enum.Font.Code
	    xsx.Text = "powered by xsx"
	    xsx.TextColor3 = Color3.fromRGB(124, 124, 124)
	    xsx.TextSize = 10.000
	    xsx.TextTransparency = 1
	    
	    text.Name = "text"
	    text.Parent = background
	    text.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	    text.BackgroundTransparency = 1.000
	    text.Position = UDim2.new(0.912751675, 0, 0, 0)
	    text.Size = UDim2.new(0, 26, 0, 21)
	    text.Font = Enum.Font.Code
	    text.Text = "hash"
	    text.TextColor3 = Color3.fromRGB(124, 124, 124)
	    text.TextSize = 10.000
	    text.TextTransparency = 1
	    text.RichText = true
	    
	    pageLayout.Name = "pageLayout"
	    pageLayout.Parent = introduction
	    pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	    pageLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	    CreateTween("xsxRotation", 0)
	    local MinusAmount = -16
	    coroutine.wrap(function()
	        while wait() do
	            MinusAmount = MinusAmount + 0.4
	            TweenService:Create(xsxLogo, TweenTable["xsxRotation"], {Rotation = xsxLogo.Rotation - MinusAmount}):Play()
	        end
	    end)()

	    TweenService:Create(edge, TweenTable["introduction"], {BackgroundTransparency = 0}):Play()
	    TweenService:Create(background, TweenTable["introduction"], {BackgroundTransparency = 0}):Play()
	    wait(.2)
	    TweenService:Create(bar, TweenTable["introduction"], {Size = UDim2.new(0, 298, 0, 1)}):Play()
	    wait(.2)
	    TweenService:Create(xsx, TweenTable["introduction"], {TextTransparency = 0}):Play()
	    TweenService:Create(text, TweenTable["introduction"], {TextTransparency = 0}):Play()
	    wait(.3)
	    TweenService:Create(xsxLogo, TweenTable["introduction"], {ImageTransparency = 0}):Play()
	    wait(2)
	    TweenService:Create(xsxLogo, TweenTable["introduction"], {ImageTransparency = 1}):Play()
	    wait(.2)
	    TweenService:Create(hashLogo, TweenTable["introduction"], {ImageTransparency = 0}):Play()
	    wait(2)
	    TweenService:Create(hashLogo, TweenTable["introduction"], {ImageTransparency = 1}):Play()
	    wait(.1)
	    TweenService:Create(text, TweenTable["introduction"], {TextTransparency = 1}):Play()
	    wait(.1)
	    TweenService:Create(xsx, TweenTable["introduction"], {TextTransparency = 1}):Play()
	    wait(.1)
	    TweenService:Create(bar, TweenTable["introduction"], {Size = UDim2.new(0, 0, 0, 1)}):Play()
	    wait(.1)
	    TweenService:Create(background, TweenTable["introduction"], {BackgroundTransparency = 1}):Play()
	    TweenService:Create(edge, TweenTable["introduction"], {BackgroundTransparency = 1}):Play()
	    wait(.2)
	    introduction:Destroy()
	end

	function library:Init(key)
	    for _,v in next, CoreGuiService:GetChildren() do
	        if v.Name == "screen" then
	            v:Destroy()
	        end
	    end

	    local title = library.title
	    key = key or Enum.KeyCode.RightAlt

	    local screen = Instance.new("ScreenGui")
	    local edge = Instance.new("Frame")
	    local edgeCorner = Instance.new("UICorner")
	    local background = Instance.new("Frame")
	    local backgroundCorner = Instance.new("UICorner")
	    local backgroundGradient = Instance.new("UIGradient")
	    local headerLabel = Instance.new("TextLabel")
	    local headerPadding = Instance.new("UIPadding")
	    local barFolder = Instance.new("Folder")
	    local bar = Instance.new("Frame")
	    local barCorner = Instance.new("UICorner")
	    local barLayout = Instance.new("UIListLayout")
	    local tabButtonsEdge = Instance.new("Frame")
	    local tabButtonCorner = Instance.new("UICorner")
	    local tabButtons = Instance.new("Frame")
	    local tabButtonCorner_2 = Instance.new("UICorner")
	    local tabButtonsGradient = Instance.new("UIGradient")
	    local tabButtonLayout = Instance.new("UIListLayout")
	    local tabButtonPadding = Instance.new("UIPadding")
	    local containerEdge = Instance.new("Frame")
	    local tabButtonCorner_3 = Instance.new("UICorner")
	    local container = Instance.new("Frame")
	    local containerCorner = Instance.new("UICorner")
	    local containerGradient = Instance.new("UIGradient")

	    screen.Name = "screen"
	    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	    if get_hidden_ui or gethui then
	        screen.Parent = (get_hidden_ui or gethui)()
	    else
	        if syn and syn.protect_gui then
	            syn.protect_gui(screen)
	            screen.Parent = game:GetService("CoreGui")
	        end
	    end

	    edge.Name = "edge"
	    edge.Parent = screen
	    edge.AnchorPoint = Vector2.new(0.5, 0.5)
	    edge.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	    edge.Position = UDim2.new(0.5, 0, 0.5, 0)
	    edge.Size = UDim2.new(0, 594, 0, 406)

	    drag(edge, 0.04)
	    local CanChangeVisibility = true
	    UserInputService.InputBegan:Connect(function(input)
	        if CanChangeVisibility and input.KeyCode == key then
	            edge.Visible = not edge.Visible
	        end
	    end)

	    edgeCorner.CornerRadius = UDim.new(0, 2)
	    edgeCorner.Name = "edgeCorner"
	    edgeCorner.Parent = edge

	    background.Name = "background"
	    background.Parent = edge
	    background.AnchorPoint = Vector2.new(0.5, 0.5)
	    background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	    background.Position = UDim2.new(0.5, 0, 0.5, 0)
	    background.Size = UDim2.new(0, 592, 0, 404)
	    background.ClipsDescendants = true

	    backgroundCorner.CornerRadius = UDim.new(0, 2)
	    backgroundCorner.Name = "backgroundCorner"
	    backgroundCorner.Parent = background

	    backgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	    backgroundGradient.Rotation = 90
	    backgroundGradient.Name = "backgroundGradient"
	    backgroundGradient.Parent = background

	    headerLabel.Name = "headerLabel"
	    headerLabel.Parent = background
	    headerLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	    headerLabel.BackgroundTransparency = 1.000
	    headerLabel.Size = UDim2.new(0, 592, 0, 38)
	    headerLabel.Font = Enum.Font.Code
	    headerLabel.Text = title
	    headerLabel.TextColor3 = Color3.fromRGB(198, 198, 198)
	    headerLabel.TextSize = 16.000
	    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	    headerLabel.RichText = true

	    headerPadding.Name = "headerPadding"
	    headerPadding.Parent = headerLabel
	    headerPadding.PaddingBottom = UDim.new(0, 6)
	    headerPadding.PaddingLeft = UDim.new(0, 12)
	    headerPadding.PaddingRight = UDim.new(0, 6)
	    headerPadding.PaddingTop = UDim.new(0, 6)

	    barFolder.Name = "barFolder"
	    barFolder.Parent = background

	    bar.Name = "bar"
	    bar.Parent = barFolder
	    bar.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	    bar.BackgroundTransparency = 0.200
	    bar.Size = UDim2.new(0, 592, 0, 1)
	    bar.BorderSizePixel = 0

	    barCorner.CornerRadius = UDim.new(0, 2)
	    barCorner.Name = "barCorner"
	    barCorner.Parent = bar

	    barLayout.Name = "barLayout"
	    barLayout.Parent = barFolder
	    barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	    barLayout.SortOrder = Enum.SortOrder.LayoutOrder

	    tabButtonsEdge.Name = "tabButtonsEdge"
	    tabButtonsEdge.Parent = background
	    tabButtonsEdge.AnchorPoint = Vector2.new(0.5, 0.5)
	    tabButtonsEdge.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	    tabButtonsEdge.Position = UDim2.new(0.1435, 0, 0.536000013, 0)
	    tabButtonsEdge.Size = UDim2.new(0, 152, 0, 360)

	    tabButtonCorner.CornerRadius = UDim.new(0, 2)
	    tabButtonCorner.Name = "tabButtonCorner"
	    tabButtonCorner.Parent = tabButtonsEdge

	    tabButtons.Name = "tabButtons"
	    tabButtons.Parent = tabButtonsEdge
	    tabButtons.AnchorPoint = Vector2.new(0.5, 0.5)
	    tabButtons.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
	    tabButtons.ClipsDescendants = true
	    tabButtons.Position = UDim2.new(0.5, 0, 0.5, 0)
	    tabButtons.Size = UDim2.new(0, 150, 0, 358)

	    tabButtonCorner_2.CornerRadius = UDim.new(0, 2)
	    tabButtonCorner_2.Name = "tabButtonCorner"
	    tabButtonCorner_2.Parent = tabButtons

	    tabButtonsGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	    tabButtonsGradient.Rotation = 90
	    tabButtonsGradient.Name = "tabButtonsGradient"
	    tabButtonsGradient.Parent = tabButtons

	    tabButtonLayout.Name = "tabButtonLayout"
	    tabButtonLayout.Parent = tabButtons
	    tabButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	    tabButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder

	    tabButtonPadding.Name = "tabButtonPadding"
	    tabButtonPadding.Parent = tabButtons
	    tabButtonPadding.PaddingBottom = UDim.new(0, 4)
	    tabButtonPadding.PaddingLeft = UDim.new(0, 4)
	    tabButtonPadding.PaddingRight = UDim.new(0, 4)
	    tabButtonPadding.PaddingTop = UDim.new(0, 4)

	    containerEdge.Name = "containerEdge"
	    containerEdge.Parent = background
	    containerEdge.AnchorPoint = Vector2.new(0.5, 0.5)
	    containerEdge.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	    containerEdge.Position = UDim2.new(0.637000024, 0, 0.536000013, 0)
	    containerEdge.Size = UDim2.new(0, 414, 0, 360)

	    tabButtonCorner_3.CornerRadius = UDim.new(0, 2)
	    tabButtonCorner_3.Name = "tabButtonCorner"
	    tabButtonCorner_3.Parent = containerEdge

	    container.Name = "container"
	    container.Parent = containerEdge
	    container.AnchorPoint = Vector2.new(0.5, 0.5)
	    container.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
	    container.Position = UDim2.new(0.5, 0, 0.5, 0)
	    container.Size = UDim2.new(0, 412, 0, 358)

	    containerCorner.CornerRadius = UDim.new(0, 2)
	    containerCorner.Name = "containerCorner"
	    containerCorner.Parent = container

	    containerGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	    containerGradient.Rotation = 90
	    containerGradient.Name = "containerGradient"
	    containerGradient.Parent = container

	    local TabLibrary = {
	        IsFirst = true,
	        CurrentTab = ""
	    }
	    CreateTween("tab_text_colour", 0.16)
	    function TabLibrary:NewTab(title)
	        title = title or "tab"

	        local tabButton = Instance.new("TextButton")
	        local page = Instance.new("ScrollingFrame")
	        local pageLayout = Instance.new("UIListLayout")
	        local pagePadding = Instance.new("UIPadding")

	        tabButton.Name = "tabButton"
	        tabButton.Parent = tabButtons
	        tabButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	        tabButton.BackgroundTransparency = 1.000
	        tabButton.ClipsDescendants = true
	        tabButton.Position = UDim2.new(-0.0281690136, 0, 0, 0)
	        tabButton.Size = UDim2.new(0, 150, 0, 22)
	        tabButton.AutoButtonColor = false
	        tabButton.Font = Enum.Font.Code
	        tabButton.Text = title
	        tabButton.TextColor3 = Color3.fromRGB(170, 170, 170)
	        tabButton.TextSize = 15.000
	        tabButton.RichText = true

	        page.Name = "page"
	        page.Parent = container
	        page.Active = true
	        page.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	        page.BackgroundTransparency = 1.000
	        page.BorderSizePixel = 0
	        page.Size = UDim2.new(0, 412, 0, 358)
	        page.BottomImage = "http://www.roblox.com/asset/?id=3062506202"
	        page.MidImage = "http://www.roblox.com/asset/?id=3062506202"
	        page.ScrollBarThickness = 1
	        page.TopImage = "http://www.roblox.com/asset/?id=3062506202"
	        page.ScrollBarImageColor3 = Color3.fromRGB(150, 0, 0)
	        page.Visible = false
	        
	        pageLayout.Name = "pageLayout"
	        pageLayout.Parent = page
	        pageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	        pageLayout.Padding = UDim.new(0, 4)

	        pagePadding.Name = "pagePadding"
	        pagePadding.Parent = page
	        pagePadding.PaddingBottom = UDim.new(0, 6)
	        pagePadding.PaddingLeft = UDim.new(0, 6)
	        pagePadding.PaddingRight = UDim.new(0, 6)
	        pagePadding.PaddingTop = UDim.new(0, 6)

	        if TabLibrary.IsFirst then
	            page.Visible = true
	            tabButton.TextColor3 = Color3.fromRGB(150, 0, 0)
	            TabLibrary.CurrentTab = title
	        end
	        
	        tabButton.MouseButton1Click:Connect(function()
	            TabLibrary.CurrentTab = title
	            for i,v in pairs(container:GetChildren()) do 
	                if v:IsA("ScrollingFrame") then
	                    v.Visible = false
	                end
	            end
	            page.Visible = true

	            for i,v in pairs(tabButtons:GetChildren()) do
	                if v:IsA("TextButton") then
	                    TweenService:Create(v, TweenTable["tab_text_colour"], {TextColor3 = Color3.fromRGB(170, 170, 170)}):Play()
	                end
	            end
	            TweenService:Create(tabButton, TweenTable["tab_text_colour"], {TextColor3 = Color3.fromRGB(150, 0, 0)}):Play()
	        end)

	        local function UpdatePageSize()
	            local correction = pageLayout.AbsoluteContentSize
	            page.CanvasSize = UDim2.new(0, correction.X+13, 0, correction.Y+13)
	        end

	        page.ChildAdded:Connect(UpdatePageSize)
	        page.ChildRemoved:Connect(UpdatePageSize)

	        TabLibrary.IsFirst = false

	        CreateTween("hover", 0.16)
	        local Components = {}
	        function Components:NewLabel(text, alignment)
	            text = text or "label"
	            alignment = alignment or "left"

	            local label = Instance.new("TextLabel")
	            local labelPadding = Instance.new("UIPadding")

	            label.Name = "label"
	            label.Parent = page
	            label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            label.BackgroundTransparency = 1.000
	            label.Position = UDim2.new(0.00499999989, 0, 0, 0)
	            label.Size = UDim2.new(0, 396, 0, 24)
	            label.Font = Enum.Font.Code
	            label.Text = text
	            label.TextColor3 = Color3.fromRGB(190, 190, 190)
	            label.TextSize = 14.000
	            label.TextWrapped = true
	            label.TextXAlignment = Enum.TextXAlignment.Left
	            label.RichText = true

	            labelPadding.Name = "pagePadding"
	            labelPadding.Parent = page
	            labelPadding.PaddingBottom = UDim.new(0, 6)
	            labelPadding.PaddingLeft = UDim.new(0, 12)
	            labelPadding.PaddingRight = UDim.new(0, 6)
	            labelPadding.PaddingTop = UDim.new(0, 6)

	            if alignment:lower():find("le") then
	                label.TextXAlignment = Enum.TextXAlignment.Left
	            elseif alignment:lower():find("cent") then
	                label.TextXAlignment = Enum.TextXAlignment.Center
	            elseif alignment:lower():find("ri") then
	                label.TextXAlignment = Enum.TextXAlignment.Right
	            end

	            UpdatePageSize()

	            local LabelFunctions = {}
	            function LabelFunctions:Text(text)
	                text = text or "new label text"
	                label.Text = text
	                return LabelFunctions
	            end
	            --
	            function LabelFunctions:Remove()
	                label:Destroy()
	                return LabelFunctions
	            end
	            --
	            function LabelFunctions:Hide()
	                label.Visible = false
	                UpdatePageSize()
	                return LabelFunctions
	            end
	            --
	            function LabelFunctions:Show()
	                label.Visible = true
	                UpdatePageSize()
	                return LabelFunctions
	            end
	            --
	            function LabelFunctions:Align(new)
	                new = new or "le"
	                if new:lower():find("le") then
	                    label.TextXAlignment = Enum.TextXAlignment.Left
	                elseif new:lower():find("cent") then
	                    label.TextXAlignment = Enum.TextXAlignment.Center
	                elseif new:lower():find("ri") then
	                    label.TextXAlignment = Enum.TextXAlignment.Right
	                end
	            end
	            return LabelFunctions
	        end

	        function Components:NewButton(text, callback)
	            text = text or "button"
	            callback = callback or function() end

	            local buttonFrame = Instance.new("Frame")
	            local buttonLayout = Instance.new("UIListLayout")
	            local button = Instance.new("TextButton")
	            local buttonCorner = Instance.new("UICorner")
	            local buttonBackground = Instance.new("Frame")
	            local buttonGradient = Instance.new("UIGradient")
	            local buttonBackCorner = Instance.new("UICorner")
	            local buttonLabel = Instance.new("TextLabel")

	            buttonFrame.Name = "buttonFrame"
	            buttonFrame.Parent = page
	            buttonFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            buttonFrame.BackgroundTransparency = 1.000
	            buttonFrame.Size = UDim2.new(0, 396, 0, 24)

	            buttonLayout.Name = "buttonLayout"
	            buttonLayout.Parent = buttonFrame
	            buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	            buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	            buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	            buttonLayout.Padding = UDim.new(0, 4)

	            button.Name = "button"
	            button.Parent = buttonFrame
	            button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	            button.Size = UDim2.new(0, 396, 0, 24)
	            button.AutoButtonColor = false
	            button.Font = Enum.Font.SourceSans
	            button.Text = ""
	            button.TextColor3 = Color3.fromRGB(0, 0, 0)
	            button.TextSize = 14.000

	            buttonCorner.CornerRadius = UDim.new(0, 2)
	            buttonCorner.Name = "buttonCorner"
	            buttonCorner.Parent = button

	            buttonBackground.Name = "buttonBackground"
	            buttonBackground.Parent = button
	            buttonBackground.AnchorPoint = Vector2.new(0.5, 0.5)
	            buttonBackground.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            buttonBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
	            buttonBackground.Size = UDim2.new(0, 394, 0, 22)

	            buttonGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	            buttonGradient.Rotation = 90
	            buttonGradient.Name = "buttonGradient"
	            buttonGradient.Parent = buttonBackground

	            buttonBackCorner.CornerRadius = UDim.new(0, 2)
	            buttonBackCorner.Name = "buttonBackCorner"
	            buttonBackCorner.Parent = buttonBackground

	            buttonLabel.Name = "buttonLabel"
	            buttonLabel.Parent = buttonBackground
	            buttonLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	            buttonLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            buttonLabel.BackgroundTransparency = 1.000
	            buttonLabel.ClipsDescendants = true
	            buttonLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	            buttonLabel.Size = UDim2.new(0, 394, 0, 22)
	            buttonLabel.Font = Enum.Font.Code
	            buttonLabel.Text = text
	            buttonLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	            buttonLabel.TextSize = 14.000
	            buttonLabel.RichText = true

	            button.MouseEnter:Connect(function()
	                TweenService:Create(button, TweenTable["hover"], {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
	            end)
	            button.MouseLeave:Connect(function()
	                TweenService:Create(button, TweenTable["hover"], {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play()
	            end)

	            button.MouseButton1Down:Connect(function()
	                TweenService:Create(buttonLabel, TweenTable["hover"], {TextColor3 = Color3.fromRGB(150, 0, 0)}):Play()
	            end)
	            button.MouseButton1Up:Connect(function()
	                TweenService:Create(buttonLabel, TweenTable["hover"], {TextColor3 = Color3.fromRGB(190, 190, 190)}):Play()
	            end)

	            button.MouseButton1Click:Connect(function()
	                callback()
	            end)

	            local NewSizeX = 396
	            local Amnt = 0
	            local function ResizeButtons()
	                local Amount = buttonFrame:GetChildren()
	                local Resized = 396
	                Amount = #Amount - 1
	                Amnt = Amount
	                local AmountToSubtract = (Amount / 2)
	                Resized = (396 / Amount) - AmountToSubtract
	                NewSizeX = (Resized)

	                for i,v in pairs(buttonFrame:GetChildren()) do
	                    if v:IsA("TextButton") then
	                        v.Size = UDim2.new(0, Resized, 0, 24)
	                        for z,x in pairs(v:GetDescendants()) do
	                            if x:IsA("TextLabel") or x:IsA("Frame") then
	                                x.Size = UDim2.new(0, Resized - 2, 0, 22)
	                            end
	                        end
	                    end
	                end
	            end

	            buttonFrame.ChildAdded:Connect(ResizeButtons)
	            buttonFrame.ChildRemoved:Connect(ResizeButtons)

	            UpdatePageSize()

	            --
	            local ButtonFunctions = {}
	            function ButtonFunctions:AddButton(text, callback_2)
	                if Amnt < 4 then
	                    text = text or "button"
	                    callback_2 = callback_2 or function() end
	    
	                    local button = Instance.new("TextButton")
	                    local buttonCorner = Instance.new("UICorner")
	                    local buttonBackground = Instance.new("Frame")
	                    local buttonGradient = Instance.new("UIGradient")
	                    local buttonBackCorner = Instance.new("UICorner")
	                    local buttonLabel = Instance.new("TextLabel")
	        
	                    button.Name = "button"
	                    button.Parent = buttonFrame
	                    button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	                    button.Size = UDim2.new(0, NewSizeX - Amnt, 0, 24)
	                    button.AutoButtonColor = false
	                    button.Font = Enum.Font.SourceSans
	                    button.Text = ""
	                    button.TextColor3 = Color3.fromRGB(0, 0, 0)
	                    button.TextSize = 14.000
	        
	                    buttonCorner.CornerRadius = UDim.new(0, 2)
	                    buttonCorner.Name = "buttonCorner"
	                    buttonCorner.Parent = button
	        
	                    buttonBackground.Name = "buttonBackground"
	                    buttonBackground.Parent = button
	                    buttonBackground.AnchorPoint = Vector2.new(0.5, 0.5)
	                    buttonBackground.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                    buttonBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
	                    buttonBackground.Size = UDim2.new(0, (NewSizeX - 2) - Amnt, 0, 22)
	        
	                    buttonGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	                    buttonGradient.Rotation = 90
	                    buttonGradient.Name = "buttonGradient"
	                    buttonGradient.Parent = buttonBackground
	        
	                    buttonBackCorner.CornerRadius = UDim.new(0, 2)
	                    buttonBackCorner.Name = "buttonBackCorner"
	                    buttonBackCorner.Parent = buttonBackground
	        
	                    buttonLabel.Name = "buttonLabel"
	                    buttonLabel.Parent = buttonBackground
	                    buttonLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	                    buttonLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                    buttonLabel.BackgroundTransparency = 1.000
	                    buttonLabel.ClipsDescendants = true
	                    buttonLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	                    buttonLabel.Size = UDim2.new(0, NewSizeX - 2, 0, 22)
	                    buttonLabel.Font = Enum.Font.Code
	                    buttonLabel.Text = text
	                    buttonLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	                    buttonLabel.TextSize = 14.000
	                    buttonLabel.RichText = true

	                    UpdatePageSize()
	        
	                    button.MouseEnter:Connect(function()
	                        TweenService:Create(button, TweenTable["hover"], {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
	                    end)
	                    button.MouseLeave:Connect(function()
	                        TweenService:Create(button, TweenTable["hover"], {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play()
	                    end)
	        
	                    button.MouseButton1Down:Connect(function()
	                        TweenService:Create(buttonLabel, TweenTable["hover"], {TextColor3 = Color3.fromRGB(150, 0, 0)}):Play()
	                    end)
	                    button.MouseButton1Up:Connect(function()
	                        TweenService:Create(buttonLabel, TweenTable["hover"], {TextColor3 = Color3.fromRGB(190, 190, 190)}):Play()
	                    end)
	        
	                    button.MouseButton1Click:Connect(function()
	                        callback_2()
	                    end)

	                    local ButtonFunctions2 = {}
	                    function ButtonFunctions2:Fire()
	                        callback_2()

	                        return ButtonFunctions2
	                    end
	                    --
	                    function ButtonFunctions2:Hide()
	                        button.Visible = false

	                        return ButtonFunctions2
	                    end
	                    --
	                    function ButtonFunctions2:Show()
	                        button.Visible = true

	                        return ButtonFunctions2
	                    end
	                    --
	                    function ButtonFunctions2:Text(text)
	                        text = text or "button new text"
	                        buttonLabel.Text = text

	                        return ButtonFunctions2
	                    end
	                    --
	                    function ButtonFunctions2:Remove()
	                        button:Destroy()

	                        return ButtonFunctions2
	                    end
	                    --
	                    function ButtonFunctions2:SetFunction(new)
	                        new = new or function() end
	                        callback_2 = new

	                        return ButtonFunctions2
	                    end
	                    return ButtonFunctions2 and ButtonFunctions
	                elseif Amnt > 4 then
	                    print("more than 4 buttons are not supported.")
	                end
	                return ButtonFunctions
	            end
	            --
	            function ButtonFunctions:Fire()
	                callback()

	                return ButtonFunctions
	            end
	            --
	            function ButtonFunctions:Hide()
	                button.Visible = false

	                return ButtonFunctions
	            end
	            --
	            function ButtonFunctions:Show()
	                button.Visible = true

	                return ButtonFunctions
	            end
	            --
	            function ButtonFunctions:Text(text)
	                text = text or "button new text"
	                buttonLabel.Text = text

	                return ButtonFunctions
	            end
	            --
	            function ButtonFunctions:Remove()
	                button:Destroy()

	                return ButtonFunctions
	            end
	            --
	            function ButtonFunctions:SetFunction(new)
	                new = new or function() end
	                callback = new

	                return ButtonFunctions
	            end
	            return ButtonFunctions
	        end
	        --

	        function Components:NewSection(text)
	            text = text or "section"

	            local sectionFrame = Instance.new("Frame")
	            local sectionLayout = Instance.new("UIListLayout")
	            local leftBar = Instance.new("Frame")
	            local sectionLabel = Instance.new("TextLabel")
	            local sectionPadding = Instance.new("UIPadding")
	            local rightBar = Instance.new("Frame")

	            sectionFrame.Name = "sectionFrame"
	            sectionFrame.Parent = page
	            sectionFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            sectionFrame.BackgroundTransparency = 1.000
	            sectionFrame.ClipsDescendants = true
	            sectionFrame.Size = UDim2.new(0, 396, 0, 18)

	            sectionLayout.Name = "sectionLayout"
	            sectionLayout.Parent = sectionFrame
	            sectionLayout.FillDirection = Enum.FillDirection.Horizontal
	            sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            sectionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	            sectionLayout.Padding = UDim.new(0, 4)


	            sectionLabel.Name = "sectionLabel"
	            sectionLabel.Parent = sectionFrame
	            sectionLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            sectionLabel.BackgroundTransparency = 1.000
	            sectionLabel.ClipsDescendants = true
	            sectionLabel.Position = UDim2.new(0.0252525248, 0, 0.020833334, 0)
	            sectionLabel.Size = UDim2.new(0, 0, 0, 18)
	            sectionLabel.Font = Enum.Font.Code
	            sectionLabel.LineHeight = 1
	            sectionLabel.Text = text
	            sectionLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	            sectionLabel.TextSize = 14.000
	            sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
	            sectionLabel.RichText = true

	            sectionPadding.Name = "sectionPadding"
	            sectionPadding.Parent = sectionLabel
	            sectionPadding.PaddingBottom = UDim.new(0, 6)
	            sectionPadding.PaddingLeft = UDim.new(0, 0)
	            sectionPadding.PaddingRight = UDim.new(0, 6)
	            sectionPadding.PaddingTop = UDim.new(0, 6)

	            rightBar.Name = "rightBar"
	            rightBar.Parent = sectionFrame
	            rightBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	            rightBar.BorderSizePixel = 0
	            rightBar.Position = UDim2.new(0.308080822, 0, 0.479166657, 0)
	            rightBar.Size = UDim2.new(0, 403, 0, 1)
	            UpdatePageSize()

	            local NewSectionSize = TextService:GetTextSize(sectionLabel.Text, sectionLabel.TextSize, sectionLabel.Font, Vector2.new(math.huge,math.huge))
	            sectionLabel.Size = UDim2.new(0, NewSectionSize.X, 0, 18)

	            local SectionFunctions = {}
	            function SectionFunctions:Text(new)
	                new = new or text
	                sectionLabel.Text = new

	                local NewSectionSize = TextService:GetTextSize(sectionLabel.Text, sectionLabel.TextSize, sectionLabel.Font, Vector2.new(math.huge,math.huge))
	                sectionLabel.Size = UDim2.new(0, NewSectionSize.X, 0, 18)

	                return SectionFunctions
	            end
	            function SectionFunctions:Hide()
	                sectionFrame.Visible = false
	                return SectionFunctions
	            end
	            function SectionFunctions:Show()
	                sectionFrame.Visible = true
	                return SectionFunctions
	            end
	            function SectionFunctions:Remove()
	                sectionFrame:Destroy()
	                return SectionFunctions
	            end
	            --
	            return SectionFunctions
	        end

	        --

	        function Components:NewToggle(text, default, callback)
	            text = text or "toggle"
	            default = default or false
	            callback = callback or function() end

	            local toggleButton = Instance.new("TextButton")
	            local toggleLayout = Instance.new("UIListLayout")
	            local toggleEdge = Instance.new("Frame")
	            local toggleEdgeCorner = Instance.new("UICorner")
	            local toggle = Instance.new("Frame")
	            local toggleCorner = Instance.new("UICorner")
	            local toggleGradient = Instance.new("UIGradient")
	            local toggleDesign = Instance.new("Frame")
	            local toggleDesignCorner = Instance.new("UICorner")
	            local toggleDesignGradient = Instance.new("UIGradient")
	            local toggleLabel = Instance.new("TextLabel")
	            local toggleLabelPadding = Instance.new("UIPadding")
	            local Extras = Instance.new("Folder")
	            local ExtrasLayout = Instance.new("UIListLayout")

	            toggleButton.Name = "toggleButton"
	            toggleButton.Parent = page
	            toggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            toggleButton.BackgroundTransparency = 1.000
	            toggleButton.ClipsDescendants = false
	            toggleButton.Size = UDim2.new(0, 396, 0, 22)
	            toggleButton.Font = Enum.Font.Code
	            toggleButton.Text = ""
	            toggleButton.TextColor3 = Color3.fromRGB(190, 190, 190)
	            toggleButton.TextSize = 14.000
	            toggleButton.TextXAlignment = Enum.TextXAlignment.Left

	            toggleLayout.Name = "toggleLayout"
	            toggleLayout.Parent = toggleButton
	            toggleLayout.FillDirection = Enum.FillDirection.Horizontal
	            toggleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            toggleLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	            toggleEdge.Name = "toggleEdge"
	            toggleEdge.Parent = toggleButton
	            toggleEdge.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	            toggleEdge.Size = UDim2.new(0, 18, 0, 18)

	            toggleEdgeCorner.CornerRadius = UDim.new(0, 2)
	            toggleEdgeCorner.Name = "toggleEdgeCorner"
	            toggleEdgeCorner.Parent = toggleEdge

	            toggle.Name = "toggle"
	            toggle.Parent = toggleEdge
	            toggle.AnchorPoint = Vector2.new(0.5, 0.5)
	            toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            toggle.Position = UDim2.new(0.5, 0, 0.5, 0)
	            toggle.Size = UDim2.new(0, 16, 0, 16)

	            toggleCorner.CornerRadius = UDim.new(0, 2)
	            toggleCorner.Name = "toggleCorner"
	            toggleCorner.Parent = toggle

	            toggleGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	            toggleGradient.Rotation = 90
	            toggleGradient.Name = "toggleGradient"
	            toggleGradient.Parent = toggle

	            toggleDesign.Name = "toggleDesign"
	            toggleDesign.Parent = toggle
	            toggleDesign.AnchorPoint = Vector2.new(0.5, 0.5)
	            toggleDesign.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            toggleDesign.BackgroundTransparency = 1.000
	            toggleDesign.Position = UDim2.new(0.5, 0, 0.5, 0)

	            toggleDesignCorner.CornerRadius = UDim.new(0, 2)
	            toggleDesignCorner.Name = "toggleDesignCorner"
	            toggleDesignCorner.Parent = toggleDesign

	            toggleDesignGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(120, 0, 0)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(100, 0, 0))}
	            toggleDesignGradient.Rotation = 90
	            toggleDesignGradient.Name = "toggleDesignGradient"
	            toggleDesignGradient.Parent = toggleDesign

	            toggleLabel.Name = "toggleLabel"
	            toggleLabel.Parent = toggleButton
	            toggleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            toggleLabel.BackgroundTransparency = 1.000
	            toggleLabel.Position = UDim2.new(0.0454545468, 0, 0, 0)
	            toggleLabel.Size = UDim2.new(0, 377, 0, 22)
	            toggleLabel.Font = Enum.Font.Code
	            toggleLabel.LineHeight = 1.150
	            toggleLabel.Text = text
	            toggleLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	            toggleLabel.TextSize = 14.000
	            toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
	            toggleLabel.RichText = true

	            toggleLabelPadding.Name = "toggleLabelPadding"
	            toggleLabelPadding.Parent = toggleLabel
	            toggleLabelPadding.PaddingLeft = UDim.new(0, 6)

	            Extras.Name = "Extras"
	            Extras.Parent = toggleButton

	            ExtrasLayout.Name = "ExtrasLayout"
	            ExtrasLayout.Parent = Extras
	            ExtrasLayout.FillDirection = Enum.FillDirection.Horizontal
	            ExtrasLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	            ExtrasLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            ExtrasLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	            ExtrasLayout.Padding = UDim.new(0, 2)

	            local NewToggleLabelSize = TextService:GetTextSize(toggleLabel.Text, toggleLabel.TextSize, toggleLabel.Font, Vector2.new(math.huge,math.huge))
	            toggleLabel.Size = UDim2.new(0, NewToggleLabelSize.X + 6, 0, 22)

	            toggleButton.MouseEnter:Connect(function()
	                TweenService:Create(toggleLabel, TweenTable["hover"], {TextColor3 = Color3.fromRGB(210, 210, 210)}):Play()
	            end)
	            toggleButton.MouseLeave:Connect(function()
	                TweenService:Create(toggleLabel, TweenTable["hover"], {TextColor3 = Color3.fromRGB(190, 190, 190)}):Play()
	            end)

	            CreateTween("toggle_form", 0.13)
	            local On = default
	            if default then
	                On = true
	            else
	                On = false
	            end
	            toggleButton.MouseButton1Click:Connect(function()
	                On = not On
	                local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
	                local Transparency = On and 0 or 1
	                TweenService:Create(toggleDesign, TweenTable["toggle_form"], {Size = SizeOn}):Play()
	                TweenService:Create(toggleDesign, TweenTable["toggle_form"], {BackgroundTransparency = Transparency}):Play()
	                callback(On)
	            end)

	            local ToggleFunctions = {}
	            function ToggleFunctions:Text(new)
	                new = new or text
	                toggleLabel.Text = new
	                return ToggleFunctions
	            end
	            --
	            function ToggleFunctions:Hide()
	                toggleButton.Visible = false
	                return ToggleFunctions
	            end
	            --
	            function ToggleFunctions:Show()
	                toggleButton.Visible = true
	                return ToggleFunctions
	            end   
	            --         
	            function ToggleFunctions:Change()
	                On = not On
	                local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
	                local Transparency = On and 0 or 1
	                TweenService:Create(toggleDesign, TweenTable["toggle_form"], {Size = SizeOn}):Play()
	                TweenService:Create(toggleDesign, TweenTable["toggle_form"], {BackgroundTransparency = Transparency}):Play()
	                callback(On)
	                return ToggleFunctions
	            end
	            --
	            function ToggleFunctions:Remove()
	                toggleButton:Destroy()
	                return ToggleFunction
	            end
	            --
	            function ToggleFunctions:Set(state)
	                On = state
	                local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
	                local Transparency = On and 0 or 1
	                TweenService:Create(toggleDesign, TweenTable["toggle_form"], {Size = SizeOn}):Play()
	                TweenService:Create(toggleDesign, TweenTable["toggle_form"], {BackgroundTransparency = Transparency}):Play()
	                callback(On)
	                return ToggleFunctions
	            end
	            --
	            local callback_t
	            function ToggleFunctions:SetFunction(new)
	                new = new or function() end
	                callback = new
	                callback_t = new
	                return ToggleFunctions
	            end
	            UpdatePageSize()
	            --
	            function ToggleFunctions:AddKeybind(default_t)
	                callback_t = callback
	                default_t = default_t or Enum.KeyCode.P
	                
	                local keybind = Instance.new("TextButton")
	                local keybindCorner = Instance.new("UICorner")
	                local keybindBackground = Instance.new("Frame")
	                local keybindGradient = Instance.new("UIGradient")
	                local keybindBackCorner = Instance.new("UICorner")
	                local keybindButtonLabel = Instance.new("TextLabel")
	                local keybindLabelStraint = Instance.new("UISizeConstraint")
	                local keybindBackgroundStraint = Instance.new("UISizeConstraint")
	                local keybindStraint = Instance.new("UISizeConstraint")

	                keybind.Name = "keybind"
	                keybind.Parent = Extras
	                keybind.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	                keybind.Position = UDim2.new(0.780303001, 0, 0, 0)
	                keybind.Size = UDim2.new(0, 87, 0, 22)
	                keybind.AutoButtonColor = false
	                keybind.Font = Enum.Font.SourceSans
	                keybind.Text = ""
	                keybind.TextColor3 = Color3.fromRGB(0, 0, 0)
	                keybind.TextSize = 14.000
	                keybind.Active = false
	    
	                keybindCorner.CornerRadius = UDim.new(0, 2)
	                keybindCorner.Name = "keybindCorner"
	                keybindCorner.Parent = keybind
	    
	                keybindBackground.Name = "keybindBackground"
	                keybindBackground.Parent = keybind
	                keybindBackground.AnchorPoint = Vector2.new(0.5, 0.5)
	                keybindBackground.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                keybindBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
	                keybindBackground.Size = UDim2.new(0, 85, 0, 20)
	    
	                keybindGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	                keybindGradient.Rotation = 90
	                keybindGradient.Name = "keybindGradient"
	                keybindGradient.Parent = keybindBackground
	    
	                keybindBackCorner.CornerRadius = UDim.new(0, 2)
	                keybindBackCorner.Name = "keybindBackCorner"
	                keybindBackCorner.Parent = keybindBackground
	    
	                keybindButtonLabel.Name = "keybindButtonLabel"
	                keybindButtonLabel.Parent = keybindBackground
	                keybindButtonLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	                keybindButtonLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                keybindButtonLabel.BackgroundTransparency = 1.000
	                keybindButtonLabel.ClipsDescendants = true
	                keybindButtonLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	                keybindButtonLabel.Size = UDim2.new(0, 85, 0, 20)
	                keybindButtonLabel.Font = Enum.Font.Code
	                keybindButtonLabel.Text = ". . ."
	                keybindButtonLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	                keybindButtonLabel.TextSize = 14.000
	                keybindButtonLabel.RichText = true
	    
	                keybindLabelStraint.Name = "keybindLabelStraint"
	                keybindLabelStraint.Parent = keybindButtonLabel
	                keybindLabelStraint.MinSize = Vector2.new(28, 20)
	    
	                keybindBackgroundStraint.Name = "keybindBackgroundStraint"
	                keybindBackgroundStraint.Parent = keybindBackground
	                keybindBackgroundStraint.MinSize = Vector2.new(28, 20)
	    
	                keybindStraint.Name = "keybindStraint"
	                keybindStraint.Parent = keybind
	                keybindStraint.MinSize = Vector2.new(30, 22)
	    
	                local Shortcuts = {
	                    Return = "enter"
	                }
	    
	                keybindButtonLabel.Text = Shortcuts[default_t.Name] or default_t.Name
	                CreateTween("keybind", 0.08)
	                
	                local NewKeybindSize = TextService:GetTextSize(keybindButtonLabel.Text, keybindButtonLabel.TextSize, keybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
	                keybindButtonLabel.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
	                keybindBackground.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
	                keybind.Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)
	                
	                function ResizeKeybind()
	                    NewKeybindSize = TextService:GetTextSize(keybindButtonLabel.Text, keybindButtonLabel.TextSize, keybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
	                    TweenService:Create(keybindButtonLabel, TweenTable["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
	                    TweenService:Create(keybindBackground, TweenTable["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
	                    TweenService:Create(keybind, TweenTable["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)}):Play()
	                end
	                keybindButtonLabel:GetPropertyChangedSignal("Text"):Connect(ResizeKeybind)
	                ResizeKeybind()
	                UpdatePageSize()
	    
	                local ChosenKey = default_t.Name
	    
	                keybind.MouseButton1Click:Connect(function()
	                    keybindButtonLabel.Text = ". . ."
	                    local InputWait = UserInputService.InputBegan:wait()
	                    if UserInputService.WindowFocused and InputWait.KeyCode.Name ~= "Unknown" then
	                        local Result = Shortcuts[InputWait.KeyCode.Name] or InputWait.KeyCode.Name
	                        keybindButtonLabel.Text = Result
	                        ChosenKey = InputWait.KeyCode.Name
	                    end
	                end)
	    
	                local ChatTextBox = Player.PlayerGui.Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar
	                if UserInputService.WindowFocused then
	                    UserInputService.InputBegan:Connect(function(c, p)
	                        if not p then
	                            if c.KeyCode.Name == ChosenKey and not ChatTextBox:IsFocused() then
	                                On = not On
	                                local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
	                                local Transparency = On and 0 or 1
	                                TweenService:Create(toggleDesign, TweenTable["toggle_form"], {Size = SizeOn}):Play()
	                                TweenService:Create(toggleDesign, TweenTable["toggle_form"], {BackgroundTransparency = Transparency}):Play()
	                                callback_t(On)
	                                return
	                            end
	                        end
	                    end)
	                end
	    
	                local ExtraKeybindFunctions = {}
	                function ExtraKeybindFunctions:SetKey(new)
	                    new = new or ChosenKey.Name
	                    ChosenKey = new.Name
	                    keybindButtonLabel.Text = new.Name
	                    return ExtraKeybindFunctions
	                end
	                --
	                function ExtraKeybindFunctions:Fire()
	                    callback_t(ChosenKey)
	                    return ExtraKeybindFunctions
	                end
	                --
	                function ExtraKeybindFunctions:SetFunction(new)
	                    new = new or function() end
	                    callback_t = new
	                    return ExtraKeybindFunctions 
	                end
	                --
	                function ExtraKeybindFunctions:Hide()
	                    keybindFrame.Visible = false
	                    return ExtraKeybindFunctions
	                end
	                --
	                function ExtraKeybindFunctions:Show()
	                    keybindFrame.Visible = true
	                    return ExtraKeybindFunctions
	                end
	                return ExtraKeybindFunctions and ToggleFunctions
	            end

	            if default then
	                toggleDesign.Size = UDim2.new(0, 12, 0, 12)
	                toggleDesign.BackgroundTransparency = 0
	                callback(true)
	            end
	            return ToggleFunctions
	        end

	        function Components:NewKeybind(text, default, callback)
	            text = text or "keybind"
	            default = default or Enum.KeyCode.P
	            callback = callback or function() end

	            local keybindFrame = Instance.new("Frame")
	            local keybindButton = Instance.new("TextButton")
	            local keybindLayout = Instance.new("UIListLayout")
	            local keybindLabel = Instance.new("TextLabel")
	            local keybindPadding = Instance.new("UIPadding")
	            local keybindFolder = Instance.new("Folder")
	            local keybindFolderLayout = Instance.new("UIListLayout")
	            local keybind = Instance.new("TextButton")
	            local keybindCorner = Instance.new("UICorner")
	            local keybindBackground = Instance.new("Frame")
	            local keybindGradient = Instance.new("UIGradient")
	            local keybindBackCorner = Instance.new("UICorner")
	            local keybindButtonLabel = Instance.new("TextLabel")
	            local keybindLabelStraint = Instance.new("UISizeConstraint")
	            local keybindBackgroundStraint = Instance.new("UISizeConstraint")
	            local keybindStraint = Instance.new("UISizeConstraint")

	            keybindFrame.Name = "keybindFrame"
	            keybindFrame.Parent = page
	            keybindFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            keybindFrame.BackgroundTransparency = 1.000
	            keybindFrame.ClipsDescendants = true
	            keybindFrame.Size = UDim2.new(0, 396, 0, 24)

	            keybindButton.Name = "keybindButton"
	            keybindButton.Parent = keybindFrame
	            keybindButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            keybindButton.BackgroundTransparency = 1.000
	            keybindButton.Size = UDim2.new(0, 396, 0, 24)
	            keybindButton.AutoButtonColor = false
	            keybindButton.Font = Enum.Font.SourceSans
	            keybindButton.Text = ""
	            keybindButton.TextColor3 = Color3.fromRGB(0, 0, 0)
	            keybindButton.TextSize = 14.000

	            keybindLayout.Name = "keybindLayout"
	            keybindLayout.Parent = keybindButton
	            keybindLayout.FillDirection = Enum.FillDirection.Horizontal
	            keybindLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            keybindLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	            keybindLayout.Padding = UDim.new(0, 4)

	            keybindLabel.Name = "keybindLabel"
	            keybindLabel.Parent = keybindButton
	            keybindLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            keybindLabel.BackgroundTransparency = 1.000
	            keybindLabel.Size = UDim2.new(0, 396, 0, 24)
	            keybindLabel.Font = Enum.Font.Code
	            keybindLabel.Text = text
	            keybindLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	            keybindLabel.TextSize = 14.000
	            keybindLabel.TextWrapped = true
	            keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
	            keybindLabel.RichText = true

	            keybindPadding.Name = "keybindPadding"
	            keybindPadding.Parent = keybindLabel
	            keybindPadding.PaddingBottom = UDim.new(0, 6)
	            keybindPadding.PaddingLeft = UDim.new(0, 2)
	            keybindPadding.PaddingRight = UDim.new(0, 6)
	            keybindPadding.PaddingTop = UDim.new(0, 6)

	            keybindFolder.Name = "keybindFolder"
	            keybindFolder.Parent = keybindFrame

	            keybindFolderLayout.Name = "keybindFolderLayout"
	            keybindFolderLayout.Parent = keybindFolder
	            keybindFolderLayout.FillDirection = Enum.FillDirection.Horizontal
	            keybindFolderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	            keybindFolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            keybindFolderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	            keybindFolderLayout.Padding = UDim.new(0, 4)

	            keybind.Name = "keybind"
	            keybind.Parent = keybindFolder
	            keybind.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	            keybind.Position = UDim2.new(0.780303001, 0, 0, 0)
	            keybind.Size = UDim2.new(0, 87, 0, 22)
	            keybind.AutoButtonColor = false
	            keybind.Font = Enum.Font.SourceSans
	            keybind.Text = ""
	            keybind.TextColor3 = Color3.fromRGB(0, 0, 0)
	            keybind.TextSize = 14.000
	            keybind.Active = false

	            keybindCorner.CornerRadius = UDim.new(0, 2)
	            keybindCorner.Name = "keybindCorner"
	            keybindCorner.Parent = keybind

	            keybindBackground.Name = "keybindBackground"
	            keybindBackground.Parent = keybind
	            keybindBackground.AnchorPoint = Vector2.new(0.5, 0.5)
	            keybindBackground.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            keybindBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
	            keybindBackground.Size = UDim2.new(0, 85, 0, 20)

	            keybindGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	            keybindGradient.Rotation = 90
	            keybindGradient.Name = "keybindGradient"
	            keybindGradient.Parent = keybindBackground

	            keybindBackCorner.CornerRadius = UDim.new(0, 2)
	            keybindBackCorner.Name = "keybindBackCorner"
	            keybindBackCorner.Parent = keybindBackground

	            keybindButtonLabel.Name = "keybindButtonLabel"
	            keybindButtonLabel.Parent = keybindBackground
	            keybindButtonLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	            keybindButtonLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            keybindButtonLabel.BackgroundTransparency = 1.000
	            keybindButtonLabel.ClipsDescendants = true
	            keybindButtonLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	            keybindButtonLabel.Size = UDim2.new(0, 85, 0, 20)
	            keybindButtonLabel.Font = Enum.Font.Code
	            keybindButtonLabel.Text = ". . ."
	            keybindButtonLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	            keybindButtonLabel.TextSize = 14.000
	            keybindButtonLabel.RichText = true

	            keybindLabelStraint.Name = "keybindLabelStraint"
	            keybindLabelStraint.Parent = keybindButtonLabel
	            keybindLabelStraint.MinSize = Vector2.new(28, 20)

	            keybindBackgroundStraint.Name = "keybindBackgroundStraint"
	            keybindBackgroundStraint.Parent = keybindBackground
	            keybindBackgroundStraint.MinSize = Vector2.new(28, 20)

	            keybindStraint.Name = "keybindStraint"
	            keybindStraint.Parent = keybind
	            keybindStraint.MinSize = Vector2.new(30, 22)

	            local Shortcuts = {
	                Return = "enter"
	            }

	            keybindButtonLabel.Text = Shortcuts[default.Name] or default.Name
	            CreateTween("keybind", 0.08)
	            
	            local NewKeybindSize = TextService:GetTextSize(keybindButtonLabel.Text, keybindButtonLabel.TextSize, keybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
	            keybindButtonLabel.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
	            keybindBackground.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
	            keybind.Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)
	            
	            function ResizeKeybind()
	                NewKeybindSize = TextService:GetTextSize(keybindButtonLabel.Text, keybindButtonLabel.TextSize, keybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
	                TweenService:Create(keybindButtonLabel, TweenTable["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
	                TweenService:Create(keybindBackground, TweenTable["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
	                TweenService:Create(keybind, TweenTable["keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)}):Play()
	            end
	            keybindButtonLabel:GetPropertyChangedSignal("Text"):Connect(ResizeKeybind)
	            ResizeKeybind()

	            local ChosenKey = default
	            keybindButton.MouseButton1Click:Connect(function()
	                keybindButtonLabel.Text = "..."
	                local InputWait = UserInputService.InputBegan:wait()
	                if UserInputService.WindowFocused and InputWait.KeyCode.Name ~= "Unknown" then
	                    local Result = Shortcuts[InputWait.KeyCode.Name] or InputWait.KeyCode.Name
	                    keybindButtonLabel.Text = Result
	                    ChosenKey = InputWait.KeyCode.Name
	                end
	            end)

	            keybind.MouseButton1Click:Connect(function()
	                keybindButtonLabel.Text = ". . ."
	                local InputWait = UserInputService.InputBegan:wait()
	                if UserInputService.WindowFocused and InputWait.KeyCode.Name ~= "Unknown" then
	                    local Result = Shortcuts[InputWait.KeyCode.Name] or InputWait.KeyCode.Name
	                    keybindButtonLabel.Text = Result
	                    ChosenKey = InputWait.KeyCode.Name
	                end
	            end)

	            local ChatTextBox = Player.PlayerGui.Chat.Frame.ChatBarParentFrame.Frame.BoxFrame.Frame.ChatBar
	            if UserInputService.WindowFocused then
	                UserInputService.InputBegan:Connect(function(c, p)
	                    if not p then
	                        if c.KeyCode.Name == ChosenKey and not ChatTextBox:IsFocused() then
	                            callback(ChosenKey)
	                            return
	                        end
	                    end
	                end)
	            end

	            UpdatePageSize()

	            local KeybindFunctions = {}
	            function KeybindFunctions:Fire()
	                callback(ChosenKey)
	                return KeybindFunctions
	            end
	            --
	            function KeybindFunctions:SetFunction(new)
	                new = new or function() end
	                callback = new
	                return KeybindFunctions 
	            end
	            --
	            function KeybindFunctions:SetKey(new)
	                new = new or ChosenKey.Name
	                ChosenKey = new.Name
	                keybindButtonLabel.Text = new.Name
	                return KeybindFunctions
	            end
	            --
	            function KeybindFunctions:Text(new)
	                new = new or keybindLabel.Text
	                keybindLabel.Text = new
	                return KeybindFunctions
	            end
	            --
	            function KeybindFunctions:Hide()
	                keybindFrame.Visible = false
	                return KeybindFunctions
	            end
	            --
	            function KeybindFunctions:Show()
	                keybindFrame.Visible = true
	                return KeybindFunctions
	            end
	            return KeybindFunctions
	        end
	        --
	        function Components:NewTextbox(text, default, place, format, type, autoexec, autoclear, callback)
	            text = text or "text box"
	            default = default or ""
	            place = place or ""
	            format = format or "all" -- all, numbers, lower, upper
	            type = type or "small" -- small, medium, large
	            autoexec = autoexec or true
	            autoclear = autoclear or false
	            callback = callback or function() end

	            if type == "small" then
	                local textboxFrame = Instance.new("Frame")
	                local textboxFolder = Instance.new("Folder")
	                local textboxFolderLayout = Instance.new("UIListLayout")
	                local textbox = Instance.new("Frame")
	                local textboxLayout = Instance.new("UIListLayout")
	                local textboxStraint = Instance.new("UISizeConstraint")
	                local textboxCorner = Instance.new("UICorner")
	                local textboxTwo = Instance.new("Frame")
	                local textboxTwoStraint = Instance.new("UISizeConstraint")
	                local textboxTwoGradient = Instance.new("UIGradient")
	                local textboxTwoCorner = Instance.new("UICorner")
	                local textBoxValues = Instance.new("TextBox")
	                local textBoxValuesStraint = Instance.new("UISizeConstraint")
	                local textboxTwoLayout = Instance.new("UIListLayout")
	                local textboxLabel = Instance.new("TextLabel")
	                local textboxPadding = Instance.new("UIPadding")
	                local textBoxValuesPadding = Instance.new("UIPadding")
	    
	                textboxFrame.Name = "textboxFrame"
	                textboxFrame.Parent = page
	                textboxFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textboxFrame.BackgroundTransparency = 1.000
	                textboxFrame.ClipsDescendants = true
	                textboxFrame.Size = UDim2.new(0, 396, 0, 24)
	    
	                textboxFolder.Name = "textboxFolder"
	                textboxFolder.Parent = textboxFrame
	    
	                textboxFolderLayout.Name = "textboxFolderLayout"
	                textboxFolderLayout.Parent = textboxFolder
	                textboxFolderLayout.FillDirection = Enum.FillDirection.Horizontal
	                textboxFolderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	                textboxFolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	                textboxFolderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	                textboxFolderLayout.Padding = UDim.new(0, 4)
	    
	                textbox.Name = "textbox"
	                textbox.Parent = textboxFolder
	                textbox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	                textbox.Size = UDim2.new(0, 133, 0, 22)
	    
	                textboxLayout.Name = "textboxLayout"
	                textboxLayout.Parent = textbox
	                textboxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	                textboxLayout.SortOrder = Enum.SortOrder.LayoutOrder
	                textboxLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	    
	                textboxStraint.Name = "textboxStraint"
	                textboxStraint.Parent = textbox
	                textboxStraint.MinSize = Vector2.new(50, 22)
	    
	                textboxCorner.CornerRadius = UDim.new(0, 2)
	                textboxCorner.Name = "textboxCorner"
	                textboxCorner.Parent = textbox
	    
	                textboxTwo.Name = "textboxTwo"
	                textboxTwo.Parent = textbox
	                textboxTwo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textboxTwo.Size = UDim2.new(0, 131, 0, 20)
	    
	                textboxTwoStraint.Name = "textboxTwoStraint"
	                textboxTwoStraint.Parent = textboxTwo
	                textboxTwoStraint.MinSize = Vector2.new(48, 20)
	    
	                textboxTwoGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	                textboxTwoGradient.Rotation = 90
	                textboxTwoGradient.Name = "textboxTwoGradient"
	                textboxTwoGradient.Parent = textboxTwo
	    
	                textboxTwoCorner.CornerRadius = UDim.new(0, 2)
	                textboxTwoCorner.Name = "textboxTwoCorner"
	                textboxTwoCorner.Parent = textboxTwo
	    
	                textBoxValues.Name = "textBoxValues"
	                textBoxValues.Parent = textboxTwo
	                textBoxValues.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textBoxValues.BackgroundTransparency = 1.000
	                textBoxValues.Position = UDim2.new(0.664141417, 0, 0.0416666679, 0)
	                textBoxValues.Size = UDim2.new(0, 131, 0, 20)
	                textBoxValues.Font = Enum.Font.Code
	                textBoxValues.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
	                textBoxValues.PlaceholderText = place
	                textBoxValues.Text = ""
	                textBoxValues.TextColor3 = Color3.fromRGB(190, 190, 190)
	                textBoxValues.TextSize = 14.000
	                textBoxValues.ClearTextOnFocus = autoclear
	                textBoxValues.ClipsDescendants = true
	                textBoxValues.TextXAlignment = Enum.TextXAlignment.Right

	                textBoxValuesPadding.Name = "textBoxValuesPadding"
	                textBoxValuesPadding.Parent = textBoxValues
	                textBoxValuesPadding.PaddingBottom = UDim.new(0, 6)
	                textBoxValuesPadding.PaddingLeft = UDim.new(0, 6)
	                textBoxValuesPadding.PaddingRight = UDim.new(0, 4)
	                textBoxValuesPadding.PaddingTop = UDim.new(0, 6)
	    
	                textBoxValuesStraint.Name = "textBoxValuesStraint"
	                textBoxValuesStraint.Parent = textBoxValues
	                textBoxValuesStraint.MinSize = Vector2.new(48, 20)
	    
	                textboxTwoLayout.Name = "textboxTwoLayout"
	                textboxTwoLayout.Parent = textboxTwo
	                textboxTwoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	                textboxTwoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	                textboxTwoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	    
	                textboxLabel.Name = "textboxLabel"
	                textboxLabel.Parent = textboxFrame
	                textboxLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textboxLabel.BackgroundTransparency = 1.000
	                textboxLabel.Size = UDim2.new(0, 396, 0, 24)
	                textboxLabel.Font = Enum.Font.Code
	                textboxLabel.Text = text
	                textboxLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	                textboxLabel.TextSize = 14.000
	                textboxLabel.TextWrapped = true
	                textboxLabel.TextXAlignment = Enum.TextXAlignment.Left
	                textboxLabel.RichText = true
	    
	                textboxPadding.Name = "textboxPadding"
	                textboxPadding.Parent = textboxLabel
	                textboxPadding.PaddingBottom = UDim.new(0, 6)
	                textboxPadding.PaddingLeft = UDim.new(0, 2)
	                textboxPadding.PaddingRight = UDim.new(0, 6)
	                textboxPadding.PaddingTop = UDim.new(0, 6)
	    
	                local ForcedMinSize = TextService:GetTextSize(textBoxValues.PlaceholderText, textBoxValues.TextSize, textBoxValues.Font, Vector2.new(math.huge,math.huge))
	                local ForcedMaxSize = TextService:GetTextSize(textboxLabel.Text, textboxLabel.TextSize, textboxLabel.Font, Vector2.new(math.huge,math.huge))
	                local NewTextboxSize = TextService:GetTextSize(textBoxValues.Text, textBoxValues.TextSize, textBoxValues.Font, Vector2.new(math.huge,math.huge))

	                CreateTween("TextBox", 0.07)

	                textboxStraint.MinSize = Vector2.new(ForcedMinSize.X + 4, 22)
	                textboxTwoStraint.MinSize = Vector2.new(ForcedMinSize.X + 2, 20)
	                textBoxValuesStraint.MinSize = Vector2.new(ForcedMinSize.X + 2, 20)
	                textboxStraint.MaxSize = Vector2.new(386 - ForcedMaxSize.X, 22)
	                textboxTwoStraint.MaxSize = Vector2.new(388 - ForcedMaxSize.X, 20)
	                textBoxValuesStraint.MaxSize = Vector2.new(388 - ForcedMaxSize.X, 20)
	                
	                function ResizeTextStraints()
	                    ForcedMinSize = TextService:GetTextSize(textBoxValues.PlaceholderText, textBoxValues.TextSize, textBoxValues.Font, Vector2.new(math.huge,math.huge))
	                    if place ~= "" then
	                        textboxStraint.MinSize = Vector2.new(ForcedMinSize.X + 10, 22)
	                        textboxTwoStraint.MinSize = Vector2.new(ForcedMinSize.X + 8, 20)
	                        textBoxValuesStraint.MinSize = Vector2.new(ForcedMinSize.X + 8, 20)
	                    else
	                        textboxStraint.MinSize = Vector2.new(28, 22)
	                        textboxTwoStraint.MinSize = Vector2.new(26, 20)
	                        textBoxValuesStraint.MinSize = Vector2.new(26, 20)
	                    end
	                end
	                function ResizeTextBox()
	                    NewTextboxSize = TextService:GetTextSize(textBoxValues.Text, textBoxValues.TextSize, textBoxValues.Font, Vector2.new(math.huge,math.huge))
	                    if NewTextboxSize.X < (396 - ForcedMaxSize.X) - 10 then
	                        TweenService:Create(textBoxValues, TweenTable["TextBox"], {Size = UDim2.new(0, NewTextboxSize.X + 8, 0, 20)}):Play()
	                        TweenService:Create(textboxTwo, TweenTable["TextBox"], {Size = UDim2.new(0, NewTextboxSize.X + 8, 0, 20)}):Play()
	                        TweenService:Create(textbox, TweenTable["TextBox"], {Size = UDim2.new(0, NewTextboxSize.X + 10, 0, 22)}):Play()
	                    else
	                        TweenService:Create(textBoxValues, TweenTable["TextBox"], {Size = UDim2.new(0, (396 - ForcedMaxSize.X) - 12, 0, 20)}):Play()
	                        TweenService:Create(textboxTwo, TweenTable["TextBox"], {Size = UDim2.new(0, (396 - ForcedMaxSize.X) - 12, 0, 20)}):Play()
	                        TweenService:Create(textbox, TweenTable["TextBox"], {Size = UDim2.new(0, (396 - ForcedMaxSize.X) - 10, 0, 22)}):Play()
	                    end
	                end
	                function SetMaxSize()
	                    ForcedMaxSize = TextService:GetTextSize(textboxLabel.Text, textboxLabel.TextSize, textboxLabel.Font, Vector2.new(math.huge,math.huge))
	                    local def = 396 - ForcedMaxSize.X
	                    textboxStraint.MaxSize = Vector2.new(def - 10, 22)
	                    textboxTwoStraint.MaxSize = Vector2.new(def - 12, 20)
	                    textBoxValuesStraint.MaxSize = Vector2.new(def - 12, 20)
	                end

	                ResizeTextBox()
	                ResizeTextStraints()
	                SetMaxSize()
	                UpdatePageSize()

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(ResizeTextBox)
	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(SetMaxSize)
	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(ResizeTextStraints)
	                textBoxValues:GetPropertyChangedSignal("PlaceholderText"):Connect(ResizeTextStraints)
	                textBoxValues:GetPropertyChangedSignal("PlaceholderText"):Connect(SetMaxSize)
	                textBoxValues:GetPropertyChangedSignal("PlaceholderText"):Connect(ResizeTextBox)
	                textboxLabel:GetPropertyChangedSignal("Text"):Connect(SetMaxSize)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "numbers" then
	                        textBoxValues.Text = textBoxValues.Text:gsub("%D+", "")
	                    end
	                end)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "lower" then
	                        textBoxValues.Text = textBoxValues.Text:lower()
	                    end
	                end)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "upper" then
	                        textBoxValues.Text = textBoxValues.Text:upper()
	                    end
	                end)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "all" or format == "" then
	                        textBoxValues.Text = textBoxValues.Text
	                    end
	                end)

	                textboxFrame.MouseEnter:Connect(function()
	                    TweenService:Create(textboxLabel, TweenTable["TextBox"], {TextColor3 = Color3.fromRGB(210, 210, 210)}):Play()
	                end)

	                textboxFrame.MouseLeave:Connect(function()
	                    TweenService:Create(textboxLabel, TweenTable["TextBox"], {TextColor3 = Color3.fromRGB(190, 190, 190)}):Play()
	                end)

	                textBoxValues.Focused:Connect(function()
	                    textBoxValues:GetPropertyChangedSignal("Text"):Connect(ResizeTextBox)
	                    TweenService:Create(textbox, TweenTable["TextBox"], {BackgroundColor3 = Color3.fromRGB(150, 0, 0)}):Play()
	                end)

	                textBoxValues.FocusLost:Connect(function()
	                    TweenService:Create(textbox, TweenTable["TextBox"], {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
	                end)

	                textBoxValues.FocusLost:Connect(function(enterPressed)
	                    if not autoexec then
	                        if enterPressed then
	                            callback(textBoxValues.Text)
	                        end
	                    else
	                        callback(textBoxValues.Text)
	                    end
	                end)

	                UpdatePageSize()

	                local TextboxFunctions = {}
	                function TextboxFunctions:Input(new)
	                    new = new or textBoxValues.Text
	                    textBoxValues = new
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Fire()
	                    callback(textBoxValues.Text)
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:SetFunction(new)
	                    new = new or callback
	                    callback = new
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Text(new)
	                    new = new or textboxLabel.Text
	                    textboxLabel.Text = new
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Hide()
	                    textboxFrame.Visible = false
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Show()
	                    textboxFrame.Visible = true
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Remove()
	                    textboxFrame:Destroy()
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Place(new)
	                    new = new or textBoxValues.PlaceholderText
	                    textBoxValues.PlaceholderText = new
	                    return TextboxFunctions
	                end
	                return TextboxFunctions
	            elseif type == "medium" then
	                local textboxFrame = Instance.new("Frame")
	                local textboxFolder = Instance.new("Folder")
	                local textboxFolderLayout = Instance.new("UIListLayout")
	                local textbox = Instance.new("Frame")
	                local textboxLayout = Instance.new("UIListLayout")
	                local textboxStraint = Instance.new("UISizeConstraint")
	                local textboxCorner = Instance.new("UICorner")
	                local textboxTwo = Instance.new("Frame")
	                local textboxTwoStraint = Instance.new("UISizeConstraint")
	                local textboxTwoGradient = Instance.new("UIGradient")
	                local textboxTwoCorner = Instance.new("UICorner")
	                local textBoxValues = Instance.new("TextBox")
	                local textBoxValuesStraint = Instance.new("UISizeConstraint")
	                local textBoxValuesPadding = Instance.new("UIPadding")
	                local textboxTwoLayout = Instance.new("UIListLayout")
	                local textboxLabel = Instance.new("TextLabel")
	                local textboxPadding = Instance.new("UIPadding")

	                textboxFrame.Name = "textboxFrame"
	                textboxFrame.Parent = page
	                textboxFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textboxFrame.BackgroundTransparency = 1.000
	                textboxFrame.ClipsDescendants = true
	                textboxFrame.Size = UDim2.new(0, 396, 0, 46)

	                textboxFolder.Name = "textboxFolder"
	                textboxFolder.Parent = textboxFrame

	                textboxFolderLayout.Name = "textboxFolderLayout"
	                textboxFolderLayout.Parent = textboxFolder
	                textboxFolderLayout.FillDirection = Enum.FillDirection.Horizontal
	                textboxFolderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	                textboxFolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	                textboxFolderLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	                textboxFolderLayout.Padding = UDim.new(0, 4)

	                textbox.Name = "textbox"
	                textbox.Parent = textboxFolder
	                textbox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	                textbox.Size = UDim2.new(0, 396, 0, 22)

	                textboxLayout.Name = "textboxLayout"
	                textboxLayout.Parent = textbox
	                textboxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	                textboxLayout.SortOrder = Enum.SortOrder.LayoutOrder
	                textboxLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	                textboxStraint.Name = "textboxStraint"
	                textboxStraint.Parent = textbox
	                textboxStraint.MaxSize = Vector2.new(396, 22)
	                textboxStraint.MinSize = Vector2.new(396, 22)

	                textboxCorner.CornerRadius = UDim.new(0, 2)
	                textboxCorner.Name = "textboxCorner"
	                textboxCorner.Parent = textbox

	                textboxTwo.Name = "textboxTwo"
	                textboxTwo.Parent = textbox
	                textboxTwo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textboxTwo.Size = UDim2.new(0, 394, 0, 20)

	                textboxTwoStraint.Name = "textboxTwoStraint"
	                textboxTwoStraint.Parent = textboxTwo
	                textboxTwoStraint.MaxSize = Vector2.new(394, 20)
	                textboxTwoStraint.MinSize = Vector2.new(394, 20)

	                textboxTwoGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	                textboxTwoGradient.Rotation = 90
	                textboxTwoGradient.Name = "textboxTwoGradient"
	                textboxTwoGradient.Parent = textboxTwo

	                textboxTwoCorner.CornerRadius = UDim.new(0, 2)
	                textboxTwoCorner.Name = "textboxTwoCorner"
	                textboxTwoCorner.Parent = textboxTwo

	                textBoxValues.Name = "textBoxValues"
	                textBoxValues.Parent = textboxTwo
	                textBoxValues.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textBoxValues.BackgroundTransparency = 1.000
	                textBoxValues.ClipsDescendants = true
	                textBoxValues.Position = UDim2.new(-0.587786257, 0, 0, 0)
	                textBoxValues.Size = UDim2.new(0, 394, 0, 20)
	                textBoxValues.Font = Enum.Font.Code
	                textBoxValues.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
	                textBoxValues.PlaceholderText = place
	                textBoxValues.Text = default
	                textBoxValues.TextColor3 = Color3.fromRGB(190, 190, 190)
	                textBoxValues.TextSize = 14.000
	                textBoxValues.TextXAlignment = Enum.TextXAlignment.Left

	                textBoxValuesStraint.Name = "textBoxValuesStraint"
	                textBoxValuesStraint.Parent = textBoxValues
	                textBoxValuesStraint.MaxSize = Vector2.new(394, 20)
	                textBoxValuesStraint.MinSize = Vector2.new(394, 20)

	                textBoxValuesPadding.Name = "textBoxValuesPadding"
	                textBoxValuesPadding.Parent = textBoxValues
	                textBoxValuesPadding.PaddingBottom = UDim.new(0, 6)
	                textBoxValuesPadding.PaddingLeft = UDim.new(0, 4)
	                textBoxValuesPadding.PaddingRight = UDim.new(0, 6)
	                textBoxValuesPadding.PaddingTop = UDim.new(0, 6)

	                textboxTwoLayout.Name = "textboxTwoLayout"
	                textboxTwoLayout.Parent = textboxTwo
	                textboxTwoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	                textboxTwoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	                textboxTwoLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	                textboxLabel.Name = "textboxLabel"
	                textboxLabel.Parent = textboxFrame
	                textboxLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textboxLabel.BackgroundTransparency = 1.000
	                textboxLabel.Size = UDim2.new(0, 396, 0, 24)
	                textboxLabel.Font = Enum.Font.Code
	                textboxLabel.Text = text
	                textboxLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	                textboxLabel.TextSize = 14.000
	                textboxLabel.TextWrapped = true
	                textboxLabel.TextXAlignment = Enum.TextXAlignment.Left
	                textboxLabel.RichText = true

	                textboxPadding.Name = "textboxPadding"
	                textboxPadding.Parent = textboxLabel
	                textboxPadding.PaddingBottom = UDim.new(0, 6)
	                textboxPadding.PaddingLeft = UDim.new(0, 2)
	                textboxPadding.PaddingRight = UDim.new(0, 6)
	                textboxPadding.PaddingTop = UDim.new(0, 6)

	                CreateTween("TextBox", 0.07)
	                UpdatePageSize()

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "numbers" then
	                        textBoxValues.Text = textBoxValues.Text:gsub("%D+", "")
	                    end
	                end)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "lower" then
	                        textBoxValues.Text = textBoxValues.Text:lower()
	                    end
	                end)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "upper" then
	                        textBoxValues.Text = textBoxValues.Text:upper()
	                    end
	                end)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "all" or format == "" then
	                        textBoxValues.Text = textBoxValues.Text
	                    end
	                end)

	                textboxFrame.MouseEnter:Connect(function()
	                    TweenService:Create(textboxLabel, TweenTable["TextBox"], {TextColor3 = Color3.fromRGB(210, 210, 210)}):Play()
	                end)

	                textboxFrame.MouseLeave:Connect(function()
	                    TweenService:Create(textboxLabel, TweenTable["TextBox"], {TextColor3 = Color3.fromRGB(190, 190, 190)}):Play()
	                end)

	                textBoxValues.Focused:Connect(function()
	                    TweenService:Create(textbox, TweenTable["TextBox"], {BackgroundColor3 = Color3.fromRGB(150, 0, 0)}):Play()
	                end)

	                textBoxValues.FocusLost:Connect(function()
	                    TweenService:Create(textbox, TweenTable["TextBox"], {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
	                end)

	                textBoxValues.FocusLost:Connect(function(enterPressed)
	                    if not autoexec then
	                        if enterPressed then
	                            callback(textBoxValues.Text)
	                        end
	                    else
	                        callback(textBoxValues.Text)
	                    end
	                end)

	                local TextboxFunctions = {}
	                function TextboxFunctions:Input(new)
	                    new = new or textBoxValues.Text
	                    textBoxValues = new
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Fire()
	                    callback(textBoxValues.Text)
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:SetFunction(new)
	                    new = new or callback
	                    callback = new
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Text(new)
	                    new = new or textboxLabel.Text
	                    textboxLabel.Text = new
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Hide()
	                    textboxFrame.Visible = false
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Show()
	                    textboxFrame.Visible = true
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Remove()
	                    textboxFrame:Destroy()
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Place(new)
	                    new = new or textBoxValues.PlaceholderText
	                    textBoxValues.PlaceholderText = new
	                    return TextboxFunctions
	                end
	                return TextboxFunctions
	            elseif type == "large" then
	                local textboxFrame = Instance.new("Frame")
	                local textboxFolder = Instance.new("Folder")
	                local textboxFolderLayout = Instance.new("UIListLayout")
	                local textbox = Instance.new("Frame")
	                local textboxLayout = Instance.new("UIListLayout")
	                local textboxStraint = Instance.new("UISizeConstraint")
	                local textboxCorner = Instance.new("UICorner")
	                local textboxTwo = Instance.new("Frame")
	                local textboxTwoStraint = Instance.new("UISizeConstraint")
	                local textboxTwoGradient = Instance.new("UIGradient")
	                local textboxTwoCorner = Instance.new("UICorner")
	                local textBoxValues = Instance.new("TextBox")
	                local textBoxValuesStraint = Instance.new("UISizeConstraint")
	                local textBoxValuesPadding = Instance.new("UIPadding")
	                local textboxTwoLayout = Instance.new("UIListLayout")
	                local textboxLabel = Instance.new("TextLabel")
	                local textboxPadding = Instance.new("UIPadding")

	                textboxFrame.Name = "textboxFrame"
	                textboxFrame.Parent = page
	                textboxFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textboxFrame.BackgroundTransparency = 1.000
	                textboxFrame.ClipsDescendants = true
	                textboxFrame.Position = UDim2.new(0.00499999989, 0, 0.268786132, 0)
	                textboxFrame.Size = UDim2.new(0, 396, 0, 142)

	                textboxFolder.Name = "textboxFolder"
	                textboxFolder.Parent = textboxFrame

	                textboxFolderLayout.Name = "textboxFolderLayout"
	                textboxFolderLayout.Parent = textboxFolder
	                textboxFolderLayout.FillDirection = Enum.FillDirection.Horizontal
	                textboxFolderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	                textboxFolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	                textboxFolderLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	                textboxFolderLayout.Padding = UDim.new(0, 4)

	                textbox.Name = "textbox"
	                textbox.Parent = textboxFolder
	                textbox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	                textbox.Position = UDim2.new(0, 0, 0.169014081, 0)
	                textbox.Size = UDim2.new(0, 396, 0, 118)

	                textboxLayout.Name = "textboxLayout"
	                textboxLayout.Parent = textbox
	                textboxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	                textboxLayout.SortOrder = Enum.SortOrder.LayoutOrder
	                textboxLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	                textboxStraint.Name = "textboxStraint"
	                textboxStraint.Parent = textbox
	                textboxStraint.MaxSize = Vector2.new(396, 118)
	                textboxStraint.MinSize = Vector2.new(396, 118)

	                textboxCorner.CornerRadius = UDim.new(0, 2)
	                textboxCorner.Name = "textboxCorner"
	                textboxCorner.Parent = textbox

	                textboxTwo.Name = "textboxTwo"
	                textboxTwo.Parent = textbox
	                textboxTwo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textboxTwo.Size = UDim2.new(0, 394, 0, 114)

	                textboxTwoStraint.Name = "textboxTwoStraint"
	                textboxTwoStraint.Parent = textboxTwo
	                textboxTwoStraint.MaxSize = Vector2.new(394, 116)
	                textboxTwoStraint.MinSize = Vector2.new(394, 116)

	                textboxTwoGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	                textboxTwoGradient.Rotation = 90
	                textboxTwoGradient.Name = "textboxTwoGradient"
	                textboxTwoGradient.Parent = textboxTwo

	                textboxTwoCorner.CornerRadius = UDim.new(0, 2)
	                textboxTwoCorner.Name = "textboxTwoCorner"
	                textboxTwoCorner.Parent = textboxTwo

	                textBoxValues.Name = "textBoxValues"
	                textBoxValues.Parent = textboxTwo
	                textBoxValues.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textBoxValues.BackgroundTransparency = 1.000
	                textBoxValues.ClipsDescendants = true
	                textBoxValues.Size = UDim2.new(0, 394, 0, 114)
	                textBoxValues.Font = Enum.Font.Code
	                textBoxValues.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
	                textBoxValues.PlaceholderText = place
	                textBoxValues.Text = default
	                textBoxValues.TextColor3 = Color3.fromRGB(190, 190, 190)
	                textBoxValues.TextSize = 14.000
	                textBoxValues.TextWrapped = true
	                textBoxValues.TextXAlignment = Enum.TextXAlignment.Left
	                textBoxValues.TextYAlignment = Enum.TextYAlignment.Top

	                textBoxValuesStraint.Name = "textBoxValuesStraint"
	                textBoxValuesStraint.Parent = textBoxValues
	                textBoxValuesStraint.MaxSize = Vector2.new(394, 116)
	                textBoxValuesStraint.MinSize = Vector2.new(394, 116)

	                textBoxValuesPadding.Name = "textBoxValuesPadding"
	                textBoxValuesPadding.Parent = textBoxValues
	                textBoxValuesPadding.PaddingBottom = UDim.new(0, 2)
	                textBoxValuesPadding.PaddingLeft = UDim.new(0, 2)
	                textBoxValuesPadding.PaddingRight = UDim.new(0, 2)
	                textBoxValuesPadding.PaddingTop = UDim.new(0, 2)

	                textboxTwoLayout.Name = "textboxTwoLayout"
	                textboxTwoLayout.Parent = textboxTwo
	                textboxTwoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	                textboxTwoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	                textboxTwoLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	                textboxLabel.Name = "textboxLabel"
	                textboxLabel.Parent = textboxFrame
	                textboxLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                textboxLabel.BackgroundTransparency = 1.000
	                textboxLabel.Size = UDim2.new(0, 396, 0, 24)
	                textboxLabel.Font = Enum.Font.Code
	                textboxLabel.Text = text
	                textboxLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	                textboxLabel.TextSize = 14.000
	                textboxLabel.TextWrapped = true
	                textboxLabel.TextXAlignment = Enum.TextXAlignment.Left
	                textboxLabel.RichText = true

	                textboxPadding.Name = "textboxPadding"
	                textboxPadding.Parent = textboxLabel
	                textboxPadding.PaddingBottom = UDim.new(0, 6)
	                textboxPadding.PaddingLeft = UDim.new(0, 2)
	                textboxPadding.PaddingRight = UDim.new(0, 6)
	                textboxPadding.PaddingTop = UDim.new(0, 6)

	                CreateTween("TextBox", 0.07)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "numbers" then
	                        textBoxValues.Text = textBoxValues.Text:gsub("%D+", "")
	                    end
	                end)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "lower" then
	                        textBoxValues.Text = textBoxValues.Text:lower()
	                    end
	                end)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "upper" then
	                        textBoxValues.Text = textBoxValues.Text:upper()
	                    end
	                end)

	                textBoxValues:GetPropertyChangedSignal("Text"):Connect(function()
	                    if format == "all" or format == "" then
	                        textBoxValues.Text = textBoxValues.Text
	                    end
	                end)

	                textboxFrame.MouseEnter:Connect(function()
	                    TweenService:Create(textboxLabel, TweenTable["TextBox"], {TextColor3 = Color3.fromRGB(210, 210, 210)}):Play()
	                end)

	                textboxFrame.MouseLeave:Connect(function()
	                    TweenService:Create(textboxLabel, TweenTable["TextBox"], {TextColor3 = Color3.fromRGB(190, 190, 190)}):Play()
	                end)

	                textBoxValues.Focused:Connect(function()
	                    TweenService:Create(textbox, TweenTable["TextBox"], {BackgroundColor3 = Color3.fromRGB(150, 0, 0)}):Play()
	                end)

	                textBoxValues.FocusLost:Connect(function()
	                    TweenService:Create(textbox, TweenTable["TextBox"], {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
	                end)

	                textBoxValues.FocusLost:Connect(function(enterPressed)
	                    if not autoexec then
	                        if enterPressed then
	                            callback(textBoxValues.Text)
	                        end
	                    else
	                        callback(textBoxValues.Text)
	                    end
	                end)

	                UpdatePageSize()

	                local TextboxFunctions = {}
	                function TextboxFunctions:Input(new)
	                    new = new or textBoxValues.Text
	                    textBoxValues = new
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Fire()
	                    callback(textBoxValues.Text)
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:SetFunction(new)
	                    new = new or callback
	                    callback = new
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Text(new)
	                    new = new or textboxLabel.Text
	                    textboxLabel.Text = new
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Hide()
	                    textboxFrame.Visible = false
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Show()
	                    textboxFrame.Visible = true
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Remove()
	                    textboxFrame:Destroy()
	                    return TextboxFunctions
	                end
	                --
	                function TextboxFunctions:Place(new)
	                    new = new or textBoxValues.PlaceholderText
	                    textBoxValues.PlaceholderText = new
	                    return TextboxFunctions
	                end
	                return TextboxFunctions
	            end
	        end
	        --
	        function Components:NewSelector(text, default, list, callback)
	            text = text or "selector"
	            default = default or ". . ."
	            list = list or {}
	            callback = callback or function() end

	            local selectorFrame = Instance.new("Frame")
	            local selectorLabel = Instance.new("TextLabel")
	            local selectorLabelPadding = Instance.new("UIPadding")
	            local selectorFrameLayout = Instance.new("UIListLayout")
	            local selector = Instance.new("TextButton")
	            local selectorCorner = Instance.new("UICorner")
	            local selectorLayout = Instance.new("UIListLayout")
	            local selectorPadding = Instance.new("UIPadding")
	            local selectorTwo = Instance.new("Frame")
	            local selectorText = Instance.new("TextLabel")
	            local textBoxValuesPadding = Instance.new("UIPadding")
	            local Frame = Instance.new("Frame")
	            local selectorTwoLayout = Instance.new("UIListLayout")
	            local selectorTwoGradient = Instance.new("UIGradient")
	            local selectorTwoCorner = Instance.new("UICorner")
	            local selectorPadding_2 = Instance.new("UIPadding")
	            local selectorContainer = Instance.new("Frame")
	            local selectorTwoLayout_2 = Instance.new("UIListLayout")
	            
	            selectorFrame.Name = "selectorFrame"
	            selectorFrame.Parent = page
	            selectorFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            selectorFrame.BackgroundTransparency = 1.000
	            selectorFrame.ClipsDescendants = true
	            selectorFrame.Position = UDim2.new(0.00499999989, 0, 0.0895953774, 0)
	            selectorFrame.Size = UDim2.new(0, 396, 0, 46)

	            
	            selectorLabel.Name = "selectorLabel"
	            selectorLabel.Parent = selectorFrame
	            selectorLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            selectorLabel.BackgroundTransparency = 1.000
	            selectorLabel.Size = UDim2.new(0, 396, 0, 24)
	            selectorLabel.Font = Enum.Font.Code
	            selectorLabel.Text = text
	            selectorLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	            selectorLabel.TextSize = 14.000
	            selectorLabel.TextWrapped = true
	            selectorLabel.TextXAlignment = Enum.TextXAlignment.Left
	            selectorLabel.RichText = true
	            
	            selectorLabelPadding.Name = "selectorLabelPadding"
	            selectorLabelPadding.Parent = selectorLabel
	            selectorLabelPadding.PaddingBottom = UDim.new(0, 6)
	            selectorLabelPadding.PaddingLeft = UDim.new(0, 2)
	            selectorLabelPadding.PaddingRight = UDim.new(0, 6)
	            selectorLabelPadding.PaddingTop = UDim.new(0, 6)
	            
	            selectorFrameLayout.Name = "selectorFrameLayout"
	            selectorFrameLayout.Parent = selectorFrame
	            selectorFrameLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	            selectorFrameLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            
	            selector.Name = "selector"
	            selector.Parent = selectorFrame
	            selector.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	            selector.ClipsDescendants = true
	            selector.Position = UDim2.new(0, 0, 0.0926640928, 0)
	            selector.Size = UDim2.new(0, 396, 0, 21)
	            selector.AutoButtonColor = false
	            selector.Font = Enum.Font.SourceSans
	            selector.Text = ""
	            selector.TextColor3 = Color3.fromRGB(0, 0, 0)
	            selector.TextSize = 14.000
	            
	            selectorCorner.CornerRadius = UDim.new(0, 2)
	            selectorCorner.Name = "selectorCorner"
	            selectorCorner.Parent = selector
	            
	            selectorLayout.Name = "selectorLayout"
	            selectorLayout.Parent = selector
	            selectorLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	            selectorLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            
	            selectorPadding.Name = "selectorPadding"
	            selectorPadding.Parent = selector
	            selectorPadding.PaddingTop = UDim.new(0, 1)
	            
	            selectorTwo.Name = "selectorTwo"
	            selectorTwo.Parent = selector
	            selectorTwo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            selectorTwo.ClipsDescendants = true
	            selectorTwo.Position = UDim2.new(0.00252525252, 0, 0, 0)
	            selectorTwo.Size = UDim2.new(0, 394, 0, 20)
	            
	            selectorText.Name = "selectorText"
	            selectorText.Parent = selectorTwo
	            selectorText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            selectorText.BackgroundTransparency = 1.000
	            selectorText.Size = UDim2.new(0, 394, 0, 20)
	            selectorText.Font = Enum.Font.Code
	            selectorText.LineHeight = 1.150
	            selectorText.TextColor3 = Color3.fromRGB(160, 160, 160)
	            selectorText.TextSize = 14.000
	            selectorText.TextXAlignment = Enum.TextXAlignment.Left
	            selectorText.Text = default
	            
	            textBoxValuesPadding.Name = "textBoxValuesPadding"
	            textBoxValuesPadding.Parent = selectorText
	            textBoxValuesPadding.PaddingBottom = UDim.new(0, 6)
	            textBoxValuesPadding.PaddingLeft = UDim.new(0, 6)
	            textBoxValuesPadding.PaddingRight = UDim.new(0, 6)
	            textBoxValuesPadding.PaddingTop = UDim.new(0, 6)
	            
	            Frame.Parent = selectorText
	            Frame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	            Frame.BorderSizePixel = 0
	            Frame.Position = UDim2.new(-0.008, 0, 1.78, 0)
	            Frame.Size = UDim2.new(0, 388, 0, 1)
	            
	            selectorTwoLayout.Name = "selectorTwoLayout"
	            selectorTwoLayout.Parent = selectorTwo
	            selectorTwoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	            selectorTwoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            
	            selectorTwoGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	            selectorTwoGradient.Rotation = 90
	            selectorTwoGradient.Name = "selectorTwoGradient"
	            selectorTwoGradient.Parent = selectorTwo
	            
	            selectorTwoCorner.CornerRadius = UDim.new(0, 2)
	            selectorTwoCorner.Name = "selectorTwoCorner"
	            selectorTwoCorner.Parent = selectorTwo
	            
	            selectorPadding_2.Name = "selectorPadding"
	            selectorPadding_2.Parent = selectorTwo
	            selectorPadding_2.PaddingTop = UDim.new(0, 1)
	            
	            selectorContainer.Name = "selectorContainer"
	            selectorContainer.Parent = selectorTwo
	            selectorContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            selectorContainer.BackgroundTransparency = 1.000
	            selectorContainer.Size = UDim2.new(0, 394, 0, 20)
	        
	            selectorTwoLayout_2.Name = "selectorTwoLayout"
	            selectorTwoLayout_2.Parent = selectorContainer
	            selectorTwoLayout_2.HorizontalAlignment = Enum.HorizontalAlignment.Center
	            selectorTwoLayout_2.SortOrder = Enum.SortOrder.LayoutOrder

	            CreateTween("selector", 0.08)

	            selectorContainer.ChildAdded:Connect(UpdatePageSize)
	            selectorContainer.ChildAdded:Connect(UpdatePageSize)

	            UpdatePageSize()

	            local Amount = #list
	            local Val = (Amount * 20)
	            function checkSizes()
	                Amount = #list
	                Val = (Amount * 20) + 20
	            end
	            for i,v in next, list do
	                local optionButton = Instance.new("TextButton")

	                optionButton.Name = "optionButton"
	                optionButton.Parent = selectorContainer
	                optionButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                optionButton.BackgroundTransparency = 1.000
	                optionButton.Size = UDim2.new(0, 394, 0, 20)
	                optionButton.AutoButtonColor = false
	                optionButton.Font = Enum.Font.Code
	                optionButton.Text = v
	                optionButton.TextColor3 = Color3.fromRGB(160, 160, 160)
	                optionButton.TextSize = 14.000
	                if optionButton.Text == default then
	                    optionButton.TextColor3 = Color3.fromRGB(150, 0, 0)
	                    callback(selectorText.Text)
	                end

	                optionButton.MouseButton1Click:Connect(function()
	                    for z,x in next, selectorContainer:GetChildren() do
	                        if x:IsA("TextButton") then
	                            TweenService:Create(x, TweenTable["selector"], {TextColor3 = Color3.fromRGB(160, 160, 160)}):Play()
	                        end
	                    end
	                    TweenService:Create(optionButton, TweenTable["selector"], {TextColor3 = Color3.fromRGB(150, 0, 0)}):Play()
	                    selectorText.Text = optionButton.Text
	                    callback(optionButton.Text)
	                end)

	                selectorContainer.Size = UDim2.new(0, 394, 0, Val)
	                selectorTwo.Size = UDim2.new(0, 394, 0, Val)
	                selector.Size = UDim2.new(0, 396, 0, Val + 2)
	                selectorFrame.Size = UDim2.new(0, 396, 0, Val + 26)

	                UpdatePageSize()
	                checkSizes()
	            end

	            UpdatePageSize()
	            local SelectorFunctions = {}
	            local AddAmount = 0
	            function SelectorFunctions:AddOption(new, callback_f)
	                new = new or "option"
	                list[new] = new

	                local optionButton = Instance.new("TextButton")

	                AddAmount = AddAmount + 20

	                optionButton.Name = "optionButton"
	                optionButton.Parent = selectorContainer
	                optionButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	                optionButton.BackgroundTransparency = 1.000
	                optionButton.Size = UDim2.new(0, 394, 0, 20)
	                optionButton.AutoButtonColor = false
	                optionButton.Font = Enum.Font.Code
	                optionButton.Text = new
	                optionButton.TextColor3 = Color3.fromRGB(140, 140, 140)
	                optionButton.TextSize = 14.000
	                if optionButton.Text == default then
	                    optionButton.TextColor3 = Color3.fromRGB(150, 0, 0)
	                    callback(selectorText.Text)
	                end

	                optionButton.MouseButton1Click:Connect(function()
	                    for z,x in next, selectorContainer:GetChildren() do
	                        if x:IsA("TextButton") then
	                            TweenService:Create(x, TweenTable["selector"], {TextColor3 = Color3.fromRGB(140, 140, 140)}):Play()
	                        end
	                    end
	                    TweenService:Create(optionButton, TweenTable["selector"], {TextColor3 = Color3.fromRGB(150, 0, 0)}):Play()
	                    selectorText.Text = optionButton.Text
	                    callback(optionButton.Text)
	                end)

	                checkSizes()
	                selectorContainer.Size = UDim2.new(0, 394, 0, Val + AddAmount)
	                selectorTwo.Size = UDim2.new(0, 394, 0, Val + AddAmount)
	                selector.Size = UDim2.new(0, 396, 0, (Val + AddAmount) + 2)
	                selectorFrame.Size = UDim2.new(0, 396, 0, (Val + AddAmount) + 26)

	                UpdatePageSize()
	                checkSizes()
	                return SelectorFunctions
	            end
	            --
	            local RemoveAmount = 0
	            function SelectorFunctions:RemoveOption(option)
	                list[option] = nil

	                RemoveAmount = RemoveAmount + 20
	                AddAmount = AddAmount - 20

	                for i,v in pairs(selectorContainer:GetDescendants()) do
	                    if v:IsA("TextButton") then
	                        if v.Text == option then
	                            v:Destroy()
	                            selectorContainer.Size = UDim2.new(0, 394, 0, Val - RemoveAmount)
	                            selectorTwo.Size = UDim2.new(0, 394, 0, Val - RemoveAmount)
	                            selector.Size = UDim2.new(0, 396, 0, (Val - RemoveAmount) + 2)
	                            selectorFrame.Size = UDim2.new(0, 396, 0, (Val + 6) - 20)
	                        end
	                    end
	                end

	                if selectorText.Text == option then
	                    selectorText.Text = ". . ."
	                end

	                UpdatePageSize()
	                checkSizes()
	                return SelectorFunctions
	            end
	            --
	            function SelectorFunctions:SetFunction(new)
	                new = new or callback
	                callback = new
	                return SelectorFunctions
	            end
	            --
	            function SelectorFunctions:Text(new)
	                new = new or selectorLabel.Text
	                selectorLabel.Text = new
	                return SelectorFunctions
	            end
	            --
	            function SelectorFunctions:Hide()
	                selectorFrame.Visible = false
	                return SelectorFunctions
	            end
	            --
	            function SelectorFunctions:Show()
	                selectorFrame.Visible = true
	                return SelectorFunctions
	            end
	            --
	            function SelectorFunctions:Remove()
	                selectorFrame:Destroy()
	                return SelectorFunctions
	            end
	            return SelectorFunctions
	        end
	        --
	        function Components:NewSlider(text, suffix, compare, compareSign, values, callback)
	            text = text or "slider"
	            suffix = suffix or ""
	            compare = compare or false
	            compareSign = compareSign or "/"
	            values = values or {
	                min = values.min or 0,
	                max = values.max or 100,
	                default = values.default or 0
	            }
	            callback = callback or function() end

	            values.max = values.max + 1

	            local sliderFrame = Instance.new("Frame")
	            local sliderFolder = Instance.new("Folder")
	            local textboxFolderLayout = Instance.new("UIListLayout")
	            local sliderButton = Instance.new("TextButton")
	            local sliderButtonCorner = Instance.new("UICorner")
	            local sliderBackground = Instance.new("Frame")
	            local sliderButtonCorner_2 = Instance.new("UICorner")
	            local sliderBackgroundGradient = Instance.new("UIGradient")
	            local sliderBackgroundLayout = Instance.new("UIListLayout")
	            local sliderIndicator = Instance.new("Frame")
	            local sliderIndicatorStraint = Instance.new("UISizeConstraint")
	            local sliderIndicatorGradient = Instance.new("UIGradient")
	            local sliderIndicatorCorner = Instance.new("UICorner")
	            local sliderBackgroundPadding = Instance.new("UIPadding")
	            local sliderButtonLayout = Instance.new("UIListLayout")
	            local sliderLabel = Instance.new("TextLabel")
	            local sliderPadding = Instance.new("UIPadding")
	            local sliderValue = Instance.new("TextLabel")

	            sliderFrame.Name = "sliderFrame"
	            sliderFrame.Parent = page
	            sliderFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            sliderFrame.BackgroundTransparency = 1.000
	            sliderFrame.ClipsDescendants = true
	            sliderFrame.Position = UDim2.new(0.00499999989, 0, 0.667630076, 0)
	            sliderFrame.Size = UDim2.new(0, 396, 0, 40)

	            sliderFolder.Name = "sliderFolder"
	            sliderFolder.Parent = sliderFrame

	            textboxFolderLayout.Name = "textboxFolderLayout"
	            textboxFolderLayout.Parent = sliderFolder
	            textboxFolderLayout.FillDirection = Enum.FillDirection.Horizontal
	            textboxFolderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	            textboxFolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            textboxFolderLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	            textboxFolderLayout.Padding = UDim.new(0, 4)

	            sliderButton.Name = "sliderButton"
	            sliderButton.Parent = sliderFolder
	            sliderButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	            sliderButton.Position = UDim2.new(0.348484844, 0, 0.600000024, 0)
	            sliderButton.Size = UDim2.new(0, 396, 0, 16)
	            sliderButton.AutoButtonColor = false
	            sliderButton.Font = Enum.Font.SourceSans
	            sliderButton.Text = ""
	            sliderButton.TextColor3 = Color3.fromRGB(0, 0, 0)
	            sliderButton.TextSize = 14.000

	            sliderButtonCorner.CornerRadius = UDim.new(0, 2)
	            sliderButtonCorner.Name = "sliderButtonCorner"
	            sliderButtonCorner.Parent = sliderButton

	            sliderBackground.Name = "sliderBackground"
	            sliderBackground.Parent = sliderButton
	            sliderBackground.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            sliderBackground.Size = UDim2.new(0, 394, 0, 14)
	            sliderBackground.ClipsDescendants = true

	            sliderButtonCorner_2.CornerRadius = UDim.new(0, 2)
	            sliderButtonCorner_2.Name = "sliderButtonCorner"
	            sliderButtonCorner_2.Parent = sliderBackground

	            sliderBackgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	            sliderBackgroundGradient.Rotation = 90
	            sliderBackgroundGradient.Name = "sliderBackgroundGradient"
	            sliderBackgroundGradient.Parent = sliderBackground

	            sliderBackgroundLayout.Name = "sliderBackgroundLayout"
	            sliderBackgroundLayout.Parent = sliderBackground
	            sliderBackgroundLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            sliderBackgroundLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	            sliderIndicator.Name = "sliderIndicator"
	            sliderIndicator.Parent = sliderBackground
	            sliderIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            sliderIndicator.BorderSizePixel = 0
	            sliderIndicator.Position = UDim2.new(0, 0, -0.100000001, 0)
	            sliderIndicator.Size = UDim2.new(0, 0, 0, 12)

	            sliderIndicatorStraint.Name = "sliderIndicatorStraint"
	            sliderIndicatorStraint.Parent = sliderIndicator
	            sliderIndicatorStraint.MaxSize = Vector2.new(392, 12)

	            sliderIndicatorGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(120, 0, 0)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(100, 0, 0))}
	            sliderIndicatorGradient.Rotation = 90
	            sliderIndicatorGradient.Name = "sliderIndicatorGradient"
	            sliderIndicatorGradient.Parent = sliderIndicator

	            sliderIndicatorCorner.CornerRadius = UDim.new(0, 2)
	            sliderIndicatorCorner.Name = "sliderIndicatorCorner"
	            sliderIndicatorCorner.Parent = sliderIndicator

	            sliderBackgroundPadding.Name = "sliderBackgroundPadding"
	            sliderBackgroundPadding.Parent = sliderBackground
	            sliderBackgroundPadding.PaddingBottom = UDim.new(0, 2)
	            sliderBackgroundPadding.PaddingLeft = UDim.new(0, 1)
	            sliderBackgroundPadding.PaddingRight = UDim.new(0, 1)
	            sliderBackgroundPadding.PaddingTop = UDim.new(0, 2)

	            sliderButtonLayout.Name = "sliderButtonLayout"
	            sliderButtonLayout.Parent = sliderButton
	            sliderButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	            sliderButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            sliderButtonLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	            sliderLabel.Name = "sliderLabel"
	            sliderLabel.Parent = sliderFrame
	            sliderLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            sliderLabel.BackgroundTransparency = 1.000
	            sliderLabel.Size = UDim2.new(0, 396, 0, 24)
	            sliderLabel.Font = Enum.Font.Code
	            sliderLabel.Text = text
	            sliderLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	            sliderLabel.TextSize = 14.000
	            sliderLabel.TextWrapped = true
	            sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
	            sliderLabel.RichText = true

	            sliderPadding.Name = "sliderPadding"
	            sliderPadding.Parent = sliderLabel
	            sliderPadding.PaddingBottom = UDim.new(0, 6)
	            sliderPadding.PaddingLeft = UDim.new(0, 2)
	            sliderPadding.PaddingRight = UDim.new(0, 6)
	            sliderPadding.PaddingTop = UDim.new(0, 6)

	            sliderValue.Name = "sliderValue"
	            sliderValue.Parent = sliderLabel
	            sliderValue.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            sliderValue.BackgroundTransparency = 1.000
	            sliderValue.Position = UDim2.new(0.577319562, 0, 0, 0)
	            sliderValue.Size = UDim2.new(0, 169, 0, 15)
	            sliderValue.Font = Enum.Font.Code
	            sliderValue.Text = values.default
	            sliderValue.TextColor3 = Color3.fromRGB(140, 140, 140)
	            sliderValue.TextSize = 14.000
	            sliderValue.TextXAlignment = Enum.TextXAlignment.Right


	            local calc1 = values.max - values.min
	            local calc2 = values.default - values.min
	            local calc3 = calc2 / calc1
	            local calc4 = calc3 * sliderBackground.AbsoluteSize.X
	            local Calculation = calc4
	            sliderIndicator.Size = UDim2.new(0, Calculation, 0, 12)
	            sliderValue.Text = values.default

	            CreateTween("slider_drag", 0.008)

	            local ValueNum = values.default
	            local slideText = compare and ValueNum .. compareSign .. tostring(values.max - 1) .. suffix or ValueNum .. suffix
	            sliderValue.Text = slideText
	            local function UpdateSlider()
	                TweenService:Create(sliderIndicator, TweenTable["slider_drag"], {Size = UDim2.new(0, math.clamp(Mouse.X - sliderIndicator.AbsolutePosition.X, 0, sliderBackground.AbsoluteSize.X), 0, 12)}):Play()

	                ValueNum = math.floor((((tonumber(values.max) - tonumber(values.min)) / sliderBackground.AbsoluteSize.X) * sliderIndicator.AbsoluteSize.X) + tonumber(values.min)) or 0.00

	                local slideText = compare and ValueNum .. compareSign .. tostring(values.max - 1) .. suffix or ValueNum .. suffix

	                sliderValue.Text = slideText

	                pcall(function()
	                    callback(ValueNum)
	                end)

	                sliderValue.Text = slideText

	                moveconnection = Mouse.Move:Connect(function()
	                    ValueNum = math.floor((((tonumber(values.max) - tonumber(values.min)) / sliderBackground.AbsoluteSize.X) * sliderIndicator.AbsoluteSize.X) + tonumber(values.min))
	                    
	                    slideText = compare and ValueNum .. compareSign .. tostring(values.max - 1) .. suffix or ValueNum .. suffix
	                    sliderValue.Text = slideText

	                    pcall(function()
	                        callback(ValueNum)
	                    end)

	                    TweenService:Create(sliderIndicator, TweenTable["slider_drag"], {Size = UDim2.new(0, math.clamp(Mouse.X - sliderIndicator.AbsolutePosition.X, 0, sliderBackground.AbsoluteSize.X), 0, 12)}):Play()
	                    if not UserInputService.WindowFocused then
	                        moveconnection:Disconnect()
	                    end
	                end)

	                releaseconnection = UserInputService.InputEnded:Connect(function(Mouse_2)
	                    if Mouse_2.UserInputType == Enum.UserInputType.MouseButton1 then
	                        ValueNum = math.floor((((tonumber(values.max) - tonumber(values.min)) / sliderBackground.AbsoluteSize.X) * sliderIndicator.AbsoluteSize.X) + tonumber(values.min))
	                        
	                        slideText = compare and ValueNum .. compareSign .. tostring(values.max - 1) .. suffix or ValueNum .. suffix
	                        sliderValue.Text = slideText

	                        pcall(function()
	                            callback(ValueNum)
	                        end)

	                        TweenService:Create(sliderIndicator, TweenTable["slider_drag"], {Size = UDim2.new(0, math.clamp(Mouse.X - sliderIndicator.AbsolutePosition.X, 0, sliderBackground.AbsoluteSize.X), 0, 12)}):Play()
	                        moveconnection:Disconnect()
	                        releaseconnection:Disconnect()
	                    end
	                end)
	            end

	            sliderButton.MouseButton1Down:Connect(function()
	                UpdateSlider()
	            end)

	            UpdatePageSize()

	            local SliderFunctions = {}
	            function SliderFunctions:Value(new)
	                local ncalc1 = new - values.min
	                local ncalc2 = ncalc1 / calc1
	                local ncalc3 = ncalc2 * sliderBackground.AbsoluteSize.X
	                local nCalculation = ncalc3
	                sliderIndicator.Size = UDim2.new(0, nCalculation, 0, 12)
	                slideText = compare and new .. compareSign .. tostring(values.max - 1) .. suffix or new .. suffix
	                sliderValue.Text = slideText
	                return SliderFunctions
	            end
	            --
	            function SliderFunctions:Max(new)
	                new = new or values.max
	                values.max = new + 1
	                slideText = compare and ValueNum .. compareSign .. tostring(values.max - 1) .. suffix or ValueNum .. suffix
	                return SliderFunctions
	            end
	            --
	            function SliderFunctions:Min(new)
	                new = new or values.min
	                values.min = new
	                slideText = compare and new .. compareSign .. tostring(values.max - 1) .. suffix or ValueNum .. suffix
	                TweenService:Create(sliderIndicator, TweenTable["slider_drag"], {Size = UDim2.new(0, math.clamp(Mouse.X - sliderIndicator.AbsolutePosition.X, 0, sliderBackground.AbsoluteSize.X), 0, 12)}):Play()
	                return SliderFunctions
	            end
	            --
	            function SliderFunctions:SetFunction(new)
	                new = new or callback
	                callback = new
	                return SliderFunctions
	            end
	            --
	            function SliderFunctions:Text(new)
	                new = new or sliderLabel.Text
	                sliderLabel.Text = new
	                return SliderFunctions
	            end
	            --
	            function SliderFunctions:Hide()
	                sliderFrame.Visible = false
	                return SliderFunctions
	            end
	            --
	            function SliderFunctions:Show()
	                sliderFrame.Visible = true
	                return SliderFunctions
	            end
	            --
	            function SliderFunctions:Remove()
	                sliderFrame:Destroy()
	                return SliderFunctions
	            end
	            return SliderFunctions
	        end
	        --
	        function Components:NewSeperator()
	            local sectionFrame = Instance.new("Frame")
	            local sectionLayout = Instance.new("UIListLayout")
	            local rightBar = Instance.new("Frame")

	            sectionFrame.Name = "sectionFrame"
	            sectionFrame.Parent = page
	            sectionFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	            sectionFrame.BackgroundTransparency = 1.000
	            sectionFrame.ClipsDescendants = true
	            sectionFrame.Position = UDim2.new(0.00499999989, 0, 0.361271679, 0)
	            sectionFrame.Size = UDim2.new(0, 396, 0, 12)

	            sectionLayout.Name = "sectionLayout"
	            sectionLayout.Parent = sectionFrame
	            sectionLayout.FillDirection = Enum.FillDirection.Horizontal
	            sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	            sectionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	            sectionLayout.Padding = UDim.new(0, 4)

	            rightBar.Name = "rightBar"
	            rightBar.Parent = sectionFrame
	            rightBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	            rightBar.BorderSizePixel = 0
	            rightBar.Position = UDim2.new(0.308080822, 0, 0.479166657, 0)
	            rightBar.Size = UDim2.new(0, 403, 0, 1)

	            UpdatePageSize()

	            local SeperatorFunctions = {}
	            function SeperatorFunctions:Hide()
	                sectionFrame.Visible = false
	                return SeperatorFunctions
	            end
	            --
	            function SeperatorFunctions:Show()
	                sectionFrame.Visible = true
	                return SeperatorFunctions
	            end
	            --
	            function SeperatorFunctions:Remove()
	                sectionFrame:Destroy()
	                return SeperatorFunctions
	            end
	            return SeperatorFunctions
	        end
	        --
	        function Components:Open()
	            TabLibrary.CurrentTab = title
	            for i,v in pairs(container:GetChildren()) do 
	                if v:IsA("ScrollingFrame") then
	                    v.Visible = false
	                end
	            end
	            page.Visible = true

	            for i,v in pairs(tabButtons:GetChildren()) do
	                if v:IsA("TextButton") then
	                    TweenService:Create(v, TweenTable["tab_text_colour"], {TextColor3 = Color3.fromRGB(170, 170, 170)}):Play()
	                end
	            end
	            TweenService:Create(tabButton, TweenTable["tab_text_colour"], {TextColor3 = Color3.fromRGB(150, 0, 0)}):Play()

	            return Components
	        end
	        --
	        function Components:Remove()
	            tabButton:Destroy()
	            page:Destroy()

	            return Components
	        end
	        --
	        function Components:Hide()
	            tabButton.Visible = false
	            page.Visible = false

	            return Components
	        end
	        --
	        function Components:Show()
	            tabButton.Visible = true

	            return Components
	        end
	        --
	        function Components:Text(text)
	            text = text or "new text"
	            tabButton.Text = text

	            return Components
	        end
	        return Components
	    end
	    --
	    function TabLibrary:Remove()
	        screen:Destroy()

	        return TabLibrary
	    end
	    --
	    function TabLibrary:Text(text)
	        text = text or "new text"
	        headerLabel.Text = text

	        return TabLibrary
	    end
	    --
	    function TabLibrary:UpdateKeybind(new)
	        new = new or key
	        key = new
	        return TabLibrary
	    end
	    return TabLibrary
	end
	return library
end
luacompactModules["src/logic/autofish.lua"] = function()
	local Autofish = {}
	ODYSSEY.Autofish = Autofish

	local AutofishData = ODYSSEY.Data.Autofish or {}
	ODYSSEY.Data.Autofish = AutofishData

	--

	ODYSSEY.InitData("Position", {3979.5, 396.1, 256.2}, AutofishData)

	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local InventoryScr = ReplicatedStorage.RS.Modules.Inventory
	local FishingScr = ReplicatedStorage.RS.Modules.Fishing

	local FishState = ReplicatedStorage.RS.Remotes.Misc.FishState
	local FishClock = ReplicatedStorage.RS.Remotes.Misc.FishClock

	local Fishing = require(FishingScr)
	local Inventory = require(InventoryScr)

	local Maid = load("src/lib/Maid.lua")
	local AutofishMaid = Maid.new()

	function Autofish.GetFishingRods()
	    local getInvRemote = ReplicatedStorage.RS.Remotes.UI.GetInventoryItems
	    local items = getInvRemote:InvokeServer()

	    local rods = {}

	    for _, item in ipairs(items) do
	        if item == "FILLER" then continue end
	        local metadata, data = Inventory.GetItemValueInfo(item)

	        if not data then continue end -- wtf
	        if data.SubType ~= "Fishing Rod" then continue end

	        local resolvedName = Inventory.ResolveItemName(metadata)
	        metadata.ResolvedName = resolvedName

	        table.insert(rods, {metadata, data})
	    end

	    return rods
	end

	function Autofish.FindRod(rodName)
	    local player = ODYSSEY.GetLocalPlayer()
	    local character = player.Character
	    local backpack = player.Backpack

	    local rod = (character:FindFirstChild(rodName)) or (backpack:FindFirstChild(rodName))
	    return rod
	end

	ODYSSEY.Maid:GiveTask(AutofishMaid)

	function Autofish.Update()
	    if AutofishData.AutofishToggle then
	        local character = ODYSSEY.GetLocalPlayer().Character
	        local hum = character:WaitForChild("Humanoid")

	        if character:FindFirstChild("FishClock") then
	            return
	        end
	        if hum.Health <= 0 then
	            return AutofishMaid:Destroy()
	        end
	       
	        AutofishMaid:GiveTask(hum.Died:Connect(function()
	            AutofishMaid:Destroy()
	        end))

	        local rod = Autofish.FindRod(AutofishData.FishingRod)

	        -- cast
	        task.wait(2)
	        FishState:FireServer("StopClock")
	        FishClock:FireServer(rod, nil, Vector3.new(table.unpack(AutofishData.Position)))
	       
	        -- wait for something to bite
	        AutofishMaid:GiveTask(character.ChildAdded:Connect(function(c)
	            if c.Name == "FishBiteProgress" then
	                while c.Parent do
	                    FishState:FireServer("Reel")
	                    task.wait(1/20)
	                end

	                -- repeat!
	                AutofishMaid:Destroy()
	            end
	        end))
	    else
	        AutofishMaid:Destroy()
	    end
	end

	ODYSSEY.Timer(1, Autofish.Update)
end
luacompactModules["src/logic/combat.lua"] = function()
	local Combat = {}
	ODYSSEY.Combat = Combat

	local CombatData = ODYSSEY.Data.Combat or {}
	ODYSSEY.Data.Combat = CombatData

	--

	local RemoteTamperer = ODYSSEY.RemoteTamperer
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- break targeting
	local setTarget = ReplicatedStorage.RS.Remotes:FindFirstChild("SetTarget", true)

	RemoteTamperer.TamperRemotes({setTarget}, function(remote, args, oldNamecall)
		if CombatData.BreakAI then
			return false
		end
	end)

	-- infinite stamina
	local bin = ODYSSEY.GetLocalPlayer():WaitForChild("bin")
	local staminaVal = bin:WaitForChild("Stamina")
	local maxStaminaVal = bin:WaitForChild("MaxStamina")

	local remote = ReplicatedStorage.RS.Remotes.Combat.StaminaCost

	function Combat.UpdateStamina()
		local ratio = staminaVal.Value / maxStaminaVal.Value

		if CombatData.NoStamina then
			if ratio < 1 then
				remote:FireServer(-2, "Dodge")
			end
		else
			-- try to reset stamina back to normal
			if ratio > 1 then
				remote:FireServer(ratio - 1, "Dodge")
			end
		end
	end

	Combat.UpdateStamina()
	ODYSSEY.Maid:GiveTask(staminaVal.Changed:Connect(Combat.UpdateStamina))
	ODYSSEY.Maid:GiveTask(maxStaminaVal.Changed:Connect(Combat.UpdateStamina))

	-- no knockback
	local player = ODYSSEY.GetLocalPlayer()

	local function OnCharacterAdded(character)
		local hrp = character:WaitForChild("HumanoidRootPart")

		ODYSSEY.Maid:GiveTask(hrp.ChildAdded:Connect(function(c)
			if not CombatData.NoKnockback then return end
			if not hrp.Parent then return end
			if c:IsA("BodyMover") and c.Name == "BodyVelocity" then
				local oldVel = c.Velocity
				c.Velocity = Vector3.new()

				task.defer(function()
					-- wait to see if it's a high jump or not
					-- then set its Velocity back
					if not hrp:FindFirstChild("Leap") then
						c:Destroy()
					else
						c.Velocity = oldVel
					end
				end)
			end
		end))
	end

	OnCharacterAdded(player.Character or player.CharacterAdded:Wait())
	ODYSSEY.Maid:GiveTask(player.CharacterAdded:Connect(OnCharacterAdded))

	-- damage tampers
	local toBlacklist = {}
	local toIntercept = {}

	for _, remote in ipairs(ReplicatedStorage.RS.Remotes:GetDescendants()) do
		local name = remote.Name
		
		if string.match(name, "Take") and string.match(name, "Damage") then
			table.insert(toBlacklist, remote)
		end
		if string.match(name, "Deal") and string.match(name, "Damage") then
			table.insert(toIntercept, remote)
		end
		
		if name == "TouchDamage" then
			table.insert(toBlacklist, remote)
		end
	end


	ODYSSEY.RemoteTamperer.TamperRemotes(toBlacklist, function()
		if CombatData.DamageReflect or CombatData.DamageNull then
			return false
		end
	end)

	ODYSSEY.RemoteTamperer.TamperRemotes(toIntercept, function(remote, args, oldNamecall)
		-- idk why vetex loves putting random ass vars in remotes
		local modelTypes = {}
		for idx, arg in pairs(args) do
			if typeof(arg) == "Instance" and arg:IsA("Model") then
				table.insert(modelTypes, {Index = idx, Value = arg})
			end
		end

		local dealer, receiver = modelTypes[1], modelTypes[2]

		-- damage reflect
		if CombatData.DamageReflect then
			if receiver.Value == ODYSSEY.GetLocalCharacter() then
				args[dealer.Index] = receiver.Value
				args[receiver.Index] = dealer.Value
			end
		else
			-- only nullify if we are being attacked
			if CombatData.DamageNull and args[dealer.Index] ~= ODYSSEY.GetLocalCharacter() then
				return false
			end
		end

		-- damage amp
		if CombatData.DamageAmp then
			local amount = CombatData.DamageAmpValue
			local fireServer = remote.FireServer

			if args[dealer.Index] ~= ODYSSEY.GetLocalCharacter() then
				amount = 1 -- don't amp if we are being attacked
			end
			
			for _ = 1, amount do
				fireServer(remote, table.unpack(args))
			end

			return false
		end
	end)
end
luacompactModules["src/logic/core.lua"] = function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- send notif funcc
	do
		local rem = ReplicatedStorage.RS.Remotes.UI.Notification
		local upvalues = getupvalues(getconnections(rem.OnClientEvent)[1].Function)[1]
		local notifFunc = upvalues.Notification
		
		ODYSSEY.SendNotification = notifFunc
	end

	-- load area func
	do
	    local LoadArea
	    for _, connection in next, getconnections(ReplicatedStorage.RS.Remotes.Misc.OnTeleport.OnClientEvent) do
	        local env = connection.Function and getfenv(connection.Function)
	        if env and tostring(rawget(env, "script")) == "Unloading" then
	            LoadArea = debug.getupvalue(connection.Function, 2)
	            break
	        end
	    end

	    ODYSSEY.LoadArea = LoadArea
	end

	-- load npc func
	do
	    local LoadCheck
	    for _, connection in pairs(getconnections(workspace.NPCs.ChildAdded)) do
	        local env = getfenv(connection.Function)
	        if rawget(env, "script").Name == "SetupNPCs" then
	            LoadCheck = getupvalues(connection.Function)[2]
	            break
	        end
	    end

	    local upvalues = getupvalues(LoadCheck)
	    
	    ODYSSEY.NPCLoadCheck = upvalues[1]
	    ODYSSEY.EnemyLoadCheck = upvalues[2]
	end
end
luacompactModules["src/logic/farming.lua"] = function()
	local Farming = {}
	ODYSSEY.Farming = Farming

	local FarmingData = ODYSSEY.Data.Farming or {}
	ODYSSEY.Data.Farming = FarmingData

	--

	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Maid = load("src/lib/Maid.lua")

	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------

	local DamageStructureRemote = ReplicatedStorage.RS.Remotes.Combat.DamageStructure
	local RocksaltMaid = Maid.new()

	function Farming.RocksaltFarm()
	    if not FarmingData.Rocksalt then
	        return RocksaltMaid:Destroy()
	    end

	    -- find a random rock
	    local rock
	    for _, island in ipairs(workspace.Map:GetChildren()) do
	        local natural = island:FindFirstChild("Natural")
	        if not natural then continue end
	        
	        local rocks = natural:FindFirstChild("Rocks")
	        if not rocks then continue end

	        rock = rocks:FindFirstChild("RockPile")
	        if not rock then continue end
	    end

	    if not rock then
	        for _, island in ipairs(ReplicatedStorage.RS.UnloadIslands:GetChildren()) do
	            local natural = island:FindFirstChild("Natural")
	            if not natural then continue end
	            
	            local rocks = natural:FindFirstChild("Rocks")
	            if not rocks then continue end
	    
	            rock = rocks:FindFirstChild("RockPile")
	            if not rock then continue end
	        end    
	    end

	    if not rock then
	        return ODYSSEY.SendNotification(nil, "Crimson Lily", "Failed to find a RockPile.", Color3.new(1, 0, 0))
	    end
	    
	    -- tp
	    local player = ODYSSEY.GetLocalPlayer()
	    local character = player.Character
	    local hrp = character.PrimaryPart

	    character:SetPrimaryPartCFrame(CFrame.new(rock.Position))
	    RocksaltMaid:GiveTask(function()
	        hrp.Anchored = false
	    end)

	    task.wait(0.1)
	    hrp.Anchored = true

	    -- destroy lmao
	    local a1 = "Explosion Magic"
	    local a2 = "1"
	    local a3 = character
	    local a4 = rock
	    local a5 = "[\"Blast\",1,100,100,false,\"Right Hand Snap\",\"(None)\",\"Blast\",\"(None)\",\"Ash\"]"

	    task.spawn(function()
	        while FarmingData.Rocksalt do
	            task.spawn(function()
	                DamageStructureRemote:InvokeServer(a1, a2, a3, a4, a5)
	            end)
	            task.wait(1/FarmingData.RocksaltSpeed)
	        end
	    end)

	    RocksaltMaid:GiveTask(workspace.Map.Temporary.ChildAdded:Connect(function(c)
	        if c.Name == "RockDrop" then
	            c.Anchored = true

	            local pp = c:WaitForChild("Prompt", 10)
	            if not pp then
	                c:Destroy()
	                return
	            end

	            local objectText = pp.ObjectText
	            if objectText == "Rock salt" and FarmingData.RocksaltGems then
	                c:Destroy()
	                return
	            end
	            
	            fireproximityprompt(pp, 0)
	        end
	    end))
	end
end
luacompactModules["src/logic/gameplay.lua"] = function()
	local Gameplay = {}
	ODYSSEY.Gameplay = Gameplay

	local GameplayData = ODYSSEY.Data.Gameplay or {}
	ODYSSEY.Data.Gameplay = GameplayData

	--

	local TeleportService = game:GetService("TeleportService")
	local HttpService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Player = ODYSSEY.GetLocalPlayer()

	function GetServers(placeId, limit)
	    local servers = {}
	    local cursor = nil

	    ODYSSEY.SendNotification(nil, "Crimson Lily", string.format("Fetching %d servers, please wait.", limit), Color3.new(1, 1, 1))
	    repeat
	        local endpoint = string.format(
	            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
	            placeId
	        )
	        if cursor then
	            endpoint ..= "&cursor=".. cursor
	        end

	        local resp = HttpService:JSONDecode(game:HttpGetAsync(endpoint))
	        cursor = resp.nextPageCursor

	        for _, server in ipairs(resp.data) do
	            if not server.playing then continue end
	            table.insert(servers, server)
	        end

	        if #servers >= limit then
	            -- dont fetch more its gonna take forever lmao
	            break
	        end
	    until cursor == nil

	    return servers
	end

	function Gameplay.LoadSlot()
	    local servers = GetServers(GameplayData.SelectedSeaId, 400)
	    local server = servers[math.random(1, #servers)]

	    TeleportService:TeleportToPlaceInstance(
	        GameplayData.SelectedSeaId,
	        server.id,
	        nil,
	        nil,
	        tonumber(GameplayData.SelectedSlot)
	    )
	end

	function Gameplay.ServerHop()
	    local data = GetServers(GameplayData.SelectedSeaId, 100)
	    table.sort(data, function(a, b)
	        return a.playing < b.playing
	    end)

	    if not data[1] then
	        ODYSSEY.SendNotification(nil, "Crimson Lily", "Couldn't find any server.", Color3.new(1, 0, 0))
	        return
	    end

	    TeleportService:TeleportToPlaceInstance(
	        GameplayData.SelectedSeaId,
	        data[1].id,
	        nil,
	        nil,
	        tonumber(GameplayData.SelectedSlot)
	    )
	end

	function Gameplay.JoinFastestServer()
	    local data = GetServers(GameplayData.SelectedSeaId, 400)
	    table.sort(data, function(a, b)
	        return a.ping < b.ping
	    end)

	    if not data[1] then
	        ODYSSEY.SendNotification(nil, "Crimson Lily", "Couldn't find any server.", Color3.new(1, 0, 0))
	        return
	    end

	    TeleportService:TeleportToPlaceInstance(
	        GameplayData.SelectedSeaId,
	        data[1].id,
	        nil,
	        nil,
	        tonumber(GameplayData.SelectedSlot)
	    )
	end

	function Gameplay.Rejoin()
	    TeleportService:TeleportToPlaceInstance(
	        game.PlaceId,
	        game.JobId,
	        nil,
	        nil,
	        tonumber(GameplayData.SelectedSlot)
	    )
	end

	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------

	function Gameplay.DiscoverAllRegions()
	    local locations = require(ReplicatedStorage.RS.Modules.Locations)
	    for regionName, _ in pairs(locations.Regions) do
	        ReplicatedStorage.RS.Remotes.Misc.UpdateLastSeen:FireServer(regionName, "")
	    end
	end

	local LoadRemote = ReplicatedStorage.RS.Remotes.NPC.LoadCheck
	function Gameplay.ForceLoad()
	    local character = ODYSSEY.GetLocalCharacter()
	    local hrp = character.HumanoidRootPart
	    ODYSSEY.LoadArea(hrp.Position, false)
	    
	    -- load NPCs
	    for _, npc in ipairs(workspace.NPCs:GetChildren()) do
	        local cf = npc:FindFirstChild("CF")
	        if not cf then continue end
	        if npc:FindFirstChild(npc.Name) then continue end
	        
	        cf = cf.Value
	        if (cf.Position - hrp.Position).Magnitude <= 300 then
	            LoadRemote:Fire(npc)
	        end
	    end

	    -- load enemies
	    for _, enemy in ipairs(ReplicatedStorage.RS.UnloadEnemies:GetChildren()) do
	        local eHrp = enemy:FindFirstChild("HumanoidRootPart")
	        if not eHrp then continue end
	        if (eHrp.Position - hrp.Position).Magnitude > 300 then continue end

	        enemy.Parent = workspace.Enemies
	        LoadRemote:Fire(enemy)
	    end
	end

	ODYSSEY.Timer(1, function()
	    if not GameplayData.ForceLoad then return end
	    Gameplay.ForceLoad()
	end)


	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------

	local eatRemote = ReplicatedStorage.RS.Remotes.Misc.ToolAction

	local InventoryScr = ReplicatedStorage.RS.Modules.Inventory
	local Inventory = require(InventoryScr)

	local function AutoEat()
	    if not GameplayData.AutoEat then return end

	    local ok, hungerBar = pcall(function()
	        return Player:FindFirstChildOfClass("PlayerGui").MainGui:FindFirstChild("HungerBar", true)
	    end)
	    if not ok then return end

	    local ok, hungerText = pcall(function()
	        return hungerBar.Back.Amount
	    end)
	    if not ok then return end


	    local hungerAmount = tonumber(hungerText.Text)
	    if hungerAmount < 100 then
	        local getInvRemote = ReplicatedStorage.RS.Remotes.UI.GetInventoryItems
	        local items = getInvRemote:InvokeServer()

	        -- to combat possible giant meals not working
	        local foods = {}

	        for _, item in ipairs(items) do
	            if item == "FILLER" then continue end
	            local metadata, data = Inventory.GetItemValueInfo(item)
	    
	            if not data then continue end -- wtf
	            if data.SubType == "Fruit" or data.SubType == "Meal" then
	                local name = Inventory.ResolveItemName(metadata)
	                local tool = Player.Backpack:FindFirstChild(name)

	                if not tool then continue end    
	                table.insert(foods, tool)
	            end
	        end

	        if #foods <= 0 then return end
	        local food = foods[math.random(1, #foods)]

	        eatRemote:FireServer(food)
	    end
	end

	ODYSSEY.Timer(3, AutoEat)

	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------

	local lastSeenRemote = ReplicatedStorage.RS.Remotes.Misc.UpdateLastSeen

	ODYSSEY.RemoteTamperer.TamperRemotes({lastSeenRemote}, function()
	    if GameplayData.DisableLastSeen then
	        return false
	    end
	end)

	function Gameplay.SpoofLocation()
	    lastSeenRemote:FireServer("The Dark Sea", "")
	    task.wait(0.1)
	    lastSeenRemote:FireServer("Frostmill Island", "")
	end
end
luacompactModules["src/logic/killaura.lua"] = function()
	local Killaura = {}
	ODYSSEY.Killaura = Killaura

	local KillauraData = ODYSSEY.Data.Killaura or {}
	ODYSSEY.Data.Killaura = KillauraData

	--

	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")

	local REMOTE = game:GetService("ReplicatedStorage").RS.Remotes.Combat.DealWeaponDamage

	local WEAPON = HttpService:JSONEncode({
	    Name = "Bronze Musket",
	    Level = 120
	})
	local ATTACK = "Piercing Shot"
	local AMMO = HttpService:JSONEncode({
		Name = "Golden Bullet",
		Level = 120,
		Amount = 999
	})

	local KILLING = {}

	function KillModel(model, ignoreDistanceLimit)
	    local humanoid = model:FindFirstChildOfClass("Humanoid")
	    local hrp = model:FindFirstChild("HumanoidRootPart")

	    local function GetHealth() end

	    if KILLING[model] then return end
		if model.Name ~= "Shark" then
			if not humanoid or not hrp then return end
			if humanoid.Health <= 0 then return end

	        GetHealth = function() return humanoid.Health end
		else
			local healthVal = model.Attributes.Health
			if healthVal.Value <= 0 then return end

	        GetHealth = function() return healthVal.Value end
		end

	    local cond1 = ODYSSEY.GetLocalPlayer():DistanceFromCharacter(hrp.Position) <= KillauraData.Radius
	    local cond2 = ignoreDistanceLimit
	    if cond1 or cond2 then
	        KILLING[model] = true

	        task.spawn(function()
	            local start = os.clock()

	            while (GetHealth() > 0) and (os.clock() - start < 10) do
	                for _ = 1, math.random(5, 10) do
						task.delay(math.random(0, 0.3), function()
							REMOTE:FireServer(0, ODYSSEY.GetLocalCharacter(), model, WEAPON, ATTACK, AMMO)
						end)
					end
	                task.wait(0.3)
	            end
				
	            KILLING[model] = nil
	        end)
	    end
	end

	function Killaura.KillOnce()
	    for _, enemy in ipairs(workspace.Enemies:GetChildren()) do
	        KillModel(enemy)
	    end

	    if ODYSSEY.Data.KillPlayers then
	        for _, player in ipairs(Players:GetPlayers()) do
	            if player == ODYSSEY.GetLocalPlayer() then continue end
	            KillModel(player.Character)
	        end
	    end
	end

	function Killaura.KillSharks()
	    for _, enemy in ipairs(workspace.Enemies:GetChildren()) do
	        if enemy.Name == "Shark" then
	            KillModel(enemy, true)
	        end
	    end
	end

	ODYSSEY.Timer(2, function()
	    if KillauraData.Active then
	        Killaura.KillOnce()
	    end
	end)
end
luacompactModules["src/logic/money.lua"] = function()
	local Money = {}
	ODYSSEY.Money = Money

	--

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")

	local SellItems = ReplicatedStorage.RS.Remotes.Misc.SellItems
	local BuyItem = ReplicatedStorage.RS.Remotes.Misc.BuyItem

	function Money.MassSell(quantity)
	    local ok, gui = pcall(function()
	        return game.Players.LocalPlayer.PlayerGui.ShopGui
	    end)
	    if not ok then
	        return ODYSSEY.SendNotification(nil, "Crimson Lily", "You are not in a shop GUI.", Color3.new(1, 0, 0))
	    end

	    local vendor = gui.NPC.Value
	    local ok, selectedItem = pcall(function()
	        local jsonData = gui.Frame.SellFrame.SumFrame.Selected.Value
	        return HttpService:JSONDecode(jsonData)
	    end)
	    if not ok then
	        return ODYSSEY.SendNotification(nil, "Crimson Lily", "The item you selected is invalid.", Color3.new(1, 0, 0))
	    end

	    local itemsToSell = {}
	    for i = 0, quantity - 1 do
	        local copy = table.clone(selectedItem)
	        copy.Amount -= i

	        table.insert(itemsToSell, HttpService:JSONEncode(copy))
	    end

	    SellItems:InvokeServer(vendor, itemsToSell, "One")
	end

	function Money.Buy(quantity)
	    local ok, gui = pcall(function()
	        return game.Players.LocalPlayer.PlayerGui.ShopGui
	    end)
	    if not ok then
	        return ODYSSEY.SendNotification(nil, "Crimson Lily", "You are not in a shop GUI.", Color3.new(1, 0, 0))
	    end

	    local vendor = gui.NPC.Value
	    local ok, selectedItem = pcall(function()
	        local jsonData = gui.Frame.ShopFrame.BuyFrame.Selected.Value
	        return HttpService:JSONDecode(jsonData)
	    end)
	    if not ok then
	        return ODYSSEY.SendNotification(nil, "Crimson Lily", "The item you selected is invalid.", Color3.new(1, 0, 0))
	    end

	    BuyItem:InvokeServer(vendor, HttpService:JSONEncode(selectedItem), "", quantity)
	end
end
luacompactModules["src/logic/remote_tamper.lua"] = function()
	local RemoteTamperer = {}
	RemoteTamperer.Tampers = {}

	-- hook game
	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
	    if checkcaller() then
	        return oldNamecall(self, ...)
	    end

	    local args = {...}
	    local method = getnamecallmethod()

	    if (self.ClassName == "RemoteEvent") and (method == "FireServer") then
	        local tamperHandler = RemoteTamperer.Tampers[self]
	        if tamperHandler then
	            local shouldFire = tamperHandler(self, args, oldNamecall)
	            if shouldFire ~= false then
	                return self.FireServer(self, table.unpack(args))
	            end

	            return nil
	        end
	    end

	    return oldNamecall(self, ...)
	end)

	ODYSSEY.MetaHooks[oldNamecall] = {
	    Object = game,
	    Method = "__namecall"
	}

	-- API
	function RemoteTamperer.TamperRemotes(remotes, tamperFunc)
	    for _, remote in ipairs(remotes) do
	        RemoteTamperer.Tampers[remote] = tamperFunc
	    end
	end

	function RemoteTamperer.UntamperRemotes(remotes)
	    for _, remote in ipairs(remotes) do
	        RemoteTamperer.Tampers[remote] = nil
	    end
	end

	return RemoteTamperer
end
luacompactModules["src/logic/teleports.lua"] = function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Locations = require(ReplicatedStorage.RS.Modules.Locations)

	local UnloadedIslands = ReplicatedStorage.RS.UnloadIslands

	local Teleports = {}
	ODYSSEY.Teleports = Teleports

	function Teleports.GetRegions()
		local regions = {}

		--
		for regionName, regionData in pairs(Locations.Regions) do
			local copy = table.clone(regionData)
			local areas = {}
			copy.Name = regionName

			--
			local regionModel = workspace.Map:FindFirstChild(regionName)
			local unloadedModel = UnloadedIslands:FindFirstChild(regionName)

			local regionDescs = regionModel:GetDescendants()

			if unloadedModel then
				for _, v in ipairs(unloadedModel:GetDescendants()) do
					table.insert(regionDescs, v)
				end
			end
			--

			-- areas
			if regionData.Areas then
				for areaName, areaData in pairs(regionData.Areas) do
					local areaCopy = table.clone(areaData)
					areaCopy.Name = areaName
					areaCopy.Region = copy
		
					if not areaData.Center then
						-- area has no Center, but detected through raycast
						for _, v in ipairs(regionDescs) do
							if v:IsA("StringValue") and v.Name == "DisplayName" and v.Value == areaName then
								local possiblePart1 = regionModel:FindFirstChildWhichIsA("BasePart", true)
								local possiblePart2 = possiblePart1

								if unloadedModel then
									possiblePart2 = unloadedModel:FindFirstChildWhichIsA("BasePart", true)
								end
								
								areaCopy.Center = (possiblePart1 and possiblePart1.Position) or (possiblePart2 and possiblePart2.Position)
								areaCopy.Model = v.Parent
								break
							end
						end
					end

					-- gah
					if not areaCopy.Center then
						areaCopy.Center = copy.Center
						areaCopy.Model = regionModel
					end

					table.insert(areas, areaCopy)
				end
			end

			copy.Areas = areas
			table.insert(regions, copy)
		end

		table.sort(regions, function(a, b)
			return a.Name < b.Name
		end)
		--

		return regions
	end

	function Teleports.TeleportToRegion(place)
		local character = ODYSSEY.GetLocalCharacter()
		if not character then return end

		local region = (place.Region and place.Region.Name) or place.Name
		local regionModel = workspace.Map:FindFirstChild(region)
		local center = regionModel:FindFirstChild("Center")

		character:SetPrimaryPartCFrame(center.CFrame)
		character.HumanoidRootPart.Anchored = true

		task.wait(0.15)
		ODYSSEY.Gameplay.ForceLoad()
		
		while not regionModel:FindFirstChild("Fragmentable") do
			regionModel.ChildAdded:Wait()
		end

		--------------------------------------------------------
		local model = place.Model or regionModel

		local destinationPart = nil
		local highestY = -9e9

		local finalPos = nil

		for _, v in ipairs(model:GetDescendants()) do
			if not v:IsA("BasePart") then continue end
			if not v.CanCollide then continue end

			if v.Position.Y + v.Size.Y/2 > highestY then
				highestY = v.Position.Y + v.Size.Y/2
				destinationPart = v
			end
		end

		if destinationPart then
			finalPos = Vector3.new(
				destinationPart.Position.X,
				highestY,
				destinationPart.Position.Z
			)
		else
			finalPos = regionModel.Center.Position
			ODYSSEY.SendNotification(nil, "Crimson Lily", "Failed to find an appropriate teleport destination.", Color3.new(1, 0, 0))
		end
		
		character:SetPrimaryPartCFrame(CFrame.new(finalPos))
		character.HumanoidRootPart.Anchored = false
	end

	Teleports.Regions = Teleports.GetRegions()

	--
	function Teleports.ToShip()
		local boat = workspace.Boats:FindFirstChild(ODYSSEY.GetLocalPlayer().Name.. "Boat")
		if not boat then
			ODYSSEY.SendNotification(nil, "Crimson Lily", "You don't have a ship spawned.", Color3.new(1, 0, 0))
			return
		end

		local character = ODYSSEY.GetLocalCharacter()
		character:SetPrimaryPartCFrame(boat.PrimaryPart.CFrame * CFrame.new(0, 10, 0))
	end

	function Teleports.ToMarker(markerName)
		local marker = workspace.CurrentCamera:FindFirstChild(markerName)
		if marker then
			local character = ODYSSEY.GetLocalCharacter()
			character:SetPrimaryPartCFrame(marker.CFrame)
		else
			ODYSSEY.SendNotification(nil, "Crimson Lily", "This marker does not exist.", Color3.new(1, 0, 0))
		end
	end
end
luacompactModules["src/logic/track.lua"] = function()
	local Trackers = {}
	ODYSSEY.Trackers = Trackers

	local TrackersData = ODYSSEY.Data.Trackers or {}
	ODYSSEY.Data.Trackers = TrackersData

	ODYSSEY.InitData("ShipESP", true, TrackersData)
	ODYSSEY.InitData("UnloadedShipESP", false, TrackersData)
	ODYSSEY.InitData("PlayerESP", true, TrackersData)
	ODYSSEY.InitData("PlayerMarkers", true, TrackersData)

	local islandsESP = TrackersData.Islands or {}
	TrackersData.Islands = islandsESP

	for _, region in ipairs(ODYSSEY.Teleports.Regions) do
	    ODYSSEY.InitData(region.Name, false, islandsESP)
	end

	--

	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local UnloadedBoats = ReplicatedStorage.RS.UnloadBoats
	local UnloadedBoats2 = ReplicatedStorage.RS.UnloadNPCShips

	local BoatsModule = require(ReplicatedStorage.RS.Modules.Boats)

	local Maid = load("src/lib/Maid.lua")

	--
	local ESP = load("src/lib/ESP.lua")
	ESP.Enabled = true

	ODYSSEY.Maid:GiveTask(function()
	    for _, object in pairs(ESP.Objects) do
	        object:Remove()
	    end
	    ESP.Objects = {}
	end)

	ESP.Overrides.UpdateAllow = function(self)
	    -- players
	    if self.Player then
	        return TrackersData.PlayerESP
	    end

	    -- boats
	    if self.Object:FindFirstChild("BoatHandler") then
	        if not TrackersData.UnloadedShipESP then
	            if self.Object.Parent ~= workspace.Boats then
	                return false
	            end
	        end

	        return TrackersData.ShipESP
	    end
	   
	    -- regions
	    if self.RegionName then
	        return TrackersData.Islands[self.RegionName]
	    end

	    return true
	end

	--
	local function TrackCharacter(character)
	    if ESP:GetBox(character) then return end
	    ESP:Add(character, {
	        Player = Players:GetPlayerFromCharacter(character),
	        RenderInNil = true
	    })
	end

	local function TrackBoat(boat)
	    if ESP:GetBox(boat) then return end
	    
	    local isNPC = boat:FindFirstChild("NPCShip") ~= nil
	    local type = boat:WaitForChild("Type").Value
	    local equips = boat:WaitForChild("Equips").Value

	    local title, titleColor = BoatsModule.GetBoatTitle(type, equips)
	    local data = title

	    if title == "" then
	        title = type
	    end
	    if isNPC then
	        local faction = boat.NPCShip.Value
	        data = string.format("%s %s", faction, title)
	    else
	        data = title
	    end

	    ESP:Add(boat, {
	        Color = titleColor,
	        Size = Vector3.new(1, 1, 1),
	        Data = data,
	        RenderInNil = true
	    })
	end

	--
	for _, island in ipairs(workspace.Map:GetChildren()) do
	    if not island:FindFirstChild("Center") then continue end
	   
	    local box = ESP:Add(island.Center, {
	        Color = Color3.fromRGB(76, 42, 135),
	        RenderInNil = true,
	        Name = "",
	        Size = Vector3.new(1, 1, 1),
	        Data = island.Name
	    })
	    box.RegionName = island.Name
	end

	--
	ODYSSEY.Timer(1, function()
	    -- players
	    for _, player in ipairs(Players:GetPlayers()) do
	        if not player.Character then continue end
	        if player == ODYSSEY.GetLocalPlayer() then continue end

	        TrackCharacter(player.Character)
	    end

	    -- botes
	    for _, boat in ipairs(workspace.Boats:GetChildren()) do
	        TrackBoat(boat)
	    end

	    for _, boat in ipairs(UnloadedBoats:GetChildren()) do
	        TrackBoat(boat)
	    end

	    for _, boat in ipairs(UnloadedBoats2:GetChildren()) do
	        TrackBoat(boat)
	    end
		
		-- cleanup
		for _, esp in pairs(ESP.Objects) do
			if (not esp.Object) or (not esp.Object:IsDescendantOf(game)) then
				esp:Remove()
			end
		end
	end)


	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------

	--[[
	local localPlayer = ODYSSEY.GetLocalPlayer()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local worldMapScr, mapGui = nil, nil
	local newPoint, adjustPoint = nil

	local TrackersMaid = Maid.new()
	ODYSSEY.Maid:GiveTask(TrackersMaid)

	local function onDescAdded(c)
	    if c.Name == "WorldMap" and c:IsA("LocalScript") then
	        local numChild = #c:GetChildren()
	        while numChild < 11 do
	            c.ChildAdded:Wait()
	        end
	        worldMapScr = c
	        
	        local regionVal = localPlayer:WaitForChild("bin"):WaitForChild("Region")
	        local updateQM = nil

	        for _, conn in next, getconnections(regionVal.Changed) do
	            local env = getfenv(conn.Function)
	            if rawget(env, "script") == worldMapScr then
	                updateQM = getupvalues(conn.Function)[4]
	            end
	        end

	        newPoint = getupvalues(updateQM)[4]
	        adjustPoint = getupvalues(updateQM)[5]
	    end
	    if c.Name == "Map" then
	        mapGui = c
	    end
	end

	for _, c in ipairs(playerGui:GetDescendants()) do
	    onDescAdded(c)
	end
	ODYSSEY.Maid:GiveTask(localPlayer.CharacterAdded:Connect(function()
	    TrackersMaid:Destroy()
	    task.wait(2)

	    TrackersMaid:GiveTask(function()
	        worldMapScr, mapGui = nil, nil
	        newPoint, adjustPoint = nil, nil
	    end)
	    for _, c in ipairs(playerGui:GetDescendants()) do
	        onDescAdded(c)
	    end
	end))

	while not (worldMapScr and mapGui and newPoint and adjustPoint) do
	    task.wait()
	end

	--------
	local NAME_COLORS =
	{
		Color3.new(253/255, 41/255, 67/255), -- BrickColor.new("Bright red").Color,
		Color3.new(1/255, 162/255, 255/255), -- BrickColor.new("Bright blue").Color,
		Color3.new(2/255, 184/255, 87/255), -- BrickColor.new("Earth green").Color,
		BrickColor.new("Bright violet").Color,
		BrickColor.new("Bright orange").Color,
		BrickColor.new("Bright yellow").Color,
		BrickColor.new("Light reddish violet").Color,
		BrickColor.new("Brick yellow").Color,
	}

	local function GetNameValue(pName)
		local value = 0
		for index = 1, #pName do
			local cValue = string.byte(string.sub(pName, index, index))
			local reverseIndex = #pName - index + 1
			if #pName%2 == 1 then
				reverseIndex = reverseIndex - 1
			end
			if reverseIndex%4 >= 2 then
				cValue = -cValue
		end
			value = value + cValue
		end
		return value
	end

	local color_offset = 0
	local function ComputeNameColor(pName)
		return NAME_COLORS[((GetNameValue(pName) + color_offset) % #NAME_COLORS) + 1]
	end
	--------

	function Trackers.CreatePlayerMarkers()
	    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
	        local character = player.Character
	        if not character then continue end

	        local hrp = character.PrimaryPart
	        if not hrp then continue end

	        if mapGui:FindFirstChild(player.Name, true) then continue end

	        local image = (player == localPlayer and "12535015260") or "12637955397"
	        local size = (player == localPlayer and UDim2.fromOffset(50, 50)) or nil

	        local color = ComputeNameColor(player.Name)
	        local name = string.format("%s (@%s)", player.DisplayName, player.Name)

	        local _, a, b = pcall(newPoint, color, name, hrp.Position.X, hrp.Position.Z, nil, true, "rbxassetid://".. image, size, color)
	        a.Name = player.Name
	        b.Name = player.Name

	        local smallMaid = Maid.new()
	        TrackersMaid:GiveTask(smallMaid)

	        smallMaid:GiveTask(game:GetService("RunService").Heartbeat:Connect(function()
	            if not a.Parent or not b.Parent then
	                return smallMaid:Destroy()
	            end
	            if not adjustPoint then
	                return smallMaid:Destroy()
	            end
	            
	            adjustPoint(a, b, hrp.Position.X, hrp.Position.Z)
	        end))
	        smallMaid:GiveTask(a)
	        smallMaid:GiveTask(b)
	    end
	end


	ODYSSEY.Timer(0.5, function()
	    if not worldMapScr or not worldMapScr.Parent then
	        return
	    end

	    if TrackersData.PlayerMarkers then
	        Trackers.CreatePlayerMarkers()
	    end
	end)]]
end
luacompactModules["src/ui/changelogs.lua"] = function()
	return {
	    {
	        Date = "5/3/2023",
	        Entries = {
	            "Improved teleports and fixed the loading lag (mostly)",
	            "Made Damage Nullification work",
	            "Added killaura",
	            "(Maybe) fixed shark damage"
	        }
	    },
	    {
	        Date = "9/3/2023",
	        Entries = {
	            "Added AI targeting break (still won't prevent them from aggroing once you hit them)",
	            "Changed killaura to use Commodore Kai's Sabre instead, which should increase its effective range (i think)"
	        }
	    },
	    {
	        Date = "10/3/2023",
	        Entries = {
	            "Improved teleporting fr",
	            "Added some banger shits"
	        }
	    },
	    {
	        Date = "12/3/2023",
	        Entries = {
	            "Added force load around yourself",
	            "Improved ESPs in general, should no longer be outdated",
	            "Added unloaded ships tracker",
	            "Added region markers (yay)",
	            "All your configs are now saved, and will be loaded on run"
	        }
	    },
	    {
	        Date = "17/3/2023",
	        Entries = {
	            "Changed No dash stamina to just straight up infinite stamina lmao",
	            "Added no knockback option in Combat",
	            "Added forced NPC load",
				"Improved kill aura. Shits now broken af"
	        }
	    },
	    {
	        Date = "18/3/2023",
	        Entries = {
	            "Added basic autofish",
	            "Added auto eat",
	        }
	    },
	    {
	        Date = "19/3/2023",
	        Entries = {
	            "Added disable last seen remote",
	            "Fixed auto eat for real (maybe) ((hopefully)) (((i think so)))",
	            "Added kill all sharks button",
	            "Added rocksalt auto farm"
	        }
	    },
	    {
	        Date = "20/3/2023",
	        Entries = {
	            "Cleaned up some internal code",
	            "Added join lowest ping server",
	            "Beautified the config file for easy reading",
	            "I think I figured out why auto eat kept failing",
	            "Autofish merged into Farming tab"
	        }
	    },
	    {
	        Date = "21/3/2023",
	        Entries = {
	            "Introducing, the One Hundred Percent Automatic Fisher that can fish from anywhere, while you are doing anything",
	            "Added the Money tab"
	        }
	    },
	    {
	        Date = "25/3/2023",
	        Entries = {
	            "Witness omniscience in display",
	            "nvm disabled it for now since too crashy"
	        }
	    }
}
end
luacompactModules["src/ui/combat.lua"] = function()
	local function InitDamage(tab)
		local CombatData = ODYSSEY.Data.Combat

		ODYSSEY.InitData("DamageReflect", false, CombatData)
		ODYSSEY.InitData("DamageNull", true, CombatData)
		ODYSSEY.InitData("DamageAmp", false, CombatData)
		ODYSSEY.InitData("DamageAmpValue", 5, CombatData)
		
		tab:NewSection("Damage tamper")
		tab:NewLabel("All the damage tampers only work against NPCs", "left")
		tab:NewToggle("Damage Nullification", CombatData.DamageNull, function(value)
			CombatData.DamageNull = value
		end)
		tab:NewToggle("Damage Reflection", CombatData.DamageReflect, function(value)
			CombatData.DamageReflect = value
		end)
		tab:NewToggle("Damage Amplification", CombatData.DamageAmp, function(value)
			CombatData.DamageAmp = value
		end)

		tab:NewSlider("Damage Amp", "", true, "/", {min = 1, max = 100, default = CombatData.DamageAmpValue}, function(value)
			CombatData.DamageAmpValue = value
		end)
	end

	local function InitKillaura(tab)
		local KillauraData = ODYSSEY.Data.Killaura

		ODYSSEY.InitData("Active", false, KillauraData)
		ODYSSEY.InitData("KillPlayers", false, KillauraData)
		ODYSSEY.InitData("Radius", 100, KillauraData)

		tab:NewSection("Killaura")
		tab:NewSlider("Radius", "m", true, "/", {min = 1, max = 300, default = KillauraData.Radius}, function(value)
			KillauraData.Radius = value
		end)
		tab:NewToggle("Killaura", KillauraData.Active, function(value)
			KillauraData.Active = value
		end)
		tab:NewToggle("Kill players", KillauraData.KillPlayers, function(value)
			KillauraData.KillPlayers = value
		end)
		tab:NewButton("Kill once", function()
			ODYSSEY.Killaura.KillOnce()
		end)
		tab:NewButton("Kill all sharks", function()
			ODYSSEY.Killaura.KillSharks()
		end)
	end

	local function InitOther(tab)
		local CombatData = ODYSSEY.Data.Combat

		ODYSSEY.InitData("NoStamina", true, CombatData)
		ODYSSEY.InitData("BreakAI", true, CombatData)
		ODYSSEY.InitData("NoKnockback", true, CombatData)

		tab:NewSection("Miscellaneous")
		tab:NewToggle("Infinite stamina", CombatData.NoStamina, function(value)
			CombatData.NoStamina = value
			ODYSSEY.Combat.UpdateStamina()
		end)
		tab:NewToggle("No knockback", CombatData.NoKnockback, function(value)
			CombatData.NoKnockback = value
		end)

		tab:NewToggle("Break AI targeting", CombatData.BreakAI, function(value)
			CombatData.BreakAI = value
		end)
	end

	return function(UILib, window)
		local tab = window:NewTab("Combat")
		
		InitDamage(tab)
		InitKillaura(tab)
		InitOther(tab)
	end
end
luacompactModules["src/ui/farming.lua"] = function()
	local Farming = ODYSSEY.Data.Farming

	local function InitRockSalt(tab)
	    ODYSSEY.InitData("Rocksalt", false, Farming)
	    ODYSSEY.InitData("RocksaltSpeed", 20, Farming)
	    ODYSSEY.InitData("RocksaltGems", true, Farming)

	    tab:NewSection("Rocksalt farm")
	    tab:NewToggle("Rocksalt farm", Farming.Rocksalt, function(value)
	        Farming.Rocksalt = value
	        ODYSSEY.Farming.RocksaltFarm()
	    end)
	    tab:NewToggle("Pick up gems only", Farming.RocksaltGems, function(value)
	        Farming.RocksaltGems = value
	    end)
	    tab:NewSlider("Speed", "times/s", false, "", {min = 1, max = 60, default = Farming.RocksaltSpeed}, function(value)
	        Farming.RocksaltSpeed = value
	    end)
	end

	local function InitAutofish(window)
	    local AutofishData = ODYSSEY.Data.Autofish

	    ODYSSEY.InitData("AutofishToggle", false, AutofishData)
	    ODYSSEY.InitData("FishingRod", "", AutofishData)
	    
	    window:NewSection("Autofish")
	    window:NewToggle("Autofish", AutofishData.AutofishToggle, function(value)
	        AutofishData.AutofishToggle = value
	    end)

	    --
	    local rods = ODYSSEY.Autofish.GetFishingRods()
	    local rodNames = {}
	    local rodMap = {}

	    if #rods > 0 then
	        local lastSavedRod = AutofishData.FishingRod

	        for _, rodData in ipairs(rods) do
	            table.insert(rodNames, rodData[1].ResolvedName)
	            rodMap[rodData[1].ResolvedName] = rodData
	        end
	    
	        if not rodMap[lastSavedRod] then
	            AutofishData.FishingRod = rodNames[math.random(1, #rodNames)]
	        end
	        
	        window:NewSelector("Fishing rod", AutofishData.FishingRod, rodNames, function(value)
	            AutofishData.FishingRod = value
	        end)
	    else
	        ODYSSEY.SendNotification(nil, "Crimson Lily", "You don't have any fishing rods. Get a rod and try again.", Color3.new(1, 0, 0))
	    end

	    --
	    local player = ODYSSEY.GetLocalPlayer()
	    local character = player.Character

	    local function getPos()
	        local pos = character.PrimaryPart.Position
	        return pos.X, pos.Y, pos.Z
	    end
	    
	    window:NewLabel("Set the position to fish at to your character's position", "le")
	    window:NewLabel("Move to a body of water and press the button to set the position there", "le")
	    window:NewLabel("This affects your fishes", "le")

	    local posLabel = window:NewLabel(string.format("Current position: %.2f, %.2f, %.2f", getPos()))

	    window:NewButton("Record position", function()
	        character = player.Character
	        AutofishData.Position = {getPos()}

	        posLabel:Text(string.format("Current position: %.2f, %.2f, %.2f", getPos()))
	    end)
	    window:NewButton("Teleport to position", function()
	        character = player.Character
	        character:SetPrimaryPartCFrame(CFrame.new(table.unpack(AutofishData.Position)))
	    end)
	end

	return function(UILib, window)
	    local tab = window:NewTab("Farming")

	    InitRockSalt(tab)
	    InitAutofish(tab)
	end
end
luacompactModules["src/ui/gameplay.lua"] = function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Basic = require(ReplicatedStorage.RS.Modules.Basic)

	local bin = ODYSSEY.GetLocalPlayer():WaitForChild("bin")

	--
	local GameplayData = ODYSSEY.Data.Gameplay

	--
	local seaNames = {}
	local seaNameToIds = {}

	for seaId, seaName in pairs(Basic.MainUniverse) do
	    table.insert(seaNames, seaName)
	    seaNameToIds[seaName] = seaId
	end

	ODYSSEY.InitData("SelectedSeaId", seaNameToIds["The Bronze Sea"], GameplayData)
	ODYSSEY.InitData("SelectedSlot", bin:WaitForChild("File").Value, GameplayData)
	ODYSSEY.InitData("ForceLoad", true, GameplayData)
	ODYSSEY.InitData("DisableLastSeen", true, GameplayData)
	ODYSSEY.InitData("AutoEat", true, GameplayData)

	return function(UILib, window)
	    local tab = window:NewTab("Gameplay")

	    tab:NewSection("Region")
	    tab:NewToggle("Force load around yourself", GameplayData.ForceLoad, function(value)
	        GameplayData.ForceLoad = value
	    end)
	    tab:NewToggle("Disable last seen (also prevents Insanity 5 damage)", GameplayData.DisableLastSeen, function(value)
	        GameplayData.DisableLastSeen = value
	    end)

	    tab:NewButton("Discover every region", function()
	        ODYSSEY.Gameplay.DiscoverAllRegions()
	    end)

	    tab:NewLabel("Use in conjunction with Disable last seen to keep your location on bounty at Dark Sea at all times.")
	    tab:NewButton("Spoof location to Dark Sea", function()
	        ODYSSEY.Gameplay.SpoofLocation()
	    end)

	    tab:NewSection("Auto eat")
	    tab:NewToggle("Auto eat", GameplayData.AutoEat, function(value)
	        GameplayData.AutoEat = value
	    end)

	    tab:NewSection("Load slots")
	    tab:NewSelector("Sea", Basic.MainUniverse[GameplayData.SelectedSeaId], seaNames, function(value)
	        GameplayData.SelectedSeaId = seaNameToIds[value]
	    end)

	    tab:NewSelector("Slot", GameplayData.SelectedSlot, {"1", "2", "3", "4", "5", "6"}, function(value)
	        GameplayData.SelectedSlot = value
	    end)
	    
	    tab:NewButton("Join random server", function()
	        ODYSSEY.Gameplay.LoadSlot()
	    end)
	    tab:NewButton("Join empty server", function()
	        ODYSSEY.Gameplay.ServerHop()
	    end)
	    tab:NewButton("Join lowest ping server", function()
	        ODYSSEY.Gameplay.JoinFastestServer()
	    end)
	    tab:NewButton("Rejoin", function()
	        ODYSSEY.Gameplay.Rejoin()
	    end)
	end
end
luacompactModules["src/ui/info.lua"] = function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RS = ReplicatedStorage:WaitForChild("RS")

	local function InitNavyInfluence(tab)
	    local navyInfluence = RS.NavyInfluence
	    local maxNavyInfluence = 1000000
	    local inf = tab:NewLabel()
	   
	    local function update()
	        local percentage = navyInfluence.Value / maxNavyInfluence
	        inf:Text(string.format("Grand Navy influence: %.2f", percentage * 100).. "%")
	    end

	    update()
	    ODYSSEY.Maid:GiveTask(navyInfluence.Changed:Connect(update))
	end

	local function InitChangelogs(tab)
	    local changelogs = load("src/ui/changelogs.lua")

	    tab:NewSection("Changelogs")
	    for _, bigEntry in ipairs(changelogs) do
	        tab:NewLabel(string.format("<b>%s</b>", bigEntry.Date))

	        for _, smallEntry in ipairs(bigEntry.Entries) do
	            tab:NewLabel("- ".. smallEntry)
	        end
	    end
	end

	return function(UILib, window)
		local tab = window:NewTab("Info")

		InitNavyInfluence(tab)
	    InitChangelogs(tab)
	end
end
luacompactModules["src/ui/init.lua"] = function()
	local UILib = load("src/lib/xsxLib.lua")
	UILib.title = "The Crimson Lily"
	UILib:Introduction()

	task.wait(0.5)
	local window = UILib:Init()

	ODYSSEY.Maid:GiveTask(function()
		window:Remove()
	end)

	if game.PlaceId ~= 3272915504 then
		load("src/ui/combat.lua")(UILib, window)
		load("src/ui/teleport.lua")(UILib, window)
		load("src/ui/farming.lua")(UILib, window)
		load("src/ui/money.lua")(UILib, window)
		load("src/ui/trackers.lua")(UILib, window)
	end

	load("src/ui/gameplay.lua")(UILib, window)
	load("src/ui/info.lua")(UILib, window)
end
luacompactModules["src/ui/money.lua"] = function()
	local function InitMassSell(tab)
	    tab:NewSection("Mass selling")
	    tab:NewLabel("Select an item in a shop GUI as normal, then use the mass sell button below", "le")

	    local quantity = 0
	    
	    tab:NewTextbox("Quantity", "", "", "numbers", "small", true, false, function(value)
	        quantity = tonumber(value)
	    end)
	    tab:NewButton("Sell", function()
	        if not quantity or typeof(quantity) ~= "number" or math.floor(quantity) ~= quantity then
	            return ODYSSEY.SendNotification(nil, "Crimson Lily", "You entered an invalid quantity.", Color3.new(1, 0, 0))
	        end

	        ODYSSEY.Money.MassSell(quantity)
	    end)
	end

	local function InitBuy(tab)
	    tab:NewSection("Cursed buying")
	    tab:NewLabel("You can buy a non-integer amount of an item lmao", "le")

	    local quantity = 0
	    
	    tab:NewTextbox("Quantity", "", "", "text", "small", true, false, function(value)
	        quantity = tonumber(value)
	    end)
	    tab:NewButton("Buy", function()
	        if not quantity or typeof(quantity) ~= "number" then
	            return ODYSSEY.SendNotification(nil, "Crimson Lily", "You entered an invalid quantity.", Color3.new(1, 0, 0))
	        end

	        ODYSSEY.Money.Buy(quantity)
	    end)
	end

	return function(UILib, window)
	    local tab = window:NewTab("Money")

	    InitBuy(tab)
	    InitMassSell(tab)
	end
end
luacompactModules["src/ui/teleport.lua"] = function()
	local function InitMisc(tab)
		tab:NewSection("Misc teleports")
		tab:NewButton("Teleport to your ship", function()
			ODYSSEY.Teleports.ToShip()
		end)
		tab:NewButton("Teleport to current story quest", function()
			ODYSSEY.Teleports.ToMarker("StoryMarker1")
		end)
		tab:NewButton("Teleport to quest", function()
			ODYSSEY.Teleports.ToMarker("QuestMarker1")
		end)
	end

	local function InitPlaces(tab)
		tab:NewSection("Place teleports")
		
		local regions = ODYSSEY.Teleports.Regions
		for _, placeData in ipairs(regions) do
			tab:NewSection(placeData.Name)
			tab:NewButton(placeData.Name, function()
				ODYSSEY.Teleports.TeleportToRegion(placeData)
			end)

			if placeData.Areas then
				for _, areaData in pairs(placeData.Areas) do
					tab:NewButton(areaData.Name, function()
						ODYSSEY.Teleports.TeleportToRegion(areaData)
					end)
				end
			end
		end
	end

	return function(UILib, window)
		local tab = window:NewTab("Teleport")
		
		InitMisc(tab)
		InitPlaces(tab)
	end
end
luacompactModules["src/ui/trackers.lua"] = function()
	local Trackers = ODYSSEY.Data.Trackers

	return function(UILib, window)
	    local tab = window:NewTab("Trackers")

	    -- ship esp
	    tab:NewSection("Ship ESP")
	    tab:NewToggle("Track ships", Trackers.ShipESP, function(value)
	        Trackers.ShipESP = value
	    end)
	    tab:NewToggle("Track unloaded ships", Trackers.UnloadedShipESP, function(value)
	        Trackers.UnloadedShipESP = value
	    end)

	    -- player esp
	    tab:NewSection("Player ESP")
	    tab:NewToggle("Track players", Trackers.PlayerESP, function(value)
	        Trackers.PlayerESP = value
	    end)

	    tab:NewToggle("Show player markers on Map", Trackers.PlayerMarkers, function(value)
	        Trackers.PlayerMarkers = value
	    end)

	    -- island esp
	    tab:NewSection("Islands ESP")
	    local islandsESP = Trackers.Islands

	    for _, region in ipairs(ODYSSEY.Teleports.Regions) do
	        tab:NewToggle(region.Name, islandsESP[region.Name], function(value)
	            islandsESP[region.Name] = value
	        end)
	    end
	end
end

local env = assert(getgenv, "Unsupported exploit")()

if env.ODYSSEY then
    env.ODYSSEY.Maid:Destroy()
    env.ODYSSEY = nil
end

-- services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- modules
local Maid = load("src/lib/Maid.lua")

local ODYSSEY = {
    Hooks = {},
    MetaHooks = {},
	
	Data = {},
    Maid = Maid.new(),
}
env.ODYSSEY = ODYSSEY

-- overall cleanup task
ODYSSEY.Maid:GiveTask(function()
    for original, hook in pairs(ODYSSEY.Hooks) do
        hookfunction(hook, original)
    end

    for original, hookData in pairs(ODYSSEY.MetaHooks) do
        hookmetamethod(hookData.Object, hookData.Method, original)
    end

    table.clear(ODYSSEY)
end)

-- read config file
if isfile("CrimsonLily.json") then
    local config = HttpService:JSONDecode(readfile("CrimsonLily.json"))
    ODYSSEY.Data = config
end

-- helpers
function ODYSSEY.GetLocalPlayer()
	return Players.LocalPlayer
end

function ODYSSEY.GetLocalCharacter()
	return ODYSSEY.GetLocalPlayer().Character
end

function ODYSSEY.Timer(interval, func)
    local cancelled = false
    ODYSSEY.Maid:GiveTask(function()
        cancelled = true
    end)

    task.spawn(function()
        while not cancelled do
            local ok, err = pcall(func)
            if not ok then
                warn("[Crimson Lily] Timer error: ".. err)
            end
            task.wait(interval)
        end
    end)
    
    return function()
        cancelled = true
    end
end

function ODYSSEY.InitData(name, value, customPath)
    local path = customPath or ODYSSEY.Data
    if path[name] == nil then
        path[name] = value
    end
end


-- init
ODYSSEY.RemoteTamperer = load("src/logic/remote_tamper.lua")

-- logic
if game.PlaceId ~= 3272915504 then
    load("src/logic/core.lua")

    load("src/logic/combat.lua")
    load("src/logic/killaura.lua")

    load("src/logic/teleports.lua")
    load("src/logic/track.lua")
    
    load("src/logic/autofish.lua")
    load("src/logic/farming.lua")
    load("src/logic/money.lua")
end

load("src/logic/gameplay.lua")
load("src/ui/init.lua")

-- config saving
local json = load("src/lib/json.lua")

ODYSSEY.Timer(1, function()
    local config = json.encode(ODYSSEY.Data, {indent = true})
    writefile("CrimsonLily.json", config)
end)
