using Calculation;

int main (string[] args)
{

    var conf = config ();
    var calc = new Evaluation (conf);

    Execution eval = (input) => {
        try {
            print ( ">>\t" + calc.eval_auto (input).to_string () + "\n\n");
        } catch (Error e) {
            print (e.message + "\n\n");
        }
    };

    Execution list = () => {
        var valis = conf.custom_variable;
        var funs = conf.custom_functions;

        if (valis.key.length > 0 || funs.key.length > 0) {
            //variables
            for (int i = 0; i < valis.key.length; i++) {
                print(@"\t$(valis.key[i])\t=\t$(valis.value[i])\n");
            }
            //functions
            for (int i = 0; i < funs.key.length; i++)
                print(@"\t$(funs.key[i]) (function)\n");
            print("\n");
        }
        else
            print("no variables or functions created\ntype '[name] = [value]' to create a variable\ntype '[name]([para1], [para2], ...) = [expression]' to create a function\n\n");
    };

    Execution create_variable = (input) => {
	    var valis = conf.custom_variable;

	    var parts = Regex.split_simple("[=:]", input);
        string key = parts[0].replace(" ", "");
        //checks if the name is used for a function
        if (parts[0].replace(" ", "") in conf.custom_functions.key) {
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
            valis.add_variable(key, value, true);
            conf.custom_variable = valis;
            calc.update(conf);
        } catch (Error e) {
            print(e.message + "\n\n");
        }
        print("\n");
    };

    Execution create_function = (input) => {
        var funs = conf.custom_functions;

        var parts = Regex.split_simple("=", input);
        string expression = parts[1];
        var fst_parts = Regex.split_simple("[(]", parts[0]);
        string name = fst_parts[0].replace(" ","");
        string[] paras = Regex.split_simple(",", (fst_parts[1].replace(" ", ""))[0:-1]);
        //checks if a variable is already named so
        if (name in conf.custom_variable.key) {
            print(@"$name is already defined (variable)\n\n");
            return;
        }
        try {
            var data = new UserFuncData.with_data(expression, paras);
            funs.add_function(name, paras.length, data);
            conf.custom_functions = funs;
            calc.update(conf);
            print("\n");
        } catch (Error e) {
            print(e.message + "\n\n");
        }
    };

    Execution delete = (input) => {
        var valis = conf.custom_variable;
        var funs = conf.custom_functions;

        var name = input.replace("rm", "").replace(" ", "");
        try {
            if (name in valis.key) {
                valis.remove_variable(name);
                print(@"variable '$name' deleted\n\n");
            }
            else if (name in funs.key) {
                funs.remove_function(name);
                print(@"function '$name' deleted\n\n");
            }
            else
                throw new CALC_ERROR.UNKNOWN(@"'$name' is not defined");
            conf.custom_variable = valis;
            conf.custom_functions = funs;
            calc.update(conf);
        } catch (Error e) {
            print(e.message + "\n\n");
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
                regex_match = "^[a-zA-Z]+[ ]?[(]([a-zA-Z],[ ]?)*[a-zA-Z][)][ ]?=.+$",
                execute = create_function
            },
            Command () {
                name = "rm",
                description = "removes a specified variable or function\ne.g. 'rm x'",
                use_regex = true,
                regex_match = "^rm [a-zA-Z]+$",
                execute = delete
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

