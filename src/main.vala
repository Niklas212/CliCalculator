using Calculation;

public inline void _print (string text) {
    print (text);
}

namespace Color {
    public const string red = "\x1B[31m";
    public const string green = "\x1B[32m";
    public const string yellow = "\x1B[33m";
    public const string blue = "\x1B[34m";
    public const string magenta = "\x1B[35m";
    public const string cyan = "\x1B[36m";
    public const string white = "\x1B[37m";
    public const string reset = "\x1B[0m";

    public void print (string text, string color) {
        _print (color + text + reset);
    }
}

int main (string[] args)
{

    var calc = new Evaluation ();

    #if DEBUG
    try {
        assert (calc.eval_auto ("3+4*2") == 11);
        assert (calc.eval_auto ("(3+4)*2") == 14);

        assert (calc.eval_auto ("sin 90") == 1);
        calc.mode = RADIAN;
        assert (calc.eval_auto ("sin (p/2)") == 1);

        assert (calc.eval_auto ("root (median (1, 3, 9), sum( 1 2 1+1 mean 2 4))") == 2);

        assert (calc.create_variable ("x", "2(2+3)") == 10);
        assert (calc.create_variable ("y", "1") == 1);
        assert (calc.eval_auto ("x") == 10);
        assert (calc.eval_auto ("xy") == 10);
        assert (calc.create_variable ("xy", "-(1)") == -1);
        assert (calc.eval_auto ("xy") == -1);
        assert (calc.create_variable ("xy", "-2") == -2);
        assert (calc.eval_auto ("xy") == -2);
        calc.remove_variable ("xy");
        assert (calc.eval_auto ("xy") == 10);

        calc.create_function ("hypo", "sqrt(aa+bb)", {"a", "b"});
        assert (calc.eval_auto ("hypo (3, 4)") == 5);
        calc.remove_function ("hypo");

        print ("all tests passed\n\n");
    } catch (Error e) {
        print (e.message + "\n");
    }
    #endif

    Execution eval = (input) => {
        try {
            print ( ">>\t" + calc.eval_auto (input).to_string () + "\n\n");
        } catch (Error e) {
            if (e is CALC_ERROR.INVALID_SYMBOL /*|| e is CALC_ERROR.REMAINING_ARGUMENT*/)
                print ("\x1b[1F\x1b[2K" + calc.error_info[0] + Color.red + calc.error_info[1] + Color.reset + calc.error_info[2] + "\n");
            Color.print (e.message + "\n\n", Color.red);
        }
    };

    Execution list = () => {

        if (calc.variable.key.length > 0 || calc.fun_extern.key.length > 0) {
            //variables
            for (int i = 0; i < calc.variable.key.length; i++) {
                print(@"\t$(calc.variable.key[i])\t=\t$(calc.variable.value[i])\n");
            }
            //functions
            for (int i = 0; i < calc.fun_extern.key.length; i++)
                print(@"\t$(calc.fun_extern.key[i]) (function)\n");
            print("\n");
        }
        else
            print("no variables or functions created\ntype '[name] = [value]' to create a variable\ntype '[name]([para1], [para2], ...) = [expression]' to create a function\n\n");
    };

    Execution create_variable = (input) => {

	    var parts = Regex.split_simple("[=:]", input);
        string key = parts[0].replace(" ", "");
        //checks if the name is used for a function
        if (calc.contains_symbol (parts[0].replace(" ", ""), false)) {
            Color.print(@"$(parts[0]) is already defined (function)\n\n", Color.yellow);
            return;
        }

        try {
            var value = calc.create_variable (key, parts[1], true);
            Color.print (@"variable '$key' defined ($value)\n", Color.green);
        } catch (Error e) {
            print(e.message + "\n\n");
        }
        print("\n");
    };

    Execution create_function = (input) => {

        var parts = Regex.split_simple("=", input);
        string expression = parts[1];
        var fst_parts = Regex.split_simple("[(]", parts[0]);
        string name = fst_parts[0].replace(" ","");
        string[] paras = Regex.split_simple(",", (fst_parts[1].replace(" ", ""))[0:-1]);
        //checks if a variable is already named so
        if (calc.contains_symbol (name)) {
            Color.print (@"$name is already defined ($( (calc.contains_symbol (name, false)) ? "function" : "variable" ))\n\n", Color.yellow);
            return;
        }

        try {
            calc.create_function (name, expression, paras);
            Color.print (@"function '$name' defined\n\n", Color.green);
        } catch (Error e) {
            print(e.message + "\n\n");
        }
    };

    Execution delete = (input) => {
        var name = input.replace("rm", "").replace(" ", "");
        try {
            if (name in calc.variable.key) {
                calc.remove_variable(name);
                Color.print (@"variable '$name' deleted\n\n", Color.magenta);
            }
            else if (name in calc.fun_extern.key) {
                calc.remove_function(name);
                Color.print (@"function '$name' deleted\n\n", Color.magenta);
            }
            else
                throw new CALC_ERROR.UNKNOWN(@"'$name' is not defined");
        } catch (Error e) {
            Color.print (e.message + "\n\n", Color.yellow);
        }
    };

    Execution settings = (input) => {

        string arg = input [8:input.length];


        if (arg.chomp () == "")
            print (@"\tround-result:\t$(calc.round_result)\n\tdecimal-digits:\t$(calc.decimal_digits)\n\tmode:\t\t$(calc.mode)\n\n\ttype 'settings [setting]' to get details about a setting\n\ttype 'settings set [setting] [value]' to change a setting\n\n");
        else {
            string[] _args = arg.chomp ().chug ().split (" ");

            if (_args[0] == "set") {
                if (_args.length > 2) {
                    switch (_args[1]) {
                        case "round-result": {
                            calc.round_result = _args[2][0].tolower () == 't';
                            Color.print (@"'round-result' set to '$(calc.round_result)'\n\n", Color.cyan);
                            break;
                        }
                        case "decimal-digits": {
                            int8 new_digits = 0;

                            try {
                                new_digits = (int8) calc.eval_auto (_args[2]);

                                if (new_digits > 127)
                                    new_digits = 127;
                                if (new_digits < -128)
                                    new_digits = -128;

                                calc.decimal_digits = new_digits;
                                Color.print (@"'decimal-digits' set to '$new_digits'\n\n", Color.cyan);
                            } catch (Error e) {
                                Color.print ("the value must be a number\n\n", Color.yellow);
                            }
                            break;

                        }
                        case "mode": {
                            calc.mode =  (_args[2][0].tolower () == 'd') ? MODE.DEGREE : MODE.RADIAN;
                            Color.print (@"'mode' set to '$(calc.mode)'\n\n", Color.cyan);
                            break;
                        }
                        default:
                            Color.print (@"unknown setting '$(_args[1])'\n\n", Color.yellow);
                            break;
                    }
                }
                 else {
                    Color.print ("missing value\n\n", Color.yellow);
                }

            } else {
                switch (_args[0]) {

                case "round-result":
                    print (@"\tvalue:\t$(calc.round_result)\n\twheter the result should be rounded\n\tpossible values:\t['true', 'false']\n\n");
                    break;
                case "decimal-digits":
                    print (@"\tvalue:\t$(calc.decimal_digits)\n\tthe amount of decimal digits\n\tpossible values:\ta number between -128 and 127\n\n");
                    break;
                case "mode":
                    print (@"\tvalue:\t$(calc.mode)\n\tpossible values:\t['DEGREE', 'RADIAN']\n\n");
                    break;
                default:
                    Color.print (@"unknown setting '$(_args[0])'\n\n", Color.yellow);
                    break;

                }
            }
        }

    };

    var con = Commands () {
        exit_commands = {"exit", "stop"},
        default_command = Command () {
            execute = eval
        },
        commands = {
            Command () {
                name = "ls",
                description = "lists all created functions and variables",
                execute = list
            },
            Command () {
                name = "create a variable",
                description = "type '[name] = [value]' to create a variable\ne.g. 'x = 10'",
                use_regex = true,
                regex_match = "^[a-zA-Zw]+[ ]?[=:].+$",
                execute = create_variable
            },
            Command () {
                name = "create a function",
                description = "type '[name]([para1], [para2], ...) = [expression]' to create a function'\ne.g. 'f(x) = x^2 + 2x' or 'hypo(a, b) = sqrt (a^2 + b^2)'",
                use_regex = true,
                regex_match = "^[a-zA-Z]+[ ]?[(]([a-zA-Z]+,[ ]?)*[a-zA-Z]+[)][ ]?=.+$",
                execute = create_function
            },
            Command () {
                name = "rm",
                description = "removes a specified variable or function\ne.g. 'rm x'",
                use_regex = true,
                regex_match = "^rm [a-zA-Z]+$",
                execute = delete
            },
            Command () {
                name = "settings",
                description = "show or change settings",
                execute = settings
            }
        }
    };

    stdout.printf("available operators:`+`, `-`, `*`, `/`, `^`, `%`, `E`, `!`\navailable constants:`p`/`pi`, `e`\navailable functions:`sqrt`,`root`(x,y), `mod`, `sin`, `cos`, `tan`, `sinh`,`cosh`,`tanh`\ntype 'help'\n\n");
    run (con);

    return 0;
}


public delegate void Execution (string arg);

public struct Command {
    bool use_regex;
    string regex_match;
    string name;
    string description;
    Execution execute;
}

public struct Commands {
    Command[] commands;
    Command default_command;
    string[] exit_commands;

    public void show_help (string input) {

        print ("\n\n");

        for (int i = 0; i < commands.length; i++) {
            var command = commands[i];

            print (command.name + "\n");
            print (command.description + "\n\n");
        }
    }
}

public void run (Commands commands) {
    string input = "";

    while (true) {
        input = stdin.read_line ();

        if (input in commands.exit_commands)
            break;

        if ("help" in input) {
            commands.show_help (input);
            continue;
        }

        bool executed = false;

        for (int i = 0; i < commands.commands.length; i++) {
            var command = commands.commands[i];

            if ((command.use_regex && Regex.match_simple (command.regex_match, input)) || (!command.use_regex && input.length >= command.name.length && command.name == input[0:command.name.length])) {

                command.execute (input);
                executed = true;
                break;
            }

        }
        if (! executed)
            commands.default_command.execute (input);

    }
}

