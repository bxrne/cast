local gfx = {}

-- Release a LÖVE object if it exists.
function gfx.release(obj)
	if obj then
		obj:release()
	end
end

-- Release every argument.
function gfx.release_all(...)
	for i = 1, select("#", ...) do
		gfx.release(select(i, ...))
	end
end

-- Repeating grayscale image filled by fn(x, y) -> 0..1.
function gfx.image(size, fn)
	local data = love.image.newImageData(size, size)
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local n = fn(x, y)
			data:setPixel(x, y, n, n, n, 1)
		end
	end
	local img = love.graphics.newImage(data)
	img:setWrap("repeat", "repeat")
	img:setFilter("linear", "linear")
	return img
end

-- Filled ellipse in local space.
function gfx.ellipse(x, y, rx, ry, rot, rgb, alpha)
	love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha or 1)
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(rot)
	love.graphics.ellipse("fill", 0, 0, rx, ry)
	love.graphics.pop()
end

-- Vertex for a colored textured mesh. Alpha defaults to 1.
function gfx.vert(x, y, u, v, rgb, a)
	return { x = x, y = y, u = u, v = v, r = rgb[1], g = rgb[2], b = rgb[3], a = a or 1 }
end

-- Triangle strip between two equal-length rails.
function gfx.strip(left, right)
	local verts = {}
	for i = 1, #left do
		local l, r = left[i], right[i]
		verts[#verts + 1] = { l.x, l.y, l.u, l.v, l.r, l.g, l.b, l.a or 1 }
		verts[#verts + 1] = { r.x, r.y, r.u, r.v, r.r, r.g, r.b, r.a or 1 }
	end
	return love.graphics.newMesh(verts, "strip", "static")
end

-- Load a shader from a game-relative path.
function gfx.shader(path)
	local code = love.filesystem.read(path)
	assert(code, path)
	return love.graphics.newShader(code)
end

-- Draw a polyline if it has at least two points.
function gfx.line(pts)
	if #pts >= 4 then
		love.graphics.line(pts)
	end
end

return gfx
