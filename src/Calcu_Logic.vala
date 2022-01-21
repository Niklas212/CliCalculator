namespace Calculation {
using GLib.Math;

public errordomain CALC_ERROR {
    INVALID_SYMBOL,
    MISSING_ARGUMENT,
    REMAINING_ARGUMENT,
    MISSING_CLOSING_BRACKET,
    MISSING_OPENING_BRACKET,
    UNKNOWN
}

public enum MODE {
    DEGREE,
    RADIAN;

    public string to_string () {
        return @"$( (this == MODE.DEGREE) ? "DEGREE" : "RADIAN" )";
    }
}

public enum MATCH_DATA_TYPE {
    OPERATOR,
	FUN_INTERN,
	FUN_EXTERN,
	CONTROL,
	VARIABLE,
    AMOUNT_TYPES
}

public class Calculator : GLib.Object
{
    construct {

        match_data = new MatchData ();
        match_data.sort_tokens ();
        match_data.generate_jump_table ();

        multiplication_token = match_data.sorted_tokens.find_node ( (a) => ((TokenData) a).key == "*" ).value;

        negate_token = new TokenData () {
            key = "-",
            type = OPERATOR,
            priority = 1,
            eval_fun = fun_ () {
                arg_left = 0,
                arg_right = 1,
                eval = (values) => -values[0]
            }
        };

        notify ["mode"].connect ( () => deg_to_rad = (mode == DEGREE) ? deg_to_rad_factor : 1 );
    }

    public MODE mode {get; set; default = DEGREE;}
    public static const double deg_to_rad_factor = PI / 180;
    private double deg_to_rad = deg_to_rad_factor;

    public TokenData multiplication_token {get; private set;}
    public TokenData negate_token {get; construct;}

    public MatchData match_data {get; private set;}

    public string input {get; set; default = "";}
	public double? result {get; private set; default = null;}
	public string[] error_info = new string[3];

    public int8 decimal_digits {get; set; default = 4;}
    public bool round_result {get; set; default = false;}

    public LinkedList <TokenData> variables = new LinkedList <TokenData> ();
    public LinkedList <TokenData> functions = new LinkedList <TokenData> ();

    public int bracket {get; set; default = 5;}


    public void clear () {

    }

    public double to_radian (double value) {
        return value * deg_to_rad;
    }

    public TokenData? create_variable (string key, string value_, bool override = true, bool add_to_self = true) throws Calculation.CALC_ERROR {
        var value = eval_auto (value_);
        var variable = new TokenData.variable (key, value);

        if (! add_to_self) {
            return variable;
        }

        var t = match_data [key];

        if (t != null && override && t.type == VARIABLE) {
            match_data [key] = variable;
            variables.find_node ( (a) => ( (TokenData) a).key == key ).value = variable;
        } else {
            match_data.add_token (variable);
            variables.append (variable);
        }

        return variable;
    }

    public TokenData? create_function (string key, string expression, string[] args, bool override = false, bool add_to_self = true) throws Calculation.CALC_ERROR {
        CustomFunctionData fun;
        fun = new CustomFunctionData.generate (key, expression, args, this, match_data);

        if (! add_to_self) {
            return fun;
        }

        var t = match_data [key];

        if (t != null && override && t.type == FUNCTION_EXTERN) {
            match_data [key] = fun;
            functions.find_node ( (a) => ( (TokenData) a).key == key ).value = fun;
        } else {
            match_data.add_token (fun);
            functions.append (fun);
        }

        return fun;
    }

    public void delete_token (string key, Type type = Type.UNDEFINED) throws Calculation.CALC_ERROR {
        var t = match_data [key];

        if (t == null) {
            throw new CALC_ERROR.UNKNOWN ("the symbol '%s' does not exist", key);
        }

        if ( match_data.default_tokens.find_node (
            (a) => ((TokenData) a).key == key) != null) {
            throw new CALC_ERROR.UNKNOWN ("'%s' can not be deleted", key);
        }

        if (t.type == VARIABLE) {
            variables.remove_where ( (a) => ( (TokenData) a).key == key );
        } else if (t.type == FUNCTION_EXTERN) {
            functions.remove_where ( (a) => ( (TokenData) a).key == key );
        }

        match_data.remove_token (key);

    }

    public void remove_symbol (string key) throws Calculation.CALC_ERROR {
        match_data.remove_token (key);
    }

    public bool contains_symbol (string key) {
        return match_data.contains (key);
    }

    public LinkedList <Token?> tokenise (MatchData match_data, out LinkedList <uint?> priorities) throws CALC_ERROR {
        bool can_negative = true;
        bool check_mul = false;

        priorities = priorities ?? new LinkedList <uint?> ();

		Token token = {};
		Type type_of_last_token = UNDEFINED;
		var tokens = new LinkedList <Token?> ();
		var bracket_value = 0;

        int i = 0;
		while (i < input.length) {

            int match_length = -1;
            token = next_match (input, i, match_data, can_negative, ref match_length);

			if (match_length > 0) {

                    // change subtract to negate if necessary
                    if (token.data != null && token.data.key == "-" && (
                        tokens.length == 0 ||
                        tokens.last.data != null && (
                            type_of_last_token == OPENING_BRACKET ||
                            type_of_last_token == SEPARATOR
                        )
                    )) {
                        token.data = negate_token;
                        token.modifier |= CHANGED;
                    }

                    if (check_mul && token.data != null && (
                            token.data.type == VARIABLE ||
                            token.data.type == FUNCTION_INTERN ||
                            token.data.type == FUNCTION_EXTERN ||
                            token.data.type == OPENING_BRACKET
                        )
                    ) {
                        tokens.append (
                            Token () {
                                priority = 2 + bracket_value,
                                modifier = GENERATED,
                                data = multiplication_token
                            }
                        );

                        priorities.insert_sorted (2 + bracket_value, (a, b) => (uint?) b > (uint?) a);
                    }

			        if (token.data == null || token.data.type < Type.OPENING_BRACKET) {
			            if (token.priority != 0)
			                token.priority += bracket_value;
			            tokens.append (token);

			            if (token.data != null && token.data.type > Type.VARIABLE) {
			                priorities.insert_sorted (token.priority, (a, b) => (uint?) b > (uint?) a);
			            }

			        } else if (token.data.type != Type.SEPARATOR) {
			            bracket_value += this.bracket * (Type._BRACKET - token.data.type);

			            if (tokens.length > 0) {

			                if (token.data.type == OPENING_BRACKET) {
			                    tokens.last.bracket_scope ++;
			                    tokens.last.modifier |= OPENING_BRACKET;
			                } else {
			                    tokens.last.bracket_scope --;
			                }

			            }

			        }

			        i += match_length;

                    check_mul = token.has_value || (token.data != null && token.data.type == CLOSING_BRACKET);

			        can_negative = token.data != null && (
			                token.data.type == OPERATOR ||
			                token.data.type == SEPARATOR ||
			                token.data.type == OPENING_BRACKET
			            );

			        if (token.data != null) {
			            type_of_last_token = token.data.type;
			        } else {
			            type_of_last_token = NUMBER;
			        }

			} else {
			    error_info = {
			        input [0 : i],
			        input [i : i + 1],
			        input [i + 1 : input.length]
			    };
			    throw new CALC_ERROR.INVALID_SYMBOL (@"the symbol '$(input[i:i+1])' is not known");
			}

		}

		if (bracket_value != 0) {
		    //TODO throw an error
		}

		return tokens;
	}

	public double eval_ (LinkedList <Token?> tokens, LinkedList <uint?> priorities) throws CALC_ERROR {

		foreach (var priority in priorities) {
			var ind = -1;
			Token? token = null;
			unowned LinkedList.Node? node_of_token = null;

			tokens.each_node_i ( (_node, index, ref proceed) => {
			    unowned var node = (LinkedList.Node<Token?>) _node;

			    if (node.value.has_value == false && node.value.priority == priority) {
			        ind = index;
			        token = node.value;
			        node_of_token = node;
			        proceed = false;
			    }
			} );

            assert (token.data != null);

            //TODO do not allow e.g. sum(4+(4, 4));
			var bracket_scope = 0;
			var check_scope = false;
			if (token.data.eval_fun.arg_right >= 1 || token.data.eval_fun.arg_right == -1)  {
			    check_scope = true;
			    bracket_scope = token.bracket_scope;

			    if (! (OPENING_BRACKET in token.modifier)) {
			        bracket_scope ++;
			    }
			}

			double[] arg = {};

			//get arg_left
			if (token.data.eval_fun.arg_left > 0)
			{
			    Token? previous_token = null;
			    if ( (ind - 1) >= 0 && (previous_token = tokens.get (ind - 1)).has_value ) {
						arg += previous_token.value;
						tokens.remove (ind - 1);
				} else throw new CALC_ERROR.MISSING_ARGUMENT(@"Missing Argument, '$(token.data.key)' requires a left argument");
			}

			//get arg_right
			int l = 0;
			while (l < token.data.eval_fun.arg_right || token.data.eval_fun.arg_right == -1) {
			    l ++;
			    Token? next_arg = null;

			    if ( (ind + 1 - token.data.eval_fun.arg_left) < tokens.length && (next_arg = (Token?) node_of_token.next.value).has_value && !(check_scope && bracket_scope <= 0) ) {
				    arg += next_arg.value;
				    bracket_scope += next_arg.bracket_scope;
				    tokens.remove_next_node (node_of_token);
				} else if (token.data.eval_fun.min_arg_right != -1 && l > token.data.eval_fun.min_arg_right) {
				    break;
				} else {
				    var arg_right = (token.data.eval_fun.min_arg_right > 0) ? token.data.eval_fun.min_arg_right : token.data.eval_fun.arg_right;
				    var no_max = token.data.eval_fun.min_arg_right > 0;
				    var key = token.data.key;
				    throw new CALC_ERROR.MISSING_ARGUMENT(@"Missing Argument, '$key' requires $( (no_max) ? "at least " : "" )$(arg_right) right $( (arg_right > 1) ? "arguments" : "argument"  )");
			    }
			}

			tokens.set (ind - token.data.eval_fun.arg_left, Token () {
				value = token.data.eval_fun.eval (arg, token.data, this),
				has_value = true,
				bracket_scope = bracket_scope,
				data = null
			});
		}

		if (tokens.length > 1) {
		    	throw new CALC_ERROR.REMAINING_ARGUMENT(@"$(tokens.length - 1) $( (tokens.length > 2) ? "arguments are" : "argument is" ) remaining");
		}

        return tokens.first.value;
	}

    public double eval_auto (string in) throws CALC_ERROR {
        this.input = in;

        try {
            #if DEBUG
            int64 msec0 = GLib.get_real_time();
            #endif
            LinkedList <uint?> priorities;
            var tokens = tokenise (match_data, out priorities);
            #if DEBUG
            int64 msec1 = GLib.get_real_time();
            #endif
            var result = eval_ (tokens, priorities);
            this.result = result;
            #if DEBUG
            int64 msec2 = GLib.get_real_time();

            print (@"times\t$(msec1 - msec0)\t$(msec2 - msec1)\n");
            #endif
        }
        catch (Error e) {
            this.clear ();
            throw e;
        }
        this.clear ();

        if (round_result) {
            return round (this.result * pow (10, decimal_digits)) / pow (10, decimal_digits);
        }

        return this.result;
    }

    public static bool compare_uint (uint a, uint b) {
        return a < b;
    }
}

}
