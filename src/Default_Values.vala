using GLib.Math;

public class DefaultValues {

    public static bool is_initialised;

    public static Func basic_functions;
    public static Func trigonometric_functions_deg;
    public static Func trigonometric_functions_rad;
    public static Replaceable variables;
    public static Operation operators;

    public static void init () {
        basic_functions = new_basic_functions;
        trigonometric_functions_deg = new_trigonometric_functions_deg;
        trigonometric_functions_rad = new_trigonometric_functions_rad;
        variables = new_variables;
        operators = new_operators;

        is_initialised = true;
    }

    public static owned Func new_basic_functions {
        owned get {
            return new Func () {
                key = {"sqrt", "root", "mod", "sum", "mean", "median"},
                eval = {
                    fun () {eval = (value) => sqrt (value[0]), arg_left = 0, arg_right = 1},
                    fun () {eval = (value) => pow (value[1], 1 / value[0]), arg_left = 0, arg_right = 2},
                    fun () {eval = (value) => mod (value[0], value[1]), arg_left = 0, arg_right = 2},
                    fun (2) {eval = (value) => sum (value), arg_left = 0, arg_right = -1},
                    fun (1) {eval = (value) => mean (value), arg_left = 0, arg_right = -1},
                    fun (1) {eval = (value) => median (value), arg_left = 0, arg_right = -1}
                }
            };
        }
    }

    public static owned Func new_trigonometric_functions_deg {
        owned get {
            return new Func () {
                key = {"sin", "cos", "tan", "sinh", "cosh", "tanh"},
                eval = {
                    fun () {eval = (value) => sin (value[0] * PI / 180), arg_left = 0, arg_right = 1},
                    fun () {eval = (value) => cos (value[0] * PI / 180), arg_left = 0, arg_right = 1},
                    fun () {eval = (value) => tan (value[0] * PI / 180), arg_left = 0, arg_right = 1},
                    fun () {eval = (value) => sinh (value[0] * PI / 180), arg_left = 0, arg_right = 1},
                    fun () {eval = (value) => cosh (value[0] * PI / 180), arg_left = 0, arg_right = 1},
                    fun () {eval = (value) => tanh (value[0] * PI / 180), arg_left = 0, arg_right = 1},
                }
            };
        }
    }

    public static owned Func new_trigonometric_functions_rad {
        owned get {
                return new Func () {
                    key = {"sin", "cos", "tan", "sinh", "cosh", "tanh"},
                    eval = {
                        fun () {eval = (value) => sin (value[0]), arg_left = 0, arg_right = 1},
                        fun () {eval = (value) => cos (value[0]), arg_left = 0, arg_right = 1},
                        fun () {eval = (value) => tan (value[0]), arg_left = 0, arg_right = 1},
                        fun () {eval = (value) => sinh (value[0]), arg_left = 0, arg_right = 1},
                        fun () {eval = (value) => cosh (value[0]), arg_left = 0, arg_right = 1},
                        fun () {eval = (value) => tanh (value[0]), arg_left = 0, arg_right = 1},
                    }
                };
        }
    }


    public static owned Operation new_operators {
        owned get {
            return  new Operation () {
		        key = {"+", "-", "*", "/", "%", "^", "!", "E"},
		        priority = {1, 1, 2, 2, 4, 3, 4, 3},
		        eval = {
			        fun () {
				        eval = (value) => value[0] + value[1], arg_left = 1, arg_right = 1 },
			        fun () {
				        eval = (value) => value[0] - value[1], arg_right = 1, arg_left = 1 },
			        fun () {
				        eval = (value) => value[0] * value[1], arg_left = 1, arg_right = 1},
			        fun () {
				        eval = (value) => value[0] / value[1], arg_right = 1, arg_left = 1 },
			        fun () {
				        eval = (value) => value[0] / 100, arg_left = 1, arg_right = 0},
			        fun () {
				        eval = (value) => pow (value[0], value[1]), arg_right = 1, arg_left = 1},
			        fun () {
				        eval = (value) => faq (value[0]), arg_left = 1, arg_right = 0},
			        fun () {
				        eval = (value) => value[0] * (pow (10, value[1])), arg_left = 1, arg_right = 1}
		        }
	        };
        }
    }

	public static owned Replaceable new_variables {
	    owned get {
	        return new Replaceable () {
                key = {"e", "p", "pi"},
                value = {2.71828189, PI, PI},
                amount_protected_variables = 3
            };
	    }
	}

    public static Func get_intern_functions (Calculation.MODE mode) {
        //TODO
        Func funs = new_basic_functions;
        var keys = funs.key;
        var evals = funs.eval;

        Func trigonometric_funs = (mode == Calculation.MODE.DEGREE) ? new_trigonometric_functions_deg : new_trigonometric_functions_rad;

        for (int i = 0; i < trigonometric_funs.key.length; i++) {
            keys += trigonometric_funs.key[i];
            evals += trigonometric_funs.eval[i];
        }

        funs.key = keys;
        funs.eval = evals;
        return funs;
    }

}

