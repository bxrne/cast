local bt = {}

bt.SUCCESS, bt.FAILURE, bt.RUNNING = "success", "failure", "running"

-- Run children in order until one returns `short`, else `long`.
local function composite(kind, short, long)
	return function(nodes)
		return { kind = kind, nodes = nodes, i = 1, short = short, long = long }
	end
end

bt.sequence = composite("sequence", bt.FAILURE, bt.SUCCESS)
bt.selector = composite("selector", bt.SUCCESS, bt.FAILURE)

-- Leaf that succeeds when fn(ctx) is true.
function bt.condition(fn)
	return { kind = "condition", fn = fn }
end

-- Leaf that delegates to fn(ctx, node).
function bt.action(fn)
	return { kind = "action", fn = fn, t = 0 }
end

-- Deep-copy a tree so each agent has its own running index.
function bt.clone(node)
	if node.nodes then
		local nodes = {}
		for i = 1, #node.nodes do
			nodes[i] = bt.clone(node.nodes[i])
		end
		return { kind = node.kind, nodes = nodes, i = 1, short = node.short, long = node.long }
	end
	return { kind = node.kind, fn = node.fn, t = 0 }
end

-- Advance one node. Returns success, failure, or running.
function bt.tick(node, ctx)
	if node.kind == "condition" then
		return node.fn(ctx) and bt.SUCCESS or bt.FAILURE
	end
	if node.kind == "action" then
		return node.fn(ctx, node)
	end
	if not node.short then
		error("unknown behaviour node: " .. tostring(node.kind))
	end
	local n = #node.nodes
	while node.i <= n do
		local st = bt.tick(node.nodes[node.i], ctx)
		if st == bt.RUNNING or st == node.short then
			if st ~= bt.RUNNING then
				node.i = 1
			end
			return st
		end
		node.i = node.i + 1
	end
	node.i = 1
	return node.long
end

return bt
