# ==============================================================================
# Taj's Mod - Upload Labs
# Calculator - Safe math expression evaluator using shunting-yard algorithm
# Author: TajemnikTV
# ==============================================================================
class_name TajsModCalculator
extends RefCounted

const LOG_NAME = "TajsModded:Calculator"

# Token types
enum TokenType {
	NUMBER,
	OPERATOR,
	LPAREN,
	RPAREN,
	FUNCTION,
	CONSTANT
}

# Operator precedence and associativity
const OPERATORS = {
	"+": {"prec": 2, "assoc": "left"},
	"-": {"prec": 2, "assoc": "left"},
	"*": {"prec": 3, "assoc": "left"},
	"/": {"prec": 3, "assoc": "left"},
	"^": {"prec": 4, "assoc": "right"},
	"u-": {"prec": 5, "assoc": "right"} # Unary minus (internal)
}

# Supported functions
const FUNCTIONS = ["sqrt", "sin", "cos", "tan", "abs", "log", "ln", "floor", "ceil", "round"]

# Supported constants
const CONSTANTS = {
	"pi": PI,
	"e": 2.718281828459045
}


## Evaluate a math expression and return result or error
## Returns: {"success": bool, "value": float, "error": String}
static func evaluate(expression: String) -> Dictionary:
	# Normalize input
	var normalized = _normalize_expression(expression)
	
	if normalized.strip_edges().is_empty():
		return {"success": false, "value": 0.0, "error": "Empty expression"}
	
	# Tokenize
	var tokens_result = _tokenize(normalized)
	if not tokens_result.success:
		return {"success": false, "value": 0.0, "error": tokens_result.error}
	
	# Convert to RPN using shunting-yard
	var rpn_result = _to_rpn(tokens_result.tokens)
	if not rpn_result.success:
		return {"success": false, "value": 0.0, "error": rpn_result.error}
	
	# Evaluate RPN
	var eval_result = _evaluate_rpn(rpn_result.output)
	return eval_result


## Normalize the expression (handle commas as decimals, whitespace, etc.)
static func _normalize_expression(expr: String) -> String:
	var result = expr.strip_edges()
	# Replace comma with period for decimal separator
	result = result.replace(",", ".")
	return result


## Tokenize the expression into tokens
static func _tokenize(expr: String) -> Dictionary:
	var tokens = []
	var i = 0
	var prev_token_type = -1 # For detecting unary minus
	
	while i < expr.length():
		var c = expr[i]
		
		# Skip whitespace
		if c == " " or c == "\t":
			i += 1
			continue
		
		# Number (including decimals and scientific notation like 1e200, 1.5e-10)
		if c.is_valid_float() or (c == "." and i + 1 < expr.length() and expr[i + 1].is_valid_int()):
			var num_str = ""
			var has_decimal = false
			var has_exponent = false
			
			while i < expr.length():
				var ch = expr[i]
				if ch.is_valid_int():
					num_str += ch
				elif ch == "." and not has_decimal and not has_exponent:
					num_str += ch
					has_decimal = true
				elif (ch == "e" or ch == "E") and not has_exponent and num_str.length() > 0:
					# Scientific notation
					num_str += ch
					has_exponent = true
					i += 1
					# Check for optional sign after exponent
					if i < expr.length() and (expr[i] == "+" or expr[i] == "-"):
						num_str += expr[i]
						i += 1
					continue
				else:
					break
				i += 1
			
			if num_str == "." or num_str.ends_with("e") or num_str.ends_with("E") or num_str.ends_with("+") or num_str.ends_with("-"):
				return {"success": false, "tokens": [], "error": "Invalid number format"}
			
			tokens.append({"type": TokenType.NUMBER, "value": float(num_str)})
			prev_token_type = TokenType.NUMBER
			continue
		
		# Operators
		if c in ["+", "-", "*", "/", "^"]:
			# Check for unary minus
			if c == "-" and (prev_token_type == -1 or prev_token_type == TokenType.OPERATOR or prev_token_type == TokenType.LPAREN):
				tokens.append({"type": TokenType.OPERATOR, "value": "u-"})
			else:
				tokens.append({"type": TokenType.OPERATOR, "value": c})
			prev_token_type = TokenType.OPERATOR
			i += 1
			continue
		
		# Parentheses
		if c == "(":
			tokens.append({"type": TokenType.LPAREN, "value": "("})
			prev_token_type = TokenType.LPAREN
			i += 1
			continue
		
		if c == ")":
			tokens.append({"type": TokenType.RPAREN, "value": ")"})
			prev_token_type = TokenType.RPAREN
			i += 1
			continue
		
		# Identifiers (functions and constants)
		if c.is_valid_identifier():
			var ident = ""
			while i < expr.length() and (expr[i].is_valid_identifier() or expr[i].is_valid_int()):
				ident += expr[i]
				i += 1
			
			var ident_lower = ident.to_lower()
			
			# Check if it's a constant
			if ident_lower in CONSTANTS:
				tokens.append({"type": TokenType.CONSTANT, "value": ident_lower})
				prev_token_type = TokenType.CONSTANT
				continue
			
			# Check if it's a function
			if ident_lower in FUNCTIONS:
				tokens.append({"type": TokenType.FUNCTION, "value": ident_lower})
				prev_token_type = TokenType.FUNCTION
				continue
			
			return {"success": false, "tokens": [], "error": "Unknown identifier: " + ident}
		
		# Percent sign - treat as /100
		if c == "%":
			tokens.append({"type": TokenType.OPERATOR, "value": "/"})
			tokens.append({"type": TokenType.NUMBER, "value": 100.0})
			prev_token_type = TokenType.NUMBER
			i += 1
			continue
		
		return {"success": false, "tokens": [], "error": "Unexpected character: " + c}
	
	return {"success": true, "tokens": tokens, "error": ""}


## Convert tokens to Reverse Polish Notation using shunting-yard algorithm
static func _to_rpn(tokens: Array) -> Dictionary:
	var output = []
	var op_stack = []
	
	for token in tokens:
		match token.type:
			TokenType.NUMBER, TokenType.CONSTANT:
				output.append(token)
			
			TokenType.FUNCTION:
				op_stack.append(token)
			
			TokenType.OPERATOR:
				var op1 = token.value
				while not op_stack.is_empty():
					var top = op_stack.back()
					if top.type == TokenType.LPAREN:
						break
					if top.type == TokenType.FUNCTION:
						output.append(op_stack.pop_back())
						continue
					
					var op2 = top.value
					var op1_info = OPERATORS.get(op1, {"prec": 0, "assoc": "left"})
					var op2_info = OPERATORS.get(op2, {"prec": 0, "assoc": "left"})
					
					if (op1_info.assoc == "left" and op1_info.prec <= op2_info.prec) or \
					   (op1_info.assoc == "right" and op1_info.prec < op2_info.prec):
						output.append(op_stack.pop_back())
					else:
						break
				
				op_stack.append(token)
			
			TokenType.LPAREN:
				op_stack.append(token)
			
			TokenType.RPAREN:
				var found_lparen = false
				while not op_stack.is_empty():
					var top = op_stack.pop_back()
					if top.type == TokenType.LPAREN:
						found_lparen = true
						break
					output.append(top)
				
				if not found_lparen:
					return {"success": false, "output": [], "error": "Mismatched parentheses"}
				
				# If there's a function on top, pop it
				if not op_stack.is_empty() and op_stack.back().type == TokenType.FUNCTION:
					output.append(op_stack.pop_back())
	
	# Pop remaining operators
	while not op_stack.is_empty():
		var top = op_stack.pop_back()
		if top.type == TokenType.LPAREN:
			return {"success": false, "output": [], "error": "Mismatched parentheses"}
		output.append(top)
	
	return {"success": true, "output": output, "error": ""}


## Evaluate RPN expression
static func _evaluate_rpn(rpn: Array) -> Dictionary:
	var stack = []
	
	for token in rpn:
		match token.type:
			TokenType.NUMBER:
				stack.append(token.value)
			
			TokenType.CONSTANT:
				var const_val = CONSTANTS.get(token.value, 0.0)
				stack.append(const_val)
			
			TokenType.OPERATOR:
				var op = token.value
				
				# Unary minus
				if op == "u-":
					if stack.is_empty():
						return {"success": false, "value": 0.0, "error": "Invalid expression"}
					var a = stack.pop_back()
					stack.append(-a)
					continue
				
				# Binary operators
				if stack.size() < 2:
					return {"success": false, "value": 0.0, "error": "Invalid expression"}
				
				var b = stack.pop_back()
				var a = stack.pop_back()
				
				match op:
					"+":
						stack.append(a + b)
					"-":
						stack.append(a - b)
					"*":
						stack.append(a * b)
					"/":
						if b == 0:
							return {"success": false, "value": 0.0, "error": "Division by zero"}
						stack.append(a / b)
					"^":
						stack.append(pow(a, b))
					_:
						return {"success": false, "value": 0.0, "error": "Unknown operator: " + op}
			
			TokenType.FUNCTION:
				if stack.is_empty():
					return {"success": false, "value": 0.0, "error": "Function requires argument"}
				
				var arg = stack.pop_back()
				var func_name = token.value
				
				match func_name:
					"sqrt":
						if arg < 0:
							return {"success": false, "value": 0.0, "error": "Cannot take square root of negative number"}
						stack.append(sqrt(arg))
					"sin":
						stack.append(sin(arg))
					"cos":
						stack.append(cos(arg))
					"tan":
						stack.append(tan(arg))
					"abs":
						stack.append(abs(arg))
					"log":
						if arg <= 0:
							return {"success": false, "value": 0.0, "error": "Logarithm of non-positive number"}
						stack.append(log(arg) / log(10)) # log base 10
					"ln":
						if arg <= 0:
							return {"success": false, "value": 0.0, "error": "Logarithm of non-positive number"}
						stack.append(log(arg)) # natural log
					"floor":
						stack.append(floor(arg))
					"ceil":
						stack.append(ceil(arg))
					"round":
						stack.append(round(arg))
					_:
						return {"success": false, "value": 0.0, "error": "Unknown function: " + func_name}
	
	if stack.size() != 1:
		return {"success": false, "value": 0.0, "error": "Invalid expression"}
	
	var result = stack[0]
	
	# Check for infinity or NaN
	if is_inf(result):
		return {"success": false, "value": 0.0, "error": "Result is infinite"}
	if is_nan(result):
		return {"success": false, "value": 0.0, "error": "Result is undefined"}
	
	return {"success": true, "value": result, "error": ""}


## Format a number for display (up to 6 decimals, trim trailing zeros)
static func format_result(value: float) -> String:
	# Check for very large or very small numbers - use scientific notation
	if abs(value) >= 1e12 or (abs(value) < 1e-6 and value != 0):
		# Use GDScript's built-in scientific notation formatter
		return String.num_scientific(value)
	
	# Format with up to 6 decimal places
	var formatted = "%.6f" % value
	
	# Trim trailing zeros and decimal point if needed
	if "." in formatted:
		formatted = formatted.rstrip("0").rstrip(".")
	
	return formatted
