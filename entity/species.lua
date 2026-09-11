local species = {}

-- Five trout taxa used in the river. Lengths are adult river fish in cm.
species.list = {
	{ id = "brown", binomial = "Salmo trutta", common = "brown trout", length_cm = { 24, 68 }, color = { 0.42, 0.38, 0.18 }, stripe = { 0.55, 0.32, 0.12 }, cover_need = 0.9, current_tolerance = 0.25, edge_bias = 0.7, depth_pref = 0.55, depth_need = 0.7, rise_depth = 0.48, cruise = 0.055, surface_period = 7.5, manners = { "sip", "rise", "head_and_tail" } },
	{ id = "rainbow", binomial = "Oncorhynchus mykiss", common = "rainbow trout", length_cm = { 22, 62 }, color = { 0.38, 0.46, 0.32 }, stripe = { 0.72, 0.28, 0.38 }, cover_need = 0.45, current_tolerance = 0.8, edge_bias = 0.25, depth_pref = 0.48, depth_need = 0.45, rise_depth = 0.72, cruise = 0.07, surface_period = 5.2, manners = { "rise", "splash", "sip" } },
	{ id = "brook", binomial = "Salvelinus fontinalis", common = "brook trout", length_cm = { 16, 38 }, color = { 0.28, 0.34, 0.22 }, stripe = { 0.62, 0.22, 0.16 }, cover_need = 0.85, current_tolerance = 0.2, edge_bias = 0.9, depth_pref = 0.22, depth_need = 0.8, rise_depth = 0.55, cruise = 0.05, surface_period = 6.4, manners = { "sip", "rise" } },
	{ id = "cutthroat", binomial = "Oncorhynchus clarkii", common = "cutthroat trout", length_cm = { 20, 52 }, color = { 0.40, 0.42, 0.24 }, stripe = { 0.70, 0.30, 0.16 }, cover_need = 0.6, current_tolerance = 0.45, edge_bias = 0.55, depth_pref = 0.35, depth_need = 0.6, rise_depth = 0.62, cruise = 0.06, surface_period = 8.0, manners = { "sip", "head_and_tail", "rise" } },
	{ id = "bull", binomial = "Salvelinus confluentus", common = "bull trout", length_cm = { 32, 86 }, color = { 0.30, 0.32, 0.28 }, stripe = { 0.22, 0.24, 0.22 }, cover_need = 0.75, current_tolerance = 0.35, edge_bias = 0.15, depth_pref = 0.82, depth_need = 0.9, rise_depth = 0.38, cruise = 0.048, surface_period = 16.0, manners = { "porpoise", "rise" } },
}

species.by_id = {}
for i = 1, #species.list do
	species.by_id[species.list[i].id] = species.list[i]
end

-- Wrap an index into the species list.
function species.at(i)
	return species.list[((i - 1) % #species.list) + 1]
end

return species
