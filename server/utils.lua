---check if a value is concerned by a pattern group
---@param value any
---@param patterns table<string>
---@return boolean
function SatisfiesPatterns(value, patterns)
	if type(value) ~= "string" then return false end

    for i = 1, #patterns do
        local pattern = patterns[i]

        if string.find(value:lower(), pattern:lower(), 1, true) then
            return true
        end
    end

    return false
end
