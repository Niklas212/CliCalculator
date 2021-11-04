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

public class Evaluation : GLib.Object
{
    construct {

        if (! DefaultValues.is_initialised) {
            DefaultValues.init ();
            DefaultValues.is_initialised = true;
        }

        match_data = new MatchData[MATCH_DATA_TYPE.AMOUNT_TYPES];

        variable = DefaultValues.new_variables;

        fun_extern = new UserFunc ();

        fun_intern_deg = DefaultValues.get_intern_functions (DEGREE);
        fun_intern_rad = DefaultValues.get_intern_functions (RADIAN);

        fun_intern = fun_intern_deg;

        // using new_operators instead of operators is not required in this case
        operator = DefaultValues.new_operators;

        init_match_data ();
    }

    public Evaluation.with_data (GenericArray<Part?> parts, GenericArray<uint?> seq) {
        var _section = new GenericArray <Part?> ();
        var _sequence = new GenericArray <uint?> ();

        parts.foreach( (x) => _section.add(x) );
        seq.foreach( (x) => _sequence.add(x) );

        this.section = _section;
        this.sequence = _sequence;
    }

    private MODE _mode;

    public MODE mode {
        get {
            return _mode;
        }
        set {
            _mode = value;

            if (_mode == MODE.RADIAN)
                fun_intern = fun_intern_rad;
            else
                fun_intern = fun_intern_deg;

        }
    }

    public string input {get; set; default = "";}
	public double? result {get; private set; default = null;}
	public string[] error_info = new string[3];

    public int8 decimal_digits {get; set; default = 4;}
    public bool round_result {get; set; default = false;}

	private PreparePart[] parts = {};
	private GenericArray <Part?> section = new GenericArray <Part?> ();
	public GenericArray <uint?> sequence = new GenericArray <uint?> ();

	public Operation operator {get; set;}

    private Func fun_intern_deg;
    private Func fun_intern_rad;
    public Func fun_intern {get; set; }

    public UserFunc fun_extern {get; set;}
    public Replaceable variable {get; set;}

    public int bracket {get; set; default = 5;}
	public string[] control {get; set; default={"(", ")", ",", " "};}

	private MatchData[] match_data;

    public bool contains_symbol (string symbol, bool check_vars = true, bool check_funs = true) {
        return (symbol in variable.key && check_vars) || symbol in fun_intern.key || (symbol in fun_extern.key && check_funs);
    }

    public void add_variable (string key, double value, bool override = true) throws CALC_ERROR {
        variable.add_variable (key, value, override);
        match_data[MATCH_DATA_TYPE.VARIABLE].key = variable.key;
    }

    public double create_variable (string key, string value, bool override = true) throws CALC_ERROR{
            eval_auto (value);
            add_variable (key, result, override);
            return result;
    }

    public void remove_variable (string key) throws CALC_ERROR {
        variable.remove_variable (key);
        match_data[MATCH_DATA_TYPE.VARIABLE].key = variable.key;
    }

    public void add_function (string key, int arg_right, UserFuncData data, bool override = false) throws CALC_ERROR {
        fun_extern.add_function (key, arg_right, data, override);
        match_data[MATCH_DATA_TYPE.FUN_EXTERN].key = fun_extern.key;
    }

    public void create_function (string key, string expression, string[] variables) throws CALC_ERROR {
        add_function (key, variables.length, new UserFuncData.with_data (expression, variables), false);
    }

    public void remove_function (string key) throws CALC_ERROR {
        fun_extern.remove_function (key);
        match_data[MATCH_DATA_TYPE.FUN_EXTERN].key = fun_extern.key;
    }

    public void clear(){
        parts={};
        section.remove_range(0,section.length);
        sequence.remove_range (0, sequence.length);
    }

    public void init_match_data () {
        match_data = {
		    MatchData () {key = operator.key, type = OPERATOR},
		    MatchData () {key = fun_intern.key, type = EXPRESSION},
		    MatchData () {key = fun_extern.key, type = FUNCTION},
		    MatchData () {key = control, type = CONTROL},
		    MatchData () {key = variable.key, type = VARIABLE}
		};
    }

    public PreparePart[] get_parts() {
        return this.parts;
    }

    public GenericArray<Part?> get_section() {
        return this.section;
    }

    public GenericArray<uint?> get_sequence() {
        return this.sequence;
    }

    public void set_parts (PreparePart[] parts) {
        this.parts = parts;
    }

	public void split() throws CALC_ERROR
	{
        bool can_negative=true;
        bool check_mul=false;

		PreparePart ap = {};

        int i = 0;
		while (i < input.length) {

            ap = next_real_match (input[i:input.length], match_data, can_negative);

			if(ap.length>0)
			    {
                    if(check_mul&&(!(ap.type==Type.OPERATOR||ap.type==Type.NUMBER||(ap.type==Type.CONTROL&&!(ap.value=="(")))))
                        parts+=PreparePart(){value="*", type=Type.OPERATOR, length=1, index=2};

                   if (ap.value == "-" && (parts.length == 0 || (parts[parts.length - 1].type == Type.CONTROL && parts[parts.length - 1].value != ")")))
                        parts += PreparePart(){value="0", type=Type.NUMBER};

			        parts += ap;
			        i += ap.length;

			        can_negative=(ap.type==Type.OPERATOR||(ap.type==Type.CONTROL&&ap.value!=")"));
			        check_mul=(ap.type==Type.NUMBER||ap.type==Type.VARIABLE||ap.value==")");
			    }
			else {
			    error_info = {
			        input [0 : i],
			        input [i : i + 1],
			        input [i + 1 : input.length]
			    };

			    throw new CALC_ERROR.INVALID_SYMBOL (@"the symbol `$(input[i:i+1])` is not known");
			}

		}
	}

	public void prepare() throws CALC_ERROR
	{
		int bracket_value = 0;
		int invisible_parts = 0;

		foreach (PreparePart part in parts)
		{
			switch (part.type)
			{
				case Type.VARIABLE: {
					section.add (Part () {
						value = variable.value[part.index],
						has_value = true
					});

					break;
				}
				case Type.NUMBER: {
					section.add (Part () {
						value = double.parse (part.value),
						has_value = true
					});

					break;
				}
				case Type.OPERATOR: {
					section.add (Part () {
					    index = section.length + invisible_parts,
						eval = operator.eval[part.index],
						priority = bracket_value + operator.priority[part.index]
					});
					sequence.add (bracket_value + operator.priority[part.index]);

					break;
				}
				case Type.EXPRESSION: {
				    section.add (Part () {
				        index = section.length + invisible_parts,
				        eval = fun_intern.eval[part.index],
				        priority = 4 + bracket_value
				    });
                    sequence.add (bracket_value + 4);
				    break;
				}
				case Type.FUNCTION: {
				    section.add (Part () {
				        index = section.length + invisible_parts,
				        priority = 4 + bracket_value,
				        eval = fun(){eval = fun_extern_eval, arg_right = fun_extern.arg_right[part.index]},
				        data  = (fun_extern.data[part.index])
				    });
				    //TODO pass config
				    sequence.add (bracket_value + 4);
				    break;
				}
				case Type.CONTROL: {
				    invisible_parts ++;
					if (part.value == ")") {
					    bracket_value -= bracket;
					    if (section.length >= 1)
					        section.get (section.length - 1).bracket_value --;
					}
					else if (part.value == "(") {
					    bracket_value += bracket;
                        if (section.length >= 1) {
					        section.get (section.length - 1).bracket_value ++;
					        section.get (section.length - 1).modifier |= OPENING_BRACKET;
					    }
					}
					break;
				}
				default: {
					break;
				}
			}
		}

	    if(bracket_value!=0) {
	        if(bracket_value>0) {
                throw new CALC_ERROR.MISSING_CLOSING_BRACKET(@" '$(bracket_value/bracket)' closing $((bracket_value/bracket==1)?"bracket is":"brackets are") missing");
	        }
	        else {
	            bracket_value*=-1;
                throw new CALC_ERROR.MISSING_OPENING_BRACKET(@" '$(bracket_value/bracket)' opening $((bracket_value/bracket==1)?"bracket is":"brackets are") missing");
	        }
	    }

	    if (section.length < 1)
	        throw new CALC_ERROR.MISSING_ARGUMENT ("");

	}

	public void eval() throws CALC_ERROR
	{

        sequence.sort ( (a, b) => (int) (a < b) );


		for (int i = 0; i < sequence.length; i++)
		{
			var ind = -1;

			for (int j = 0; j < section.length; j++)
			    if (section.get(j).has_value == false && section.get(j).priority == sequence.get(i)) {
			        ind = j;
			        break;
			    }

			var part = section.get (ind);

			var bracket_scope = 0;
			var check_scope = false;
			if ( (part.eval.arg_right >= 1 || part.eval.arg_right == -1) ) {
			    check_scope = true;
			    bracket_scope = part.bracket_value;

			    if (! (OPENING_BRACKET in part.modifier)) {
			        bracket_scope ++;
			    }
			    //bracket_scope += (int) (OPENING_BRACKET in part.modifier);
			}

			double[] arg = {};

			//get arg_left
			if (part.eval.arg_left > 0)
			{
			    if ( (ind - 1) >= 0 && section.get (ind - 1).has_value) {
				    arg += section.get (ind - 1).value;
				    section.remove_index (ind - 1);
				}
				else throw new CALC_ERROR.MISSING_ARGUMENT(@"Missing Argument, '$(parts[ind].value)' requires a left argument");
			}

			//get arg_right
			int l = 0;
			while (l < part.eval.arg_right || part.eval.arg_right == -1)
			{
			    l ++;
			    if ( (ind + 1 - part.eval.arg_left) < section.length && section.get (ind + 1 - part.eval.arg_left).has_value && !(check_scope && bracket_scope <= 0) ) {
				    arg += section.get (ind + 1 - part.eval.arg_left).value;
				    bracket_scope += section.get (ind + 1 - part.eval.arg_left).bracket_value;
				    section.remove_index (ind + 1 - part.eval.arg_left);
				}
				else if (part.eval.min_arg_right != -1 && l > part.eval.min_arg_right) {
				    break;
				}
				else {
				    var arg_right = (part.eval.min_arg_right > 0) ? part.eval.min_arg_right : part.eval.arg_right;
				    var no_max = part.eval.min_arg_right > 0;
				    var key = parts[part.index].value;
				    throw new CALC_ERROR.MISSING_ARGUMENT(@"Missing Argument, '$key' requires $( (no_max) ? "at least " : "" )$(arg_right) right $( (arg_right > 1) ? "arguments" : "argument"  )");
			    }
			}

			section.set (ind - part.eval.arg_left, Part() {
				value = part.eval.eval(arg, part.data),
				has_value = true,
				bracket_value = bracket_scope
			});
		}

		if (section.length > 1) {
		    	throw new CALC_ERROR.REMAINING_ARGUMENT(@"$(section.length - 1) $( (section.length > 2) ? "arguments are" : "argument is" ) remaining");
		}

		result = section.get(0).value ?? 0 / 0;

		if (round_result) {
		    result = round (result * pow (10, decimal_digits)) / pow (10, decimal_digits);
	    }
	}

    public double eval_auto (string in) throws CALC_ERROR {
        this.input = in;

        try {
            #if DEBUG
            int64 msec0 = GLib.get_real_time();
            #endif
            this.split();
            #if DEBUG
            int64 msec1 = GLib.get_real_time();
            #endif
            this.prepare();
            #if DEBUG
            int64 msec2 = GLib.get_real_time();
            #endif
            this.eval();
            #if DEBUG
            int64 msec3 = GLib.get_real_time();
            print (@"times\t$(msec1 - msec0)\t$(msec2 - msec1)\t$(msec3 - msec2)\n");
            #endif
        }
        catch(Error e) {
            this.clear();
            throw e;
        }
        this.clear();
        return this.result;
    }

    public static double eval_trusted_function (double[] value, UserFuncData data) {

        var sequence = new GenericArray <uint?> (data.parts.length);
        var section = new GenericArray <Part?> (data.sequence.length);

        data.parts.foreach ((part) => section.add (part));
        data.sequence.foreach ((seq) => sequence.add (seq));

        // set parameters
        for (int i = 0; i < data.part_index.length; i++) {
            section[data.part_index[i]].value = value[data.argument_index[i]];
        }

        sequence.sort ( (a, b) => (int) (a < b) );

		for (int i = 0; i < sequence.length; i++)
		{
			var ind = -1;

			for (int j = 0; j < section.length; j++)
			    if (section.get(j).has_value == false && section.get(j).priority == sequence.get(i)) {
			        ind = j;
			        break;
			    }

			var part = section.get (ind);

			var bracket_scope = 0;
			var check_scope = false;
			if ( (part.eval.arg_right >= 1 || part.eval.arg_right == -1) ) {
			    check_scope = true;
			    bracket_scope = part.bracket_value;

			    if (! (OPENING_BRACKET in part.modifier)) {
			        bracket_scope ++;
			    }
			}

			double[] arg = {};

			//get arg_left
			if (part.eval.arg_left > 0)
			{
				    arg += section.get (ind - 1).value;
				    section.remove_index (ind - 1);
			}

			//get arg_right
			int l = 0;
			while (l < part.eval.arg_right || part.eval.arg_right == -1)
			{
			    l ++;
			    if ( (ind + 1 - part.eval.arg_left) < section.length && !(check_scope && bracket_scope <= 0) ) {
				    arg += section.get (ind + 1 - part.eval.arg_left).value;
				    bracket_scope += section.get (ind + 1 - part.eval.arg_left).bracket_value;
				    section.remove_index (ind + 1 - part.eval.arg_left);
				}
				else {
				    break;
				}
			}

			section.set (ind - part.eval.arg_left, Part () {
				value = part.eval.eval(arg, part.data),
				has_value = true,
				bracket_value = bracket_scope
			});
		}
		return section.get (0).value;
    }


    public static Eval fun_extern_eval = (value, data) => {
        var func_data = data as UserFuncData;

        return eval_trusted_function (value, func_data);
    };


    public static void get_data_range (UserFuncData data, double start, double end, int amount_of_steps, ref double[] values, int array_start ) {

        for (int i = 0; i < amount_of_steps; i++) {
            double x = start + (end - start) / (amount_of_steps - 1) * i;

            values [i + array_start] = fun_extern_eval ( {x}, data);

        }

    }

}

}
