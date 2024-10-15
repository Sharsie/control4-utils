--- Trim whitespace at start and end of string
---@param s string
---@return string, number
function Trim(s) -- Source: PiL2 20.4
	s = s or ""
	return s:gsub("^%s*(.-)%s*$", "%1")
end
