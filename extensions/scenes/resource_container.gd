extends "res://scenes/resource_container.gd"

# MOD: Universal Receiver Check
# Check if a target container has the 'is_universal_receiver' method and returns true.
func can_connect(to: ResourceContainer) -> bool:
	if !is_instance_valid(to): return false
	
	# MOD START: Universal Receiver Logic (for Bin)
	if to.has_method("is_universal_receiver") and to.is_universal_receiver():
		return true
	# MOD END
	
	if get_connection_shape() != to.get_connection_shape(): return false
	if (get_connector_color() != "white" and to.get_connector_color() != "white") and get_connector_color() != to.get_connector_color(): return false
	if !can_set(to.resource) or !to.can_set(resource): return false
	if excluded_resources.has(to.resource): return false
	if excluded_colors.has(to.get_connector_color()): return false

	return true
