local bt = {}

bt.SUCCESS = "success"
bt.FAILURE = "failure"
bt.RUNNING = "running"

function bt.sequence(nodes)
	return { kind = "sequence", nodes = nodes, i = 1 }
end

function bt.selector(nodes)
	return { kind = "selector", nodes = nodes, i = 1 }
end

function bt.condition(fn)
	return { kind = "condition", fn = fn }
end

function bt.action(fn)
	return { kind = "action", fn = fn, t = 0 }
end

function bt.clone(node)
	if node.kind == "sequence" or node.kind == "selector" then
		local nodes = {}
		for i = 1, #node.nodes do
			nodes[i] = bt.clone(node.nodes[i])
		end
		return { kind = node.kind, nodes = nodes, i = 1 }
	end
	return { kind = node.kind, fn = node.fn, t = 0 }
end

function bt.tick(node, ctx)
	local kind = node.kind
	if kind == "condition" then
		if node.fn(ctx) then
			return bt.SUCCESS
		end
		return bt.FAILURE
	end
	if kind == "action" then
		return node.fn(ctx, node)
	end
	if kind == "sequence" then
		local n = #node.nodes
		while node.i <= n do
			local st = bt.tick(node.nodes[node.i], ctx)
			if st == bt.RUNNING then
				return bt.RUNNING
			end
			if st == bt.FAILURE then
				node.i = 1
				return bt.FAILURE
			end
			node.i = node.i + 1
		end
		node.i = 1
		return bt.SUCCESS
	end
	if kind == "selector" then
		local n = #node.nodes
		while node.i <= n do
			local st = bt.tick(node.nodes[node.i], ctx)
			if st == bt.RUNNING then
				return bt.RUNNING
			end
			if st == bt.SUCCESS then
				node.i = 1
				return bt.SUCCESS
			end
			node.i = node.i + 1
		end
		node.i = 1
		return bt.FAILURE
	end
	error("unknown behaviour node: " .. tostring(kind))
end

return bt
