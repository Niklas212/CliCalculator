using GLib.Math;

public Func get_basic_functions () {
    return new Func () {
        key = {"sqrt", "root", "mod", "sum", "mean", "median"},
        eval = {
            fun () {eval = (value) => sqrt (value[0]), arg_left = 0, arg_right = 1},
            fun () {eval = (value) => pow (value[1], 1 / value[0]), arg_left = 0, arg_right = 2},
            fun () {eval = (value) => mod (value[0], value[1]), arg_left = 0, arg_right = 2},
            fun (2) {eval = (value) => sum (value), arg_left = 0, arg_right = -1},
            fun (1) {eval = (value) => mean (value), arg_left = 0, arg_right = -1},
            fun (2) {eval = (value) => median (value), arg_left = 0, arg_right = -1}
        }
    };
}

public Func get_trigonometric_functions_deg () {
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

public Func get_trigonometric_functions_rad () {
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

public Func get_intern_functions (bool mode)
{
//TODO: reimplement
    Func funs = get_basic_functions ();
    var keys = funs.key;
    var evals = funs.eval;

    Func trigonometric_funs = (mode) ? get_trigonometric_functions_deg () : get_trigonometric_functions_rad ();

    for (int i = 0; i < trigonometric_funs.key.length; i++) {
        keys += trigonometric_funs.key[i];
        evals += trigonometric_funs.eval[i];
    }

    funs.key = keys;
    funs.eval = evals;
    return funs;
}

public Operation get_default_operators ()
{
    return Operation(){
		key={"+","-","*","/","%","^","!","E"},
		priority={1,1,2,2,4,3,4,3},
		eval={
			fun(){
				eval=(value)=>value[0]+value[1], arg_left=1, arg_right=1 },
			fun(){
				eval=(value)=>value[0]-value[1], arg_right=1, arg_left=1 },
			fun(){
				eval=(value)=>value[0]*value[1], arg_left=1, arg_right=1},
			fun(){
				eval=(value)=>value[0]/value[1], arg_right=1, arg_left=1 },
			fun(){
				eval=(value)=>value[0]/100,
				arg_left=1, arg_right=0},
			fun(){
				eval=(value)=>pow(value[0],value[1]),
				arg_right=1, arg_left=1},
			fun() {
				eval=(value)=>faq(value[0]),
				arg_left=1, arg_right=0},
			fun() {
				eval=(value)=>value[0]*(pow(10,value[1])),
				arg_left=1, arg_right=1}
		}
	};
}

public Replaceable get_default_variables ()
{
    Replaceable ret = new Replaceable () {
        key = {"e", "p", "pi"},
        value = {2.71828189, PI, PI},
        amount_protected_variables = 3
    };
    return ret;
}
