[indent=0]
uses GLib.Math

delegate Eval(value:array of double, data: Data?):double

class abstract Data: Object
	prop public part:Part
		get
			return part


[Flags]
enum Modifier
	OPENING_BRACKET = 1


enum Type
	NUMBER
	VARIABLE
	FUNCTION
	EXPRESSION
	CONTROL
	OPERATOR
/*
struct config
	use_degrees:bool
	round_decimal:bool
	decimal_digit:int
	//custom_variable:Replaceable
	//custom_functions:CustomFunctions
*/
struct MatchData
	children: array of ChildData
	type: Type
	max_length: int

	construct @init (_type: Type, keys: array of string)
		type = _type
		reevaluate (keys)

	def reevaluate (keys: array of string)
		children = new array of ChildData [keys.length]


		for var i = 0 to (keys.length - 1)
			children[i] = ChildData () {key = keys[i], virtual_index = i}

			if keys[i].length > max_length
				max_length = keys[i].length

		for var i = 0 to (children.length - 2)
			for var j = 0 to (children.length - 2)
				if (children[j].key.length < children[j + 1].key.length)
					var tmp = children[j + 1]
					children[j + 1] = children[j]
					children[j] = tmp


struct ChildData
	key: string
	virtual_index: int

struct PreparePart
	value:string
	type:Type
	length:int
	index:int

class UserFunc
	key: array of string
	arg_right: array of int
	data: array of UserFuncData
	eval: Eval

	def add_function(_key:string, _arg_right:int, _data:UserFuncData, _override:bool = false) raises Calculation.CALC_ERROR
		if _key in key
			if _override
				for var i = 0 to (key.length - 1)
					if key[i] == _key
						arg_right[i] = _arg_right
						data[i] = _data
						return
			else
				raise new Calculation.CALC_ERROR.UNKNOWN(@"'$_key' is already defined")
		var keys = key
		var args = arg_right
		var datas = data
		keys += _key
		args += _arg_right
		datas += _data
		key = keys
		arg_right = args
		data = datas

	def remove_function(name:string):int raises Calculation.CALC_ERROR
		if not (name in key) do raise new Calculation.CALC_ERROR.UNKNOWN(@"the function '$name' is not defined")

		index:int = -1

		var keys = new array of string[key.length - 1]
		var args = new array of int[key.length - 1]
		var datas = new array of UserFuncData[key.length - 1]

		if key.length == 1
			key = keys
			arg_right = args
			data = datas
			return 0

		m:int = 0
		for var i = 0 to keys.length
			if key[i] == name
				m = 1
				index = i
			else
				keys[i - m] = key[i]
				args[i - m] = arg_right[i]
				datas[i - m] = data[i]
		key = keys
		data = datas
		arg_right = args

		return index

/*
struct UserFunc
	key: array of string
	eval:Eval
	arg_right: array of int
	data:array of UserFuncData
*/

struct Part
	value: double?
	eval: fun
	has_value: bool
	priority: uint
	data: Data
	modifier: Modifier
	bracket_value: int
	index: int

class Replaceable
	key:array of string
	value:array of double
	amount_protected_variables: int

	def add_variable(_key:string, _value:double, _override:bool = false) raises Calculation.CALC_ERROR
		//TODO: check if name is valid in Calcu_Logic
		if _key in key or _key in DefaultValues.variables.key
			if _key in DefaultValues.variables.key or not _override
				raise new Calculation.CALC_ERROR.UNKNOWN(@"'$(_key)' is already defined")
			if _override
				for var i = 0 to (key.length - 1)
					if key[i] == _key
						key[i] = _key
						value[i] = _value
						return
		var values = value
		var keys = key
		keys += _key
		values += _value
		value = values
		key = keys

	def remove_variable(_name:string):int raises Calculation.CALC_ERROR
		index:int = -1
		if _name in key[amount_protected_variables:key.length]
			var keys = new array of string[key.length - 1]
			var values = new array of double[value.length - 1]
			if key.length == 1
				key = keys
				value = values
				return 0
			m:int = 0
			for var i = 0 to (key.length - 1)
				if key[i] != _name
					keys [i - m] = key[i]
					values [i - m] = value[i]
				else
					m = 1
					index = i
			key = keys
			value = values

			return index
		else if _name in key [0 : amount_protected_variables]
			raise new Calculation.CALC_ERROR.UNKNOWN (@"the variable '$_name' can not be deleted")
		else
			raise new Calculation.CALC_ERROR.UNKNOWN(@"the variable '$_name' does not exist")

class Operation
	key:array of string
	priority:array of int
	eval:array of fun

class Func
	key:array of string
	eval:array of fun

struct fun
	eval:Eval
	arg_left:int
	arg_right:int
	min_arg_right:int

	construct (min_arg_right:int = -1)
		this.min_arg_right = min_arg_right



class UserFuncData: Data
	part_index: array of int
	argument_index: array of int
	sequence: GenericArray of uint?
	parts: GenericArray of Part?

	construct with_data(expression:string, variables: array of string) raises Calculation.CALC_ERROR
		try
			this.generate_data(expression, variables)
		except e: Calculation.CALC_ERROR
			raise e

	def generate_data(expression:string, variables: array of string, test:bool = true) raises Calculation.CALC_ERROR
		var e = new Calculation.Evaluation()
		e.input = expression

		var amount_default_vars = e.variable.key.length

		for i in variables
			if i in e.variable.key
				 raise new Calculation.CALC_ERROR.UNKNOWN(@"'$i' is already defined --- use another variable name")
			else
				e.add_variable (i, 0.0)
		try
			e.split()
		except er: Calculation.CALC_ERROR
			e.clear()
			raise er
		// set part_index && argument_index
		var parts = e.get_parts()
		part_ind: array of int = new array of int[0]
		argument_ind: array of int = new array of int[0]
		i:int = 0
		position:int = -1
		for p in parts
			if p.type == Type.VARIABLE
				position = get_string_index(e.variable.key, p.value)
				if position > (amount_default_vars - 1)
					part_ind += i
					argument_ind += position - amount_default_vars
			else if p.type == Type.CONTROL do i--
			i++
		this.part_index = part_ind
		this.argument_index = argument_ind
		//set sequence && parts
		try
			e.prepare()
			this.parts = e.get_section()
			this.sequence = e.get_sequence()
		except er: Calculation.CALC_ERROR
			e.clear()
			raise er

		//test generated data
		if test
			try
				var test_e = new Calculation.Evaluation.with_data (e.get_section (), e.get_sequence ())
				test_e.set_parts (e.get_parts ())
				test_e.eval()
			except er: Calculation.CALC_ERROR
				er.message = "incorrect expression: " + er.message
				raise er

def get_string_index(arr: array of string, match:string):int
	i:int = 0
	for a in arr
		if a == match
			return i
		i ++
	return -1

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



def next_multi_match (input:string, string_start:int, data:array of MatchData): PreparePart
	max_match_type_index:int = -1
	max_match_index:int = -1
	max_match_length:int = -1

	i:int = -1
	j:int = -1
	// consider using sorted (string-length) data
	for d in data
		i ++
		j = -1

		if max_match_length > d.max_length
			continue

		for e in d.children
			j ++
			if (e.key.length <= (input.length - string_start) && e.key.length > max_match_length && input [string_start : string_start + e.key.length] == e.key)
				max_match_type_index = i
				max_match_index = j
				max_match_length = e.key.length
				break

	if (max_match_length > 0)
		return PreparePart() {
			value = data[max_match_type_index].children[max_match_index].key,
			type = data[max_match_type_index].type,
			length = data[max_match_type_index].children[max_match_index].key.length,
			index = data[max_match_type_index].children[max_match_index].virtual_index
		}
	else
		return PreparePart() {
			length = -1
		}


def next_real_match (input:string, string_start:int, data:array of MatchData, can_negative:bool):PreparePart
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
					return PreparePart () {
						value = input[string_start:i],
						type = NUMBER,
						length = i - string_start
					}
				else do break
	return next_multi_match (input, string_start, data)

