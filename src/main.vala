using Calculation;

int main (string[] args)
{

    var calc = new Evaluation ();

    Execution eval = (input) => {
        try {
            print ( ">>\t" + calc.eval_auto (input).to_string () + "\n\n");
        } catch (Error e) {
            print (e.message + "\n\n");
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
        if (parts[0].replace(" ", "") in calc.fun_extern.key) {
            print(@"$(parts[0]) is already defined (function)\n\n");
            return;
        }
        double value = 0;

        try {
            value = calc.eval_auto(parts[1]);
        } catch (Error e) {
            print(e.message + "\n\n");
            return;
        }

        try {
            calc.add_variable (key, value, true);
            print (@">> variable '$key' defined ($value)\n");
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
        if (name in calc.variable.key) {
            print(@"$name is already defined (variable)\n\n");
            return;
        }
        try {
            var data = new UserFuncData.with_data(expression, paras);
            calc.add_function(name, paras.length, data);
            print(@">> function '$name' defined\n\n");
        } catch (Error e) {
            print(e.message + "\n\n");
        }
    };

    Execution delete = (input) => {
        var name = input.replace("rm", "").replace(" ", "");
        try {
            if (name in calc.variable.key) {
                calc.remove_variable(name);
                print(@"variable '$name' deleted\n\n");
            }
            else if (name in calc.fun_extern.key) {
                calc.remove_function(name);
                print(@"function '$name' deleted\n\n");
            }
            else
                throw new CALC_ERROR.UNKNOWN(@"'$name' is not defined");
        } catch (Error e) {
            print(e.message + "\n\n");
        }
    };

    Execution settings = (input) => {

        string arg = input [8:input.length];


        if (arg.chomp () == "")
            print (@">>\tround-result:\t$(calc.round_result)\n>>\tdecimal-digits:\t$(calc.decimal_digits)\n>>\tmode:\t\t$(calc.mode)\n\n>>\ttype 'settings [setting]' to get details about a setting\n>>\ttype 'settings set [setting] [value]' to change a setting\n\n");
        else {
            string[] _args = arg.chomp ().chug ().split (" ");

            if (_args[0] == "set") {
                if (_args.length > 2) {
                    switch (_args[1]) {
                        case "round-result": {
                            calc.round_result = _args[2][0].tolower () == 't';
                            print (@"'round-result' set to '$(calc.round_result)'\n\n");
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
                                print (@"'decimal-digits' set to '$new_digits'\n\n");
                            } catch (Error e) {
                                print ("the value must be a number\n\n");
                            }
                            break;

                        }
                        case "mode": {
                            calc.mode =  (_args[2][0].tolower () == 'd') ? MODE.DEGREE : MODE.RADIAN;
                            print (@"'mode' set to '$(calc.mode)'\n\n");
                            break;
                        }
                        default:
                            print (@"unknown setting '$(_args[1])'\n\n");
                            break;
                    }
                }
                 else {
                    print ("missing value\n\n");
                }

            } else {
                switch (_args[0]) {

                case "round-result":
                    print (@">>\tvalue:\t$(calc.round_result)\n>>\twheter the result should be rounded\n>>\tpossible values:\t['true', 'false']\n\n");
                    break;
                case "decimal-digits":
                    print (@">>\tvalue:\t$(calc.decimal_digits)\n>>\tthe amount of decimal digits\n>>\tpossible values:\ta number between -128 and 127\n\n");
                    break;
                case "mode":
                    print (@">>\tvalue:\t$(calc.mode)\n>>\tpossible values:\t['DEGREE', 'RADIAN']\n\n");
                    break;
                default:
                    print (@"unknown setting '$(_args[0])'\n\n");
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
                name = "RADIAN",
                description = "use radians",
                execute = () => calc.mode = MODE.RADIAN
            },
             Command () {
                name = "DEGREE",
                description = "use degrees",
                execute = () => calc.mode = MODE.DEGREE
            },
            Command () {
                name = "settings",
                description = "show or change settings",
                execute = settings
            }
        }
    };

    stdout.printf("avaible operators:`+`, `-`, `*`, `/`, `^`, `%`, `E`, `!`\navaible constants:`p`/`pi`, `e`\navaible functions:`sqrt`,`root`(x,y), `mod`, `sin`, `cos`, `tan`, `sinh`,`cosh`,`tanh`\ntype 'help'\n\n");
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

