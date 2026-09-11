local species = {}

-- Five trout taxa. Aggression and skittishness are 0..1. feed is rest, nymph, emerge, film.
species.list = {
	{ id = "brown", binomial = "Salmo trutta", common = "brown trout", length_cm = { 24, 68 }, color = { 0.52, 0.44, 0.22 }, stripe = { 0.78, 0.40, 0.14 }, cover_need = 0.9, current_tolerance = 0.25, edge_bias = 0.7, depth_pref = 0.55, depth_need = 0.7, rise_depth = 0.48, cruise = 0.055, surface_period = 7.5, aggression = 0.85, skittish = 0.55, feed_period = 22, feed = { 0.22, 0.48, 0.12, 0.18 }, manners = { "sip", "rise", "head_and_tail" } },
	{ id = "rainbow", binomial = "Oncorhynchus mykiss", common = "rainbow trout", length_cm = { 22, 62 }, color = { 0.30, 0.48, 0.34 }, stripe = { 0.85, 0.34, 0.42 }, cover_need = 0.45, current_tolerance = 0.8, edge_bias = 0.25, depth_pref = 0.48, depth_need = 0.45, rise_depth = 0.72, cruise = 0.07, surface_period = 5.2, aggression = 0.7, skittish = 0.4, feed_period = 16, feed = { 0.12, 0.32, 0.18, 0.38 }, manners = { "rise", "splash", "sip" } },
	{ id = "brook", binomial = "Salvelinus fontinalis", common = "brook trout", length_cm = { 16, 38 }, color = { 0.30, 0.34, 0.18 }, stripe = { 0.85, 0.30, 0.18 }, cover_need = 0.85, current_tolerance = 0.2, edge_bias = 0.9, depth_pref = 0.22, depth_need = 0.8, rise_depth = 0.55, cruise = 0.05, surface_period = 6.4, aggression = 0.35, skittish = 0.8, feed_period = 18, feed = { 0.2, 0.4, 0.15, 0.25 }, manners = { "sip", "rise" } },
	{ id = "cutthroat", binomial = "Oncorhynchus clarkii", common = "cutthroat trout", length_cm = { 20, 52 }, color = { 0.48, 0.44, 0.22 }, stripe = { 0.88, 0.42, 0.22 }, cover_need = 0.6, current_tolerance = 0.45, edge_bias = 0.55, depth_pref = 0.35, depth_need = 0.6, rise_depth = 0.62, cruise = 0.06, surface_period = 8.0, aggression = 0.3, skittish = 0.75, feed_period = 20, feed = { 0.18, 0.38, 0.16, 0.28 }, manners = { "sip", "head_and_tail", "rise" } },
	{ id = "bull", binomial = "Salvelinus confluentus", common = "bull trout", length_cm = { 32, 86 }, color = { 0.38, 0.42, 0.36 }, stripe = { 0.40, 0.44, 0.40 }, cover_need = 0.75, current_tolerance = 0.35, edge_bias = 0.15, depth_pref = 0.82, depth_need = 0.9, rise_depth = 0.38, cruise = 0.048, surface_period = 16.0, aggression = 0.9, skittish = 0.25, feed_period = 28, feed = { 0.4, 0.45, 0.08, 0.07 }, manners = { "porpoise", "rise" } },
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
