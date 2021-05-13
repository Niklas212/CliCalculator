using Calculation;

int main (string[] args)
{
	stdout.printf("avaible operators:`+`, `-`, `*`, `/`, `^`, `%`, `E`, `!`\navaible constants:`p`/`pi`, `e`\navaible functions:`sqrt`,`root`(x,y), `mod`, `sin`, `cos`, `tan`, `sinh`,`cosh`,`tanh`\nMode:degrees\n\n");
    const string re_create_fn = "^[a-zA-Z]+[(]([a-zA-Z],)*[a-zA-Z][)]=.*$";

	string input;
	var running=true;

	var valis = Replaceable();
	var funs = CustomFunctions();
	var conf = config();
    var calc = new Calculation.Evaluation(config(){use_degrees = true});

	while(running)
	{
	    input=stdin.read_line();

	    if (input == "exit")
	        running=false;
	    else if(input.length > 0) {
	        if (Regex.match_simple(@"[a-zA-Zw]+[=:].+", input.replace(" ", ""))) {
	            var parts = Regex.split_simple("[=:]", input);
	            string key = parts[0].replace(" ", "");
	            //checks if a function is named so
	            if (parts[0].replace(" ", "") in conf.custom_functions.key) {
	                print(@"$(parts[0]) is already defined (function)\n\n");
	                continue;
	            }
	            double value = 0;

	            try {
	                value = calc.eval_auto(parts[1]);
	            } catch (Error e) {
	                print(e.message + "\n\n");
	                continue;
	            }

	            try {
	                valis.add_variable(key, value, true);
	                conf.custom_variable = valis;
	                calc.update(conf);
	            } catch (Error e) {
	                print(e.message + "\n\n");
	            }
	            print("\n");
	            continue;
	        }
	        else if (Regex.match_simple(re_create_fn, input.replace(" ", ""))) {
	            var parts = Regex.split_simple("=", input);
	            string expression = parts[1];
	            var fst_parts = Regex.split_simple("[(]", parts[0]);
	            string name = fst_parts[0].replace(" ","");
	            string[] paras = Regex.split_simple(",", (fst_parts[1].replace(" ", ""))[0:-1]);
	            //checks if a variable is already named so
	            if (name in conf.custom_variable.key) {
	                print(@"$name is already defined (variable)\n\n");
	                continue;
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
	            continue;
	        }
	        else if (Regex.match_simple("^delete[a-zA-Z]+$", input.replace(" ", ""))) {
	            var name = input.replace("delete", "").replace(" ", "");
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
                continue;
	        }
	        else if (input == "list") {
	            print (@"=> '$(funs.key.length)'\n");
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
	            else print("no variables or functions created\ntype '[name] = [value]' to create a variable\ntype '[name]([para1], [para2], ...) = [expression]' to create a function\n\n");
	            continue;
	        }
            try {
                double result = calc.eval_auto(input);
	            stdout.printf(@">>\t$result\n\n");
	        }
	        catch (Error e) {
	            stdout.printf(e.message+"\n\n");
	        }
	    }
	}
    stdout.printf("Calculator stopped\n");
	return 0;
}

