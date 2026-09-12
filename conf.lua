---@diagnostic disable: undefined-global

-- LÖVE window and identity.
function love.conf(t)
	t.identity = "cast"
	t.version = "11.5"
	t.console = true
	t.window.title = "cast"
	t.window.width = 1280
	t.window.height = 720
	t.window.resizable = true
end
