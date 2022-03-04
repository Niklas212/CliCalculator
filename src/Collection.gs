[indent=0]
uses GLib.Math

[CCode (has_target = false)]
delegate Eval (value: array of double, data: TokenData, calc: Calculation.Calculator): double

[Flags]
enum Modifier
	OPENING_BRACKET
	INVALID
	GENERATED
	CHANGED
	TAGGED
	PARAMETER


enum Type
	NUMBER
	VARIABLE
	FUNCTION_INTERN
	FUNCTION_EXTERN
	OPERATOR
	OPENING_BRACKET
	_BRACKET // must be between OPENING_ and CLOSING_
	CLOSING_BRACKET
	SEPARATOR
	UNDEFINED

def type_to_string (type: Type) : string
	case type
		when NUMBER do return "NUMBER"
		when VARIABLE do return "VARIABLE"
		when FUNCTION_INTERN do return "FUNCTION-INTERN"
		when FUNCTION_EXTERN do return "EXPRESSION-EXTERN"
		when OPERATOR do return "OPERATOR"
		when OPENING_BRACKET do return "OPENINIG-BRACKET"
		when CLOSING_BRACKET do return "CLOSING-BRACKET"
		when SEPARATOR do return "SEPARATOR"
		default do return "UNDEFINED"

struct Token
	has_value: bool
	value: double?
	priority: uint
	modifier: Modifier
	bracket_scope: int
	data: TokenData

	def to_string (): string
		var builder = new StringBuilder ("Token\n")

		builder.append_printf ("\thas-value: %s\n", has_value ? "true" : "false")
		if has_value
			builder.append_printf ("\tvalue: %f\n", value)

		if priority != 0
			builder.append_printf ("\tpriority: %d\n", (int) priority)

		if bracket_scope != 0
			builder.append_printf ("\tbracket-scope: %d\n", bracket_scope)

		if modifier != 0
			builder.append ("\tmodifier: ")

			if OPENING_BRACKET in modifier
				builder.append ("OPENING-BRACKET; ")

			if GENERATED in modifier
				builder.append ("GENERATED; ")

			if CHANGED in modifier
				builder.append ("CHANGED; ")

			if PARAMETER in modifier
				builder.append ("PARAMETER; ")

			builder.append ("\n")

		if data != null
			builder.append_printf ("\tdata: %p ('%s')\n", data, data.key)


		return (string) builder.data

//[Compact]
class TokenData
	key: string
	type: Type
	has_value: bool
	value: double?
	eval_fun: fun_?
	priority: uint

	construct variable (key: string, value: double)
		self.key = key
		type = VARIABLE
		has_value = true
		self.value = value

	construct undefined ()
		type = UNDEFINED

	def generate_token (): Token
		return Token () {
			has_value = has_value,
			value = value,
			priority = priority,
			data = self
		}

	def generate_tagged_token (): Token
		return Token () {
			has_value = has_value,
			value = value,
			priority = priority,
			data = self,
			modifier = TAGGED
		}

	def to_string (): string
		var builder = new StringBuilder ("TokenData\n")
		builder.append_printf ("\tkey: '%s'\n", key)
		builder.append_printf ("\ttype: %s\n", type_to_string (type))
		builder.append_printf ("\thas-value: %s\n", has_value ? "true" : "false")
		if has_value
			builder.append_printf ("\tvalue: %f\n", value)
		builder.append_printf ("\tpriority: %d\n", (int) priority)

		return (string) builder.data

class CustomFunctionData : TokenData
	priorities: LinkedList of uint?
	tokens: LinkedList of Token?
	arguments: array of ArgumentInfo
	parameters: array of TokenData

	print_progress: static bool = false
	//used by to_function_string ()
	insert_spaces: static bool = true

	construct (key: string)
		type = FUNCTION_EXTERN
		has_value = false
		self.key = key
		priority = 4

		eval_fun = fun_ ()
		eval_fun.eval = def (values, data_, calc)
			var data = data_ as CustomFunctionData

			for var arg_info in data.arguments
				arg_info.node.value.value = values [arg_info.argument_index]

			var tokens = data.tokens.copy ()

			return calc.eval (tokens, data.priorities)



	construct generate (_key: string, expression: string, args: array of string, calc: Calculation.Calculator, _match_data: MatchData, test: bool = true) raises Calculation.CALC_ERROR
		self (_key)

		var match_data = _match_data.copy ()
		parameters = new array of TokenData [args.length]

		var index = 0;
		for var key in args
			var parameter = new TokenData.variable (key, 0)
			match_data.add_Tokenf (parameter)
			parameters [index ++] = parameter

		calc.input = expression;
		tokens = calc.tokenise (match_data, out priorities)

		var argument_info = self.arguments

		iterate_fun: LinkedList.EachNode of Token? = def (_node)
			var token = _node.value
			if token.data != null
				if token.data.type == VARIABLE and token.data.key in args
					var arg_info = ArgumentInfo ()
					arg_info.node = _node
					arg_info.argument_index = get_string_index (args, token.data.key)
					argument_info += arg_info

		tokens.each_node (iterate_fun)
		self.arguments = argument_info

		eval_fun.arg_right = args.length

		if test
			try
				paras: array of double = new array of double [args.length]

				for var i = 1 to args.length
					paras [i - 1] = i

				calc.eval (tokens.copy (), priorities)
			except error: Calculation.CALC_ERROR
				raise new Calculation.CALC_ERROR.UNKNOWN ("invalid expression: %s", error.message)


	construct by_points (_key: string, points: array of Point, match_data: MatchData, needed_decimal_digits: int = 12) raises Calculation.CALC_ERROR
		self (_key)

		// code below checks if multiple points have the same y value and shifts the points

		var y_values = new array of double [points.length, 2]

		for var i = 0 to (points.length - 1)
			var y = points[i].y
			var is_set = false

			for var j = 0 to (i - 1)
				if y_values[j, 0] == y
					y_values [j, 1] ++
					is_set = true
					break;

			if not is_set
				y_values[i, 0] = y

		var y_value = 0.0
		var amount_points = -1.0

		for var i = 0 to (points.length - 1)
			if y_values [i, 1] > amount_points
				amount_points = y_values [i, 1]
				y_value = y_values [i, 0]

		for var i = 0 to (points.length - 1)
			points[i].y -= y_value

		generate_function_from_points (points, match_data, needed_decimal_digits)

		// 'reverse' the shift of the points
		tokens.last.value += y_value

		// delete '+ 0' at the end of the function
		if tokens.length > 1 and tokens.last.value == 0.0
			tokens.remove (tokens.length - 1)
			tokens.remove (tokens.length - 1)
			priorities.remove (priorities.length - 1)


		// + -5 => - 5
		if tokens.length > 1 and tokens.last.value < 0.0
			tokens.last.value *= -1
			tokens [tokens.length - 2] = match_data ["-"].generate_token ()


	construct by_xy_values (_key: string, values: array of double, match_data: MatchData, needed_decimal_digits:int = 12) raises Calculation.CALC_ERROR
		var points = new array of Point[0]

		if values.length % 2 == 1
			raise new Calculation.CALC_ERROR.UNKNOWN ("missing y-value")

		for var i = 0 to (values.length / 2 - 1)
			points += Point (values[i * 2], values[i * 2 + 1])

		self.by_points (_key, points, match_data, needed_decimal_digits)



	/*
		generates a function f(x) = a*x^n + b*x^(n-1) ... that goes through the given points

		to generate the fuction:
			every point has its own subfunction
			the final function is the sum of the subfunctions
			f(x) = g(x) + h(x) + ...

			the subfunction of a point evaluates to point.y for point.x
			for the x-values of the other points it evaluates to 0

				e.g. for the given points: (1, 2), (2, 4), (3, 5)
					g(x) // represents (1, 2)
						g(1) = 2
						g(2) = 0
						g(3) = 0
					h(x) // represents (2, 4)
						h(1) = 0
						h(2) = 4
						h(3) = 0
					i(x) // represents (3, 5)
						i(1) = 0
						i(2) = 0
						i(3) = 5

					final function:
					f(x) = g(x) + h(x) + i (x)
						f(1) = 2
						f(2) = 4
						f(3) = 5

			to generate a subfunction 'g' that represents the point 'p':
				g(x) = p.y * (x - otherPoint.x) * (x - anotherPoint.x) ... / ((p.x - otherPoint.x) * (p.x - anotherPoint.x) ...)

				e.g. for the given points: (1, 2), (2, 4), (3, 5)
					the subfunction that represents the first point:
						g(x) = 2 * (x - 2) * (x - 3) / ( (1 - 2) * (1 - 3))

			the subfunctions are expanded
				e.g. g(x) [see above] = x^2 - 5x + 6

			the subfunctions are summed
				e.g. for the given points: (1, 2), (2, 4), (3, 5)
					g(x) = x^2 - 5x + 6
					h(x) = -4x^2 + 16x - 12
					i(x) = 2.5x^2 - 7.5x + 5

					f(x) = g(x) + h(x) + i(x)
					=> f(x) = -0.5x^2 + 3.5x - 1

	*/

	def generate_function_from_points (points: array of Point, match_data: MatchData, needed_decimal_digits:int = 12) raises Calculation.CALC_ERROR
		eval_fun.arg_right = 1

		var amount_of_points = points.length

		var factors = new array of double[amount_of_points]

		// stores the factors (a, b, ...)
		var values = new array of double[amount_of_points]

		for var i = 0 to (amount_of_points - 1) do factors[i] = 1

		for var f = 0 to (amount_of_points - 1)
			for var i = 0 to (amount_of_points - 1)
				if f == i do continue

				if points[i].x == points[f].x
					raise new Calculation.CALC_ERROR.UNKNOWN ("every point must have a unique x-value")

				factors [i] *= points[i].x - points[f].x


		var max_paths = 1 << (points.length) - 1

		// subfunction for every point
		for var i = 0 to (amount_of_points - 1)
			var path = 0

			if points[i].y == 0
				if print_progress
					print "calculated paths of point [%d/%d]", i + 1, points.length
				continue

			// for every combination: 0 -> 'x' 1 -> x-value
			while (path < (1 << (points.length - 1)))

				if print_progress
					print "calculate path [%d/%d] of point [%d/%d]", path, max_paths, i + 1, points.length

				var cur_value = points[i].y / factors[i]


				var amount_x = 0
				var bit_index = -1

				// evaluate the combination
				for var p = 0 to (points.length - 1)
					if p == i do continue
					else do bit_index ++

					// check wheter multiply with 'x' or -x value of point
					if ((path & (1 << bit_index)) > 0)
						cur_value *= (- points[p].x)
					else
						amount_x ++


				values [amount_x] += cur_value


				path ++


		// round values e.g.  1e-16 -> 0
		if needed_decimal_digits > 0
			for var i = 0 to (values.length - 1)
				if values [i].abs () < exp10 (-needed_decimal_digits)
					values [i] = 0.0
					continue
				values [i] = round (values[i] * exp10 (needed_decimal_digits)) / exp10 (needed_decimal_digits)


		// generate tokens: a*x^n + b*x^(n-1) ...
		tokens = new LinkedList of Token?
		priorities = new LinkedList of uint?
		_arguments: array of ArgumentInfo = self.arguments

		var multiplication_token = match_data ["*"]
		var addition_token = match_data ["+"]
		var subtraction_token = match_data ["-"]
		var power_token = match_data ["^"]

		assert_nonnull (multiplication_token)
		assert_nonnull (addition_token)
		assert_nonnull (subtraction_token)
		assert_nonnull (power_token)

		var amount_power_tokens = 0
		var amount_multiplication_tokens = 0
		var amount_addition_tokens = 0

		// set parameter info
		parameters = {new TokenData.variable ("x", 0)}

		var change_sign = false

		for var i = 0 to (points.length - 1)
			var x = points.length - 1 - i

			if values[x] == 0 and x != 0 do continue

			if (values [x] != 1 and values [x] != -1) or x == 0
				// a
				tokens.append ( Token () {
					has_value = true,
					data = null,
					value = (change_sign) ? -values [x] : values [x]
				} )

				if x == 0 do continue

				// *
				tokens.append (multiplication_token.generate_token ())
				amount_multiplication_tokens ++

			// x
			tokens.append (parameters[0].generate_token ())


			// add argument
			_arguments += ArgumentInfo () {
				argument_index = 0,
				node = tokens.last_node
			}

			if x > 1

				// ^
				tokens.append (power_token.generate_token ())
				amount_power_tokens ++

				// n
				tokens.append ( Token () {
					has_value = true,
					data = null,
					value = x
				} )

			change_sign = false

			if x > 0
				// +
				if values [x - 1] >= 0 or x == 1
					tokens.append (addition_token.generate_token ())
				else
					tokens.append (subtraction_token.generate_token ())
					change_sign = true
				amount_addition_tokens ++

		arguments = _arguments

		// set priorities
		for var i = 0 to (amount_power_tokens - 1)
			priorities.append (power_token.priority)

		for var i = 0 to (amount_multiplication_tokens - 1)
			priorities.append (multiplication_token.priority)

		for var i = 0 to (amount_addition_tokens - 1)
			priorities.append (addition_token.priority)



	struct Point
		x: double
		y: double

		construct (x: double, y:double)
			self.x = x
			self.y = y

	def new to_string (): string
		var builder = new StringBuilder (super.to_string ())

		builder.append ("\n# Function-Data #\n")

		builder.append ("## priorities ##\n")

		for var p in priorities
			builder.append_printf ("\t\t%d\n", (int) p)

		builder.append ("## tokens ##\n")

		for var t in tokens
			builder.append_printf ("%s\n", t.to_string ())

		builder.append_printf ("\targ-info (%d)\n", arguments.length)

		for var a in arguments
			builder.append_printf ("\t\t%s\n", a.to_string ())

		return (string) builder.data

	def to_function_string (): string

		var builder = new StringBuilder (key + " (" + parameters[0].key)

		for var i = 1 to (parameters.length - 1)
			builder.append ("," + parameters[i].key)

		builder.append (") = ")

		var need_separator = false
		var bracket_scope = 0u
		var generated = false

		if tokens.first.data != null
			bracket_scope += (tokens.first.priority - tokens.first.data.priority) / 5
		else if tokens.length > 1
			bracket_scope += (tokens[1].priority - tokens[1].data.priority) / 5

		for var i = 1 to bracket_scope
			builder.append_c ('(')


		for var token in tokens
			generated = GENERATED in token.modifier
			if !generated and token.data == null
				if need_separator
					builder.append (", ")
				builder.append (token.value.to_string ())
			else if !generated
				var append_spaces = insert_spaces and (
					token.data.type == OPERATOR and
					( token.data.eval_fun.arg_right
					+ token.data.eval_fun.arg_left > 1
					)
				)
				if append_spaces do builder.append_c (' ')
				builder.append (token.data.key)
				if append_spaces do builder.append_c (' ')


			if token.bracket_scope != 0
				var scope = token.bracket_scope
				bracket_scope += scope
				var bracket_char = (scope > 0) ? '(' : ')'
				var brackets = (scope > 0) ? scope : -scope

				for var i = 1 to brackets
					builder.append_c (bracket_char)
			else if insert_spaces and (token.data != null) and (token.data.type == FUNCTION_INTERN or token.data.type == FUNCTION_EXTERN)
				// append space before a function, if there is no bracket: 'sinx' => 'sin x'
				builder.append_c (' ')

			need_separator = token.data == null

		return (string) builder.data;


	struct ArgumentInfo
		node: unowned LinkedList.Node of Token?
		argument_index: int

		def to_string (): string
			return "node: %p, argument: %d".printf (node, argument_index)

class MatchData
	prop public default_tokens: LinkedList of TokenData
		get
		set

	prop public sorted_tokens: LinkedList of TokenData
		get
		set

	sorting_function: static LinkedList.SortingFunction of TokenData

	init static
		sorting_function = def (a, b)
			if b.key[0].isalpha ()
				if a.key[0].isalpha ()
					if char_to_upper (a.key[0]) < char_to_upper (b.key[0])
						return false
					else if char_to_upper (a.key[0]) > char_to_upper (b.key[0])
						return true
					else
						return a.key.length < b.key.length
				else
					return false
			else if a.key[0].isalpha ()
				return true
			else
				return a.key.length < b.key.length


	construct ()
		default_tokens = DefaultValues.get_default_tokens ()

		for var i = 0 to 26
			jump_table [i].amount_entries = 0
			jump_table [i].start = null

	jump_table: JumpTableData[27] // index-0 is for non alphabetic characters

	struct JumpTableData
		start: unowned LinkedList.Node of TokenData
		amount_entries: int

		def to_string (): string
			return "JumpTableData\n\tstart-node: %p ('%s')\n\tamount-entries: %d\n".printf (start, (start == null) ? "" : start.value.key, amount_entries)

	def copy () : MatchData
		var match_data = new MatchData ()

		match_data.default_tokens = self.default_tokens.copy ()
		match_data.sorted_tokens = self.sorted_tokens.copy ()

		for var i = 0 to 26
			match_data.jump_table[i] = self.jump_table[i]

		return match_data



	def generate_jump_table ()

		first_char_previous_node: char = '\0'
		fun: LinkedList.EachNode of TokenData = def (node)
			var first_char_current_node = node.value.key[0]
			var is_alpha = first_char_current_node.isalpha ()

			if is_alpha
				first_char_current_node = char_to_upper (first_char_current_node)

			if first_char_previous_node == first_char_current_node or not is_alpha
				if is_alpha
					jump_table[first_char_previous_node - 64].amount_entries += 1
				else
					if jump_table[0].amount_entries == 0
						jump_table[0].start = node
					jump_table[0].amount_entries += 1
			else
				if is_alpha
					var jump_table_index = first_char_current_node - 64
					jump_table[jump_table_index].start = node
					jump_table[jump_table_index].amount_entries += 1
				else
					jump_table[0].start = node
					jump_table[0].amount_entries += 1

			first_char_previous_node = first_char_current_node

		sorted_tokens.each_node (fun)

	def clear_jump_table ()
		for var i = 0 to 26
			jump_table [i].amount_entries = 0
			jump_table [i].start = null

	def sort_tokens ()
		var old_list = (sorted_tokens == null) ? default_tokens : sorted_tokens
		var new_list = new LinkedList of TokenData

		for var value in old_list
			new_list.insert_sorted (value, (LinkedList.SortingFunction of TokenData) self.sorting_function)

		sorted_tokens = new_list

	def add_Tokenf (token: TokenData)
		sorted_tokens.append (token)
		sort_tokens ()
		clear_jump_table ()
		generate_jump_table ()

	def add_token (token: TokenData) raises Calculation.CALC_ERROR
		if token.key in self
			raise new Calculation.CALC_ERROR.UNKNOWN ("the key '%s' is already used", token.key)

		last_token: TokenData = null


		fun: LinkedList.EachNodeI of TokenData = def (node, index, ref proceed)
			if not sorting_function (token, node.value) or index + 1 == sorted_tokens.length

				var is_last = false

				if sorting_function (token, node.value)
					index ++
					is_last = true

				var first_char = token.key [0]

				if first_char.isalpha () do first_char = char_to_upper (first_char)

				if first_char.isalpha ()

					if last_token != null and last_token.key[0].toupper () == first_char
						jump_table [first_char - 64].amount_entries += 1
						sorted_tokens.insert (token, index)
					else
						sorted_tokens.insert (token, index)
						jump_table [first_char - 64].amount_entries += 1

						if (not is_last) or (node.value.key[0].toupper () != first_char)
							jump_table [first_char - 64].start = sorted_tokens.get_node (index)
				else
					if last_token != null and last_token.key[0] == first_char
						jump_table [0].amount_entries += 1
						sorted_tokens.insert (token, index)
					else
						sorted_tokens.insert (token, index)
						jump_table [0].amount_entries += 1

						if (not is_last) or (node.value.key[0] != first_char)
							jump_table [0].start = sorted_tokens.get_node (index)

				proceed = false



			last_token = node.value
			assert_nonnull (last_token)

		sorted_tokens.each_node_i (fun)

	def remove_token (key: string) raises Calculation.CALC_ERROR

		if not (key in self)
			raise new Calculation.CALC_ERROR.UNKNOWN ("'%s' is not defined", key)

		remove_fun: LinkedList.CompareFunction of TokenData = def (a)
			return a.key == key

		var index = (key[0].isalpha ()) ? (char_to_upper (key[0]) - 64) : 0

		if jump_table [index].start.value.key == key
			if jump_table [index].start.next != null and char_to_upper (jump_table [index].start.next.value.key [0]) == char_to_upper (key [0])
				jump_table [index].start = jump_table [index].start.next
			else
				jump_table [index].start = null

		jump_table [index].amount_entries -= 1

		sorted_tokens.remove_where (remove_fun)


	def private _get (key: string): unowned LinkedList.Node of TokenData
		var first_char = key[0]

		if first_char.isalpha ()
			first_char = char_to_upper (first_char)
			node: unowned LinkedList.Node of TokenData = jump_table [first_char - 64].start

			if node == null
				return null
			else
				for var i = 0 to (jump_table [first_char - 64].amount_entries - 1)
					if node.value.key == key
						return node
					node = node.next
				return null

		else
			node: unowned LinkedList.Node of TokenData = jump_table[0].start

			if node == null
				return null

			for var i = 0 to (jump_table [0].amount_entries)
				if node.value.key == key
					return node
				node = node.next
			return null

	def @contains (key: string): bool
		return _get (key) != null

	def @get (key: string): TokenData?
		res: unowned LinkedList.Node of TokenData = _get (key)
		return (res == null) ? null : res.value

	def @set (key: string, value: TokenData)
		node: unowned LinkedList.Node of TokenData = _get (key)

		if node == null
			return

		node.value = value


	def to_string (): string
		var builder = new StringBuilder ("# MatchData #\n\n")
		builder.append ("## default-tokens ##\n")

		for var token in default_tokens
			builder.append (token.to_string ())

		builder.append ("\n## sorted-tokens ##\n")

		for var token in sorted_tokens
			builder.append (token.to_string ())

		builder.append ("\n## jump-table ##\n")

		for var i = 0 to 26
			builder.append (jump_table[i].to_string ())

		return (string) builder.data

struct fun_
	eval: Eval
	arg_left: int
	arg_right: int
	min_arg_right: int

	construct (min_arg_right:int = -1)
		this.min_arg_right = min_arg_right

	construct variable_arguments (min_arg_right: int = -1)
		arg_right = int.MAX
		this.min_arg_right = min_arg_right



def get_string_index (arr: array of string, match:string):int
	i:int = 0
	for a in arr
		if a == match
			return i
		i ++
	return -1

def inline char_to_upper (a: char): char
	return ((a - 65) % 32) + 65

def faq(a:double):double
	if a<0 do return 0
	if a==0 do return 1
	ret:double=1
	for var i=1 to a
		ret*=i
	return ret

def mod(a:double,b:double):double
	d:double=a/b
	dc:double=floor(d)
	if d==dc do return 0
	ret:double=(d-dc)*b
	return Math.round(ret*100000)/100000

def sum (v:array of double): double
	result:double = 0
	for d in v
		result += d
	return result


def mean (v:array of double): double
	result:double = 0
	for d in v
		result += d
	return result / v.length

def median (v: array of double): double
	for var i = 0 to (v.length - 2)
		for var j = 0 to (v.length - 2)
			if (v[j] > v[j + 1])
				var tmp = v[j + 1]
				v[j + 1] = v[j]
				v[j] = tmp

	if v.length % 2 == 0 do return (v[v.length / 2] + v[(v.length - 1) / 2]) / 2
	else do return v[(v.length - 1) / 2]


def get_next_token (input: string, string_start: int, data: MatchData): Token
	var first_char = input[string_start]
	var max_match_length = input.length - string_start

	if first_char.isalpha ()
		first_char = char_to_upper (first_char)
		var jump_table_index = first_char - 64

		node: unowned LinkedList.Node of TokenData = data.jump_table[jump_table_index].start

		for var i = 1 to data.jump_table[jump_table_index].amount_entries
			if max_match_length >= node.value.key.length && node.value.key == input [string_start : string_start + node.value.key.length]
				return node.value.generate_token ()

			node = node.next
	else
		node: unowned LinkedList.Node of TokenData = data.jump_table[0].start
		// i is 1 because [a to b] is including b
		for var i = 1 to data.jump_table[0].amount_entries
			if max_match_length >= node.value.key.length && node.value.key == input [string_start : string_start + node.value.key.length]
				return node.value.generate_token ()

			node = node.next

	return Token () {
		modifier = INVALID
	}


[Flags]
enum MatchOptions
	ALLOW_SCIENTIFIC_NOTATION
	ALLOW_UNDERSCORES
	ALL = (ALLOW_SCIENTIFIC_NOTATION
		| ALLOW_UNDERSCORES)

def string_to_double (str: string): double
	var result = 0.0;
	var negative = false;
	var has_sign = false
	var is_decimal = false;
	var factor = 0.1;
	var i = 0

	if str[0] == '-'
		i ++
		negative = true
		has_sign = true
	else if str[0] == '+'
		i ++
		has_sign = true

	while i < (str.length - 1)
		var _char = str[i]

		if _char >= 48 and _char <= 57
			if not is_decimal
				result *= 10
				result += _char - 48
			else
				result += (_char - 48) * factor
				factor *= 0.1
		else if _char == '.'
			if is_decimal or (has_sign and i == 1)
				break
			is_decimal = true
		else if _char == '_' and (i > 1 or (not has_sign and i > 0))
			pass
		else
			break

		i ++

	if negative
		result = -result

	return result

def next_match (input: string, string_start: int, data: MatchData, can_negative: bool, ref length: int, options: MatchOptions = ALL): Token
	can_number:bool = false
	is_decimal:bool = false
	is_number:bool = false

	if (can_negative && (input[string_start] == '-' || input[string_start] == '+'))
		can_number = true
	else if input[string_start].isdigit ()
		can_number = true
		is_number = true
	else if input[string_start] == '.'
		can_number = true
		is_decimal = true

	if can_number
		var i = string_start
		while (++i <= input.length)
			if input[i].isdigit ()
				is_number = true
			else if (!is_decimal && input[i] == '.')
				is_decimal = true
			else
				if is_number
					length = i - string_start
					return Token () {
						value = double.parse (input[string_start:i]),
						has_value = true
					}
				else do break

	var token =  get_next_token (input, string_start, data)
	if token.data == null
		length = -1
	else
		length = token.data.key.length
	return token


