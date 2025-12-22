# ==============================================================================
# Taj's Mod - Upload Labs
# Fuzzy Search - Efficient fuzzy matching for command palette
# Author: TajemnikTV
# ==============================================================================
class_name TajsModFuzzySearch
extends RefCounted

## Search result structure
## { "command": Dictionary, "score": float, "matched_title": bool }


## Perform fuzzy search on commands
## Returns sorted array of { command, score, matched_title }
static func search(query: String, commands: Array[Dictionary], context: RefCounted, max_results: int = 12) -> Array[Dictionary]:
	if query.is_empty():
		return []
	
	var results: Array[Dictionary] = []
	var query_lower = query.to_lower()
	
	for cmd in commands:
		# Skip categories in search (they're navigated, not searched)
		if cmd.get("is_category", false):
			continue
		
		# Check visibility
		var can_run_func = cmd.get("can_run", Callable())
		if can_run_func.is_valid() and not can_run_func.call(context):
			continue
		
		var score = _calculate_score(query_lower, cmd)
		if score > 0:
			results.append({
				"command": cmd,
				"score": score,
				"matched_title": _matches_title(query_lower, cmd.get("title", ""))
			})
	
	# Sort by score descending
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Limit results
	if results.size() > max_results:
		results.resize(max_results)
	
	return results


## Calculate match score for a command
## Higher score = better match
## Ranking: exact prefix (100) > word start (80) > substring (60) > fuzzy (40) > keyword match (30)
static func _calculate_score(query: String, cmd: Dictionary) -> float:
	var title = cmd.get("title", "").to_lower()
	var keywords = cmd.get("keywords", [])
	var hint = cmd.get("hint", "").to_lower()
	var best_score = 0.0
	
	# Check title
	if title.begins_with(query):
		best_score = max(best_score, 100.0)
	elif _word_starts_with(title, query):
		best_score = max(best_score, 80.0)
	elif title.contains(query):
		best_score = max(best_score, 60.0)
	elif _fuzzy_match(query, title):
		best_score = max(best_score, 40.0)
	
	# Check keywords
	for keyword in keywords:
		var kw = str(keyword).to_lower()
		if kw.begins_with(query):
			best_score = max(best_score, 50.0)
		elif kw.contains(query):
			best_score = max(best_score, 30.0)
	
	# Check hint (lower priority)
	if hint.contains(query):
		best_score = max(best_score, 20.0)
	
	# Length bonus - prefer shorter titles when scores are close
	if best_score > 0:
		best_score += 10.0 / (title.length() + 1)
	
	return best_score


## Check if query matches the start of any word in text
static func _word_starts_with(text: String, query: String) -> bool:
	var words = text.split(" ", false)
	for word in words:
		if word.begins_with(query):
			return true
	return false


## Simple fuzzy match - checks if all query chars appear in order
static func _fuzzy_match(query: String, text: String) -> bool:
	var query_idx = 0
	var text_idx = 0
	
	while query_idx < query.length() and text_idx < text.length():
		if query[query_idx] == text[text_idx]:
			query_idx += 1
		text_idx += 1
	
	return query_idx == query.length()


## Check if query matches title
static func _matches_title(query: String, title: String) -> bool:
	var title_lower = title.to_lower()
	return title_lower.begins_with(query) or title_lower.contains(query)


## Filter commands by category visibility and context
static func filter_by_context(commands: Array[Dictionary], context: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for cmd in commands:
		var can_run_func = cmd.get("can_run", Callable())
		if can_run_func.is_valid():
			if can_run_func.call(context):
				result.append(cmd)
		else:
			result.append(cmd)
	
	return result
