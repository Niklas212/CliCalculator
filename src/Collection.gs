[indent=0]
uses GLib.Math

[CCode (has_target = false)]
delegate Eval_ (value: array of double, data: TokenData, calc: Calculation.Calculator): double

[Flags]
enum Modifier
	OPENING_BRACKET
	INVALID
	GENERATED
	CHANGED
	TAGGED


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

			return calc.eval_ (tokens, data.priorities)



	construct generate (_key: string, expression: string, args: array of string, calc: Calculation.Calculator, _match_data: MatchData, test: bool = true) raises Calculation.CALC_ERROR
		self (_key)

		var match_data = _match_data.copy ()

		for var key in args
			match_data.add_Tokenf (new TokenData.variable (key, 0))

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

				calc.eval_ (tokens.copy (), priorities)
			except error: Calculation.CALC_ERROR
				raise new Calculation.CALC_ERROR.UNKNOWN ("invalid expression: %s", error.message)


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


	struct ArgumentInfo
		node: unowned LinkedList.Node of Token?
		argument_index: int

		def to_string (): string
			return "node: %p, argument: %d".printf (node, argument_index)

class MatchData
	prop public default_tokens: LinkedList of TokenData
		get

	prop public sorted_tokens: LinkedList of TokenData
		get

	construct ()
		default_tokens = DefaultValues.get_default_tokens ()

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
				first_char_current_node = char_to_lower (first_char_current_node)

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

		sorting_function: LinkedList.SortingFunction of TokenData = def (a, b)
			if b.key[0].isalpha ()
				if a.key[0].isalpha ()
					if char_to_lower (a.key[0]) < char_to_lower (b.key[0])
						return false
					else if char_to_lower (a.key[0]) > char_to_lower (b.key[0])
						return true
					else
						return a.key.length < b.key.length
				else
					return false
			else if a.key[0].isalpha ()
				return true
			else
				return a.key.length < b.key.length

		for var value in old_list
			new_list.insert_sorted (value, sorting_function)

		sorted_tokens = new_list

	def add_Tokenf (token: TokenData)
		sorted_tokens.append (token)
		sort_tokens ()
		clear_jump_table ()
		generate_jump_table ()

	def add_token (token: TokenData) raises Calculation.CALC_ERROR
		if token.key in self
			raise new Calculation.CALC_ERROR.UNKNOWN ("the key '%s' is already used", token.key)

		sorted_tokens.append (token)
		sort_tokens ()
		clear_jump_table ()
		generate_jump_table ()


	def remove_token (key: string) raises Calculation.CALC_ERROR
		//TODO implement
		if not (key in self)
			raise new Calculation.CALC_ERROR.UNKNOWN ("'%s' is not defined", key)

		remove_fun: LinkedList.CompareFunction of TokenData = def (a)
			return a.key == key

		sorted_tokens.remove_where (remove_fun)
		sort_tokens ()
		clear_jump_table ()
		generate_jump_table ()

	def contains (key: string): bool
		var first_char = key[0]

		if first_char.isalpha ()
			first_char = char_to_lower (first_char)
			node: unowned LinkedList.Node of TokenData = jump_table [first_char - 64].start

			if node == null
				return false
			else
				for var i = 0 to (jump_table [first_char - 64].amount_entries - 1)
					if node.value.key == key
						return true
					node = node.next
				return false

		else
			node: unowned LinkedList.Node of TokenData = jump_table[0].start

			if node == null
				return false

			for var i = 0 to (jump_table [0].amount_entries)
				if node.value.key == key
					return true
				node = node.next
			return false

	def @get (key: string): TokenData?
		var first_char = key[0]

		if first_char.isalpha ()
			first_char = char_to_lower (first_char)
			node: unowned LinkedList.Node of TokenData = jump_table [first_char - 64].start

			if node == null
				return null
			else
				for var i = 0 to (jump_table [first_char - 64].amount_entries - 1)
					if node.value.key == key
						return node.value
					node = node.next
				return null

		else
			node: unowned LinkedList.Node of TokenData = jump_table[0].start

			if node == null
				return null

			for var i = 0 to (jump_table [0].amount_entries)
				if node.value.key == key
					return node.value
				node = node.next
			return null

	def @set (key: string, value: TokenData)
		var first_char = key[0]

		if first_char.isalpha ()
			first_char = char_to_lower (first_char)
			node: unowned LinkedList.Node of TokenData = jump_table [first_char - 64].start

			if node == null
				return
			else
				for var i = 0 to (jump_table [first_char - 64].amount_entries - 1)
					if node.value.key == key
						node.value = value
						return
					node = node.next
				return

		else
			node: unowned LinkedList.Node of TokenData = jump_table[0].start

			if node == null
				return

			for var i = 0 to (jump_table [0].amount_entries)
				if node.value.key == key
					node.value = value
					return
				node = node.next
			return


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
	eval: Eval_
	arg_left: int
	arg_right: int
	min_arg_right: int

	construct (min_arg_right:int = -1)
		this.min_arg_right = min_arg_right

	construct variable_arguments (min_arg_right: int = -1)
		arg_right = int.MAX
		this.min_arg_right = min_arg_right



def get_string_index(arr: array of string, match:string):int
	i:int = 0
	for a in arr
		if a == match
			return i
		i ++
	return -1

def inline char_to_lower (a: char): char
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
	// sorting //TODO use faster algorithm
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
		first_char = char_to_lower (first_char)
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


def next_match (input: string, string_start: int, data: MatchData, can_negative: bool, ref length: int): Token
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

